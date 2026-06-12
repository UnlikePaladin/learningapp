import Foundation
import SwiftData

enum SourceType: String, Codable {
    case camera
    case paste
}

@Model
final class StudyMaterial {
    @Attribute(.unique) var id: UUID
    var rawText: String
    var title: String
    var sourceType: SourceType
    var dateAdded: Date

    init(id: UUID = UUID(), rawText: String, title: String = "", sourceType: SourceType, dateAdded: Date = Date()) {
        self.id = id
        self.rawText = rawText
        self.title = title
        self.sourceType = sourceType
        self.dateAdded = dateAdded
    }
}

@Model
final class StoredChunk {
    @Attribute(.unique) var id: UUID
    var materialID: UUID
    var text: String
    var order: Int
    var embedding: [Double]

    init(id: UUID = UUID(), materialID: UUID, text: String, order: Int, embedding: [Double]) {
        self.id = id
        self.materialID = materialID
        self.text = text
        self.order = order
        self.embedding = embedding
    }
}

struct Chunk: Identifiable, Codable {
    var id: UUID = UUID()
    var summary: String
    var keyPoints: [String]
    var originalText: String
    var order: Int
}

struct Question: Identifiable, Codable {
    var id: UUID = UUID()
    var prompt: String
    var expectedAnswer: String
    var difficulty: Int
}

struct Feedback: Codable {
    var isCorrect: Bool
    var explanation: String
    var encouragement: String
}

enum QuestionStyle: String, Codable, CaseIterable {
    case eli5, analogy, realWorld, whatIf
}

struct StudyPlanItem: Identifiable, Codable {
    var id: UUID = UUID()
    var materialID: UUID
    var materialTitle: String
    var priority: Int
    var reason: String
    var suggestedDuration: Int
}

struct StudyPlan: Identifiable, Codable {
    var id: UUID = UUID()
    var items: [StudyPlanItem]
    var generatedDate: Date = Date()
}

@Model
final class SessionResult {
    @Attribute(.unique) var id: UUID
    var questionsAnswered: Int
    var correctCount: Int
    var duration: TimeInterval
    var date: Date
    var materialID: UUID

    init(id: UUID = UUID(), questionsAnswered: Int, correctCount: Int, duration: TimeInterval, date: Date = Date(), materialID: UUID) {
        self.id = id
        self.questionsAnswered = questionsAnswered
        self.correctCount = correctCount
        self.duration = duration
        self.date = date
        self.materialID = materialID
    }
}

