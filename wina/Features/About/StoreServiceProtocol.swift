//
//  StoreServiceProtocol.swift
//  wina
//
//  Protocol for abstracting StoreKit operations, enabling mock-based testing.
//

import StoreKit

/// Result of an entitlement check
struct EntitlementResult {
    let hasEntitlement: Bool
    let wasRevoked: Bool
}

/// Result of processing unfinished transactions
struct UnfinishedTransactionResult {
    let isAdRemoved: Bool
}

/// Protocol abstracting StoreKit operations for testability
protocol StoreServiceProtocol: Sendable {
    /// Fetch products by IDs
    func fetchProducts(for ids: [String]) async throws -> [Product]

    /// Purchase a product
    func purchase(_ product: Product) async throws -> Product.PurchaseResult

    /// Sync with App Store (restore purchases)
    func sync() async throws

    /// Check current entitlements for a product
    func checkEntitlement(for productID: String) async -> EntitlementResult

    /// Process unfinished transactions
    func processUnfinishedTransactions(for productID: String) async -> UnfinishedTransactionResult?

    /// Listen for transaction updates
    func transactionUpdates() -> AsyncStream<(productID: String, isRevoked: Bool)>
}

/// Real implementation using StoreKit
final class RealStoreService: StoreServiceProtocol {
    static let shared = RealStoreService()

    private init() {}

    func fetchProducts(for ids: [String]) async throws -> [Product] {
        try await Product.products(for: ids)
    }

    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        try await product.purchase()
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func checkEntitlement(for productID: String) async -> EntitlementResult {
        // Check transaction history for revocation
        var latestHistoryTransaction: Transaction?
        for await result in Transaction.all {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                if let current = latestHistoryTransaction {
                    if transaction.signedDate > current.signedDate {
                        latestHistoryTransaction = transaction
                    }
                } else {
                    latestHistoryTransaction = transaction
                }
            }
        }

        if let historyTransaction = latestHistoryTransaction,
           historyTransaction.revocationDate != nil {
            return EntitlementResult(hasEntitlement: false, wasRevoked: true)
        }

        // Check latest transaction
        if let latestResult = await Transaction.latest(for: productID),
           case .verified(let transaction) = latestResult,
           transaction.revocationDate != nil {
            return EntitlementResult(hasEntitlement: false, wasRevoked: true)
        }

        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                return EntitlementResult(hasEntitlement: true, wasRevoked: false)
            }
        }

        return EntitlementResult(hasEntitlement: false, wasRevoked: false)
    }

    func processUnfinishedTransactions(for productID: String) async -> UnfinishedTransactionResult? {
        var result: UnfinishedTransactionResult?
        for await verificationResult in Transaction.unfinished {
            if case .verified(let transaction) = verificationResult,
               transaction.productID == productID {
                result = UnfinishedTransactionResult(isAdRemoved: transaction.revocationDate == nil)
                await transaction.finish()
            }
        }
        return result
    }

    func transactionUpdates() -> AsyncStream<(productID: String, isRevoked: Bool)> {
        AsyncStream { continuation in
            let task = Task.detached {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        continuation.yield((
                            productID: transaction.productID,
                            isRevoked: transaction.revocationDate != nil
                        ))
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
