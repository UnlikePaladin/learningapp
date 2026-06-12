import Foundation
import FirebaseFirestore
import SwiftData

final class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - Profile

    func userProfileExists(uid: String) async -> Bool {
        do {
            return try await db.collection("users").document(uid).getDocument().exists
        } catch {
            return false
        }
    }

    func createProfile(
        uid: String,
        nickname: String,
        avatarID: String,
        avatarBackground: String,
        avatarBlob: Data?,
        interests: [String]
    ) async throws {
        var data: [String: Any] = [
            "nickname": nickname,
            "avatarID": avatarID,
            "avatarBackground": avatarBackground,
            "interests": interests,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let blob = avatarBlob {
            data["avatarBlob"] = blob.base64EncodedString()
        }
        try await db.collection("users").document(uid).setData(data)
    }

    // MARK: - Local → Firestore sync

    @MainActor
    func syncLocalData(uid: String, context: ModelContext) async throws {
        let userRef = db.collection("users").document(uid)
        let batch = db.batch()

        let lessons = try context.fetch(FetchDescriptor<Lesson>())
        for lesson in lessons {
            let ref = userRef.collection("lessons").document(lesson.id.uuidString)
            batch.setData([
                "title": lesson.title,
                "dateCreated": lesson.dateCreated
            ], forDocument: ref, merge: true)
        }

        let sources = try context.fetch(FetchDescriptor<Source>())
        for source in sources {
            let ref = userRef.collection("sources").document(source.id.uuidString)
            var doc: [String: Any] = [
                "lessonID": source.lessonID.uuidString,
                "rawText": source.rawText,
                "sourceType": source.sourceType.rawValue,
                "dateAdded": source.dateAdded
            ]
            if let name = source.fileName { doc["fileName"] = name }
            batch.setData(doc, forDocument: ref, merge: true)
        }

        let modules = try context.fetch(FetchDescriptor<Module>())
        for module in modules {
            let ref = userRef.collection("modules").document(module.id.uuidString)
            batch.setData([
                "lessonID": module.lessonID.uuidString,
                "title": module.title,
                "summary": module.summary,
                "explanation": module.explanation,
                "order": module.order
            ], forDocument: ref, merge: true)
        }

        let cards = try context.fetch(FetchDescriptor<StudyCard>())
        for card in cards {
            let ref = userRef.collection("studyCards").document(card.id.uuidString)
            batch.setData([
                "moduleID": card.moduleID.uuidString,
                "lessonID": card.lessonID.uuidString,
                "title": card.title,
                "explanation": card.explanation,
                "order": card.order
            ], forDocument: ref, merge: true)
        }

        let plans = try context.fetch(FetchDescriptor<CustomStudyPlan>())
        for plan in plans {
            let ref = userRef.collection("studyPlans").document(plan.id.uuidString)
            batch.setData([
                "name": plan.name,
                "lessonIDs": plan.lessonIDs.map(\.uuidString),
                "dateCreated": plan.dateCreated
            ], forDocument: ref, merge: true)
        }

        let results = try context.fetch(FetchDescriptor<SessionResult>())
        for result in results {
            let ref = userRef.collection("sessionResults").document(result.id.uuidString)
            var doc: [String: Any] = [
                "lessonID": result.lessonID.uuidString,
                "questionsAnswered": result.questionsAnswered,
                "correctCount": result.correctCount,
                "duration": result.duration,
                "date": result.date
            ]
            if let mid = result.moduleID { doc["moduleID"] = mid.uuidString }
            if let pid = result.planID { doc["planID"] = pid.uuidString }
            batch.setData(doc, forDocument: ref, merge: true)
        }

        try await batch.commit()
    }
}
