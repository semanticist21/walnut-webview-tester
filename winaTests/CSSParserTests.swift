import XCTest
import SwiftUI
@testable import wina

final class CSSParserTests: XCTestCase {
    
    // MARK: - Color Parsing Tests
    
    func testParseHexColor3Digit() {
        let styles = CSSParser.parse("color: #F00;")
        XCTAssertNotNil(styles.color)
        // Red color should be close to (1, 0, 0)
        XCTAssertEqual(styles.color, Color(red: 1, green: 0, blue: 0))
    }
    
    func testParseHexColor6Digit() {
        let styles = CSSParser.parse("color: #FF0000;")
        XCTAssertNotNil(styles.color)
        XCTAssertEqual(styles.color, Color(red: 1, green: 0, blue: 0))
    }
    
    func testParseRgbColor() {
        let styles = CSSParser.parse("color: rgb(255, 128, 0);")
        XCTAssertNotNil(styles.color)
        // RGB values should be normalized (0-1)
    }
    
    func testParseRgbaColor() {
        let styles = CSSParser.parse("color: rgba(255, 0, 0, 0.5);")
        XCTAssertNotNil(styles.color)
    }
    
    func testParseNamedColor() {
        let styles = CSSParser.parse("color: red;")
        XCTAssertEqual(styles.color, Color.red)
    }
    
    func testParseNamedColorGreen() {
        let styles = CSSParser.parse("color: green;")
        XCTAssertEqual(styles.color, Color.green)
    }
    
    func testParseNamedColorBlue() {
        let styles = CSSParser.parse("color: blue;")
        XCTAssertEqual(styles.color, Color.blue)
    }
    
    func testParseBackgroundColor() {
        let styles = CSSParser.parse("background-color: #00FF00;")
        XCTAssertNotNil(styles.backgroundColor)
    }
    
    func testParseTransparentColor() {
        let styles = CSSParser.parse("color: transparent;")
        XCTAssertEqual(styles.color, Color.clear)
    }
    
    // MARK: - Font Size Tests
    
    func testParseFontSizeWithPx() {
        let styles = CSSParser.parse("font-size: 16px;")
        XCTAssertEqual(styles.fontSize, 16)
    }
    
    func testParseFontSizeWithEm() {
        let styles = CSSParser.parse("font-size: 1.5em;")
        XCTAssertEqual(styles.fontSize, 1.5)
    }
    
    func testParseFontSizeDefault() {
        let styles = CSSParser.parse("font-size: invalid;")
        XCTAssertEqual(styles.fontSize, 14.0)  // Default
    }
    
    // MARK: - Font Weight Tests
    
    func testParseFontWeightBold() {
        let styles = CSSParser.parse("font-weight: bold;")
        XCTAssertEqual(styles.fontWeight, .bold)
        XCTAssertTrue(styles.isBold)
    }
    
    func testParseFontWeight700() {
        let styles = CSSParser.parse("font-weight: 700;")
        XCTAssertEqual(styles.fontWeight, .bold)
    }
    
    func testParseFontWeightLight() {
        let styles = CSSParser.parse("font-weight: 300;")
        XCTAssertEqual(styles.fontWeight, .light)
    }
    
    func testParseFontWeightNormal() {
        let styles = CSSParser.parse("font-weight: normal;")
        XCTAssertEqual(styles.fontWeight, .regular)
    }
    
    // MARK: - Font Style Tests
    
    func testParseFontStyleItalic() {
        let styles = CSSParser.parse("font-style: italic;")
        XCTAssertTrue(styles.isItalic)
    }
    
    func testParseFontFamily() {
        let styles = CSSParser.parse("font-family: monospace;")
        XCTAssertEqual(styles.fontStyle, .monospaced)
    }
    
    // MARK: - Font Shorthand Tests
    
    func testParseFontShorthand() {
        let styles = CSSParser.parse("font: bold 16px Arial;")
        XCTAssertTrue(styles.isBold)
        XCTAssertEqual(styles.fontSize, 16)
    }
    
    func testParseFontShorthandItalic() {
        let styles = CSSParser.parse("font: italic 14px serif;")
        XCTAssertTrue(styles.isItalic)
        XCTAssertEqual(styles.fontSize, 14)
    }
    
    // MARK: - Opacity Tests
    
    func testParseOpacityDecimal() {
        let styles = CSSParser.parse("opacity: 0.5;")
        XCTAssertEqual(styles.opacity, 0.5)
    }
    
    func testParseOpacityPercent() {
        let styles = CSSParser.parse("opacity: 50%;")
        XCTAssertEqual(styles.opacity, 0.5)
    }
    
    func testParseOpacityDefault() {
        let styles = CSSParser.parse("opacity: invalid;")
        XCTAssertEqual(styles.opacity, 1.0)  // Default fully opaque
    }
    
    // MARK: - Padding Tests
    
    func testParsePaddingSingleValue() {
        let styles = CSSParser.parse("padding: 10px;")
        XCTAssertNotNil(styles.padding)
        XCTAssertEqual(styles.padding?.top, 10)
        XCTAssertEqual(styles.padding?.leading, 10)
    }
    
    func testParsePaddingTwoValues() {
        let styles = CSSParser.parse("padding: 10px 20px;")
        XCTAssertNotNil(styles.padding)
        XCTAssertEqual(styles.padding?.top, 10)
        XCTAssertEqual(styles.padding?.leading, 20)
    }
    
    // MARK: - Multiple Properties Tests
    
    func testParseMultipleProperties() {
        let styles = CSSParser.parse("color: red; font-size: 16px; font-weight: bold;")
        XCTAssertEqual(styles.color, Color.red)
        XCTAssertEqual(styles.fontSize, 16)
        XCTAssertTrue(styles.isBold)
    }
    
    func testParseColorAndBackground() {
        let styles = CSSParser.parse("color: white; background-color: #000000;")
        XCTAssertEqual(styles.color, Color.white)
        XCTAssertNotNil(styles.backgroundColor)
    }
    
    func testParseComplexStyle() {
        let styles = CSSParser.parse("color: #FF5733; font-size: 18px; font-weight: bold; opacity: 0.9;")
        XCTAssertNotNil(styles.color)
        XCTAssertEqual(styles.fontSize, 18)
        XCTAssertTrue(styles.isBold)
        XCTAssertEqual(styles.opacity, 0.9)
    }
    
    // MARK: - Edge Cases Tests
    
    func testParseEmptyString() {
        let styles = CSSParser.parse("")
        XCTAssertNil(styles.color)
        XCTAssertNil(styles.fontSize)
    }
    
    func testParseWithExtraWhitespace() {
        let styles = CSSParser.parse("  color :  red  ;  font-size :  16px  ;  ")
        XCTAssertEqual(styles.color, Color.red)
        XCTAssertEqual(styles.fontSize, 16)
    }
    
    func testParseInvalidProperty() {
        let styles = CSSParser.parse("invalid-property: invalid-value;")
        XCTAssertNil(styles.color)
        XCTAssertNil(styles.fontSize)
    }
    
    func testParseWithoutSemicolon() {
        let styles = CSSParser.parse("color: red")
        XCTAssertEqual(styles.color, Color.red)
    }
    
    func testParseWebColors() {
        let webColors = [
            ("lime", Color(red: 0, green: 1, blue: 0)),
            ("navy", Color(red: 0, green: 0, blue: 0.5)),
            ("teal", Color(red: 0, green: 0.5, blue: 0.5)),
        ]
        
        for (colorName, expectedColor) in webColors {
            let styles = CSSParser.parse("color: \(colorName);")
            XCTAssertEqual(styles.color, expectedColor, "Failed for color: \(colorName)")
        }
    }
    
    // MARK: - Font Property Tests
    
    func testFontGeneration() {
        let styles = CSSParser.parse("font-size: 16px; font-weight: bold;")
        XCTAssertNotNil(styles.font)
    }
    
    func testFontWithMonospaced() {
        let styles = CSSParser.parse("font-family: monospace; font-size: 14px;")
        XCTAssertEqual(styles.fontStyle, .monospaced)
        XCTAssertEqual(styles.fontSize, 14)
    }
    
    // MARK: - Case Insensitivity Tests
    
    func testParseColorCaseInsensitive() {
        let styles1 = CSSParser.parse("color: RED;")
        let styles2 = CSSParser.parse("color: Red;")
        let styles3 = CSSParser.parse("color: red;")
        
        XCTAssertEqual(styles1.color, styles2.color)
        XCTAssertEqual(styles2.color, styles3.color)
        XCTAssertEqual(styles1.color, Color.red)
    }
    
    func testParseFontWeightCaseInsensitive() {
        let styles1 = CSSParser.parse("font-weight: BOLD;")
        let styles2 = CSSParser.parse("font-weight: Bold;")
        let styles3 = CSSParser.parse("font-weight: bold;")
        
        XCTAssertEqual(styles1.fontWeight, styles2.fontWeight)
        XCTAssertEqual(styles2.fontWeight, styles3.fontWeight)
        XCTAssertTrue(styles1.isBold)
    }
    
    // MARK: - Real Console Use Cases
    
    func testConsoleStyleWarning() {
        // Typical console.warn() style
        let styles = CSSParser.parse("color: orange; font-weight: bold;")
        XCTAssertEqual(styles.color, Color.orange)
        XCTAssertTrue(styles.isBold)
    }
    
    func testConsoleStyleError() {
        // Typical console.error() style
        let styles = CSSParser.parse("color: red; font-weight: bold; background-color: #ffebee;")
        XCTAssertEqual(styles.color, Color.red)
        XCTAssertTrue(styles.isBold)
        XCTAssertNotNil(styles.backgroundColor)
    }
    
    func testConsoleStyleSuccess() {
        // Typical console.log success style
        let styles = CSSParser.parse("color: green; font-weight: bold; font-size: 14px;")
        XCTAssertEqual(styles.color, Color.green)
        XCTAssertTrue(styles.isBold)
        XCTAssertEqual(styles.fontSize, 14)
    }
    
    func testConsoleStyleInfo() {
        // Typical console.info() style
        let styles = CSSParser.parse("color: blue; font-style: italic;")
        XCTAssertEqual(styles.color, Color.blue)
        XCTAssertTrue(styles.isItalic)
    }
}
