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
        struct Inventory: Codable {
            let id: UUID
            let name: String
            let quantity: Double
            let unit: String
            let storage: String
            let purchasedAt: Date
            let expiresAt: Date?
            let isStaple: Bool
            let barcode: String?
        }
        struct Shopping: Codable {
            let id: UUID
            let name: String
            let quantity: Double
            let unit: String
            let category: String
            let isChecked: Bool
            let createdAt: Date
        }

        let version: Int
        let favorites: [String]
        let disliked: [String]
        let recentChoices: [String]
        let meals: [Meal]?
        let inventory: [Inventory]?
        let shopping: [Shopping]?
    }

    var selectedIngredients: Set<String> = []
    var maximumMinutes = 30
    var diets: Set<Diet> = []
    var favorites: Set<String> = []
    var disliked: Set<String> = []
    var recentChoices: [String] = []
    var mealHistory: [MealRecord] = []
    var inventory: [InventoryItem] = []
    var shoppingList: [ShoppingItem] = []
    var recommendationFilters = RecommendationFilters()
    var servings = 2

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
        inventory = (try? context.fetch(FetchDescriptor<InventoryItem>(sortBy: [SortDescriptor(\.name)]))) ?? []
        shoppingList = (try? context.fetch(FetchDescriptor<ShoppingItem>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
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

    var expiringIngredients: Set<String> {
        let deadline = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return Set(inventory.filter { $0.quantity > 0 && $0.expiresAt.map { $0 <= deadline } == true }.map(\.name))
    }

    func addInventory(name: String, quantity: Double, unit: String, storage: String, expiresAt: Date?, isStaple: Bool, barcode: String? = nil) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, quantity > 0 else { return }
        if expiresAt == nil, let existing = inventory.first(where: { $0.name == name && $0.unit == unit && $0.storage == storage && $0.expiresAt == nil }) {
            existing.quantity += quantity
            existing.isStaple = existing.isStaple || isStaple
            selectedIngredients.insert(name)
            persist()
            return
        }
        let item = InventoryItem(name: name, quantity: quantity, unit: unit, storage: storage, expiresAt: expiresAt, isStaple: isStaple, barcode: barcode)
        context.insert(item)
        inventory.append(item)
        inventory.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        selectedIngredients.insert(name)
        persist()
    }

    func addKnownBarcode(_ barcode: String) -> Bool {
        guard let item = inventory.first(where: { $0.barcode == barcode }) else { return false }
        item.quantity += 1
        selectedIngredients.insert(item.name)
        persist()
        return true
    }

    func addInventory(text: String, storage: String = "冷藏") {
        text.components(separatedBy: CharacterSet(charactersIn: "、，,；;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.prefix(100)
            .forEach { addInventory(name: $0, quantity: 1, unit: "份", storage: storage, expiresAt: nil, isStaple: false) }
    }

    func deleteInventory(_ item: InventoryItem) {
        inventory.removeAll { $0.id == item.id }
        context.delete(item)
        if !inventory.contains(where: { $0.name == item.name && $0.quantity > 0 }) { selectedIngredients.remove(item.name) }
        persist()
    }

    func consume(_ item: InventoryItem, amount: Double = 1) {
        item.quantity = max(0, item.quantity - amount)
        if item.quantity == 0 { selectedIngredients.remove(item.name) }
        persist()
    }

    func consumeIngredients(_ names: [String]) {
        // ponytail: quantities are user-defined units; deduct one unit until recipes carry measured amounts.
        names.compactMap { name in inventory.first { $0.name == name && $0.quantity > 0 } }.forEach { item in
            item.quantity = max(0, item.quantity - 1)
            if item.quantity == 0 { selectedIngredients.remove(item.name) }
        }
        persist()
    }

    func addShoppingItem(name: String, quantity: Double = 1, unit: String = "份") {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, quantity > 0 else { return }
        if let existing = shoppingList.first(where: { $0.name == name && $0.unit == unit && !$0.isChecked }) {
            existing.quantity += quantity
        } else {
            let item = ShoppingItem(name: name, quantity: quantity, unit: unit, category: Self.shoppingCategory(for: name))
            context.insert(item)
            shoppingList.append(item)
        }
        persist()
    }

    func addRecipeToShoppingList(_ recipe: Recipe) {
        let stocked = Set(inventory.filter { $0.quantity > 0 }.map(\.name))
        recipe.ingredients.filter { !stocked.contains($0) }.forEach { addShoppingItem(name: $0) }
    }

    func toggleShoppingItem(_ item: ShoppingItem) { item.isChecked.toggle(); persist() }
    func deleteShoppingItem(_ item: ShoppingItem) { shoppingList.removeAll { $0.id == item.id }; context.delete(item); persist() }

    var shoppingListText: String {
        shoppingList.filter { !$0.isChecked }.map { "□ \($0.name) \($0.quantity.formatted()) \($0.unit)" }.joined(separator: "\n")
    }

    private static func shoppingCategory(for name: String) -> String {
        if ["鸡肉", "牛肉", "虾", "鸡蛋"].contains(name) { return "肉蛋水产" }
        if ["米饭", "面条", "面包"].contains(name) { return "主食" }
        if ["奶酪"].contains(name) { return "乳制品" }
        return "蔬菜及其他"
    }

    func exportData() throws -> String {
        let meals = mealHistory.map { Archive.Meal(id: $0.id, recipeID: $0.recipeID, cookedAt: $0.cookedAt, rating: $0.rating, note: $0.note) }
        let inventory = inventory.map { Archive.Inventory(id: $0.id, name: $0.name, quantity: $0.quantity, unit: $0.unit, storage: $0.storage, purchasedAt: $0.purchasedAt, expiresAt: $0.expiresAt, isStaple: $0.isStaple, barcode: $0.barcode) }
        let shopping = shoppingList.map { Archive.Shopping(id: $0.id, name: $0.name, quantity: $0.quantity, unit: $0.unit, category: $0.category, isChecked: $0.isChecked, createdAt: $0.createdAt) }
        let archive = Archive(version: 1, favorites: favorites.sorted(), disliked: disliked.sorted(), recentChoices: recentChoices, meals: meals, inventory: inventory, shopping: shopping)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(archive), as: UTF8.self)
    }

    func importData(_ text: String) throws {
        guard text.utf8.count <= 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(text.utf8))
        guard archive.version == 1,
              (archive.meals?.count ?? 0) <= 10_000,
              archive.meals?.allSatisfy({ !$0.recipeID.isEmpty && (0...2).contains($0.rating) }) != false,
              (archive.inventory?.count ?? 0) <= 10_000,
              archive.inventory?.allSatisfy({ !$0.name.isEmpty && $0.quantity >= 0 }) != false
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
        try context.delete(model: InventoryItem.self)
        inventory = (archive.inventory ?? []).map {
            let item = InventoryItem(id: $0.id, name: $0.name, quantity: $0.quantity, unit: $0.unit, storage: $0.storage, purchasedAt: $0.purchasedAt, expiresAt: $0.expiresAt, isStaple: $0.isStaple, barcode: $0.barcode)
            context.insert(item)
            return item
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        try context.delete(model: ShoppingItem.self)
        shoppingList = (archive.shopping ?? []).filter { !$0.name.isEmpty && $0.quantity >= 0 }.map {
            let item = ShoppingItem(id: $0.id, name: $0.name, quantity: $0.quantity, unit: $0.unit, category: $0.category, isChecked: $0.isChecked, createdAt: $0.createdAt)
            context.insert(item)
            return item
        }
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
            try context.delete(model: InventoryItem.self)
            try context.delete(model: ShoppingItem.self)
            mealHistory = []
            inventory = []
            shoppingList = []
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
