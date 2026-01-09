//
//  StoreManagerTests.swift
//  winaTests
//
//  Tests for StoreManager IAP functionality using Mock-based approach.
//

import StoreKit
import Testing
@testable import wina

/// Mock implementation of StoreServiceProtocol for fast testing
final class MockStoreService: StoreServiceProtocol, @unchecked Sendable {
    var mockProducts: [Product] = []
    var mockPurchaseResult: Product.PurchaseResult?
    var mockEntitlementResult = EntitlementResult(hasEntitlement: false, wasRevoked: false)
    var mockUnfinishedResult: UnfinishedTransactionResult?
    var syncCalled = false
    var fetchError: Error?
    var purchaseError: Error?
    var syncError: Error?

    private var transactionContinuation: AsyncStream<(productID: String, isRevoked: Bool)>.Continuation?

    func fetchProducts(for ids: [String]) async throws -> [Product] {
        if let error = fetchError { throw error }
        return mockProducts
    }

    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        if let error = purchaseError { throw error }
        guard let result = mockPurchaseResult else {
            throw StoreKitError.unknown
        }
        return result
    }

    func sync() async throws {
        if let error = syncError { throw error }
        syncCalled = true
    }

    func checkEntitlement(for productID: String) async -> EntitlementResult {
        mockEntitlementResult
    }

    func processUnfinishedTransactions(for productID: String) async -> UnfinishedTransactionResult? {
        mockUnfinishedResult
    }

    func transactionUpdates() -> AsyncStream<(productID: String, isRevoked: Bool)> {
        AsyncStream { continuation in
            self.transactionContinuation = continuation
        }
    }

    /// Simulate a transaction update (for testing transaction listener)
    func simulateTransactionUpdate(productID: String, isRevoked: Bool) {
        transactionContinuation?.yield((productID: productID, isRevoked: isRevoked))
    }
}

// MARK: - Singleton Tests

@Suite("StoreManager Singleton Tests")
struct StoreManagerSingletonTests {

    @Test("Shared instance exists")
    func sharedInstanceExists() {
        let manager = StoreManager.shared
        #expect(manager === StoreManager.shared)
    }

    @Test("Shared instance is singleton")
    func sharedInstanceIsSingleton() {
        let manager1 = StoreManager.shared
        let manager2 = StoreManager.shared
        #expect(manager1 === manager2)
    }
}

// MARK: - Initial State Tests

@Suite("StoreManager Initial State Tests")
struct StoreManagerInitialStateTests {

    @Test("Initial loading is false")
    @MainActor
    func initialLoadingIsFalse() async {
        let mockService = MockStoreService()
        let manager = StoreManager.createForTesting(storeService: mockService)

        // Wait for init tasks to complete
        try? await Task.sleep(for: .milliseconds(50))

        #expect(manager.isLoading == false)
    }

    @Test("Initial error message is nil")
    @MainActor
    func initialErrorMessageIsNil() async {
        let mockService = MockStoreService()
        let manager = StoreManager.createForTesting(storeService: mockService)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(manager.errorMessage == nil)
    }

    @Test("Initial isAdRemoved is false with no entitlement")
    @MainActor
    func initialIsAdRemovedIsFalse() async {
        let mockService = MockStoreService()
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: false, wasRevoked: false)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(manager.isAdRemoved == false)
    }
}

// MARK: - Entitlement Tests

@Suite("StoreManager Entitlement Tests")
struct StoreManagerEntitlementTests {

    @Test("Check entitlements with no purchase returns false")
    @MainActor
    func checkEntitlementsWithNoPurchase() async {
        let mockService = MockStoreService()
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: false, wasRevoked: false)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.checkEntitlements()

        #expect(manager.isAdRemoved == false)
    }

    @Test("Check entitlements with valid purchase returns true")
    @MainActor
    func checkEntitlementsWithValidPurchase() async {
        let mockService = MockStoreService()
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: true, wasRevoked: false)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.checkEntitlements()

        #expect(manager.isAdRemoved == true)
    }

    @Test("Revoked entitlement removes ad removal")
    @MainActor
    func revokedEntitlementRemovesAdRemoval() async {
        let mockService = MockStoreService()
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: false, wasRevoked: true)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.checkEntitlements()

        #expect(manager.isAdRemoved == false)
    }
}

// MARK: - Purchase Flow Tests

@Suite("StoreManager Purchase Flow Tests")
struct StoreManagerPurchaseFlowTests {

    @Test("Purchase with no product shows error")
    @MainActor
    func purchaseWithNoProductShowsError() async {
        let mockService = MockStoreService()
        mockService.mockProducts = []  // No products available

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.purchaseAdRemoval()

        #expect(manager.errorMessage == "Product not available")
        #expect(manager.isLoading == false)
    }

    @Test("Purchase fetch error shows error message")
    @MainActor
    func purchaseFetchErrorShowsErrorMessage() async {
        let mockService = MockStoreService()
        mockService.fetchError = StoreKitError.unknown

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.purchaseAdRemoval()

        #expect(manager.errorMessage != nil)
        #expect(manager.isLoading == false)
    }

    @Test("Loading state resets after purchase attempt")
    @MainActor
    func loadingStateResetsAfterPurchaseAttempt() async {
        let mockService = MockStoreService()
        mockService.mockProducts = []

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.purchaseAdRemoval()

        #expect(manager.isLoading == false)
    }
}

// MARK: - Restore Tests

@Suite("StoreManager Restore Tests")
struct StoreManagerRestoreTests {

    @Test("Restore with no purchases shows error")
    @MainActor
    func restoreWithNoPurchasesShowsError() async {
        let mockService = MockStoreService()
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: false, wasRevoked: false)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.restorePurchases()

        #expect(manager.errorMessage == "No purchases to restore")
        #expect(manager.isLoading == false)
    }

    @Test("Restore with existing purchase succeeds")
    @MainActor
    func restoreWithExistingPurchaseSucceeds() async {
        let mockService = MockStoreService()
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: true, wasRevoked: false)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.restorePurchases()

        #expect(manager.isAdRemoved == true)
        #expect(manager.errorMessage == nil)
        #expect(manager.isLoading == false)
    }

    @Test("Restore calls sync")
    @MainActor
    func restoreCallsSync() async {
        let mockService = MockStoreService()

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.restorePurchases()

        #expect(mockService.syncCalled == true)
    }

    @Test("Sync error shows error message")
    @MainActor
    func syncErrorShowsErrorMessage() async {
        let mockService = MockStoreService()
        mockService.syncError = StoreKitError.unknown

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        await manager.restorePurchases()

        #expect(manager.errorMessage != nil)
        #expect(manager.isLoading == false)
    }
}

// MARK: - Unfinished Transaction Tests

@Suite("StoreManager Unfinished Transaction Tests")
struct StoreManagerUnfinishedTransactionTests {

    @Test("Unfinished valid transaction grants entitlement")
    @MainActor
    func unfinishedValidTransactionGrantsEntitlement() async {
        let mockService = MockStoreService()
        mockService.mockUnfinishedResult = UnfinishedTransactionResult(isAdRemoved: true)  // Valid transaction
        mockService.mockEntitlementResult = EntitlementResult(hasEntitlement: true, wasRevoked: false)

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(manager.isAdRemoved == true)
    }

    @Test("Unfinished revoked transaction removes entitlement")
    @MainActor
    func unfinishedRevokedTransactionRemovesEntitlement() async {
        let mockService = MockStoreService()
        mockService.mockUnfinishedResult = UnfinishedTransactionResult(isAdRemoved: false)  // Revoked transaction

        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(manager.isAdRemoved == false)
    }
}

// MARK: - Transaction Update Tests

@Suite("StoreManager Transaction Update Tests")
struct StoreManagerTransactionUpdateTests {

    @Test("Transaction update for matching product toggles ad removal")
    @MainActor
    func transactionUpdateMatchingProductTogglesAdRemoval() async {
        let mockService = MockStoreService()
        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        mockService.simulateTransactionUpdate(productID: "removeAds", isRevoked: false)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(manager.isAdRemoved == true)

        mockService.simulateTransactionUpdate(productID: "removeAds", isRevoked: true)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(manager.isAdRemoved == false)
    }

    @Test("Transaction update for other products is ignored")
    @MainActor
    func transactionUpdateOtherProductIgnored() async {
        let mockService = MockStoreService()
        let manager = StoreManager.createForTesting(storeService: mockService)
        try? await Task.sleep(for: .milliseconds(50))

        mockService.simulateTransactionUpdate(productID: "removeAds", isRevoked: false)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(manager.isAdRemoved == true)

        mockService.simulateTransactionUpdate(productID: "otherProduct", isRevoked: true)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(manager.isAdRemoved == true)
    }
}
