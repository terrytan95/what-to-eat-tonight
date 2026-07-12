import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    struct Archive: Codable {
        let version: Int
        let favorites: [String]
        let disliked: [String]
        let recentChoices: [String]
    }

    var selectedIngredients: Set<String> = []
    var maximumMinutes = 30
    var diets: Set<Diet> = []
    var favorites: Set<String> = []
    var disliked: Set<String> = []
    var recentChoices: [String] = []

    private let context: ModelContext
    private let profile: UserProfile

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.key == "primary" })
        let stored: UserProfile?
        do {
            stored = try context.fetch(descriptor).first
        } catch {
            fatalError("Unable to read local preferences: \(error.localizedDescription)")
        }
        if let stored {
            profile = stored
        } else {
            let migrated = UserProfile(
                favoriteRecipeIDs: defaults.stringArray(forKey: "favorites") ?? [],
                dislikedRecipeIDs: defaults.stringArray(forKey: "disliked") ?? [],
                recentRecipeIDs: defaults.stringArray(forKey: "recentChoices") ?? []
            )
            context.insert(migrated)
            profile = migrated
            do {
                try context.save()
            } catch {
                context.rollback()
                fatalError("Unable to migrate local preferences: \(error.localizedDescription)")
            }
            defaults.removeObject(forKey: "favorites")
            defaults.removeObject(forKey: "disliked")
            defaults.removeObject(forKey: "recentChoices")
        }
        favorites = Set(profile.favoriteRecipeIDs)
        disliked = Set(profile.dislikedRecipeIDs)
        recentChoices = profile.recentRecipeIDs
    }

    func toggleFavorite(_ id: String) {
        favorites.formSymmetricDifference([id])
        profile.favoriteRecipeIDs = favorites.sorted()
        persist()
    }

    func dislike(_ id: String) {
        disliked.insert(id)
        profile.dislikedRecipeIDs = disliked.sorted()
        persist()
    }

    func choose(_ id: String) {
        recentChoices = Array(([id] + recentChoices.filter { $0 != id }).prefix(10))
        profile.recentRecipeIDs = recentChoices
        persist()
    }

    func exportData() throws -> String {
        let archive = Archive(version: 1, favorites: favorites.sorted(), disliked: disliked.sorted(), recentChoices: recentChoices)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(archive), as: UTF8.self)
    }

    func importData(_ text: String) throws {
        let archive = try JSONDecoder().decode(Archive.self, from: Data(text.utf8))
        guard archive.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        favorites = Set(archive.favorites)
        disliked = Set(archive.disliked)
        recentChoices = Array(archive.recentChoices.prefix(10))
        profile.favoriteRecipeIDs = favorites.sorted()
        profile.dislikedRecipeIDs = disliked.sorted()
        profile.recentRecipeIDs = recentChoices
        try context.save()
    }

    func deleteAllData() {
        favorites = []
        disliked = []
        recentChoices = []
        profile.favoriteRecipeIDs = []
        profile.dislikedRecipeIDs = []
        profile.recentRecipeIDs = []
        persist()
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            assertionFailure("Unable to save local preferences: \(error.localizedDescription)")
        }
    }
}
