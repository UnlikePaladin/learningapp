import Foundation
import SwiftUI
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var nickname: String
    /// Asset name of the chosen giraffe avatar (e.g., "happy_giraffe").
    var avatarID: String
    /// Identifier for the background color behind the avatar (e.g., "white", "mint").
    var avatarBackground: String
    /// Selected interest tags (e.g., "Math", "Algebra").
    var interests: [String]
    var dateCreated: Date
    /// Composite avatar image (giraffe + background color) saved as PNG data.
    var avatarBlob: Data?

    init(
        id: UUID = UUID(),
        nickname: String = "",
        avatarID: String = "happy_giraffe",
        avatarBackground: String = "white",
        interests: [String] = [],
        dateCreated: Date = Date(),
        avatarBlob: Data? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarID = avatarID
        self.avatarBackground = avatarBackground
        self.interests = interests
        self.dateCreated = dateCreated
        self.avatarBlob = avatarBlob
    }
}

/// All available giraffe avatars in the asset catalog.
enum GiraffeAvatar: String, CaseIterable, Identifiable {
    case happy = "happy_giraffe"
    case clearHappy = "clear_happy_giraffe"
    case normal = "normal_giraffe"
    case question = "question_giraffe"
    case talk = "talk_giraffe"
    case iguessbro = "iguessbro_giraffe"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy: "Cheerful"
        case .clearHappy: "Bright"
        case .normal: "Steady"
        case .question: "Curious"
        case .talk: "Chatty"
        case .iguessbro: "Easygoing"
        }
    }
}

/// Pastel-ish backgrounds that look good behind a giraffe.
enum AvatarBackground: String, CaseIterable, Identifiable {
    case white
    case mint
    case sky
    case lavender
    case peach
    case sunshine
    case bubblegum
    case sand
    case sage
    case slate

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white:     return .white
        case .mint:      return Color(red: 0.78, green: 0.92, blue: 0.85)
        case .sky:       return Color(red: 0.78, green: 0.89, blue: 0.96)
        case .lavender:  return Color(red: 0.86, green: 0.83, blue: 0.94)
        case .peach:     return Color(red: 0.99, green: 0.87, blue: 0.82)
        case .sunshine:  return Color(red: 1.00, green: 0.93, blue: 0.71)
        case .bubblegum: return Color(red: 1.00, green: 0.80, blue: 0.86)
        case .sand:      return Color(red: 0.98, green: 0.89, blue: 0.74)
        case .sage:      return Color(red: 0.81, green: 0.89, blue: 0.78)
        case .slate:     return Color(red: 0.78, green: 0.81, blue: 0.84)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    static func color(for id: String) -> Color {
        AvatarBackground(rawValue: id)?.color ?? .white
    }
}

/// Curated interest catalogue presented in the editor. The user can also add custom tags.
enum InterestCatalog {
    struct Group {
        let name: String
        let tags: [String]
    }

    static let groups: [Group] = [
        Group(name: "Math", tags: [
            "Math", "Algebra", "Geometry", "Calculus", "Statistics", "Trigonometry"
        ]),
        Group(name: "Science", tags: [
            "Science", "Biology", "Chemistry", "Physics", "Astronomy", "Earth Science"
        ]),
        Group(name: "Languages", tags: [
            "English", "Spanish", "French", "German", "Latin", "Mandarin"
        ]),
        Group(name: "Humanities", tags: [
            "History", "Geography", "Philosophy", "Economics", "Psychology"
        ]),
        Group(name: "Tech", tags: [
            "Programming", "Computer Science", "Data Science", "Web Development", "AI/ML"
        ]),
        Group(name: "Arts", tags: [
            "Art History", "Music Theory", "Literature", "Creative Writing", "Film"
        ])
    ]
}
