import SwiftUI

struct QuizCardView: View {
    let questions: [Question]
    let aiService: FoundationModelService
    var onComplete: ([Bool]) -> Void

    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var feedback: Feedback?
    @State private var isEvaluating = false
    @State private var results: [Bool] = []
    @State private var cardOffset: CGFloat = 0
    @State private var showXP = false

    private var currentQuestion: Question { questions[currentIndex] }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 20) {
                // Progress
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Card
                VStack(spacing: 16) {
                    if let feedback {
                        feedbackView(feedback)
                    } else {
                        questionView
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 280)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .offset(x: cardOffset)
            }

            XPAnimationView(xpAmount: 10, isShowing: $showXP)
                .padding(.top, 40)
        }
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
        .animation(.easeInOut(duration: 0.25), value: feedback != nil)
    }

    private var questionView: some View {
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
                Text("Submit")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isEvaluating)

            if isEvaluating {
                ProgressView("Checking...")
            }
        }
    }

    private func feedbackView(_ fb: Feedback) -> some View {
        VStack(spacing: 16) {
            Image(systemName: fb.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(fb.isCorrect ? .green : .orange)

            Text(fb.isCorrect ? "Correct!" : "Not quite")
                .font(.title2.bold())

            Text(fb.explanation)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text(fb.encouragement)
                .font(.callout.italic())
                .foregroundStyle(.blue)

            Button {
                advance()
            } label: {
                Text(currentIndex < questions.count - 1 ? "Next Question" : "Finish")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func submit() {
        isEvaluating = true
        Task {
            do {
                let fb = try await aiService.evaluateAnswer(question: currentQuestion, userAnswer: userAnswer)
                feedback = fb
                results.append(fb.isCorrect)
                if fb.isCorrect { showXP = true }
            } catch {
                feedback = Feedback(isCorrect: false, explanation: "Could not evaluate answer.", encouragement: "Keep trying!")
                results.append(false)
            }
            isEvaluating = false
        }
    }

    private func advance() {
        if currentIndex < questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                cardOffset = -400
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                currentIndex += 1
                userAnswer = ""
                feedback = nil
                cardOffset = 400
                withAnimation(.easeInOut(duration: 0.2)) {
                    cardOffset = 0
                }
            }
        } else {
            onComplete(results)
        }
    }
}
