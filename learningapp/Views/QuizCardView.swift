import SwiftUI

struct QuizCardView: View {
    let questions: [Question]
    let aiService: FoundationModelService
    var difficulty: DifficultyLevel = .medium
    var onComplete: ([Bool]) -> Void

    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var feedback: Feedback?
    @State private var isEvaluating = false
    @State private var results: [Bool] = []
    @State private var cardOffset: CGFloat = 0
    @State private var showXP = false
    @State private var feedbackScale: CGFloat = 0.85
    @State private var cardShake: CGFloat = 0

    private var currentQuestion: Question { questions[currentIndex] }
    private var progress: Double { Double(currentIndex + 1) / Double(questions.count) }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 20) {
                progressSection
                    .padding(.horizontal)

                cardSection
                    .padding(.horizontal)
                    .offset(x: cardOffset)
            }

            XPAnimationView(xpAmount: 10, isShowing: $showXP)
                .padding(.top, 40)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color("Lightgreen"), Color("Darkgreen")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 10)

            HStack {
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let feedback {
                    Label(feedback.isCorrect ? "+10 XP" : "+5 XP", systemImage: "star.fill")
                        .font(.caption.bold())
                        .foregroundStyle(feedback.isCorrect ? Color("Lightgreen") : Color("Orange"))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: feedback != nil)
        }
    }

    private var cardSection: some View {
        Group {
            if let feedback {
                feedbackCard(feedback)
                    .scaleEffect(feedbackScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            feedbackScale = 1.0
                        }
                    }
            } else {
                questionCard
                    .offset(x: cardShake)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.09), radius: 14, y: 6)
        .animation(.easeInOut(duration: 0.22), value: feedback != nil)
    }

    private var questionCard: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color("Darkgreen"))
                .frame(height: 5)

            VStack(spacing: 20) {
                Text(currentQuestion.prompt)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Type your answer...", text: $userAnswer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .font(.body)

                Button {
                    submit()
                } label: {
                    Group {
                        if isEvaluating {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Checking...").font(.headline)
                            }
                        } else {
                            Text("Submit Answer").font(.headline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white)
                    .background(
                        userAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isEvaluating
                            ? Color.secondary.opacity(0.35)
                            : Color("Darkgreen"),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .animation(.easeInOut(duration: 0.15), value: userAnswer.isEmpty)
                }
                .buttonStyle(.plain)
                .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isEvaluating)
            }
            .padding(24)
        }
    }

    private func feedbackCard(_ fb: Feedback) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: fb.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(fb.isCorrect ? "Correct!" : "Not quite")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(fb.isCorrect ? Color("Darkgreen") : Color("Red"))

            VStack(alignment: .leading, spacing: 14) {
                Text(fb.explanation)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !fb.encouragement.isEmpty {
                    Text(fb.encouragement)
                        .font(.callout.italic())
                        .foregroundStyle(fb.isCorrect ? Color("Darkgreen") : Color("Orange"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    advance()
                } label: {
                    Text(currentIndex < questions.count - 1 ? "Next Question  →" : "Finish Session")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.white)
                        .background(
                            fb.isCorrect ? Color("Darkgreen") : Color("Orange"),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    private func submit() {
        isEvaluating = true
        feedbackScale = 0.85
        Task {
            do {
                let fb = try await aiService.evaluateAnswer(
                    question: currentQuestion,
                    userAnswer: userAnswer,
                    difficulty: difficulty
                )
                feedback = fb
                results.append(fb.isCorrect)
                if fb.isCorrect {
                    showXP = true
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { cardShake = 9 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { cardShake = -9 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(.spring()) { cardShake = 0 }
                    }
                }
            } catch {
                feedback = Feedback(isCorrect: false, explanation: "Could not evaluate answer.", encouragement: "Keep trying!")
                results.append(false)
            }
            isEvaluating = false
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
                cardOffset = 420
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) { cardOffset = 0 }
            }
        } else {
            onComplete(results)
        }
    }
}
