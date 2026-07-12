struct Recipe: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let ingredients: [String]
    let minutes: Int
    let diets: Set<Diet>
    let steps: [String]

    func isEligible(maximumMinutes: Int, diets requiredDiets: Set<Diet>, excluding excludedIDs: Set<String> = []) -> Bool {
        !excludedIDs.contains(id) && minutes <= maximumMinutes && requiredDiets.isSubset(of: diets)
    }
}

enum Diet: String, CaseIterable, Identifiable {
    case vegetarian = "素食"
    case dairyFree = "无乳制品"
    case glutenFree = "无麸质"

    var id: Self { self }
}

struct Recommendation: Identifiable {
    let recipe: Recipe
    let available: [String]
    let missing: [String]
    let score: Double
    let reason: String
    var id: String { recipe.id }
}

enum DinnerMode: String, CaseIterable, Identifiable {
    case cook = "在家做"
    case eatOut = "出去吃"
    var id: Self { self }
}

struct DinnerChoice {
    let id: String
    let name: String
    let emoji: String
    let reason: String
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

enum DinnerDecider {
    static let diningCategories = [
        DinnerChoice(id: "hotpot", name: "火锅", emoji: "🍲", reason: "适合慢慢吃，也方便照顾不同口味"),
        DinnerChoice(id: "sushi", name: "寿司", emoji: "🍣", reason: "清爽、选择多，今晚不用开火"),
        DinnerChoice(id: "pizza", name: "披萨", emoji: "🍕", reason: "轻松分享，很适合不想纠结的晚上"),
        DinnerChoice(id: "noodles-out", name: "面馆", emoji: "🍜", reason: "上菜快，热乎又满足"),
        DinnerChoice(id: "thai", name: "泰国菜", emoji: "🌶️", reason: "酸辣开胃，适合换换口味")
    ]

    static func choices(mode: DinnerMode, maximumMinutes: Int, diets: Set<Diet>, excluding: Set<String>) -> [DinnerChoice] {
        switch mode {
        case .cook:
            return RecipeCatalog.recipes
                .filter { $0.isEligible(maximumMinutes: maximumMinutes, diets: diets, excluding: excluding) }
                .map { DinnerChoice(id: $0.id, name: $0.name, emoji: $0.emoji, reason: "约 \($0.minutes) 分钟就能上桌") }
        case .eatOut:
            return diningCategories.filter { !excluding.contains($0.id) }
        }
    }
}
