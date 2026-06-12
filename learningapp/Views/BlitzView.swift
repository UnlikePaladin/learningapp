import SwiftUI
import SwiftData

/// 60-second rapid-fire MC quiz. Pre-generates a batch of easy questions, then runs a timer.
/// Combo multiplier rewards consecutive correct answers (1×, 1.5×, 2×, 2.5×, 3× capped at 5+ streak).
struct BlitzView: View {
    let scope: QuizScope
    var difficulty: DifficultyLevel = .easy  // spec says "intentionally easy" for reinforcement
    var onExit: (Int, Int) -> Void  // (correctCount, totalAnswered)

    @Environment(\.modelContext) private var modelContext
    @AppStorage("blitz.highScore") private var highScore: Int = 0

    private let totalDuration: TimeInterval = 60

    // Game state
    @State private var phase: Phase = .countdown(3)
    @State private var questions: [MCQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var combo: Int = 0
    @State private var bestCombo: Int = 0
    @State private var score: Int = 0
    @State private var correctCount: Int = 0
    @State private var totalAnswered: Int = 0
    @State private var timeRemaining: TimeInterval = 60
    @State private var timer: Timer? = nil

    // Animation flair
    @State private var flashColor: Color? = nil
    @State private var comboPulse: Bool = false
    @State private var lastResultIcon: String? = nil

    enum Phase: Equatable {
        case loading
        case countdown(Int)
        case playing
        case finished
    }

    var body: some View {
        ScrollView {
            switch phase {
            case .loading:
                loadingView
            case .countdown(let n):
                countdownView(n)
            case .playing:
                playingView
                    .padding(.horizontal)
            case .finished:
                resultsView
                    .padding(.horizontal)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: phase)
        .task { await prepare() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Phases

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Loading blitz questions…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .padding()
    }

    private func countdownView(_ n: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color("Yellow"))
            Text(n > 0 ? "\(n)" : "GO!")
                .font(.system(size: 88, weight: .black, design: .rounded))
                .foregroundStyle(Color("Orange"))
                .contentTransition(.numericText())
            Text("Answer as many as you can in 60 seconds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding()
    }

    private var playingView: some View {
        VStack(spacing: 14) {
            timerBar
            statsRow
            if let q = currentQuestion {
                questionCard(q)
            }
            comboFlair
        }
        .padding(.vertical, 8)
        .background(flashColor?.opacity(0.18) ?? .clear)
        .animation(.easeOut(duration: 0.15), value: flashColor)
    }

    // MARK: - Timer bar

    private var timerBar: some View {
        let frac = max(0, min(1, timeRemaining / totalDuration))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(timerColor(for: frac))
                    .frame(width: max(8, geo.size.width * frac))
                    .animation(.linear(duration: 0.2), value: timeRemaining)
            }
        }
        .frame(height: 10)
        .overlay(
            HStack {
                Text("\(Int(ceil(timeRemaining)))s")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                Spacer()
            }
        )
    }

    private func timerColor(for fraction: Double) -> Color {
        if fraction > 0.5 { return Color("Lightgreen") }
        if fraction > 0.25 { return Color("Yellow") }
        return Color("Red")
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack {
            statPill(icon: "star.fill", color: Color("Yellow"), label: "\(score)")
            Spacer()
            comboBadge
            Spacer()
            statPill(icon: "checkmark.circle.fill", color: Color("Darkgreen"), label: "\(correctCount)")
        }
    }

    private func statPill(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(label).font(.caption.bold())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private var comboBadge: some View {
        let multiplier = BlitzSession.multiplier(forCombo: combo)
        let multiplierText = String(format: multiplier == floor(multiplier) ? "%.0f×" : "%.1f×", multiplier)
        return HStack(spacing: 4) {
            if combo >= 3 {
                Image(systemName: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(combo >= 10 ? Color("Red") : (combo >= 5 ? Color("Orange") : Color("Yellow")))
            }
            Text("\(combo) combo").font(.caption.bold())
            Text(multiplierText)
                .font(.caption2.bold())
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color("Orange").opacity(0.2), in: Capsule())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .scaleEffect(comboPulse ? 1.15 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: comboPulse)
    }

    // MARK: - Question card

    private var currentQuestion: MCQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private func questionCard(_ q: MCQuestion) -> some View {
        VStack(spacing: 12) {
            Text(q.prompt)
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                    Button { handleAnswer(idx) } label: {
                        Text(opt)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.primary)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("Darkgreen").opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    // MARK: - Combo flair

    private var comboFlair: some View {
        Group {
            if combo >= 10 {
                Text("🔥 ON FIRE! 🔥")
                    .font(.title3.bold())
                    .foregroundStyle(Color("Red"))
                    .transition(.scale.combined(with: .opacity))
            } else if combo >= 5 {
                Text("🔥 Hot streak!")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color("Orange"))
                    .transition(.scale.combined(with: .opacity))
            } else if combo >= 3 {
                Text("On a roll")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color("Yellow"))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        let isNewHigh = score > highScore
        return VStack(spacing: 18) {
            Image(systemName: isNewHigh ? "crown.fill" : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(isNewHigh ? Color("Yellow") : Color("Darkgreen"))

            Text(isNewHigh ? "New High Score!" : "Time's Up!")
                .font(.largeTitle.bold())

            VStack(spacing: 10) {
                statRow(icon: "star.fill", color: Color("Yellow"), label: "Score", value: "\(score)")
                statRow(icon: "trophy.fill", color: Color("Orange"), label: "High Score", value: "\(max(highScore, score))")
                statRow(icon: "flame.fill", color: Color("Red"), label: "Best Combo", value: "\(bestCombo)")
                statRow(icon: "questionmark.circle.fill", color: .blue, label: "Answered", value: "\(totalAnswered)")
                statRow(icon: "checkmark.circle.fill", color: Color("Darkgreen"), label: "Correct",
                        value: "\(correctCount) (\(accuracyText))")
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                Button { restart() } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.white)
                        .background(Color("Orange"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button { onExit(correctCount, totalAnswered) } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(Color("Darkgreen"))
                        .background(Color("Lightgreen").opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
    }

    private var accuracyText: String {
        guard totalAnswered > 0 else { return "0%" }
        let pct = Int(Double(correctCount) / Double(totalAnswered) * 100)
        return "\(pct)%"
    }

    // MARK: - Setup & flow

    private func prepare() async {
        phase = .loading
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

        let coordinator = StudyCoordinator()
        // Pre-generate a chunky batch upfront so the timer doesn't catch us mid-generation.
        let batch = await coordinator.generateMCQuestions(
            for: ragScope,
            topicHint: topicHint,
            count: 25,
            difficulty: .easy,
            context: modelContext
        )
        questions = batch
        if questions.isEmpty {
            // Skip the countdown and show empty results immediately.
            phase = .finished
            return
        }
        await runCountdown()
    }

    private func runCountdown() async {
        for n in stride(from: 3, through: 1, by: -1) {
            await MainActor.run { phase = .countdown(n) }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        await MainActor.run { phase = .countdown(0) }
        try? await Task.sleep(nanoseconds: 400_000_000)
        await MainActor.run { startGame() }
    }

    private func startGame() {
        timeRemaining = totalDuration
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                timer?.invalidate()
                timer = nil
                if score > highScore { highScore = score }
                phase = .finished
            }
        }
    }

    private func handleAnswer(_ index: Int) {
        guard let q = currentQuestion else { return }
        totalAnswered += 1
        if index == q.correctIndex {
            // Combo bumps BEFORE we score this answer — multiplier scales as the streak grows.
            let multiplier = BlitzSession.multiplier(forCombo: combo + 1)
            let pointsEarned = Int(round(Double(BlitzSession.basePoints) * multiplier))
            score += pointsEarned
            combo += 1
            bestCombo = max(bestCombo, combo)
            correctCount += 1
            flashColor = Color("Lightgreen")
            comboPulse.toggle()
        } else {
            combo = 0
            flashColor = Color("Red")
        }

        // Move to next question. Wrap if user burns through the whole batch.
        currentIndex += 1
        if currentIndex >= questions.count { currentIndex = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { flashColor = nil }
    }

    private func restart() {
        timer?.invalidate()
        timer = nil
        currentIndex = 0
        combo = 0
        bestCombo = 0
        score = 0
        correctCount = 0
        totalAnswered = 0
        timeRemaining = totalDuration
        phase = .countdown(3)
        Task { await prepare() }
    }
}
