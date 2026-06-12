import SwiftUI

struct StudySessionView: View {
    var material: StudyMaterial?

    enum SessionState {
        case idle
        case loading
        case reviewing([Chunk])
        case quizzing([Question])
        case complete(correct: Int, total: Int)
    }

    @State private var state: SessionState = .idle
    @State private var aiService = FoundationModelService()
    @State private var errorMessage: String?

    private var stateID: String {
        switch state {
        case .idle: "idle"
        case .loading: "loading"
        case .reviewing: "reviewing"
        case .quizzing: "quizzing"
        case .complete: "complete"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .idle:
                    idleView
                case .loading:
                    loadingView
                case .reviewing(let chunks):
                    reviewingView(chunks)
                case .quizzing(let questions):
                    QuizCardView(questions: questions, aiService: aiService) { results in
                        let correct = results.filter { $0 }.count
                        withAnimation(.easeInOut) {
                            state = .complete(correct: correct, total: results.count)
                        }
                    }
                case .complete(let correct, let total):
                    completeView(correct: correct, total: total)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: stateID)
            .padding()
            .navigationTitle("Study Session")
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear { startIfNeeded() }
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
            Text("Breaking down your material...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func reviewingView(_ chunks: [Chunk]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                FocusTimerView()
                ForEach(chunks) { chunk in
                    ChunkView(chunk: chunk) {
                        startQuiz(for: chunk)
                    }
                }
            }
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

            Text(correct == total ? "Perfect score! You're doing amazing!" : "Great effort! Every question makes you stronger.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Study Again") {
                startIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func startIfNeeded() {
        guard let material else { return }
        withAnimation { state = .loading }
        Task {
            do {
                let chunks = try await aiService.chunkText(material.rawText)
                withAnimation { state = .reviewing(chunks) }
            } catch {
                errorMessage = error.localizedDescription
                withAnimation { state = .idle }
            }
        }
    }

    private func startQuiz(for chunk: Chunk) {
        withAnimation { state = .loading }
        Task {
            do {
                let questions = try await aiService.generateQuestions(from: chunk)
                withAnimation { state = .quizzing(questions) }
            } catch {
                errorMessage = error.localizedDescription
                withAnimation { state = .reviewing([chunk]) }
            }
        }
    }
}

#Preview {
    StudySessionView()
}
