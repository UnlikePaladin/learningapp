import Foundation
import SwiftData

enum SourceType: String, Codable {
    case camera
    case paste
    case pdf
}

// MARK: - Lesson (top-level concept)

@Model
final class Lesson {
    @Attribute(.unique) var id: UUID
    var title: String
    var dateCreated: Date

    init(id: UUID = UUID(), title: String = "", dateCreated: Date = Date()) {
        self.id = id
        self.title = title
        self.dateCreated = dateCreated
    }
}

// MARK: - Source (raw input attached to a lesson)

@Model
final class Source {
    @Attribute(.unique) var id: UUID
    var lessonID: UUID
    var rawText: String
    var sourceType: SourceType
    var fileName: String?
    var dateAdded: Date

    init(id: UUID = UUID(), lessonID: UUID, rawText: String, sourceType: SourceType, fileName: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.lessonID = lessonID
        self.rawText = rawText
        self.sourceType = sourceType
        self.fileName = fileName
        self.dateAdded = dateAdded
    }
}

// MARK: - Module (auto-generated topical group)

@Model
final class Module {
    @Attribute(.unique) var id: UUID
    var lessonID: UUID
    var title: String
    var summary: String
    /// AI-generated tutor-style explanation of the module's content. Generated lazily on first view.
    var explanation: String
    var order: Int

    init(id: UUID = UUID(), lessonID: UUID, title: String, summary: String = "", explanation: String = "", order: Int) {
        self.id = id
        self.lessonID = lessonID
        self.title = title
        self.summary = summary
        self.explanation = explanation
        self.order = order
    }
}

// MARK: - Study Cards (flashcards for ADHD-friendly carousel study)

@Model
final class StudyCard {
    @Attribute(.unique) var id: UUID
    var moduleID: UUID
    var lessonID: UUID
    var title: String
    var explanation: String
    var order: Int

    init(id: UUID = UUID(), moduleID: UUID, lessonID: UUID, title: String, explanation: String, order: Int) {
        self.id = id
        self.moduleID = moduleID
        self.lessonID = lessonID
        self.title = title
        self.explanation = explanation
        self.order = order
    }
}

// MARK: - StoredChunk (now belongs to a Module)

@Model
final class StoredChunk {
    @Attribute(.unique) var id: UUID
    var lessonID: UUID
    var moduleID: UUID
    var sourceID: UUID
    var text: String
    var order: Int
    var embedding: [Double]

    init(id: UUID = UUID(), lessonID: UUID, moduleID: UUID, sourceID: UUID, text: String, order: Int, embedding: [Double]) {
        self.id = id
        self.lessonID = lessonID
        self.moduleID = moduleID
        self.sourceID = sourceID
        self.text = text
        self.order = order
        self.embedding = embedding
    }
}

// MARK: - Custom Study Plan (user-created opt-in grouping)

@Model
final class CustomStudyPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var lessonIDs: [UUID]
    var dateCreated: Date

    init(id: UUID = UUID(), name: String, lessonIDs: [UUID] = [], dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.lessonIDs = lessonIDs
        self.dateCreated = dateCreated
    }
}

// MARK: - Session result (now references lesson + optional module)

@Model
final class SessionResult {
    @Attribute(.unique) var id: UUID
    var lessonID: UUID
    var moduleID: UUID?
    var planID: UUID?
    var questionsAnswered: Int
    var correctCount: Int
    var duration: TimeInterval
    var date: Date

    init(id: UUID = UUID(), lessonID: UUID, moduleID: UUID? = nil, planID: UUID? = nil, questionsAnswered: Int, correctCount: Int, duration: TimeInterval, date: Date = Date()) {
        self.id = id
        self.lessonID = lessonID
        self.moduleID = moduleID
        self.planID = planID
        self.questionsAnswered = questionsAnswered
        self.correctCount = correctCount
        self.duration = duration
        self.date = date
    }
}

// MARK: - Plain types used for AI generation / quiz

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

// MARK: - Suggested study plan (AI-generated suggestion, distinct from CustomStudyPlan)

struct SuggestedPlanItem: Identifiable, Codable {
    var id: UUID = UUID()
    var lessonID: UUID
    var lessonTitle: String
    var priority: Int
    var reason: String
    var suggestedDuration: Int
}

struct SuggestedStudyPlan: Identifiable, Codable {
    var id: UUID = UUID()
    var items: [SuggestedPlanItem]
    var generatedDate: Date = Date()
}
