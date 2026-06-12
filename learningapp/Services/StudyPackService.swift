import Foundation
import SwiftData

enum StudyPackError: LocalizedError {
    case unsupportedVersion(Int)
    case readFailed(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "This study pack uses format version \(v), which this app version doesn't understand. Try updating the app."
        case .readFailed(let m):
            return "Couldn't read the study pack file: \(m)"
        case .decodeFailed(let m):
            return "The study pack file is corrupted or malformed: \(m)"
        }
    }
}

enum StudyPackService {
    // MARK: - Export

    /// Build a portable export of a lesson with everything a recipient needs to study it.
    static func makeExport(
        for lesson: Lesson,
        context: ModelContext,
        createdBy: String? = nil
    ) -> StudyPackExport {
        let lessonID = lesson.id

        // Sources for this lesson, sorted oldest-first to preserve the original order.
        let sources = (try? context.fetch(FetchDescriptor<Source>(
            predicate: #Predicate { $0.lessonID == lessonID }
        ))) ?? []
        let sortedSources = sources.sorted { $0.dateAdded < $1.dateAdded }
        let sourceExports = sortedSources.map { src in
            SourceExport(
                rawText: src.rawText,
                sourceType: src.sourceType.rawValue,
                fileName: src.fileName,
                dateAdded: src.dateAdded
            )
        }

        // Modules in order, with their cards and chunks.
        let modules = (try? context.fetch(FetchDescriptor<Module>(
            predicate: #Predicate { $0.lessonID == lessonID }
        ))) ?? []
        let sortedModules = modules.sorted { $0.order < $1.order }

        let allCards = (try? context.fetch(FetchDescriptor<StudyCard>(
            predicate: #Predicate { $0.lessonID == lessonID }
        ))) ?? []
        let allChunks = (try? context.fetch(FetchDescriptor<StoredChunk>(
            predicate: #Predicate { $0.lessonID == lessonID }
        ))) ?? []

        let moduleExports = sortedModules.map { module -> ModuleExport in
            let moduleID = module.id
            let moduleCards = allCards
                .filter { $0.moduleID == moduleID }
                .sorted { $0.order < $1.order }
                .map { CardExport(title: $0.title, explanation: $0.explanation, order: $0.order) }
            let moduleChunks = allChunks
                .filter { $0.moduleID == moduleID }
                .sorted { $0.order < $1.order }
                .map { ChunkExport(text: $0.text, order: $0.order, embedding: $0.embedding) }
            return ModuleExport(
                title: module.title,
                summary: module.summary,
                explanation: module.explanation,
                order: module.order,
                cards: moduleCards,
                chunks: moduleChunks
            )
        }

        return StudyPackExport(
            title: lesson.title.isEmpty ? "Untitled Lesson" : lesson.title,
            createdBy: createdBy,
            createdAt: lesson.dateCreated,
            exportedAt: Date(),
            sources: sourceExports,
            modules: moduleExports
        )
    }

    /// Encode an export as JSON data ready to write to disk.
    static func encode(_ pack: StudyPackExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(pack)
    }

    /// Write a pack to a temp `.studypack` file and return the URL. ShareLink uses this.
    static func writeToTempFile(_ pack: StudyPackExport) throws -> URL {
        let data = try encode(pack)
        let safeTitle = pack.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let baseName = safeTitle.isEmpty ? "lesson" : safeTitle
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension("studypack")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Decode

    static func decode(_ data: Data) throws -> StudyPackExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let pack = try decoder.decode(StudyPackExport.self, from: data)
            if pack.version > StudyPackExport.currentVersion {
                throw StudyPackError.unsupportedVersion(pack.version)
            }
            return pack
        } catch let e as StudyPackError {
            throw e
        } catch {
            throw StudyPackError.decodeFailed(error.localizedDescription)
        }
    }

    static func read(from url: URL) throws -> StudyPackExport {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            return try decode(data)
        } catch let e as StudyPackError {
            throw e
        } catch {
            throw StudyPackError.readFailed(error.localizedDescription)
        }
    }

    // MARK: - Import

    /// Insert the pack's contents into SwiftData as a new lesson. Returns the new Lesson.
    @discardableResult
    static func importPack(_ pack: StudyPackExport, into context: ModelContext) -> Lesson {
        // New lesson identity — never collide with an existing one.
        let lesson = Lesson(
            title: pack.title,
            dateCreated: pack.createdAt
        )
        context.insert(lesson)

        // Recreate sources
        for src in pack.sources {
            let sourceType = SourceType(rawValue: src.sourceType) ?? .paste
            let source = Source(
                lessonID: lesson.id,
                rawText: src.rawText,
                sourceType: sourceType,
                fileName: src.fileName,
                dateAdded: src.dateAdded
            )
            context.insert(source)
        }

        // For each module, recreate the module + its cards + its chunks
        // (we don't know which source each chunk originally came from once exported,
        // so chunks reference a synthetic placeholder source ID)
        let placeholderSourceID = UUID()
        for moduleExport in pack.modules {
            let module = Module(
                lessonID: lesson.id,
                title: moduleExport.title,
                summary: moduleExport.summary,
                explanation: moduleExport.explanation,
                order: moduleExport.order
            )
            context.insert(module)

            for cardExport in moduleExport.cards {
                let card = StudyCard(
                    moduleID: module.id,
                    lessonID: lesson.id,
                    title: cardExport.title,
                    explanation: cardExport.explanation,
                    order: cardExport.order
                )
                context.insert(card)
            }

            for chunkExport in moduleExport.chunks {
                let chunk = StoredChunk(
                    lessonID: lesson.id,
                    moduleID: module.id,
                    sourceID: placeholderSourceID,
                    text: chunkExport.text,
                    order: chunkExport.order,
                    embedding: chunkExport.embedding
                )
                context.insert(chunk)
            }
        }

        try? context.save()
        return lesson
    }
}
