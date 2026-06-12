import SwiftUI
import SwiftData
import FirebaseCore

@main
struct learningappApp: App {
    @State private var authService: AuthService

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
            UserProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
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

    init() {
        FirebaseApp.configure()          // must run first
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .onOpenURL { url in
                    handleIncomingFile(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func handleIncomingFile(_ url: URL) {
        guard url.pathExtension.lowercased() == "studypack" else { return }
        do {
            let pack = try StudyPackService.read(from: url)
            StudyPackService.importPack(pack, into: sharedModelContainer.mainContext)
        } catch {
            print("Study pack import failed: \(error.localizedDescription)")
        }
    }
}
