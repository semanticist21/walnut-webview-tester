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

    private var updateListenerTask: Task<Void, Error>?

    private let productID = "removeAds"

    private init() {
        // Start listening for transaction updates (refunds, background purchases, etc.)
        updateListenerTask = listenForTransactions()

        // Check current entitlements on init
        Task {
            await checkEntitlements()
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

    // MARK: - Entitlements Check

    /// Check current entitlements (call on app launch)
    @MainActor
    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID {
                    isAdRemoved = true
                    return
                }
            }
        }
        // No valid entitlement found
        isAdRemoved = false
    }

    // MARK: - Purchase

    @MainActor
    func purchaseAdRemoval() async {
        isLoading = true
        errorMessage = nil

        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                errorMessage = "Product not available"
                isLoading = false
                return
            }

            let result = try await product.purchase()
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
