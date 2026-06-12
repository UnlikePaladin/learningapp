import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Custom file type for shared lessons. Conforms to public.json since the payload is JSON.
    /// For full integration (so iOS opens .studypack files in this app from Files / AirDrop),
    /// this UTI must also be declared in the target's Info.plist under
    /// "Exported Type Identifiers" + "Document Types". See the README in this folder.
    static let studyPack = UTType(exportedAs: "com.mangolassiglazers.learningapp.studypack")
}

/// Wraps a `StudyPackExport` so SwiftUI's `ShareLink` can hand it off to AirDrop, Mail,
/// Messages, etc. The encoded JSON is written to a temp file with a `.studypack` extension.
struct StudyPackFile: Transferable {
    let pack: StudyPackExport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .studyPack) { item in
            let url = try StudyPackService.writeToTempFile(item.pack)
            return SentTransferredFile(url)
        }
    }
}
