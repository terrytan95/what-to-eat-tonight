import PhotosUI
import SwiftUI
import Vision

struct InventoryView: View {
    @Environment(AppState.self) private var state
    @State private var showAdd = false
    @State private var showBatch = false
    @State private var showScanner = false
    @State private var photo: PhotosPickerItem?
    @State private var photoSuggestions = ""
    @State private var showPhotoConfirmation = false
    @State private var photoError = false

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
                Button("扫描包装或条码", systemImage: "barcode.viewfinder") { showScanner = true }
                    .disabled(!InventoryScanner.isAvailable)
                PhotosPicker(selection: $photo, matching: .images) { Label("识别食材照片", systemImage: "photo") }
                Menu("常备模板") {
                    Button("家常基础") { state.addInventory(text: "鸡蛋、番茄、米饭、面条、土豆、洋葱、青菜") }
                    Button("健身餐") { state.addInventory(text: "鸡蛋、鸡肉、米饭、青菜、虾") }
                    Button("宿舍快手") { state.addInventory(text: "鸡蛋、面条、面包、奶酪") }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddInventoryView() }
        .sheet(isPresented: $showBatch) { BatchInventoryView() }
        .sheet(isPresented: $showScanner) { ScannerCaptureView() }
        .sheet(isPresented: $showPhotoConfirmation) { BatchInventoryView(initialText: photoSuggestions) }
        .alert("没有识别到常见食材", isPresented: $photoError) { Button("好") {} } message: { Text("可以改用包装扫描、键盘听写或手动输入。") }
        .onChange(of: photo) { _, item in if let item { Task { await classify(item) } } }
    }

    private func classify(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data), let cgImage = image.cgImage else { photoError = true; return }
        let request = VNClassifyImageRequest()
        guard (try? VNImageRequestHandler(cgImage: cgImage).perform([request])) != nil else { photoError = true; return }
        let mapping = [
            "egg": "鸡蛋", "tomato": "番茄", "rice": "米饭", "noodle": "面条", "chicken": "鸡肉", "beef": "牛肉",
            "tofu": "豆腐", "potato": "土豆", "onion": "洋葱", "vegetable": "青菜", "lettuce": "青菜", "mushroom": "蘑菇",
            "shrimp": "虾", "cheese": "奶酪", "bread": "面包"
        ]
        let names = request.results?.filter { $0.confidence >= 0.12 }.compactMap { result in
            mapping.first { result.identifier.localizedCaseInsensitiveContains($0.key) }?.value
        } ?? []
        photoSuggestions = Array(Set(names)).sorted().joined(separator: "、")
        if photoSuggestions.isEmpty { photoError = true } else { showPhotoConfirmation = true }
    }
}

private struct ScannerCaptureView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var scannedName = ""
    @State private var scannedBarcode: String?
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            InventoryScanner { name, barcode in
                if let barcode, state.addKnownBarcode(barcode) {
                    dismiss()
                } else {
                    scannedName = name
                    scannedBarcode = barcode
                    showConfirmation = true
                }
            }
            .ignoresSafeArea()
            .navigationTitle("扫描食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("取消") { dismiss() } }
            .sheet(isPresented: $showConfirmation) {
                AddInventoryView(initialName: scannedName, barcode: scannedBarcode)
            }
        }
    }
}

private struct BatchInventoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var storage = "冷藏"

    init(initialText: String = "") { _text = State(initialValue: initialText) }

    var body: some View {
        NavigationStack {
            Form {
                TextEditor(text: $text).frame(minHeight: 180)
                Text("支持换行、顿号、逗号或分号分隔，最多导入 100 项；也可点击系统键盘的麦克风直接听写。")
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
    let barcode: String?

    init(initialName: String = "", barcode: String? = nil) {
        _name = State(initialValue: initialName)
        self.barcode = barcode
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("食材名称", text: $name)
                if let barcode { LabeledContent("条码", value: barcode) }
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
                        state.addInventory(name: name, quantity: quantity, unit: unit, storage: storage, expiresAt: hasExpiry ? expiresAt : nil, isStaple: isStaple, barcode: barcode)
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quantity <= 0)
                }
            }
        }
    }
}
