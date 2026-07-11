import Foundation

enum RecommendationEngine {
    static func recommendations(
        ingredients: Set<String>,
        maximumMinutes: Int,
        diets: Set<Diet>,
        excluding excludedIDs: Set<String> = []
    ) -> [Recommendation] {
        RecipeCatalog.recipes
            .filter { !excludedIDs.contains($0.id) && $0.minutes <= maximumMinutes && diets.isSubset(of: $0.diets) }
            .map { recipe in
                let available = recipe.ingredients.filter(ingredients.contains)
                let missing = recipe.ingredients.filter { !ingredients.contains($0) }
                let coverage = Double(available.count) / Double(recipe.ingredients.count)
                return Recommendation(recipe: recipe, available: available, missing: missing, score: coverage - Double(missing.count) * 0.05)
            }
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.recipe.minutes < rhs.recipe.minutes : lhs.score > rhs.score
            }
    }
}
