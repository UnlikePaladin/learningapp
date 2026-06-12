import Foundation
import FoundationModels

@Generable
struct TitleResult {
    @Guide(description: "A short, descriptive title (3-8 words) in Title Case. No colons, no quotes, no trailing punctuation.")
    var title: String
}

@Generable
struct ModuleTitleResult {
    @Guide(description: "A short title (2-5 words) in Title Case. No colons, no 'Key Points', no quotes.")
    var title: String
    @Guide(description: "One specific sentence describing what the student will learn. Start with a verb (Explains, Covers, Introduces, Describes). Do NOT restate the title or use the words 'module' or 'section'.")
    var summary: String
}

@Generable
struct SummaryOnlyResult {
    @Guide(description: "One specific sentence describing what a student will learn. Start with a verb. Be specific about actual concepts.")
    var summary: String
}

@Generable
struct StudyCardResult {
    @Guide(description: "A short concept title (3-6 words).")
    var title: String
    @Guide(description: "A clear, ADHD-friendly explanation of this single concept (2-3 short sentences). Simple language. Actually explain — don't paraphrase the source.")
    var explanation: String
}

@Generable
struct StudyCardsResult {
    @Guide(description: "Array of 3-7 cards, each covering ONE distinct idea. Cards should not overlap.")
    var cards: [StudyCardResult]
}

@Generable
struct ContentRelevance {
    @Guide(description: "true if the text is meaningful educational lesson content (explanations, definitions, examples). false if it is boilerplate (branding, copyright, headers, footers, image captions, navigation, contact info).")
    var isLessonContent: Bool
}

@Generable
struct ConceptListResult {
    @Guide(description: "Array of distinct concept titles from the content. Each title is 2-5 words. Aim for the count the user asks for unless the content genuinely has fewer distinct ideas.")
    var concepts: [String]
}

@Generable
struct GeneratedQuestion {
    @Guide(description: "A clear, concise question testing understanding of one concept.")
    var prompt: String
    @Guide(description: "The expected answer, brief and focused.")
    var expectedAnswer: String
    @Guide(description: "Difficulty from 1 (easy) to 5 (hard).")
    var difficulty: Int
}

@Generable
struct FeedbackResult {
    @Guide(description: "Whether the answer demonstrates understanding.")
    var isCorrect: Bool
    @Guide(description: "Brief explanation of what a complete answer should include.")
    var explanation: String
    @Guide(description: "Genuine, brief encouragement that celebrates effort.")
    var encouragement: String
}

@Generable
struct SuggestedPlanItemResult {
    @Guide(description: "0-based index of the lesson in the input list.")
    var lessonIndex: Int
    @Guide(description: "Priority from 1 (highest) to 5 (lowest).")
    var priority: Int
    @Guide(description: "Brief reason this lesson should be studied next.")
    var reason: String
    @Guide(description: "Suggested study duration in minutes (5-25).")
    var suggestedDuration: Int
}

@Generable
struct SuggestedPlanResult {
    @Guide(description: "3-5 plan items, ordered by priority.")
    var items: [SuggestedPlanItemResult]
}

@Observable
final class FoundationModelService {

    // MARK: - Availability

    /// Returns true when the on-device model is downloaded and Apple Intelligence is enabled.
    /// Call this before any AI feature so we can show a graceful unavailable state.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var unavailabilityReason: String? {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            switch reason {
            case .deviceNotEligible:
                return "This device doesn't support Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is turned off. Enable it in Settings."
            case .modelNotReady:
                return "The language model is still downloading. Try again shortly."
            @unknown default:
                return "Apple Intelligence is unavailable on this device."
            }
        }
        return nil
    }

    // MARK: - Generation options for different tasks

    /// Deterministic, low-temperature options for classification/title tasks where we want
    /// stable, predictable output. `greedy` sampling avoids any randomness.
    private let deterministicOptions = GenerationOptions(sampling: .greedy, temperature: 0.0)

    /// Slightly creative options for content like card explanations and question writing,
    /// where some variety helps quality.
    private let creativeOptions = GenerationOptions(temperature: 0.5)

    // MARK: - Session builders with task-specific Instructions

    /// Session for content generation: titles, summaries, cards, explanations.
    /// No tools — these are pure text-shaping tasks.
    private func makeContentSession() -> LanguageModelSession {
        LanguageModelSession {
            "You are a clear, patient educational tutor for learners with ADHD."
            "Always ground your output strictly in the material the user provides. Never invent facts that aren't in the source."
            "Use simple language and short sentences. Output exactly what the requested schema asks for — no extra commentary, prefaces, or sign-offs."
        }
    }

    /// Session for content classification — uses the specialized .contentTagging model
    /// which Apple has tuned for topic detection, entity extraction, and tag-style outputs.
    /// Better fit than the general model for binary lesson-content vs boilerplate decisions
    /// and for concept extraction (which is essentially tagging).
    private func makeClassifierSession() -> LanguageModelSession {
        LanguageModelSession(model: SystemLanguageModel(useCase: .contentTagging)) {
            "Classify or tag the input. Return only the requested fields."
            "Be conservative: when uncertain, treat input as content (true)."
        }
    }

    /// Session for quiz generation and answer evaluation. NO tools attached.
    private func makeQuizSession() -> LanguageModelSession {
        LanguageModelSession {
            "You are a precise educational tutor for an ADHD-focused study app."
            "All questions and evaluations must be grounded ONLY in the material the user provides — never add outside information."
            "Output exactly what the requested schema asks for. Do not add commentary."
        }
    }

    // MARK: - Content Filtering

    func isLessonContent(_ text: String) async -> Bool {
        let prompt = """
        Is this text meaningful educational lesson content?

        FALSE for: branding, copyright notices, page numbers, headers, footers, image captions, navigation, table of contents, URLs, contact info.
        TRUE for: explanations of concepts, definitions, examples, lesson narrative, educational facts.

        Text:
        \(text)
        """
        do {
            let response = try await makeClassifierSession().respond(
                to: prompt,
                generating: ContentRelevance.self,
                options: deterministicOptions
            )
            return response.content.isLessonContent
        } catch {
            return true // fail open
        }
    }

    // MARK: - Title Generation

    func generateLessonTitle(representativeContent: String, keyTerms: [String]) async throws -> String {
        let termsLine = keyTerms.isEmpty ? "" : "Most frequent topic words: \(keyTerms.joined(separator: ", "))\n\n"
        let prompt = """
        Produce a topic title for this lesson. 2-6 words, Title Case. Just the subject — \
        no "Key Points", no "Lesson on...", no colons, no quotes.

        Examples: "The Water Cycle", "Mitochondria and Chloroplasts", "Newton's Laws of Motion".

        \(termsLine)Most representative content:
        \(representativeContent)
        """
        let response = try await makeContentSession().respond(
            to: prompt,
            generating: TitleResult.self,
            options: deterministicOptions
        )
        return sanitizeTitle(response.content.title)
    }

    func generateModuleTitle(content: String, keyTerms: [String]) async throws -> (title: String, summary: String) {
        let termsLine = keyTerms.isEmpty ? "" : "Topic words: \(keyTerms.joined(separator: ", "))\n\n"
        let prompt = """
        Produce a title (2-5 words, Title Case) and a one-sentence summary for this section of a lesson.

        The summary must:
        - Start with a verb (Explains, Covers, Introduces, Describes)
        - Be specific about the actual concepts
        - Not restate the title; not use the word "module" or "section"

        Good summary examples:
        - "Explains how water changes between liquid, solid, and gas as it moves through the atmosphere."
        - "Covers the four stages of the water cycle and how they connect."
        - "Introduces mitochondria as the cell's energy producers and how ATP is made."

        \(termsLine)Content:
        \(content)
        """
        let response = try await makeContentSession().respond(
            to: prompt,
            generating: ModuleTitleResult.self,
            options: deterministicOptions
        )
        return (sanitizeTitle(response.content.title), response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Focused retry for just the summary, in case the combined call returned empty.
    func generateModuleSummary(content: String, keyTerms: [String]) async throws -> String {
        let termsLine = keyTerms.isEmpty ? "" : "Topic words: \(keyTerms.joined(separator: ", "))\n\n"
        let prompt = """
        Write ONE specific sentence describing what a student would learn from this content. \
        Start with a verb (Explains, Covers, Introduces, Describes). Be specific.

        Examples:
        - "Explains how water changes between liquid, solid, and gas."
        - "Covers the four stages of the water cycle and how they connect."
        - "Introduces mitochondria as the cell's energy producers."

        \(termsLine)Content:
        \(content)
        """
        let response = try await makeContentSession().respond(
            to: prompt,
            generating: SummaryOnlyResult.self,
            options: deterministicOptions
        )
        return response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate flashcard-style study cards from module content.
    /// Each card covers one discrete concept for ADHD-friendly carousel study.
    func generateStudyCards(content: String) async throws -> [(title: String, explanation: String)] {
        let trimmed = String(content.prefix(2500))
        let prompt = """
        Create 3-7 flashcards from the content below. Each card covers ONE distinct concept; cards should not overlap.

        Each card has:
        - Title: 3-6 words naming the concept
        - Explanation: 2-3 short sentences that EXPLAIN the concept in your own words. Use examples or analogies if helpful. Don't just paraphrase the source.

        Content:
        \(trimmed)
        """
        let response = try await makeContentSession().respond(
            to: prompt,
            generating: StudyCardsResult.self,
            options: creativeOptions
        )
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

    // MARK: - Question Generation (multistep: plan concepts → one question each)

    /// Multistep generation that's far more reliable than asking for N questions in one shot.
    /// Step 1: ask the model to identify up to N distinct concepts from the content (small output).
    /// Step 2: for each concept, ask for ONE question (tiny output per call).
    /// Each individual call uses a tiny fraction of the 4096-token budget, leaving room for
    /// tool schemas in step 2.
    func generateQuestions(context: String, count: Int = 3, difficulty: DifficultyLevel = .medium) async throws -> [Question] {
        try await generateQuestions(context: context, count: count, difficulty: difficulty, progress: nil)
    }

    /// Variant that reports progress as concepts are planned and individual questions are produced.
    /// Progress: 0.0 → 0.1 (planning concepts), 0.1 → 1.0 (generating questions one by one).
    func generateQuestions(
        context: String,
        count: Int = 3,
        difficulty: DifficultyLevel = .medium,
        progress: ((Double, String) -> Void)?
    ) async throws -> [Question] {
        progress?(0.05, "Identifying concepts…")

        let rawConcepts = (try? await generateQuestionConcepts(context: context, maxCount: count)) ?? []
        // Dedupe concepts case-insensitively so we don't run two passes on the same idea.
        var seen = Set<String>()
        let concepts = rawConcepts.filter { c in
            let key = c.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
        guard !concepts.isEmpty else { return [] }

        let target = min(count, concepts.count)
        progress?(0.1, "Found \(concepts.count) concepts")

        var questions: [Question] = []
        var askedNormalized = Set<String>()  // for cheap dedupe check on outputs
        for (index, concept) in concepts.prefix(count).enumerated() {
            let frac = Double(index) / Double(target)
            progress?(0.1 + frac * 0.9, "Generating question \(index + 1) of \(target)…")

            // Sliding window of already-asked question prompts.
            let previousPrompts = questions.map(\.prompt)

            guard let q = try? await generateSingleQuestion(
                context: context,
                concept: concept,
                difficulty: difficulty,
                previousQuestions: previousPrompts
            ) else { continue }

            let p = q.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = q.expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty, !a.isEmpty else { continue }

            // Defensive: drop the question if it's a near-duplicate of one we already kept.
            // Uses a simplified normalized form for cheap comparison.
            let key = normalizedQuestionKey(p)
            if askedNormalized.contains(key) { continue }
            askedNormalized.insert(key)

            questions.append(Question(prompt: p, expectedAnswer: a, difficulty: q.difficulty))
        }
        progress?(1.0, "Done")
        return questions
    }

    /// Normalize a question prompt for cheap duplicate detection — lowercase, alphanumerics only,
    /// stopwords stripped. So "What is the water cycle?" and "What's the water cycle" both
    /// collapse to "water cycle" and dedupe naturally.
    private func normalizedQuestionKey(_ s: String) -> String {
        let stopwords: Set<String> = ["what", "is", "the", "a", "an", "are", "how", "does", "do",
                                       "can", "you", "your", "of", "to", "for", "in", "on", "at",
                                       "and", "or", "this", "that", "these", "those", "it"]
        return s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
            .joined(separator: " ")
    }

    /// Step 1 of the pipeline: ask the model what concepts can be quizzed from this content.
    /// Uses the .contentTagging specialized model since this is essentially a tagging task —
    /// extract topic labels from the source. Output is just a list of strings.
    private func generateQuestionConcepts(context: String, maxCount: Int) async throws -> [String] {
        let prompt = """
        Identify \(maxCount) distinct concepts from the study material below — one per item. \
        Aim for exactly \(maxCount). Only return fewer if the material genuinely has fewer \
        distinct ideas (in which case stop at the natural limit, don't pad with duplicates). \
        Each concept title is 2-5 words. Avoid overlapping or near-duplicate concepts.

        Study material:
        \(context)
        """
        let response = try await makeClassifierSession().respond(
            to: prompt,
            generating: ConceptListResult.self,
            options: deterministicOptions
        )
        return response.content.concepts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Step 2 of the pipeline: generate ONE question for the given concept.
    /// `previousQuestions` is a sliding window of recently-asked question prompts so the model
    /// can avoid repeating itself. Tiny output schema leaves plenty of budget headroom.
    private func generateSingleQuestion(
        context: String,
        concept: String,
        difficulty: DifficultyLevel,
        previousQuestions: [String]
    ) async throws -> GeneratedQuestion {
        let avoidBlock: String
        if previousQuestions.isEmpty {
            avoidBlock = ""
        } else {
            // Keep the window bounded so the prompt doesn't grow unbounded as the quiz progresses.
            let recent = previousQuestions.suffix(8)
            let bulleted = recent.enumerated().map { i, q in "\(i + 1). \(q)" }.joined(separator: "\n")
            avoidBlock = """

                Questions already asked in this quiz — do NOT repeat or paraphrase any of these. \
                Pick a different angle on the concept:
                \(bulleted)

                """
        }

        let prompt = """
        Generate ONE active recall question about this concept: "\(concept)"

        The question should test \(difficulty.systemPrompt). Use ONLY information present in \
        the material below — do not introduce facts that aren't there. Keep it clear and focused.\(avoidBlock)

        Study material:
        \(context)
        """
        let response = try await makeQuizSession().respond(
            to: prompt,
            generating: GeneratedQuestion.self,
            options: creativeOptions
        )
        return response.content
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
        Evaluate this student's answer.

        \(leniency)

        In the explanation, briefly state what a complete answer would include.

        Question: \(question.prompt)
        Expected answer: \(question.expectedAnswer)
        Student's answer: \(userAnswer)
        """
        // No tools — the question, expected answer, and student answer are all in the prompt.
        // Deterministic so grading is consistent for the same answer.
        let response = try await makeQuizSession().respond(
            to: prompt,
            generating: FeedbackResult.self,
            options: deterministicOptions
        )
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
        Suggest 3-5 lessons to study next. Prioritize lessons not yet studied or with low accuracy.

        Lessons:
        \(summaries)
        """
        let response = try await makeContentSession().respond(
            to: prompt,
            generating: SuggestedPlanResult.self,
            options: deterministicOptions
        )
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
