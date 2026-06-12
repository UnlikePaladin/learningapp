import Foundation

/// What the quiz session is targeting: a whole lesson, a module within a lesson,
/// or a custom multi-lesson plan.
struct QuizScope: Identifiable, Hashable {
    let id = UUID()
    let kind: Kind
    let title: String

    enum Kind: Hashable {
        case lesson(Lesson)
        case module(Module, lessonID: UUID)
        case plan(CustomStudyPlan)
    }

    static func == (lhs: QuizScope, rhs: QuizScope) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
