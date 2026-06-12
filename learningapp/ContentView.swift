import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    @State private var showChat = false

    var body: some View {
        ZStack {
            if FoundationModelService.isAvailable {
                mainTabs
            } else {
                unavailableView
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.45)) {
                showSplash = false
            }
        }
    }

    private var mainTabs: some View {
        ZStack(alignment: .bottomTrailing) {
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
                Tab("You", systemImage: "person.crop.circle") {
                    ProfileView()
                }
            }

            Button {
                showChat = true
            } label: {
                Image("normal_giraffe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .padding(14)
                    .background(Color("Darkgreen"), in: Circle())
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 84)
        }
        .sheet(isPresented: $showChat) {
            GiraffeChatView()
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
