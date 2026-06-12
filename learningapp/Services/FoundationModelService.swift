import Foundation
import FoundationModels

@Generable
struct TitleResult {
    @Guide(description: "A short, descriptive title for this study material (3-8 words)")
    var title: String
}

@Generable
struct ModuleTitleResult {
    @Guide(description: "A short module title (2-5 words) describing the topic of this group of content")
    var title: String
    @Guide(description: "A one-sentence summary of the module")
    var summary: String
}

@Generable
struct StudyCardResult {
    @Guide(description: "A short concept title (3-6 words) for this idea")
    var title: String
    @Guide(description: "A clear, ADHD-friendly explanation of this single concept (2-3 short sentences). Use simple language. Do not just paraphrase — actually explain the concept.")
    var explanation: String
}

@Generable
struct StudyCardsResult {
    @Guide(description: "Array of 3-7 study cards, each covering ONE distinct idea or concept from the content. Each card should stand alone as a single learnable unit.")
    var cards: [StudyCardResult]
}

@Generable
struct ContentRelevance {
    @Guide(description: "true if the text is meaningful educational lesson content (explanations, definitions, examples, concepts). false if it is boilerplate like branding, copyright notices, page headers/footers, image captions, navigation, table of contents, or legal disclaimers.")
    var isLessonContent: Bool
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
    @Guide(description: "Whether the answer demonstrates understanding")
    var isCorrect: Bool
    @Guide(description: "Brief explanation of what the complete answer should include")
    var explanation: String
    @Guide(description: "Genuine encouragement that celebrates effort")
    var encouragement: String
}

@Generable
struct SuggestedPlanItemResult {
    @Guide(description: "The index of the lesson in the input list (0-based)")
    var lessonIndex: Int
    @Guide(description: "Priority from 1 (highest) to 5 (lowest)")
    var priority: Int
    @Guide(description: "Brief reason why this lesson should be studied next")
    var reason: String
    @Guide(description: "Suggested study duration in minutes (5-25)")
    var suggestedDuration: Int
}

@Generable
struct SuggestedPlanResult {
    @Guide(description: "3-5 suggested plan items, ordered by priority")
    var items: [SuggestedPlanItemResult]
}

@Observable
final class FoundationModelService {
    private let session = LanguageModelSession()

    // MARK: - Content Filtering

    func isLessonContent(_ text: String) async -> Bool {
        let prompt = """
        Determine if the following text is meaningful educational lesson content.

        Answer FALSE for: branding, company names, copyright notices, page numbers,
        headers, footers, image captions, navigation, table of contents, URLs, contact info.

        Answer TRUE for: explanations of concepts, definitions, examples,
        lesson narrative, educational facts.

        Text:
        \(text)
        """
        do {
            let response = try await session.respond(to: prompt, generating: ContentRelevance.self)
            return response.content.isLessonContent
        } catch {
            return true // fail open
        }
    }

    // MARK: - Title Generation

    func generateLessonTitle(representativeContent: String, keyTerms: [String]) async throws -> String {
        let termsLine = keyTerms.isEmpty ? "" : "Most frequent topic words: \(keyTerms.joined(separator: ", "))\n\n"
        let prompt = """
        You are creating a short topic title for a lesson. Based on the most representative \
        content below and the key terms, output a short noun phrase naming the main topic.

        Rules:
        - 2 to 6 words
        - Title Case (e.g., "The Water Cycle", "Cell Biology")
        - Just the subject — no colons, no "Key Points", no "Summary", no "Lesson on..."
        - Do NOT copy section headers
        - Do NOT include quotes or trailing punctuation

        Examples: "The Water Cycle", "Mitochondria and Chloroplasts", "Newton's Laws of Motion"

        \(termsLine)Most representative content:
        \(representativeContent)
        """
        let response = try await session.respond(to: prompt, generating: TitleResult.self)
        return sanitizeTitle(response.content.title)
    }

    func generateModuleTitle(content: String, keyTerms: [String]) async throws -> (title: String, summary: String) {
        let termsLine = keyTerms.isEmpty ? "" : "Topic words in this module: \(keyTerms.joined(separator: ", "))\n\n"
        let prompt = """
        You are creating a module title for a section of a lesson. Output a short topic phrase \
        (2-5 words) that names what this module covers, plus a one-sentence summary.

        Rules:
        - Title in Title Case, 2-5 words
        - No colons, no "Key Points", no quotes
        - Summary should be one clear sentence

        \(termsLine)Module content:
        \(content)
        """
        let response = try await session.respond(to: prompt, generating: ModuleTitleResult.self)
        return (sanitizeTitle(response.content.title), response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Generate flashcard-style study cards from module content. Called lazily on first view.
    /// Each card covers one discrete concept for ADHD-friendly carousel study.
    func generateStudyCards(content: String) async throws -> [(title: String, explanation: String)] {
        let trimmed = String(content.prefix(2500))
        let prompt = """
        You are a tutor creating flashcards for a student with ADHD. Read the content below and \
        produce 3-7 study cards. Each card must cover ONE distinct concept from the material — \
        ideas should not overlap between cards.

        For each card:
        - Title: 3-6 words naming the concept
        - Explanation: 2-3 short sentences in clear, simple language

        Do NOT copy or paraphrase the source. Actually EXPLAIN each concept in your own words, \
        like you're teaching it to someone new. Use examples or analogies if helpful.

        Content:
        \(trimmed)
        """
        let response = try await session.respond(to: prompt, generating: StudyCardsResult.self)
        return response.content.cards.map { card in
            (
                title: card.title.trimmingCharacters(in: .whitespacesAndNewlines),
                explanation: card.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func sanitizeTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: ".:,;"))
        let badPrefixes = ["lesson on ", "lesson: ", "title: ", "topic: ", "subject: ", "module: ", "key points", "summary of "]
        for prefix in badPrefixes {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
            }
        }
        if title.count > 60 {
            let truncated = String(title.prefix(60))
            if let lastSpace = truncated.lastIndex(of: " ") {
                title = String(truncated[..<lastSpace])
            } else {
                title = truncated
            }
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Question Generation (RAG-aware)

    func generateQuestions(context: String, count: Int = 3, difficulty: DifficultyLevel = .medium) async throws -> [Question] {
        let prompt = """
        You are an educational tutor. Generate exactly \(count) active recall questions \
        based ONLY on the following study material. Do NOT add information not present below. \
        Each question should test \(difficulty.systemPrompt). \
        Keep questions clear, concise, and focused on one concept at a time.

        Study material:
        \(context)
        """
        let response = try await session.respond(to: prompt, generating: QuestionsResult.self)
        return response.content.questions.map { q in
            Question(prompt: q.prompt, expectedAnswer: q.expectedAnswer, difficulty: q.difficulty)
        }
    }

    // MARK: - Answer Evaluation

    func evaluateAnswer(question: Question, userAnswer: String, difficulty: DifficultyLevel = .medium) async throws -> Feedback {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let nonAnswers: Set<String> = ["yes", "no", "yeah", "nah", "sure", "ok", "okay", "idk", "maybe", "true", "false", "y", "n"]
        if nonAnswers.contains(trimmed) || trimmed.count < 3 {
            return Feedback(
                isCorrect: false,
                explanation: "The expected answer is: \(question.expectedAnswer)",
                encouragement: "Give it another shot — try explaining in your own words!"
            )
        }

        let leniency: String
        switch difficulty {
        case .easy:
            leniency = "Leniency: HIGH. Accept answers that capture the main idea even if they miss details or use informal language. Only mark wrong if the answer shows no understanding or is completely off-topic."
        case .medium:
            leniency = "Leniency: MODERATE. Accept answers that demonstrate understanding of the key concept even if not perfectly worded. Mark wrong if major parts are missing."
        case .hard:
            leniency = "Leniency: LOW. Require the answer to address most key points. Mark wrong if important details are missing or the answer is vague."
        }

        let prompt = """
        You are a tutor evaluating a student's answer.

        \(leniency)

        In the explanation, briefly state what a complete answer would include.
        Keep encouragement genuine and brief.

        Question: \(question.prompt)
        Expected answer: \(question.expectedAnswer)
        Student's answer: \(userAnswer)
        """
        let response = try await session.respond(to: prompt, generating: FeedbackResult.self)
        let r = response.content
        return Feedback(isCorrect: r.isCorrect, explanation: r.explanation, encouragement: r.encouragement)
    }

    // MARK: - Suggested Study Plan (AI suggestion based on history)

    func generateSuggestedPlan(lessons: [Lesson], sessions: [SessionResult]) async throws -> SuggestedStudyPlan {
        let summaries = lessons.enumerated().map { i, lesson in
            let related = sessions.filter { $0.lessonID == lesson.id }
            let acc = related.isEmpty ? "not studied" :
                "\(Int(Double(related.map(\.correctCount).reduce(0, +)) / Double(max(1, related.map(\.questionsAnswered).reduce(0, +))) * 100))%"
            return "[\(i)] \"\(lesson.title.isEmpty ? "Untitled" : lesson.title)\" — \(acc)"
        }.joined(separator: "\n")

        let prompt = """
        You are a study planner. Suggest 3-5 lessons to study next.
        Prioritize lessons not studied or with low accuracy.

        Lessons:
        \(summaries)
        """
        let response = try await session.respond(to: prompt, generating: SuggestedPlanResult.self)
        let items = response.content.items.compactMap { item -> SuggestedPlanItem? in
            guard item.lessonIndex >= 0, item.lessonIndex < lessons.count else { return nil }
            let l = lessons[item.lessonIndex]
            return SuggestedPlanItem(
                lessonID: l.id,
                lessonTitle: l.title.isEmpty ? "Untitled" : l.title,
                priority: item.priority,
                reason: item.reason,
                suggestedDuration: item.suggestedDuration
            )
        }
        return SuggestedStudyPlan(items: items)
    }
}
