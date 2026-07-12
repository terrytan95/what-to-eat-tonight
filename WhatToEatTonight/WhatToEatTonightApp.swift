import SwiftUI
import SwiftData

@main
struct WhatToEatTonightApp: App {
    private let persistence: PersistenceController
    @State private var appState: AppState

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
                .modelContainer(persistence.container)
        }
    }
}
