//
//  JsonParserEdgeCaseTests.swift
//  winaTests
//
//  Extensive edge-case coverage for JsonParser CRUD, parsing, and formatting.
//

import Foundation
import Testing
@testable import wina

private func canonicalJSON(_ json: String) -> String? {
    guard let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
          let normalized = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
        return nil
    }
    return String(data: normalized, encoding: .utf8)
}

@Suite("JsonParser Validation Edge Cases")
struct JsonParserValidationEdgeCaseTests {

    private static let validJsonStrings: [String] = [
        "{}",
        "[]",
        "{\"a\":1}",
        "{\"a\":1,\"b\":2}",
        "{\"a\":{\"b\":2}}",
        "{\"array\":[1,2,3]}",
        "{\"array\":[\"a\",\"b\"]}",
        "{\"nested\":[{\"id\":1},{\"id\":2}]}",
        "{\"bool\":true}",
        "{\"null\":null}",
        "[1]",
        "[1,2,3]",
        "[true,false]",
        "[null,\"text\"]",
        "[{\"a\":1}]",
        "{\"emptyArray\":[]}",
        "{\"emptyObject\":{}}",
        "{\"text\":\"hello\"}",
        "{\"unicode\":\"Hello\"}",
        "{\"escape\":\"a\\/b\"}",
        "{\"a\":1,}",
        "[1,]",
        "{\"a\":[1,]}"
    ]

    private static let invalidJsonStrings: [String] = [
        "",
        " ",
        "\n",
        "{",
        "}",
        "[",
        "]",
        "{\"a\":}",
        "{\"a\" 1}",
        "{\"a\":1 \"b\":2}",
        "{\"a\":1,\"b\":}",
        "[,1]",
        "[1 2]",
        "{\"a\":[,1]}",
        "\"string\"",
        "123",
        "true",
        "false",
        "null",
        "not json",
        "{invalid}"
    ]

    @Test("Valid JSON strings", arguments: validJsonStrings)
    func testValidJsonStrings(_ input: String) {
        #expect(JsonParser.isValidJson(input))
    }

    @Test("Invalid JSON strings", arguments: invalidJsonStrings)
    func testInvalidJsonStrings(_ input: String) {
        #expect(!JsonParser.isValidJson(input))
    }
}

@Suite("JsonParser Parsing Edge Cases")
struct JsonParserParsingEdgeCaseTests {

    enum PrimitiveKind: String {
        case string
        case number
        case bool
        case null
    }

    private static let primitiveCases: [(String, PrimitiveKind, String)] = [
        ("\"hello\"", .string, "hello"),
        ("42", .number, "42"),
        ("3.14", .number, "3.14"),
        ("true", .bool, "true"),
        ("false", .bool, "false"),
        ("null", .null, "")
    ]

    @Test("Parse primitives", arguments: primitiveCases)
    func testParsePrimitives(_ input: String, _ kind: PrimitiveKind, _ expected: String) {
        let result = JsonParser.parse(input)
        #expect(result.isValid)
        guard let node = result.node else {
            #expect(Bool(false))
            return
        }
        switch (node.value, kind) {
        case let (.string(lhs), .string):
            #expect(lhs == expected)
        case let (.number(lhs), .number):
            guard let expectedNumber = Double(expected) else {
                #expect(Bool(false))
                return
            }
            #expect(lhs == expectedNumber)
        case let (.bool(lhs), .bool):
            #expect(lhs == (expected == "true"))
        case (.null, .null):
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
    }

    private static let emptyCases: [String] = [
        "",
        " ",
        "\n",
        "\t"
    ]

    @Test("Parse empty returns empty result", arguments: emptyCases)
    func testParseEmpty(_ input: String) {
        let result = JsonParser.parse(input)
        #expect(!result.isValid)
        #expect(result.node == nil)
        #expect(result.error == nil)
    }

    private static let invalidCases: [String] = [
        "{invalid}",
        "{\"a\":}",
        "{\"a\" 1}",
        "{\"a\":1 \"b\":2}",
        "[,1]",
        "[1 2]",
        "{\"a\":[,1]}"
    ]

    @Test("Parse invalid returns error", arguments: invalidCases)
    func testParseInvalid(_ input: String) {
        let result = JsonParser.parse(input)
        #expect(!result.isValid)
        #expect(result.node == nil)
        #expect(result.error != nil)
    }
}

@Suite("JsonParser Count Elements Edge Cases")
struct JsonParserCountElementsEdgeCaseTests {

    private static let countCases: [(String, Int)] = [
        ("{}", 0),
        ("{\"a\":1}", 1),
        ("{\"a\":1,\"b\":2}", 2),
        ("{\"a\":1,\"b\":2,\"c\":3}", 3),
        ("[]", 0),
        ("[1]", 1),
        ("[1,2,3]", 3),
        ("[{\"a\":1},{\"b\":2}]", 2),
        ("[true,false,true]", 3),
        ("\"string\"", 0),
        ("123", 0),
        ("true", 0),
        ("null", 0),
        ("not json", 0)
    ]

    @Test("Count elements", arguments: countCases)
    func testCountElements(_ input: String, _ expected: Int) {
        #expect(JsonParser.countElements(input) == expected)
    }
}

@Suite("JsonParser Formatting Edge Cases")
struct JsonParserFormattingEdgeCaseTests {

    private static let prettyPrintCases: [String] = [
        "{\"b\":2,\"a\":1}",
        "[3,2,1]",
        "{\"nested\":{\"b\":2,\"a\":1}}",
        "{\"array\":[3,2,1]}",
        "{\"text\":\"a/b\"}"
    ]

    @Test("Pretty print returns non-nil", arguments: prettyPrintCases)
    func testPrettyPrintValid(_ input: String) {
        #expect(JsonParser.prettyPrint(input) != nil)
    }

    private static let prettyPrintInvalid: [String] = [
        "{invalid}",
        "",
        " ",
        "{\"a\":}",
        "{\"a\" 1}",
        "{\"a\":1 \"b\":2}",
        "[,1]",
        "[1 2]"
    ]

    @Test("Pretty print invalid returns nil", arguments: prettyPrintInvalid)
    func testPrettyPrintInvalid(_ input: String) {
        #expect(JsonParser.prettyPrint(input) == nil)
    }

    private static let minifyCases: [(String, String)] = [
        ("{\n  \"b\": 2,\n  \"a\": 1\n}", "{\"a\":1,\"b\":2}"),
        ("[\n  3,\n  2,\n  1\n]", "[3,2,1]"),
        ("{\n  \"text\": \"a/b\"\n}", "{\"text\":\"a/b\"}")
    ]

    @Test("Minify canonicalizes", arguments: minifyCases)
    func testMinifyValid(_ input: String, _ expected: String) {
        let result = JsonParser.minify(input)
        #expect(result != nil)
        #expect(canonicalJSON(result ?? "") == canonicalJSON(expected))
    }

    private static let minifyInvalid: [String] = [
        "{invalid}",
        "",
        " ",
        "{\"a\":}",
        "{\"a\" 1}",
        "{\"a\":1 \"b\":2}",
        "[,1]",
        "[1 2]"
    ]

    @Test("Minify invalid returns nil", arguments: minifyInvalid)
    func testMinifyInvalid(_ input: String) {
        #expect(JsonParser.minify(input) == nil)
    }
}

@Suite("JsonParser CRUD Edge Cases")
struct JsonParserCrudEdgeCaseTests {

    private static let addToObjectCases: [(String, [String], String, String, String?)] = [
        ("{\"a\":1}", [], "b", "2", "{\"a\":1,\"b\":2}"),
        ("{\"a\":{\"b\":1}}", ["a"], "c", "2", "{\"a\":{\"b\":1,\"c\":2}}"),
        ("{\"items\":[{\"a\":1},{\"b\":2}]}", ["items", "[1]"], "c", "3", "{\"items\":[{\"a\":1},{\"b\":2,\"c\":3}]}"),
        ("{\"a\":1}", ["missing"], "b", "2", "{\"a\":1}"),
        ("[1,2,3]", [], "b", "2", nil)
    ]

    @Test("Add to object", arguments: addToObjectCases)
    func testAddToObject(_ input: String, _ path: [String], _ key: String, _ valueJSON: String, _ expected: String?) {
        let value = valueJSON.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed) }
        guard let value else {
            #expect(Bool(false))
            return
        }
        let result = JsonParser.addToObject(input, at: path, key: key, value: value)
        if let expected {
            #expect(canonicalJSON(result ?? "") == canonicalJSON(expected))
        } else {
            #expect(result == nil)
        }
    }

    private static let appendToArrayCases: [(String, [String], String, String?)] = [
        ("[1,2]", [], "3", "[1,2,3]"),
        ("{\"items\":[1,2]}", ["items"], "3", "{\"items\":[1,2,3]}"),
        ("[[1],[2]]", ["[0]"], "3", "[[1,3],[2]]"),
        ("{\"a\":1}", [], "3", nil)
    ]

    @Test("Append to array", arguments: appendToArrayCases)
    func testAppendToArray(_ input: String, _ path: [String], _ valueJSON: String, _ expected: String?) {
        let value = valueJSON.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed) }
        guard let value else {
            #expect(Bool(false))
            return
        }
        let result = JsonParser.appendToArray(input, at: path, value: value)
        if let expected {
            #expect(canonicalJSON(result ?? "") == canonicalJSON(expected))
        } else {
            #expect(result == nil)
        }
    }

    private static let deleteCases: [(String, [String], String?)] = [
        ("{\"a\":1,\"b\":2}", ["a"], "{\"b\":2}"),
        ("[1,2,3]", ["[1]"], "[1,3]"),
        ("{\"a\":{\"b\":1,\"c\":2}}", ["a", "b"], "{\"a\":{\"c\":2}}"),
        ("{\"a\":1}", ["missing"], "{\"a\":1}")
    ]

    @Test("Delete at path", arguments: deleteCases)
    func testDelete(_ input: String, _ path: [String], _ expected: String?) {
        let result = JsonParser.delete(input, at: path)
        if let expected {
            #expect(canonicalJSON(result ?? "") == canonicalJSON(expected))
        } else {
            #expect(result == nil)
        }
    }

    private static let updateCases: [(String, [String], String, String?)] = [
        ("{\"a\":1}", ["a"], "2", "{\"a\":2}"),
        ("{\"a\":{\"b\":1}}", ["a", "b"], "2", "{\"a\":{\"b\":2}}"),
        ("[1,2,3]", ["[0]"], "9", "[9,2,3]"),
        ("{\"items\":[1,2]}", ["items", "[1]"], "9", "{\"items\":[1,9]}"),
        ("{\"a\":1}", ["missing"], "2", "{\"a\":1,\"missing\":2}"),
        ("[1,2,3]", ["[9]"], "9", "[1,2,3]"),
        ("{\"a\":1}", [], "{\"b\":2}", "{\"b\":2}")
    ]

    @Test("Update at path", arguments: updateCases)
    func testUpdate(_ input: String, _ path: [String], _ valueJSON: String, _ expected: String?) {
        let value = valueJSON.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed) }
        guard let value else {
            #expect(Bool(false))
            return
        }
        let result = JsonParser.update(input, at: path, value: value)
        if let expected {
            #expect(canonicalJSON(result ?? "") == canonicalJSON(expected))
        } else {
            #expect(result == nil)
        }
    }

    private static let deleteRootCases: [String] = [
        "{\"a\":1}",
        "[1,2,3]"
    ]

    @Test("Delete root returns nil", arguments: deleteRootCases)
    func testDeleteRoot(_ input: String) {
        #expect(JsonParser.delete(input, at: []) == nil)
    }
}

@Suite("JsonTemplate Edge Cases")
struct JsonTemplateEdgeCaseTests {

    @Test("JsonTemplate content is non-empty")
    func testTemplateContent() {
        for template in JsonTemplate.allCases {
            #expect(!template.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test("JsonTemplate icon values")
    func testTemplateIcon() {
        for template in JsonTemplate.allCases {
            #expect(!template.icon.isEmpty)
        }
    }
}
