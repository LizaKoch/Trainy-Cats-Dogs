import Foundation
import SwiftData

enum PetSpecies: String, Codable, CaseIterable {
    case dog = "Собака"
    case cat = "Кошка"
}

@Model
final class Dog {
    var name: String
    var breed: String
    var birthDate: Date?
    var notes: String
    var createdAt: Date
    var speciesRaw: String = PetSpecies.dog.rawValue
    @Attribute(.externalStorage) var photoData: Data?

    var species: PetSpecies {
        get { PetSpecies(rawValue: speciesRaw) ?? .dog }
        set { speciesRaw = newValue.rawValue }
    }

    init(
        name: String,
        breed: String = "",
        birthDate: Date? = nil,
        notes: String = "",
        species: PetSpecies = .dog,
        photoData: Data? = nil
    ) {
        self.name = name
        self.breed = breed
        self.birthDate = birthDate
        self.notes = notes
        self.createdAt = .now
        self.speciesRaw = species.rawValue
        self.photoData = photoData
    }
}
