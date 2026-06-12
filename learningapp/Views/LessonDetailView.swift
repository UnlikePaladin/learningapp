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
                // Quiz button - quiz the whole lesson
                Button {
                    startingQuiz = QuizScope(kind: .lesson(lesson), title: lesson.title)
                } label: {
                    Label("Quiz This Lesson", systemImage: "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)

                // Modules
                VStack(alignment: .leading, spacing: 12) {
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

                // Sources
                VStack(alignment: .leading, spacing: 12) {
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
            VStack(alignment: .leading, spacing: 6) {
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
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func sourceRow(_ source: Source) -> some View {
        HStack {
            Image(systemName: iconForSource(source.sourceType))
                .foregroundStyle(.blue)
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
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
