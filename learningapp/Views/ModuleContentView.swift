import SwiftUI
import SwiftData

struct ModuleContentView: View {
    let lesson: Lesson
    @Bindable var module: Module

    @Query private var allChunks: [StoredChunk]
    @Query private var allCards: [StudyCard]
    @Environment(\.modelContext) private var modelContext

    @State private var startingQuiz: QuizScope?
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var currentIndex = 0
    @State private var showOriginal = false

    private let modelService = FoundationModelService()

    private var moduleCards: [StudyCard] {
        allCards
            .filter { $0.moduleID == module.id }
            .sorted { $0.order < $1.order }
    }

    private var moduleChunks: [StoredChunk] {
        allChunks
            .filter { $0.moduleID == module.id }
            .sorted { $0.order < $1.order }
    }

    private var fullContent: String {
        moduleChunks.map(\.text).joined(separator: "\n\n")
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !module.summary.isEmpty {
                    Text(module.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Body
            if isGenerating {
                generatingView
            } else if !moduleCards.isEmpty {
                carouselView
            } else if let error = generationError {
                errorView(error)
            } else {
                emptyView
            }

            // Quiz button
            Button {
                startingQuiz = QuizScope(kind: .module(module, lessonID: lesson.id), title: module.title)
            } label: {
                Label("Quiz This Module", systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !fullContent.isEmpty {
                Button {
                    showOriginal = true
                } label: {
                    Image(systemName: "doc.text")
                }
            }
        }
        .sheet(isPresented: $showOriginal) {
            NavigationStack {
                ScrollView {
                    Text(fullContent)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle("Original Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("Done") { showOriginal = false }
                }
            }
        }
        .fullScreenCover(item: $startingQuiz) { scope in
            StudySessionView(scope: scope)
        }
        .task {
            await ensureCards()
        }
    }

    // MARK: - Subviews

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Creating flashcards...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No content yet",
            systemImage: "rectangle.stack",
            description: Text("Add a source to this lesson to study it.")
        )
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Couldn't create flashcards")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await ensureCards(force: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var carouselView: some View {
        VStack(spacing: 16) {
            // Progress bar + counter
            VStack(spacing: 6) {
                ProgressView(value: Double(currentIndex + 1), total: Double(moduleCards.count))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                HStack {
                    Text("Card \(currentIndex + 1) of \(moduleCards.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if currentIndex < moduleCards.count - 1 {
                        Text("Swipe →")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Label("Last card", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal)

            // Cards
            TabView(selection: $currentIndex) {
                ForEach(Array(moduleCards.enumerated()), id: \.element.id) { index, card in
                    flashcardView(card)
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
        }
    }

    private func flashcardView(_ card: StudyCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.title)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                Text(card.explanation)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Generation

    private func ensureCards(force: Bool = false) async {
        guard force || moduleCards.isEmpty else { return }
        guard !isGenerating else { return }
        guard !fullContent.isEmpty else { return }

        isGenerating = true
        generationError = nil
        defer { isGenerating = false }

        // If forcing regeneration, delete old cards first
        if force {
            for card in moduleCards { modelContext.delete(card) }
        }

        do {
            let cards = try await modelService.generateStudyCards(content: fullContent)
            guard !cards.isEmpty else {
                generationError = "The model returned no cards. Try again."
                return
            }
            for (i, card) in cards.enumerated() {
                let stored = StudyCard(
                    moduleID: module.id,
                    lessonID: lesson.id,
                    title: card.title,
                    explanation: card.explanation,
                    order: i
                )
                modelContext.insert(stored)
            }
            try? modelContext.save()
            currentIndex = 0
        } catch {
            generationError = error.localizedDescription
        }
    }
}
