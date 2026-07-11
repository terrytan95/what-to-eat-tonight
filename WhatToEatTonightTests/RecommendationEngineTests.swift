import Testing
@testable import WhatToEatTonight

struct RecommendationEngineTests {
    @Test func ranksBestIngredientCoverageFirst() {
        let results = RecommendationEngine.recommendations(ingredients: ["番茄", "鸡蛋"], maximumMinutes: 30, diets: [])
        #expect(results.first?.recipe.id == "tomato-eggs")
        #expect(results.first?.missing.isEmpty == true)
    }

    @Test func appliesTimeDietAndExclusionFilters() {
        let results = RecommendationEngine.recommendations(ingredients: ["米饭", "鸡蛋"], maximumMinutes: 20, diets: [.vegetarian], excluding: ["tomato-eggs"])
        #expect(results.allSatisfy { $0.recipe.minutes <= 20 && $0.recipe.diets.contains(.vegetarian) })
        #expect(!results.contains { $0.recipe.id == "tomato-eggs" })
    }
}
