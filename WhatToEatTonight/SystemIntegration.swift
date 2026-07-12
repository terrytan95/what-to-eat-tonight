import AppIntents
import CoreSpotlight
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

struct SuggestDinnerIntent: AppIntent {
    static let title: LocalizedStringResource = "今晚吃什么"
    static let description = IntentDescription("根据输入的食材推荐一道晚餐。")

    @Parameter(title: "现有食材") var ingredients: [String]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recipe = RecommendationEngine.recommendations(ingredients: Set(ingredients), maximumMinutes: 60, diets: []).first?.recipe
        return .result(dialog: IntentDialog(recipe.map { "今晚可以做\($0.name)，大约\($0.minutes)分钟。" } ?? "没有找到合适菜谱，请在 App 中放宽条件。"))
    }
}

struct AddIngredientIntent: AppIntent {
    static let title: LocalizedStringResource = "添加冰箱食材"
    static let openAppWhenRun = false

    @Parameter(title: "食材") var ingredient: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceController()
        let state = AppState(context: persistence.container.mainContext)
        state.addInventory(name: ingredient, quantity: 1, unit: "份", storage: "冷藏", expiresAt: nil, isStaple: false)
        return .result(dialog: "已把\(ingredient)加入冰箱。")
    }
}

struct ReadShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "查看购物清单"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceController()
        let state = AppState(context: persistence.container.mainContext)
        let text = state.shoppingListText.isEmpty ? "购物清单是空的。" : state.shoppingListText.replacingOccurrences(of: "□ ", with: "")
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct WhatToEatTonightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SuggestDinnerIntent(), phrases: ["用 \(.applicationName) 决定晚餐", "问 \(.applicationName) 今晚吃什么"], shortTitle: "决定晚餐", systemImageName: "fork.knife")
        AppShortcut(intent: AddIngredientIntent(), phrases: ["用 \(.applicationName) 添加食材"], shortTitle: "添加食材", systemImageName: "refrigerator")
        AppShortcut(intent: ReadShoppingListIntent(), phrases: ["用 \(.applicationName) 查看购物清单"], shortTitle: "购物清单", systemImageName: "cart")
    }
}

@MainActor
enum AppNotifications {
    static func requestAuthorization() async -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true
    }

    static func scheduleDinnerReminder(hour: Int, minute: Int) async {
        guard await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = "今晚吃什么？"
        content.body = "打开 App，用冰箱里的食材快速决定晚餐。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "dinner-reminder", content: content, trigger: trigger))
    }

    static func cancelDinnerReminder() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dinner-reminder"]) }

    static func scheduleTimer(_ timer: CookingTimer) async {
        guard timer.endDate > .now, await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = "烹饪计时完成"
        content.body = timer.label
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timer.endDate.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "cooking-\(timer.id)", content: content, trigger: trigger))
    }

    static func cancelTimer(_ timer: CookingTimer) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cooking-\(timer.id)"]) }

    static func scheduleExpiry(for item: InventoryItem) async {
        guard let expiry = item.expiresAt,
              let reminder = Calendar.current.date(byAdding: .day, value: -1, to: expiry),
              reminder > .now,
              await requestAuthorization()
        else { return }
        let content = UNMutableNotificationContent()
        content.title = "食材即将过期"
        content.body = "\(item.name) 明天到期，今晚优先用掉吧。"
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day], from: reminder).merging(DateComponents(hour: 9))
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "expiry-\(item.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }
}

enum RecipeSearchIndexer {
    static func index() {
        let items = RecipeCatalog.recipes.map { recipe in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = recipe.name
            attributes.contentDescription = "\(recipe.minutes) 分钟 · \(recipe.ingredients.joined(separator: "、"))"
            attributes.keywords = recipe.ingredients
            attributes.contentURL = URL(string: "wteat://recipe/\(recipe.id)")
            let item = CSSearchableItem(uniqueIdentifier: "recipe-\(recipe.id)", domainIdentifier: "recipes", attributeSet: attributes)
            item.expirationDate = .distantFuture
            return item
        }
        CSSearchableIndex.default().indexSearchableItems(items)
    }
}

enum DeepLink: Identifiable {
    case recipe(Recipe)
    case room(String)

    var id: String {
        switch self {
        case .recipe(let recipe): "recipe-\(recipe.id)"
        case .room(let code): "room-\(code)"
        }
    }

    init?(url: URL) {
        guard url.scheme == "wteat" else { return nil }
        let value = url.pathComponents.last ?? ""
        switch url.host {
        case "recipe":
            guard let recipe = RecipeCatalog.recipes.first(where: { $0.id == value }) else { return nil }
            self = .recipe(recipe)
        case "room":
            let code = String(value.filter(\.isNumber).prefix(6))
            guard code.count == 6 else { return nil }
            self = .room(code)
        default: return nil
        }
    }
}

struct ReminderSettingsView: View {
    @AppStorage("dinnerReminderEnabled") private var isEnabled = false
    @AppStorage("dinnerReminderHour") private var hour = 18
    @AppStorage("dinnerReminderMinute") private var minute = 0

    var body: some View {
        Form {
            Toggle("晚餐提醒", isOn: $isEnabled)
            DatePicker("提醒时间", selection: reminderTime, displayedComponents: .hourAndMinute)
                .disabled(!isEnabled)
            Section { Text("提醒只在设备本地安排，可随时在系统通知设置中关闭。") }
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("晚餐提醒")
        .onChange(of: isEnabled) { updateReminder() }
        .onChange(of: hour) { if isEnabled { updateReminder() } }
        .onChange(of: minute) { if isEnabled { updateReminder() } }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            hour = components.hour ?? 18
            minute = components.minute ?? 0
        }
    }

    private func updateReminder() {
        if isEnabled {
            Task { await AppNotifications.scheduleDinnerReminder(hour: hour, minute: minute) }
        } else {
            AppNotifications.cancelDinnerReminder()
        }
    }
}

private extension DateComponents {
    func merging(_ other: DateComponents) -> DateComponents {
        var result = self
        result.hour = other.hour
        result.minute = other.minute
        return result
    }
}
