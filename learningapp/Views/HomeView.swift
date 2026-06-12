import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query(sort: \SessionResult.date, order: .reverse) private var sessions: [SessionResult]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var coordinator = StudyCoordinator()

    private var recentLessons: [Lesson] { Array(lessons.prefix(4)) }

    private let tileColors: [Color] = [
        Color("Orange"), Color("Lightgreen"), Color("Red"), Color("Darkgreen")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to learn?")
                                .font(.largeTitle.bold())
                            Text("Small steps lead to big results.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StreakBadgeView()
                    }
                    .padding(.top, 4)

                    Button {
                        showingInput = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add New Lesson")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                Text("Paste text, scan, or import PDF")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(18)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent Lessons")
                            .font(.headline)

                        if recentLessons.isEmpty {
                            ContentUnavailableView(
                                "No lessons yet",
                                systemImage: "book.closed",
                                description: Text("Tap above to create your first lesson.")
                            )
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 14
                            ) {
                                ForEach(Array(recentLessons.enumerated()), id: \.element.id) { index, lesson in
                                    NavigationLink {
                                        LessonDetailView(lesson: lesson)
                                    } label: {
                                        lessonTile(lesson, color: tileColors[index % tileColors.count])
                                    }
                                    .buttonStyle(.plain)
                                }
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

    private func lessonTile(_ lesson: Lesson, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Text(lesson.title.isEmpty ? "Untitled" : lesson.title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(lesson.dateCreated, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    HomeView()
}
