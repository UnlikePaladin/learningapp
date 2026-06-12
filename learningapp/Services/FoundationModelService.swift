import Foundation
import FoundationModels

@Generable
struct ChunkedLesson {
    @Guide(description: "A short title for this micro-lesson chunk")
    var title: String
    @Guide(description: "The original text segment this chunk covers")
    var originalText: String
    @Guide(description: "A 1-2 sentence summary of the chunk for quick review")
    var summary: String
    @Guide(description: "3-5 key points extracted from the chunk, each brief and actionable")
    var keyPoints: [String]
}

@Generable
struct ChunkingResult {
    @Guide(description: "Array of micro-lesson chunks broken from the source text, each short enough for a learner with ADHD to digest in 2-3 minutes")
    var chunks: [ChunkedLesson]
}

@Generable
struct SummaryResult {
    @Guide(description: "A concise 1-2 sentence summary")
    var summary: String
    @Guide(description: "3-5 bullet-point key takeaways, short and memorable")
    var keyPoints: [String]
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

    /// Strips markdown artifacts, image credits, footnotes, and excess whitespace
    /// that can trigger Apple's on-device safety filter false positives.
    private func sanitizeInput(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Remove image credits, footnote markers, and markdown image syntax
                if trimmed.hasPrefix("_Image") || trimmed.hasPrefix("\\[^") || trimmed.hasPrefix("![") { return false }
                if trimmed.hasPrefix("*Image") || trimmed.hasPrefix("[^") { return false }
                return true
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Splits text into segments under the character limit to avoid safety filter
    /// triggers on very long inputs.
    private func splitIntoSegments(_ text: String, maxLength: Int = 2000) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n")
        var segments: [String] = []
        var current = ""
        for para in paragraphs {
            if current.count + para.count + 2 > maxLength && !current.isEmpty {
                segments.append(current)
                current = para
            } else {
                current += current.isEmpty ? para : "\n\n" + para
            }
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    func chunkText(_ text: String) async throws -> [Chunk] {
        let cleaned = sanitizeInput(text)
        let segments = splitIntoSegments(cleaned)

        var allChunks: [Chunk] = []
        var order = 0

        for segment in segments {
            let prompt = """
            You are an educational tutor. The following is academic study material from a textbook. \
            Break it into micro-lesson chunks. Each chunk should be short enough to read in 2-3 minutes. \
            For each chunk provide a summary and key points that are easy to remember.

            Study material:
            \(segment)
            """

            let response = try await session.respond(to: prompt, generating: ChunkingResult.self)
            for lesson in response.content.chunks {
                allChunks.append(Chunk(
                    summary: lesson.summary,
                    keyPoints: lesson.keyPoints,
                    originalText: lesson.originalText,
                    order: order
                ))
                order += 1
            }
        }
        return allChunks
    }

    func summarize(_ text: String) async throws -> (summary: String, keyPoints: [String]) {
        let cleaned = sanitizeInput(text)
        let prompt = """
        You are an educational tutor. Summarize the following academic study material \
        into a brief summary and key points. Keep it concise and memorable.

        Study material:
        \(String(cleaned.prefix(3000)))
        """

        let response = try await session.respond(to: prompt, generating: SummaryResult.self)
        let result = response.content
        return (result.summary, result.keyPoints)
    }

    func generateQuestions(from chunk: Chunk, count: Int = 3) async throws -> [Question] {
        let cleaned = sanitizeInput(chunk.originalText)
        let prompt = """
        You are an educational tutor. Generate exactly \(count) active recall \
        questions from this academic study material. Each question should test understanding, not memorization. \
        Keep questions clear, concise, and focused on one concept at a time.

        Study material:
        \(String(cleaned.prefix(2000)))

        Key points:
        \(chunk.keyPoints.joined(separator: "\n"))
        """

        let response = try await session.respond(to: prompt, generating: QuestionsResult.self)
        return response.content.questions.map { q in
            Question(prompt: q.prompt, expectedAnswer: q.expectedAnswer, difficulty: q.difficulty)
        }
    }

    func generateStudyPlan(materials: [StudyMaterial], recentSessions: [SessionResult]) async throws -> StudyPlan {
        let materialSummary = materials.prefix(10).map { $0.rawText.prefix(100) }.joined(separator: "\n")
        let sessionSummary = recentSessions.prefix(5).map { "Score: \($0.correctCount)/\($0.questionsAnswered)" }.joined(separator: ", ")
        let prompt = """
        You are a study planner for a learner with ADHD. Create a 7-day study plan. \
        Schedule short sessions (15-30 min) spread across days. Consider recent performance.

        Materials available: \(materialSummary)
        Recent scores: \(sessionSummary)
        """
        let response = try await session.respond(to: prompt, generating: StudyPlanResult.self)
        let items = response.content.items.compactMap { item -> StudyPlanItem? in
            guard item.materialIndex >= 0, item.materialIndex < materials.count else { return nil }
            let mat = materials[item.materialIndex]
            return StudyPlanItem(materialID: mat.id, materialTitle: String(mat.rawText.prefix(50)), priority: item.priority, reason: item.reason, suggestedDuration: item.suggestedDuration)
        }
        return StudyPlan(items: items)
    }

    func generateStudyPlan(materials: [StudyMaterial]) async throws -> StudyPlan {
        let descriptions = materials.enumerated().map { "\($0.offset): \($0.element.rawText.prefix(200))" }.joined(separator: "\n")
        let prompt = """
        You are a study assistant for a learner with ADHD. Given these study materials, \
        create a prioritized study plan. Consider recency and variety.

        Materials:
        \(descriptions)
        """

        let response = try await session.respond(to: prompt, generating: StudyPlanResult.self)
        let items = response.content.items.compactMap { item -> StudyPlanItem? in
            guard item.materialIndex >= 0, item.materialIndex < materials.count else { return nil }
            let mat = materials[item.materialIndex]
            return StudyPlanItem(materialID: mat.id, materialTitle: String(mat.rawText.prefix(50)), priority: item.priority, reason: item.reason, suggestedDuration: item.suggestedDuration)
        }
        return StudyPlan(items: items)
    }

    func evaluateAnswer(question: Question, userAnswer: String) async throws -> Feedback {
        let prompt = """
        You are a supportive study assistant for a learner with ADHD. Evaluate this answer. \
        Be lenient — accept answers that demonstrate understanding even if not word-for-word. \
        Celebrate effort and progress genuinely.

        Question: \(question.prompt)
        Expected answer: \(question.expectedAnswer)
        Student's answer: \(userAnswer)
        """

        let response = try await session.respond(to: prompt, generating: FeedbackResult.self)
        let r = response.content
        return Feedback(isCorrect: r.isCorrect, explanation: r.explanation, encouragement: r.encouragement)
    }

    func generateAdaptiveQuestions(from chunk: Chunk, performanceHistory: [SessionResult], count: Int = 3) async throws -> [Question] {
        let accuracy: Double = performanceHistory.isEmpty ? 0.5 : Double(performanceHistory.map(\.correctCount).reduce(0, +)) / Double(max(1, performanceHistory.map(\.questionsAnswered).reduce(0, +)))
        let difficulty = accuracy > 0.8 ? 4 : accuracy < 0.5 ? 2 : 3
        let style = accuracy > 0.8 ? "conceptual, application-based" : accuracy < 0.5 ? "simple recall, fill-in-the-blank" : "mixed understanding"
        let cleaned = sanitizeInput(chunk.originalText)

        let prompt = """
        You are an educational tutor. Generate exactly \(count) \(style) questions \
        at difficulty level \(difficulty)/5 from this academic study material. Keep questions clear and focused.

        Study material:
        \(String(cleaned.prefix(2000)))

        Key points:
        \(chunk.keyPoints.joined(separator: "\n"))
        """

        let response = try await session.respond(to: prompt, generating: QuestionsResult.self)
        return response.content.questions.map { q in
            Question(prompt: q.prompt, expectedAnswer: q.expectedAnswer, difficulty: difficulty)
        }
    }

    func generateStudyPlan(materials: [StudyMaterial], sessions: [SessionResult]) async throws -> StudyPlan {
        let materialSummaries = materials.enumerated().map { i, m in
            let related = sessions.filter { $0.materialID == m.id }
            let accuracy = related.isEmpty ? "never studied" : "\(Int(Double(related.map(\.correctCount).reduce(0, +)) / Double(max(1, related.map(\.questionsAnswered).reduce(0, +))) * 100))% accuracy"
            let lastStudied = related.max(by: { $0.date < $1.date })?.date
            let recency = lastStudied.map { "\(Int(Date().timeIntervalSince($0) / 86400)) days ago" } ?? "never"
            return "[\(i)] \"\(m.rawText.prefix(80))...\" — \(accuracy), last studied: \(recency)"
        }.joined(separator: "\n")

        let prompt = """
        You are a study planner for a learner with ADHD. Create a short study plan (3-5 items max). \
        Prioritize materials that haven't been studied, were studied long ago, or have low accuracy. \
        Keep it manageable and not overwhelming.

        Materials:
        \(materialSummaries)
        """

        let response = try await session.respond(to: prompt, generating: StudyPlanResult.self)
        let items = response.content.items.compactMap { item -> StudyPlanItem? in
            guard item.materialIndex >= 0, item.materialIndex < materials.count else { return nil }
            let m = materials[item.materialIndex]
            return StudyPlanItem(materialID: m.id, materialTitle: String(m.rawText.prefix(50)), priority: item.priority, reason: item.reason, suggestedDuration: item.suggestedDuration)
        }
        return StudyPlan(items: items)
    }

    func generateBonusQuestion(from chunks: [Chunk], style: QuestionStyle) async throws -> Question {
        let context = sanitizeInput(chunks.map(\.originalText).joined(separator: "\n\n"))
        let styleInstruction: String
        switch style {
        case .eli5: styleInstruction = "Explain-like-I'm-5: ask a question that requires simplifying a concept for a child"
        case .analogy: styleInstruction = "Ask a question that requires creating an analogy or metaphor for a concept"
        case .realWorld: styleInstruction = "Ask how a concept applies to a real-world everyday situation"
        case .whatIf: styleInstruction = "Ask a creative what-if scenario that explores the concept from a new angle"
        }

        let prompt = """
        You are an educational tutor. Generate one engaging \
        bonus question using this style: \(styleInstruction). Make it interesting and memorable.

        Academic study material:
        \(String(context.prefix(3000)))
        """

        let response = try await session.respond(to: prompt, generating: GeneratedQuestion.self)
        let q = response.content
        return Question(prompt: q.prompt, expectedAnswer: q.expectedAnswer, difficulty: q.difficulty)
    }
}
