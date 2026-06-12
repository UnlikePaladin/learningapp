import Foundation

/// Self-contained, JSON-serializable snapshot of a lesson.
/// Includes everything a recipient needs to study without re-running ingestion:
/// the original sources, the AI-generated modules + cards, and the embedded chunks
/// that power RAG. Embeddings are bundled so quizzes work immediately on import.
struct StudyPackExport: Codable {
    /// Bumped if we make breaking changes to the schema.
    static let currentVersion = 1

    var version: Int = StudyPackExport.currentVersion
    let title: String
    let createdBy: String?
    let createdAt: Date
    let exportedAt: Date

    let sources: [SourceExport]
    let modules: [ModuleExport]
}

struct SourceExport: Codable {
    let rawText: String
    let sourceType: String   // "camera" | "paste" | "pdf"
    let fileName: String?
    let dateAdded: Date
}

struct ModuleExport: Codable {
    let title: String
    let summary: String
    let explanation: String
    let order: Int
    let cards: [CardExport]
    let chunks: [ChunkExport]
}

struct CardExport: Codable {
    let title: String
    let explanation: String
    let order: Int
}

struct ChunkExport: Codable {
    let text: String
    let order: Int
    let embedding: [Double]
}
