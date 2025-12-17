//
//  CSSUtilities.swift
//  wina
//
//  CSS formatting, syntax highlighting, and display components.
//

import SwiftUI

// MARK: - CSS Syntax Colors

/// CSS syntax highlighting colors with dark/light mode support
/// Based on WCAG accessibility guidelines (4.5:1 contrast ratio)
enum CSSSyntaxColors {
    /// Property names (e.g., "color", "background")
    static func property(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.78, green: 0.56, blue: 0.90)  // Light purple
            : Color(red: 0.56, green: 0.27, blue: 0.68)  // Dark purple
    }

    /// Color values (e.g., "#fff", "rgba()")
    static func colorValue(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.40, green: 0.80, blue: 0.40)  // Light green
            : Color(red: 0.13, green: 0.55, blue: 0.13)  // Forest green
    }

    /// Numeric values (e.g., "10px", "1.5")
    static func number(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.60, green: 0.80, blue: 1.00)  // Light blue
            : Color(red: 0.10, green: 0.40, blue: 0.75)  // Steel blue
    }

    /// String values (e.g., "'Arial'")
    static func string(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.70, blue: 0.40)  // Light orange
            : Color(red: 0.80, green: 0.40, blue: 0.00)  // Dark orange
    }

    /// URL values (e.g., "url(...)")
    static func url(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.85, green: 0.65, blue: 0.50)  // Light brown
            : Color(red: 0.55, green: 0.35, blue: 0.20)  // Dark brown
    }

    /// Keyword values (e.g., "block", "flex")
    static func keyword(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.70, green: 0.70, blue: 0.75)  // Light gray
            : Color(red: 0.35, green: 0.35, blue: 0.40)  // Dark gray
    }
}

// MARK: - CSS Formatter

/// CSS formatter utilities
enum CSSFormatter {
    /// Parses a CSS rule, handling both regular rules and at-rules like @keyframes
    static func parseRule(from cssText: String) -> ParsedCSSContent {
        let trimmed = cssText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if this is a @keyframes rule
        if trimmed.hasPrefix("@keyframes") || trimmed.hasPrefix("@-webkit-keyframes") {
            return .keyframes(parseKeyframes(from: trimmed))
        }

        // Regular rule - parse flat properties
        return .properties(parseProperties(from: trimmed))
    }

    /// Parses @keyframes rule into individual frame blocks
    private static func parseKeyframes(
        from cssText: String
    ) -> [(selector: String, properties: [(property: String, value: String)])] {
        var results: [(selector: String, properties: [(property: String, value: String)])] = []

        // Find the outer braces of @keyframes
        guard let firstBrace = cssText.firstIndex(of: "{"),
              let lastBrace = cssText.lastIndex(of: "}"),
              firstBrace < lastBrace else {
            return results
        }

        let innerContent = String(cssText[cssText.index(after: firstBrace)..<lastBrace])

        // Parse each keyframe block (e.g., "0% { ... }" or "from { ... }")
        let pattern = #"([\d.]+%|from|to)\s*\{([^}]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return results
        }

        let nsRange = NSRange(innerContent.startIndex..., in: innerContent)
        let matches = regex.matches(in: innerContent, options: [], range: nsRange)

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let selectorRange = Range(match.range(at: 1), in: innerContent),
                  let propsRange = Range(match.range(at: 2), in: innerContent) else {
                continue
            }

            let selector = String(innerContent[selectorRange]).trimmingCharacters(in: .whitespaces)
            let propsText = String(innerContent[propsRange])
            let properties = parsePropertiesFromBlock(propsText)

            if !properties.isEmpty {
                results.append((selector, properties))
            }
        }

        return results
    }

    /// Parses CSS properties from a simple block content (no nested braces)
    private static func parsePropertiesFromBlock(
        _ content: String
    ) -> [(property: String, value: String)] {
        let declarations = content.split(separator: ";", omittingEmptySubsequences: true)

        return declarations.compactMap { decl in
            let parts = decl.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }

            let property = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            guard !property.isEmpty, !value.isEmpty else { return nil }
            return (property, value)
        }
    }

    /// Parses CSS properties from a rule's cssText (for regular rules)
    static func parseProperties(from cssText: String) -> [(property: String, value: String)] {
        var content = cssText

        // Find content between braces
        if let openBrace = content.firstIndex(of: "{"),
           let closeBrace = content.lastIndex(of: "}") {
            content = String(content[content.index(after: openBrace)..<closeBrace])
        }

        return parsePropertiesFromBlock(content)
    }

    /// Formats CSS text with proper indentation
    static func format(_ cssText: String) -> String {
        let properties = parseProperties(from: cssText)
        return properties.map { "  \($0.property): \($0.value);" }.joined(separator: "\n")
    }
}

// MARK: - Formatted CSS Property Row

/// Formatted CSS property row with syntax highlighting and color preview
struct FormattedCSSPropertyRow: View {
    let property: String
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    private var parsedColor: Color? {
        CSSColorParser.parse(value)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Property name (keyword color)
            Text(property)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CSSSyntaxColors.property(for: colorScheme))

            Text(":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Color swatch before value (if applicable)
            if let color = parsedColor {
                ColorSwatchView(color: color)
            }

            // Value (formatted based on type)
            FormattedValueText(value: value)
                .fixedSize(horizontal: false, vertical: true)

            Text(";")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Formatted Value Text

/// Syntax highlighted value text with !important detection (CSS Cascade standard)
struct FormattedValueText: View {
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    /// Check if value contains !important (highest cascade priority)
    private var hasImportant: Bool {
        value.lowercased().contains("!important")
    }

    /// Value without !important suffix
    private var valueWithoutImportant: String {
        let stripped = value.replacingOccurrences(
            of: "\\s*!important\\s*",
            with: "",
            options: .regularExpression
        )
        return stripped.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        if hasImportant {
            // CSS Cascade: !important has highest priority - highlight in red
            HStack(spacing: 2) {
                Text(valueWithoutImportant)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(valueColor(for: valueWithoutImportant))
                Text("!important")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.red)
            }
        } else {
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(valueColor(for: value))
        }
    }

    private func valueColor(for text: String) -> Color {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()

        // Color values
        if CSSColorParser.containsColor(trimmed) {
            return CSSSyntaxColors.colorValue(for: colorScheme)
        }

        // Numbers and units
        if trimmed.first?.isNumber == true ||
           trimmed.hasPrefix(".") ||
           trimmed.hasPrefix("-") {
            return CSSSyntaxColors.number(for: colorScheme)
        }

        // Strings
        if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") {
            return CSSSyntaxColors.string(for: colorScheme)
        }

        // URLs
        if trimmed.hasPrefix("url(") {
            return CSSSyntaxColors.url(for: colorScheme)
        }

        // Default for keywords
        return CSSSyntaxColors.keyword(for: colorScheme)
    }
}

// MARK: - Keyframe Block View

/// View for displaying a keyframe block (e.g., "0% { transform: ... }")
struct KeyframeBlockView: View {
    let selector: String
    let properties: [(property: String, value: String)]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Keyframe selector (0%, 100%, from, to)
            Text("\(selector) {")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CSSSyntaxColors.keyword(for: colorScheme))

            // Properties
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(properties.enumerated()), id: \.offset) { _, prop in
                    FormattedCSSPropertyRow(property: prop.property, value: prop.value)
                }
            }
            .padding(.leading, 12)

            Text("}")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Code Block

enum CodeLanguage {
    case html
    case css
    case javascript
}

struct CodeBlock: View {
    let code: String
    let language: CodeLanguage

    var body: some View {
        Text(code)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
