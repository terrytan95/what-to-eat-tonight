import CoreImage.CIFilterBuiltins
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { PantryView() }
                .tabItem { Label("食材", systemImage: "carrot") }
            NavigationStack { DecideView() }
                .tabItem { Label("决定", systemImage: "sparkles") }
            NavigationStack { TogetherView() }
                .tabItem { Label("一起选", systemImage: "person.2") }
        }
    }
}

struct PantryView: View {
    @Environment(AppState.self) private var state
    @State private var customIngredient = ""
    @State private var showResults = false

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("冰箱里有什么？").font(.largeTitle.bold())
                    Text("选出手边食材，今晚少买一点、快做一点。").foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82))], spacing: 10) {
                    ForEach(RecipeCatalog.ingredients, id: \.self) { ingredient in
                        ingredientButton(ingredient)
                    }
                    ForEach(state.selectedIngredients.sorted().filter { !RecipeCatalog.ingredients.contains($0) }, id: \.self) { ingredient in
                        ingredientButton(ingredient)
                    }
                }

                HStack {
                    TextField("添加其他食材", text: $customIngredient)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(addIngredient)
                    Button("添加", action: addIngredient).disabled(customIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                VStack(alignment: .leading) {
                    Text("最多 \(state.maximumMinutes) 分钟").font(.headline)
                    Slider(value: Binding(get: { Double(state.maximumMinutes) }, set: { state.maximumMinutes = Int($0) }), in: 10...60, step: 5)
                        .accessibilityLabel("最长烹饪时间")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("饮食需要").font(.headline)
                    ForEach(Diet.allCases) { diet in
                        Toggle(diet.rawValue, isOn: Binding(get: { state.diets.contains(diet) }, set: { enabled in
                            if enabled { state.diets.insert(diet) } else { state.diets.remove(diet) }
                        }))
                    }
                }

                Button { showResults = true } label: {
                    Text("看看能做什么").frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.selectedIngredients.isEmpty)
            }
            .padding()
        }
        .navigationTitle("今晚吃什么")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResults) { ResultsView() }
    }

    private func ingredientButton(_ ingredient: String) -> some View {
        let selected = state.selectedIngredients.contains(ingredient)
        return Button {
            state.selectedIngredients.formSymmetricDifference([ingredient])
        } label: {
            Text(ingredient).frame(maxWidth: .infinity).padding(.vertical, 9)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(selected ? .orange : .secondary)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func addIngredient() {
        let value = customIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        state.selectedIngredients.insert(value)
        customIngredient = ""
    }
}

struct ResultsView: View {
    @Environment(AppState.self) private var state

    private var recommendations: [Recommendation] {
        RecommendationEngine.recommendations(ingredients: state.selectedIngredients, maximumMinutes: state.maximumMinutes, diets: state.diets, excluding: state.disliked)
    }

    var body: some View {
        Group {
            if recommendations.isEmpty {
                ContentUnavailableView("暂时没有合适结果", systemImage: "fork.knife", description: Text("放宽烹饪时间或饮食条件再试试。"))
            } else {
                List(recommendations) { result in
                    NavigationLink(value: result.recipe) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(result.recipe.emoji) \(result.recipe.name)").font(.headline)
                            Text("\(result.recipe.minutes) 分钟 · 已有 \(result.available.count)/\(result.recipe.ingredients.count) 种食材").foregroundStyle(.secondary)
                            if !result.missing.isEmpty { Text("还缺：\(result.missing.joined(separator: "、"))").font(.caption).foregroundStyle(.orange) }
                        }.padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("推荐给你")
        .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
    }
}

struct RecipeDetailView: View {
    @Environment(AppState.self) private var state
    let recipe: Recipe

    var body: some View {
        List {
            Section {
                HStack { Text(recipe.emoji).font(.system(size: 58)); VStack(alignment: .leading) { Text(recipe.name).font(.title.bold()); Text("约 \(recipe.minutes) 分钟").foregroundStyle(.secondary) } }
            }
            Section("需要的食材") { ForEach(recipe.ingredients, id: \.self) { Text($0) } }
            Section("简单做法") { ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in Text("\(index + 1). \(step)") } }
            Section {
                Button(state.favorites.contains(recipe.id) ? "取消收藏" : "收藏") { state.toggleFavorite(recipe.id) }
                Button("不喜欢这个", role: .destructive) { state.dislike(recipe.id) }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DecideView: View {
    @Environment(AppState.self) private var state
    @State private var mode: DinnerMode = .cook
    @State private var current: DinnerChoice?
    @State private var remaining: [DinnerChoice] = []

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("别想了，就吃这个").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("先做决定，想换再换。").foregroundStyle(.secondary)
            }
            Picker("用餐方式", selection: $mode) {
                ForEach(DinnerMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { reset() }

            if let current {
                VStack(spacing: 14) {
                    Text(current.emoji).font(.system(size: 82))
                    Text(current.name).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(current.reason).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 28))

                Button("就吃这个") { state.choose(current.id) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("换一个") { pickNext() }.disabled(remaining.isEmpty)
                Button("以后少推荐这个", role: .destructive) {
                    state.dislike(current.id)
                    pickNext()
                }
            } else {
                ContentUnavailableView("准备好了吗？", systemImage: "sparkles", description: Text("点一下，今晚的选择就交给我。"))
                Button("帮我决定") { reset(); pickNext() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("快速决定")
        .onChange(of: state.maximumMinutes) { reset() }
    }

    private func reset() {
        current = nil
        remaining = DinnerDecider.choices(mode: mode, maximumMinutes: state.maximumMinutes, diets: state.diets, excluding: state.disliked)
            .sorted { lhs, rhs in
                let leftRecent = state.recentChoices.firstIndex(of: lhs.id) ?? .max
                let rightRecent = state.recentChoices.firstIndex(of: rhs.id) ?? .max
                return leftRecent > rightRecent
            }
    }

    private func pickNext() {
        if remaining.isEmpty { reset() }
        current = remaining.isEmpty ? nil : remaining.removeFirst()
    }
}

struct TogetherView: View {
    @State private var room = NearbyRoom()
    @State private var enteredCode = ""
    @State private var showVoting = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("两个人，都满意").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("在同一网络附近，输入房间码即可一起选。无需注册。")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            Button {
                room.create()
                showVoting = true
            } label: {
                Label("创建房间", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)

            HStack {
                Divider()
                Text("或者加入").font(.caption).foregroundStyle(.secondary)
                Divider()
            }

            TextField("六位房间码", text: $enteredCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .textFieldStyle(.roundedBorder)
                .onChange(of: enteredCode) { enteredCode = String(enteredCode.filter(\.isNumber).prefix(6)) }

            Button("加入房间") {
                room.join(code: enteredCode)
                if room.code.count == 6 { showVoting = true }
            }
            .buttonStyle(.bordered)
            .disabled(enteredCode.count != 6)
            Spacer()
        }
        .padding()
        .navigationTitle("一起选")
        .navigationDestination(isPresented: $showVoting) { VotingRoomView(room: room) }
        .onDisappear { if !showVoting { room.stop() } }
    }
}

struct VotingRoomView: View {
    @Bindable var room: NearbyRoom

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("房间码").font(.caption).foregroundStyle(.secondary)
                        Text(room.code).font(.title.monospacedDigit().bold()).textSelection(.enabled)
                    }
                    Spacer()
                    ShareLink(item: "打开 WhatToEatTonight，加入房间 \(room.code)") { Label("邀请", systemImage: "square.and.arrow.up") }
                }
                Text(room.status).font(.footnote).foregroundStyle(.secondary)
                QRCodeView(value: room.code).frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }

            if !room.matches.isEmpty {
                Section("共同喜欢") {
                    ForEach(room.matches) { recipe in
                        NavigationLink(value: recipe) { Label("\(recipe.emoji) \(recipe.name)", systemImage: "heart.fill").foregroundStyle(.pink) }
                    }
                }
            } else if let fallback = room.bestFallback {
                Section("当前最受欢迎") {
                    NavigationLink(value: fallback) { Text("\(fallback.emoji) \(fallback.name)") }
                }
            }

            Section("喜欢就点一下") {
                ForEach(RecipeCatalog.recipes) { recipe in
                    let liked = room.votes[room.localParticipant]?.likedRecipeIDs.contains(recipe.id) == true
                    Button { room.toggleLike(recipe.id) } label: {
                        HStack {
                            Text("\(recipe.emoji) \(recipe.name)").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: liked ? "heart.fill" : "heart").foregroundStyle(liked ? .pink : .secondary)
                        }
                    }
                    .accessibilityValue(liked ? "已喜欢" : "未选择")
                }
            }
        }
        .navigationTitle("共同决定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
        .onDisappear { room.stop() }
    }
}

private struct QRCodeView: View {
    let value: String

    var body: some View {
        if let image = image {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 150, height: 150)
                .accessibilityLabel("房间码二维码 \(value)")
        }
    }

    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage else { return nil }
        return UIImage(ciImage: output.transformed(by: .init(scaleX: 8, y: 8)))
    }
}
