import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Bindable var plan: CustomStudyPlan
    @Query private var allLessons: [Lesson]
    @Environment(\.modelContext) private var modelContext

    @State private var startingQuiz: QuizScope?
    @State private var showingEditLessons = false

    var planLessons: [Lesson] {
        allLessons.filter { plan.lessonIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    startingQuiz = QuizScope(kind: .plan(plan), title: plan.name)
                } label: {
                    Label("Quiz Across All Lessons", systemImage: "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(planLessons.isEmpty)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lessons in Plan")
                            .font(.headline)
                        Spacer()
                        Button("Edit", systemImage: "pencil") {
                            showingEditLessons = true
                        }
                        .font(.caption)
                    }

                    if planLessons.isEmpty {
                        Text("No lessons in this plan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(planLessons) { lesson in
                            NavigationLink {
                                LessonDetailView(lesson: lesson)
                            } label: {
                                lessonRow(lesson)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $startingQuiz) { scope in
            StudySessionView(scope: scope)
        }
        .sheet(isPresented: $showingEditLessons) {
            EditPlanLessonsView(plan: plan)
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            Image(systemName: "book.fill")
                .foregroundStyle(.blue)
            Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct EditPlanLessonsView: View {
    @Bindable var plan: CustomStudyPlan
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(lessons) { lesson in
                    Button {
                        toggle(lesson.id)
                    } label: {
                        HStack {
                            Image(systemName: selectedIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(lesson.id) ? Color.accentColor : Color.secondary)
                            Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Edit Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        plan.lessonIDs = Array(selectedIDs)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedIDs = Set(plan.lessonIDs)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
}
