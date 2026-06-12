import Foundation
import SwiftData

@Observable
final class StudyCoordinator {
    var currentMaterial: StudyMaterial?
    var chunks: [Chunk] = []
    var currentQuestions: [Question] = []
    var isProcessing = false
    var currentPlan: StudyPlan?

    private let modelService = FoundationModelService()

    func processMaterial(_ material: StudyMaterial) async {
        isProcessing = true
        defer { isProcessing = false }
        currentMaterial = material
        do {
            chunks = try await modelService.chunkText(material.rawText)
        } catch {
            chunks = []
        }
    }

    func generateQuiz(for chunk: Chunk) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            currentQuestions = try await modelService.generateQuestions(from: chunk)
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

    func generateAndSchedulePlan(context: ModelContext) async {
        isProcessing = true
        defer { isProcessing = false }
        let materials = PersistenceService.fetchAll(context: context)
        let sessions = PersistenceService.fetchRecentSessions(limit: 10, context: context)
        do {
            let plan = try await modelService.generateStudyPlan(materials: materials, recentSessions: sessions)
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
}
