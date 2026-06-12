import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query(sort: \SessionResult.date, order: .reverse) private var sessions: [SessionResult]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var coordinator = StudyCoordinator()

    private var recentLessons: [Lesson] { Array(lessons.prefix(3)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
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

                    // Quick add
                    Button {
                        showingInput = true
                    } label: {
                        Label("Add New Lesson", systemImage: "plus.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)

                    // Recent lessons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Lessons")
                            .font(.headline)
                        if recentLessons.isEmpty {
                            ContentUnavailableView(
                                "No lessons yet",
                                systemImage: "book.closed",
                                description: Text("Tap above to create your first lesson.")
                            )
                        } else {
                            ForEach(recentLessons) { lesson in
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
            .navigationTitle("Home")
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
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            Image(systemName: "book.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                    .font(.subheadline.bold())
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
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    HomeView()
}
