import SwiftUI
import SwiftData

@main
struct WhatToEatTonightApp: App {
    private let persistence: PersistenceController
    @State private var appState: AppState
    @State private var entitlementStore = EntitlementStore()

    init() {
        let persistence = PersistenceController()
        self.persistence = persistence
        _appState = State(initialValue: AppState(context: persistence.container.mainContext))
        RecipeSearchIndexer.index()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(entitlementStore)
                .modelContainer(persistence.container)
                .task { await entitlementStore.prepare() }
                .task { await entitlementStore.observeTransactions() }
        }
    }
}
