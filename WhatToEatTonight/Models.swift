import Foundation

struct Recipe: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let emoji: String
    let ingredients: [String]
    let minutes: Int
    let diets: Set<Diet>
    let steps: [String]
}

enum Diet: String, CaseIterable, Codable, Identifiable {
    case vegetarian = "素食"
    case dairyFree = "无乳制品"
    case glutenFree = "无麸质"

    var id: Self { self }
}

struct Recommendation: Identifiable, Hashable {
    let recipe: Recipe
    let available: [String]
    let missing: [String]
    let score: Double
    var id: String { recipe.id }
}

enum RecipeCatalog {
    static let ingredients = ["鸡蛋", "番茄", "米饭", "面条", "鸡肉", "牛肉", "豆腐", "土豆", "洋葱", "青菜", "蘑菇", "虾", "奶酪", "面包"]

    static let recipes: [Recipe] = [
        Recipe(id: "tomato-eggs", name: "番茄炒蛋", emoji: "🍅", ingredients: ["番茄", "鸡蛋"], minutes: 15, diets: [.vegetarian, .glutenFree], steps: ["番茄切块，鸡蛋打散。", "先炒鸡蛋盛出，再炒番茄。", "鸡蛋回锅调味即可。"]),
        Recipe(id: "fried-rice", name: "家常炒饭", emoji: "🍚", ingredients: ["米饭", "鸡蛋", "青菜", "洋葱"], minutes: 18, diets: [.vegetarian, .dairyFree, .glutenFree], steps: ["食材切小块。", "鸡蛋炒散，加入蔬菜。", "加入米饭炒匀并调味。"]),
        Recipe(id: "chicken-potato", name: "土豆炖鸡", emoji: "🍲", ingredients: ["鸡肉", "土豆", "洋葱"], minutes: 40, diets: [.dairyFree, .glutenFree], steps: ["鸡肉煎至变色。", "加入土豆和洋葱翻炒。", "加水调味，炖至软烂。"]),
        Recipe(id: "tofu-mushroom", name: "蘑菇烧豆腐", emoji: "🍄", ingredients: ["豆腐", "蘑菇", "青菜"], minutes: 25, diets: [.vegetarian, .dairyFree, .glutenFree], steps: ["豆腐煎至两面金黄。", "加入蘑菇炒软。", "加入青菜和调味料收汁。"]),
        Recipe(id: "beef-noodles", name: "洋葱牛肉面", emoji: "🍜", ingredients: ["牛肉", "面条", "洋葱", "青菜"], minutes: 30, diets: [.dairyFree], steps: ["面条煮熟备用。", "牛肉与洋葱炒香。", "加入汤和青菜，与面条组合。"]),
        Recipe(id: "shrimp-rice", name: "鲜虾盖饭", emoji: "🍤", ingredients: ["虾", "米饭", "鸡蛋", "青菜"], minutes: 25, diets: [.dairyFree, .glutenFree], steps: ["虾仁煎熟。", "鸡蛋和青菜炒熟。", "铺在米饭上并调味。"]),
        Recipe(id: "cheese-toast", name: "芝士蛋吐司", emoji: "🥪", ingredients: ["面包", "奶酪", "鸡蛋"], minutes: 10, diets: [.vegetarian], steps: ["面包放上奶酪。", "煎一颗鸡蛋。", "组合后烤至奶酪融化。"])
    ]
}
