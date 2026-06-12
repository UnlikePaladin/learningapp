import SwiftUI

struct BlockQuizView: View {
    let questions: [MCQuestion]
    var difficulty: DifficultyLevel = .medium
    var onComplete: ([Bool]) -> Void

    private let gridRows = 5
    private let gridCols = 6

    @State private var grid: [[Bool]] = Array(repeating: Array(repeating: false, count: 6), count: 5)
    @State private var clearingRows: Set<Int> = []
    @State private var clearingCols: Set<Int> = []
    @State private var blocksPlaced: Int = 0
    @State private var score: Int = 0

    @State private var pendingBlock: BlockShape? = nil
    @State private var isPlacingBlock: Bool = false
    @State private var validAnchors: Set<CellPosition> = []
    @State private var previewAnchor: CellPosition? = nil
    @State private var bonusText: String? = nil
    @State private var showBonus: Bool = false
    @State private var gridBounce: Bool = false

    private var previewCells: Set<CellPosition> {
        guard let anchor = previewAnchor, let block = pendingBlock else { return [] }
        return Set(block.cells.map { CellPosition(row: anchor.row + $0.row, col: anchor.col + $0.col) })
    }

    @State private var currentIndex: Int = 0
    @State private var wrongOptions: Set<Int> = []
    @State private var attemptsLeft: Int = 2
    @State private var showFeedback: Bool = false
    @State private var lastCorrect: Bool = false
    @State private var results: [Bool] = []
    @State private var cardOffset: CGFloat = 0
    @State private var cardShake: CGFloat = 0
    @State private var feedbackScale: CGFloat = 0.85

    private var currentQuestion: MCQuestion { questions[currentIndex] }
    private var progress: Double { Double(currentIndex + 1) / Double(questions.count) }

    var body: some View {
        ScrollView {
            if isPlacingBlock {
                placementView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                quizView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isPlacingBlock)
    }

    // MARK: - Quiz view (question + mini grid)

    private var quizView: some View {
        VStack(spacing: 14) {
            progressSection.padding(.horizontal)
            statsRow.padding(.horizontal)
            miniGridPreview.padding(.horizontal)
            questionSection.padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color("Lightgreen"), Color("Darkgreen")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(10, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            HStack {
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var statsRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption).foregroundStyle(Color("Yellow"))
                Text("Score: \(score)").font(.caption.bold())
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "square.fill").font(.caption).foregroundStyle(Color("Darkgreen"))
                Text("\(blocksPlaced) blocks placed").font(.caption.bold()).foregroundStyle(Color("Darkgreen"))
            }
        }
    }

    private var miniGridPreview: some View {
        HStack {
            Spacer()
            gridView(cellSize: 20, interactive: false)
            Spacer()
        }
    }

    private var questionSection: some View {
        Group {
            if showFeedback {
                feedbackCard
                    .scaleEffect(feedbackScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { feedbackScale = 1.0 }
                    }
            } else {
                mcCard.offset(x: cardShake)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.09), radius: 12, y: 5)
        .offset(x: cardOffset)
        .animation(.easeInOut(duration: 0.22), value: showFeedback)
    }

    // MARK: - Placement view

    private var placementView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Place Your Block")
                            .font(.title2.bold())
                        Text("Tap a highlighted cell. Complete rows or columns for bonus points!")
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

            // Pending block tray
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

            // Large interactive grid
            HStack {
                Spacer()
                gridView(cellSize: 30, interactive: true)
                Spacer()
            }
            .padding(.horizontal)

            // Confirm button — appears once user selects a position
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

            // Legend
            HStack(spacing: 16) {
                legendItem(color: Color("Lightgreen").opacity(0.5), label: "Valid")
                legendItem(color: Color("Lightgreen"), label: "Preview")
                legendItem(color: Color("Darkgreen"), label: "Placed")
                legendItem(color: Color("Orange"), label: "Clearing!")
            }
            .padding(.horizontal)

            Spacer(minLength: 20)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Shared grid view

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
                                    .stroke(
                                        isPreview ? Color("Darkgreen").opacity(0.8) : Color.clear,
                                        lineWidth: 1.5
                                    )
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

    // MARK: - MC card

    private var mcCard: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color("Darkgreen")).frame(height: 5)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Q\(currentIndex + 1)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color("Darkgreen").opacity(0.12), in: Capsule())
                        .foregroundStyle(Color("Darkgreen"))

                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { i in
                            Circle()
                                .fill(i <= difficulty.dotCount ? difficulty.color : Color.secondary.opacity(0.2))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Spacer()

                    Text(difficulty.rawValue).font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 3) {
                        ForEach(0..<attemptsLeft, id: \.self) { _ in
                            Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Color("Red"))
                        }
                    }
                }

                Text(currentQuestion.prompt)
                    .font(.title3.bold())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(Array(currentQuestion.options.enumerated()), id: \.offset) { idx, opt in
                        optionButton(index: idx, text: opt)
                    }
                }
            }
            .padding(18)
        }
    }

    private func optionButton(index: Int, text: String) -> some View {
        let isWrong = wrongOptions.contains(index)
        let letters = ["A", "B", "C", "D"]
        return Button { handleAnswer(index) } label: {
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

    // MARK: - Feedback card

    private var feedbackCard: some View {
        let headerColor: Color = lastCorrect ? Color("Darkgreen") : Color("Red")
        let headerIcon = lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        let headerTitle = lastCorrect ? "Correct! Block earned" : "Incorrect"

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: headerIcon).font(.title2).foregroundStyle(.white)
                Text(headerTitle).font(.headline.bold()).foregroundStyle(.white)
                Spacer()
                if lastCorrect {
                    Image(systemName: "square.fill").font(.title3).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(headerColor)

            VStack(alignment: .leading, spacing: 12) {
                if !lastCorrect {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Correct answer:").font(.caption.bold()).foregroundStyle(Color("Orange"))
                        Text(currentQuestion.options[currentQuestion.correctIndex])
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
                        Text(currentIndex < questions.count - 1 ? "Next Question  →" : "Finish")
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
    }

    // MARK: - Actions

    private func handleAnswer(_ index: Int) {
        if index == currentQuestion.correctIndex {
            lastCorrect = true
            results.append(true)
            score += 10
            feedbackScale = 0.85
            showFeedback = true
            pendingBlock = BlockShape.allShapesPool().filter { $0.cells.count <= 3 }.randomElement()
        } else {
            attemptsLeft -= 1
            wrongOptions.insert(index)
            shakeCard()
            if attemptsLeft <= 0 {
                lastCorrect = false
                results.append(false)
                feedbackScale = 0.85
                showFeedback = true
            }
        }
    }

    private func enterPlacementMode() {
        guard let block = pendingBlock else { advance(); return }
        computeValidAnchors(for: block)

        if validAnchors.isEmpty {
            withAnimation(.easeInOut(duration: 0.35)) {
                grid = Array(repeating: Array(repeating: false, count: gridCols), count: gridRows)
            }
            pendingBlock = nil
            score += 15
            showFeedback = false
            lastCorrect = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isPlacingBlock = true
        }
    }

    private func handleGridTap(row: Int, col: Int) {
        let tapped = CellPosition(row: row, col: col)

        // Tap on ghost preview → confirm
        if previewCells.contains(tapped), let anchor = previewAnchor {
            confirmPlacement(at: anchor)
            return
        }

        // Tap valid anchor → set preview (or deselect if same)
        if validAnchors.contains(tapped) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                previewAnchor = (previewAnchor == tapped) ? nil : tapped
            }
            return
        }

        // Tap elsewhere → clear preview
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
        if currentIndex < questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.18)) { cardOffset = -420 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                currentIndex += 1
                wrongOptions = []
                attemptsLeft = 2
                showFeedback = false
                lastCorrect = false
                feedbackScale = 0.85
                cardOffset = 420
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) { cardOffset = 0 }
            }
        } else {
            onComplete(results)
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
        var linesCleared = 0
        var newGrid = grid

        var rowsToClear = Set<Int>()
        for r in 0..<gridRows where grid[r].allSatisfy({ $0 }) {
            rowsToClear.insert(r)
            linesCleared += 1
        }

        var colsToClear = Set<Int>()
        for c in 0..<gridCols where (0..<gridRows).allSatisfy({ grid[$0][c] }) {
            colsToClear.insert(c)
            linesCleared += 1
        }

        guard linesCleared > 0 else { return }

        clearingRows = rowsToClear
        clearingCols = colsToClear

        let bonus = linesCleared * 20 * (linesCleared > 1 ? 2 : 1)
        score += bonus
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
