import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query(sort: \SessionResult.date, order: .reverse) private var sessions: [SessionResult]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var coordinator = StudyCoordinator()

    private var recentLessons: [Lesson] { Array(lessons.prefix(3)) }

    private let cardColors: [Color] = [
        Color("Orange"), Color("Lightgreen"), Color("Red"), Color("Yellow"), Color("Darkgreen")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add New Lesson")
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Lessons")
                            .font(.headline)
                        if recentLessons.isEmpty {
                            ContentUnavailableView(
                                "No lessons yet",
                                systemImage: "book.closed",
                                description: Text("Tap above to create your first lesson.")
                            )
                        } else {
                            ForEach(Array(recentLessons.enumerated()), id: \.element.id) { index, lesson in
                                NavigationLink {
                                    LessonDetailView(lesson: lesson)
                                } label: {
                                    lessonCard(lesson, accent: cardColors[index % cardColors.count])
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

    private func lessonCard(_ lesson: Lesson, accent: Color) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
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
            .padding(.vertical, 14)
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

#Preview {
    HomeView()
}
