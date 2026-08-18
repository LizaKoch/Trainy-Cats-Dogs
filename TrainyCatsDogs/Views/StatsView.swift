import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    let dog: Dog
    @Query(sort: \TrainingSession.date) private var allSessions: [TrainingSession]

    private var sessions: [TrainingSession] {
        allSessions.filter { $0.dog?.persistentModelID == dog.persistentModelID }
    }

    private struct DayCount: Identifiable {
        let day: Date
        var count: Int
        var id: Date { day }
    }

    private var last14Days: [DayCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var buckets: [Date: Int] = [:]
        for offset in stride(from: 13, through: 0, by: -1) {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                buckets[day] = 0
            }
        }
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            if buckets[day] != nil {
                buckets[day, default: 0] += 1
            }
        }
        return buckets.keys.sorted().map { DayCount(day: $0, count: buckets[$0] ?? 0) }
    }

    private struct ResultShare: Identifiable {
        let result: SessionResult
        let count: Int
        var id: String { result.rawValue }
    }

    private var resultBreakdown: [ResultShare] {
        SessionResult.allCases.map { result in
            ResultShare(result: result, count: sessions.filter { $0.result == result }.count)
        }.filter { $0.count > 0 }
    }

    private var categoryMinutes: [(category: ExerciseCategory, minutes: Int)] {
        Dictionary(grouping: sessions) { $0.exercise?.category ?? .obedience }
            .map { (category: $0.key, minutes: $0.value.reduce(0) { $0 + $1.durationSeconds } / 60) }
            .sorted { $0.minutes > $1.minutes }
    }

    // MARK: - Прогресс по упражнениям: что повторить, что уже отлично

    private struct ExerciseProgress: Identifiable {
        let exercise: Exercise
        let attempts: Int
        /// Успешность по последним (до 5) тренировкам этого упражнения, 0...1.
        /// Считаем именно недавние попытки, а не всю историю — иначе один неудачный
        /// старт месяц назад будет вечно портить картину, хотя собака давно освоила трюк.
        let recentScore: Double
        let lastDate: Date

        var id: PersistentIdentifier { exercise.persistentModelID }

        var tier: Tier {
            if recentScore >= 0.85 { return .mastered }
            if recentScore >= 0.5 { return .improving }
            return .needsPractice
        }

        enum Tier: CaseIterable {
            case needsPractice, improving, mastered

            var title: String {
                switch self {
                case .needsPractice: return "Стоит повторить"
                case .improving: return "Получается, но есть куда расти"
                case .mastered: return "Отличный результат"
                }
            }

            var icon: String {
                switch self {
                case .needsPractice: return "arrow.counterclockwise.circle.fill"
                case .improving: return "chart.line.uptrend.xyaxis.circle.fill"
                case .mastered: return "star.circle.fill"
                }
            }

            var color: Color {
                switch self {
                case .needsPractice: return .orange
                case .improving: return Theme.accent
                case .mastered: return .green
                }
            }
        }
    }

    private var exerciseProgress: [ExerciseProgress] {
        let grouped = Dictionary(grouping: sessions) { $0.exercise }
        return grouped.compactMap { exercise, sessions -> ExerciseProgress? in
            guard let exercise else { return nil }
            let sorted = sessions.sorted { $0.date > $1.date }
            let recent = sorted.prefix(5)
            let score = recent.reduce(0.0) { $0 + $1.result.score } / Double(recent.count)
            return ExerciseProgress(
                exercise: exercise,
                attempts: sessions.count,
                recentScore: score,
                lastDate: sorted.first?.date ?? .now
            )
        }
    }

    // MARK: - Динамика по неделям

    private struct WeekScore: Identifiable {
        let weekStart: Date
        let score: Double
        var id: Date { weekStart }
    }

    private var weeklyTrend: [WeekScore] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
        }
        let allWeeks = grouped
            .map { week, sessions in
                WeekScore(
                    weekStart: week,
                    score: sessions.reduce(0.0) { $0 + $1.result.score } / Double(sessions.count)
                )
            }
            .sorted { $0.weekStart < $1.weekStart }
        return Array(allWeeks.suffix(8))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        summaryRow
                        if !exerciseProgress.isEmpty {
                            progressSection
                        }
                        if weeklyTrend.count >= 2 {
                            trendChart
                        }
                        activityChart
                        if !resultBreakdown.isEmpty {
                            resultsChart
                        }
                        if !categoryMinutes.isEmpty {
                            categoryChart
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Статистика")
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Пока нет данных для статистики")
                .foregroundStyle(.secondary)
            Text("Проведи первую тренировку — и здесь появятся графики.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            statTile(title: "Всего", value: "\(sessions.count)", icon: "checkmark.circle.fill")
            statTile(title: "Мин. выдержки", value: "\(sessions.reduce(0) { $0 + $1.durationSeconds } / 60)", icon: "clock.fill")
            statTile(title: "За 14 дней", value: "\(last14Days.reduce(0) { $0 + $1.count })", icon: "calendar")
        }
    }

    private func statTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
            Text(value).font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Резервируем место под 2 строки всегда — иначе у карточки
                // с более длинной подписью («Мин. выдержки») высота больше,
                // чем у соседних, и ряд получается неровным.
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Секция прогресса по упражнениям

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Прогресс по упражнениям").font(.headline)
                Text("Успешность считаем по последним попыткам — старые неудачи не тянут вниз то, что собака уже освоила.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(ExerciseProgress.Tier.allCases, id: \.self) { tier in
                let items = exerciseProgress
                    .filter { $0.tier == tier }
                    .sorted { tier == .mastered ? $0.recentScore > $1.recentScore : $0.recentScore < $1.recentScore }

                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(tier.title, systemImage: tier.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tier.color)

                        ForEach(items) { item in
                            progressRow(item)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private func progressRow(_ item: ExerciseProgress) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.exercise.title)
                    .font(.subheadline.weight(.medium))
                Text("\(item.attempts) \(attemptsWord(item.attempts)) · последний раз \(item.lastDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(item.recentScore * 100))%")
                .font(.subheadline.bold())
                .foregroundStyle(item.tier.color)
        }
    }

    private func attemptsWord(_ count: Int) -> String {
        let mod100 = count % 100
        let mod10 = count % 10
        if (11...14).contains(mod100) { return "попыток" }
        switch mod10 {
        case 1: return "попытка"
        case 2, 3, 4: return "попытки"
        default: return "попыток"
        }
    }

    // MARK: - Графики

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Динамика успешности по неделям").font(.headline)
            Chart(weeklyTrend) { item in
                LineMark(
                    x: .value("Неделя", item.weekStart, unit: .weekOfYear),
                    y: .value("Успешность", item.score * 100)
                )
                .foregroundStyle(Theme.accentGradient)
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 140)
        }
        .cardStyle()
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Тренировки за 14 дней").font(.headline)
            Chart(last14Days) { item in
                BarMark(
                    x: .value("День", item.day, unit: .day),
                    y: .value("Тренировок", item.count)
                )
                .foregroundStyle(Theme.accentGradient)
                .cornerRadius(4)
            }
            .frame(height: 160)
        }
        .cardStyle()
    }

    private var resultsChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Результаты тренировок").font(.headline)
            Chart(resultBreakdown) { item in
                SectorMark(
                    angle: .value("Кол-во", item.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Результат", item.result.rawValue))
                .cornerRadius(4)
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Минуты выдержки по категориям").font(.headline)
            Chart(categoryMinutes, id: \.category) { item in
                BarMark(
                    x: .value("Минуты", item.minutes),
                    y: .value("Категория", item.category.rawValue)
                )
                .foregroundStyle(Theme.accentGradient)
                .cornerRadius(4)
            }
            .frame(height: CGFloat(categoryMinutes.count * 40 + 20))
        }
        .cardStyle()
    }
}

#Preview {
    StatsView(dog: Dog(name: "Рекс"))
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
}
