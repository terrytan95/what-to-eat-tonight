import CoreImage.CIFilterBuiltins
import SwiftUI

struct RootView: View {
    #if DEBUG
    private var demoScreen: DemoScreen? {
        if let value = ProcessInfo.processInfo.environment["DEMO_SCREEN"] { return DemoScreen(rawValue: value) }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoScreen"), arguments.indices.contains(index + 1) else { return nil }
        return DemoScreen(rawValue: arguments[index + 1])
    }
    #endif

    @ViewBuilder var body: some View {
        #if DEBUG
        if let demoScreen {
            DemoScreenView(screen: demoScreen)
        } else {
            app
        }
        #else
        app
        #endif
    }

    private var app: some View {
        TabView {
            Tab("食材", systemImage: "carrot.fill") { NavigationStack { PantryView() } }
            Tab("决定", systemImage: "bolt.fill") { NavigationStack { DecideView() } }
            Tab("一起选", systemImage: "person.2.fill") { NavigationStack { TogetherView() } }
            Tab("设置", systemImage: "gearshape.fill") { NavigationStack { SettingsView() } }
        }
        .tint(AppTheme.orange)
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var importText = ""
    @State private var showImporter = false
    @State private var showDeleteConfirmation = false
    @State private var message: String?

    var body: some View {
        List {
            Section("数据") {
                if let export = try? state.exportData() {
                    ShareLink(item: export) { Label("导出数据", systemImage: "square.and.arrow.up") }
                }
                Button { showImporter = true } label: { Label("导入数据", systemImage: "square.and.arrow.down") }
                Button("删除全部数据", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
            }
            Section("记录") {
                NavigationLink { MealHistoryView() } label: {
                    Label("饮食日历", systemImage: "calendar")
                    Spacer()
                    Text("\(state.mealHistory.count)").foregroundStyle(.secondary)
                }
            }
            Section {
                Text("数据默认仅保存在这台设备上。开启云同步前不会上传。")
            }.font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showImporter) {
            NavigationStack {
                TextEditor(text: $importText).font(.body.monospaced()).padding()
                    .navigationTitle("粘贴导出数据")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { showImporter = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("导入") {
                                do {
                                    try state.importData(importText)
                                    message = "导入完成"
                                    showImporter = false
                                } catch {
                                    message = "无法导入：数据格式不正确"
                                }
                            }.disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
            }
        }
        .confirmationDialog("确定删除所有本地数据？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除全部数据", role: .destructive) { state.deleteAllData(); message = "本地数据已删除" }
        }
        .alert("WhatToEatTonight", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }
}

struct MealHistoryView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        List(state.mealHistory) { record in
            let recipe = RecipeCatalog.recipes.first { $0.id == record.recipeID }
            HStack(spacing: 12) {
                Text(recipe?.emoji ?? "🍽️").font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe?.name ?? record.recipeID).font(.headline)
                    Text(record.cookedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    if !record.note.isEmpty { Text(record.note).font(.caption) }
                }
                Spacer()
                Text(["不喜欢", "一般", "很好吃"][record.rating])
                    .font(.caption.weight(.medium))
                    .foregroundStyle(record.rating == 2 ? AppTheme.green : record.rating == 0 ? AppTheme.pink : .secondary)
            }
        }
        .overlay { if state.mealHistory.isEmpty { ContentUnavailableView("还没有饮食记录", systemImage: "calendar", description: Text("在菜谱详情点击“吃过了”即可记录。")) } }
        .navigationTitle("饮食日历")
    }
}

struct PantryView: View {
    @Environment(AppState.self) private var state
    @State private var customIngredient = ""
    @State private var showResults = false
    @State private var showInventory = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var chipColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 96), spacing: 10)]
    }

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: "冰箱里有什么？", subtitle: "选择你有的食材和偏好，看看能做什么")
                Button { showInventory = true } label: {
                    HStack {
                        Label("管理冰箱库存", systemImage: "refrigerator.fill")
                        Spacer()
                        Text("\(state.inventory.filter { $0.quantity > 0 }.count) 项").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }.appCard(padding: 14)
                }.buttonStyle(.plain)

                sectionTitle("常见食材")
                LazyVGrid(columns: chipColumns, spacing: 10) {
                    ForEach(RecipeCatalog.ingredients, id: \.self) { ingredient in ingredientButton(ingredient) }
                    ForEach(state.selectedIngredients.sorted().filter { !RecipeCatalog.ingredients.contains($0) }, id: \.self) { ingredient in ingredientButton(ingredient) }
                }

                HStack {
                    TextField("添加其他食材", text: $customIngredient).submitLabel(.done).onSubmit(addIngredient)
                    Button("添加", action: addIngredient).disabled(customIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12).appGlassControl(interactive: true)

                sectionTitle("可用时间")
                VStack(spacing: 10) {
                    HStack {
                        Label("10 分钟", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(state.maximumMinutes) 分钟").font(.headline).foregroundStyle(AppTheme.orange)
                        Spacer()
                        Text("60 分钟+").font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { Double(state.maximumMinutes) }, set: { state.maximumMinutes = Int($0) }), in: 10...60, step: 5)
                        .accessibilityLabel("最长烹饪时间")
                        .accessibilityValue("\(state.maximumMinutes) 分钟")
                }

                sectionTitle("饮食偏好")
                LazyVGrid(columns: chipColumns, spacing: 10) {
                    ForEach(Diet.allCases) { diet in dietButton(diet) }
                }

                Button { showResults = true } label: {
                    Text("看看能做什么").fontWeight(.semibold).frame(maxWidth: .infinity).frame(minHeight: 50)
                }
                .appPrimaryButtonStyle().tint(AppTheme.orange)
                .disabled(state.selectedIngredients.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showResults) { ResultsView() }
        .navigationDestination(isPresented: $showInventory) { InventoryView() }
        .onAppear { state.selectedIngredients.formUnion(state.inventory.filter { $0.quantity > 0 }.map(\.name)) }
    }

    private func sectionTitle(_ title: String) -> some View { Text(title).font(.headline) }

    private func ingredientButton(_ ingredient: String) -> some View {
        let selected = state.selectedIngredients.contains(ingredient)
        return Button { state.selectedIngredients.formSymmetricDifference([ingredient]) } label: {
            HStack(spacing: 6) {
                Text(ingredient.ingredientEmoji)
                Text(ingredient).lineLimit(1)
                if selected { Image(systemName: "checkmark.circle.fill").font(.caption) }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain).selectedChip(selected)
    }

    private func dietButton(_ diet: Diet) -> some View {
        let selected = state.diets.contains(diet)
        return Button {
            if selected { state.diets.remove(diet) } else { state.diets.insert(diet) }
        } label: {
            HStack { Image(systemName: diet == .vegetarian ? "leaf.fill" : diet == .dairyFree ? "drop.fill" : "checkmark.seal.fill"); Text(diet.rawValue) }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain).selectedChip(selected)
    }

    private func addIngredient() {
        let value = customIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        state.selectedIngredients.insert(value); customIngredient = ""
    }
}

struct ResultsView: View {
    @Environment(AppState.self) private var state
    private var recommendations: [Recommendation] {
        RecommendationEngine.recommendations(ingredients: state.selectedIngredients, maximumMinutes: state.maximumMinutes, diets: state.diets, excluding: state.disliked, ratings: state.ratings, recentIDs: state.recentChoices, priorityIngredients: state.expiringIngredients)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(recommendations) { result in
                    NavigationLink(value: result.recipe) {
                        HStack(spacing: 14) {
                            FoodIcon(emoji: result.recipe.emoji, size: 62)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(result.recipe.name).font(.headline)
                                HStack(spacing: 10) {
                                    Label("\(result.recipe.minutes) 分钟", systemImage: "clock")
                                    Text("\(Int(Double(result.available.count) / Double(result.recipe.ingredients.count) * 100))% 食材")
                                }.font(.caption).foregroundStyle(.secondary)
                                Text(result.missing.isEmpty ? "完全匹配" : "缺 \(result.missing.joined(separator: "、"))")
                                    .font(.caption.weight(.medium)).foregroundStyle(result.missing.isEmpty ? AppTheme.green : AppTheme.orange)
                                Text(result.reason).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle()).appCard(padding: 12)
                    }.buttonStyle(.plain)
                }
            }.padding(18)
        }
        .background(AppTheme.background)
        .navigationTitle("推荐给你")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
        .overlay { if recommendations.isEmpty { ContentUnavailableView("暂时没有合适结果", systemImage: "fork.knife", description: Text("放宽烹饪时间或饮食条件再试试。")) } }
    }
}

struct RecipeDetailView: View {
    @Environment(AppState.self) private var state
    let recipe: Recipe
    @State private var showRating = false
    @State private var privateEntry = false
    @State private var showConsume = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    FoodIcon(emoji: recipe.emoji, size: 156)
                    HStack(spacing: 24) {
                        Label("\(recipe.minutes) 分钟", systemImage: "clock")
                        Label("简单", systemImage: "chart.bar.fill")
                    }.font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)

                Divider()
                Text("食材（2–3 人份）").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    ForEach(recipe.ingredients, id: \.self) { Text("\($0.ingredientEmoji)  \($0)") }
                }
                Divider()
                Text("步骤").font(.headline)
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white).frame(width: 25, height: 25).background(AppTheme.orange, in: Circle())
                        Text(step).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle("本次不记录到饮食历史", isOn: $privateEntry).font(.footnote)
            }.padding(20).padding(.bottom, 86)
        }
        .background(AppTheme.background)
        .navigationTitle(recipe.name).navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { state.toggleFavorite(recipe.id) } label: { Label(state.favorites.contains(recipe.id) ? "已收藏" : "收藏", systemImage: state.favorites.contains(recipe.id) ? "heart.fill" : "heart").frame(maxWidth: .infinity).frame(minHeight: 44) }
                Button { state.dislike(recipe.id) } label: { Label("不喜欢", systemImage: "hand.thumbsdown").frame(maxWidth: .infinity).frame(minHeight: 44) }
                Button { showRating = true } label: { Label("吃过了", systemImage: "checkmark.circle").frame(maxWidth: .infinity).frame(minHeight: 44) }
            }
            .fontWeight(.medium).padding(10).appGlassControl().padding(.horizontal)
        }
        .confirmationDialog("这道菜怎么样？", isPresented: $showRating, titleVisibility: .visible) {
            Button("很好吃") { record(rating: 2) }
            Button("一般") { record(rating: 1) }
            Button("不喜欢") { record(rating: 0) }
        }
        .confirmationDialog("同步扣减冰箱库存？", isPresented: $showConsume, titleVisibility: .visible) {
            Button("每种食材扣减 1 单位") { state.consumeIngredients(recipe.ingredients) }
            Button("暂不扣减", role: .cancel) {}
        }
    }

    private func record(rating: Int) {
        state.recordMeal(recipe.id, rating: rating, privateEntry: privateEntry)
        showConsume = state.inventory.contains { recipe.ingredients.contains($0.name) && $0.quantity > 0 }
    }
}

struct DecideView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: DinnerMode = .cook
    @State private var current: DinnerChoice?
    @State private var remaining: [DinnerChoice] = []
    var startsWithChoice = false

    private var selectedRecipe: Recipe? { RecipeCatalog.recipes.first { $0.id == current?.id } }

    var body: some View {
        ScrollView {
        VStack(spacing: 22) {
            ScreenHeader(title: "别想了，就吃这个", subtitle: "一键决定，告别选择困难")
            Picker("用餐方式", selection: $mode) { ForEach(DinnerMode.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).onChange(of: mode) { reset() }

            if let current {
                VStack(spacing: 14) {
                    Text(current.name).font(.system(.title, design: .rounded, weight: .bold))
                    FoodIcon(emoji: current.emoji, size: 174)
                    HStack(spacing: 24) {
                        if let selectedRecipe { Label("\(selectedRecipe.minutes) 分钟", systemImage: "clock") }
                        Label(mode == .cook ? "简单" : "外出", systemImage: mode == .cook ? "chart.bar.fill" : "figure.walk")
                    }
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(current.reason).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 310).appCard()
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))

                Button { state.choose(current.id) } label: {
                    Text("就吃这个").fontWeight(.semibold).frame(maxWidth: .infinity).frame(minHeight: 50)
                }.appPrimaryButtonStyle().tint(AppTheme.orange)
                Button { pickNext() } label: { Label("换一个", systemImage: "arrow.clockwise").frame(maxWidth: .infinity).frame(minHeight: 46) }.appSecondaryButtonStyle()
                Button("以后少推荐这个", role: .destructive) { state.dislike(current.id); pickNext() }.font(.footnote)
            } else {
                Image(systemName: "sparkles").font(.system(size: 58)).foregroundStyle(AppTheme.orange).padding(.top, 80)
                Text("准备好了吗？").font(.title2.bold())
                Button("帮我决定") { reset(); pickNext() }.frame(maxWidth: .infinity).frame(minHeight: 50).appPrimaryButtonStyle().tint(AppTheme.orange)
            }
        }}
        .padding(18).background(AppTheme.background).toolbar(.hidden, for: .navigationBar)
        .onAppear { if startsWithChoice, current == nil { reset(); pickNext() } }
    }

    private func reset() {
        current = nil
        remaining = DinnerDecider.choices(mode: mode, maximumMinutes: state.maximumMinutes, diets: state.diets, excluding: state.disliked)
            .sorted { (state.recentChoices.firstIndex(of: $0.id) ?? .max) > (state.recentChoices.firstIndex(of: $1.id) ?? .max) }
    }
    private func pickNext() { if remaining.isEmpty { reset() }; withAnimation(.snappy) { current = remaining.isEmpty ? nil : remaining.removeFirst() } }
}

struct TogetherView: View {
    @State private var room = NearbyRoom()
    @State private var enteredCode = ""
    @State private var showVoting = false

    var body: some View {
        VStack(spacing: 24) {
            ScreenHeader(title: "两个人，都满意", subtitle: "创建房间，一起找到共同喜欢的菜")
            HStack(spacing: 20) {
                avatar("person.crop.circle.fill", color: .blue); Image(systemName: "heart.fill").font(.largeTitle).foregroundStyle(AppTheme.pink); avatar("person.crop.circle.fill", color: AppTheme.orange)
            }.padding(.vertical, 22)
            Button { room.create(); showVoting = true } label: { Label("创建房间", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).frame(minHeight: 50) }
                .appPrimaryButtonStyle().tint(AppTheme.orange)
            HStack {
                Rectangle().fill(.primary.opacity(0.15)).frame(height: 0.5)
                Text("或加入已有房间").font(.caption).foregroundStyle(.secondary).fixedSize()
                Rectangle().fill(.primary.opacity(0.15)).frame(height: 0.5)
            }
            TextField("1  2  3  4  5  6", text: $enteredCode)
                .keyboardType(.numberPad).textContentType(.oneTimeCode).multilineTextAlignment(.center).font(.title.monospacedDigit().weight(.semibold))
                .padding().appGlassControl().onChange(of: enteredCode) { enteredCode = String(enteredCode.filter(\.isNumber).prefix(6)) }
            Button("加入房间") { room.join(code: enteredCode); if room.code.count == 6 { showVoting = true } }
                .frame(maxWidth: .infinity).frame(minHeight: 46).appSecondaryButtonStyle().disabled(enteredCode.count != 6)
            Spacer()
        }
        .padding(18).background(AppTheme.background).toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showVoting) { VotingRoomView(room: room) }
        .onChange(of: showVoting) { oldValue, newValue in if oldValue, !newValue { room.stop() } }
        .onDisappear { if !showVoting { room.stop() } }
    }

    private func avatar(_ symbol: String, color: Color) -> some View { Image(systemName: symbol).font(.system(size: 68)).foregroundStyle(color).accessibilityHidden(true) }
}

struct VotingRoomView: View {
    @Bindable var room: NearbyRoom

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Label(room.status, systemImage: "circle.fill").font(.caption).foregroundStyle(AppTheme.green)
                    Spacer(); QRCodeView(value: room.code).frame(width: 74, height: 74)
                }.appCard(padding: 12)

                if let match = room.matches.first {
                    NavigationLink(value: match) { Label("共同喜欢：\(match.name)", systemImage: "heart.fill").frame(maxWidth: .infinity) }
                        .foregroundStyle(AppTheme.pink).appCard(padding: 14).buttonStyle(.plain)
                } else if let fallback = room.bestFallback {
                    NavigationLink(value: fallback) { Label("当前最受欢迎：\(fallback.name)", systemImage: "star.fill").frame(maxWidth: .infinity) }
                        .appCard(padding: 14).buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    HStack {
                        Spacer(); Text("我").frame(width: 34); Text("对方").frame(width: 34)
                    }.font(.caption2).foregroundStyle(.secondary).padding(.bottom, 4)
                    ForEach(RecipeCatalog.recipes) { recipe in
                        let liked = room.votes[room.localParticipant]?.likedRecipeIDs.contains(recipe.id) == true
                        let remoteLiked = room.votes.values.filter { $0.participant != room.localParticipant }.contains { $0.likedRecipeIDs.contains(recipe.id) }
                        Button { room.toggleLike(recipe.id) } label: {
                            HStack(spacing: 12) {
                                FoodIcon(emoji: recipe.emoji, size: 44)
                                VStack(alignment: .leading) { Text(recipe.name).font(.headline); Text("\(recipe.minutes) 分钟 · 简单").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Image(systemName: liked ? "heart.fill" : "heart").font(.title3).foregroundStyle(liked ? AppTheme.pink : .secondary).frame(width: 34)
                                Image(systemName: remoteLiked ? "heart.fill" : "heart").font(.title3).foregroundStyle(remoteLiked ? AppTheme.pink : .secondary).frame(width: 34).allowsHitTesting(false)
                            }.padding(.vertical, 11)
                        }.buttonStyle(.plain).accessibilityValue("我\(liked ? "已喜欢" : "未选择")，对方\(remoteLiked ? "已喜欢" : "未选择")")
                        if recipe.id != RecipeCatalog.recipes.last?.id { Divider() }
                    }
                }.appCard(padding: 12)
                Text("双方各点“♡”，找到共同喜欢的菜吧！").font(.footnote).foregroundStyle(.secondary)
            }.padding(18)
        }
        .background(AppTheme.background).navigationTitle("房间：\(room.code)").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: "打开 WhatToEatTonight，加入房间 \(room.code)") { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("邀请")
        }
        .navigationDestination(for: Recipe.self) { recipe in room.matches.contains(recipe) ? AnyView(MatchResultView(recipe: recipe)) : AnyView(RecipeDetailView(recipe: recipe)) }
    }
}

struct MatchResultView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var body: some View {
        ScrollView {
        VStack(spacing: 18) {
            Text("🎉  共同喜欢  🎉").font(.system(.largeTitle, design: .rounded, weight: .bold)).padding(.top, 120)
            Text("你们都爱这道菜！").foregroundStyle(.secondary)
            VStack(spacing: 14) {
                FoodIcon(emoji: recipe.emoji, size: 176); Text(recipe.name).font(.system(.title, design: .rounded, weight: .bold))
                HStack(spacing: 24) { Label("\(recipe.minutes) 分钟", systemImage: "clock"); Label("简单", systemImage: "chart.bar.fill") }.font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).appCard()
            NavigationLink(value: recipe) {
                Text("去做这道菜").fontWeight(.semibold).frame(maxWidth: .infinity).frame(minHeight: 50)
            }.appPrimaryButtonStyle().tint(AppTheme.orange)
            Button { dismiss() } label: {
                Text("再找其他菜").frame(maxWidth: .infinity).frame(minHeight: 46)
            }.appSecondaryButtonStyle()
        }.padding(18)}.background(AppTheme.background).toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
    }
}

private struct QRCodeView: View {
    let value: String
    var body: some View {
        if let image { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().accessibilityLabel("房间码二维码 \(value)") }
    }
    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8)
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#if DEBUG
private enum DemoScreen: String { case pantry, results, detail, decide, together, voting, match }

private struct DemoScreenView: View {
    @Environment(AppState.self) private var state
    let screen: DemoScreen
    @State private var room = NearbyRoom()
    @State private var selectedTab: Int

    init(screen: DemoScreen) {
        self.screen = screen
        let tab = switch screen {
        case .pantry, .results, .detail: 0
        case .decide: 1
        case .together, .voting, .match: 2
        }
        _selectedTab = State(initialValue: tab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { foodScreen }.tabItem { Label("食材", systemImage: "carrot.fill") }.tag(0)
            NavigationStack { DecideView(startsWithChoice: screen == .decide) }.tabItem { Label("决定", systemImage: "bolt.fill") }.tag(1)
            NavigationStack { togetherScreen }.tabItem { Label("一起选", systemImage: "person.2.fill") }.tag(2)
        }
        .tint(AppTheme.orange)
        .onAppear {
            if state.selectedIngredients.isEmpty { state.selectedIngredients = ["鸡蛋", "番茄", "土豆", "洋葱", "青菜"] }
        }
    }

    @ViewBuilder private var foodScreen: some View {
        switch screen {
        case .results: ResultsView()
        case .detail: RecipeDetailView(recipe: RecipeCatalog.recipes[0])
        default: PantryView()
        }
    }

    @ViewBuilder private var togetherScreen: some View {
        switch screen {
        case .voting: VotingRoomView(room: room).task { seedRoom() }
        case .match: MatchResultView(recipe: RecipeCatalog.recipes[0])
        default: TogetherView()
        }
    }

    private func seedRoom() {
        room.code = "123456"; room.status = "2 人在线"
        room.votes = [room.localParticipant: .init(participant: room.localParticipant, likedRecipeIDs: ["tomato-eggs"]), "对方": .init(participant: "对方", likedRecipeIDs: [])]
    }
}
#endif
