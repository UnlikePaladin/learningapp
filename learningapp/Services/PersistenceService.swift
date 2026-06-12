import Foundation
import SwiftData

struct PersistenceService {
    // MARK: - Lessons

    static func save(_ lesson: Lesson, context: ModelContext) {
        context.insert(lesson)
        try? context.save()
    }

    static func fetchAllLessons(context: ModelContext) -> [Lesson] {
        let descriptor = FetchDescriptor<Lesson>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Cascade delete: lesson + its modules + sources + chunks + cards
    static func delete(_ lesson: Lesson, context: ModelContext) {
        let lessonID = lesson.id
        let chunks = (try? context.fetch(FetchDescriptor<StoredChunk>(predicate: #Predicate { $0.lessonID == lessonID }))) ?? []
        chunks.forEach { context.delete($0) }
        let cards = (try? context.fetch(FetchDescriptor<StudyCard>(predicate: #Predicate { $0.lessonID == lessonID }))) ?? []
        cards.forEach { context.delete($0) }
        let modules = (try? context.fetch(FetchDescriptor<Module>(predicate: #Predicate { $0.lessonID == lessonID }))) ?? []
        modules.forEach { context.delete($0) }
        let sources = (try? context.fetch(FetchDescriptor<Source>(predicate: #Predicate { $0.lessonID == lessonID }))) ?? []
        sources.forEach { context.delete($0) }
        context.delete(lesson)
        try? context.save()
    }

    // MARK: - Sessions

    static func saveSession(_ session: SessionResult, context: ModelContext) {
        context.insert(session)
        try? context.save()
    }

    static func fetchSessions(for lessonID: UUID?, context: ModelContext) -> [SessionResult] {
        var descriptor = FetchDescriptor<SessionResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let lessonID {
            descriptor.predicate = #Predicate { $0.lessonID == lessonID }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchRecentSessions(limit: Int, context: ModelContext) -> [SessionResult] {
        var descriptor = FetchDescriptor<SessionResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
