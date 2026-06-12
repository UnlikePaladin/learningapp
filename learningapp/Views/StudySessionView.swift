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
                    QuizCardView(
                        questions: questions,
                        aiService: FoundationModelService(),
                        difficulty: chosenDifficulty
                    ) { results in
                        let correct = results.filter { $0 }.count
                        let total = results.count
                        saveSession(correct: correct, total: total)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            state = .complete(correct: correct, total: total)
                        }
                    }
                case .complete(let correct, let total):
                    SessionCompleteView(
                        correct: correct,
                        total: total,
                        onDone: { dismiss() },
                        onStudyAgain: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                state = .config
                            }
                        }
                    )
                }
            }
            .navigationTitle("Study Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color("Lightgreen").opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38))
                    .foregroundStyle(Color("Darkgreen"))
                    .symbolEffect(.pulse)
            }
            Text("Generating questions...")
                .font(.headline)
            Text("This takes a moment...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startQuiz(count: Int, difficulty: DifficultyLevel) {
        chosenDifficulty = difficulty
        sessionStart = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { state = .loading }
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    state = .quizzing(questions)
                }
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

// MARK: - Complete Screen

private struct SessionCompleteView: View {
    let correct: Int
    let total: Int
    let onDone: () -> Void
    let onStudyAgain: () -> Void

    @State private var ringProgress: Double = 0

    private var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
    private var isGreat: Bool { accuracy >= 0.8 }
    private var xpEarned: Int { correct * 10 + (total - correct) * 5 }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 14)
                    .frame(width: 150, height: 150)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        isGreat ? Color("Lightgreen") : Color("Orange"),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.9, dampingFraction: 0.7), value: ringProgress)

                VStack(spacing: 2) {
                    Text("\(correct)/\(total)")
                        .font(.title.bold())
                    Text("correct")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    ringProgress = accuracy
                }
            }

            VStack(spacing: 8) {
                Text(isGreat ? "Excellent work!" : "Keep going!")
                    .font(.largeTitle.bold())
                Text(isGreat ? "You're mastering this material!" : "Every attempt builds your knowledge.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color("Yellow"))
                Text("+\(xpEarned) XP earned")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color("Darkgreen"))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color("Lightgreen").opacity(0.15), in: Capsule())

            Spacer()

            VStack(spacing: 10) {
                Button(action: onDone) {
                    Text("Done")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button(action: onStudyAgain) {
                    Text("Study Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(Color("Darkgreen"))
                        .background(Color("Darkgreen").opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding()
    }
}
