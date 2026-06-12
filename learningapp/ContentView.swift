import SwiftUI

struct ContentView: View {
    var body: some View {
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
}

#Preview {
    ContentView()
}
