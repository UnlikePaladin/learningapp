import SwiftUI
import SwiftData

struct LessonDetailView: View {
    @Bindable var lesson: Lesson
    @Query private var allModules: [Module]
    @Query private var allSources: [Source]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddSource = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var startingQuiz: QuizScope?
    @State private var coordinator = StudyCoordinator()

    var lessonModules: [Module] {
        allModules.filter { $0.lessonID == lesson.id }.sorted { $0.order < $1.order }
    }
    var lessonSources: [Source] {
        allSources.filter { $0.lessonID == lesson.id }.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    startingQuiz = QuizScope(kind: .lesson(lesson), title: lesson.title)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        Text("Quiz This Lesson")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(18)
                    .background(Color("Orange"), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Modules")
                        .font(.headline)
                    if lessonModules.isEmpty {
                        Text("Modules will appear once content is processed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lessonModules) { module in
                            moduleCard(module)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sources")
                            .font(.headline)
                        Spacer()
                        Button("Add Source", systemImage: "plus") {
                            showingAddSource = true
                        }
                        .font(.caption)
                    }
                    if lessonSources.isEmpty {
                        Text("No sources yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lessonSources) { source in
                            sourceRow(source)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(lesson.title.isEmpty ? "Lesson" : lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Rename Lesson", systemImage: "pencil") {
                    renameText = lesson.title
                    showingRename = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .alert("Rename Lesson", isPresented: $showingRename) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    lesson.title = renameText
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddSource) {
            ContentInputView { rawText, sourceType, fileName in
                Task {
                    await coordinator.addSource(
                        rawText: rawText,
                        sourceType: sourceType,
                        fileName: fileName,
                        to: lesson,
                        context: modelContext
                    )
                }
            }
        }
        .fullScreenCover(item: $startingQuiz) { scope in
            StudySessionView(scope: scope)
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

    private func moduleCard(_ module: Module) -> some View {
        NavigationLink {
            ModuleContentView(lesson: lesson, module: module)
        } label: {
            HStack(spacing: 0) {
                VStack {
                    Image(systemName: "book.pages.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(width: 58)
                .frame(maxHeight: .infinity)
                .background(Color("Darkgreen"))

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(module.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    if !module.summary.isEmpty {
                        Text(module.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 72)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func sourceRow(_ source: Source) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("Lightgreen").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconForSource(source.sourceType))
                    .font(.caption)
                    .foregroundStyle(Color("Lightgreen"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(source.fileName ?? sourceLabel(source.sourceType))
                    .font(.caption)
                    .lineLimit(1)
                Text(source.dateAdded, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func iconForSource(_ type: SourceType) -> String {
        switch type {
        case .camera: "camera.fill"
        case .pdf: "doc.fill"
        case .paste: "doc.text.fill"
        }
    }

    private func sourceLabel(_ type: SourceType) -> String {
        switch type {
        case .camera: "Camera scan"
        case .pdf: "PDF"
        case .paste: "Pasted text"
        }
    }
}
