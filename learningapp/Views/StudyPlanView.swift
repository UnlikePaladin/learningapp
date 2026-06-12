import SwiftUI
import SwiftData

struct StudyPlanView: View {
    @Query(sort: \StudyMaterial.dateAdded, order: .reverse) private var materials: [StudyMaterial]
    @Query(sort: \SessionResult.date, order: .reverse) private var sessions: [SessionResult]
    @State private var plan: StudyPlan?
    @State private var isLoading = false
    @State private var selectedMaterial: StudyMaterial?
    @State private var aiService = FoundationModelService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generating your study plan...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else if let plan, !plan.items.isEmpty {
                    planList(plan.items)
                } else {
                    ContentUnavailableView("No study plan yet", systemImage: "list.clipboard", description: Text("Add study materials first, then generate a plan."))
                }
            }
            .navigationTitle("Study Plan")
            .toolbar {
                if !materials.isEmpty {
                    Button("Generate") { generatePlan() }
                        .disabled(isLoading)
                }
            }
            .navigationDestination(item: $selectedMaterial) { material in
                StudySessionView(material: material)
            }
        }
        .onAppear { if plan == nil && !materials.isEmpty { generatePlan() } }
    }

    private func planList(_ items: [StudyPlanItem]) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    planRow(item)
                }
            }
            .padding()
        }
    }

    private func planRow(_ item: StudyPlanItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor(item.priority))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.materialTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(item.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(item.suggestedDuration) min")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }

            Spacer()

            Button {
                selectedMaterial = materials.first { $0.id == item.materialID }
            } label: {
                Text("Start")
                    .font(.subheadline.bold())
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: .red
        case 2: .orange
        case 3: .yellow
        default: .green
        }
    }

    private func generatePlan() {
        isLoading = true
        Task {
            do {
                let result = try await aiService.generateStudyPlan(materials: materials, sessions: sessions)
                plan = result
            } catch {
                plan = nil
            }
            isLoading = false
        }
    }
}

#Preview {
    StudyPlanView()
        .modelContainer(for: StudyMaterial.self, inMemory: true)
}
