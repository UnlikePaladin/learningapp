import Foundation

struct ChunkWithEmbedding {
    let text: String
    let vector: [Double]
    let sourceID: UUID
    let order: Int
}

struct ClusteredModule {
    var chunks: [ChunkWithEmbedding]
}

/// Groups chunks into modules using TextTiling on embedding similarities.
/// Enforces a minimum module size and merges adjacent small modules.
enum ModuleClusteringService {
    private static let minChunksPerModule = 3
    private static let absoluteMinForSplit = 6

    static func cluster(chunks: [ChunkWithEmbedding]) -> [ClusteredModule] {
        let total = chunks.count
        guard !chunks.isEmpty else { return [] }

        // Short lessons → single module. Splitting tiny content is just noise.
        if total < absoluteMinForSplit {
            return [ClusteredModule(chunks: chunks)]
        }

        // Compute consecutive similarities
        var sims: [Double] = []
        sims.reserveCapacity(total - 1)
        for i in 0..<(total - 1) {
            sims.append(CosineSimilarity.calculate(chunks[i].vector, chunks[i + 1].vector))
        }

        let mean = sims.reduce(0, +) / Double(sims.count)
        let variance = sims.map { pow($0 - mean, 2) }.reduce(0, +) / Double(sims.count)
        let stddev = sqrt(variance)

        // Conservative threshold: only split where similarity drops more than 1 stddev below mean.
        // This avoids over-segmenting when the document is consistently on-topic.
        let threshold = mean - stddev

        // Initial boundaries
        var boundaries: [Int] = []
        for (i, sim) in sims.enumerated() {
            if sim < threshold {
                boundaries.append(i + 1)
            }
        }

        // Build initial modules from boundaries
        var modules: [[ChunkWithEmbedding]] = []
        var startIdx = 0
        for boundary in boundaries {
            modules.append(Array(chunks[startIdx..<boundary]))
            startIdx = boundary
        }
        modules.append(Array(chunks[startIdx..<total]))

        // Merge any module smaller than minChunksPerModule with a neighbor
        modules = mergeSmallModules(modules)

        // Hard cap: never have more than ⌈total / minChunksPerModule⌉ modules
        let maxAllowed = max(1, total / minChunksPerModule)
        while modules.count > maxAllowed {
            // Find the smallest adjacent pair and merge them
            var smallestIdx = 0
            var smallestSize = Int.max
            for i in 0..<(modules.count - 1) {
                let combined = modules[i].count + modules[i + 1].count
                if combined < smallestSize {
                    smallestSize = combined
                    smallestIdx = i
                }
            }
            modules[smallestIdx].append(contentsOf: modules[smallestIdx + 1])
            modules.remove(at: smallestIdx + 1)
        }

        return modules.map { ClusteredModule(chunks: $0) }
    }

    private static func mergeSmallModules(_ input: [[ChunkWithEmbedding]]) -> [[ChunkWithEmbedding]] {
        var modules = input
        var i = 0
        while i < modules.count {
            if modules[i].count < minChunksPerModule && modules.count > 1 {
                if i == modules.count - 1 {
                    // Last module — merge backward
                    modules[i - 1].append(contentsOf: modules[i])
                    modules.remove(at: i)
                } else if i == 0 {
                    // First module — merge forward
                    modules[i + 1] = modules[i] + modules[i + 1]
                    modules.remove(at: i)
                } else {
                    // Middle — merge with whichever neighbor is smaller
                    if modules[i - 1].count <= modules[i + 1].count {
                        modules[i - 1].append(contentsOf: modules[i])
                        modules.remove(at: i)
                    } else {
                        modules[i + 1] = modules[i] + modules[i + 1]
                        modules.remove(at: i)
                    }
                }
                // Don't increment — re-check the new module at this index
            } else {
                i += 1
            }
        }
        return modules
    }
}
