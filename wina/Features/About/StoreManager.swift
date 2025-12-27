//
//  StoreManager.swift
//  wina
//

import StoreKit

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private(set) var isAdRemoved = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var product: Product?

    private var updateListenerTask: Task<Void, Error>?

    private let productID = "removeAds"

    private init() {
        // Start listening for transaction updates (refunds, background purchases, etc.)
        updateListenerTask = listenForTransactions()

        // Process unfinished transactions and check entitlements on init
        Task {
            await processUnfinishedTransactions()
            await checkEntitlements()
            await fetchProduct()
        }
    }

    // MARK: - Fetch Product

    /// Fetch product info to display price
    @MainActor
    func fetchProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            // Silently fail - price just won't be displayed
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates (refunds, Ask to Buy approvals, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    // MARK: - Unfinished Transactions

    /// Process any unfinished transactions from previous sessions
    @MainActor
    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            await handle(transactionResult: result)
        }
    }

    // MARK: - Entitlements Check

    /// Check current entitlements (call on app launch)
    @MainActor
    func checkEntitlements() async {
        await processUnfinishedTransactions()

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
            isAdRemoved = false
            return
        }

        if let latestResult = await Transaction.latest(for: productID),
           case .verified(let transaction) = latestResult,
           transaction.revocationDate != nil {
            isAdRemoved = false
            return
        }

        var hasActiveEntitlement = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                hasActiveEntitlement = true
                break
            }
        }

        isAdRemoved = hasActiveEntitlement
    }

    // MARK: - Purchase

    @MainActor
    func purchaseAdRemoval() async {
        isLoading = true
        errorMessage = nil

        do {
            // Use cached product or fetch if not available
            let purchaseProduct: Product
            if let cached = product {
                purchaseProduct = cached
            } else {
                let products = try await Product.products(for: [productID])
                guard let fetched = products.first else {
                    errorMessage = "Product not available"
                    isLoading = false
                    return
                }
                purchaseProduct = fetched
                product = fetched
            }

            let result = try await purchaseProduct.purchase()
            await handle(purchaseResult: result)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkEntitlements()

            if !isAdRemoved {
                errorMessage = "No purchases to restore"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Handle Results

    @MainActor
    private func handle(purchaseResult: Product.PurchaseResult) async {
        switch purchaseResult {
        case .success(let verification):
            await handle(transactionResult: verification)
        case .userCancelled:
            break
        case .pending:
            errorMessage = "Purchase is pending approval"
        @unknown default:
            errorMessage = "Unknown error occurred"
        }
    }

    @MainActor
    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            if transaction.productID == productID {
                // Check if revoked (refunded)
                if transaction.revocationDate != nil {
                    isAdRemoved = false
                } else {
                    isAdRemoved = true
                }
            }
            // IMPORTANT: Always finish the transaction
            await transaction.finish()

        case .unverified:
            errorMessage = "Purchase could not be verified"
        }
    }
}
