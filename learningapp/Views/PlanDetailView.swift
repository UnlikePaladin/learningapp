import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Bindable var plan: CustomStudyPlan
    @Query private var allLessons: [Lesson]
    @Environment(\.modelContext) private var modelContext

    @State private var startingQuiz: QuizScope?
    @State private var showingEditLessons = false

    private let lessonAccents: [Color] = [
        Color("Darkgreen"), Color("Orange"), Color("Lightgreen"), Color("Red")
    ]

    var planLessons: [Lesson] {
        allLessons.filter { plan.lessonIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Stats card — inspired by Order Details info card
                HStack(spacing: 0) {
                    statCell(
                        icon: "book.fill",
                        value: "\(planLessons.count)",
                        label: "Lessons",
                        color: Color("Darkgreen")
                    )
                    Divider().frame(height: 40)
                    statCell(
                        icon: "list.clipboard.fill",
                        value: plan.lessonIDs.isEmpty ? "Empty" : "Active",
                        label: "Status",
                        color: plan.lessonIDs.isEmpty ? Color("Red") : Color("Lightgreen")
                    )
                }
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Lessons section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Lessons in Plan", systemImage: "book.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color("Darkgreen"))
                        Spacer()
                        Button {
                            showingEditLessons = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Edit")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("Darkgreen").opacity(0.1), in: Capsule())
                            .foregroundStyle(Color("Darkgreen"))
                        }
                        .buttonStyle(.plain)
                    }

                    if planLessons.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("No lessons in this plan yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        ForEach(Array(planLessons.enumerated()), id: \.element.id) { index, lesson in
                            NavigationLink {
                                LessonDetailView(lesson: lesson)
                            } label: {
                                lessonRow(lesson, accent: lessonAccents[index % lessonAccents.count])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding()
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button {
                    startingQuiz = QuizScope(kind: .plan(plan), title: plan.name)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: "play.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        Text("Quiz Across All Lessons")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        planLessons.isEmpty ? Color.secondary.opacity(0.4) : Color("Orange"),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .disabled(planLessons.isEmpty)
                .padding()
                .background(.regularMaterial)
            }
        }
        .fullScreenCover(item: $startingQuiz) { scope in
            StudySessionView(scope: scope)
        }
        .sheet(isPresented: $showingEditLessons) {
            EditPlanLessonsView(plan: plan)
        }
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func lessonRow(_ lesson: Lesson, accent: Color) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(lesson.dateCreated, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Edit Plan Lessons

struct EditPlanLessonsView: View {
    @Bindable var plan: CustomStudyPlan
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(lessons) { lesson in
                        lessonSelectCard(lesson)
                    }
                }
                .padding()
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
                    .fontWeight(.bold)
                    .foregroundStyle(Color("Darkgreen"))
                }
            }
            .onAppear {
                selectedIDs = Set(plan.lessonIDs)
            }
        }
    }

    private func lessonSelectCard(_ lesson: Lesson) -> some View {
        let isSelected = selectedIDs.contains(lesson.id)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                if selectedIDs.contains(lesson.id) {
                    selectedIDs.remove(lesson.id)
                } else {
                    selectedIDs.insert(lesson.id)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color("Darkgreen") : Color.secondary.opacity(0.12))
                        .frame(width: 30, height: 30)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(lesson.dateCreated, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color("Darkgreen").opacity(0.07) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color("Darkgreen").opacity(0.4) : Color.secondary.opacity(0.15),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
