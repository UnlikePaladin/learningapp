import SwiftUI
import SwiftData

/// Endless variant of the block quiz. Questions stream in from the AI in the background;
/// the run continues until the grid jams (no valid placement for the next earned block) or
/// the user quits. Tracks a high score per scope.
struct BlockInfiniteView: View {
    let scope: QuizScope
    var difficulty: DifficultyLevel = .medium
    var onExit: (Int, Int) -> Void  // (correctCount, totalAnswered)

    @Environment(\.modelContext) private var modelContext
    @AppStorage("blockInfinite.highScore") private var globalHighScore: Int = 0

    // Game grid (matches the BlockQuizView layout)
    private let gridRows = 5
    private let gridCols = 6

    @State private var grid: [[Bool]] = Array(repeating: Array(repeating: false, count: 6), count: 5)
    @State private var clearingRows: Set<Int> = []
    @State private var clearingCols: Set<Int> = []
    @State private var blocksPlaced: Int = 0
    @State private var linesCleared: Int = 0
    @State private var score: Int = 0

    // Block placement state
    @State private var pendingBlock: BlockShape? = nil
    @State private var isPlacingBlock: Bool = false
    @State private var validAnchors: Set<CellPosition> = []
    @State private var previewAnchor: CellPosition? = nil
    @State private var bonusText: String? = nil
    @State private var showBonus: Bool = false
    @State private var gridBounce: Bool = false

    // Question state — uses an async queue replenished in the background
    @State private var questionQueue: [MCQuestion] = []
    @State private var currentQuestion: MCQuestion? = nil
    @State private var wrongOptions: Set<Int> = []
    @State private var attemptsLeft: Int = 2
    @State private var totalAnswered: Int = 0
    @State private var correctCount: Int = 0
    @State private var cardShake: CGFloat = 0
    @State private var feedbackScale: CGFloat = 0.85

    @State private var isFetchingMore: Bool = false
    @State private var fetchFailureCount: Int = 0
    @State private var coordinator = StudyCoordinator()

    // End-of-run state
    @State private var gameOver: Bool = false
    @State private var gameOverReason: String = ""
    @State private var startTime: Date = Date()

    // Showing answer feedback inline
    @State private var showFeedback: Bool = false
    @State private var lastCorrect: Bool = false

    private var previewCells: Set<CellPosition> {
        guard let anchor = previewAnchor, let block = pendingBlock else { return [] }
        return Set(block.cells.map { CellPosition(row: anchor.row + $0.row, col: anchor.col + $0.col) })
    }

    private var elapsedSeconds: Int { max(0, Int(Date().timeIntervalSince(startTime))) }

    var body: some View {
        ScrollView {
            if gameOver {
                gameOverView
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if isPlacingBlock {
                placementView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if currentQuestion != nil {
                quizView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                loadingView
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isPlacingBlock)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: gameOver)
        .task { await initialFetch() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Preparing infinite mode…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .padding()
    }

    // MARK: - Game over

    private var gameOverView: some View {
        VStack(spacing: 18) {
            Image(systemName: score >= globalHighScore && score > 0 ? "crown.fill" : "flag.checkered")
                .font(.system(size: 56))
                .foregroundStyle(Color("Yellow"))

            Text(score >= globalHighScore && score > 0 ? "New High Score!" : "Game Over")
                .font(.largeTitle.bold())

            Text(gameOverReason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                statRow(icon: "star.fill", color: Color("Yellow"), label: "Score", value: "\(score)")
                statRow(icon: "trophy.fill", color: Color("Orange"), label: "High Score", value: "\(globalHighScore)")
                statRow(icon: "square.grid.2x2", color: Color("Darkgreen"), label: "Blocks Placed", value: "\(blocksPlaced)")
                statRow(icon: "rectangle.split.3x1.fill", color: Color("Lightgreen"), label: "Lines Cleared", value: "\(linesCleared)")
                statRow(icon: "questionmark.circle.fill", color: .blue, label: "Questions", value: "\(correctCount)/\(totalAnswered) correct")
                statRow(icon: "clock.fill", color: .secondary, label: "Time", value: formatTime(elapsedSeconds))
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                Button {
                    restart()
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    onExit(correctCount, totalAnswered)
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(Color("Darkgreen"))
                        .background(Color("Lightgreen").opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Quiz view

    private var quizView: some View {
        VStack(spacing: 14) {
            statsHeader.padding(.horizontal)
            miniGridPreview.padding(.horizontal)
            if let q = currentQuestion {
                if showFeedback {
                    feedbackCard(for: q)
                        .padding(.horizontal)
                } else {
                    mcCard(for: q)
                        .offset(x: cardShake)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var statsHeader: some View {
        HStack(spacing: 14) {
            statPill(icon: "star.fill", color: Color("Yellow"), value: "\(score)")
            statPill(icon: "trophy.fill", color: Color("Orange"), value: "\(max(globalHighScore, score))")
            Spacer()
            statPill(icon: "questionmark.circle.fill", color: .blue, value: "Q\(totalAnswered + 1)")
            if isFetchingMore {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    private func statPill(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.caption.bold())
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }

    private var miniGridPreview: some View {
        HStack {
            Spacer()
            gridView(cellSize: 20, interactive: false)
            Spacer()
        }
    }

    private func mcCard(for question: MCQuestion) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color("Darkgreen")).frame(height: 5)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("INFINITE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color("Darkgreen"), Color("Orange")],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<attemptsLeft, id: \.self) { _ in
                            Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Color("Red"))
                        }
                    }
                }

                Text(question.prompt)
                    .font(.title3.bold())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { idx, opt in
                        optionButton(question: question, index: idx, text: opt)
                    }
                }
            }
            .padding(18)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.09), radius: 12, y: 5)
    }

    private func optionButton(question: MCQuestion, index: Int, text: String) -> some View {
        let isWrong = wrongOptions.contains(index)
        let letters = ["A", "B", "C", "D"]
        return Button { handleAnswer(question: question, index: index) } label: {
            HStack(spacing: 10) {
                Text(letters[min(index, 3)])
                    .font(.caption.bold())
                    .frame(width: 24, height: 24)
                    .background(
                        isWrong ? Color.secondary.opacity(0.15) : Color("Darkgreen").opacity(0.15),
                        in: Circle()
                    )
                    .foregroundStyle(isWrong ? Color.secondary : Color("Darkgreen"))

                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isWrong {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(Color("Red"))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                isWrong ? Color.secondary.opacity(0.06) : Color("Darkgreen").opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isWrong ? Color.secondary.opacity(0.2) : Color("Darkgreen").opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isWrong)
    }

    private func feedbackCard(for question: MCQuestion) -> some View {
        let headerColor: Color = lastCorrect ? Color("Darkgreen") : Color("Red")
        let headerIcon = lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        let headerTitle = lastCorrect ? "Correct! Block earned" : "Incorrect"

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: headerIcon).font(.title2).foregroundStyle(.white)
                Text(headerTitle).font(.headline.bold()).foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(headerColor)

            VStack(alignment: .leading, spacing: 12) {
                if !lastCorrect {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Correct answer:").font(.caption.bold()).foregroundStyle(Color("Orange"))
                        Text(question.options[question.correctIndex])
                            .font(.body.bold()).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color("Orange").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("Orange").opacity(0.2), lineWidth: 1))
                }

                if lastCorrect {
                    Button { enterPlacementMode() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2").font(.headline)
                            Text("Place Block on Grid").font(.headline.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { advance() } label: {
                        Text("Next Question  →")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(.white)
                            .background(headerColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.09), radius: 12, y: 5)
    }

    // MARK: - Placement view (mirrors BlockQuizView's placement UI)

    private var placementView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Place Your Block")
                            .font(.title2.bold())
                        Text("Tap a highlighted cell. Clear rows or columns for bonus points!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.subheadline).foregroundStyle(Color("Yellow"))
                            Text("\(score)").font(.title3.bold())
                        }
                        if showBonus, let bonus = bonusText {
                            Text(bonus)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color("Orange"))
                                .transition(.scale(scale: 0.7).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            if let block = pendingBlock {
                HStack(spacing: 12) {
                    Text("Your block:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    block.shapeView(cellSize: 24)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color("Darkgreen").opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Darkgreen").opacity(0.2), lineWidth: 1))
                .padding(.horizontal)
            }

            HStack {
                Spacer()
                gridView(cellSize: 30, interactive: true)
                Spacer()
            }
            .padding(.horizontal)

            if previewAnchor != nil {
                Button {
                    if let anchor = previewAnchor { confirmPlacement(at: anchor) }
                } label: {
                    Label("Place Here", systemImage: "checkmark.circle.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Text("Tap a highlighted cell to preview placement")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Grid

    private func gridView(cellSize: CGFloat, interactive: Bool) -> some View {
        VStack(spacing: 2) {
            ForEach(0..<gridRows, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<gridCols, id: \.self) { c in
                        let isClearing = clearingRows.contains(r) || clearingCols.contains(c)
                        let isPreview = previewCells.contains(CellPosition(row: r, col: c))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellFill(row: r, col: c, interactive: interactive, isClearing: isClearing))
                            .frame(width: cellSize, height: cellSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(isPreview ? Color("Darkgreen").opacity(0.8) : Color.clear, lineWidth: 1.5)
                            )
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: grid[r][c])
                            .animation(.easeInOut(duration: 0.18), value: isClearing)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPreview)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if interactive { handleGridTap(row: r, col: c) }
                            }
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
        .scaleEffect(gridBounce ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: gridBounce)
    }

    private func cellFill(row: Int, col: Int, interactive: Bool, isClearing: Bool) -> Color {
        if isClearing { return Color("Orange") }
        if grid[row][col] { return Color("Darkgreen") }
        let pos = CellPosition(row: row, col: col)
        if interactive {
            if previewCells.contains(pos) { return Color("Lightgreen") }
            if validAnchors.contains(pos) {
                return previewAnchor == nil
                    ? Color("Lightgreen").opacity(0.35)
                    : Color.secondary.opacity(0.08)
            }
        }
        return Color.secondary.opacity(0.1)
    }

    // MARK: - Question fetching

    private func initialFetch() async {
        if !questionQueue.isEmpty || currentQuestion != nil { return }
        await fetchMore(initial: true)
        if currentQuestion == nil, let next = questionQueue.first {
            questionQueue.removeFirst()
            currentQuestion = next
        }
        if currentQuestion == nil {
            triggerGameOver(reason: "Couldn't generate any questions for this scope. Try adding more material.")
        }
    }

    private func fetchMore(initial: Bool = false) async {
        if isFetchingMore { return }
        isFetchingMore = true
        defer { isFetchingMore = false }

        let ragScope: RAGService.Scope
        let topicHint: String
        switch scope.kind {
        case .lesson(let lesson):
            ragScope = .lesson(lesson.id)
            topicHint = lesson.title
        case .module(let module, _):
            ragScope = .module(module.id)
            topicHint = "\(module.title) \(module.summary)"
        case .plan(let plan):
            ragScope = .lessons(plan.lessonIDs)
            topicHint = plan.name
        }

        let batchSize = initial ? 8 : 6
        let questions = await coordinator.generateMCQuestions(
            for: ragScope,
            topicHint: topicHint,
            count: batchSize,
            difficulty: difficulty,
            context: modelContext
        )

        if questions.isEmpty {
            fetchFailureCount += 1
        } else {
            // Avoid back-to-back duplicates by deduping against the existing queue.
            let existing = Set(questionQueue.map { normalize($0.prompt) })
            let fresh = questions.filter { !existing.contains(normalize($0.prompt)) }
            questionQueue.append(contentsOf: fresh)
            fetchFailureCount = 0
        }
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    // MARK: - Answer flow

    private func handleAnswer(question: MCQuestion, index: Int) {
        if index == question.correctIndex {
            lastCorrect = true
            correctCount += 1
            score += 10
            feedbackScale = 0.85
            withAnimation(.easeInOut(duration: 0.18)) { showFeedback = true }
            // Earn a small/medium block on correct answer.
            pendingBlock = BlockShape.allShapesPool().filter { $0.cells.count <= 3 }.randomElement()
        } else {
            attemptsLeft -= 1
            wrongOptions.insert(index)
            shakeCard()
            if attemptsLeft <= 0 {
                lastCorrect = false
                feedbackScale = 0.85
                withAnimation(.easeInOut(duration: 0.18)) { showFeedback = true }
            }
        }
    }

    private func enterPlacementMode() {
        guard let block = pendingBlock else {
            advance()
            return
        }
        computeValidAnchors(for: block)

        if validAnchors.isEmpty {
            // Grid is jammed for this block — game over.
            triggerGameOver(reason: "The grid is full — no room to place your next block.")
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isPlacingBlock = true }
    }

    private func handleGridTap(row: Int, col: Int) {
        let tapped = CellPosition(row: row, col: col)
        if previewCells.contains(tapped), let anchor = previewAnchor {
            confirmPlacement(at: anchor)
            return
        }
        if validAnchors.contains(tapped) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                previewAnchor = (previewAnchor == tapped) ? nil : tapped
            }
            return
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { previewAnchor = nil }
    }

    private func confirmPlacement(at anchor: CellPosition) {
        guard let block = pendingBlock else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            placeShape(block, row: anchor.row, col: anchor.col)
            blocksPlaced += 1
        }

        previewAnchor = nil
        pendingBlock = nil
        validAnchors = []

        gridBounce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { gridBounce = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { checkAndClearLines() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isPlacingBlock = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showFeedback = false
                lastCorrect = false
                advance()
            }
        }
    }

    private func advance() {
        totalAnswered += 1

        // Update high score live
        if score > globalHighScore { globalHighScore = score }

        // Reset per-question state
        wrongOptions = []
        attemptsLeft = 2
        showFeedback = false
        lastCorrect = false
        feedbackScale = 0.85
        currentQuestion = nil

        // Pull next question or fetch if queue is empty
        Task {
            // Trigger background top-up if running low
            if questionQueue.count <= 3 && !isFetchingMore {
                Task { await fetchMore() }
            }

            // Wait for a question to be available, with a backoff if fetching is in progress
            var attempts = 0
            while questionQueue.isEmpty && attempts < 30 {
                if !isFetchingMore { await fetchMore() }
                if questionQueue.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    attempts += 1
                }
            }

            if let next = questionQueue.first {
                questionQueue.removeFirst()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentQuestion = next
                }
            } else {
                triggerGameOver(reason: "Ran out of questions and couldn't generate more. Add more material to keep going.")
            }
        }
    }

    private func shakeCard() {
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { cardShake = 9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { cardShake = -9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring()) { cardShake = 0 }
        }
    }

    private func triggerGameOver(reason: String) {
        if score > globalHighScore { globalHighScore = score }
        gameOverReason = reason
        withAnimation { gameOver = true }
    }

    private func restart() {
        grid = Array(repeating: Array(repeating: false, count: gridCols), count: gridRows)
        clearingRows = []
        clearingCols = []
        blocksPlaced = 0
        linesCleared = 0
        score = 0
        pendingBlock = nil
        isPlacingBlock = false
        validAnchors = []
        previewAnchor = nil
        bonusText = nil
        showBonus = false
        questionQueue = []
        currentQuestion = nil
        wrongOptions = []
        attemptsLeft = 2
        totalAnswered = 0
        correctCount = 0
        showFeedback = false
        lastCorrect = false
        gameOver = false
        gameOverReason = ""
        startTime = Date()
        Task { await initialFetch() }
    }

    // MARK: - Block grid logic

    private func computeValidAnchors(for block: BlockShape) {
        var positions = Set<CellPosition>()
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                if canPlaceShape(block, row: r, col: c) {
                    positions.insert(CellPosition(row: r, col: c))
                }
            }
        }
        validAnchors = positions
    }

    private func canPlaceShape(_ shape: BlockShape, row: Int, col: Int) -> Bool {
        for cell in shape.cells {
            let r = row + cell.row
            let c = col + cell.col
            if r < 0 || r >= gridRows || c < 0 || c >= gridCols { return false }
            if grid[r][c] { return false }
        }
        return true
    }

    private func placeShape(_ shape: BlockShape, row: Int, col: Int) {
        for cell in shape.cells {
            let r = row + cell.row
            let c = col + cell.col
            guard r >= 0, r < gridRows, c >= 0, c < gridCols else { continue }
            grid[r][c] = true
        }
    }

    private func checkAndClearLines() {
        var linesClearedNow = 0
        var newGrid = grid

        var rowsToClear = Set<Int>()
        for r in 0..<gridRows where grid[r].allSatisfy({ $0 }) {
            rowsToClear.insert(r)
            linesClearedNow += 1
        }

        var colsToClear = Set<Int>()
        for c in 0..<gridCols where (0..<gridRows).allSatisfy({ grid[$0][c] }) {
            colsToClear.insert(c)
            linesClearedNow += 1
        }

        guard linesClearedNow > 0 else { return }

        clearingRows = rowsToClear
        clearingCols = colsToClear

        // Bonus scales with the run — keep the rush going as the player scores more
        let bonus = linesClearedNow * 20 * (linesClearedNow > 1 ? 2 : 1)
        score += bonus
        linesCleared += linesClearedNow
        if score > globalHighScore { globalHighScore = score }
        bonusText = "+\(bonus) Bonus!"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showBonus = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) { showBonus = false }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 0.25)) {
                for r in rowsToClear { newGrid[r] = Array(repeating: false, count: gridCols) }
                for c in colsToClear { for r in 0..<gridRows { newGrid[r][c] = false } }
                grid = newGrid
                clearingRows = []
                clearingCols = []
            }
        }
    }
}
