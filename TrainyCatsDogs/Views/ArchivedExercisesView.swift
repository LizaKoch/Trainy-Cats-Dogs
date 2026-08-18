import SwiftUI
import SwiftData

/// Отдельный экран для архива — чтобы архивные упражнения не мешались
/// в основном каталоге, но всегда можно было вернуть нужное обратно.
struct ArchivedExercisesView: View {
    @Query(sort: \Exercise.title) private var allExercises: [Exercise]

    private var archived: [Exercise] {
        allExercises.filter { $0.isArchived }
    }

    var body: some View {
        List {
            if archived.isEmpty {
                Text("В архиве пока пусто.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(archived) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.title).font(.subheadline.weight(.medium))
                            Text(exercise.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Вернуть") {
                            exercise.isArchived = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("Архив")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ArchivedExercisesView()
            .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
    }
}
