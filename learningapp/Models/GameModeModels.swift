import Foundation

// MARK: - Boss Battle

struct BossEncounter: Identifiable {
    let id: UUID
    let topic: String
    var bossName: String
    var bossIntro: String
    var totalBossHP: Int
    var currentBossHP: Int
    var userHP: Int
    var currentRound: Int

    init(
        id: UUID = UUID(),
        topic: String,
        bossName: String,
        bossIntro: String,
        totalBossHP: Int = 5,
        userHP: Int = 3
    ) {
        self.id = id
        self.topic = topic
        self.bossName = bossName
        self.bossIntro = bossIntro
        self.totalBossHP = totalBossHP
        self.currentBossHP = totalBossHP
        self.userHP = userHP
        self.currentRound = 1
    }

    var isBossDefeated: Bool { currentBossHP <= 0 }
    var isUserDefeated: Bool { userHP <= 0 }

    /// Difficulty scales with round per the spec.
    /// Rounds 1-2 → easy (recognition), 3-4 → medium (recall), 5+ → hard (application).
    var roundDifficulty: DifficultyLevel {
        switch currentRound {
        case 1, 2: return .easy
        case 3, 4: return .medium
        default: return .hard
        }
    }
}

// MARK: - Speed Blitz

struct BlitzSession: Identifiable {
    let id: UUID
    let scopeTitle: String
    let duration: TimeInterval
    var questionsAnswered: Int
    var correctCount: Int
    var bestCombo: Int
    var finalScore: Int
    var date: Date

    init(
        id: UUID = UUID(),
        scopeTitle: String,
        duration: TimeInterval = 60,
        questionsAnswered: Int = 0,
        correctCount: Int = 0,
        bestCombo: Int = 0,
        finalScore: Int = 0,
        date: Date = Date()
    ) {
        self.id = id
        self.scopeTitle = scopeTitle
        self.duration = duration
        self.questionsAnswered = questionsAnswered
        self.correctCount = correctCount
        self.bestCombo = bestCombo
        self.finalScore = finalScore
        self.date = date
    }

    /// Combo multiplier per the spec: 1x, 1.5x, 2x, 2.5x, 3x — capped at 5+ streak.
    static func multiplier(forCombo combo: Int) -> Double {
        switch combo {
        case 0: return 1.0
        case 1: return 1.0
        case 2: return 1.5
        case 3: return 2.0
        case 4: return 2.5
        default: return 3.0
        }
    }

    static let basePoints = 100
}
