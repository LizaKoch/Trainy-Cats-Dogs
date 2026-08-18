import SwiftUI
import SwiftData

struct DogOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var breed = ""
    @State private var species: PetSpecies = .dog

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentGradient)
                            .frame(width: 88, height: 88)
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.white)
                    }
                    Text("Знакомство")
                        .font(.largeTitle.bold())
                    Text("Расскажи о своём питомце, чтобы начать тренировки")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 14) {
                    Picker("Вид питомца", selection: $species) {
                        ForEach(PetSpecies.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Кличка", text: $name)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Порода (необязательно)", text: $breed)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("Мы сразу добавим стартовую библиотеку из 15 упражнений, чтобы было с чего начать.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    let dog = Dog(name: name.trimmingCharacters(in: .whitespaces), breed: breed, species: species)
                    modelContext.insert(dog)
                    seedExercisesIfNeeded(context: modelContext)
                } label: {
                    Text("Начать")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!isValid)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview {
    DogOnboardingView()
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
}
