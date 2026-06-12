import SwiftUI
import SwiftData

struct CreatePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]

    @State private var planName = ""
    @State private var selectedLessonIDs: Set<UUID> = []

    private var canCreate: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedLessonIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color("Darkgreen").opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "list.clipboard.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Color("Darkgreen"))
                        }
                        Text("New Study Plan")
                            .font(.title2.bold())
                        Text("Group lessons and quiz across all of them")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Plan name
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Plan Name", systemImage: "textformat")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color("Darkgreen"))

                        HStack(spacing: 12) {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                                .foregroundStyle(Color("Darkgreen"))
                                .frame(width: 20)
                            TextField("e.g., Biology Review", text: $planName)
                                .font(.body)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    planName.isEmpty ? Color.secondary.opacity(0.15) : Color("Darkgreen").opacity(0.4),
                                    lineWidth: 1.5
                                )
                        )
                        .animation(.easeInOut(duration: 0.15), value: planName.isEmpty)
                    }

                    // Lesson selection
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Select Lessons", systemImage: "book.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color("Darkgreen"))
                            Spacer()
                            if !selectedLessonIDs.isEmpty {
                                Text("\(selectedLessonIDs.count) selected")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color("Darkgreen").opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color("Darkgreen"))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.3), value: selectedLessonIDs.isEmpty)

                        if lessons.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("Add some lessons first.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            ForEach(lessons) { lesson in
                                lessonSelectCard(lesson)
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        let plan = CustomStudyPlan(
                            name: planName.trimmingCharacters(in: .whitespaces),
                            lessonIDs: Array(selectedLessonIDs)
                        )
                        modelContext.insert(plan)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Text("Create Plan")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(.white)
                            .background(
                                canCreate ? Color("Darkgreen") : Color.secondary.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .animation(.easeInOut(duration: 0.15), value: canCreate)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func lessonSelectCard(_ lesson: Lesson) -> some View {
        let isSelected = selectedLessonIDs.contains(lesson.id)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                toggle(lesson.id)
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

    private func toggle(_ id: UUID) {
        if selectedLessonIDs.contains(id) {
            selectedLessonIDs.remove(id)
        } else {
            selectedLessonIDs.insert(id)
        }
    }
}
