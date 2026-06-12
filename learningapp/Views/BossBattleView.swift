import SwiftUI
import SwiftData

/// Boss Battle mode. The current scope (lesson/module/plan) becomes the "boss".
/// User HP starts at 3 hearts; boss HP starts at 5 rounds. Difficulty scales by round.
/// Win = boss HP zero. Lose = user HP zero (offers retry on easier).
struct BossBattleView: View {
    let scope: QuizScope
    var difficulty: DifficultyLevel = .medium
    var onExit: (Int, Int) -> Void  // (correctCount, totalAnswered)

    @Environment(\.modelContext) private var modelContext

    // Phases of the battle
    enum Phase {
        case loading
        case intro
        case playing
        case feedback
        case victory
        case defeat
    }

    @State private var phase: Phase = .loading
    @State private var encounter: BossEncounter? = nil
    @State private var topic: String = ""

    // Question + answer state
    @State private var currentQuestion: Question? = nil
    @State private var userAnswer: String = ""
    @State private var lastFeedback: Feedback? = nil
    @State private var lastReaction: String = ""
    @State private var lastCorrect: Bool = false
    @State private var isEvaluating: Bool = false
    @State private var isLoadingNext: Bool = false

    // Closing message (victory/defeat)
    @State private var outcomeMessage: String = ""

    // Animations
    @State private var bossShake: CGFloat = 0
    @State private var heartShake: CGFloat = 0
    @State private var damageFlash: Bool = false

    // Aggregate stats reported on exit
    @State private var totalAnswered: Int = 0
    @State private var correctCount: Int = 0

    private let modelService = FoundationModelService()
    private let coordinator = StudyCoordinator()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                switch phase {
                case .loading:
                    loadingView
                case .intro:
                    introView
                case .playing, .feedback:
                    battleView
                case .victory:
                    outcomeView(victory: true)
                case .defeat:
                    outcomeView(victory: false)
                }
            }
            .padding()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: phase)
        .task { await setupBattle() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Summoning your boss…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 22) {
            bossSpriteView
                .frame(height: 120)

            VStack(spacing: 8) {
                Text(encounter?.bossName ?? "???")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color("Red"))
                Text("Boss Battle: \(topic)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            dialogueBubble(text: encounter?.bossIntro ?? "Prepare yourself…")

            Button { phase = .playing; Task { await loadRoundQuestion() } } label: {
                Label("Begin Battle", systemImage: "flame.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [Color("Red"), Color("Orange")], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Battle

    private var battleView: some View {
        VStack(spacing: 14) {
            bossHeader
            bossSpriteView
                .frame(height: 100)
                .offset(x: bossShake)
                .opacity(damageFlash ? 0.4 : 1.0)

            if phase == .feedback {
                reactionBubble
            }

            userHeader

            if phase == .playing {
                questionCard
            } else if phase == .feedback {
                feedbackCard
            }
        }
    }

    private var bossHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(Color("Red"))
                Text(encounter?.bossName ?? "Boss").font(.headline)
                Spacer()
                Text("Round \(encounter?.currentRound ?? 1)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color("Orange").opacity(0.2), in: Capsule())
            }
            hpBar(
                current: encounter?.currentBossHP ?? 0,
                total: encounter?.totalBossHP ?? 1,
                color: Color("Red"),
                trackColor: Color("Red").opacity(0.2)
            )
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var userHeader: some View {
        HStack {
            Text("You").font(.headline)
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < (encounter?.userHP ?? 0) ? "heart.fill" : "heart")
                        .foregroundStyle(Color("Red"))
                        .font(.title3)
                        .offset(x: i < (encounter?.userHP ?? 0) ? 0 : heartShake)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var bossSpriteView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color("Red").opacity(0.7), Color("Orange").opacity(0.5)],
                        center: .center, startRadius: 10, endRadius: 80
                    )
                )
                .frame(width: 110, height: 110)
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .shadow(color: Color("Red"), radius: 8)
        }
    }

    private func hpBar(current: Int, total: Int, color: Color, trackColor: Color) -> some View {
        let frac = total > 0 ? max(0, min(1, Double(current) / Double(total))) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(color)
                    .frame(width: max(8, geo.size.width * frac))
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: current)
            }
        }
        .frame(height: 12)
        .overlay(
            HStack {
                Spacer()
                Text("\(current)/\(total)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.trailing, 8)
            }
        )
    }

    private func dialogueBubble(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color("Red").opacity(0.3), lineWidth: 1))
    }

    private var reactionBubble: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "quote.opening").foregroundStyle(.secondary)
            Text(lastReaction.isEmpty ? "…" : lastReaction)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color("Red").opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Question card

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(roundLabel).font(.caption.bold()).foregroundStyle(Color("Orange"))
                Spacer()
            }
            if isLoadingNext || currentQuestion == nil {
                HStack {
                    ProgressView()
                    Text("Preparing the next attack…").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else if let q = currentQuestion {
                Text(q.prompt)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("Type your answer", text: $userAnswer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Button { Task { await submitAnswer(q) } } label: {
                    HStack {
                        if isEvaluating { ProgressView().scaleEffect(0.7) }
                        Text(isEvaluating ? "Evaluating…" : "Strike!")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(.white)
                    .background(Color("Red"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEvaluating)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var roundLabel: String {
        guard let e = encounter else { return "" }
        switch e.roundDifficulty {
        case .easy: return "ROUND \(e.currentRound) · RECOGNITION"
        case .medium: return "ROUND \(e.currentRound) · RECALL"
        case .hard: return "ROUND \(e.currentRound) · APPLICATION"
        }
    }

    // MARK: - Feedback card

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(lastCorrect ? Color("Darkgreen") : Color("Red"))
                Text(lastCorrect ? "Direct hit!" : "Missed!")
                    .font(.headline.bold())
            }
            if let fb = lastFeedback, !fb.explanation.isEmpty {
                Text(fb.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button { Task { await advanceRound() } } label: {
                Text(continueLabel)
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(.white)
                    .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var continueLabel: String {
        guard let e = encounter else { return "Continue" }
        if e.isBossDefeated { return "Victory!  →" }
        if e.isUserDefeated { return "Defeat — see results" }
        return "Next Round  →"
    }

    // MARK: - Outcome (victory / defeat)

    private func outcomeView(victory: Bool) -> some View {
        VStack(spacing: 18) {
            Image(systemName: victory ? "crown.fill" : "shield.lefthalf.filled.slash")
                .font(.system(size: 56))
                .foregroundStyle(victory ? Color("Yellow") : Color("Red"))

            Text(victory ? "Victory!" : "Defeated")
                .font(.largeTitle.bold())

            if !outcomeMessage.isEmpty {
                Text(outcomeMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 10) {
                statRow(icon: "flame.fill", color: Color("Red"), label: "Boss", value: encounter?.bossName ?? "")
                statRow(icon: "questionmark.circle.fill", color: .blue, label: "Rounds", value: "\(encounter?.currentRound ?? 0)")
                statRow(icon: "checkmark.circle.fill", color: Color("Darkgreen"), label: "Correct", value: "\(correctCount)/\(totalAnswered)")
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                if !victory {
                    Button { restart(easierMode: true) } label: {
                        Label("Retry (Easier)", systemImage: "arrow.clockwise")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white)
                            .background(Color("Orange"), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { restart(easierMode: false) } label: {
                        Label("Battle Again", systemImage: "arrow.clockwise")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white)
                            .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

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

    // MARK: - Setup

    private func setupBattle() async {
        // Resolve topic from scope
        switch scope.kind {
        case .lesson(let lesson): topic = lesson.title.isEmpty ? "this lesson" : lesson.title
        case .module(let module, _): topic = module.title.isEmpty ? "this module" : module.title
        case .plan(let plan): topic = plan.name
        }

        // Generate boss intro (name + flavour). On failure, fall back to a generic boss.
        let (name, intro): (String, String)
        if let result = try? await modelService.generateBossIntro(topic: topic) {
            name = result.name.isEmpty ? "The \(topic) Boss" : result.name
            intro = result.intro.isEmpty ? "I am the master of \(topic). Defeat me if you can." : result.intro
        } else {
            name = "The \(topic) Boss"
            intro = "I am the master of \(topic). Defeat me if you can."
        }

        encounter = BossEncounter(topic: topic, bossName: name, bossIntro: intro)
        phase = .intro
    }

    // MARK: - Round flow

    private func loadRoundQuestion() async {
        guard let e = encounter else { return }
        await MainActor.run { isLoadingNext = true }
        defer { Task { @MainActor in isLoadingNext = false } }

        let ragScope: RAGService.Scope
        let topicHint: String
        switch scope.kind {
        case .lesson(let lesson):
            ragScope = .lesson(lesson.id); topicHint = lesson.title
        case .module(let module, _):
            ragScope = .module(module.id); topicHint = "\(module.title) \(module.summary)"
        case .plan(let plan):
            ragScope = .lessons(plan.lessonIDs); topicHint = plan.name
        }

        // One question per round, scaled to the round's difficulty.
        let questions = await coordinator.generateQuestions(
            for: ragScope,
            topicHint: topicHint,
            count: 1,
            difficulty: e.roundDifficulty,
            context: modelContext
        )
        await MainActor.run {
            currentQuestion = questions.first
            userAnswer = ""
        }
    }

    private func submitAnswer(_ question: Question) async {
        let answer = userAnswer
        await MainActor.run { isEvaluating = true }
        defer { Task { @MainActor in isEvaluating = false } }

        let feedback: Feedback
        do {
            feedback = try await modelService.evaluateAnswer(
                question: question,
                userAnswer: answer,
                difficulty: encounter?.roundDifficulty ?? .medium
            )
        } catch {
            feedback = Feedback(
                isCorrect: false,
                explanation: "Couldn't evaluate — try again.",
                encouragement: ""
            )
        }

        let correct = feedback.isCorrect
        let reaction = (try? await modelService.generateBossReaction(
            bossName: encounter?.bossName ?? "Boss",
            topic: topic,
            question: question.prompt,
            correctAnswer: question.expectedAnswer,
            wasCorrect: correct
        )) ?? (correct ? "Lucky shot…" : "You'll need to do better than that.")

        await MainActor.run {
            totalAnswered += 1
            lastFeedback = feedback
            lastReaction = reaction
            lastCorrect = correct

            guard var e = encounter else { return }
            if correct {
                e.currentBossHP = max(0, e.currentBossHP - 1)
                correctCount += 1
                triggerBossDamage()
            } else {
                e.userHP = max(0, e.userHP - 1)
                triggerHeartLoss()
            }
            encounter = e
            phase = .feedback
        }
    }

    private func advanceRound() async {
        guard var e = encounter else { return }

        if e.isBossDefeated {
            await finishBattle(victory: true)
            return
        }
        if e.isUserDefeated {
            await finishBattle(victory: false)
            return
        }

        e.currentRound += 1
        await MainActor.run {
            encounter = e
            currentQuestion = nil
            userAnswer = ""
            lastFeedback = nil
            lastReaction = ""
            phase = .playing
        }
        await loadRoundQuestion()
    }

    private func finishBattle(victory: Bool) async {
        let bossName = encounter?.bossName ?? "Boss"
        let message = (try? await modelService.generateBossOutcome(
            bossName: bossName,
            topic: topic,
            victory: victory
        )) ?? (victory
            ? "You mastered \(topic)! Well done."
            : "Don't worry — review the basics and come back stronger.")

        await MainActor.run {
            outcomeMessage = message
            phase = victory ? .victory : .defeat
        }
    }

    // MARK: - Animations

    private func triggerBossDamage() {
        damageFlash = true
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 8)) { bossShake = 14 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 8)) { bossShake = -14 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring()) { bossShake = 0 }
            damageFlash = false
        }
    }

    private func triggerHeartLoss() {
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 8)) { heartShake = 8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 8)) { heartShake = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring()) { heartShake = 0 }
        }
    }

    // MARK: - Restart

    private func restart(easierMode: Bool) {
        encounter = nil
        currentQuestion = nil
        userAnswer = ""
        lastFeedback = nil
        lastReaction = ""
        outcomeMessage = ""
        totalAnswered = 0
        correctCount = 0
        phase = .loading
        Task { await setupBattle() }
    }
}
