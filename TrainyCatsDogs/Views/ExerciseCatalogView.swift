import SwiftUI
import SwiftData

/// Все — единая лента: твоя локальная библиотека (готовые + свои + скачанные)
/// вперемешку с ещё не добавленными публикациями из облака, по дате.
/// Моя — только подписанные упражнения: это TODO, чисто локальный фильтр.
enum ExerciseFeedScope: String, CaseIterable {
    case all = "Все"
    case mine = "Моя"
}

/// Единица объединённой ленты: локальное (SwiftData) или облачное (Firestore,
/// ещё не добавленное себе) упражнение. Нужен, чтобы показывать оба типа
/// в одном списке без двух отдельных вкладок.
private enum FeedItem: Identifiable {
    case local(Exercise)
    case cloud(CloudExercise)

    var id: AnyHashable {
        switch self {
        case .local(let exercise): return exercise.persistentModelID
        case .cloud(let cloudExercise): return cloudExercise.id ?? UUID().uuidString
        }
    }

    var createdAt: Date {
        switch self {
        case .local(let exercise): return exercise.createdAt
        case .cloud(let cloudExercise): return cloudExercise.createdAt ?? .distantPast
        }
    }
}

struct ExerciseCatalogView: View {
    let dog: Dog
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @State private var selectedCategory: ExerciseCategory?
    @State private var feedScope: ExerciseFeedScope = .all
    @State private var showAddExercise = false
    @StateObject private var communityService = FirestoreExerciseService()

    /// remoteID уже добавленных себе облачных упражнений — по нему прячем
    /// их из облачной части ленты, чтобы не показывать дважды.
    private var addedRemoteIDs: Set<String> {
        Set(exercises.compactMap(\.remoteID))
    }

    /// Локальная часть ленты: подходящие по виду питомца и категории,
    /// не архивные, и — в режиме «Моя» — только подписанные.
    private var filteredLocal: [Exercise] {
        exercises.filter { exercise in
            !exercise.isArchived
                && exercise.audience.matches(dog.species)
                && (selectedCategory == nil || exercise.category == selectedCategory)
                && (feedScope == .all || exercise.isSubscribed)
        }
    }

    /// Облачная часть ленты: только в режиме «Все» — на подписку из
    /// «Моя» облачные (ещё не скачанные) упражнения не попадают, ведь
    /// подписаться можно только на то, что уже у тебя в библиотеке.
    private var filteredCloud: [CloudExercise] {
        guard feedScope == .all else { return [] }
        return communityService.feed.filter { cloudExercise in
            guard let id = cloudExercise.id, !addedRemoteIDs.contains(id) else { return false }
            if let selectedCategory, cloudExercise.category != selectedCategory.rawValue { return false }
            let audience = ExerciseAudience(rawValue: cloudExercise.audience) ?? .both
            return audience.matches(dog.species)
        }
    }

    private var combinedFeed: [FeedItem] {
        (filteredLocal.map(FeedItem.local) + filteredCloud.map(FeedItem.cloud))
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyStateText: String {
        switch feedScope {
        case .all:
            return "Здесь пока пусто. Добавь своё упражнение кнопкой «+» вверху."
        case .mine:
            return "Пока никто не подписан. Открой упражнение и нажми «Подписаться», чтобы добавить его сюда — это как TODO."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    feedPicker
                    categoryPicker

                    if let errorMessage = communityService.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if communityService.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Загружаем сообщество…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if combinedFeed.isEmpty && !communityService.isLoading {
                        Text(emptyStateText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(combinedFeed) { item in
                                feedRow(for: item)
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable { await communityService.loadFeed() }
            .navigationTitle("Упражнения")
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(dog: dog, exercise: exercise)
            }
            .navigationDestination(for: CloudExercise.self) { cloudExercise in
                CloudExerciseDetailView(cloudExercise: cloudExercise, isAdded: false) {
                    addToLibrary(cloudExercise)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ArchivedExercisesView()
                    } label: {
                        Image(systemName: "archivebox")
                    }
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView()
            }
            .task {
                if communityService.feed.isEmpty {
                    await communityService.loadFeed()
                }
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private func feedRow(for item: FeedItem) -> some View {
        switch item {
        case .local(let exercise):
            NavigationLink(value: exercise) {
                ExerciseRow(exercise: exercise)
            }
            .buttonStyle(.plain)
        case .cloud(let cloudExercise):
            NavigationLink(value: cloudExercise) {
                CommunityRow(cloudExercise: cloudExercise)
            }
            .buttonStyle(.plain)
        }
    }

    private func addToLibrary(_ cloudExercise: CloudExercise) {
        let exercise = cloudExercise.makeLocalExercise()
        modelContext.insert(exercise)
    }

    private var feedPicker: some View {
        Picker("Лента", selection: $feedScope) {
            ForEach(ExerciseFeedScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Все категории", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    categoryChip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(.thinMaterial))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accentGradient.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon(for: exercise.category))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if exercise.isCustom {
                        Text("Своё")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.15)))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text("\(exercise.category.rawValue) · \(exercise.difficulty.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if exercise.isSubscribed {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }

            if exercise.reaction == .like {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    private func icon(for category: ExerciseCategory) -> String {
        switch category {
        case .obedience: return "checkmark.seal.fill"
        case .impulseControl: return "hand.raised.fill"
        case .socialization: return "figure.2.and.child.holdinghands"
        case .tricks: return "sparkles"
        }
    }
}

/// Строка облачного (ещё не скачанного) упражнения — визуально отличается
/// небольшой подписью «из сообщества», чтобы сразу было видно, что это
/// не часть твоей библиотеки, а предложение добавить.
private struct CommunityRow: View {
    let cloudExercise: CloudExercise

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(cloudExercise.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("из сообщества")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }
                Text("\(cloudExercise.category) · \(cloudExercise.difficulty) · автор: \(cloudExercise.authorName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }
}

#Preview {
    ExerciseCatalogView(dog: Dog(name: "Рекс"))
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
}
