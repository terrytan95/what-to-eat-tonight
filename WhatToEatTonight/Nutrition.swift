import SwiftUI

struct Macronutrients: Equatable {
    var protein: Double = 0
    var fat: Double = 0
    var carbohydrates: Double = 0
    var calories: Double = 0

    static func + (lhs: Self, rhs: Self) -> Self {
        .init(protein: lhs.protein + rhs.protein, fat: lhs.fat + rhs.fat, carbohydrates: lhs.carbohydrates + rhs.carbohydrates, calories: lhs.calories + rhs.calories)
    }

    func scaled(by factor: Double) -> Self {
        .init(protein: protein * factor, fat: fat * factor, carbohydrates: carbohydrates * factor, calories: calories * factor)
    }
}

struct NutritionSummaryView: View {
    let nutrients: Macronutrients
    var title = "营养估算"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            HStack {
                value("蛋白质", nutrients.protein, unit: "g")
                value("脂肪", nutrients.fat, unit: "g")
                value("碳水", nutrients.carbohydrates, unit: "g")
                value("热量", nutrients.calories, unit: "kcal")
            }
            Text("按食材重量和典型食材数据估算，烹饪方式、品牌和可食部会造成差异，不用于医疗决策。")
                .font(.caption2).foregroundStyle(.secondary)
            Link("查看数据来源：USDA FDC", destination: NutritionEstimator.sourceURL).font(.caption2)
        }.appCard()
    }

    private func value(_ name: String, _ amount: Double, unit: String) -> some View {
        VStack(spacing: 3) {
            Text(amount.formatted(.number.precision(.fractionLength(0...1)))).font(.headline).minimumScaleFactor(0.7)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(name).font(.caption2)
        }.frame(maxWidth: .infinity)
    }
}

enum NutritionEstimator {
    static let sourceName = "USDA FoodData Central"
    static let sourceURL = URL(string: "https://fdc.nal.usda.gov/")!

    // Approximate nutrients per 100 g for a representative raw or cooked form.
    private static let per100Grams: [String: Macronutrients] = [
        "鸡蛋": .init(protein: 12.56, fat: 9.51, carbohydrates: 0.72, calories: 143),
        "番茄": .init(protein: 0.88, fat: 0.20, carbohydrates: 3.89, calories: 18),
        "米饭": .init(protein: 2.69, fat: 0.28, carbohydrates: 28.17, calories: 130),
        "面条": .init(protein: 4.54, fat: 2.07, carbohydrates: 25.16, calories: 138),
        "鸡肉": .init(protein: 31.02, fat: 3.57, carbohydrates: 0, calories: 165),
        "牛肉": .init(protein: 26.00, fat: 15.00, carbohydrates: 0, calories: 250),
        "豆腐": .init(protein: 17.30, fat: 8.72, carbohydrates: 2.78, calories: 144),
        "土豆": .init(protein: 2.05, fat: 0.09, carbohydrates: 17.49, calories: 77),
        "洋葱": .init(protein: 1.10, fat: 0.10, carbohydrates: 9.34, calories: 40),
        "青菜": .init(protein: 1.50, fat: 0.20, carbohydrates: 2.18, calories: 13),
        "蘑菇": .init(protein: 3.09, fat: 0.34, carbohydrates: 3.26, calories: 22),
        "虾": .init(protein: 24.00, fat: 0.28, carbohydrates: 0.20, calories: 99),
        "奶酪": .init(protein: 22.87, fat: 33.31, carbohydrates: 3.09, calories: 403),
        "面包": .init(protein: 8.85, fat: 3.33, carbohydrates: 49.42, calories: 266)
    ]

    static var supportedIngredients: Set<String> { Set(per100Grams.keys) }

    static func estimate(ingredientWeights: [String: Double]) -> Macronutrients {
        ingredientWeights.reduce(into: Macronutrients()) { total, item in
            guard item.value > 0, let nutrients = per100Grams[item.key] else { return }
            total = total + nutrients.scaled(by: item.value / 100)
        }
    }

    static func estimate(recipe: Recipe, servings: Int) -> Macronutrients {
        estimate(ingredientWeights: recipe.ingredientGrams).scaled(by: Double(max(1, servings)) / 2)
    }

    static func matches(_ goal: NutritionGoal, recipe: Recipe) -> Bool {
        let perServing = estimate(recipe: recipe, servings: 1)
        return switch goal {
        case .highProtein: perServing.protein >= 20
        case .lowerCarb: perServing.carbohydrates <= 45
        case .lighter: perServing.calories <= 500 && perServing.fat <= 20
        }
    }
}
