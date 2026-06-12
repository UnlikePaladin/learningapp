import Foundation
import PDFKit

enum PDFExtractor {
    /// Extract and clean text from a PDF file at the given URL.
    static func extractText(from url: URL) -> String? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { return nil }

        var pageTexts: [String] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                pageTexts.append(pageText)
            }
        }

        let cleaned = clean(pageTexts: pageTexts)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cleaned
    }

    /// Clean PDF text by removing branding, headers, footers, URLs, and other noise.
    private static func clean(pageTexts: [String]) -> String {
        // Find lines that repeat across multiple pages (headers/footers)
        var lineCountAcrossPages: [String: Int] = [:]
        for pageText in pageTexts {
            let uniqueLines = Set(pageText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) })
            for line in uniqueLines {
                lineCountAcrossPages[line, default: 0] += 1
            }
        }
        let totalPages = pageTexts.count
        // Lines appearing on >50% of pages are likely headers/footers
        let repeatThreshold = max(2, totalPages / 2)
        let repeatedLines = Set(lineCountAcrossPages.filter { $0.value >= repeatThreshold }.keys)

        var allLines: [String] = []
        for pageText in pageTexts {
            for rawLine in pageText.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if shouldKeep(line: line, repeated: repeatedLines) {
                    allLines.append(line)
                }
            }
        }

        // Collapse runs of empty lines
        var result: [String] = []
        var lastWasEmpty = false
        for line in allLines {
            let isEmpty = line.isEmpty
            if isEmpty && lastWasEmpty { continue }
            result.append(line)
            lastWasEmpty = isEmpty
        }

        return result.joined(separator: "\n")
    }

    private static func shouldKeep(line: String, repeated: Set<String>) -> Bool {
        if line.isEmpty { return true } // keep paragraph breaks for now (collapsed later)
        if repeated.contains(line) { return false }

        let lower = line.lowercased()

        // Copyright / legal
        if line.contains("©") || line.contains("™") || line.contains("®") { return false }
        if lower.contains("copyright") || lower.contains("all rights reserved") { return false }
        if lower.hasPrefix("registered") || lower.hasPrefix("trademark") { return false }

        // URLs and emails
        if line.range(of: #"https?://"#, options: .regularExpression) != nil { return false }
        if line.range(of: #"www\.[^\s]+"#, options: .regularExpression) != nil { return false }
        if line.range(of: #"[\w\.-]+@[\w\.-]+"#, options: .regularExpression) != nil { return false }

        // Pure numbers (page numbers)
        if line.range(of: #"^\d+$"#, options: .regularExpression) != nil { return false }
        if line.range(of: #"^Page\s+\d+"#, options: [.regularExpression, .caseInsensitive]) != nil { return false }

        // Image-related captions and instructions
        if lower.hasPrefix("figure ") || lower.hasPrefix("fig.") { return false }
        if lower.contains("logo") && line.count < 80 { return false }
        if lower.hasPrefix("image:") || lower.hasPrefix("photo:") { return false }

        // Very short lines that aren't sentences (often headers, captions, branding)
        // Keep them if they look like a heading (e.g., "The Water Cycle")
        if line.count < 4 { return false }

        return true
    }
}
