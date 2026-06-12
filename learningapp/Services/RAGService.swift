import Foundation
import SwiftData

struct ScoredChunk {
    let chunk: StoredChunk
    let score: Double
}

final class RAGService {
    private let embeddingService = EmbeddingService()
    private let maxContextChars = 2500

    enum Scope {
        case lesson(UUID)
        case module(UUID)
        case lessons([UUID])  // for custom plans
        case all
    }

    /// Retrieve top-K chunks most relevant to a query within the given scope.
    func retrieveRelevantChunks(
        query: String,
        scope: Scope,
        from context: ModelContext,
        topK: Int = 4
    ) -> [StoredChunk] {
        guard let queryVector = embeddingService.embed(query) else { return [] }

        let descriptor = FetchDescriptor<StoredChunk>()
        guard let allChunks = try? context.fetch(descriptor) else { return [] }

        let candidates: [StoredChunk]
        switch scope {
        case .lesson(let id):
            candidates = allChunks.filter { $0.lessonID == id }
        case .module(let id):
            candidates = allChunks.filter { $0.moduleID == id }
        case .lessons(let ids):
            let idSet = Set(ids)
            candidates = allChunks.filter { idSet.contains($0.lessonID) }
        case .all:
            candidates = allChunks
        }

        let scored = candidates
            .map { ScoredChunk(chunk: $0, score: CosineSimilarity.calculate(queryVector, $0.embedding)) }
            .sorted { $0.score > $1.score }

        var result: [StoredChunk] = []
        var charCount = 0
        for item in scored.prefix(topK) {
            if charCount + item.chunk.text.count > maxContextChars && !result.isEmpty { break }
            result.append(item.chunk)
            charCount += item.chunk.text.count
        }
        return result
    }

    func buildContext(from chunks: [StoredChunk]) -> String {
        chunks.enumerated().map { i, chunk in
            "[\(i + 1)] \(chunk.text)"
        }.joined(separator: "\n\n")
    }

    /// Find the chunks closest to the centroid of all chunk embeddings.
    func mostRepresentativeChunks(from embeddings: [(text: String, vector: [Double])], topK: Int = 3) -> [String] {
        guard !embeddings.isEmpty else { return [] }
        if embeddings.count <= topK { return embeddings.map(\.text) }

        let dim = embeddings[0].vector.count
        var centroid = [Double](repeating: 0, count: dim)
        for entry in embeddings {
            for i in 0..<dim { centroid[i] += entry.vector[i] }
        }
        for i in 0..<dim { centroid[i] /= Double(embeddings.count) }

        return embeddings
            .map { (text: $0.text, score: CosineSimilarity.calculate(centroid, $0.vector)) }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map(\.text)
    }
}
