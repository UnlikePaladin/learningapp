import SwiftUI
import SwiftData

@main
struct learningappApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Lesson.self,
            Source.self,
            Module.self,
            StoredChunk.self,
            StudyCard.self,
            CustomStudyPlan.self,
            SessionResult.self,
            ReviewSchedule.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed during development — wipe old store and retry
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingFile(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Called when the OS hands us a `.studypack` file (AirDrop receive, "Open in" from
    /// Files / Mail / Messages, etc.). Decodes and imports as a new lesson.
    @MainActor
    private func handleIncomingFile(_ url: URL) {
        guard url.pathExtension.lowercased() == "studypack" else { return }
        do {
            let pack = try StudyPackService.read(from: url)
            StudyPackService.importPack(pack, into: sharedModelContainer.mainContext)
        } catch {
            // Surfacing this requires UI plumbing; for now log and bail.
            // The user can also import via the Lessons tab → menu → Import Study Pack.
            print("Study pack import failed: \(error.localizedDescription)")
        }
    }
}
