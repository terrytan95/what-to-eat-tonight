import SwiftUI

struct FamilyMealPlanView: View {
    @Environment(AppState.self) private var state
    @State private var showAddMember = false
    @State private var noResults = false

    var body: some View {
        List {
            Section("家庭成员") {
                ForEach(state.familyMembers) { member in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name).font(.headline)
                        let details = member.dietRawValues + member.excludedIngredients.map { "不吃\($0)" }
                        if !details.isEmpty { Text(details.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                    }
                }.onDelete { offsets in offsets.map { state.familyMembers[$0] }.forEach(state.deleteFamilyMember) }
                Button("添加家庭成员", systemImage: "person.badge.plus") { showAddMember = true }
            }

            Section("未来一周") {
                if state.mealPlan.isEmpty {
                    Button("生成一周菜单", systemImage: "wand.and.stars") { noResults = !state.generateMealPlan() }
                } else {
                    ForEach(state.mealPlan) { entry in
                        let recipe = state.allRecipes.first { $0.id == entry.recipeID }
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.date, format: .dateTime.weekday(.wide).month().day()).font(.caption).foregroundStyle(.secondary)
                                Text("\(recipe?.emoji ?? "🍽️")  \(recipe?.name ?? entry.recipeID)").font(.headline)
                            }
                            Spacer()
                            Button { state.replaceMealPlanEntry(entry) } label: { Image(systemName: "arrow.triangle.2.circlepath") }.accessibilityLabel("替换这一天")
                        }
                    }
                    Button("重新生成", systemImage: "wand.and.stars") { noResults = !state.generateMealPlan() }
                    Button("缺少食材加入购物清单", systemImage: "cart.badge.plus") { state.addMealPlanToShoppingList() }
                }
            }

            Section { Text("菜单会合并全家的饮食限制，避免连续重复，并优先使用当前设置的时间和人数。") }
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("家庭与菜单")
        .sheet(isPresented: $showAddMember) { AddFamilyMemberView() }
        .alert("没有满足全家条件的菜谱", isPresented: $noResults) { Button("好") {} } message: { Text("请放宽时间、饮食限制或“不吃”食材后重试。") }
    }
}

private struct AddFamilyMemberView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var diets: Set<Diet> = []
    @State private var exclusions = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名", text: $name)
                Section("饮食限制") {
                    ForEach(Diet.allCases) { diet in
                        Toggle(diet.rawValue, isOn: Binding(get: { diets.contains(diet) }, set: { enabled in
                            if enabled { diets.insert(diet) } else { diets.remove(diet) }
                        }))
                    }
                }
                TextField("不吃的食材，用逗号分隔", text: $exclusions, axis: .vertical)
            }
            .navigationTitle("添加成员")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { state.addFamilyMember(name: name, diets: diets, exclusions: exclusions); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
