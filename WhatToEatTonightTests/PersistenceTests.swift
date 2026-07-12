import Foundation
import SwiftData
import Testing
@testable import WhatToEatTonight

@MainActor
struct PersistenceTests {
    @Test func migratesLegacyPreferencesOnce() throws {
        let suite = "PersistenceTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(["tomato-eggs"], forKey: "favorites")
        defaults.set(["fried-rice"], forKey: "disliked")
        defaults.set(["cheese-toast"], forKey: "recentChoices")
        defer { defaults.removePersistentDomain(forName: suite) }

        let persistence = PersistenceController(inMemory: true)
        let state = AppState(context: persistence.container.mainContext, defaults: defaults)

        #expect(state.favorites == ["tomato-eggs"])
        #expect(state.disliked == ["fried-rice"])
        #expect(state.recentChoices == ["cheese-toast"])
        #expect(defaults.object(forKey: "favorites") == nil)

        state.toggleFavorite("fried-rice")
        let reloaded = AppState(context: persistence.container.mainContext, defaults: defaults)
        #expect(reloaded.favorites == ["fried-rice", "tomato-eggs"])

        let exported = try state.exportData()
        state.deleteAllData()
        #expect(state.favorites.isEmpty)
        try state.importData(exported)
        #expect(state.favorites == ["fried-rice", "tomato-eggs"])

        state.addInventory(text: "鸡蛋、番茄\n鸡蛋")
        #expect(state.inventory.count == 2)
        #expect(state.inventory.first { $0.name == "鸡蛋" }?.quantity == 2)

        state.addRecipeToShoppingList(RecipeCatalog.recipes.first { $0.id == "cheese-toast" }!)
        #expect(state.shoppingList.map(\.name) == ["面包", "奶酪"])
        state.addShoppingItem(name: "面包")
        #expect(state.shoppingList.first { $0.name == "面包" }?.quantity == 2)

        state.addFamilyMember(name: "A", diets: [.vegetarian], exclusions: "蘑菇")
        #expect(state.generateMealPlan(days: 3))
        #expect(state.mealPlan.count == 3)
        #expect(state.mealPlan.allSatisfy { entry in
            RecipeCatalog.recipes.first { $0.id == entry.recipeID }?.diets.contains(.vegetarian) == true
        })

        let session = state.cookingSession(for: "tomato-eggs")
        state.moveCookingStep(session, to: 2, stepCount: 3)
        state.addCookingTimer(recipeID: "tomato-eggs", minutes: 5)
        #expect(session.currentStep == 2)
        #expect(state.cookingTimers.count == 1)

        state.addCustomRecipe(
            name: "健身鸡肉饭",
            emoji: "🥗",
            ingredientWeights: ["鸡肉": 240, "米饭": 200, "青菜": 160],
            minutes: 25,
            diets: [.dairyFree, .glutenFree],
            steps: ["煎熟鸡肉", "组合装盘"]
        )
        let custom = try #require(state.customRecipes.first?.recipe)
        #expect(custom.ingredientGrams["鸡肉"] == 240)
        #expect(NutritionEstimator.estimate(recipe: custom, servings: 1).protein > 35)
        #expect(RecommendationEngine.recommendations(ingredients: ["鸡肉", "米饭", "青菜"], maximumMinutes: 30, diets: [], recipes: state.allRecipes).contains { $0.recipe.id == custom.id })
    }
}
