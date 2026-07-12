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

@Model
final class FamilyMember {
    @Attribute(.unique) var id: UUID
    var name: String
    var dietRawValues: [String]
    var excludedIngredients: [String]

    init(id: UUID = UUID(), name: String, dietRawValues: [String] = [], excludedIngredients: [String] = []) {
        self.id = id
        self.name = name
        self.dietRawValues = dietRawValues
        self.excludedIngredients = excludedIngredients
    }
}

@Model
final class MealPlanEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var recipeID: String
    var servings: Int

    init(id: UUID = UUID(), date: Date, recipeID: String, servings: Int) {
        self.id = id
        self.date = date
        self.recipeID = recipeID
        self.servings = servings
    }
}

@Model
final class CookingSession {
    @Attribute(.unique) var id: UUID
    var recipeID: String
    var currentStep: Int
    var startedAt: Date

    init(id: UUID = UUID(), recipeID: String, currentStep: Int = 0, startedAt: Date = .now) {
        self.id = id
        self.recipeID = recipeID
        self.currentStep = currentStep
        self.startedAt = startedAt
    }
}

@Model
final class CookingTimer {
    @Attribute(.unique) var id: UUID
    var recipeID: String
    var label: String
    var endDate: Date

    init(id: UUID = UUID(), recipeID: String, label: String, endDate: Date) {
        self.id = id
        self.recipeID = recipeID
        self.label = label
        self.endDate = endDate
    }
}

@MainActor
final class PersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: UserProfile.self, MealRecord.self, InventoryItem.self, ShoppingItem.self, FamilyMember.self, MealPlanEntry.self, CookingSession.self, CookingTimer.self, configurations: configuration)
        } catch {
            fatalError("Unable to initialize local storage: \(error.localizedDescription)")
        }
    }
}
