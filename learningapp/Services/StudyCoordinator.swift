import Foundation
import SwiftData

@Observable
final class StudyCoordinator {
    var currentMaterial: StudyMaterial?
    var currentQuestions: [Question] = []
    var isProcessing = false
    var currentPlan: StudyPlan?

    // Ingestion progress (0.0 to 1.0)
    var ingestionProgress: Double = 0
    var ingestionStatus: String = ""

    private let modelService = FoundationModelService()
    private let ragService = RAGService()
    private let embeddingService = EmbeddingService()

    // MARK: - Ingestion (called when user adds new material)

    /// Chunk text locally, AI-filter for relevance, embed each chunk, store in SwiftData, generate title.
    func ingestMaterial(_ material: StudyMaterial, context: ModelContext) async {
        isProcessing = true
        ingestionProgress = 0
        defer {
            isProcessing = false
            ingestionProgress = 0
            ingestionStatus = ""
        }

        // 1. Local chunking
        ingestionStatus = "Splitting text..."
        let rawChunks = chunkLocally(material.rawText)
        guard !rawChunks.isEmpty else { return }

        // 2. AI filter: classify each chunk as content or boilerplate
        ingestionStatus = "Filtering relevant content..."
        var relevantChunks: [String] = []
        for (i, chunk) in rawChunks.enumerated() {
            ingestionProgress = Double(i) / Double(rawChunks.count) * 0.7 // 70% of progress
            // Skip very short chunks without classification (likely junk)
            if chunk.count < 30 { continue }
            if await modelService.isLessonContent(chunk) {
                relevantChunks.append(chunk)
            }
        }

        // If filtering nuked everything, fall back to raw chunks
        if relevantChunks.isEmpty { relevantChunks = rawChunks }

        // 3. Embed and store each relevant chunk (also capture embeddings for centroid analysis)
        ingestionStatus = "Embedding chunks..."
        var embeddedChunks: [(text: String, vector: [Double])] = []
        for (i, text) in relevantChunks.enumerated() {
            ingestionProgress = 0.7 + Double(i) / Double(relevantChunks.count) * 0.25
            guard let vector = embeddingService.embed(text) else { continue }
            let stored = StoredChunk(materialID: material.id, text: text, order: i, embedding: vector)
            context.insert(stored)
            embeddedChunks.append((text, vector))
        }

        // 4. Generate a title using RAG: centroid retrieval + lemmatized key terms
        ingestionStatus = "Generating title..."
        ingestionProgress = 0.95
        if material.title.isEmpty {
            let representative = ragService.mostRepresentativeChunks(from: embeddedChunks, topK: 3)
                .joined(separator: "\n\n")
            let keyTerms = TextAnalysis.extractKeyTerms(material.rawText, topN: 8)
            if let title = try? await modelService.generateTitle(
                representativeContent: representative.isEmpty ? material.rawText : representative,
                keyTerms: keyTerms
            ), !title.isEmpty {
                material.title = title
            } else {
                let firstLine = material.rawText.components(separatedBy: .newlines)
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
                material.title = String(firstLine.prefix(50))
            }
        }

        ingestionProgress = 1.0
        try? context.save()
    }

    // MARK: - Study Session (RAG-powered)

    /// Generate questions by retrieving relevant chunks from SwiftData.
    func generateQuiz(for material: StudyMaterial, count: Int = 3, difficulty: DifficultyLevel = .medium, context: ModelContext) async {
        isProcessing = true
        defer { isProcessing = false }
        currentMaterial = material

        let topic = material.title.isEmpty ? String(material.rawText.prefix(100)) : material.title
        let chunks = ragService.retrieveRelevantChunks(query: topic, from: context, materialID: material.id)
        let ragContext = ragService.buildContext(from: chunks)

        do {
            currentQuestions = try await modelService.generateQuestions(context: ragContext, count: count, difficulty: difficulty)
        } catch {
            currentQuestions = []
        }
    }

    /// Generate adaptive questions using performance history.
    func generateAdaptiveQuiz(for material: StudyMaterial, sessions: [SessionResult], context: ModelContext) async {
        isProcessing = true
        defer { isProcessing = false }
        currentMaterial = material

        let topic = material.title.isEmpty ? String(material.rawText.prefix(100)) : material.title
        let chunks = ragService.retrieveRelevantChunks(query: topic, from: context, materialID: material.id)
        let ragContext = ragService.buildContext(from: chunks)

        do {
            currentQuestions = try await modelService.generateAdaptiveQuestions(
                context: ragContext, performanceHistory: sessions)
        } catch {
            currentQuestions = []
        }
    }

    func submitAnswer(question: Question, answer: String) async -> Feedback {
        do {
            return try await modelService.evaluateAnswer(question: question, userAnswer: answer)
        } catch {
            return Feedback(isCorrect: false, explanation: "Unable to evaluate answer.", encouragement: "Keep trying!")
        }
    }

    // MARK: - Append Content (add more to existing material)

    /// Append new text to an existing material, re-chunk and embed only the new content.
    func appendContent(_ newText: String, to material: StudyMaterial, context: ModelContext) async {
        isProcessing = true
        ingestionProgress = 0
        defer {
            isProcessing = false
            ingestionProgress = 0
            ingestionStatus = ""
        }

        material.rawText += "\n\n" + newText

        let descriptor = FetchDescriptor<StoredChunk>()
        let allChunks = (try? context.fetch(descriptor)) ?? []
        let maxOrder = allChunks.filter { $0.materialID == material.id }.map(\.order).max() ?? -1

        // Chunk and AI-filter the new text
        ingestionStatus = "Filtering relevant content..."
        let newChunks = chunkLocally(newText)
        var relevantChunks: [String] = []
        for (i, chunk) in newChunks.enumerated() {
            ingestionProgress = Double(i) / Double(max(1, newChunks.count)) * 0.7
            if chunk.count < 30 { continue }
            if await modelService.isLessonContent(chunk) {
                relevantChunks.append(chunk)
            }
        }
        if relevantChunks.isEmpty { relevantChunks = newChunks }

        ingestionStatus = "Embedding chunks..."
        for (i, text) in relevantChunks.enumerated() {
            ingestionProgress = 0.7 + Double(i) / Double(relevantChunks.count) * 0.3
            guard let vector = embeddingService.embed(text) else { continue }
            let stored = StoredChunk(materialID: material.id, text: text, order: maxOrder + 1 + i, embedding: vector)
            context.insert(stored)
        }

        ingestionProgress = 1.0
        try? context.save()
    }

    // MARK: - Study Plan

    func generateAndSchedulePlan(context: ModelContext) async {
        isProcessing = true
        defer { isProcessing = false }
        let materials = PersistenceService.fetchAll(context: context)
        let sessions = PersistenceService.fetchRecentSessions(limit: 10, context: context)
        do {
            let plan = try await modelService.generateStudyPlan(materials: materials, sessions: sessions)
            currentPlan = plan
            for (index, item) in plan.items.enumerated() {
                guard let material = materials.first(where: { $0.id == item.materialID }) else { continue }
                let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
                NotificationService.scheduleReviewReminder(for: material, at: date)
            }
        } catch {
            currentPlan = nil
        }
    }

    func completeSession(result: SessionResult, context: ModelContext) {
        PersistenceService.saveSession(result, context: context)
        let accuracy = result.questionsAnswered > 0 ? Double(result.correctCount) / Double(result.questionsAnswered) : 0
        let quality = SpacedRepetitionService.qualityFromAccuracy(accuracy)
        let schedule = SpacedRepetitionService.getOrCreateSchedule(for: result.materialID, context: context)
        SpacedRepetitionService.calculateNextReview(schedule: schedule, quality: quality)
        try? context.save()
        NotificationService.scheduleReviewReminder(
            for: StudyMaterial(id: result.materialID, rawText: "", sourceType: .paste),
            at: schedule.nextReviewDate
        )
    }

    // MARK: - Local Chunking (no AI, just text splitting)

    /// Split text into ~300-500 char chunks by paragraph boundaries.
    private func chunkLocally(_ text: String) -> [String] {
        let cleaned = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { line in
                !line.hasPrefix("_Image") && !line.hasPrefix("[^") && !line.hasPrefix("![")
            }

        // Group paragraphs into chunks of ~400 chars
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
