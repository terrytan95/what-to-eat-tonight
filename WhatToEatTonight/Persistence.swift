import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var key: String
    var favoriteRecipeIDs: [String]
    var dislikedRecipeIDs: [String]
    var recentRecipeIDs: [String]

    init(
        key: String = "primary",
        favoriteRecipeIDs: [String] = [],
        dislikedRecipeIDs: [String] = [],
        recentRecipeIDs: [String] = []
    ) {
        self.key = key
        self.favoriteRecipeIDs = favoriteRecipeIDs
        self.dislikedRecipeIDs = dislikedRecipeIDs
        self.recentRecipeIDs = recentRecipeIDs
    }
}

@Model
final class MealRecord {
    @Attribute(.unique) var id: UUID
    var recipeID: String
    var cookedAt: Date
    var rating: Int
    var note: String

    init(id: UUID = UUID(), recipeID: String, cookedAt: Date = .now, rating: Int, note: String = "") {
        self.id = id
        self.recipeID = recipeID
        self.cookedAt = cookedAt
        self.rating = rating
        self.note = note
    }
}

@MainActor
final class PersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: UserProfile.self, MealRecord.self, configurations: configuration)
        } catch {
            fatalError("Unable to initialize local storage: \(error.localizedDescription)")
        }
    }
}
