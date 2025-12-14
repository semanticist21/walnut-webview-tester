//
//  StorageItemTests.swift
//  winaTests
//
//  Tests for StorageItem Equatable implementation.
//  Verifies that value changes are properly detected for SwiftUI updates.
//

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
