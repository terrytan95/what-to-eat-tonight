import Foundation

enum RecommendationEngine {
    static func recommendations(
        ingredients: Set<String>,
        maximumMinutes: Int,
        diets: Set<Diet>,
        excluding excludedIDs: Set<String> = []
    ) -> [Recommendation] {
        let aliases = ["西红柿": "番茄", "洋芋": "土豆", "马铃薯": "土豆", "大虾": "虾"]
        let normalizedIngredients = Set(ingredients.map { aliases[$0] ?? $0 })
        return RecipeCatalog.recipes
            .filter { $0.isEligible(maximumMinutes: maximumMinutes, diets: diets, excluding: excludedIDs) }
            .map { recipe in
                let available = recipe.ingredients.filter(normalizedIngredients.contains)
                let missing = recipe.ingredients.filter { !normalizedIngredients.contains($0) }
                let coverage = Double(available.count) / Double(recipe.ingredients.count)
                return Recommendation(recipe: recipe, available: available, missing: missing, score: coverage - Double(missing.count) * 0.05)
            }
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.recipe.minutes < rhs.recipe.minutes : lhs.score > rhs.score
            }
    }
}
