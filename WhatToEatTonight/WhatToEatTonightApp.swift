import SwiftUI

@main
struct WhatToEatTonightApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.orange)
        }
    }
}
