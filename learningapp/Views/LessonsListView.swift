import SwiftUI
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LessonsListView: View {
    @Query(sort: \Lesson.dateCreated, order: .reverse) private var lessons: [Lesson]
    @Query private var modules: [Module]
    @Query private var sources: [Source]
    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var showingFileImporter = false
    @State private var importErrorMessage: String? = nil
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
            .safeAreaInset(edge: .top, spacing: 0) {
                GiraffeBannerView(
                    title: "My Lessons",
                    subtitle: "Your study library",
                    giraffeImage: "question_giraffe"
                )
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Lesson", systemImage: "plus") {
                            showingInput = true
                        }
                        Button("Import Study Pack", systemImage: "square.and.arrow.down") {
                            showingFileImporter = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.studyPack, .json]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let pack = try StudyPackService.read(from: url)
                        StudyPackService.importPack(pack, into: modelContext)
                    } catch {
                        importErrorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                }
            }
            .alert(
                "Couldn't Import",
                isPresented: .init(
                    get: { importErrorMessage != nil },
                    set: { if !$0 { importErrorMessage = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(importErrorMessage ?? "")
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
