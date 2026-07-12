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

@Model
final class InventoryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var storage: String
    var purchasedAt: Date
    var expiresAt: Date?
    var isStaple: Bool
    var barcode: String?

    init(id: UUID = UUID(), name: String, quantity: Double = 1, unit: String = "份", storage: String = "冷藏", purchasedAt: Date = .now, expiresAt: Date? = nil, isStaple: Bool = false, barcode: String? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.storage = storage
        self.purchasedAt = purchasedAt
        self.expiresAt = expiresAt
        self.isStaple = isStaple
        self.barcode = barcode
    }
}

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var isChecked: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, quantity: Double = 1, unit: String = "份", category: String, isChecked: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.isChecked = isChecked
        self.createdAt = createdAt
    }
}

@MainActor
final class PersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: UserProfile.self, MealRecord.self, InventoryItem.self, ShoppingItem.self, configurations: configuration)
        } catch {
            fatalError("Unable to initialize local storage: \(error.localizedDescription)")
        }
    }
}
