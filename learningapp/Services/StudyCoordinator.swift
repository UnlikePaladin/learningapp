import Foundation
import SwiftData

@Observable
final class StudyCoordinator {
    var currentMaterial: StudyMaterial?
    var currentQuestions: [Question] = []
    var isProcessing = false
    var currentPlan: StudyPlan?

    private let modelService = FoundationModelService()
    private let ragService = RAGService()
    private let embeddingService = EmbeddingService()

    // MARK: - Ingestion (called when user adds new material)

    /// Chunk text locally, embed each chunk, store in SwiftData, generate title.
    func ingestMaterial(_ material: StudyMaterial, context: ModelContext) async {
        isProcessing = true
        defer { isProcessing = false }

        // 1. Local chunking — split by paragraphs, no AI needed
        let rawChunks = chunkLocally(material.rawText)

        // 2. Embed and store each chunk
        for (i, text) in rawChunks.enumerated() {
            guard let vector = embeddingService.embed(text) else { continue }
            let stored = StoredChunk(materialID: material.id, text: text, order: i, embedding: vector)
            context.insert(stored)
        }

        // 3. Generate a title from the first chunk
        if material.title.isEmpty {
            let titleText = rawChunks.first ?? String(material.rawText.prefix(200))
            if let title = try? await modelService.generateTitle(from: titleText), !title.isEmpty {
                material.title = title
            } else {
                // Fallback: use first line or first 50 chars as title
                let firstLine = material.rawText.components(separatedBy: .newlines)
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
                material.title = String(firstLine.prefix(50))
            }
        }

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
        defer { isProcessing = false }

        // Append to raw text
        material.rawText += "\n\n" + newText

        // Get current max order for this material's chunks
        let descriptor = FetchDescriptor<StoredChunk>()
        let allChunks = (try? context.fetch(descriptor)) ?? []
        let maxOrder = allChunks.filter { $0.materialID == material.id }.map(\.order).max() ?? -1

        // Chunk and embed only the new text
        let newChunks = chunkLocally(newText)
        for (i, text) in newChunks.enumerated() {
            guard let vector = embeddingService.embed(text) else { continue }
            let stored = StoredChunk(materialID: material.id, text: text, order: maxOrder + 1 + i, embedding: vector)
            context.insert(stored)
        }

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
