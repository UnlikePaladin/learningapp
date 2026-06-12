import Foundation
import SwiftData

@Model
final class ReviewSchedule {
    @Attribute(.unique) var id: UUID
    var materialID: UUID
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date
    var lastReviewDate: Date

    init(id: UUID = UUID(), materialID: UUID, easeFactor: Double = 2.5, interval: Int = 0, repetitions: Int = 0, nextReviewDate: Date = Date(), lastReviewDate: Date = Date()) {
        self.id = id
        self.materialID = materialID
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
    }
}

struct SpacedRepetitionService {
    /// SM-2 algorithm: quality 0-5, updates schedule in place
    static func calculateNextReview(schedule: ReviewSchedule, quality: Int) {
        let q = max(0, min(5, quality))
        schedule.lastReviewDate = Date()

        if q < 3 {
            schedule.repetitions = 0
            schedule.interval = 1
        } else {
            switch schedule.repetitions {
            case 0: schedule.interval = 1
            case 1: schedule.interval = 6
            default: schedule.interval = Int(round(Double(schedule.interval) * schedule.easeFactor))
            }
            schedule.repetitions += 1
        }

        let efDelta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        schedule.easeFactor = max(1.3, schedule.easeFactor + efDelta)
        schedule.nextReviewDate = Calendar.current.date(byAdding: .day, value: schedule.interval, to: Date()) ?? Date()
    }

    /// Convert session accuracy (0.0-1.0) to SM-2 quality (0-5)
    static func qualityFromAccuracy(_ accuracy: Double) -> Int {
        return min(5, max(0, Int(round(accuracy * 5.0))))
    }

    static func getMaterialsDueForReview(context: ModelContext) -> [StudyMaterial] {
        let now = Date()
        let schedulesDescriptor = FetchDescriptor<ReviewSchedule>(
            predicate: #Predicate { $0.nextReviewDate <= now }
        )
        let schedules = (try? context.fetch(schedulesDescriptor)) ?? []
        let dueIDs = Set(schedules.map(\.materialID))

        let materialsDescriptor = FetchDescriptor<StudyMaterial>()
        let allMaterials = (try? context.fetch(materialsDescriptor)) ?? []
        return allMaterials.filter { dueIDs.contains($0.id) }
    }

    static func getOrCreateSchedule(for materialID: UUID, context: ModelContext) -> ReviewSchedule {
        let descriptor = FetchDescriptor<ReviewSchedule>(
            predicate: #Predicate { $0.materialID == materialID }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let schedule = ReviewSchedule(materialID: materialID)
        context.insert(schedule)
        try? context.save()
        return schedule
    }
}
