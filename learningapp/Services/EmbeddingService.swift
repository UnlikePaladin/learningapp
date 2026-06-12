import Foundation
import NaturalLanguage

final class EmbeddingService {
    private let model = NLEmbedding.sentenceEmbedding(for: .english)

    var isAvailable: Bool { model != nil }

    func embed(_ text: String) -> [Double]? {
        model?.vector(for: text)
    }

    func embedChunks(_ texts: [String]) -> [[Double]?] {
        texts.map { embed($0) }
    }
}
