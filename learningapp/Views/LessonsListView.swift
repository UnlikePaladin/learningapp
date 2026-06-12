import SwiftUI
import SwiftData

struct LessonsListView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query private var modules: [Module]
    @Query private var sources: [Source]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var coordinator = StudyCoordinator()

    private let accentColors: [Color] = [
        Color("Orange"), Color("Lightgreen"), Color("Red"), Color("Yellow"), Color("Darkgreen")
    ]

    var body: some View {
        NavigationStack {
            Group {
                if lessons.isEmpty {
                    ContentUnavailableView(
                        "No lessons yet",
                        systemImage: "book.closed",
                        description: Text("Tap + to add your first lesson.")
                    )
                } else {
                    List {
                        ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                            NavigationLink {
                                LessonDetailView(lesson: lesson)
                            } label: {
                                lessonCard(lesson, index: index)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete(perform: deleteLessons)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Lessons")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Lesson", systemImage: "plus") {
                        showingInput = true
                    }
                }
            }
            .sheet(isPresented: $showingInput) {
                ContentInputView { rawText, sourceType, fileName in
                    Task {
                        await coordinator.createLesson(
                            rawText: rawText,
                            sourceType: sourceType,
                            fileName: fileName,
                            context: modelContext
                        )
                    }
                }
            }
            .overlay {
                if coordinator.isProcessing {
                    ingestionOverlay
                }
            }
        }
    }

    private func lessonCard(_ lesson: Lesson, index: Int) -> some View {
        let accent = accentColors[index % accentColors.count]
        let moduleCount = modules.filter { $0.lessonID == lesson.id }.count

        return HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.caption2)
                            Text("\(moduleCount) modules")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(accent)

                        Text(lesson.dateCreated, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
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

    private var ingestionOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: coordinator.ingestionProgress)
                .frame(width: 220)
            Text(coordinator.ingestionStatus.isEmpty ? "Processing..." : coordinator.ingestionStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func deleteLessons(at offsets: IndexSet) {
        for index in offsets {
            PersistenceService.delete(lessons[index], context: modelContext)
        }
    }
}
