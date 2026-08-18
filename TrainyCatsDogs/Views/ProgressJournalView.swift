import SwiftUI
import SwiftData

struct ProgressJournalView: View {
    let dog: Dog
    @Query(sort: \TrainingSession.date, order: .reverse) private var allSessions: [TrainingSession]

    private var sessions: [TrainingSession] {
        allSessions.filter { $0.dog?.persistentModelID == dog.persistentModelID }
    }

    private var streak: Int {
        let calendar = Calendar.current
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: .now)
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryRow

                    VStack(alignment: .leading, spacing: 12) {
                        Text("История").font(.headline)

                        if sessions.isEmpty {
                            Text("Пока нет тренировок — начни с любого упражнения из каталога.")
                                .foregroundStyle(.secondary)
                                .cardStyle()
                        } else {
                            // LazyVStack вместо обычного: история тренировок со временем
                            // растёт без ограничений, и без "ленивой" загрузки каждая
                            // строка строилась бы заново при каждом обновлении экрана,
                            // даже если она сейчас не видна на экране.
                            LazyVStack(spacing: 12) {
                                ForEach(sessions) { session in
                                    sessionRow(session)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Прогресс")
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            statTile(title: "Всего тренировок", value: "\(sessions.count)", icon: "checkmark.circle.fill")
            statTile(title: "Дней подряд", value: "\(streak)", icon: "flame.fill")
        }
    }

    private func statTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func sessionRow(_ session: TrainingSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            resultBadge(session.result)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.exercise?.title ?? "Упражнение удалено")
                    .font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !session.note.isEmpty {
                    Text(session.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .cardStyle()
    }

    private func resultBadge(_ result: SessionResult) -> some View {
        let (icon, color): (String, Color) = {
            switch result {
            case .success: return ("checkmark.circle.fill", .green)
            case .partial: return ("circle.lefthalf.filled", .orange)
            case .struggled: return ("xmark.circle.fill", .red)
            }
        }()
        return Image(systemName: icon)
            .foregroundStyle(color)
            .font(.title3)
    }
}

#Preview {
    ProgressJournalView(dog: Dog(name: "Рекс"))
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
}
