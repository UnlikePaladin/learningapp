import SwiftUI
import SwiftData

struct CustomPlansListView: View {
    @Query(sort: \CustomStudyPlan.dateCreated, order: .reverse) private var plans: [CustomStudyPlan]
    @Query private var lessons: [Lesson]
    @Environment(\.modelContext) private var modelContext

    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet",
                        systemImage: "list.clipboard",
                        description: Text("Create a study plan to group lessons you want to study together.")
                    )
                } else {
                    List {
                        ForEach(plans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                planRow(plan)
                            }
                        }
                        .onDelete(perform: deletePlans)
                    }
                }
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Plan", systemImage: "plus") {
                        showingCreate = true
                    }
                    .disabled(lessons.isEmpty)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView()
            }
        }
    }

    private func planRow(_ plan: CustomStudyPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.name)
                .font(.headline)
            Text("\(plan.lessonIDs.count) lessons")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
    }
}
