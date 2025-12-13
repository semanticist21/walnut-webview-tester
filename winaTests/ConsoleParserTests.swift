//
//  ConsoleParserTests.swift
//  winaTests
//
//  Tests for ConsoleParser: JSONParser, RegexFilter, ConsoleExporter
//

import XCTest
@testable import wina

// MARK: - JSONParser Tests

final class JSONParserTests: XCTestCase {

    // MARK: - parse() Tests

    func testParseValidObject() {
        let json = #"{"name": "test", "value": 123}"#
        let result = JSONParser.parse(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.original, json)
        XCTAssertTrue(result?.formatted.contains("\"name\"") ?? false)
        XCTAssertTrue(result?.minified.contains("name") ?? false)
    }

    func testParseValidArray() {
        let json = "[1, 2, 3]"
        let result = JSONParser.parse(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.original, json)
    }

    func testParseNestedObject() {
        let json = #"{"outer": {"inner": {"deep": true}}}"#
        let result = JSONParser.parse(json)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.formatted.contains("deep") ?? false)
    }

    func testParseInvalidJSON() {
        let invalid = "not json at all"
        let result = JSONParser.parse(invalid)

        XCTAssertNil(result)
    }

    func testParseEmptyString() {
        let result = JSONParser.parse("")
        XCTAssertNil(result)
    }

    func testParseMalformedJSON() {
        let malformed = #"{"key": value}"#  // Missing quotes around value
        let result = JSONParser.parse(malformed)

        XCTAssertNil(result)
    }

    func testParseUnclosedBrace() {
        let unclosed = #"{"key": "value""#
        let result = JSONParser.parse(unclosed)

        XCTAssertNil(result)
    }

    func testParseUnclosedBracket() {
        let unclosed = "[1, 2, 3"
        let result = JSONParser.parse(unclosed)

        XCTAssertNil(result)
    }

    func testParseTrailingComma() {
        // Note: Foundation's JSONSerialization on iOS 15+ accepts trailing commas (JSON5-like)
        // This tests that our parser handles it consistently with the system
        let trailing = #"{"key": "value",}"#
        let result = JSONParser.parse(trailing)

        // Foundation accepts this, so we do too
        XCTAssertNotNil(result)
    }

    func testParseSpecialCharacters() {
        let special = #"{"emoji": "🚀", "unicode": "\u0048\u0065\u006C\u006C\u006F"}"#
        let result = JSONParser.parse(special)

        XCTAssertNotNil(result)
    }

    func testParseEscapedQuotes() {
        let escaped = #"{"message": "He said \"hello\""}"#
        let result = JSONParser.parse(escaped)

        XCTAssertNotNil(result)
    }

    func testParseNullValue() {
        let json = #"{"value": null}"#
        let result = JSONParser.parse(json)

        XCTAssertNotNil(result)
    }

    func testParseBooleanValues() {
        let json = #"{"active": true, "deleted": false}"#
        let result = JSONParser.parse(json)

        XCTAssertNotNil(result)
    }

    func testParseNumberFormats() {
        let json = #"{"int": 42, "float": 3.14, "negative": -10, "exp": 1.5e10}"#
        let result = JSONParser.parse(json)

        XCTAssertNotNil(result)
    }

    // MARK: - extract() Tests

    func testExtractPureJSON() {
        let message = #"{"status": "ok"}"#
        let result = JSONParser.extract(from: message)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.original, message)
    }

    func testExtractJSONWithWhitespace() {
        let message = "   {\"status\": \"ok\"}   "
        let result = JSONParser.extract(from: message)

        XCTAssertNotNil(result)
    }

    func testExtractJSONFromMixedText() {
        let message = "Response: {\"status\": \"ok\"} received"
        let result = JSONParser.extract(from: message)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.formatted.contains("status") ?? false)
    }

    func testExtractArrayFromText() {
        let message = "Data: [1, 2, 3] items"
        let result = JSONParser.extract(from: message)

        XCTAssertNotNil(result)
    }

    func testExtractNoJSON() {
        let message = "Just a plain text message without any JSON"
        let result = JSONParser.extract(from: message)

        XCTAssertNil(result)
    }

    func testExtractNestedJSONFromText() {
        let message = #"Got {"outer": {"inner": "value"}} back"#
        let result = JSONParser.extract(from: message)

        XCTAssertNotNil(result)
    }

    func testExtractBracesNotJSON() {
        let message = "Use {curly} braces for templates"
        let result = JSONParser.extract(from: message)

        XCTAssertNil(result)  // {curly} is not valid JSON
    }

    // MARK: - parseTableData() Tests

    func testParseTableDataValid() {
        let json = #"[{"name": "Alice", "age": "30"}, {"name": "Bob", "age": "25"}]"#
        let result = JSONParser.parseTableData(from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0]["name"], "Alice")
        XCTAssertEqual(result?[1]["age"], "25")
    }

    func testParseTableDataEmptyArray() {
        let json = "[]"
        let result = JSONParser.parseTableData(from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }

    func testParseTableDataInvalidFormat() {
        let json = #"{"not": "an array"}"#
        let result = JSONParser.parseTableData(from: json)

        XCTAssertNil(result)
    }

    func testParseTableDataNotJSON() {
        let result = JSONParser.parseTableData(from: "not json")
        XCTAssertNil(result)
    }

    func testParseTableDataConvertsTypes() {
        let json = #"[{"string": "text", "number": 123, "bool": true, "null": null}]"#
        let result = JSONParser.parseTableData(from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?[0]["string"], "text")
        XCTAssertEqual(result?[0]["number"], "123")
        XCTAssertEqual(result?[0]["bool"], "1")  // true becomes 1 in String(describing:)
    }
}

// MARK: - RegexFilter Tests

final class RegexFilterTests: XCTestCase {

    // MARK: - compile() Tests

    func testCompileValidPattern() {
        let result = RegexFilter.compile("test.*pattern")

        if case .success(let regex) = result {
            XCTAssertNotNil(regex)
        } else {
            XCTFail("Expected success")
        }
    }

    func testCompileInvalidPattern() {
        let result = RegexFilter.compile("[invalid")  // Unclosed bracket

        if case .invalidPattern(let error) = result {
            XCTAssertFalse(error.isEmpty)
        } else {
            XCTFail("Expected invalidPattern")
        }
    }

    func testCompileEmptyPattern() {
        // Empty pattern behavior depends on NSRegularExpression implementation
        // Just verify it doesn't crash and returns a consistent result
        let result = RegexFilter.compile("")

        switch result {
        case .success(let regex):
            // If it succeeds, empty pattern matches everything
            XCTAssertTrue(RegexFilter.matches("any text", regex: regex))
        case .invalidPattern:
            // Some implementations reject empty patterns
            XCTAssertTrue(true)
        }
    }

    // MARK: - matches() Tests

    func testMatchesSimplePattern() {
        XCTAssertTrue(RegexFilter.matches("hello world", pattern: "world"))
        XCTAssertFalse(RegexFilter.matches("hello world", pattern: "foo"))
    }

    func testMatchesCaseInsensitive() {
        XCTAssertTrue(RegexFilter.matches("Hello World", pattern: "hello"))
        XCTAssertTrue(RegexFilter.matches("HELLO", pattern: "hello"))
    }

    func testMatchesRegexPattern() {
        XCTAssertTrue(RegexFilter.matches("error123", pattern: "error\\d+"))
        XCTAssertFalse(RegexFilter.matches("errorABC", pattern: "error\\d+"))
    }

    func testMatchesStartAnchor() {
        XCTAssertTrue(RegexFilter.matches("hello world", pattern: "^hello"))
        XCTAssertFalse(RegexFilter.matches("say hello", pattern: "^hello"))
    }

    func testMatchesEndAnchor() {
        XCTAssertTrue(RegexFilter.matches("hello world", pattern: "world$"))
        XCTAssertFalse(RegexFilter.matches("world hello", pattern: "world$"))
    }

    func testMatchesInvalidPatternReturnsFalse() {
        XCTAssertFalse(RegexFilter.matches("any text", pattern: "[invalid"))
    }

    func testMatchesSpecialCharacters() {
        XCTAssertTrue(RegexFilter.matches("file.txt", pattern: "file\\.txt"))
        XCTAssertTrue(RegexFilter.matches("a+b=c", pattern: "a\\+b"))
    }

    func testMatchesWithCompiledRegex() {
        guard case .success(let regex) = RegexFilter.compile("error") else {
            XCTFail("Should compile")
            return
        }

        XCTAssertTrue(RegexFilter.matches("Found error in line 5", regex: regex))
        XCTAssertFalse(RegexFilter.matches("All good", regex: regex))
    }

    // MARK: - matchesLog() Tests

    func testMatchesLogInMessage() {
        guard case .success(let regex) = RegexFilter.compile("error") else {
            XCTFail("Should compile")
            return
        }

        XCTAssertTrue(RegexFilter.matchesLog(message: "An error occurred", source: nil, regex: regex))
    }

    func testMatchesLogInSource() {
        guard case .success(let regex) = RegexFilter.compile("main\\.js") else {
            XCTFail("Should compile")
            return
        }

        XCTAssertTrue(RegexFilter.matchesLog(message: "Some message", source: "main.js:45", regex: regex))
    }

    func testMatchesLogNeitherMatch() {
        guard case .success(let regex) = RegexFilter.compile("notfound") else {
            XCTFail("Should compile")
            return
        }

        XCTAssertFalse(RegexFilter.matchesLog(message: "Some message", source: "app.js:10", regex: regex))
    }

    func testMatchesLogNilSource() {
        guard case .success(let regex) = RegexFilter.compile("message") else {
            XCTFail("Should compile")
            return
        }

        XCTAssertTrue(RegexFilter.matchesLog(message: "A message here", source: nil, regex: regex))
        XCTAssertFalse(RegexFilter.matchesLog(message: "Nothing", source: nil, regex: regex))
    }
}

// MARK: - ConsoleExporter Tests

final class ConsoleExporterTests: XCTestCase {

    func createTestLog(type: ConsoleLog.LogType, message: String, source: String? = nil) -> ConsoleLog {
        ConsoleLog(type: type, message: message, source: source, timestamp: Date())
    }

    // MARK: - exportAsText() Tests

    func testExportAsTextEmpty() {
        let result = ConsoleExporter.exportAsText([])
        XCTAssertEqual(result, "")
    }

    func testExportAsTextSingleLog() {
        let log = createTestLog(type: .log, message: "Test message")
        let result = ConsoleExporter.exportAsText([log])

        XCTAssertTrue(result.contains("[LOG]"))
        XCTAssertTrue(result.contains("Test message"))
    }

    func testExportAsTextWithSource() {
        let log = createTestLog(type: .error, message: "Error occurred", source: "app.js:42")
        let result = ConsoleExporter.exportAsText([log])

        XCTAssertTrue(result.contains("[ERROR]"))
        XCTAssertTrue(result.contains("(app.js:42)"))
    }

    func testExportAsTextMultipleLogs() {
        let logs = [
            createTestLog(type: .log, message: "First"),
            createTestLog(type: .warn, message: "Second"),
            createTestLog(type: .error, message: "Third")
        ]
        let result = ConsoleExporter.exportAsText(logs)

        XCTAssertTrue(result.contains("First"))
        XCTAssertTrue(result.contains("Second"))
        XCTAssertTrue(result.contains("Third"))
        XCTAssertEqual(result.components(separatedBy: "\n").count, 3)
    }

    func testExportAsTextDateFormat() {
        let log = createTestLog(type: .info, message: "Info")
        let result = ConsoleExporter.exportAsText([log])

        // Check date format: [YYYY-MM-DD HH:mm:ss.SSS]
        let datePattern = "\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d{3}\\]"
        XCTAssertTrue(result.range(of: datePattern, options: .regularExpression) != nil)
    }

    // MARK: - exportAsJSON() Tests

    func testExportAsJSONEmpty() {
        let result = ConsoleExporter.exportAsJSON([])
        XCTAssertEqual(result, "[\n\n]")
    }

    func testExportAsJSONSingleLog() {
        let log = createTestLog(type: .log, message: "Test")
        let result = ConsoleExporter.exportAsJSON([log])

        XCTAssertTrue(result.contains("\"type\" : \"log\""))
        XCTAssertTrue(result.contains("\"message\" : \"Test\""))
        XCTAssertTrue(result.contains("\"timestamp\""))
    }

    func testExportAsJSONWithSource() {
        let log = createTestLog(type: .warn, message: "Warning", source: "file.js:10")
        let result = ConsoleExporter.exportAsJSON([log])

        XCTAssertTrue(result.contains("\"source\" : \"file.js:10\""))
    }

    func testExportAsJSONWithoutSource() {
        let log = createTestLog(type: .debug, message: "Debug", source: nil)
        let result = ConsoleExporter.exportAsJSON([log])

        // Should not contain source key at all
        XCTAssertFalse(result.contains("\"source\""))
    }

    func testExportAsJSONIsValidJSON() {
        let logs = [
            createTestLog(type: .log, message: "One"),
            createTestLog(type: .error, message: "Two")
        ]
        let result = ConsoleExporter.exportAsJSON(logs)

        // Parse it back to verify it's valid JSON
        let data = result.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)

        XCTAssertNotNil(parsed)
        XCTAssertTrue(parsed is [[String: Any]])
    }

    func testExportAsJSONEscapesSpecialChars() {
        let log = createTestLog(type: .log, message: "Line1\nLine2\tTabbed\"Quoted\"")
        let result = ConsoleExporter.exportAsJSON([log])

        // Should be valid JSON even with special characters
        let data = result.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed)
    }

    func testExportAsJSONTimestampFormat() {
        let log = createTestLog(type: .info, message: "Info")
        let result = ConsoleExporter.exportAsJSON([log])

        // ISO8601 format
        XCTAssertTrue(result.contains("T"))  // ISO8601 contains T separator
    }
}
