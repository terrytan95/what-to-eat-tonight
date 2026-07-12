import SwiftUI

struct CustomRecipesView: View {
    @Environment(AppState.self) private var state
    @State private var showCreator = false

    var body: some View {
        List {
            ForEach(state.customRecipes) { custom in
                NavigationLink {
                    RecipeDetailView(recipe: custom.recipe)
                } label: {
                    HStack {
                        Text(custom.emoji).font(.title)
                        VStack(alignment: .leading) {
                            Text(custom.name).font(.headline)
                            Text("\(custom.minutes) 分钟 · \(custom.ingredientNames.count) 种食材")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in offsets.map { state.customRecipes[$0] }.forEach(state.deleteCustomRecipe) }
        }
        .overlay { if state.customRecipes.isEmpty { ContentUnavailableView("还没有自建菜谱", systemImage: "book.pages", description: Text("添加食材重量后会自动估算营养。")) } }
        .navigationTitle("我的菜谱")
        .toolbar { Button("添加", systemImage: "plus") { showCreator = true } }
        .sheet(isPresented: $showCreator) { CustomRecipeEditor() }
    }
}

private struct CustomRecipeEditor: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🍽️"
    @State private var minutes = 20
    @State private var diets: Set<Diet> = []
    @State private var weights: [String: Double] = [:]
    @State private var steps = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && weights.values.contains(where: { $0 > 0 })
            && !steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("菜名", text: $name)
                    TextField("图标", text: $emoji).onChange(of: emoji) { emoji = String(emoji.prefix(1)) }
                    Stepper("烹饪时间：\(minutes) 分钟", value: $minutes, in: 1...240, step: 5)
                }
                Section("食材重量（2 人份）") {
                    ForEach(RecipeCatalog.ingredients, id: \.self) { ingredient in
                        Toggle(isOn: selected(ingredient)) {
                            HStack { Text("\(ingredient.ingredientEmoji)  \(ingredient)"); Spacer(); if let grams = weights[ingredient] { Text("\(grams.formatted())g").foregroundStyle(.secondary) } }
                        }
                        if weights[ingredient] != nil {
                            Stepper("\(ingredient)克数", value: grams(ingredient), in: 10...2000, step: 10).labelsHidden()
                        }
                    }
                }
                if !weights.isEmpty {
                    NutritionSummaryView(nutrients: NutritionEstimator.estimate(ingredientWeights: weights), title: "整份营养估算")
                        .listRowInsets(EdgeInsets())
                }
                Section("饮食标签") {
                    ForEach(Diet.allCases) { diet in Toggle(diet.rawValue, isOn: dietBinding(diet)) }
                }
                Section("步骤（每行一步）") { TextEditor(text: $steps).frame(minHeight: 120) }
            }
            .navigationTitle("新建菜谱")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        state.addCustomRecipe(name: name, emoji: emoji, ingredientWeights: weights, minutes: minutes, diets: diets, steps: steps.components(separatedBy: .newlines))
                        dismiss()
                    }.disabled(!isValid)
                }
            }
        }
    }

    private func selected(_ ingredient: String) -> Binding<Bool> {
        Binding(get: { weights[ingredient] != nil }, set: { enabled in
            if enabled { weights[ingredient] = 100 } else { weights[ingredient] = nil }
        })
    }

    private func grams(_ ingredient: String) -> Binding<Double> {
        Binding(get: { weights[ingredient] ?? 100 }, set: { weights[ingredient] = $0 })
    }

    private func dietBinding(_ diet: Diet) -> Binding<Bool> {
        Binding(get: { diets.contains(diet) }, set: { enabled in
            if enabled { diets.insert(diet) } else { diets.remove(diet) }
        })
    }
}
