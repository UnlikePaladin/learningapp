import Foundation
import FoundationModels

/// Snapshot of a chunk for the tool to search over. Captured at session creation time
/// so the tool stays Sendable (no live ModelContext dependency).
struct GlossarySnapshot: Sendable {
    let lessonTitle: String
    let moduleTitle: String
    let text: String
    let embedding: [Double]
}

/// Lets the model look up information from the user's own lessons. The model can call this
/// when explaining a concept that might be defined elsewhere in the user's library.
struct GlossaryLookupTool: Tool {
    let name = "lookupGlossary"
    let description = "Searches the user's other lessons for content related to a term. Returns up to 3 excerpts from related modules."

    let snapshots: [GlossarySnapshot]

    @Generable
    struct Arguments {
        @Guide(description: "The term, concept, or short question to look up across the user's lessons. E.g. 'photosynthesis', 'how does the water cycle work'.")
        var query: String
    }

    @Generable
    struct Result {
        @Guide(description: "Up to 3 relevant excerpts from the user's lessons.")
        var matches: [Match]
    }

    @Generable
    struct Match {
        @Guide(description: "The title of the lesson this excerpt came from.")
        var lesson: String
        @Guide(description: "The title of the module this excerpt came from.")
        var module: String
        @Guide(description: "The excerpt text.")
        var excerpt: String
    }

    func call(arguments: Arguments) async throws -> Result {
        let embeddingService = EmbeddingService()
        guard let queryVector = embeddingService.embed(arguments.query), !snapshots.isEmpty else {
            return Result(matches: [])
        }

        let scored = snapshots.map { snap -> (snap: GlossarySnapshot, score: Double) in
            (snap, CosineSimilarity.calculate(queryVector, snap.embedding))
        }.sorted { $0.score > $1.score }

        // Only return matches with a meaningful similarity score
        let topMatches = scored.prefix(3).filter { $0.score > 0.3 }

        return Result(matches: topMatches.map { entry in
            Match(
                lesson: entry.snap.lessonTitle,
                module: entry.snap.moduleTitle,
                excerpt: String(entry.snap.text.prefix(300))
            )
        })
    }
}
