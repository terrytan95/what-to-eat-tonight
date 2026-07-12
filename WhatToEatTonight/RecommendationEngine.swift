import Foundation

enum RecommendationEngine {
    static func recommendations(
        ingredients: Set<String>,
        maximumMinutes: Int,
        diets: Set<Diet>,
        excluding excludedIDs: Set<String> = [],
        ratings: [String: Int] = [:],
        recentIDs: [String] = [],
        priorityIngredients: Set<String> = [],
        filters: RecommendationFilters = .init(),
        recipes: [Recipe] = RecipeCatalog.recipes
    ) -> [Recommendation] {
        let aliases = ["西红柿": "番茄", "洋芋": "土豆", "马铃薯": "土豆", "大虾": "虾"]
        let substitutes = ["番茄": "罐装番茄", "鸡蛋": "嫩豆腐", "米饭": "面条", "鸡肉": "豆腐", "牛肉": "鸡肉", "青菜": "任意叶菜", "洋葱": "葱", "奶酪": "无乳奶酪", "面包": "馒头"]
        let normalizedIngredients = Set(ingredients.map { aliases[$0] ?? $0 })
        return recipes
            .filter { recipe in
                let attributes = recipe.attributes
                return recipe.isEligible(maximumMinutes: maximumMinutes, diets: diets, excluding: excludedIDs)
                    && filters.effort.map { attributes.effort.rawValue <= $0.rawValue } != false
                    && filters.tool.map(attributes.tools.contains) != false
                    && filters.cuisine.map { attributes.cuisine == $0 } != false
                    && filters.occasion.map(attributes.occasions.contains) != false
                    && filters.nutrition.map { NutritionEstimator.matches($0, recipe: recipe) } != false
                    && filters.weather.map(attributes.weather.contains) != false
                    && filters.budgetPerPerson.map { attributes.estimatedCostPerPerson <= $0 } != false
            }
            .map { recipe in
                let available = recipe.ingredients.filter(normalizedIngredients.contains)
                let missing = recipe.ingredients.filter { !normalizedIngredients.contains($0) }
                let coverage = Double(available.count) / Double(recipe.ingredients.count)
                let ratingBonus = Double((ratings[recipe.id] ?? 1) - 1) * 0.12
                let recentPenalty = recentIDs.prefix(7).contains(recipe.id) ? 0.18 : 0
                let priorityCount = recipe.ingredients.filter(priorityIngredients.contains).count
                let reason = if priorityCount > 0 { "优先用掉 \(priorityCount) 种临期食材" }
                    else if ratings[recipe.id] == 2 { "你上次觉得很好吃" }
                    else if recentPenalty > 0 { "最近吃过，已降低排序" }
                    else if missing.isEmpty { "现有食材完全匹配" }
                    else { "只缺 \(missing.count) 种食材" }
                let substitutions = missing.compactMap { ingredient in substitutes[ingredient].map { "\(ingredient)可换\($0)" } }
                return Recommendation(recipe: recipe, available: available, missing: missing, score: coverage - Double(missing.count) * 0.05 + ratingBonus - recentPenalty + Double(priorityCount) * 0.15, reason: reason, substitutions: substitutions)
            }
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.recipe.minutes < rhs.recipe.minutes : lhs.score > rhs.score
            }
    }
}
