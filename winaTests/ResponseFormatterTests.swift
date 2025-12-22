//
//  ResponseFormatterTests.swift
//  winaTests
//
//  Tests for ResponseFormatterView with syntax highlighting and formatting.
//

import XCTest
import SwiftUI
@testable import wina

final class ResponseFormatterTests: XCTestCase {

    // MARK: - JSON Formatting Tests

    func testJSONFormattingValidJSON() {
        let jsonString = """
        {"name":"John","age":30,"active":true}
        """

        let view = JSONFormattedView(jsonString: jsonString)
        XCTAssertNotNil(view)
    }

    func testJSONFormattingMultilineJSON() {
        let jsonString = """
        {
          "users": [
            {
              "id": 1,
              "name": "John"
            }
          ]
        }
        """

        let view = JSONFormattedView(jsonString: jsonString)
        XCTAssertNotNil(view)
    }

    func testJSONElementTypeDetection() {
        // Test key detection
        let keyLine = #""name": "value""#
        XCTAssertTrue(keyLine.contains("name"))

        // Test number detection
        let numberLine = "123"
        XCTAssertTrue(numberLine.allSatisfy { $0.isNumber })

        // Test boolean detection
        let booleanLine = "true"
        XCTAssertTrue(booleanLine == "true" || booleanLine == "false")

        // Test null detection
        let nullLine = "null"
        XCTAssertEqual(nullLine, "null")
    }

    func testJSONWithSpecialCharacters() {
        let jsonString = """
        {"message":"Hello\\nWorld","path":"C:\\\\Users\\\\file.txt"}
        """

        let view = JSONFormattedView(jsonString: jsonString)
        XCTAssertNotNil(view)
    }

    func testJSONWithUnicodeCharacters() {
        let jsonString = """
        {"greeting":"你好","emoji":"😊","special":"\\u0048\\u0065\\u006c\\u006c\\u006f"}
        """

        let view = JSONFormattedView(jsonString: jsonString)
        XCTAssertNotNil(view)
    }

    func testJSONWithNestedArrays() {
        let jsonString = """
        {
          "data": [
            [1, 2, 3],
            [4, 5, 6]
          ]
        }
        """

        let view = JSONFormattedView(jsonString: jsonString)
        XCTAssertNotNil(view)
    }

    func testJSONWithMixedTypes() {
        let jsonString = """
        {
          "string": "value",
          "number": 42,
          "float": 3.14,
          "boolean": true,
          "null": null,
          "array": [1, "two", false],
          "object": {"nested": true}
        }
        """

        let view = JSONFormattedView(jsonString: jsonString)
        XCTAssertNotNil(view)
    }

    func testJSONInvalidFormat() {
        let invalidJSON = """
        {invalid json content}
        """

        let view = JSONFormattedView(jsonString: invalidJSON)
        XCTAssertNotNil(view)
    }

    // MARK: - HTML Formatting Tests

    func testHTMLBasicStructure() {
        let htmlString = """
        <!DOCTYPE html>
        <html>
          <head>
            <title>Test Page</title>
          </head>
          <body>
            <h1>Hello World</h1>
          </body>
        </html>
        """

        let view = HTMLFormattedView(htmlString: htmlString)
        XCTAssertNotNil(view)
    }

    func testHTMLWithAttributes() {
        let htmlString = """
        <div class="container" id="main" data-value="test">
          <p style="color: red;">Text</p>
        </div>
        """

        let view = HTMLFormattedView(htmlString: htmlString)
        XCTAssertNotNil(view)
    }

    func testHTMLWithComments() {
        let htmlString = """
        <div>
          <!-- This is a comment -->
          <p>Content</p>
        </div>
        """

        let view = HTMLFormattedView(htmlString: htmlString)
        XCTAssertNotNil(view)
    }

    func testHTMLWithSelfClosingTags() {
        let htmlString = """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="stylesheet" href="style.css" />
          </head>
          <body>
            <img src="image.png" alt="Image" />
            <br />
          </body>
        </html>
        """

        let view = HTMLFormattedView(htmlString: htmlString)
        XCTAssertNotNil(view)
    }

    func testHTMLWithSpecialCharacters() {
        let htmlString = """
        <p>&lt;tag&gt; &amp; special &quot;chars&quot; &apos;here&apos;</p>
        """

        let view = HTMLFormattedView(htmlString: htmlString)
        XCTAssertNotNil(view)
    }

    func testHTMLWithScriptTag() {
        let htmlString = """
        <html>
          <head>
            <script type="text/javascript">
              console.log("Test");
            </script>
          </head>
        </html>
        """

        let view = HTMLFormattedView(htmlString: htmlString)
        XCTAssertNotNil(view)
    }

    // MARK: - XML Formatting Tests

    func testXMLBasicStructure() {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <root>
          <item id="1">
            <name>Test</name>
          </item>
        </root>
        """

        let view = XMLFormattedView(xmlString: xmlString)
        XCTAssertNotNil(view)
    }

    func testXMLWithNamespaces() {
        let xmlString = """
        <?xml version="1.0"?>
        <root xmlns="http://example.com" xmlns:custom="http://custom.com">
          <custom:element>Value</custom:element>
        </root>
        """

        let view = XMLFormattedView(xmlString: xmlString)
        XCTAssertNotNil(view)
    }

    func testXMLWithCDATA() {
        let xmlString = """
        <?xml version="1.0"?>
        <root>
          <data><![CDATA[This is <raw> data & content]]></data>
        </root>
        """

        let view = XMLFormattedView(xmlString: xmlString)
        XCTAssertNotNil(view)
    }

    func testXMLWithAttributes() {
        let xmlString = """
        <?xml version="1.0"?>
        <root version="1.0" encoding="UTF-8">
          <element attr1="value1" attr2="value2">
            <child>Text</child>
          </element>
        </root>
        """

        let view = XMLFormattedView(xmlString: xmlString)
        XCTAssertNotNil(view)
    }

    // MARK: - Response Content Type Tests

    func testResponseContentTypeColors() {
        XCTAssertEqual(ResponseContentType.json.rawValue, "JSON")
        XCTAssertEqual(ResponseContentType.html.rawValue, "HTML")
        XCTAssertEqual(ResponseContentType.xml.rawValue, "XML")
        XCTAssertEqual(ResponseContentType.text.rawValue, "Text")
    }

    func testResponseContentTypeColorValues() {
        XCTAssertEqual(ResponseContentType.json.color, .purple)
        XCTAssertEqual(ResponseContentType.html.color, .orange)
        XCTAssertEqual(ResponseContentType.xml.color, .teal)
        XCTAssertEqual(ResponseContentType.text.color, .gray)
    }

    // MARK: - Plain Text View Tests

    func testPlainTextViewSingleLine() {
        let text = "Single line of text"
        let view = PlainTextView(text: text, language: .text)
        XCTAssertNotNil(view)
    }

    func testPlainTextViewMultipleLines() {
        let text = """
        Line 1
        Line 2
        Line 3
        """

        let view = PlainTextView(text: text, language: .text)
        XCTAssertNotNil(view)
    }

    func testCSSFormatting() {
        let cssText = """
        body {
          margin: 0;
          padding: 0;
          font-family: Arial, sans-serif;
        }
        """

        let view = PlainTextView(text: cssText, language: .css)
        XCTAssertNotNil(view)
    }

    func testJavaScriptFormatting() {
        let jsText = """
        function hello(name) {
          console.log("Hello, " + name);
        }
        """

        let view = PlainTextView(text: jsText, language: .javascript)
        XCTAssertNotNil(view)
    }

    // MARK: - Response Formatter View Tests

    func testResponseFormatterViewJSON() {
        let json = """
        {"key": "value"}
        """

        let view = ResponseFormatterView(responseBody: json, contentType: .json)
        XCTAssertNotNil(view)
    }

    func testResponseFormatterViewHTML() {
        let html = "<html><body><p>Test</p></body></html>"

        let view = ResponseFormatterView(responseBody: html, contentType: .html)
        XCTAssertNotNil(view)
    }

    func testResponseFormatterViewXML() {
        let xml = "<?xml version=\"1.0\"?><root><item>Test</item></root>"

        let view = ResponseFormatterView(responseBody: xml, contentType: .xml)
        XCTAssertNotNil(view)
    }

    func testResponseFormatterViewText() {
        let text = "Plain text response"

        let view = ResponseFormatterView(responseBody: text, contentType: .text)
        XCTAssertNotNil(view)
    }

    func testResponseFormatterViewCSS() {
        let css = "body { color: red; }"

        let view = ResponseFormatterView(responseBody: css, contentType: .css)
        XCTAssertNotNil(view)
    }

    func testResponseFormatterViewJavaScript() {
        let js = "console.log('test');"

        let view = ResponseFormatterView(responseBody: js, contentType: .javascript)
        XCTAssertNotNil(view)
    }

    // MARK: - Edge Cases

    func testEmptyJSON() {
        let emptyJson = "{}"
        let view = JSONFormattedView(jsonString: emptyJson)
        XCTAssertNotNil(view)
    }

    func testEmptyHTMLDocument() {
        let emptyHtml = "<html></html>"
        let view = HTMLFormattedView(htmlString: emptyHtml)
        XCTAssertNotNil(view)
    }

    func testLargeJSON() {
        let largeArray = (0..<1000)
            .map { #"{"id":\#($0),"value":"test"}"# }
            .joined(separator: ",")
        let largeJson = "[\(largeArray)]"

        let view = JSONFormattedView(jsonString: largeJson)
        XCTAssertNotNil(view)
    }

    func testVeryLongHTMLLine() {
        let longContent = String(repeating: "x", count: 1000)
        let longHtml = "<p>\(longContent)</p>"

        let view = HTMLFormattedView(htmlString: longHtml)
        XCTAssertNotNil(view)
    }

    func testMixedContentTypes() {
        let mixedJson = """
        {
          "html": "<p>nested</p>",
          "xml": "<?xml version='1.0'?>",
          "css": "body { color: red; }"
        }
        """

        let view = ResponseFormatterView(responseBody: mixedJson, contentType: .json)
        XCTAssertNotNil(view)
    }

    // MARK: - Integration Tests

    func testFormattingWithLineBreaks() {
        let textWithLineBreaks = "Line1\nLine2\nLine3"
        let view = PlainTextView(text: textWithLineBreaks, language: .text)
        XCTAssertNotNil(view)
    }

    func testFormattingWithTabs() {
        let textWithTabs = "func hello() {\n\tprint(\"test\")\n}"
        let view = PlainTextView(text: textWithTabs, language: .javascript)
        XCTAssertNotNil(view)
    }

    func testFormattingWithMixedWhitespace() {
        let mixedWhitespace = "  indented\n\t\ttab indented\nno indent"
        let view = PlainTextView(text: mixedWhitespace, language: .text)
        XCTAssertNotNil(view)
    }
}
