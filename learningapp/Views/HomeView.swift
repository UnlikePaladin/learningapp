import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \StudyMaterial.dateAdded, order: .reverse) private var materials: [StudyMaterial]
    @State private var showingInput = false
    @State private var selectedMaterial: StudyMaterial?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Greeting header with streak
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ready to learn?")
                                .font(.largeTitle.bold())
                            Text("Small steps lead to big results.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StreakBadgeView()
                    }

                    // View Study Plan
                    NavigationLink {
                        StudyPlanView()
                    } label: {
                        Label("View Study Plan", systemImage: "list.clipboard")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)

                    // Start Studying button
                    Button {
                        showingInput = true
                    } label: {
                        Label("Start Studying", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // Recent materials
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Materials")
                            .font(.headline)

                        if materials.isEmpty {
                            ContentUnavailableView(
                                "No materials yet",
                                systemImage: "tray",
                                description: Text("Your recent study materials will appear here.")
                            )
                        } else {
                            ForEach(materials) { material in
                                NavigationLink {
                                    StudySessionView(material: material)
                                } label: {
                                    materialRow(material)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .sheet(isPresented: $showingInput) {
                ContentInputView(onSave: { material in
                    selectedMaterial = material
                })
            }
            .navigationDestination(item: $selectedMaterial) { material in
                StudySessionView(material: material)
            }
        }
    }

    private func materialRow(_ material: StudyMaterial) -> some View {
        HStack {
            Image(systemName: material.sourceType == .camera ? "camera.fill" : "doc.text.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(material.rawText.prefix(60) + (material.rawText.count > 60 ? "..." : ""))
                    .font(.subheadline)
                    .lineLimit(1)
                Text(material.dateAdded, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: StudyMaterial.self, inMemory: true)
}
