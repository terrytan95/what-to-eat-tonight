import SwiftUI

struct ShoppingListView: View {
    @Environment(AppState.self) private var state
    @State private var newItem = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("添加购物项", text: $newItem).onSubmit(add)
                    Button("添加", action: add).disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            ForEach(["蔬菜及其他", "肉蛋水产", "主食", "乳制品"], id: \.self) { category in
                let items = state.shoppingList.filter { $0.category == category && !$0.isChecked }
                if !items.isEmpty { shoppingSection(category, items: items) }
            }
            let completed = state.shoppingList.filter(\.isChecked)
            if !completed.isEmpty { shoppingSection("已完成", items: completed) }
        }
        .overlay { if state.shoppingList.isEmpty { ContentUnavailableView("购物清单为空", systemImage: "cart", description: Text("可手动添加，或从菜谱自动生成。")) } }
        .navigationTitle("购物清单")
        .toolbar {
            if !state.shoppingListText.isEmpty { ShareLink(item: state.shoppingListText) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("分享购物清单") }
        }
    }

    private func shoppingSection(_ title: String, items: [ShoppingItem]) -> some View {
        Section(title) {
            ForEach(items) { item in
                Button { state.toggleShoppingItem(item) } label: {
                    HStack {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle").foregroundStyle(item.isChecked ? AppTheme.green : .secondary)
                        Text(item.name).strikethrough(item.isChecked)
                        Spacer()
                        Text("\(item.quantity.formatted()) \(item.unit)").foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }.onDelete { offsets in offsets.map { items[$0] }.forEach(state.deleteShoppingItem) }
        }
    }

    private func add() {
        state.addShoppingItem(name: newItem)
        newItem = ""
    }
}
