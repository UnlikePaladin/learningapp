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

    private let headerColors: [Color] = [
        Color("Darkgreen"), Color("Orange"), Color("Lightgreen"), Color("Red")
    ]

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
            if !module.summary.isEmpty {
                Text(module.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            if isGenerating {
                generatingView
            } else if !moduleCards.isEmpty {
                carouselView
            } else if let error = generationError {
                errorView(error)
            } else {
                emptyView
            }

            Button {
                startingQuiz = QuizScope(kind: .module(module, lessonID: lesson.id), title: module.title)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("Quiz This Module")
                        .font(.title3.bold())
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(.white)
                .background(Color("Orange"), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !fullContent.isEmpty {
                Button { showOriginal = true } label: {
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color("Lightgreen").opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36))
                    .foregroundStyle(Color("Darkgreen"))
                    .symbolEffect(.pulse)
            }
            Text("Creating flashcards...")
                .font(.headline)
            Text("Hang tight, almost ready!")
                .font(.subheadline)
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color("Red").opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color("Red"))
            }
            Text("Couldn't create flashcards")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                Task { await ensureCards(force: true) }
            } label: {
                Text("Retry")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(.white)
                    .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var carouselView: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(0..<min(moduleCards.count, 15), id: \.self) { i in
                        Capsule()
                            .fill(
                                i < currentIndex
                                    ? Color("Darkgreen")
                                    : i == currentIndex
                                        ? headerColors[i % headerColors.count]
                                        : Color.secondary.opacity(0.2)
                            )
                            .frame(width: i == currentIndex ? 20 : 7, height: 7)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                    }
                }

                HStack {
                    Text("Card \(currentIndex + 1) of \(moduleCards.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if currentIndex < moduleCards.count - 1 {
                        HStack(spacing: 3) {
                            Text("Swipe")
                            Image(systemName: "arrow.right")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    } else {
                        Label("All done!", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color("Lightgreen"))
                    }
                }
            }
            .padding(.horizontal)

            TabView(selection: $currentIndex) {
                ForEach(Array(moduleCards.enumerated()), id: \.element.id) { index, card in
                    flashcardView(card, index: index)
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .frame(maxHeight: .infinity)
        }
    }

    private func flashcardView(_ card: StudyCard, index: Int) -> some View {
        let color = headerColors[index % headerColors.count]

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label("Card \(index + 1)", systemImage: "lightbulb.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
                Text(card.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(color)

            ScrollView {
                Text(card.explanation)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    // MARK: - Generation

    private func ensureCards(force: Bool = false) async {
        guard force || moduleCards.isEmpty else { return }
        guard !isGenerating else { return }
        guard !fullContent.isEmpty else { return }

        isGenerating = true
        generationError = nil
        defer { isGenerating = false }

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
