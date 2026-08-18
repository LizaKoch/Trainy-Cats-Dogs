import SwiftUI
import SwiftData

/// Экран создания своего упражнения. Пока полностью локальный — то, что
/// здесь создастся, останется только на этом устройстве, пока не появится
/// кнопка «Опубликовать» (это отдельный шаг позже).
struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService

    @State private var title = ""
    @State private var description = ""
    @State private var steps: [String] = [""]
    @State private var category: ExerciseCategory = .obedience
    @State private var difficulty: ExerciseDifficulty = .beginner
    @State private var audience: ExerciseAudience = .both
    @FocusState private var focusedStepIndex: Int?

    private var trimmedSteps: [String] {
        steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !trimmedSteps.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $description, axis: .vertical)
                }

                Section("Для кого") {
                    Picker("Питомец", selection: $audience) {
                        ForEach(ExerciseAudience.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Категория и сложность") {
                    Picker("Категория", selection: $category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    Picker("Сложность", selection: $difficulty) {
                        ForEach(ExerciseDifficulty.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                Section("Шаги") {
                    ForEach(steps.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            TextField("Опиши шаг", text: $steps[index])
                                .focused($focusedStepIndex, equals: index)
                        }
                    }
                    .onDelete { offsets in
                        steps.remove(atOffsets: offsets)
                        if steps.isEmpty { steps = [""] }
                    }

                    Button {
                        steps.append("")
                        focusedStepIndex = steps.count - 1
                    } label: {
                        Label("Добавить шаг", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Новое упражнение")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        let exercise = Exercise(
                            title: title.trimmingCharacters(in: .whitespaces),
                            exerciseDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            steps: trimmedSteps,
                            category: category,
                            difficulty: difficulty,
                            audience: audience,
                            isCustom: true,
                            authorName: auth.user?.email
                        )
                        modelContext.insert(exercise)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedStepIndex = nil }
                }
            }
        }
    }
}

#Preview {
    AddExerciseView()
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
        .environmentObject(AuthService())
}
