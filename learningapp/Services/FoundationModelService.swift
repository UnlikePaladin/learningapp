import Foundation
import FoundationModels

@Generable
struct TitleResult {
    @Guide(description: "A short, descriptive title for this study material (3-8 words)")
    var title: String
}

@Generable
struct GeneratedQuestion {
    @Guide(description: "A clear, concise question testing understanding of one concept")
    var prompt: String
    @Guide(description: "The expected answer, brief and focused")
    var expectedAnswer: String
    @Guide(description: "Difficulty from 1 (easy) to 5 (hard)")
    var difficulty: Int
}

@Generable
struct QuestionsResult {
    @Guide(description: "Array of active recall questions, each testing one concept")
    var questions: [GeneratedQuestion]
}

@Generable
struct FeedbackResult {
    @Guide(description: "Whether the answer demonstrates understanding of the concept")
    var isCorrect: Bool
    @Guide(description: "Brief explanation of why the answer is correct or what was missed")
    var explanation: String
    @Guide(description: "Genuine encouragement that celebrates effort and progress")
    var encouragement: String
}

@Generable
struct StudyPlanItemResult {
    @Guide(description: "The index of the material in the input list (0-based)")
    var materialIndex: Int
    @Guide(description: "Priority from 1 (highest) to 5 (lowest)")
    var priority: Int
    @Guide(description: "Brief reason why this material should be studied next")
    var reason: String
    @Guide(description: "Suggested study duration in minutes (5-25)")
    var suggestedDuration: Int
}

@Generable
struct StudyPlanResult {
    @Guide(description: "3-5 study plan items, ordered by priority")
    var items: [StudyPlanItemResult]
}

@Observable
final class FoundationModelService {
    private let session = LanguageModelSession()

    // MARK: - Title Generation

    /// Generate a short title from the first ~200 chars of material. Cheap call.
    func generateTitle(from text: String) async throws -> String {
        let snippet = String(text.prefix(300))
        let prompt = """
        You are an educational tutor. Generate a short descriptive title (3-8 words) \
        for this study material. Only output the title, nothing else.

        Material excerpt:
        \(snippet)
        """
        let response = try await session.respond(to: prompt, generating: TitleResult.self)
        return response.content.title
    }

    // MARK: - Question Generation (RAG-aware)

    /// Generate questions from RAG-retrieved context. Context is already token-budget limited.
    func generateQuestions(context: String, count: Int = 3) async throws -> [Question] {
        let prompt = """
        You are an educational tutor. Generate exactly \(count) active recall questions \
        based ONLY on the following study material. Do NOT add information not present below. \
        Each question should test understanding of one concept.

        Study material:
        \(context)
        """
        let response = try await session.respond(to: prompt, generating: QuestionsResult.self)
        return response.content.questions.map { q in
            Question(prompt: q.prompt, expectedAnswer: q.expectedAnswer, difficulty: q.difficulty)
        }
    }

    /// Generate adaptive questions using RAG context + performance history.
    func generateAdaptiveQuestions(context: String, performanceHistory: [SessionResult], count: Int = 3) async throws -> [Question] {
        let accuracy: Double = performanceHistory.isEmpty ? 0.5 :
            Double(performanceHistory.map(\.correctCount).reduce(0, +)) /
            Double(max(1, performanceHistory.map(\.questionsAnswered).reduce(0, +)))
        let difficulty = accuracy > 0.8 ? 4 : accuracy < 0.5 ? 2 : 3
        let style = accuracy > 0.8 ? "conceptual, application-based" :
                    accuracy < 0.5 ? "simple recall" : "mixed understanding"

        let prompt = """
        You are an educational tutor. Generate exactly \(count) \(style) questions \
        at difficulty \(difficulty)/5 based ONLY on the material below. Do NOT invent facts.

        Study material:
        \(context)
        """
        let response = try await session.respond(to: prompt, generating: QuestionsResult.self)
        return response.content.questions.map { q in
            Question(prompt: q.prompt, expectedAnswer: q.expectedAnswer, difficulty: difficulty)
        }
    }

    // MARK: - Answer Evaluation

    func evaluateAnswer(question: Question, userAnswer: String) async throws -> Feedback {
        let prompt = """
        You are a supportive tutor. Evaluate this answer. Be lenient — accept answers \
        that show understanding even if not word-for-word. Celebrate effort.

        Question: \(question.prompt)
        Expected: \(question.expectedAnswer)
        Student answered: \(userAnswer)
        """
        let response = try await session.respond(to: prompt, generating: FeedbackResult.self)
        let r = response.content
        return Feedback(isCorrect: r.isCorrect, explanation: r.explanation, encouragement: r.encouragement)
    }

    // MARK: - Study Plan

    func generateStudyPlan(materials: [StudyMaterial], sessions: [SessionResult]) async throws -> StudyPlan {
        let summaries = materials.enumerated().map { i, m in
            let related = sessions.filter { $0.materialID == m.id }
            let acc = related.isEmpty ? "not studied" :
                "\(Int(Double(related.map(\.correctCount).reduce(0, +)) / Double(max(1, related.map(\.questionsAnswered).reduce(0, +))) * 100))%"
            return "[\(i)] \"\(m.title.isEmpty ? String(m.rawText.prefix(40)) : m.title)\" — \(acc)"
        }.joined(separator: "\n")

        let prompt = """
        You are a study planner. Create a short plan (3-5 items). \
        Prioritize materials not studied or with low accuracy.

        Materials:
        \(summaries)
        """
        let response = try await session.respond(to: prompt, generating: StudyPlanResult.self)
        let items = response.content.items.compactMap { item -> StudyPlanItem? in
            guard item.materialIndex >= 0, item.materialIndex < materials.count else { return nil }
            let m = materials[item.materialIndex]
            let title = m.title.isEmpty ? String(m.rawText.prefix(50)) : m.title
            return StudyPlanItem(materialID: m.id, materialTitle: title, priority: item.priority, reason: item.reason, suggestedDuration: item.suggestedDuration)
        }
        return StudyPlan(items: items)
    }
}
