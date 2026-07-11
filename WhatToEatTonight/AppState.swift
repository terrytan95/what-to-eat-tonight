import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var selectedIngredients: Set<String> = []
    var maximumMinutes = 30
    var diets: Set<Diet> = []
    var favorites: Set<String> = []
    var disliked: Set<String> = []
    var recentChoices: [String] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        disliked = Set(defaults.stringArray(forKey: "disliked") ?? [])
        recentChoices = defaults.stringArray(forKey: "recentChoices") ?? []
    }

    func toggleFavorite(_ id: String) {
        favorites.formSymmetricDifference([id])
        defaults.set(Array(favorites), forKey: "favorites")
    }

    func dislike(_ id: String) {
        disliked.insert(id)
        defaults.set(Array(disliked), forKey: "disliked")
    }

    func choose(_ id: String) {
        recentChoices = Array(([id] + recentChoices.filter { $0 != id }).prefix(10))
        defaults.set(recentChoices, forKey: "recentChoices")
    }
}
