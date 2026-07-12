import SwiftUI

struct InventoryView: View {
    @Environment(AppState.self) private var state
    @State private var showAdd = false
    @State private var showBatch = false

    var body: some View {
        List {
            ForEach(["冷藏", "冷冻", "常温"], id: \.self) { storage in
                let items = state.inventory.filter { $0.storage == storage }
                if !items.isEmpty {
                    Section(storage) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.name.ingredientEmoji).font(.title2)
                                VStack(alignment: .leading) {
                                    HStack { Text(item.name).font(.headline); if item.isStaple { Image(systemName: "star.fill").foregroundStyle(AppTheme.orange) } }
                                    HStack {
                                        Text("\(item.quantity.formatted()) \(item.unit)")
                                        if let expiresAt = item.expiresAt {
                                            Text(expiresAt, format: .dateTime.month().day()).foregroundStyle(expiresAt <= Date.now.addingTimeInterval(3 * 86_400) ? AppTheme.pink : .secondary)
                                        }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { state.consume(item) } label: { Image(systemName: "minus.circle") }.disabled(item.quantity <= 0)
                            }
                        }.onDelete { offsets in offsets.map { items[$0] }.forEach(state.deleteInventory) }
                    }
                }
            }
        }
        .overlay { if state.inventory.isEmpty { ContentUnavailableView("冰箱还是空的", systemImage: "refrigerator", description: Text("添加食材后会自动参与推荐。")) } }
        .navigationTitle("冰箱库存")
        .toolbar {
            Menu("添加", systemImage: "plus") {
                Button("手动添加", systemImage: "square.and.pencil") { showAdd = true }
                Button("批量粘贴", systemImage: "doc.on.clipboard") { showBatch = true }
                Menu("常备模板") {
                    Button("家常基础") { state.addInventory(text: "鸡蛋、番茄、米饭、面条、土豆、洋葱、青菜") }
                    Button("健身餐") { state.addInventory(text: "鸡蛋、鸡肉、米饭、青菜、虾") }
                    Button("宿舍快手") { state.addInventory(text: "鸡蛋、面条、面包、奶酪") }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddInventoryView() }
        .sheet(isPresented: $showBatch) { BatchInventoryView() }
    }
}

private struct BatchInventoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var storage = "冷藏"

    var body: some View {
        NavigationStack {
            Form {
                TextEditor(text: $text).frame(minHeight: 180)
                Text("支持换行、顿号、逗号或分号分隔，最多导入 100 项。")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("存放位置", selection: $storage) { ForEach(["冷藏", "冷冻", "常温"], id: \.self) { Text($0) } }
            }
            .navigationTitle("批量添加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { state.addInventory(text: text, storage: storage); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddInventoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = 1.0
    @State private var unit = "份"
    @State private var storage = "冷藏"
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var isStaple = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("食材名称", text: $name)
                HStack { TextField("数量", value: $quantity, format: .number).keyboardType(.decimalPad); TextField("单位", text: $unit).frame(width: 80) }
                Picker("存放位置", selection: $storage) { ForEach(["冷藏", "冷冻", "常温"], id: \.self) { Text($0) } }
                Toggle("设置过期日期", isOn: $hasExpiry)
                if hasExpiry { DatePicker("过期日期", selection: $expiresAt, displayedComponents: .date) }
                Toggle("设为常备食材", isOn: $isStaple)
            }
            .navigationTitle("添加食材")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        state.addInventory(name: name, quantity: quantity, unit: unit, storage: storage, expiresAt: hasExpiry ? expiresAt : nil, isStaple: isStaple)
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quantity <= 0)
                }
            }
        }
    }
}
