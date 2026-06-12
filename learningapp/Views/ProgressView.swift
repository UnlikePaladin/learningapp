import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                ProgressDashboardContent()
                    .padding()
            }
            .background(Color("Darkgreen").opacity(0.05).ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: SessionResult.self, inMemory: true)
}
