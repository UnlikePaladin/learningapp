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
}
