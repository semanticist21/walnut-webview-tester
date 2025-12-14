//
//  ColorExtensions.swift
//  wina
//
//  Shared color utilities for hex conversion
//

import SwiftUI

// MARK: - Color Hex Conversion

extension Color {
    /// Creates a Color from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        guard !hex.isEmpty else { return nil }
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    /// Converts Color to hex string (e.g., "#FF5733")
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - UIColor Hex Conversion

extension UIColor {
    /// Creates a UIColor from a hex string (e.g., "#FF5733" or "FF5733")
    convenience init?(hex: String) {
        guard !hex.isEmpty else { return nil }
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - CSS Color Parsing

/// Parses CSS color values (hex, rgb, rgba, hsl, hsla, named colors)
enum CSSColorParser {
    /// Attempts to parse a CSS color string and returns a SwiftUI Color
    static func parse(_ cssValue: String) -> Color? {
        let trimmed = cssValue.trimmingCharacters(in: .whitespaces).lowercased()

        // Check hex colors (#RGB, #RRGGBB, #RRGGBBAA)
        if trimmed.hasPrefix("#") {
            return parseHex(trimmed)
        }

        // Check rgb/rgba
        if trimmed.hasPrefix("rgb") {
            return parseRGB(trimmed)
        }

        // Check hsl/hsla
        if trimmed.hasPrefix("hsl") {
            return parseHSL(trimmed)
        }

        // Check named colors
        if let namedColor = namedColors[trimmed] {
            return parseHex(namedColor)
        }

        return nil
    }

    /// Checks if a CSS value contains a color
    static func containsColor(_ cssValue: String) -> Bool {
        parse(cssValue) != nil
    }

    /// Extracts all color values from a CSS property value
    static func extractColors(from cssValue: String) -> [(color: Color, range: Range<String.Index>)] {
        var results: [(Color, Range<String.Index>)] = []

        // Pattern for various color formats
        let patterns = [
            "#[0-9a-fA-F]{3,8}",
            "rgba?\\([^)]+\\)",
            "hsla?\\([^)]+\\)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsRange = NSRange(cssValue.startIndex..., in: cssValue)
                let matches = regex.matches(in: cssValue, options: [], range: nsRange)

                for match in matches {
                    if let range = Range(match.range, in: cssValue) {
                        let colorString = String(cssValue[range])
                        if let color = parse(colorString) {
                            results.append((color, range))
                        }
                    }
                }
            }
        }

        // Check for named colors (word boundaries)
        for (name, hex) in namedColors {
            if let regex = try? NSRegularExpression(
                pattern: "\\b\(name)\\b",
                options: .caseInsensitive
            ) {
                let nsRange = NSRange(cssValue.startIndex..., in: cssValue)
                let matches = regex.matches(in: cssValue, options: [], range: nsRange)

                for match in matches {
                    if let range = Range(match.range, in: cssValue),
                       let color = parseHex(hex) {
                        results.append((color, range))
                    }
                }
            }
        }

        return results
    }

    // MARK: - Private Parsers

    private static func parseHex(_ hex: String) -> Color? {
        var sanitized = hex.replacingOccurrences(of: "#", with: "")

        // Expand short hex (#RGB → #RRGGBB)
        if sanitized.count == 3 {
            sanitized = sanitized.map { "\($0)\($0)" }.joined()
        }

        // Handle 4-char hex (#RGBA → #RRGGBBAA)
        if sanitized.count == 4 {
            sanitized = sanitized.map { "\($0)\($0)" }.joined()
        }

        guard sanitized.count == 6 || sanitized.count == 8 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        if sanitized.count == 6 {
            return Color(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else {
            return Color(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        }
    }

    private static func parseRGB(_ rgb: String) -> Color? {
        // Extract numbers from rgb(r, g, b) or rgba(r, g, b, a)
        let pattern = "rgba?\\(\\s*([\\d.]+%?)\\s*[,\\s]\\s*([\\d.]+%?)\\s*[,\\s]\\s*([\\d.]+%?)\\s*(?:[,/]\\s*([\\d.]+%?))?\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(rgb.startIndex..., in: rgb)
        guard let match = regex.firstMatch(in: rgb, options: [], range: nsRange) else {
            return nil
        }

        func extractValue(_ index: Int, isAlpha: Bool = false) -> Double? {
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: rgb) else { return nil }
            let value = String(rgb[range])

            if value.hasSuffix("%") {
                let numStr = String(value.dropLast())
                guard let num = Double(numStr) else { return nil }
                return isAlpha ? num / 100.0 : (num / 100.0) * 255.0
            }
            return Double(value)
        }

        guard let r = extractValue(1),
              let g = extractValue(2),
              let b = extractValue(3) else { return nil }

        let a = extractValue(4, isAlpha: true) ?? 1.0

        return Color(
            red: min(r / 255.0, 1.0),
            green: min(g / 255.0, 1.0),
            blue: min(b / 255.0, 1.0),
            opacity: a
        )
    }

    private static func parseHSL(_ hsl: String) -> Color? {
        // Extract values from hsl(h, s%, l%) or hsla(h, s%, l%, a)
        let pattern = "hsla?\\(\\s*([\\d.]+)\\s*[,\\s]\\s*([\\d.]+)%?\\s*[,\\s]\\s*([\\d.]+)%?\\s*(?:[,/]\\s*([\\d.]+%?))?\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(hsl.startIndex..., in: hsl)
        guard let match = regex.firstMatch(in: hsl, options: [], range: nsRange) else {
            return nil
        }

        func extractDouble(_ index: Int) -> Double? {
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: hsl) else { return nil }
            var value = String(hsl[range])
            if value.hasSuffix("%") { value = String(value.dropLast()) }
            return Double(value)
        }

        guard let hue = extractDouble(1),
              let saturation = extractDouble(2),
              let lightness = extractDouble(3) else { return nil }

        var alpha = 1.0
        if match.numberOfRanges > 4,
           let range = Range(match.range(at: 4), in: hsl) {
            var value = String(hsl[range])
            if value.hasSuffix("%") {
                value = String(value.dropLast())
                alpha = (Double(value) ?? 100.0) / 100.0
            } else {
                alpha = Double(value) ?? 1.0
            }
        }

        // Convert HSL to RGB
        let (red, green, blue) = hslToRGB(
            hue: hue / 360.0,
            saturation: saturation / 100.0,
            lightness: lightness / 100.0
        )
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func hslToRGB(
        hue: Double,
        saturation: Double,
        lightness: Double
    ) -> (Double, Double, Double) {
        if saturation == 0 {
            return (lightness, lightness, lightness)
        }

        let chroma2 = lightness < 0.5
            ? lightness * (1 + saturation)
            : lightness + saturation - lightness * saturation
        let chroma1 = 2 * lightness - chroma2

        func hueToRGB(_ c1: Double, _ c2: Double, _ hueOffset: Double) -> Double {
            var adjustedHue = hueOffset
            if adjustedHue < 0 { adjustedHue += 1 }
            if adjustedHue > 1 { adjustedHue -= 1 }
            if adjustedHue < 1 / 6 { return c1 + (c2 - c1) * 6 * adjustedHue }
            if adjustedHue < 1 / 2 { return c2 }
            if adjustedHue < 2 / 3 { return c1 + (c2 - c1) * (2 / 3 - adjustedHue) * 6 }
            return c1
        }

        return (
            hueToRGB(chroma1, chroma2, hue + 1 / 3),
            hueToRGB(chroma1, chroma2, hue),
            hueToRGB(chroma1, chroma2, hue - 1 / 3)
        )
    }

    // MARK: - Named Colors (CSS Level 4)

    private static let namedColors: [String: String] = [
        "transparent": "#00000000",
        "black": "#000000",
        "white": "#ffffff",
        "red": "#ff0000",
        "green": "#008000",
        "blue": "#0000ff",
        "yellow": "#ffff00",
        "cyan": "#00ffff",
        "magenta": "#ff00ff",
        "gray": "#808080",
        "grey": "#808080",
        "silver": "#c0c0c0",
        "maroon": "#800000",
        "olive": "#808000",
        "lime": "#00ff00",
        "aqua": "#00ffff",
        "teal": "#008080",
        "navy": "#000080",
        "fuchsia": "#ff00ff",
        "purple": "#800080",
        "orange": "#ffa500",
        "pink": "#ffc0cb",
        "brown": "#a52a2a",
        "coral": "#ff7f50",
        "crimson": "#dc143c",
        "gold": "#ffd700",
        "indigo": "#4b0082",
        "ivory": "#fffff0",
        "khaki": "#f0e68c",
        "lavender": "#e6e6fa",
        "salmon": "#fa8072",
        "tomato": "#ff6347",
        "turquoise": "#40e0d0",
        "violet": "#ee82ee",
        "wheat": "#f5deb3",
        "skyblue": "#87ceeb",
        "slategray": "#708090",
        "steelblue": "#4682b4",
        "tan": "#d2b48c",
        "thistle": "#d8bfd8",
        "plum": "#dda0dd",
        "peru": "#cd853f",
        "orchid": "#da70d6",
        "mintcream": "#f5fffa",
        "linen": "#faf0e6",
        "lightgray": "#d3d3d3",
        "lightblue": "#add8e6",
        "hotpink": "#ff69b4",
        "honeydew": "#f0fff0",
        "greenyellow": "#adff2f",
        "forestgreen": "#228b22",
        "firebrick": "#b22222",
        "dodgerblue": "#1e90ff",
        "dimgray": "#696969",
        "deeppink": "#ff1493",
        "darkviolet": "#9400d3",
        "darkturquoise": "#00ced1",
        "darkslategray": "#2f4f4f",
        "darkred": "#8b0000",
        "darkorange": "#ff8c00",
        "darkolivegreen": "#556b2f",
        "darkmagenta": "#8b008b",
        "darkkhaki": "#bdb76b",
        "darkgreen": "#006400",
        "darkgray": "#a9a9a9",
        "darkcyan": "#008b8b",
        "darkblue": "#00008b",
        "cornflowerblue": "#6495ed",
        "chocolate": "#d2691e",
        "chartreuse": "#7fff00",
        "cadetblue": "#5f9ea0",
        "burlywood": "#deb887",
        "blueviolet": "#8a2be2",
        "bisque": "#ffe4c4",
        "beige": "#f5f5dc",
        "azure": "#f0ffff",
        "aquamarine": "#7fffd4",
        "antiquewhite": "#faebd7",
        "aliceblue": "#f0f8ff"
    ]
}
