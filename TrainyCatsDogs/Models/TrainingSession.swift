import Foundation
import SwiftData

enum SessionResult: String, Codable, CaseIterable {
    case success = "Идеально"
    case partial = "Почти"
    case struggled = "Не вышло"

    /// Числовой вес результата для статистики: используется, чтобы посчитать
    /// «успешность» упражнения за последние тренировки (0 — не вышло, 1 — получилось).
    var score: Double {
        switch self {
        case .success: return 1.0
        case .partial: return 0.5
        case .struggled: return 0.0
        }
    }
}

/// Одно и то же упражнение можно тренировать по-разному: «Сидеть» может быть как
/// на выдержку по времени, так и просто на выполнение — режим выбирается каждый раз
/// при записи тренировки, а не привязан жёстко к упражнению.
enum TrainingMode: String, Codable, CaseIterable {
    case hold = "Выдержка"
    case simple = "Выполнение"
}

@Model
final class TrainingSession {
    var date: Date
    var resultRaw: String
    var note: String
    /// Длительность в секундах. Имеет смысл только для режима «Выдержка» —
    /// для «Выполнение» всегда 0.
    var durationSeconds: Int = 60
    var modeRaw: String = TrainingMode.simple.rawValue

    var dog: Dog?
    var exercise: Exercise?

    var result: SessionResult {
        get { SessionResult(rawValue: resultRaw) ?? .success }
        set { resultRaw = newValue.rawValue }
    }

    var mode: TrainingMode {
        get { TrainingMode(rawValue: modeRaw) ?? .simple }
        set { modeRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        result: SessionResult,
        note: String = "",
        durationSeconds: Int = 60,
        mode: TrainingMode = .simple,
        dog: Dog?,
        exercise: Exercise?
    ) {
        self.date = date
        self.resultRaw = result.rawValue
        self.note = note
        self.durationSeconds = durationSeconds
        self.modeRaw = mode.rawValue
        self.dog = dog
        self.exercise = exercise
    }
}
