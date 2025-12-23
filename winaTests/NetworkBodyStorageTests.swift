//
//  NetworkBodyStorageTests.swift
//  winaTests
//
//  Tests for NetworkBodyStorage disk-based caching.
//

import XCTest
@testable import wina

final class NetworkBodyStorageTests: XCTestCase {

    var storage: NetworkBodyStorage!

    override func setUp() {
        super.setUp()
        storage = NetworkBodyStorage.shared
    }

    override func tearDown() {
        // Clear all cached files after each test
        storage.clearAll()

        // Wait for async file operations to complete
        let expectation = expectation(description: "Clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        storage = nil
        super.tearDown()
    }

    // MARK: - Save and Load Tests

    func testSaveAndLoadRequestBody() {
        let id = UUID()
        let body = "test request body content"

        storage.save(id: id, type: .request, body: body)

        // Wait for async save
        let expectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let loaded = storage.load(id: id, type: .request)
        XCTAssertEqual(loaded, body)
    }

    func testSaveAndLoadResponseBody() {
        let id = UUID()
        let body = "{\"data\": true, \"count\": 42}"

        storage.save(id: id, type: .response, body: body)

        let expectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let loaded = storage.load(id: id, type: .response)
        XCTAssertEqual(loaded, body)
    }

    func testLoadNonexistentReturnsNil() {
        let id = UUID()
        let loaded = storage.load(id: id, type: .request)
        XCTAssertNil(loaded)
    }

    func testSaveEmptyBodyDoesNotCreateFile() {
        let id = UUID()

        storage.save(id: id, type: .request, body: "")

        let expectation = expectation(description: "Save processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let loaded = storage.load(id: id, type: .request)
        XCTAssertNil(loaded)
    }

    // MARK: - Delete Tests

    func testDeleteRemovesBothRequestAndResponseBody() {
        let id = UUID()

        storage.save(id: id, type: .request, body: "request content")
        storage.save(id: id, type: .response, body: "response content")

        let saveExpectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Verify both exist
        XCTAssertNotNil(storage.load(id: id, type: .request))
        XCTAssertNotNil(storage.load(id: id, type: .response))

        storage.delete(id: id)

        let deleteExpectation = expectation(description: "Delete completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deleteExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertNil(storage.load(id: id, type: .request))
        XCTAssertNil(storage.load(id: id, type: .response))
    }

    func testDeleteMultipleIds() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        storage.save(id: id1, type: .request, body: "content 1")
        storage.save(id: id2, type: .request, body: "content 2")
        storage.save(id: id3, type: .request, body: "content 3")

        let saveExpectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        storage.delete(ids: [id1, id2])

        let deleteExpectation = expectation(description: "Delete completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deleteExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertNil(storage.load(id: id1, type: .request))
        XCTAssertNil(storage.load(id: id2, type: .request))
        XCTAssertNotNil(storage.load(id: id3, type: .request))
    }

    // MARK: - Clear All Tests

    func testClearAllRemovesEverything() {
        let id1 = UUID()
        let id2 = UUID()

        storage.save(id: id1, type: .request, body: "request 1")
        storage.save(id: id1, type: .response, body: "response 1")
        storage.save(id: id2, type: .response, body: "response 2")

        let saveExpectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        storage.clearAll()

        let clearExpectation = expectation(description: "Clear completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            clearExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertNil(storage.load(id: id1, type: .request))
        XCTAssertNil(storage.load(id: id1, type: .response))
        XCTAssertNil(storage.load(id: id2, type: .response))
    }

    // MARK: - Async Load Tests

    func testAsyncLoadCompletion() {
        let id = UUID()
        let body = "async content test"

        storage.save(id: id, type: .request, body: body)

        let saveExpectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let loadExpectation = expectation(description: "Async load completed")

        storage.loadAsync(id: id, type: .request) { result in
            XCTAssertEqual(result, body)
            loadExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testAsyncLoadNonexistentReturnsNil() {
        let id = UUID()

        let loadExpectation = expectation(description: "Async load completed")

        storage.loadAsync(id: id, type: .request) { result in
            XCTAssertNil(result)
            loadExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Special Characters Tests

    func testSaveBodyWithSpecialCharacters() {
        let id = UUID()
        let body = """
        {
            "emoji": "🎉🚀",
            "korean": "한글 테스트",
            "japanese": "日本語テスト",
            "quotes": "He said \\"Hello\\"",
            "newlines": "Line1\\nLine2"
        }
        """

        storage.save(id: id, type: .response, body: body)

        let expectation = expectation(description: "Save completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let loaded = storage.load(id: id, type: .response)
        XCTAssertEqual(loaded, body)
    }
}
