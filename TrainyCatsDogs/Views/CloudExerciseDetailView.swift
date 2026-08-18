import SwiftUI

/// Просмотр упражнения из облачной ленты «Сообщество» до того, как добавить
/// его себе. В отличие от ExerciseDetailView здесь нет тренировки, лайков
/// и архива — это чужой (или уже опубликованный свой) контент, который
/// можно посмотреть и, если понравилось, добавить в свою библиотеку.
struct CloudExerciseDetailView: View {
    let cloudExercise: CloudExercise
    let onAdd: () -> Void
    @State private var added: Bool

    init(cloudExercise: CloudExercise, isAdded: Bool, onAdd: @escaping () -> Void) {
        self.cloudExercise = cloudExercise
        self.onAdd = onAdd
        _added = State(initialValue: isAdded)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 8) {
                    Text("Описание").font(.headline)
                    Text(cloudExercise.exerciseDescription)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Шаги").font(.headline)
                    ForEach(Array(cloudExercise.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Theme.accentGradient))
                            Text(step)
                        }
                    }
                }
                .cardStyle()

                if let youtubeURLString = cloudExercise.youtubeURL, let url = URL(string: youtubeURLString) {
                    Link(destination: url) {
                        Label("Смотреть видео на YouTube", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    onAdd()
                    added = true
                } label: {
                    Text(added ? "Добавлено" : "Добавить себе")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(added)
            }
            .padding()
        }
        .navigationTitle(cloudExercise.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(cloudExercise.category, systemImage: "tag.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
                Label(cloudExercise.difficulty, systemImage: "gauge.medium")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
                Label(cloudExercise.audience, systemImage: "pawprint.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
            }
            Text("Автор: \(cloudExercise.authorName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        CloudExerciseDetailView(
            cloudExercise: CloudExercise(
                id: "preview",
                title: "Сидеть",
                exerciseDescription: "Базовая команда.",
                steps: ["Шаг 1", "Шаг 2"],
                category: ExerciseCategory.obedience.rawValue,
                difficulty: ExerciseDifficulty.beginner.rawValue,
                audience: ExerciseAudience.dog.rawValue,
                authorId: "abc",
                authorName: "Лиза",
                youtubeURL: nil,
                likeCount: 0,
                dislikeCount: 0,
                createdAt: nil
            ),
            isAdded: false,
            onAdd: {}
        )
    }
}
