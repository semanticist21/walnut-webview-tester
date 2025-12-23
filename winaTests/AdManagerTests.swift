//
//  AdManagerTests.swift
//  winaTests
//
//  Tests for AdManager and AdOptions.
//

import XCTest
@testable import wina

// MARK: - AdOptions Tests

final class AdOptionsTests: XCTestCase {

    func testDefaultProbability() {
        let options = AdOptions(id: "test")
        XCTAssertEqual(options.probability, 0.3)
    }

    func testCustomProbability() {
        let options = AdOptions(id: "test", probability: 0.5)
        XCTAssertEqual(options.probability, 0.5)
    }

    func testProbabilityClampedToMin() {
        let options = AdOptions(id: "test", probability: -0.5)
        XCTAssertEqual(options.probability, 0.0)
    }

    func testProbabilityClampedToMax() {
        let options = AdOptions(id: "test", probability: 1.5)
        XCTAssertEqual(options.probability, 1.0)
    }

    func testProbabilityAtBoundaries() {
        let zeroOptions = AdOptions(id: "test", probability: 0.0)
        XCTAssertEqual(zeroOptions.probability, 0.0)

        let oneOptions = AdOptions(id: "test", probability: 1.0)
        XCTAssertEqual(oneOptions.probability, 1.0)
    }

    func testIdIsPreserved() {
        let options = AdOptions(id: "unique_feature_id")
        XCTAssertEqual(options.id, "unique_feature_id")
    }
}

// MARK: - AdManager Tests

@MainActor
final class AdManagerTests: XCTestCase {

    var manager: AdManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = AdManager.shared
        manager.resetAllShownStates()
    }

    override func tearDown() async throws {
        manager.resetAllShownStates()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstanceExists() {
        XCTAssertNotNil(AdManager.shared)
    }

    func testSharedInstanceIsSingleton() {
        let manager1 = AdManager.shared
        let manager2 = AdManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    // MARK: - Ad Unit ID Tests

    func testInterstitialAdUnitIdIsValid() {
        let adUnitId = AdManager.interstitialAdUnitId
        XCTAssertFalse(adUnitId.isEmpty)
        XCTAssertTrue(adUnitId.hasPrefix("ca-app-pub-"))
    }

    func testBannerAdUnitIdIsValid() {
        let adUnitId = AdManager.bannerAdUnitId
        XCTAssertFalse(adUnitId.isEmpty)
        XCTAssertTrue(adUnitId.hasPrefix("ca-app-pub-"))
    }

    func testTestInterstitialAdUnitIdIsGoogleTest() {
        let testAdUnitId = AdManager.testInterstitialAdUnitId
        // Google's test ad unit IDs start with this prefix
        XCTAssertTrue(testAdUnitId.hasPrefix("ca-app-pub-3940256099942544"))
    }

    func testTestBannerAdUnitIdIsGoogleTest() {
        let testAdUnitId = AdManager.testBannerAdUnitId
        // Google's test ad unit IDs start with this prefix
        XCTAssertTrue(testAdUnitId.hasPrefix("ca-app-pub-3940256099942544"))
    }

    // MARK: - shownAdIds Tracking Tests

    func testHasShownAdReturnsFalseInitially() {
        XCTAssertFalse(manager.hasShownAd(for: "test_id"))
    }

    func testResetShownStateForSpecificId() {
        // We can't directly set shownAdIds, but we can test the reset methods
        // First test that hasShownAd returns false for a new id
        let testId = "reset_test_id"
        XCTAssertFalse(manager.hasShownAd(for: testId))

        // Reset should not crash even if id wasn't shown
        manager.resetShownState(for: testId)
        XCTAssertFalse(manager.hasShownAd(for: testId))
    }

    func testResetAllShownStates() {
        // Test that reset doesn't crash
        manager.resetAllShownStates()

        // After reset, all should return false
        XCTAssertFalse(manager.hasShownAd(for: "id1"))
        XCTAssertFalse(manager.hasShownAd(for: "id2"))
        XCTAssertFalse(manager.hasShownAd(for: "id3"))
    }

    func testMultipleIdsTrackedIndependently() {
        // Each id should be tracked independently
        let id1 = "feature_1"
        let id2 = "feature_2"

        // Both should be initially false
        XCTAssertFalse(manager.hasShownAd(for: id1))
        XCTAssertFalse(manager.hasShownAd(for: id2))

        // Reset one should not affect the other
        manager.resetShownState(for: id1)
        XCTAssertFalse(manager.hasShownAd(for: id1))
        XCTAssertFalse(manager.hasShownAd(for: id2))
    }
}
