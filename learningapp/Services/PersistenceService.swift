import Foundation
import SwiftData

struct PersistenceService {
    static func save(_ material: StudyMaterial, context: ModelContext) {
        context.insert(material)
        try? context.save()
    }

    static func fetchAll(context: ModelContext) -> [StudyMaterial] {
        let descriptor = FetchDescriptor<StudyMaterial>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func delete(_ material: StudyMaterial, context: ModelContext) {
        context.delete(material)
        try? context.save()
    }

    static func saveSession(_ session: SessionResult, context: ModelContext) {
        context.insert(session)
        try? context.save()
    }

    static func fetchSessions(for materialID: UUID?, context: ModelContext) -> [SessionResult] {
        var descriptor = FetchDescriptor<SessionResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let materialID {
            descriptor.predicate = #Predicate { $0.materialID == materialID }
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
