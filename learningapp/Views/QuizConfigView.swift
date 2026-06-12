import SwiftUI

enum QuizMode {
    case classic
    case block
    case blockInfinite
    case boss
    case blitz
}

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
        case .few: "leaf.fill"
        case .bunch: "flame.fill"
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
        case .easy: "tortoise.fill"
        case .medium: "hare.fill"
        case .hard: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: Color("Lightgreen")
        case .medium: Color("Orange")
        case .hard: Color("Red")
        }
    }

    var dotCount: Int {
        switch self {
        case .easy: 1
        case .medium: 2
        case .hard: 3
        }
    }
}

struct QuizConfigView: View {
    let title: String
    let onStart: (Int, DifficultyLevel, QuizMode) -> Void

    @State private var amount: QuestionAmount = .few
    @State private var difficulty: DifficultyLevel = .medium

    var body: some View {
        ZStack {
            Color("Darkgreen").opacity(0.05).ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color("Darkgreen").opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("Darkgreen"))
                    }
                    Text(title.isEmpty ? "Quiz Time" : title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("How many questions?")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(QuestionAmount.allCases, id: \.self) { option in
                            configButton(
                                title: option.rawValue,
                                icon: option.icon,
                                subtitle: "~\(option.baseCount)",
                                isSelected: amount == option,
                                color: Color("Darkgreen")
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    amount = option
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Difficulty")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                            configButton(
                                title: level.rawValue,
                                icon: level.icon,
                                subtitle: nil,
                                isSelected: difficulty == level,
                                color: level.color
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    difficulty = level
                                }
                            }
                        }
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        onStart(amount.baseCount, difficulty, .classic)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill").font(.title3)
                            Text("Classic Quiz").font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(Color("Orange"), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onStart(amount.baseCount, difficulty, .block)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.grid.2x2.fill").font(.title3)
                            Text("Block Quiz").font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onStart(amount.baseCount, difficulty, .blockInfinite)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "infinity").font(.title3)
                            Text("Infinite Block").font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [Color("Lightgreen")],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onStart(amount.baseCount, difficulty, .boss)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill").font(.title3)
                            Text("Boss Battle").font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [Color("Red")],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onStart(amount.baseCount, difficulty, .blitz)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill").font(.title3)
                            Text("Speed Blitz").font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [Color("Yellow")],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }

    private func configButton(
        title: String, icon: String, subtitle: String?,
        isSelected: Bool, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : color)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(isSelected ? color : color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1))
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}
