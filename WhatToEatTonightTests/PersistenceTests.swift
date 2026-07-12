import Foundation
import SwiftData
import Testing
@testable import WhatToEatTonight

@MainActor
struct PersistenceTests {
    @Test func migratesLegacyPreferencesOnce() throws {
        let suite = "PersistenceTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(["tomato-eggs"], forKey: "favorites")
        defaults.set(["fried-rice"], forKey: "disliked")
        defaults.set(["cheese-toast"], forKey: "recentChoices")
        defer { defaults.removePersistentDomain(forName: suite) }

        let persistence = PersistenceController(inMemory: true)
        let state = AppState(context: persistence.container.mainContext, defaults: defaults)

        #expect(state.favorites == ["tomato-eggs"])
        #expect(state.disliked == ["fried-rice"])
        #expect(state.recentChoices == ["cheese-toast"])
        #expect(defaults.object(forKey: "favorites") == nil)

        state.toggleFavorite("fried-rice")
        let reloaded = AppState(context: persistence.container.mainContext, defaults: defaults)
        #expect(reloaded.favorites == ["fried-rice", "tomato-eggs"])

        let exported = try state.exportData()
        state.deleteAllData()
        #expect(state.favorites.isEmpty)
        try state.importData(exported)
        #expect(state.favorites == ["fried-rice", "tomato-eggs"])

        state.addInventory(text: "鸡蛋、番茄\n鸡蛋")
        #expect(state.inventory.count == 2)
        #expect(state.inventory.first { $0.name == "鸡蛋" }?.quantity == 2)
    }
}
