import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    struct Archive: Codable {
        struct Meal: Codable {
            let id: UUID
            let recipeID: String
            let cookedAt: Date
            let rating: Int
            let note: String
        }

        let version: Int
        let favorites: [String]
        let disliked: [String]
        let recentChoices: [String]
        let meals: [Meal]?
    }

    var selectedIngredients: Set<String> = []
    var maximumMinutes = 30
    var diets: Set<Diet> = []
    var favorites: Set<String> = []
    var disliked: Set<String> = []
    var recentChoices: [String] = []
    var mealHistory: [MealRecord] = []

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
        let meals = FetchDescriptor<MealRecord>(sortBy: [SortDescriptor(\.cookedAt, order: .reverse)])
        mealHistory = (try? context.fetch(meals)) ?? []
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

    func recordMeal(_ recipeID: String, rating: Int, note: String = "", privateEntry: Bool = false) {
        guard (0...2).contains(rating) else { return }
        if !privateEntry {
            let record = MealRecord(recipeID: recipeID, rating: rating, note: note)
            context.insert(record)
            mealHistory.insert(record, at: 0)
            choose(recipeID)
        }
        if rating == 2 { favorites.insert(recipeID); profile.favoriteRecipeIDs = favorites.sorted() }
        if rating == 0 { disliked.insert(recipeID); profile.dislikedRecipeIDs = disliked.sorted() }
        persist()
    }

    func rating(for recipeID: String) -> Int? { mealHistory.first { $0.recipeID == recipeID }?.rating }

    var ratings: [String: Int] {
        Dictionary(mealHistory.reversed().map { ($0.recipeID, $0.rating) }, uniquingKeysWith: { _, latest in latest })
    }

    func exportData() throws -> String {
        let meals = mealHistory.map { Archive.Meal(id: $0.id, recipeID: $0.recipeID, cookedAt: $0.cookedAt, rating: $0.rating, note: $0.note) }
        let archive = Archive(version: 1, favorites: favorites.sorted(), disliked: disliked.sorted(), recentChoices: recentChoices, meals: meals)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(archive), as: UTF8.self)
    }

    func importData(_ text: String) throws {
        guard text.utf8.count <= 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(text.utf8))
        guard archive.version == 1,
              (archive.meals?.count ?? 0) <= 10_000,
              archive.meals?.allSatisfy({ !$0.recipeID.isEmpty && (0...2).contains($0.rating) }) != false
        else { throw CocoaError(.coderReadCorrupt) }
        favorites = Set(archive.favorites)
        disliked = Set(archive.disliked)
        recentChoices = Array(archive.recentChoices.prefix(10))
        profile.favoriteRecipeIDs = favorites.sorted()
        profile.dislikedRecipeIDs = disliked.sorted()
        profile.recentRecipeIDs = recentChoices
        try context.delete(model: MealRecord.self)
        mealHistory = (archive.meals ?? []).map {
            let record = MealRecord(id: $0.id, recipeID: $0.recipeID, cookedAt: $0.cookedAt, rating: $0.rating, note: $0.note)
            context.insert(record)
            return record
        }.sorted { $0.cookedAt > $1.cookedAt }
        try context.save()
    }

    func deleteAllData() {
        favorites = []
        disliked = []
        recentChoices = []
        profile.favoriteRecipeIDs = []
        profile.dislikedRecipeIDs = []
        profile.recentRecipeIDs = []
        do {
            try context.delete(model: MealRecord.self)
            mealHistory = []
        } catch {
            assertionFailure("Unable to delete meal history: \(error.localizedDescription)")
        }
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
