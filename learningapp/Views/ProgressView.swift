import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                ProgressDashboardContent()
                    .padding()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                GiraffeBannerView(
                    title: "My Progress",
                    subtitle: "Good job!",
                    giraffeImage: "clear_happy_giraffe"
                )
            }
            .background(Color("Darkgreen").opacity(0.05).ignoresSafeArea())
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: SessionResult.self, inMemory: true)
}
