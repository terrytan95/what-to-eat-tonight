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
    let substitutions: [String]
    var id: String { recipe.id }
}

enum DinnerMode: String, CaseIterable, Identifiable {
    case cook = "在家做"
    case eatOut = "出去吃"
    var id: Self { self }
}

enum EffortLevel: Int, CaseIterable, Identifiable {
    case minimal, easy, involved
    var id: Self { self }
    var title: String { ["完全不想动", "可以简单做", "愿意认真做"][rawValue] }
}

enum KitchenTool: String, CaseIterable, Identifiable {
    case noFire = "无需开火", onePot = "一口锅", riceCooker = "电饭煲", microwave = "微波炉", airFryer = "空气炸锅"
    var id: Self { self }
}

enum Cuisine: String, CaseIterable, Identifiable {
    case chinese = "中餐", western = "西餐", japanese = "日料", korean = "韩餐", southeastAsian = "东南亚"
    var id: Self { self }
}

enum MealOccasion: String, CaseIterable, Identifiable {
    case weekday = "工作日晚餐", lateNight = "夜宵", fitness = "健身餐", lunchbox = "适合带饭", kids = "儿童餐", gathering = "朋友聚餐"
    var id: Self { self }
}

enum NutritionGoal: String, CaseIterable, Identifiable {
    case highProtein = "高蛋白", lowerCarb = "少主食", lighter = "清淡"
    var id: Self { self }
}

enum WeatherMood: String, CaseIterable, Identifiable {
    case cold = "冷天", hot = "炎热", rainy = "下雨"
    var id: Self { self }
}

struct RecommendationFilters {
    var effort: EffortLevel? = nil
    var tool: KitchenTool? = nil
    var cuisine: Cuisine? = nil
    var occasion: MealOccasion? = nil
    var nutrition: NutritionGoal? = nil
    var weather: WeatherMood? = nil
    var budgetPerPerson: Int? = nil

    var isEmpty: Bool { effort == nil && tool == nil && cuisine == nil && occasion == nil && nutrition == nil && weather == nil && budgetPerPerson == nil }
}

struct RecipeAttributes {
    let effort: EffortLevel
    let tools: Set<KitchenTool>
    let cuisine: Cuisine
    let occasions: Set<MealOccasion>
    let nutrition: Set<NutritionGoal>
    let weather: Set<WeatherMood>
    let estimatedCostPerPerson: Int
}

extension Recipe {
    var attributes: RecipeAttributes {
        switch id {
        case "tomato-eggs": .init(effort: .minimal, tools: [.onePot], cuisine: .chinese, occasions: [.weekday, .kids], nutrition: [.lighter], weather: [.hot], estimatedCostPerPerson: 12)
        case "fried-rice": .init(effort: .easy, tools: [.onePot], cuisine: .chinese, occasions: [.weekday, .lateNight, .lunchbox, .kids], nutrition: [], weather: [.rainy], estimatedCostPerPerson: 10)
        case "chicken-potato": .init(effort: .involved, tools: [.onePot, .riceCooker], cuisine: .chinese, occasions: [.gathering, .lunchbox], nutrition: [.highProtein], weather: [.cold, .rainy], estimatedCostPerPerson: 24)
        case "tofu-mushroom": .init(effort: .easy, tools: [.onePot], cuisine: .chinese, occasions: [.weekday, .fitness], nutrition: [.lighter, .lowerCarb], weather: [.hot], estimatedCostPerPerson: 16)
        case "beef-noodles": .init(effort: .easy, tools: [.onePot], cuisine: .chinese, occasions: [.weekday, .lateNight], nutrition: [.highProtein], weather: [.cold, .rainy], estimatedCostPerPerson: 28)
        case "shrimp-rice": .init(effort: .easy, tools: [.onePot, .riceCooker], cuisine: .chinese, occasions: [.fitness, .lunchbox], nutrition: [.highProtein], weather: [.hot], estimatedCostPerPerson: 26)
        default: .init(effort: .minimal, tools: [.noFire, .airFryer], cuisine: .western, occasions: [.weekday, .lateNight, .kids], nutrition: [], weather: [.hot], estimatedCostPerPerson: 18)
        }
    }
}

struct DinnerChoice {
    let id: String
    let name: String
    let emoji: String
    let reason: String
}

struct RecipeDuel {
    private(set) var contenderIDs: [String]
    var pair: [String] { Array(contenderIDs.prefix(2)) }
    var winnerID: String? { contenderIDs.count == 1 ? contenderIDs[0] : nil }

    mutating func choose(_ winnerID: String) {
        guard pair.contains(winnerID), pair.count == 2 else { return }
        let loserID = pair.first { $0 != winnerID }
        contenderIDs.removeAll { $0 == loserID }
    }
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
