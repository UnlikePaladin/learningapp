import SwiftUI
import SwiftData

struct StudySessionView: View {
    var material: StudyMaterial?

    enum SessionState {
        case config
        case idle
        case loading
        case quizzing([Question])
        case complete(correct: Int, total: Int)
    }

    @Environment(\.modelContext) private var modelContext
    @State private var state: SessionState = .config
    @State private var coordinator = StudyCoordinator()
    @State private var errorMessage: String?
    @State private var chosenDifficulty: DifficultyLevel = .medium
    @State private var sessionStart = Date()

    private var stateID: String {
        switch state {
        case .config: "config"
        case .idle: "idle"
        case .loading: "loading"
        case .quizzing: "quizzing"
        case .complete: "complete"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .config:
                    if let material {
                        QuizConfigView(material: material) { count, difficulty in
                            startQuiz(count: count, difficulty: difficulty)
                        }
                    } else {
                        idleView
                    }
                case .idle:
                    idleView
                case .loading:
                    loadingView
                case .quizzing(let questions):
                    QuizCardView(questions: questions, aiService: FoundationModelService(), difficulty: chosenDifficulty) { results in
                        let correct = results.filter { $0 }.count
                        let total = results.count
                        // Save session result for progress tracking
                        if let materialID = material?.id {
                            let session = SessionResult(
                                questionsAnswered: total,
                                correctCount: correct,
                                duration: Date().timeIntervalSince(sessionStart),
                                materialID: materialID
                            )
                            coordinator.completeSession(result: session, context: modelContext)
                        }
                        withAnimation(.easeInOut) {
                            state = .complete(correct: correct, total: total)
                        }
                    }
                case .complete(let correct, let total):
                    completeView(correct: correct, total: total)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: stateID)
            .navigationTitle("Study Session")
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            FocusTimerView()
            ContentUnavailableView("No material selected", systemImage: "doc.text", description: Text("Choose material from the Home tab to begin."))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating questions...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func completeView(correct: Int, total: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Session Complete!")
                .font(.largeTitle.bold())

            Text("\(correct)/\(total) correct")
                .font(.title)
                .foregroundStyle(correct == total ? .green : .orange)

            Text(correct == total ? "Perfect score!" : "Great effort! Every question makes you stronger.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Study Again") {
                withAnimation { state = .config }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func startQuiz(count: Int, difficulty: DifficultyLevel) {
        guard let material else { return }
        chosenDifficulty = difficulty
        sessionStart = Date()
        withAnimation { state = .loading }
        Task {
            await coordinator.generateQuiz(for: material, count: count, difficulty: difficulty, context: modelContext)
            if coordinator.currentQuestions.isEmpty {
                errorMessage = "Could not generate questions. Try adding more material."
                withAnimation { state = .config }
            } else {
                withAnimation { state = .quizzing(coordinator.currentQuestions) }
            }
        }
    }
}

#Preview {
    StudySessionView()
}
