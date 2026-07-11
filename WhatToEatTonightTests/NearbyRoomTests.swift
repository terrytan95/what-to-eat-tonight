import Testing
@testable import WhatToEatTonight

@MainActor
struct NearbyRoomTests {
    @Test func matchRequiresEveryParticipantToLikeRecipe() {
        let room = NearbyRoom()
        room.votes = [
            "A": RoomVote(participant: "A", likedRecipeIDs: ["tomato-eggs", "fried-rice"]),
            "B": RoomVote(participant: "B", likedRecipeIDs: ["tomato-eggs"])
        ]
        #expect(room.matches.map(\.id) == ["tomato-eggs"])
    }
}
