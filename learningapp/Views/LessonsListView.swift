import SwiftUI
import SwiftData

struct LessonsListView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query private var modules: [Module]
    @Query private var sources: [Source]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var coordinator = StudyCoordinator()

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
                        ForEach(lessons) { lesson in
                            NavigationLink {
                                LessonDetailView(lesson: lesson)
                            } label: {
                                lessonRow(lesson)
                            }
                        }
                        .onDelete(perform: deleteLessons)
                    }
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

    private func lessonRow(_ lesson: Lesson) -> some View {
        let moduleCount = modules.filter { $0.lessonID == lesson.id }.count
        let sourceCount = sources.filter { $0.lessonID == lesson.id }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 12) {
                Label("\(moduleCount) modules", systemImage: "square.stack.3d.up")
                Label("\(sourceCount) sources", systemImage: "doc.text")
                Text(lesson.dateCreated, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
