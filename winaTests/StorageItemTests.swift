//
//  StorageItemTests.swift
//  winaTests
//
//  Tests for StorageItem Equatable implementation.
//  Verifies that value changes are properly detected for SwiftUI updates.
//

import Foundation
import Testing
@testable import wina

// MARK: - StorageItem Equatable Tests

@Suite("StorageItem Equatable")
struct StorageItemEquatableTests {

    // MARK: - Basic Equality (Same Instance)

    @Test("Same instance is equal to itself")
    func testSameInstanceIsEqual() {
        let item = StorageItem(
            key: "testKey",
            value: "testValue",
            storageType: .localStorage
        )

        #expect(item == item)
    }

    // MARK: - Different Properties Tests

    @Test("Different keys are not equal")
    func testDifferentKeysNotEqual() {
        let item1 = StorageItem(
            key: "key1",
            value: "value",
            storageType: .localStorage
        )
        let item2 = StorageItem(
            key: "key2",
            value: "value",
            storageType: .localStorage
        )

        #expect(item1 != item2)
    }

    @Test("Different values are not equal")
    func testDifferentValuesNotEqual() {
        let item1 = StorageItem(
            key: "key",
            value: "value1",
            storageType: .localStorage
        )
        let item2 = StorageItem(
            key: "key",
            value: "value2",
            storageType: .localStorage
        )

        #expect(item1 != item2)
    }

    @Test("Different storage types are not equal")
    func testDifferentStorageTypesNotEqual() {
        let item1 = StorageItem(
            key: "key",
            value: "value",
            storageType: .localStorage
        )
        let item2 = StorageItem(
            key: "key",
            value: "value",
            storageType: .sessionStorage
        )

        #expect(item1 != item2)
    }

    // MARK: - ID Uniqueness

    @Test("Each instance has unique ID")
    func testUniqueIds() {
        let item1 = StorageItem(
            key: "key",
            value: "value",
            storageType: .localStorage
        )
        let item2 = StorageItem(
            key: "key",
            value: "value",
            storageType: .localStorage
        )

        // UUID is auto-generated per instance
        #expect(item1.id != item2.id)
    }

    // MARK: - Value Update Detection (Critical for SwiftUI)

    @Test("Value change creates different item")
    func testValueChangeCreatesDifferentItem() {
        let item1 = StorageItem(
            key: "counter",
            value: "1",
            storageType: .localStorage
        )

        // Simulate value update - create new instance with different value
        let item2 = StorageItem(
            key: "counter",
            value: "2",
            storageType: .localStorage
        )

        // Items must not be equal for SwiftUI to detect change
        #expect(item1 != item2, "Value change must be detected for SwiftUI to update UI")
    }

    @Test("Same value same key different instances are not equal")
    func testDifferentInstancesNotEqual() {
        // Even with same properties, different instances have different IDs
        let item1 = StorageItem(
            key: "key",
            value: "value",
            storageType: .localStorage
        )
        let item2 = StorageItem(
            key: "key",
            value: "value",
            storageType: .localStorage
        )

        // Because ID is auto-generated UUID, these are different
        #expect(item1 != item2)
    }
}

// MARK: - StorageItem Storage Type Tests

@Suite("StorageItem StorageType")
struct StorageItemStorageTypeTests {

    @Test("localStorage has correct properties")
    func testLocalStorage() {
        let type = StorageItem.StorageType.localStorage
        #expect(type.label == "Local")
        #expect(type.icon == "internaldrive")
        #expect(type.rawValue == "localStorage")
    }

    @Test("sessionStorage has correct properties")
    func testSessionStorage() {
        let type = StorageItem.StorageType.sessionStorage
        #expect(type.label == "Session")
        #expect(type.icon == "clock")
        #expect(type.rawValue == "sessionStorage")
    }

    @Test("cookies has correct properties")
    func testCookies() {
        let type = StorageItem.StorageType.cookies
        #expect(type.label == "Cookies")
        #expect(type.icon == "birthday.cake")
        #expect(type.rawValue == "cookies")
    }

    @Test("All storage types are covered")
    func testAllCases() {
        let allCases = StorageItem.StorageType.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.localStorage))
        #expect(allCases.contains(.sessionStorage))
        #expect(allCases.contains(.cookies))
    }

    @Test("Storage types have stable sort order")
    func testSortOrder() {
        #expect(StorageItem.StorageType.localStorage.sortOrder == 0)
        #expect(StorageItem.StorageType.sessionStorage.sortOrder == 1)
        #expect(StorageItem.StorageType.cookies.sortOrder == 2)

        let sorted = StorageItem.StorageType.allCases.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted == [.localStorage, .sessionStorage, .cookies])
    }
}

// MARK: - StorageValueType Tests

@Suite("StorageValueType Detection")
struct StorageValueTypeTests {

    @Test("Detects empty value")
    func testEmptyValue() {
        #expect(StorageValueType.detect(from: "") == .empty)
    }

    @Test("Detects JSON object")
    func testJsonObject() {
        #expect(StorageValueType.detect(from: "{\"key\": \"value\"}") == .json)
        #expect(StorageValueType.detect(from: "{}") == .json)
    }

    @Test("Detects JSON array")
    func testJsonArray() {
        #expect(StorageValueType.detect(from: "[1, 2, 3]") == .json)
        #expect(StorageValueType.detect(from: "[]") == .json)
    }

    @Test("Detects boolean true")
    func testBooleanTrue() {
        #expect(StorageValueType.detect(from: "true") == .bool)
        #expect(StorageValueType.detect(from: "TRUE") == .bool)
        #expect(StorageValueType.detect(from: "True") == .bool)
    }

    @Test("Detects boolean false")
    func testBooleanFalse() {
        #expect(StorageValueType.detect(from: "false") == .bool)
        #expect(StorageValueType.detect(from: "FALSE") == .bool)
        #expect(StorageValueType.detect(from: "False") == .bool)
    }

    @Test("Detects number")
    func testNumber() {
        #expect(StorageValueType.detect(from: "42") == .number)
        #expect(StorageValueType.detect(from: "3.14") == .number)
        #expect(StorageValueType.detect(from: "-100") == .number)
        #expect(StorageValueType.detect(from: "0") == .number)
    }

    @Test("Detects string")
    func testString() {
        #expect(StorageValueType.detect(from: "hello") == .string)
        #expect(StorageValueType.detect(from: "some text here") == .string)
        #expect(StorageValueType.detect(from: "123abc") == .string) // Not a pure number
    }

    @Test("Non-JSON curly braces detected as string")
    func testInvalidJson() {
        // Invalid JSON should fall back to string
        #expect(StorageValueType.detect(from: "{invalid json") == .string)
        #expect(StorageValueType.detect(from: "[1, 2, ") == .string)
    }
}

// MARK: - URL Encoding Tests

@Suite("URL Encoding/Decoding")
struct URLEncodingTests {

    // MARK: - Basic Encoding

    @Test("Encodes special characters")
    func testEncodesSpecialCharacters() {
        let original = "hello world"
        let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded == "hello%20world")
    }

    @Test("Encodes ampersand and equals")
    func testEncodesAmpersandEquals() {
        let original = "key=value&foo=bar"
        let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        // Note: = and & are allowed in urlQueryAllowed
        #expect(encoded == "key=value&foo=bar")
    }

    @Test("Encodes Korean characters")
    func testEncodesKorean() {
        let original = "안녕하세요"
        let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded != nil)
        #expect(encoded != original)
        #expect(encoded?.contains("%") == true)
    }

    @Test("Encodes emoji")
    func testEncodesEmoji() {
        let original = "hello 👋 world"
        let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded != nil)
        #expect(encoded?.contains("%") == true)
    }

    // MARK: - Basic Decoding

    @Test("Decodes percent-encoded space")
    func testDecodesSpace() {
        let encoded = "hello%20world"
        let decoded = encoded.removingPercentEncoding
        #expect(decoded == "hello world")
    }

    @Test("Decodes Korean characters")
    func testDecodesKorean() {
        let original = "안녕하세요"
        let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let decoded = encoded.removingPercentEncoding
        #expect(decoded == original)
    }

    // MARK: - Round-trip Tests

    @Test("Encode then decode returns original")
    func testRoundTrip() {
        let testCases = [
            "hello world",
            "안녕하세요",
            "email@example.com",
            "path/to/file",
            "query=value&other=123",
            "special chars: !@#$%^&*()",
            ""
        ]

        for original in testCases {
            let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            #expect(encoded != nil, "Encoding failed for: \(original)")

            let decoded = encoded?.removingPercentEncoding
            #expect(decoded == original, "Round-trip failed for: \(original)")
        }
    }

    // MARK: - Edge Cases

    @Test("Empty string encoding")
    func testEmptyString() {
        let empty = ""
        let encoded = empty.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded == "")

        let decoded = encoded?.removingPercentEncoding
        #expect(decoded == "")
    }

    @Test("Already encoded string double encoding")
    func testDoubleEncoding() {
        let original = "hello world"
        let encoded1 = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        // hello%20world

        let encoded2 = encoded1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        // hello%2520world (% becomes %25)

        #expect(encoded1 == "hello%20world")
        #expect(encoded2 == "hello%2520world")
        #expect(encoded1 != encoded2, "Double encoding should produce different result")
    }

    @Test("Already decoded string stays same")
    func testAlreadyDecodedString() {
        let plain = "hello world"
        let decoded = plain.removingPercentEncoding
        #expect(decoded == plain, "Plain string should stay the same after decode")
    }

    @Test("Invalid percent encoding returns nil or original")
    func testInvalidPercentEncoding() {
        // Invalid percent sequences
        let invalid1 = "hello%GGworld"  // GG is not valid hex
        let decoded1 = invalid1.removingPercentEncoding
        // Swift returns nil for invalid sequences
        #expect(decoded1 == nil || decoded1 == invalid1)

        let invalid2 = "hello%2"  // Incomplete percent sequence
        let decoded2 = invalid2.removingPercentEncoding
        #expect(decoded2 == nil || decoded2 == invalid2)
    }

    // MARK: - Cookie Value Specific Tests

    @Test("Cookie value with semicolon")
    func testCookieValueWithSemicolon() {
        // Semicolons are special in cookies
        let original = "value;with;semicolons"
        let encoded = original.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded != nil)

        let decoded = encoded?.removingPercentEncoding
        #expect(decoded == original)
    }

    @Test("Cookie value with JSON")
    func testCookieValueWithJson() {
        let jsonValue = "{\"user\":\"john\",\"id\":123}"
        let encoded = jsonValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded != nil)

        let decoded = encoded?.removingPercentEncoding
        #expect(decoded == jsonValue)
    }

    // MARK: - State Toggle Simulation

    @Test("Toggle encode/decode state simulation")
    func testToggleSimulation() {
        // Simulate the UI toggle behavior
        var currentValue = "hello%20world"
        var isDecoded = false

        // Initial state: encoded
        #expect(isDecoded == false)

        // User clicks "Decoded" - switch to decoded view
        if !isDecoded {
            if let decoded = currentValue.removingPercentEncoding {
                currentValue = decoded
            }
            isDecoded = true
        }
        #expect(currentValue == "hello world")
        #expect(isDecoded == true)

        // User clicks "Encoded" - switch back to encoded view
        if isDecoded {
            if let encoded = currentValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                currentValue = encoded
            }
            isDecoded = false
        }
        #expect(currentValue == "hello%20world")
        #expect(isDecoded == false)
    }

    @Test("Toggle with non-encoded value")
    func testToggleWithPlainValue() {
        // Start with a plain value (no encoding needed)
        var currentValue = "plaintext"
        var isDecoded = false

        // Switch to decoded - nothing changes
        if !isDecoded {
            if let decoded = currentValue.removingPercentEncoding {
                currentValue = decoded
            }
            isDecoded = true
        }
        #expect(currentValue == "plaintext")

        // Switch to encoded - nothing changes
        if isDecoded {
            if let encoded = currentValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                currentValue = encoded
            }
            isDecoded = false
        }
        #expect(currentValue == "plaintext")
    }
}
