import Foundation
import SwiftData

struct ScoredChunk {
    let chunk: StoredChunk
    let score: Double
}

final class RAGService {
    private let embeddingService = EmbeddingService()

    /// Maximum characters of context to pass to the model (~1000 tokens ≈ 4000 chars).
    /// Leaves room for prompt instructions + output within 4096 token budget.
    private let maxContextChars = 2500

    /// Retrieve top-K chunks most relevant to a query.
    func retrieveRelevantChunks(
        query: String,
        from context: ModelContext,
        materialID: UUID? = nil,
        topK: Int = 3
    ) -> [StoredChunk] {
        guard let queryVector = embeddingService.embed(query) else { return [] }

        let descriptor = FetchDescriptor<StoredChunk>()
        guard let allChunks = try? context.fetch(descriptor) else { return [] }

        let candidates = materialID == nil
            ? allChunks
            : allChunks.filter { $0.materialID == materialID }

        let scored = candidates
            .map { ScoredChunk(chunk: $0, score: CosineSimilarity.calculate(queryVector, $0.embedding)) }
            .sorted { $0.score > $1.score }

        // Take top-K but also respect token budget
        var result: [StoredChunk] = []
        var charCount = 0
        for item in scored.prefix(topK) {
            if charCount + item.chunk.text.count > maxContextChars && !result.isEmpty { break }
            result.append(item.chunk)
            charCount += item.chunk.text.count
        }
        return result
    }

    /// Build a context string from retrieved chunks for injection into prompts.
    func buildContext(from chunks: [StoredChunk]) -> String {
        chunks.enumerated().map { i, chunk in
            "[\(i + 1)] \(chunk.text)"
        }.joined(separator: "\n\n")
    }

    /// Find the chunks closest to the centroid of all chunk embeddings.
    /// These are the most semantically "central" / representative chunks of the material.
    func mostRepresentativeChunks(from embeddings: [(text: String, vector: [Double])], topK: Int = 3) -> [String] {
        guard !embeddings.isEmpty else { return [] }
        if embeddings.count <= topK { return embeddings.map(\.text) }

        // Compute centroid
        let dim = embeddings[0].vector.count
        var centroid = [Double](repeating: 0, count: dim)
        for entry in embeddings {
            for i in 0..<dim { centroid[i] += entry.vector[i] }
        }
        for i in 0..<dim { centroid[i] /= Double(embeddings.count) }

        // Sort by similarity to centroid
        return embeddings
            .map { (text: $0.text, score: CosineSimilarity.calculate(centroid, $0.vector)) }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map(\.text)
    }
}
