import SwiftUI

enum QuestionAmount: String, CaseIterable {
    case few = "A Few"
    case bunch = "A Bunch"
    case many = "Many"

    var baseCount: Int {
        switch self {
        case .few: 5
        case .bunch: 10
        case .many: 20
        }
    }

    var icon: String {
        switch self {
        case .few: "leaf"
        case .bunch: "flame"
        case .many: "bolt.fill"
        }
    }
}

enum DifficultyLevel: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var systemPrompt: String {
        switch self {
        case .easy: "simple recall and basic understanding"
        case .medium: "understanding and application"
        case .hard: "analysis, application, and critical thinking"
        }
    }

    var icon: String {
        switch self {
        case .easy: "tortoise"
        case .medium: "hare"
        case .hard: "bolt"
        }
    }

    var color: Color {
        switch self {
        case .easy: .green
        case .medium: .orange
        case .hard: .red
        }
    }
}

struct QuizConfigView: View {
    let title: String
    let onStart: (Int, DifficultyLevel) -> Void

    @State private var amount: QuestionAmount = .few
    @State private var difficulty: DifficultyLevel = .medium

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(title.isEmpty ? "Quiz Time" : title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Question count
            VStack(alignment: .leading, spacing: 12) {
                Text("How many questions?")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(QuestionAmount.allCases, id: \.self) { option in
                        configButton(
                            title: option.rawValue,
                            icon: option.icon,
                            subtitle: "~\(option.baseCount)",
                            isSelected: amount == option
                        ) { amount = option }
                    }
                }
            }

            // Difficulty
            VStack(alignment: .leading, spacing: 12) {
                Text("Difficulty")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        configButton(
                            title: level.rawValue,
                            icon: level.icon,
                            subtitle: nil,
                            isSelected: difficulty == level,
                            tint: level.color
                        ) { difficulty = level }
                    }
                }
            }

            Spacer()

            // Start button
            Button {
                onStart(amount.baseCount, difficulty)
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    private func configButton(title: String, icon: String, subtitle: String?, isSelected: Bool, tint: Color = .accentColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(isSelected ? tint.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? tint : .secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? tint : .primary)
    }
}
