import SwiftUI
import SwiftData

struct StudySessionView: View {
    let scope: QuizScope

    enum SessionState {
        case config
        case loading
        case quizzing([Question])
        case complete(correct: Int, total: Int)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var state: SessionState = .config
    @State private var coordinator = StudyCoordinator()
    @State private var errorMessage: String?
    @State private var chosenDifficulty: DifficultyLevel = .medium
    @State private var sessionStart = Date()

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .config:
                    QuizConfigView(title: scope.title) { count, difficulty in
                        startQuiz(count: count, difficulty: difficulty)
                    }
                case .loading:
                    loadingView
                case .quizzing(let questions):
                    QuizCardView(questions: questions, aiService: FoundationModelService(), difficulty: chosenDifficulty) { results in
                        let correct = results.filter { $0 }.count
                        let total = results.count
                        saveSession(correct: correct, total: total)
                        withAnimation(.easeInOut) {
                            state = .complete(correct: correct, total: total)
                        }
                    }
                case .complete(let correct, let total):
                    completeView(correct: correct, total: total)
                }
            }
            .navigationTitle("Study Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
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
            HStack(spacing: 12) {
                Button("Study Again") {
                    withAnimation { state = .config }
                }
                .buttonStyle(.bordered)
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func startQuiz(count: Int, difficulty: DifficultyLevel) {
        chosenDifficulty = difficulty
        sessionStart = Date()
        withAnimation { state = .loading }
        Task {
            let ragScope: RAGService.Scope
            let topicHint: String
            switch scope.kind {
            case .lesson(let lesson):
                ragScope = .lesson(lesson.id)
                topicHint = lesson.title
            case .module(let module, let lessonID):
                ragScope = .module(module.id)
                topicHint = "\(module.title) \(module.summary)"
                _ = lessonID
            case .plan(let plan):
                ragScope = .lessons(plan.lessonIDs)
                topicHint = plan.name
            }

            let questions = await coordinator.generateQuestions(
                for: ragScope,
                topicHint: topicHint,
                count: count,
                difficulty: difficulty,
                context: modelContext
            )
            if questions.isEmpty {
                errorMessage = "Could not generate questions. Try adding more material."
                withAnimation { state = .config }
            } else {
                withAnimation { state = .quizzing(questions) }
            }
        }
    }

    private func saveSession(correct: Int, total: Int) {
        let lessonID: UUID
        var moduleID: UUID? = nil
        var planID: UUID? = nil

        switch scope.kind {
        case .lesson(let lesson):
            lessonID = lesson.id
        case .module(let module, let lid):
            lessonID = lid
            moduleID = module.id
        case .plan(let plan):
            planID = plan.id
            // Use first lesson in plan for the lessonID — we still need one for grouping
            lessonID = plan.lessonIDs.first ?? UUID()
        }

        let session = SessionResult(
            lessonID: lessonID,
            moduleID: moduleID,
            planID: planID,
            questionsAnswered: total,
            correctCount: correct,
            duration: Date().timeIntervalSince(sessionStart)
        )
        coordinator.completeSession(result: session, context: modelContext)
    }
}
