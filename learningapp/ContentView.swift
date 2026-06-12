import SwiftUI

struct ContentView: View {
    var body: some View {
        if FoundationModelService.isAvailable {
            mainTabs
        } else {
            unavailableView
        }
    }

    private var mainTabs: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Lessons", systemImage: "book") {
                LessonsListView()
            }
            Tab("Plans", systemImage: "list.clipboard") {
                CustomPlansListView()
            }
            Tab("Progress", systemImage: "chart.bar") {
                ProgressDashboardView()
            }
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Apple Intelligence Required", systemImage: "apple.intelligence")
        } description: {
            Text(FoundationModelService.unavailabilityReason ?? "This app needs Apple Intelligence enabled to work.")
        } actions: {
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
}
