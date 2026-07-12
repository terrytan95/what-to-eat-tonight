import SwiftUI
import UIKit

struct CookingModeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var session: CookingSession?
    @State private var note = ""
    @State private var consumeInventory = true
    @State private var showRating = false

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(spacing: 24) {
                        Text("第 \(session.currentStep + 1) / \(recipe.steps.count) 步").font(.headline).foregroundStyle(AppTheme.orange)
                        Text(recipe.steps[session.currentStep]).font(.system(.title, design: .rounded, weight: .semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 220).appCard()

                        HStack {
                            Button("上一步", systemImage: "chevron.left") { state.moveCookingStep(session, to: session.currentStep - 1, stepCount: recipe.steps.count) }
                                .disabled(session.currentStep == 0)
                            Spacer()
                            Button("下一步", systemImage: "chevron.right") { state.moveCookingStep(session, to: session.currentStep + 1, stepCount: recipe.steps.count) }
                                .disabled(session.currentStep == recipe.steps.count - 1)
                        }.buttonStyle(.bordered)

                        if session.currentStep + 1 < recipe.steps.count {
                            Label("计时期间可以先准备下一步食材", systemImage: "arrow.triangle.branch").font(.footnote).foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("计时器").font(.headline)
                                Spacer()
                                Menu("添加", systemImage: "timer") {
                                    ForEach([3, 5, 10, 15, 30], id: \.self) { minutes in Button("\(minutes) 分钟") { state.addCookingTimer(recipeID: recipe.id, minutes: minutes) } }
                                }
                            }
                            ForEach(state.cookingTimers.filter { $0.recipeID == recipe.id }) { timer in
                                CookingTimerRow(timer: timer) { state.deleteCookingTimer(timer) }
                            }
                        }.appCard()

                        VStack(alignment: .leading) {
                            Text("做菜笔记").font(.headline)
                            TextEditor(text: $note).frame(minHeight: 90).padding(6).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                            Toggle("完成后同步扣减库存", isOn: $consumeInventory)
                        }.appCard()

                        Button("完成烹饪", systemImage: "checkmark.circle.fill") { showRating = true }
                            .frame(maxWidth: .infinity).frame(minHeight: 50).appPrimaryButtonStyle().tint(AppTheme.orange)
                    }.padding(18)
                }
            } else {
                ProgressView()
            }
        }
        .background(AppTheme.background)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { session = state.cookingSession(for: recipe.id) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("这道菜怎么样？", isPresented: $showRating, titleVisibility: .visible) {
            Button("很好吃") { finish(rating: 2) }
            Button("一般") { finish(rating: 1) }
            Button("不喜欢") { finish(rating: 0) }
        }
    }

    private func finish(rating: Int) {
        guard let session else { return }
        state.finishCooking(session, recipe: recipe, rating: rating, note: note, consumeInventory: consumeInventory)
        dismiss()
    }
}

private struct CookingTimerRow: View {
    let timer: CookingTimer
    let delete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, Int(timer.endDate.timeIntervalSince(context.date)))
            HStack {
                Label(timer.label, systemImage: "timer")
                Spacer()
                Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)).monospacedDigit()
                Button(action: delete) { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("删除计时器")
            }
        }
    }
}
