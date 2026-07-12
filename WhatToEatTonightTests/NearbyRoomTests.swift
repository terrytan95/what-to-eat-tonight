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

    @Test func anonymousVotesWaitForSubmissionAndHonorVeto() {
        let room = NearbyRoom()
        room.votes = [
            room.localParticipant: RoomVote(participant: room.localParticipant, likedRecipeIDs: ["tomato-eggs"], vetoedRecipeIDs: [], isSubmitted: false),
            "B": RoomVote(participant: "B", likedRecipeIDs: ["tomato-eggs"], vetoedRecipeIDs: [], isSubmitted: true)
        ]
        #expect(room.matches.isEmpty)
        room.submitVote()
        #expect(room.matches.map(\.id) == ["tomato-eggs"])
        room.toggleVeto("tomato-eggs")
        room.submitVote()
        #expect(room.matches.isEmpty)
    }
}
