import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var dogs: [Dog]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let dog = dogs.first {
            MainTabView(dog: dog)
                .task { updateSeedExercisesIfNeeded(context: modelContext) }
        } else {
            DogOnboardingView()
        }
    }
}

struct MainTabView: View {
    let dog: Dog

    var body: some View {
        TabView {
            ExerciseCatalogView(dog: dog)
                .tabItem { Label("Упражнения", systemImage: "list.bullet") }

            StatsView(dog: dog)
                .tabItem { Label("Статистика", systemImage: "chart.bar.fill") }

            ProgressJournalView(dog: dog)
                .tabItem { Label("Прогресс", systemImage: "chart.line.uptrend.xyaxis") }

            DogProfileView(dog: dog)
                .tabItem { Label("Профиль", systemImage: "pawprint.fill") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
        .environmentObject(AuthService())
}
