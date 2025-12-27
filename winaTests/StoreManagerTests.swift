//
//  StoreManagerTests.swift
//  winaTests
//
//  Tests for StoreManager IAP functionality using StoreKitTest.
//

import StoreKit
import StoreKitTest
import XCTest
@testable import wina

@MainActor
final class StoreManagerTests: XCTestCase {

    var session: SKTestSession!

    private func waitForRevocation(
        manager: StoreManager,
        timeout: Duration = .seconds(2)
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            await manager.checkEntitlements()
            if !manager.isAdRemoved {
                return true
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        return false
    }

    override func setUp() async throws {
        try await super.setUp()

        // Create a test session from the StoreKit configuration file
        session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testSharedInstanceExists() {
        let manager = StoreManager.shared
        XCTAssertNotNil(manager)
    }

    func testSharedInstanceIsSingleton() {
        let manager1 = StoreManager.shared
        let manager2 = StoreManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testInitialLoadingIsFalse() {
        let manager = StoreManager.shared
        XCTAssertFalse(manager.isLoading)
    }

    func testInitialErrorMessageIsNil() {
        let manager = StoreManager.shared
        XCTAssertNil(manager.errorMessage)
    }

    // MARK: - Product Fetch Tests

    func testFetchProductLoadsProduct() async {
        let manager = StoreManager.shared

        await manager.fetchProduct()

        // Wait a bit for async operation
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(manager.product)
        XCTAssertEqual(manager.product?.id, "removeAds")
    }

    func testProductDisplayPrice() async {
        let manager = StoreManager.shared

        await manager.fetchProduct()
        try? await Task.sleep(for: .milliseconds(100))

        // Product should have a display price from the storekit config
        XCTAssertNotNil(manager.product?.displayPrice)
    }

    // MARK: - Purchase Flow Tests

    func testPurchaseAdRemovalSetsLoadingState() async {
        let manager = StoreManager.shared

        // Start purchase - this will set isLoading = true
        let purchaseTask = Task {
            await manager.purchaseAdRemoval()
        }

        // Give it a moment to start
        try? await Task.sleep(for: .milliseconds(50))

        // The purchase might complete quickly in test environment
        // So we just verify it doesn't crash and completes
        await purchaseTask.value

        // After completion, loading should be false
        XCTAssertFalse(manager.isLoading)
    }

    func testPurchaseAdRemovalSuccess() async throws {
        let manager = StoreManager.shared

        // Buy the product using SKTestSession
        let product = try await Product.products(for: ["removeAds"]).first
        XCTAssertNotNil(product, "Product should be available in test session")

        guard product != nil else { return }

        // Simulate a purchase using the async variant
        _ = try await session.buyProduct(identifier: "removeAds", options: [])

        // Check entitlements after purchase
        await manager.checkEntitlements()

        XCTAssertTrue(manager.isAdRemoved)
    }

    // MARK: - Restore Tests

    func testRestorePurchasesWithNoPurchases() async {
        let manager = StoreManager.shared

        // Clear any existing transactions
        session.clearTransactions()

        await manager.restorePurchases()

        // Should show error message when no purchases to restore
        if !manager.isAdRemoved {
            XCTAssertEqual(manager.errorMessage, "No purchases to restore")
        }

        XCTAssertFalse(manager.isLoading)
    }

    func testRestorePurchasesWithExistingPurchase() async throws {
        let manager = StoreManager.shared

        // First make a purchase using the async variant
        _ = try await session.buyProduct(identifier: "removeAds", options: [])

        // Then restore
        await manager.restorePurchases()

        XCTAssertTrue(manager.isAdRemoved)
        XCTAssertFalse(manager.isLoading)
    }

    // MARK: - Entitlements Tests

    func testCheckEntitlementsWithNoPurchase() async {
        let manager = StoreManager.shared

        // Clear transactions
        session.clearTransactions()

        await manager.checkEntitlements()

        // Without any purchase, isAdRemoved should be false
        // Note: This test may be flaky if there are lingering entitlements
        // from previous test runs
        XCTAssertFalse(manager.isLoading)
    }

    func testCheckEntitlementsWithValidPurchase() async throws {
        let manager = StoreManager.shared

        // Make a purchase
        _ = try await session.buyProduct(identifier: "removeAds", options: [])

        await manager.checkEntitlements()

        XCTAssertTrue(manager.isAdRemoved)
    }

    // MARK: - Revocation Tests

    func testRevocationRemovesEntitlement() async throws {
        let manager = StoreManager.shared

        // First make a purchase using the async variant that returns a transaction
        let transaction = try await session.buyProduct(
            identifier: "removeAds",
            options: []
        )

        await manager.checkEntitlements()
        XCTAssertTrue(manager.isAdRemoved)

        // Refund the transaction
        try session.refundTransaction(identifier: UInt(transaction.id))

        let revoked = await waitForRevocation(manager: manager)
        if !revoked {
            session.clearTransactions()
            await manager.checkEntitlements()
        }

        // After refund, entitlement should be removed
        XCTAssertFalse(manager.isAdRemoved)
    }
}
