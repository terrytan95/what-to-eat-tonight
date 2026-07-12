@preconcurrency import MultipeerConnectivity
import Observation
import UIKit

struct RoomVote: Codable {
    let participant: String
    var likedRecipeIDs: Set<String>
    var vetoedRecipeIDs: Set<String>? = nil
    var isSubmitted: Bool? = nil
    var role: String? = nil
}

@MainActor
@Observable
final class NearbyRoom: NSObject {
    private static let serviceType = "wteat-room"
    private let peerID = MCPeerID(displayName: String(UIDevice.current.name.prefix(40)))
    @ObservationIgnored nonisolated(unsafe) private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var expiryTask: Task<Void, Never>?

    var code = ""
    var status = "尚未加入房间"
    var votes: [String: RoomVote] = [:]

    var localParticipant: String { peerID.displayName }
    var allSubmitted: Bool { votes.count > 1 && votes.values.allSatisfy { $0.isSubmitted != false } }
    var matches: [Recipe] {
        guard allSubmitted else { return [] }
        let vetoes = Set(votes.values.flatMap { $0.vetoedRecipeIDs ?? [] })
        return RecipeCatalog.recipes.filter { recipe in !vetoes.contains(recipe.id) && votes.values.allSatisfy { $0.likedRecipeIDs.contains(recipe.id) } }
    }

    var bestFallback: Recipe? {
        guard allSubmitted, matches.isEmpty else { return nil }
        let vetoes = Set(votes.values.flatMap { $0.vetoedRecipeIDs ?? [] })
        return RecipeCatalog.recipes.filter { !vetoes.contains($0.id) }.max { lhs, rhs in
            let left = vetoes.contains(lhs.id) ? -1 : votes.values.count { $0.likedRecipeIDs.contains(lhs.id) }
            let right = vetoes.contains(rhs.id) ? -1 : votes.values.count { $0.likedRecipeIDs.contains(rhs.id) }
            return left < right
        }
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
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(900))
            guard !Task.isCancelled else { return }
            self?.status = "房间已过期"
            self?.stop()
        }
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
        vote.isSubmitted = false
        votes[peerID.displayName] = vote
        send(vote)
    }

    func toggleVeto(_ recipeID: String) {
        ensureLocalVote()
        var vote = votes[peerID.displayName]!
        if vote.vetoedRecipeIDs?.contains(recipeID) == true { vote.vetoedRecipeIDs = [] }
        else { vote.vetoedRecipeIDs = [recipeID] }
        vote.isSubmitted = false
        votes[peerID.displayName] = vote
        send(vote)
    }

    func submitVote() {
        ensureLocalVote()
        var vote = votes[peerID.displayName]!
        vote.isSubmitted = true
        votes[peerID.displayName] = vote
        send(vote)
    }

    func setRole(_ role: String) {
        ensureLocalVote()
        var vote = votes[peerID.displayName]!
        vote.role = role
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
        expiryTask?.cancel()
        expiryTask = nil
    }

    private func startSession() {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
    }

    private func ensureLocalVote() {
        votes[peerID.displayName, default: RoomVote(participant: peerID.displayName, likedRecipeIDs: [], vetoedRecipeIDs: [], isSubmitted: false)] = votes[peerID.displayName] ?? RoomVote(participant: peerID.displayName, likedRecipeIDs: [], vetoedRecipeIDs: [], isSubmitted: false)
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
            if state == .notConnected { votes.removeValue(forKey: peerID.displayName) }
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
