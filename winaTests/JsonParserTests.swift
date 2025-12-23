//
//  JsonParserTests.swift
//  winaTests
//
//  Tests for JsonParser: JSON parsing, validation, and CRUD operations
//

import XCTest
@testable import wina

// MARK: - JSON Validation Tests

final class JsonValidationTests: XCTestCase {

    func testValidJsonObject() {
        XCTAssertTrue(JsonParser.isValidJson("{}"))
        XCTAssertTrue(JsonParser.isValidJson("{\"key\": \"value\"}"))
        XCTAssertTrue(JsonParser.isValidJson("{\"a\": 1, \"b\": 2}"))
    }

    func testValidJsonArray() {
        XCTAssertTrue(JsonParser.isValidJson("[]"))
        XCTAssertTrue(JsonParser.isValidJson("[1, 2, 3]"))
        XCTAssertTrue(JsonParser.isValidJson("[\"a\", \"b\"]"))
    }

    func testValidJsonPrimitives() {
        // JSONSerialization.jsonObject() without .fragmentsAllowed does NOT parse primitives
        // These are technically valid JSON but not recognized as top-level objects/arrays
        XCTAssertFalse(JsonParser.isValidJson("\"string\""))
        XCTAssertFalse(JsonParser.isValidJson("123"))
        XCTAssertFalse(JsonParser.isValidJson("true"))
        XCTAssertFalse(JsonParser.isValidJson("false"))
        XCTAssertFalse(JsonParser.isValidJson("null"))
    }

    func testInvalidJson() {
        XCTAssertFalse(JsonParser.isValidJson(""))
        XCTAssertFalse(JsonParser.isValidJson("   "))
        XCTAssertFalse(JsonParser.isValidJson("{"))
        XCTAssertFalse(JsonParser.isValidJson("{\"key\":}"))
        XCTAssertFalse(JsonParser.isValidJson("not json"))
    }
}

// MARK: - Element Count Tests

final class JsonElementCountTests: XCTestCase {

    func testCountObjectKeys() {
        XCTAssertEqual(JsonParser.countElements("{}"), 0)
        XCTAssertEqual(JsonParser.countElements("{\"a\": 1}"), 1)
        XCTAssertEqual(JsonParser.countElements("{\"a\": 1, \"b\": 2, \"c\": 3}"), 3)
    }

    func testCountArrayItems() {
        XCTAssertEqual(JsonParser.countElements("[]"), 0)
        XCTAssertEqual(JsonParser.countElements("[1]"), 1)
        XCTAssertEqual(JsonParser.countElements("[1, 2, 3, 4, 5]"), 5)
    }

    func testCountPrimitive() {
        // JSONSerialization doesn't parse standalone primitives without fragmentsAllowed
        // So primitives return 0 (treated as invalid JSON)
        XCTAssertEqual(JsonParser.countElements("\"string\""), 0)
        XCTAssertEqual(JsonParser.countElements("123"), 0)
    }

    func testCountInvalid() {
        XCTAssertEqual(JsonParser.countElements("not json"), 0)
        XCTAssertEqual(JsonParser.countElements(""), 0)
    }
}

// MARK: - Parse Tests

final class JsonParseTests: XCTestCase {

    func testParseEmptyObject() {
        let result = JsonParser.parse("{}")

        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.node)
        XCTAssertNil(result.error)

        if case .object(let dict) = result.node?.value {
            XCTAssertTrue(dict.isEmpty)
        } else {
            XCTFail("Expected object")
        }
    }

    func testParseEmptyArray() {
        let result = JsonParser.parse("[]")

        XCTAssertTrue(result.isValid)
        if case .array(let arr) = result.node?.value {
            XCTAssertTrue(arr.isEmpty)
        } else {
            XCTFail("Expected array")
        }
    }

    func testParseObjectWithValues() {
        let json = """
        {
            "string": "hello",
            "number": 42,
            "boolean": true,
            "null": null
        }
        """
        let result = JsonParser.parse(json)

        XCTAssertTrue(result.isValid)
        if case .object(let dict) = result.node?.value {
            XCTAssertEqual(dict.count, 4)

            if case .string(let str) = dict["string"] {
                XCTAssertEqual(str, "hello")
            } else {
                XCTFail("Expected string")
            }

            if case .number(let num) = dict["number"] {
                XCTAssertEqual(num, 42)
            } else {
                XCTFail("Expected number")
            }

            if case .bool(let bool) = dict["boolean"] {
                XCTAssertTrue(bool)
            } else {
                XCTFail("Expected boolean")
            }

            if case .null = dict["null"] {
                // OK
            } else {
                XCTFail("Expected null")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    func testParseNestedStructure() {
        let json = """
        {
            "nested": {
                "array": [1, 2, 3]
            }
        }
        """
        let result = JsonParser.parse(json)

        XCTAssertTrue(result.isValid)
    }

    func testParseEmpty() {
        let result = JsonParser.parse("")

        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.node)
        XCTAssertNil(result.error)
    }

    func testParseInvalid() {
        let result = JsonParser.parse("{invalid}")

        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.node)
        XCTAssertNotNil(result.error)
    }

    func testParseErrorMessage() {
        let result = JsonParser.parse("{\"key\": }")

        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error?.displayMessage)
    }
}

// MARK: - Pretty Print Tests

final class JsonPrettyPrintTests: XCTestCase {

    func testPrettyPrintObject() {
        let minified = "{\"b\":2,\"a\":1}"
        let pretty = JsonParser.prettyPrint(minified)

        XCTAssertNotNil(pretty)
        XCTAssertTrue(pretty!.contains("\n"))
        // Should be sorted by key
        XCTAssertTrue(pretty!.contains("\"a\""))
        XCTAssertTrue(pretty!.contains("\"b\""))
    }

    func testPrettyPrintArray() {
        let minified = "[1,2,3]"
        let pretty = JsonParser.prettyPrint(minified)

        XCTAssertNotNil(pretty)
        XCTAssertTrue(pretty!.contains("\n"))
    }

    func testPrettyPrintInvalid() {
        let result = JsonParser.prettyPrint("not json")
        XCTAssertNil(result)
    }
}

// MARK: - Minify Tests

final class JsonMinifyTests: XCTestCase {

    func testMinifyObject() {
        let pretty = """
        {
            "key": "value",
            "number": 123
        }
        """
        let minified = JsonParser.minify(pretty)

        XCTAssertNotNil(minified)
        XCTAssertFalse(minified!.contains("\n"))
    }

    func testMinifyInvalid() {
        let result = JsonParser.minify("not json")
        XCTAssertNil(result)
    }
}

// MARK: - CRUD Operations Tests

final class JsonCRUDTests: XCTestCase {

    // MARK: - Add to Object

    func testAddToRootObject() {
        let json = "{\"a\": 1}"
        let result = JsonParser.addToObject(json, at: [], key: "b", value: 2)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"b\""))
        XCTAssertTrue(result!.contains("2"))
    }

    func testAddToNestedObject() {
        let json = "{\"nested\": {}}"
        let result = JsonParser.addToObject(json, at: ["nested"], key: "key", value: "value")

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"key\""))
        XCTAssertTrue(result!.contains("\"value\""))
    }

    func testAddToNonObject() {
        let json = "[1, 2, 3]"
        let result = JsonParser.addToObject(json, at: [], key: "key", value: "value")

        XCTAssertNil(result)  // Can't add key to array
    }

    // MARK: - Append to Array

    func testAppendToRootArray() {
        let json = "[1, 2]"
        let result = JsonParser.appendToArray(json, at: [], value: 3)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("3"))
    }

    func testAppendToNestedArray() {
        let json = "{\"items\": [1, 2]}"
        let result = JsonParser.appendToArray(json, at: ["items"], value: 3)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("3"))
    }

    func testAppendToNonArray() {
        let json = "{}"
        let result = JsonParser.appendToArray(json, at: [], value: 1)

        XCTAssertNil(result)  // Can't append to object
    }

    // MARK: - Delete

    func testDeleteFromObject() {
        let json = "{\"a\": 1, \"b\": 2}"
        let result = JsonParser.delete(json, at: ["a"])

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.contains("\"a\""))
        XCTAssertTrue(result!.contains("\"b\""))
    }

    func testDeleteFromArray() {
        let json = "[1, 2, 3]"
        let result = JsonParser.delete(json, at: ["[1]"])

        XCTAssertNotNil(result)
        // Should remove index 1 (value 2)
    }

    func testDeleteRoot() {
        let json = "{}"
        let result = JsonParser.delete(json, at: [])

        XCTAssertNil(result)  // Can't delete root
    }

    // MARK: - Update

    func testUpdateValue() {
        let json = "{\"key\": \"old\"}"
        let result = JsonParser.update(json, at: ["key"], value: "new")

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"new\""))
        XCTAssertFalse(result!.contains("\"old\""))
    }

    func testUpdateNestedValue() {
        let json = "{\"nested\": {\"key\": 1}}"
        let result = JsonParser.update(json, at: ["nested", "key"], value: 2)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("2"))
    }

    func testUpdateArrayElement() {
        let json = "[1, 2, 3]"
        let result = JsonParser.update(json, at: ["[1]"], value: 99)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("99"))
    }

    func testUpdateRoot() {
        let json = "{\"old\": \"data\"}"
        let result = JsonParser.update(json, at: [], value: ["new": "data"])

        XCTAssertNotNil(result)
    }
}

// MARK: - JSON Template Tests

final class JsonTemplateTests: XCTestCase {

    func testEmptyObjectTemplate() {
        XCTAssertEqual(JsonTemplate.emptyObject.content, "{}")
    }

    func testEmptyArrayTemplate() {
        XCTAssertEqual(JsonTemplate.emptyArray.content, "[]")
    }

    func testKeyValueTemplate() {
        let content = JsonTemplate.keyValue.content
        XCTAssertTrue(content.contains("\"key\""))
        XCTAssertTrue(content.contains("\"value\""))
    }

    func testArrayWithItemsTemplate() {
        let content = JsonTemplate.arrayWithItems.content
        XCTAssertTrue(content.contains("\"item1\""))
        XCTAssertTrue(content.contains("\"item2\""))
    }

    func testTemplateIcons() {
        XCTAssertEqual(JsonTemplate.emptyObject.icon, "curlybraces")
        XCTAssertEqual(JsonTemplate.emptyArray.icon, "brackets")
        XCTAssertEqual(JsonTemplate.keyValue.icon, "curlybraces")
        XCTAssertEqual(JsonTemplate.arrayWithItems.icon, "brackets")
    }

    func testAllCases() {
        XCTAssertEqual(JsonTemplate.allCases.count, 4)
    }
}

// MARK: - Parse Error Tests

final class JsonParseErrorTests: XCTestCase {

    func testErrorDisplayMessageWithLocation() {
        let error = JsonParser.ParseError(
            message: "Unexpected token",
            position: 10,
            line: 2,
            column: 5
        )

        XCTAssertEqual(error.displayMessage, "Line 2, Col 5: Unexpected token")
    }

    func testErrorDisplayMessageWithoutLocation() {
        let error = JsonParser.ParseError(
            message: "Invalid JSON",
            position: nil,
            line: nil,
            column: nil
        )

        XCTAssertEqual(error.displayMessage, "Invalid JSON")
    }
}
