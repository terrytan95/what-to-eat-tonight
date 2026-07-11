@preconcurrency import MultipeerConnectivity
import Observation
import UIKit

struct RoomVote: Codable, Hashable {
    let participant: String
    var likedRecipeIDs: Set<String>
}

@MainActor
@Observable
final class NearbyRoom: NSObject {
    private static let serviceType = "wteat-room"
    private let peerID = MCPeerID(displayName: String(UIDevice.current.name.prefix(40)))
    nonisolated(unsafe) private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var code = ""
    var status = "尚未加入房间"
    var votes: [String: RoomVote] = [:]

    var localParticipant: String { peerID.displayName }
    var participantCount: Int { max(1, Set(votes.keys).count) }

    var matches: [Recipe] {
        guard !votes.isEmpty else { return [] }
        return RecipeCatalog.recipes.filter { recipe in votes.values.allSatisfy { $0.likedRecipeIDs.contains(recipe.id) } }
    }

    func create() {
        stop()
        code = String(format: "%06d", Int.random(in: 0...999_999))
        startSession()
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["code": code], serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        status = "房间已创建，等待对方加入"
        ensureLocalVote()
    }

    func join(code rawCode: String) {
        let normalized = rawCode.filter(\.isNumber)
        guard normalized.count == 6 else { status = "请输入六位房间码"; return }
        stop()
        code = normalized
        startSession()
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        status = "正在寻找房间…"
        ensureLocalVote()
    }

    func toggleLike(_ recipeID: String) {
        ensureLocalVote()
        var vote = votes[peerID.displayName]!
        vote.likedRecipeIDs.formSymmetricDifference([recipeID])
        votes[peerID.displayName] = vote
        send(vote)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        votes = [:]
    }

    private func startSession() {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
    }

    private func ensureLocalVote() {
        votes[peerID.displayName, default: RoomVote(participant: peerID.displayName, likedRecipeIDs: [])] = votes[peerID.displayName] ?? RoomVote(participant: peerID.displayName, likedRecipeIDs: [])
    }

    private func send(_ vote: RoomVote) {
        guard let session, !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(vote) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func sendLocalVote() {
        guard let vote = votes[peerID.displayName] else { return }
        send(vote)
    }
}

extension NearbyRoom: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in status = "无法创建房间：\(error.localizedDescription)" }
    }
}

extension NearbyRoom: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard info?["code"] == code, let session else { return }
            status = "找到房间，正在连接…"
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
            browser.stopBrowsingForPeers()
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in status = "无法查找房间：\(error.localizedDescription)" }
    }
}

extension NearbyRoom: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            status = switch state {
            case .connected: "已连接 \(session.connectedPeers.count + 1) 人"
            case .connecting: "正在连接…"
            case .notConnected: "连接已断开"
            @unknown default: "连接状态未知"
            }
            if state == .connected { sendLocalVote() }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let vote = try? JSONDecoder().decode(RoomVote.self, from: data) else { return }
        Task { @MainActor in
            votes[vote.participant] = vote
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
