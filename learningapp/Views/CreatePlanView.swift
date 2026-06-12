import SwiftUI
import SwiftData

struct CreatePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]

    @State private var planName = ""
    @State private var selectedLessonIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Name") {
                    TextField("e.g., Biology Review", text: $planName)
                }

                Section {
                    if lessons.isEmpty {
                        Text("Add some lessons first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lessons) { lesson in
                            Button {
                                toggle(lesson.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedLessonIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedLessonIDs.contains(lesson.id) ? Color.accentColor : Color.secondary)
                                    Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Select Lessons")
                } footer: {
                    Text("\(selectedLessonIDs.count) selected")
                        .font(.caption)
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let plan = CustomStudyPlan(
                            name: planName.trimmingCharacters(in: .whitespaces),
                            lessonIDs: Array(selectedLessonIDs)
                        )
                        modelContext.insert(plan)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespaces).isEmpty || selectedLessonIDs.isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedLessonIDs.contains(id) {
            selectedLessonIDs.remove(id)
        } else {
            selectedLessonIDs.insert(id)
        }
    }
}
