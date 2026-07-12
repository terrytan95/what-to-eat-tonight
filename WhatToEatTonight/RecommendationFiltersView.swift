import SwiftUI

struct RecommendationFiltersView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                optionalPicker("今天的精力", selection: binding(\.effort), values: EffortLevel.allCases, title: \.title)
                optionalPicker("厨具", selection: binding(\.tool), values: KitchenTool.allCases, title: \.rawValue)
                optionalPicker("菜系", selection: binding(\.cuisine), values: Cuisine.allCases, title: \.rawValue)
                optionalPicker("用餐场景", selection: binding(\.occasion), values: MealOccasion.allCases, title: \.rawValue)
                optionalPicker("营养偏好", selection: binding(\.nutrition), values: NutritionGoal.allCases, title: \.rawValue)
                optionalPicker("天气", selection: binding(\.weather), values: WeatherMood.allCases, title: \.rawValue)
                Picker("每人预算", selection: binding(\.budgetPerPerson)) {
                    Text("不限").tag(nil as Int?)
                    ForEach([20, 30, 50, 80], id: \.self) { Text("¥\($0) 以内").tag(Optional($0)) }
                }
                Stepper("用餐人数：\(state.servings) 人", value: Binding(get: { state.servings }, set: { state.servings = $0 }), in: 1...12)
                Section { Text("营养选项仅用于一般饮食偏好，不构成医疗或营养建议。") }.font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("更多筛选")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("重置") { state.recommendationFilters = .init() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<RecommendationFilters, Value>) -> Binding<Value> {
        Binding(get: { state.recommendationFilters[keyPath: keyPath] }, set: { state.recommendationFilters[keyPath: keyPath] = $0 })
    }

    private func optionalPicker<Value: Hashable>(
        _ label: String,
        selection: Binding<Value?>,
        values: [Value],
        title: KeyPath<Value, String>
    ) -> some View {
        Picker(label, selection: selection) {
            Text("不限").tag(nil as Value?)
            ForEach(values, id: \.self) { value in Text(value[keyPath: title]).tag(Optional(value)) }
        }
    }
}
