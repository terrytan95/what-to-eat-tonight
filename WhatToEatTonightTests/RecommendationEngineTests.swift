import Foundation
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

    @Test func dinnerDeciderReusesFiltersAndHonorsExclusions() {
        let choices = DinnerDecider.choices(mode: .cook, maximumMinutes: 15, diets: [.vegetarian], excluding: ["tomato-eggs"])
        #expect(choices.allSatisfy { $0.id != "tomato-eggs" })
        #expect(choices.contains { $0.id == "cheese-toast" })
    }

    @Test func recognizesCommonIngredientAliases() {
        let results = RecommendationEngine.recommendations(ingredients: ["西红柿", "鸡蛋"], maximumMinutes: 20, diets: [])
        #expect(results.first?.recipe.id == "tomato-eggs")
        #expect(results.first?.missing.isEmpty == true)
    }

    @Test func feedbackAndRecencyAffectRankingReason() {
        let results = RecommendationEngine.recommendations(
            ingredients: ["番茄", "鸡蛋", "面包", "奶酪"],
            maximumMinutes: 20,
            diets: [.vegetarian],
            ratings: ["cheese-toast": 2],
            recentIDs: ["tomato-eggs"]
        )
        #expect(results.first?.recipe.id == "cheese-toast")
        #expect(results.first?.reason == "你上次觉得很好吃")
    }

    @Test func prioritizesRecipesThatUseExpiringIngredients() {
        let results = RecommendationEngine.recommendations(
            ingredients: ["番茄", "鸡蛋", "面包", "奶酪"],
            maximumMinutes: 20,
            diets: [.vegetarian],
            priorityIngredients: ["奶酪"]
        )
        #expect(results.first?.recipe.id == "cheese-toast")
        #expect(results.first?.reason.contains("临期食材") == true)
    }

    @Test func appliesAdvancedFiltersTogether() {
        let filters = RecommendationFilters(effort: .easy, tool: .onePot, cuisine: .chinese, occasion: .fitness, nutrition: .lowerCarb, weather: .hot, budgetPerPerson: 20)
        let results = RecommendationEngine.recommendations(ingredients: ["豆腐", "蘑菇", "青菜"], maximumMinutes: 30, diets: [.vegetarian], filters: filters)
        #expect(results.map(\.recipe.id) == ["tofu-mushroom"])
    }

    @Test func suggestsKnownIngredientSubstitutions() {
        let result = RecommendationEngine.recommendations(ingredients: ["番茄"], maximumMinutes: 20, diets: []).first { $0.recipe.id == "tomato-eggs" }
        #expect(result?.substitutions == ["鸡蛋可换嫩豆腐"])
    }

    @Test func duelEliminatesOnlyTheLosingChoice() {
        var duel = RecipeDuel(contenderIDs: ["a", "b", "c"])
        duel.choose("b")
        #expect(duel.contenderIDs == ["b", "c"])
        duel.choose("c")
        #expect(duel.winnerID == "c")
    }

    @Test func nutritionScalesFromIngredientWeightAndServings() {
        let one = NutritionEstimator.estimate(recipe: RecipeCatalog.recipes[0], servings: 1)
        let two = NutritionEstimator.estimate(recipe: RecipeCatalog.recipes[0], servings: 2)
        #expect(one.protein > 0)
        #expect(abs(two.protein - one.protein * 2) < 0.001)
        #expect(abs(two.calories - one.calories * 2) < 0.001)
        #expect(NutritionEstimator.matches(.lighter, recipe: RecipeCatalog.recipes[0]))
    }

    @Test func nutritionUsesGramsAndRejectsUnsupportedWeights() {
        let nutrients = NutritionEstimator.estimate(ingredientWeights: ["鸡蛋": 100, "番茄": 200, "未知食材": 500, "米饭": -20])
        #expect(abs(nutrients.protein - 14.32) < 0.01)
        #expect(abs(nutrients.fat - 9.91) < 0.01)
        #expect(abs(nutrients.carbohydrates - 8.5) < 0.01)
        #expect(abs(nutrients.calories - 179) < 0.01)
        #expect(Set(RecipeCatalog.ingredients).isSubset(of: NutritionEstimator.supportedIngredients))
        #expect(NutritionEstimator.sourceURL.host == "fdc.nal.usda.gov")
    }

    @Test func parsesValidatedAppLinks() {
        guard case .recipe(let recipe) = DeepLink(url: URL(string: "wteat://recipe/tomato-eggs")!) else {
            Issue.record("Expected a recipe deep link")
            return
        }
        #expect(recipe.id == "tomato-eggs")
        guard case .room(let code) = DeepLink(url: URL(string: "wteat://room/123456")!) else {
            Issue.record("Expected a room deep link")
            return
        }
        #expect(code == "123456")
        #expect(DeepLink(url: URL(string: "wteat://room/123")!) == nil)
    }
}
