import SwiftUI
import SwiftData

struct LessonsListView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query private var modules: [Module]
    @Query private var sources: [Source]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var coordinator = StudyCoordinator()

    private let cardColors: [Color] = [
        Color("Orange"), Color("Lightgreen"), Color("Red"), Color("Darkgreen")
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
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                        .onDelete(perform: deleteLessons)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color("Darkgreen").opacity(0.05).ignoresSafeArea())
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
        let color = cardColors[index % cardColors.count]
        let moduleCount = modules.filter { $0.lessonID == lesson.id }.count

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.caption)
                    Text("\(moduleCount) modules")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white.opacity(0.85))

                Text(lesson.dateCreated, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.6))
                .font(.subheadline)
        }
        .padding(16)
        .background(color, in: RoundedRectangle(cornerRadius: 16))
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
