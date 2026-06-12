import SwiftUI

struct QuizCardView: View {
    let questions: [Question]
    let aiService: FoundationModelService
    var difficulty: DifficultyLevel = .medium
    var onComplete: ([Bool], [Question]) -> Void

    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var feedback: Feedback?
    @State private var isEvaluating = false
    @State private var results: [Bool] = []
    @State private var skippedQuestions: [Question] = []
    @State private var cardOffset: CGFloat = 0
    @State private var showXP = false
    @State private var feedbackScale: CGFloat = 0.85
    @State private var cardShake: CGFloat = 0
    @State private var isSkipped = false

    private var currentQuestion: Question { questions[currentIndex] }
    private var progress: Double { Double(currentIndex + 1) / Double(questions.count) }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 14) {
                progressSection.padding(.horizontal)
                cardSection.padding(.horizontal).offset(x: cardOffset)
            }
            XPAnimationView(xpAmount: 10, isShowing: $showXP).padding(.top, 36)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [Color("Lightgreen"), Color("Darkgreen")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let fb = feedback {
                    Label(
                        fb.isCorrect ? "+10 XP" : (isSkipped ? "Para repasar" : "+5 XP"),
                        systemImage: fb.isCorrect ? "star.fill" : (isSkipped ? "bookmark.fill" : "star")
                    )
                    .font(.caption.bold())
                    .foregroundStyle(fb.isCorrect ? Color("Lightgreen") : (isSkipped ? Color("Orange") : Color("Red")))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: feedback != nil)
        }
    }

    // MARK: - Card shell

    private var cardSection: some View {
        Group {
            if let fb = feedback {
                feedbackCard(fb)
                    .scaleEffect(feedbackScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { feedbackScale = 1.0 }
                    }
            } else {
                questionCard.offset(x: cardShake)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.09), radius: 12, y: 5)
        .animation(.easeInOut(duration: 0.22), value: feedback != nil)
    }

    // MARK: - Question card

    private var questionCard: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color("Darkgreen")).frame(height: 5)

            VStack(alignment: .leading, spacing: 14) {
                // Badge row
                HStack(spacing: 8) {
                    Text("Q\(currentIndex + 1)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color("Darkgreen").opacity(0.12), in: Capsule())
                        .foregroundStyle(Color("Darkgreen"))

                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { i in
                            Circle()
                                .fill(i <= difficulty.dotCount ? difficulty.color : Color.secondary.opacity(0.2))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Spacer()

                    Text(difficulty.rawValue)
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Question text — left-aligned, prominent
                Text(currentQuestion.prompt)
                    .font(.title3.bold())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Answer input with tinted background
                TextField("Type your answer...", text: $userAnswer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...5)
                    .font(.body)
                    .padding(12)
                    .background(Color("Darkgreen").opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("Darkgreen").opacity(0.15), lineWidth: 1))

                // Action buttons
                VStack(spacing: 8) {
                    Button { submit() } label: {
                        Group {
                            if isEvaluating {
                                HStack(spacing: 8) { ProgressView().tint(.white); Text("Checking...").font(.headline) }
                            } else {
                                Text("Submit Answer").font(.headline.bold())
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                        .background(
                            userAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isEvaluating
                                ? Color.secondary.opacity(0.35) : Color("Darkgreen"),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .animation(.easeInOut(duration: 0.15), value: userAnswer.isEmpty)
                    }
                    .buttonStyle(.plain)
                    .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isEvaluating)

                    Button { skipQuestion() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark.fill").font(.caption)
                            Text("Saltar - ver respuesta").font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(Color("Red"))
                        .background(Color("Red").opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isEvaluating)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Feedback card

    private func feedbackCard(_ fb: Feedback) -> some View {
        let headerColor: Color = fb.isCorrect ? Color("Darkgreen") : (isSkipped ? Color("Orange") : Color("Red"))
        let headerIcon = fb.isCorrect ? "checkmark.circle.fill" : (isSkipped ? "bookmark.fill" : "xmark.circle.fill")
        let headerTitle = fb.isCorrect ? "Correct!" : (isSkipped ? "Para repasar" : "Not quite")

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: headerIcon).font(.title2).foregroundStyle(.white)
                Text(headerTitle).font(.headline.bold()).foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(headerColor)

            VStack(alignment: .leading, spacing: 12) {
                if isSkipped {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Respuesta correcta:")
                            .font(.caption.bold())
                            .foregroundStyle(Color("Orange"))
                        Text(fb.explanation)
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color("Orange").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(fb.explanation)
                        .font(.body).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !fb.encouragement.isEmpty {
                    Text(fb.encouragement)
                        .font(.callout.italic())
                        .foregroundStyle(fb.isCorrect ? Color("Darkgreen") : (isSkipped ? Color("Orange") : Color("Red")))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button { advance() } label: {
                    Text(currentIndex < questions.count - 1 ? "Next Question  →" : "Finish Session")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                        .background(headerColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
    }

    // MARK: - Actions

    private func submit() {
        isEvaluating = true
        isSkipped = false
        feedbackScale = 0.85
        Task {
            do {
                let fb = try await aiService.evaluateAnswer(question: currentQuestion, userAnswer: userAnswer, difficulty: difficulty)
                feedback = fb
                results.append(fb.isCorrect)
                if fb.isCorrect { showXP = true } else { shakeCard() }
            } catch {
                feedback = Feedback(isCorrect: false, explanation: "Could not evaluate answer.", encouragement: "Keep trying!")
                results.append(false)
            }
            isEvaluating = false
        }
    }

    private func skipQuestion() {
        isSkipped = true
        feedbackScale = 0.85
        skippedQuestions.append(currentQuestion)
        results.append(false)
        feedback = Feedback(
            isCorrect: false,
            explanation: currentQuestion.expectedAnswer,
            encouragement: "Marcado para repasar. ¡Ya lo aprenderás!"
        )
    }

    private func shakeCard() {
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { cardShake = 9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { cardShake = -9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring()) { cardShake = 0 }
        }
    }

    private func advance() {
        if currentIndex < questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.18)) { cardOffset = -420 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                currentIndex += 1
                userAnswer = ""
                feedback = nil
                feedbackScale = 0.85
                isSkipped = false
                cardOffset = 420
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) { cardOffset = 0 }
            }
        } else {
            onComplete(results, skippedQuestions)
        }
    }
}
