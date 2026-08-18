import SwiftUI

struct ExerciseDetailView: View {
    let dog: Dog
    let exercise: Exercise
    @EnvironmentObject private var auth: AuthService
    @StateObject private var firestoreService = FirestoreExerciseService()
    @State private var startTraining = false
    @State private var isPublishing = false
    @State private var publishError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 8) {
                    Text("Описание").font(.headline)
                    Text(exercise.exerciseDescription)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Шаги").font(.headline)
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
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

                reactionRow

                Button {
                    startTraining = true
                } label: {
                    Text("Начать тренировку")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding()
        }
        .navigationTitle(exercise.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $startTraining) {
            TrainingSessionView(dog: dog, exercise: exercise)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exercise.isArchived.toggle()
                } label: {
                    Image(systemName: exercise.isArchived ? "tray.and.arrow.up" : "archivebox")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(exercise.category.rawValue, systemImage: "tag.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
                Label(exercise.difficulty.rawValue, systemImage: "gauge.medium")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
                Label(exercise.audience.rawValue, systemImage: "pawprint.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
            }
            if exercise.isCustom, let author = exercise.authorName {
                Text("Автор: \(author)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Дизлайк нигде не показывается — ни счётчиком, ни где-либо ещё —
    /// но сохраняется в модели: пригодится позже для облачной ленты.
    private var reactionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    exercise.reaction = exercise.reaction == .like ? nil : .like
                } label: {
                    Label("Нравится", systemImage: exercise.reaction == .like ? "heart.fill" : "heart")
                }
                .tint(.pink)

                Button {
                    exercise.reaction = exercise.reaction == .dislike ? nil : .dislike
                } label: {
                    Label("Не нравится", systemImage: exercise.reaction == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                }
                .tint(.secondary)

                Spacer()
            }

            Button {
                exercise.isSubscribed.toggle()
            } label: {
                Label(
                    exercise.isSubscribed ? "Отписаться" : "Подписаться",
                    systemImage: exercise.isSubscribed ? "bell.fill" : "bell"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(exercise.isSubscribed ? Theme.accent : Theme.accent.opacity(0.7))

            if exercise.isSubscribed {
                Text("Упражнение добавлено в твою личную ленту («Моя») — это как TODO.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            publishSection
        }
        .buttonStyle(.bordered)
        .font(.footnote)
    }

    /// Публиковать можно только своё и ещё не опубликованное упражнение —
    /// то, что скачано из «Сообщества», уже отмечено как isPublished и
    /// повторно наверх не уходит.
    @ViewBuilder
    private var publishSection: some View {
        if exercise.isCustom && !exercise.isPublished {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    publish()
                } label: {
                    if isPublishing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Опубликовать в общую ленту", systemImage: "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentSecondary)
                .disabled(isPublishing)

                if let publishError {
                    Text(publishError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        } else if exercise.isPublished {
            Label("Уже в общей ленте «Сообщество»", systemImage: "checkmark.icloud.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func publish() {
        guard let uid = auth.user?.uid else {
            publishError = "Не удалось определить пользователя — попробуй перезайти в аккаунт."
            return
        }
        let authorName = auth.user?.email ?? exercise.authorName ?? "Аноним"
        isPublishing = true
        publishError = nil
        Task {
            do {
                let remoteID = try await firestoreService.publish(exercise, authorId: uid, authorName: authorName)
                exercise.remoteID = remoteID
                exercise.isPublished = true
            } catch {
                publishError = "Не удалось опубликовать: \(error.localizedDescription)"
            }
            isPublishing = false
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(
            dog: Dog(name: "Рекс"),
            exercise: Exercise(
                title: "Сидеть",
                exerciseDescription: "Базовая команда.",
                steps: ["Шаг 1", "Шаг 2"],
                category: .obedience,
                difficulty: .beginner
            )
        )
        .environmentObject(AuthService())
    }
}
