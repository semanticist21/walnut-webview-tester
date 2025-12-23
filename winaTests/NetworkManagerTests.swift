//
//  NetworkManagerTests.swift
//  winaTests
//
//  Tests for NetworkManager request tracking, memory management, and statistics.
//

import XCTest
@testable import wina

final class NetworkManagerTests: XCTestCase {

    var manager: NetworkManager!

    override func setUp() {
        super.setUp()
        manager = NetworkManager()
    }

    override func tearDown() {
        manager.clear()
        manager = nil
        super.tearDown()
    }

    // MARK: - Request Lifecycle Tests

    func testAddRequestCreatesNewEntry() {
        let id = UUID().uuidString
        manager.addRequest(
            id: id,
            method: "GET",
            url: "https://example.com/api",
            requestType: "fetch",
            headers: ["Accept": "application/json"],
            body: nil
        )

        // Wait for async dispatch
        let expectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.requests.count, 1)
        XCTAssertEqual(manager.requests.first?.method, "GET")
        XCTAssertEqual(manager.requests.first?.url, "https://example.com/api")
        XCTAssertNil(manager.requests.first?.status)  // Still pending
    }

    func testAddRequestNormalizesMethodToUppercase() {
        manager.addRequest(
            id: UUID().uuidString,
            method: "post",
            url: "https://example.com",
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let expectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.requests.first?.method, "POST")
    }

    func testUpdateRequestSetsStatusAndResponse() {
        let id = UUID().uuidString

        manager.addRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let addExpectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        manager.updateRequest(
            id: id,
            status: 200,
            statusText: "OK",
            responseHeaders: ["Content-Type": "application/json"],
            responseBody: "{\"success\": true}",
            error: nil
        )

        let updateExpectation = expectation(description: "Request updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let request = manager.requests.first
        XCTAssertEqual(request?.status, 200)
        XCTAssertEqual(request?.statusText, "OK")
        XCTAssertNotNil(request?.endTime)
    }

    func testUpdateNonexistentRequestDoesNothing() {
        manager.updateRequest(
            id: UUID().uuidString,
            status: 200,
            statusText: "OK",
            responseHeaders: nil,
            responseBody: nil,
            error: nil
        )

        let expectation = expectation(description: "Update processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(manager.requests.isEmpty)
    }

    func testPendingCountTracksIncompleteRequests() {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString

        manager.addRequest(id: id1, method: "GET", url: "https://a.com", requestType: "fetch", headers: nil, body: nil)
        manager.addRequest(id: id2, method: "POST", url: "https://b.com", requestType: "xhr", headers: nil, body: nil)

        let addExpectation = expectation(description: "Requests added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.pendingCount, 2)

        manager.updateRequest(id: id1, status: 200, statusText: "OK", responseHeaders: nil, responseBody: nil, error: nil)

        let updateExpectation = expectation(description: "Request updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.pendingCount, 1)
    }

    func testErrorCountTracksFailedRequests() {
        let id = UUID().uuidString

        manager.addRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let addExpectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        manager.updateRequest(
            id: id,
            status: 500,
            statusText: "Internal Server Error",
            responseHeaders: nil,
            responseBody: nil,
            error: nil
        )

        let updateExpectation = expectation(description: "Request updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.errorCount, 1)
    }

    // MARK: - Clear Tests

    func testClearRemovesAllRequests() {
        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "https://example.com/1",
            requestType: "fetch",
            headers: nil,
            body: nil
        )
        manager.addRequest(
            id: UUID().uuidString,
            method: "POST",
            url: "https://example.com/2",
            requestType: "xhr",
            headers: nil,
            body: nil
        )

        let addExpectation = expectation(description: "Requests added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.requests.count, 2)

        manager.clear()

        XCTAssertTrue(manager.requests.isEmpty)
    }

    func testClearIfNotPreservedClearsWhenPreserveLogFalse() {
        // Temporarily set preserveLog to false
        UserDefaults.standard.set(false, forKey: "networkPreserveLog")

        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "https://example.com",
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let addExpectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        manager.clearIfNotPreserved()

        XCTAssertTrue(manager.requests.isEmpty)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "networkPreserveLog")
    }

    func testClearIfNotPreservedKeepsWhenPreserveLogTrue() {
        // Set preserveLog to true
        UserDefaults.standard.set(true, forKey: "networkPreserveLog")

        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "https://example.com",
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let addExpectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        manager.clearIfNotPreserved()

        XCTAssertEqual(manager.requests.count, 1)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "networkPreserveLog")
    }

    // MARK: - Mixed Content Tests

    func testMixedContentDetectsHTTPOnHTTPSPage() {
        // Set page as HTTPS
        manager.pageURL = URL(string: "https://secure.com")

        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "http://insecure.com/image.png",  // HTTP resource
            requestType: "image",
            headers: nil,
            body: nil
        )

        let expectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.mixedContentCount, 1)
    }

    func testMixedContentIgnoresHTTPSOnHTTPS() {
        // Set page as HTTPS
        manager.pageURL = URL(string: "https://secure.com")

        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "https://secure.com/api",  // HTTPS resource
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let expectation = expectation(description: "Request added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.mixedContentCount, 0)
    }

    // MARK: - Page Security Tests

    func testPageIsSecureReturnsCorrectValue() {
        manager.pageURL = URL(string: "https://example.com")
        XCTAssertTrue(manager.pageIsSecure)

        manager.pageURL = URL(string: "http://example.com")
        XCTAssertFalse(manager.pageIsSecure)

        manager.pageURL = nil
        XCTAssertFalse(manager.pageIsSecure)
    }

    // MARK: - Capture Toggle Tests

    func testIsCapturingDisablesNewRequests() {
        manager.isCapturing = false

        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "https://example.com",
            requestType: "fetch",
            headers: nil,
            body: nil
        )

        let expectation = expectation(description: "Request processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(manager.requests.isEmpty)
    }

    // MARK: - Request Type Tests

    func testRequestTypeParsing() {
        manager.addRequest(
            id: UUID().uuidString,
            method: "GET",
            url: "https://example.com/api",
            requestType: "fetch",
            headers: nil,
            body: nil
        )
        manager.addRequest(
            id: UUID().uuidString,
            method: "POST",
            url: "https://example.com/data",
            requestType: "xhr",
            headers: nil,
            body: nil
        )

        let expectation = expectation(description: "Requests added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let fetchRequest = manager.requests.first { $0.url.contains("/api") }
        let xhrRequest = manager.requests.first { $0.url.contains("/data") }

        XCTAssertEqual(fetchRequest?.requestType, .fetch)
        XCTAssertEqual(xhrRequest?.requestType, .xhr)
    }
}

// MARK: - LogClearStrategy Tests

final class LogClearStrategyTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(LogClearStrategy.origin.displayName, "Same Origin")
        XCTAssertEqual(LogClearStrategy.page.displayName, "Each Page")
        XCTAssertEqual(LogClearStrategy.keep.displayName, "Keep All")
    }

    func testDescriptions() {
        XCTAssertFalse(LogClearStrategy.origin.description.isEmpty)
        XCTAssertFalse(LogClearStrategy.page.description.isEmpty)
        XCTAssertFalse(LogClearStrategy.keep.description.isEmpty)
    }

    func testAllCases() {
        XCTAssertEqual(LogClearStrategy.allCases.count, 3)
    }
}
