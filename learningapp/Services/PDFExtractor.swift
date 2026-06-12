import Foundation
import PDFKit

enum PDFExtractor {
    /// Extract and clean text from a PDF file at the given URL.
    /// Always runs Vision OCR on every page so handwritten annotations over digital PDFs are captured.
    static func extractText(
        from url: URL,
        progress: ((Double, String) -> Void)? = nil
    ) async -> String? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { return nil }
        let totalPages = document.pageCount

        var pageTexts: [String] = []
        for i in 0..<totalPages {
            guard let page = document.page(at: i) else { continue }
            progress?(Double(i) / Double(totalPages), "Recognizing page \(i + 1) of \(totalPages)...")

            // Always OCR — this captures both digital text and handwritten annotations
            var text = ""
            if let cgImage = OCRService.renderPage(page),
               let ocrText = try? await OCRService.recognizeText(in: cgImage) {
                text = ocrText
            }

            // Fall back to page.string only if OCR returned nothing
            if text.isEmpty {
                text = page.string ?? ""
            }

            pageTexts.append(text)
        }

        progress?(1.0, "Cleaning text...")
        let cleaned = clean(pageTexts: pageTexts)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cleaned
    }

    /// Clean PDF text by removing branding, headers, footers, URLs, and other noise.
    private static func clean(pageTexts: [String]) -> String {
        var lineCountAcrossPages: [String: Int] = [:]
        for pageText in pageTexts {
            let uniqueLines = Set(pageText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) })
            for line in uniqueLines {
                lineCountAcrossPages[line, default: 0] += 1
            }
        }
        let totalPages = pageTexts.count
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
        if line.isEmpty { return true }
        if repeated.contains(line) { return false }

        let lower = line.lowercased()

        if line.contains("©") || line.contains("™") || line.contains("®") { return false }
        if lower.contains("copyright") || lower.contains("all rights reserved") { return false }
        if lower.hasPrefix("registered") || lower.hasPrefix("trademark") { return false }

        if line.range(of: #"https?://"#, options: .regularExpression) != nil { return false }
        if line.range(of: #"www\.[^\s]+"#, options: .regularExpression) != nil { return false }
        if line.range(of: #"[\w\.-]+@[\w\.-]+"#, options: .regularExpression) != nil { return false }

        if line.range(of: #"^\d+$"#, options: .regularExpression) != nil { return false }
        if line.range(of: #"^Page\s+\d+"#, options: [.regularExpression, .caseInsensitive]) != nil { return false }

        if lower.hasPrefix("figure ") || lower.hasPrefix("fig.") { return false }
        if lower.contains("logo") && line.count < 80 { return false }
        if lower.hasPrefix("image:") || lower.hasPrefix("photo:") { return false }

        if line.count < 4 { return false }

        return true
    }
}
