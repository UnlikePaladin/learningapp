import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Study", systemImage: "book") {
                StudySessionView()
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
