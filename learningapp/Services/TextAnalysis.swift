import Foundation
import NaturalLanguage

enum TextAnalysis {
    /// Common English stopwords filtered out of key term extraction.
    private static let stopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "must", "shall", "can", "in", "on", "at",
        "to", "for", "of", "with", "by", "from", "as", "and", "or", "but",
        "not", "no", "if", "then", "else", "when", "where", "what", "who", "which",
        "how", "why", "this", "that", "these", "those", "i", "you", "he", "she",
        "it", "we", "they", "them", "their", "his", "her", "its", "our", "your",
        "my", "me", "us", "him", "also", "such", "any", "some", "all", "both",
        "each", "every", "more", "most", "other", "another", "than", "so", "very",
        "just", "only", "own", "same", "too", "into", "about", "above", "below",
        "out", "up", "down", "off", "over", "under", "again", "further", "once",
        "here", "there", "now", "even", "also", "called", "use", "used", "using",
        "make", "made", "get", "got", "see", "seen", "go", "goes", "going",
        "one", "two", "three", "first", "second", "many", "much", "few", "lot"
    ]

    /// Extract the top-N most frequent content words from text.
    /// Uses lemmatization so "cells" and "cell" count together; "running" → "run".
    static func extractKeyTerms(_ text: String, topN: Int = 8) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text

        var counts: [String: Int] = [:]
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: [.omitWhitespace, .omitPunctuation, .omitOther]) { tag, tokenRange in
            // Prefer the lemma; fall back to the original token
            let lemma = tag?.rawValue ?? String(text[tokenRange])
            let lower = lemma.lowercased()

            // Filter: must be at least 3 letters, all letters, not a stopword
            if lower.count >= 3,
               !stopwords.contains(lower),
               lower.allSatisfy({ $0.isLetter }) {
                counts[lower, default: 0] += 1
            }
            return true
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(topN)
            .map { $0.key }
    }
}
