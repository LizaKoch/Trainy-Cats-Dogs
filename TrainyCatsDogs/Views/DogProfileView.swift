import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct DogProfileView: View {
    @Bindable var dog: Dog
    @EnvironmentObject private var auth: AuthService
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoSection
                    infoCard
                    accountCard
                }
                .padding()
            }
            .navigationTitle("Профиль")
            .background(Theme.background.ignoresSafeArea())
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Фото с камеры может весить несколько мегабайт — а показываем
                    // мы его в кружке 120×120. Без уменьшения телефон каждый раз
                    // декодирует и хранит полноразмерный оригинал впустую.
                    dog.photoData = Self.downsizedJPEGData(from: uiImage)
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                photoImage
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.accent, .white)
                }
            }

            Text(dog.name.isEmpty ? "Без имени" : dog.name)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var photoImage: some View {
        if let data = dog.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(Theme.accentGradient)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
        }
    }

    /// Уменьшает изображение до разумного максимального размера и сжимает
    /// в JPEG перед сохранением в базу — вместо хранения оригинала на
    /// несколько мегабайт ради маленькой круглой иконки профиля.
    private static func downsizedJPEGData(from image: UIImage, maxDimension: CGFloat = 600) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("О питомце").font(.headline)
            Picker("Вид", selection: $dog.species) {
                ForEach(PetSpecies.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Divider()
            TextField("Кличка", text: $dog.name)
            Divider()
            TextField("Порода", text: $dog.breed)
            Divider()
            TextField("Заметки", text: $dog.notes, axis: .vertical)
        }
        .cardStyle()
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Аккаунт").font(.headline)
            if let email = auth.user?.email {
                Label(email, systemImage: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                auth.signOut()
            } label: {
                Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .cardStyle()
    }
}

#Preview {
    DogProfileView(dog: Dog(name: "Рекс"))
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
        .environmentObject(AuthService())
}
