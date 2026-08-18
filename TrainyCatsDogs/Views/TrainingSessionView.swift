import SwiftUI
import SwiftData
import Combine
import Foundation

struct TrainingSessionView: View {
    let dog: Dog
    let exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var result: SessionResult = .success
    @State private var note = ""
    @State private var mode: TrainingMode
    @State private var durationMinutes = 0
    @State private var durationSecondsPart = 0
    @State private var isTimerRunning = false
    @State private var timerStartDate: Date?
    @FocusState private var focusedDurationField: DurationField?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Упражнения, которые чаще всего тренируют именно на выдержку —
    /// используем как разумное значение по умолчанию, но пользователь
    /// всегда может переключить режим вручную для любого упражнения.
    private static let holdExerciseTitles: Set<String> = [
        "Сидеть", "Лежать", "Место", "Ждать", "Замри", "Внимание (зрительный контакт)"
    ]

    private static func defaultMode(for exercise: Exercise) -> TrainingMode {
        holdExerciseTitles.contains(exercise.title) ? .hold : .simple
    }

    init(dog: Dog, exercise: Exercise) {
        self.dog = dog
        self.exercise = exercise
        _mode = State(initialValue: Self.defaultMode(for: exercise))
    }

    private enum DurationField {
        case minutes, seconds
    }

    private var totalDurationSeconds: Int {
        durationMinutes * 60 + durationSecondsPart
    }

    private var timerDisplay: String {
        String(format: "%d:%02d", durationMinutes, durationSecondsPart)
    }

    /// Значение барабана минут как текст — позволяет напечатать число с клавиатуры
    /// вместо прокрутки. Барабан ниже остаётся синхронизирован через ту же переменную.
    private var minutesText: Binding<String> {
        Binding(
            get: { String(durationMinutes) },
            set: { newValue in
                let digits = String(newValue.filter(\.isNumber).prefix(3))
                durationMinutes = digits.isEmpty ? 0 : min(max(Int(digits) ?? 0, 0), 100)
            }
        )
    }

    private var secondsText: Binding<String> {
        Binding(
            get: { String(durationSecondsPart) },
            set: { newValue in
                let digits = String(newValue.filter(\.isNumber).prefix(2))
                durationSecondsPart = digits.isEmpty ? 0 : min(max(Int(digits) ?? 0, 0), 59)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(exercise.title) {
                    ForEach(exercise.steps, id: \.self) { step in
                        Label(step, systemImage: "checkmark.circle")
                    }
                }

                Section("Результат") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Тип тренировки", selection: $mode) {
                            ForEach(TrainingMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("«Выдержка» — если тренируешь по времени (сидеть, лежать, зрительный контакт). «Выполнение» — если просто отмечаешь, получилось или нет.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    Picker("Как прошло", selection: $result) {
                        ForEach(SessionResult.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .hold {
                        holdDurationSection
                    }

                    TextField("Заметка (необязательно)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Тренировка")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.accent)
            .onChange(of: mode) { _, newMode in
                if newMode == .simple {
                    isTimerRunning = false
                }
            }
            .onReceive(ticker) { _ in
                guard isTimerRunning, let start = timerStartDate else { return }
                let elapsed = Int(Date().timeIntervalSince(start))
                durationMinutes = elapsed / 60
                durationSecondsPart = elapsed % 60
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let session = TrainingSession(
                            result: result,
                            note: note,
                            durationSeconds: mode == .hold ? totalDurationSeconds : 0,
                            mode: mode,
                            dog: dog,
                            exercise: exercise
                        )
                        modelContext.insert(session)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedDurationField = nil }
                }
            }
        }
    }

    private var holdDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(timerDisplay)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isTimerRunning ? Theme.accent : .primary)

                Spacer()

                Button {
                    if isTimerRunning {
                        isTimerRunning = false
                    } else {
                        durationMinutes = 0
                        durationSecondsPart = 0
                        timerStartDate = .now
                        isTimerRunning = true
                    }
                } label: {
                    Label(isTimerRunning ? "Стоп" : "Старт", systemImage: isTimerRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 90)
                }
                .buttonStyle(.borderedProminent)
                .tint(isTimerRunning ? .red : Theme.accent)
            }

            Text("Нажми «Старт», когда собака встанет в стойку, и «Стоп», когда она отпустит — время посчитается само.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Или укажи вручную")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Числа над барабанами — можно напечатать значение с клавиатуры,
                // тапнув по нему, вместо прокрутки колеса.
                HStack(spacing: 4) {
                    Spacer()
                    TextField("0", text: minutesText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedDurationField, equals: .minutes)
                        .frame(width: 36)
                    Text("мин").foregroundStyle(.secondary)

                    Spacer().frame(width: 16)

                    TextField("0", text: secondsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedDurationField, equals: .seconds)
                        .frame(width: 36)
                    Text("сек").foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.title3.monospacedDigit().weight(.semibold))

                HStack(spacing: 0) {
                    Picker("Минуты", selection: $durationMinutes) {
                        ForEach(0...100, id: \.self) { minute in
                            Text("\(minute) мин").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Секунды", selection: $durationSecondsPart) {
                        ForEach(0..<60, id: \.self) { second in
                            Text("\(second) сек").tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 130)
            }
            .disabled(isTimerRunning)
            .opacity(isTimerRunning ? 0.4 : 1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TrainingSessionView(
        dog: Dog(name: "Рекс"),
        exercise: Exercise(
            title: "Сидеть",
            exerciseDescription: "Базовая команда.",
            steps: ["Шаг 1", "Шаг 2"],
            category: .obedience,
            difficulty: .beginner
        )
    )
    .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
}
