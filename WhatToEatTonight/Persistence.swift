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

@MainActor
final class PersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: UserProfile.self, configurations: configuration)
        } catch {
            fatalError("Unable to initialize local storage: \(error.localizedDescription)")
        }
    }
}
