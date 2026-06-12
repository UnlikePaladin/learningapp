import Foundation

/// Fast, deterministic heuristic that decides whether a chunk of text is
/// meaningful educational content vs boilerplate (branding, headers, captions, etc.).
/// Replaces a per-chunk AI call which was prohibitively slow for long PDFs.
enum LocalContentFilter {
    /// Returns true when the chunk looks like prose content worth keeping.
    static func isLikelyContent(_ chunk: String) -> Bool {
        let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 30 { return false }

        let lower = trimmed.lowercased()

        // Hard rejects — boilerplate fingerprints
        if trimmed.contains("©") || trimmed.contains("™") || trimmed.contains("®") { return false }
        if lower.contains("copyright") || lower.contains("all rights reserved") { return false }
        if lower.hasPrefix("page ") && trimmed.count < 80 { return false }
        if lower.hasPrefix("figure ") && trimmed.count < 120 { return false }
        if lower.hasPrefix("table of contents") { return false }

        // URL/email-dominated short blocks (contact pages, footers)
        let urlMatches = trimmed.matches(of: /https?:\/\/[^\s]+|www\.[^\s]+|[\w\.-]+@[\w\.-]+/).count
        if urlMatches >= 2 && trimmed.count < 300 { return false }

        // Word stats
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        let wordCount = words.count
        if wordCount < 6 { return false }

        // Excessive ALL-CAPS words suggests headers/branding (e.g., "ANGLIAN WATER LESSON 1")
        let capsWords = words.filter { word -> Bool in
            let letters = word.filter { $0.isLetter }
            guard letters.count >= 3 else { return false }
            return letters.allSatisfy { $0.isUppercase }
        }.count
        let capsRatio = Double(capsWords) / Double(wordCount)
        if capsRatio > 0.4 { return false }

        // Numeric-heavy short blocks (data tables, page lists)
        let digitChars = trimmed.filter { $0.isNumber }.count
        if Double(digitChars) / Double(trimmed.count) > 0.35 { return false }

        // Score-based content check: prose typically has sentences
        let periodCount = trimmed.filter { $0 == "." }.count
        let endsWithSentence = ".!?".contains(trimmed.last ?? " ")

        var score = 0
        if endsWithSentence { score += 1 }
        if periodCount >= 1 { score += 1 }
        if wordCount >= 15 { score += 1 }
        if wordCount >= 30 { score += 1 }
        // Has at least one common English filler word — strong prose signal
        let proseWords: Set<String> = ["the", "is", "are", "was", "were", "of", "a", "an", "and", "or", "but", "that", "this"]
        if words.contains(where: { proseWords.contains($0.lowercased()) }) { score += 1 }

        return score >= 3
    }
}
