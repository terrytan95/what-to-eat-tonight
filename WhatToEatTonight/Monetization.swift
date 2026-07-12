import Observation
import StoreKit
import SwiftUI

@MainActor
@Observable
final class EntitlementStore {
    private enum VerificationError: Error { case failed }
    static let productIDs = [
        "com.terrytan.WhatToEatTonight.pro.monthly",
        "com.terrytan.WhatToEatTonight.lifetime"
    ]

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var errorMessage: String?
    var isLoading = false

    var hasPro: Bool { !purchasedProductIDs.isDisjoint(with: Self.productIDs) }

    func prepare() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            await refreshEntitlements()
        } catch {
            errorMessage = "暂时无法连接 App Store。"
        }
    }

    func purchase(_ product: Product) async {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .pending: errorMessage = "购买正在等待批准。"
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            errorMessage = "购买未完成，请稍后重试。"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "无法恢复购买，请确认 App Store 登录状态。"
        }
    }

    func observeTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? verified(result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result), transaction.revocationDate == nil else { continue }
            active.insert(transaction.productID)
        }
        purchasedProductIDs = active
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw VerificationError.failed
        }
    }
}

struct ProPreviewView: View {
    @Environment(EntitlementStore.self) private var store

    var body: some View {
        List {
            Section {
                Label(store.hasPro ? "Pro 已解锁" : "WhatToEatTonight Pro", systemImage: store.hasPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.title3.bold()).foregroundStyle(store.hasPro ? AppTheme.green : AppTheme.orange)
                Text("未来可用于扩展菜谱包、跨设备家庭菜单和跨网络房间；基础推荐、营养估算与附近共同选择保持免费。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("可用方案") {
                if store.isLoading {
                    ProgressView()
                } else if store.products.isEmpty {
                    ContentUnavailableView("付费资源尚未发布", systemImage: "storefront", description: Text("产品代码已经就绪；在 App Store Connect 创建商品后会自动显示。"))
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button { Task { await store.purchase(product) } } label: {
                            HStack { VStack(alignment: .leading) { Text(product.displayName).font(.headline); Text(product.description).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(product.displayPrice).fontWeight(.semibold) }
                        }.disabled(store.purchasedProductIDs.contains(product.id))
                    }
                }
                Button("恢复购买", systemImage: "arrow.clockwise") { Task { await store.restore() } }
            }
        }
        .navigationTitle("Pro 与付费资源")
        .alert("App Store", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("好") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
