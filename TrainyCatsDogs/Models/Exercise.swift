import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, CaseIterable {
    case obedience = "Базовое послушание"
    case impulseControl = "Импульс-контроль"
    case socialization = "Привыкание/социализация"
    case tricks = "Трюки"
}

enum ExerciseDifficulty: String, Codable, CaseIterable {
    case beginner = "Новичок"
    case intermediate = "Средний"
    case advanced = "Продвинутый"
}

/// Для какого питомца подходит упражнение. Отдельный тип от PetSpecies:
/// у конкретного питомца вид всегда один («Собака» или «Кошка»), а вот
/// упражнение может быть рассчитано сразу на обоих.
enum ExerciseAudience: String, Codable, CaseIterable {
    case dog = "Собаки"
    case cat = "Кошки"
    case both = "Кошки и собаки"

    /// Подходит ли упражнение питомцу такого вида.
    func matches(_ species: PetSpecies) -> Bool {
        switch self {
        case .both: return true
        case .dog: return species == .dog
        case .cat: return species == .cat
        }
    }
}

/// Лайк/дизлайк — одно значение на упражнение: поставить дизлайк снимает
/// лайк и наоборот (как в большинстве сервисов). Дизлайк нигде в интерфейсе
/// не показывается публично, но сохраняется — на будущее, когда появится
/// облачная лента и на его основе можно будет решать, что показывать.
enum ExerciseReaction: String, Codable {
    case like
    case dislike
}

// Задел под будущий шеринг: isCustom и authorName уже сейчас различают
// встроенные упражнения (isCustom == false) и созданные пользователем,
// чтобы в фазе 2 не пришлось переделывать модель данных.
@Model
final class Exercise {
    var title: String
    var exerciseDescription: String
    var steps: [String]
    var categoryRaw: String
    var difficultyRaw: String
    var isCustom: Bool
    var authorName: String?
    var createdAt: Date
    var audienceRaw: String = ExerciseAudience.dog.rawValue
    var isArchived: Bool = false
    var reactionRaw: String?
    /// Подписка кладёт упражнение в личную ленту («Моя») — это и есть TODO:
    /// напоминания в будущем будут строиться именно по подписанным упражнениям.
    var isSubscribed: Bool = false
    /// Опубликовано ли упражнение в общую облачную ленту (Firestore).
    /// true и для своих опубликованных упражнений, и для тех, что скачаны
    /// из чужой публикации — второй раз публиковать их не нужно.
    var isPublished: Bool = false
    /// ID документа в Firestore, если упражнение опубликовано или скачано
    /// из облачной ленты. По нему находим уже добавленные упражнения,
    /// чтобы не дублировать при повторном заходе в «Сообщество».
    var remoteID: String?
    /// Ссылка на видео на youtube с показом упражнения (необязательно).
    var videoURLString: String?
    /// Путь к своему загруженному видео (файл лежит в Documents на устройстве,
    /// здесь хранится только относительный путь, не сами данные видео —
    /// они слишком тяжёлые для базы).
    var localVideoFileName: String?

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .obedience }
        set { categoryRaw = newValue.rawValue }
    }

    var difficulty: ExerciseDifficulty {
        get { ExerciseDifficulty(rawValue: difficultyRaw) ?? .beginner }
        set { difficultyRaw = newValue.rawValue }
    }

    var audience: ExerciseAudience {
        get { ExerciseAudience(rawValue: audienceRaw) ?? .dog }
        set { audienceRaw = newValue.rawValue }
    }

    var reaction: ExerciseReaction? {
        get { reactionRaw.flatMap(ExerciseReaction.init(rawValue:)) }
        set { reactionRaw = newValue?.rawValue }
    }

    init(
        title: String,
        exerciseDescription: String,
        steps: [String],
        category: ExerciseCategory,
        difficulty: ExerciseDifficulty,
        audience: ExerciseAudience = .dog,
        isCustom: Bool = false,
        authorName: String? = nil
    ) {
        self.title = title
        self.exerciseDescription = exerciseDescription
        self.steps = steps
        self.categoryRaw = category.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.isCustom = isCustom
        self.authorName = authorName
        self.createdAt = .now
        self.audienceRaw = audience.rawValue
        self.isArchived = false
        self.reactionRaw = nil
        self.isSubscribed = false
        self.isPublished = false
        self.remoteID = nil
        self.videoURLString = nil
        self.localVideoFileName = nil
    }
}
