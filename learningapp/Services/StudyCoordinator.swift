import Foundation
import SwiftData

@Observable
final class StudyCoordinator {
    var isProcessing = false
    var ingestionProgress: Double = 0
    var ingestionStatus: String = ""

    /// Quiz generation progress (0.0 to 1.0). Updated as concepts are planned and questions generated.
    var quizProgress: Double = 0
    var quizStatus: String = ""

    private let modelService = FoundationModelService()
    private let ragService = RAGService()
    private let embeddingService = EmbeddingService()

    // MARK: - Ingestion: create new lesson from a source

    /// Create a new Lesson from a source text (paste, camera, or PDF).
    /// Chunks, AI-filters, embeds, clusters into modules, generates titles.
    @discardableResult
    func createLesson(
        rawText: String,
        sourceType: SourceType,
        fileName: String? = nil,
        context: ModelContext
    ) async -> Lesson? {
        let lesson = Lesson()
        context.insert(lesson)
        let source = Source(lessonID: lesson.id, rawText: rawText, sourceType: sourceType, fileName: fileName)
        context.insert(source)
        try? context.save()

        await processSource(source, lesson: lesson, context: context)
        return lesson
    }

    /// Add a new source to an existing lesson and re-cluster modules.
    func addSource(
        rawText: String,
        sourceType: SourceType,
        fileName: String? = nil,
        to lesson: Lesson,
        context: ModelContext
    ) async {
        let source = Source(lessonID: lesson.id, rawText: rawText, sourceType: sourceType, fileName: fileName)
        context.insert(source)
        try? context.save()
        await processSource(source, lesson: lesson, context: context)
    }

    /// Process a single source: chunk → AI filter → embed → cluster the NEW content into NEW modules.
    /// Existing modules and their cards stay intact.
    private func processSource(_ source: Source, lesson: Lesson, context: ModelContext) async {
        isProcessing = true
        ingestionProgress = 0
        defer {
            isProcessing = false
            ingestionProgress = 0
            ingestionStatus = ""
        }

        // 1. Local chunking
        ingestionStatus = "Splitting text..."
        let rawChunks = chunkLocally(source.rawText)
        guard !rawChunks.isEmpty else { return }

        // 2. Fast local heuristic filter — no AI call per chunk (was ~1-2s each, prohibitive for big PDFs).
        ingestionStatus = "Filtering relevant content..."
        ingestionProgress = 0.4
        let relevantChunks: [String] = {
            let filtered = rawChunks.filter { LocalContentFilter.isLikelyContent($0) }
            return filtered.isEmpty ? rawChunks : filtered
        }()

        // 3. Embed each new chunk
        ingestionStatus = "Embedding chunks..."
        var newEmbedded: [ChunkWithEmbedding] = []
        for (i, text) in relevantChunks.enumerated() {
            ingestionProgress = 0.5 + Double(i) / Double(relevantChunks.count) * 0.2
            guard let vec = embeddingService.embed(text) else { continue }
            newEmbedded.append(ChunkWithEmbedding(text: text, vector: vec, sourceID: source.id, order: i))
        }

        guard !newEmbedded.isEmpty else { return }

        // 4. Cluster ONLY the new chunks into new modules.
        // Existing modules and cards stay untouched.
        ingestionStatus = "Organizing into modules..."
        ingestionProgress = 0.7
        let lessonID = lesson.id
        let existingModuleCount = (try? context.fetch(FetchDescriptor<Module>(predicate: #Predicate { $0.lessonID == lessonID })))?.count ?? 0
        let clustered = ModuleClusteringService.cluster(chunks: newEmbedded)

        // 5. For each cluster, generate a title + create Module + StoredChunks
        ingestionStatus = "Generating module titles..."
        for (clusterIdx, cluster) in clustered.enumerated() {
            ingestionProgress = 0.7 + Double(clusterIdx) / Double(clustered.count) * 0.2

            let moduleOrder = existingModuleCount + clusterIdx
            let moduleContent = String(cluster.chunks.map(\.text).joined(separator: "\n").prefix(1500))
            let combinedText = cluster.chunks.map(\.text).joined(separator: " ")
            let keyTerms = TextAnalysis.extractKeyTerms(combinedText, topN: 6)

            let fallbackTitle: String = {
                let topTerms = keyTerms.prefix(3).map { $0.capitalized }
                if topTerms.isEmpty { return "Section \(moduleOrder + 1)" }
                return topTerms.joined(separator: " & ")
            }()

            // Try to get a real title + summary from the model
            var moduleTitle = fallbackTitle
            var moduleSummary = ""
            if let result = try? await modelService.generateModuleTitle(
                content: moduleContent,
                keyTerms: keyTerms
            ) {
                if !result.title.isEmpty { moduleTitle = result.title }
                if !result.summary.isEmpty { moduleSummary = result.summary }
            }

            // If summary is empty, retry with a focused summary-only call
            if moduleSummary.isEmpty {
                if let retrySummary = try? await modelService.generateModuleSummary(
                    content: moduleContent,
                    keyTerms: keyTerms
                ), !retrySummary.isEmpty {
                    moduleSummary = retrySummary
                }
            }

            // Last resort: build a key-term-based summary (NEVER use raw text)
            if moduleSummary.isEmpty {
                moduleSummary = buildKeyTermSummary(keyTerms: keyTerms, title: moduleTitle)
            }

            let module = Module(lessonID: lesson.id, title: moduleTitle, summary: moduleSummary, order: moduleOrder)
            context.insert(module)

            for (chunkOrder, chunk) in cluster.chunks.enumerated() {
                let stored = StoredChunk(
                    lessonID: lesson.id,
                    moduleID: module.id,
                    sourceID: chunk.sourceID,
                    text: chunk.text,
                    order: chunkOrder,
                    embedding: chunk.vector
                )
                context.insert(stored)
            }
        }

        // 6. Generate or update lesson title (only if currently empty)
        if lesson.title.isEmpty {
            ingestionStatus = "Generating lesson title..."
            ingestionProgress = 0.95
            let titleSource = ragService.mostRepresentativeChunks(
                from: newEmbedded.map { (text: $0.text, vector: $0.vector) },
                topK: 3
            ).joined(separator: "\n\n")
            let allText = newEmbedded.map(\.text).joined(separator: " ")
            let keyTerms = TextAnalysis.extractKeyTerms(allText, topN: 8)
            if let title = try? await modelService.generateLessonTitle(
                representativeContent: titleSource.isEmpty ? source.rawText : titleSource,
                keyTerms: keyTerms
            ), !title.isEmpty {
                lesson.title = title
            } else {
                let firstLine = source.rawText.components(separatedBy: .newlines)
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Untitled"
                lesson.title = String(firstLine.prefix(50))
            }
        }

        ingestionProgress = 1.0
        try? context.save()
    }

    /// Build a clean fallback summary from key terms (never raw text).
    /// Used only when both AI calls failed to produce a summary.
    private func buildKeyTermSummary(keyTerms: [String], title: String) -> String {
        let topTerms = keyTerms.prefix(3).map { $0.capitalized }
        if topTerms.isEmpty {
            return "Covers concepts related to \(title)."
        }
        if topTerms.count == 1 {
            return "Covers \(topTerms[0])."
        }
        if topTerms.count == 2 {
            return "Covers \(topTerms[0]) and \(topTerms[1])."
        }
        let allButLast = topTerms.dropLast().joined(separator: ", ")
        return "Covers \(allButLast), and \(topTerms.last!)."
    }

    // MARK: - Quiz generation (for Lesson, Module, or CustomStudyPlan)

    func generateQuestions(
        for scope: RAGService.Scope,
        topicHint: String,
        count: Int,
        difficulty: DifficultyLevel,
        context: ModelContext
    ) async -> [Question] {
        quizProgress = 0
        quizStatus = "Finding relevant content…"
        defer {
            quizProgress = 0
            quizStatus = ""
        }

        // Scale RAG retrieval with the user's requested count. A 5-question quiz only needs
        // a few representative chunks; a 20-question quiz needs much broader context so the
        // model has enough distinct concepts to pull from.
        let topK = max(3, min(10, (count + 2) / 3))
        let maxChars = max(1500, min(4000, count * 200))
        let chunks = ragService.retrieveRelevantChunks(
            query: topicHint,
            scope: scope,
            from: context,
            topK: topK,
            maxChars: maxChars
        )
        let ragContext = ragService.buildContext(from: chunks)
        guard !ragContext.isEmpty else { return [] }

        do {
            return try await modelService.generateQuestions(
                context: ragContext,
                count: count,
                difficulty: difficulty
            ) { [weak self] frac, status in
                Task { @MainActor in
                    self?.quizProgress = frac
                    self?.quizStatus = status
                }
            }
        } catch {
            return []
        }
    }

    func evaluate(question: Question, answer: String, difficulty: DifficultyLevel) async -> Feedback {
        do {
            return try await modelService.evaluateAnswer(question: question, userAnswer: answer, difficulty: difficulty)
        } catch {
            return Feedback(isCorrect: false, explanation: "Could not evaluate.", encouragement: "Keep going!")
        }
    }

    // MARK: - Session Completion

    func completeSession(result: SessionResult, context: ModelContext) {
        PersistenceService.saveSession(result, context: context)
        let accuracy = result.questionsAnswered > 0 ? Double(result.correctCount) / Double(result.questionsAnswered) : 0
        let quality = SpacedRepetitionService.qualityFromAccuracy(accuracy)
        let schedule = SpacedRepetitionService.getOrCreateSchedule(for: result.lessonID, context: context)
        SpacedRepetitionService.calculateNextReview(schedule: schedule, quality: quality)
        try? context.save()
    }

    // MARK: - Local Chunking

    private func chunkLocally(_ text: String) -> [String] {
        let cleaned = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { line in
                !line.hasPrefix("_Image") && !line.hasPrefix("[^") && !line.hasPrefix("![")
            }

        var chunks: [String] = []
        var current = ""
        for para in cleaned {
            if current.count + para.count > 400 && !current.isEmpty {
                chunks.append(current)
                current = para
            } else {
                current += current.isEmpty ? para : "\n" + para
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
