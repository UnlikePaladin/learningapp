import Foundation
import SwiftData

@Observable
final class StudyCoordinator {
    var isProcessing = false
    var ingestionProgress: Double = 0
    var ingestionStatus: String = ""

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

    /// Process a single source: chunk → AI filter → embed → re-cluster all chunks for the lesson.
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

        // 2. AI filter for relevance
        ingestionStatus = "Filtering relevant content..."
        var relevantChunks: [String] = []
        for (i, chunk) in rawChunks.enumerated() {
            ingestionProgress = Double(i) / Double(rawChunks.count) * 0.5
            if chunk.count < 30 { continue }
            if await modelService.isLessonContent(chunk) {
                relevantChunks.append(chunk)
            }
        }
        if relevantChunks.isEmpty { relevantChunks = rawChunks }

        // 3. Embed each chunk (we don't store yet — clustering happens first)
        ingestionStatus = "Embedding chunks..."
        var newEmbedded: [ChunkWithEmbedding] = []
        for (i, text) in relevantChunks.enumerated() {
            ingestionProgress = 0.5 + Double(i) / Double(relevantChunks.count) * 0.2
            guard let vec = embeddingService.embed(text) else { continue }
            newEmbedded.append(ChunkWithEmbedding(text: text, vector: vec, sourceID: source.id, order: i))
        }

        // 4. Combine with existing chunks for this lesson, re-cluster all of them
        ingestionStatus = "Organizing into modules..."
        ingestionProgress = 0.7
        let lessonID = lesson.id
        let existingChunks = (try? context.fetch(FetchDescriptor<StoredChunk>(predicate: #Predicate { $0.lessonID == lessonID }))) ?? []
        let existingEmbedded = existingChunks.map {
            ChunkWithEmbedding(text: $0.text, vector: $0.embedding, sourceID: $0.sourceID, order: $0.order)
        }
        let allChunks = existingEmbedded + newEmbedded

        // Wipe old modules + chunks; we'll rebuild them
        let oldModules = (try? context.fetch(FetchDescriptor<Module>(predicate: #Predicate { $0.lessonID == lessonID }))) ?? []
        oldModules.forEach { context.delete($0) }
        existingChunks.forEach { context.delete($0) }

        let clustered = ModuleClusteringService.cluster(chunks: allChunks)

        // 5. For each cluster, generate a title + create Module + StoredChunks
        ingestionStatus = "Generating module titles..."
        for (moduleOrder, cluster) in clustered.enumerated() {
            ingestionProgress = 0.7 + Double(moduleOrder) / Double(clustered.count) * 0.2

            let moduleContent = cluster.chunks.map(\.text).joined(separator: "\n").prefix(1500)
            let combinedText = cluster.chunks.map(\.text).joined(separator: " ")
            let keyTerms = TextAnalysis.extractKeyTerms(combinedText, topN: 6)

            // Build a fallback title from the top key terms (capitalized).
            // Used if the AI title generator fails or returns empty.
            let fallbackTitle: String = {
                let topTerms = keyTerms.prefix(3).map { $0.capitalized }
                if topTerms.isEmpty { return "Section \(moduleOrder + 1)" }
                return topTerms.joined(separator: " & ")
            }()

            // Fallback summary: first ~140 chars of the content, ending at a sentence boundary.
            let fallbackSummary: String = {
                let text = combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return "" }
                let truncated = String(text.prefix(140))
                if let lastPeriod = truncated.lastIndex(where: { ".!?".contains($0) }) {
                    return String(truncated[..<truncated.index(after: lastPeriod)])
                }
                if let lastSpace = truncated.lastIndex(of: " ") {
                    return String(truncated[..<lastSpace]) + "…"
                }
                return truncated + "…"
            }()

            var moduleTitle = fallbackTitle
            var moduleSummary = fallbackSummary
            if let result = try? await modelService.generateModuleTitle(
                content: String(moduleContent),
                keyTerms: keyTerms
            ) {
                if !result.title.isEmpty { moduleTitle = result.title }
                if !result.summary.isEmpty { moduleSummary = result.summary }
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
                from: allChunks.map { (text: $0.text, vector: $0.vector) },
                topK: 3
            ).joined(separator: "\n\n")
            let allText = allChunks.map(\.text).joined(separator: " ")
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

    // MARK: - Quiz generation (for Lesson, Module, or CustomStudyPlan)

    func generateQuestions(
        for scope: RAGService.Scope,
        topicHint: String,
        count: Int,
        difficulty: DifficultyLevel,
        context: ModelContext
    ) async -> [Question] {
        let chunks = ragService.retrieveRelevantChunks(query: topicHint, scope: scope, from: context)
        let ragContext = ragService.buildContext(from: chunks)
        guard !ragContext.isEmpty else { return [] }
        do {
            return try await modelService.generateQuestions(context: ragContext, count: count, difficulty: difficulty)
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
