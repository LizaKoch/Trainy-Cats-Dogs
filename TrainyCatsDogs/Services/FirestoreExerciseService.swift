import Foundation
import FirebaseFirestore

/// Публикуемая версия упражнения — то, что реально лежит в общей облачной
/// коллекции Firestore. Отдельный тип от SwiftData `Exercise`: Firestore
/// работает с обычными Codable-структурами, а не с классами @Model.
/// Видео здесь намеренно нет: при добавлении себе скачивается только текст,
/// а не тяжёлые файлы — ровно та гибридная схема, которую мы обсуждали.
struct CloudExercise: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var title: String
    var exerciseDescription: String
    var steps: [String]
    var category: String
    var difficulty: String
    var audience: String
    var authorId: String
    var authorName: String
    var youtubeURL: String?
    var likeCount: Int
    var dislikeCount: Int
    @ServerTimestamp var createdAt: Date?

    /// Собирает локальное (SwiftData) упражнение из скачанного облачного —
    /// используется, когда пользователь нажимает «Добавить себе».
    func makeLocalExercise() -> Exercise {
        let exercise = Exercise(
            title: title,
            exerciseDescription: exerciseDescription,
            steps: steps,
            category: ExerciseCategory(rawValue: category) ?? .obedience,
            difficulty: ExerciseDifficulty(rawValue: difficulty) ?? .beginner,
            audience: ExerciseAudience(rawValue: audience) ?? .both,
            isCustom: true,
            authorName: authorName
        )
        exercise.videoURLString = youtubeURL
        exercise.remoteID = id
        // Это уже опубликованная версия — повторно её публиковать не нужно.
        exercise.isPublished = true
        return exercise
    }
}

/// Обёртка над Cloud Firestore: чтение публичной ленты и публикация своих
/// упражнений. Видео и офлайн-кеш здесь не трогаем — только текстовые
/// данные упражнения, ровно то, что нужно для ленты.
@MainActor
final class FirestoreExerciseService: ObservableObject {
    @Published var feed: [CloudExercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var collection: CollectionReference { db.collection("exercises") }

    /// Загружает всю публичную ленту, новые публикации сверху. Без пагинации —
    /// для MVP-масштаба библиотека упражнений небольшая.
    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await collection.order(by: "createdAt", descending: true).getDocuments()
            feed = try snapshot.documents.compactMap { try $0.data(as: CloudExercise.self) }
        } catch {
            errorMessage = "Не удалось загрузить ленту: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Публикует упражнение и возвращает ID документа Firestore — его сохраняем
    /// в Exercise.remoteID локально, чтобы не опубликовать одно и то же дважды.
    @discardableResult
    func publish(_ exercise: Exercise, authorId: String, authorName: String) async throws -> String {
        let ref = collection.document()
        let cloud = CloudExercise(
            id: ref.documentID,
            title: exercise.title,
            exerciseDescription: exercise.exerciseDescription,
            steps: exercise.steps,
            category: exercise.categoryRaw,
            difficulty: exercise.difficultyRaw,
            audience: exercise.audienceRaw,
            authorId: authorId,
            authorName: authorName,
            youtubeURL: exercise.videoURLString,
            likeCount: 0,
            dislikeCount: 0
        )
        try await ref.setData(from: cloud)
        return ref.documentID
    }
}
