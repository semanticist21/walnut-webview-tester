//
//  SourceDetailComponents.swift
//  wina
//
//  Supporting views for ElementDetailView.
//

import SwiftUI

// MARK: - Matched Rules Group View

/// Displays a group of matched CSS rules from a single source/layer (Chrome DevTools style)
struct MatchedRulesGroupView: View {
    let source: MatchedCSSRule.CSSSource
    let layer: String?
    let rules: [MatchedCSSRule]

    @Environment(\.colorScheme) private var colorScheme

    /// Check if this group is CORS blocked
    private var isCORSBlocked: Bool {
        rules.first?.isCORSBlocked ?? false
    }

    /// Header text showing layer or source
    private var headerText: String {
        if let layer {
            return "Layer \(layer)"
        }
        return source.displayName
    }

    /// Subheader showing source file (when layer exists)
    private var sourceText: String? {
        guard layer != nil else { return nil }
        return source.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header (Chrome DevTools style: "Layer utilities" or source name)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    layerIcon
                    Text(headerText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(layer != nil ? .primary : .secondary)
                    Spacer()
                    // Rules count badge
                    Text("\(rules.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }

                // Source file subheader (when showing layer)
                if let sourceText {
                    HStack(spacing: 4) {
                        sourceIcon
                        Text(sourceText)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 2)
                }
            }

            // Rules or CORS warning
            if isCORSBlocked {
                corsBlockedView
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rules) { rule in
                        MatchedRuleRowView(rule: rule)
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(10)
        .background(layerBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Background color based on CSS Cascade standard (source-based, not layer name)
    /// CSS Cascade priority: inline > unlayered > layered
    private var layerBackground: Color {
        switch source {
        case .inline:
            // Inline styles have high cascade priority - subtle orange highlight
            return Color.orange.opacity(0.08)
        default:
            // All other sources use neutral background
            // @layer existence is indicated by icon, not background color
            return Color.secondary.opacity(0.05)
        }
    }

    /// Icon for layer type
    @ViewBuilder
    private var layerIcon: some View {
        if layer != nil {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
        } else {
            sourceIcon
        }
    }

    private var corsBlockedView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Cross-origin: rules not accessible")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 8)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch source {
        case .inline:
            Image(systemName: "tag")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
        case .styleTag:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.purple)
        case .stylesheet:
            Image(systemName: isCORSBlocked ? "lock.doc" : "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(isCORSBlocked ? .orange : .blue)
        case .unknown:
            Image(systemName: "questionmark")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Matched Rule Row View

/// Displays a single matched rule with selector and properties
struct MatchedRuleRowView: View {
    let rule: MatchedCSSRule
    @State private var isExpanded: Bool = false
    @State private var showCopiedFeedback: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    /// Generates copyable CSS text for the entire rule
    private var copyableRuleText: String {
        let propsText = rule.properties
            .map { prop in
                let important = prop.isImportant ? " !important" : ""
                return "  \(prop.property): \(prop.value)\(important);"
            }
            .joined(separator: "\n")
        return "\(rule.selector) {\n\(propsText)\n}"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(rule.selector)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(CSSSyntaxColors.keyword(for: colorScheme))
                        .lineLimit(1)

                    Spacer()

                    // Copy button (visible when expanded)
                    if isExpanded {
                        Button {
                            UIPasteboard.general.string = copyableRuleText
                            withAnimation(.easeOut(duration: 0.15)) {
                                showCopiedFeedback = true
                            }
                            Task {
                                try? await Task.sleep(for: .seconds(1.2))
                                await MainActor.run {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        showCopiedFeedback = false
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(showCopiedFeedback ? Color.green : Color.gray.opacity(0.6))
                                .frame(width: 24, height: 24)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(rule.properties.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                SelectableCSSPropertiesView(
                    properties: rule.properties,
                    colorScheme: colorScheme
                )
                .padding(.leading, 16)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
        }
    }
}

// MARK: - Selectable CSS Properties View

/// Displays CSS properties with text selection enabled for drag-to-copy
struct SelectableCSSPropertiesView: View {
    let properties: [CSSProperty]
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(properties) { prop in
                SelectableCSSPropertyRow(
                    property: prop.property,
                    value: prop.value,
                    isImportant: prop.isImportant,
                    isOverridden: prop.isOverridden,
                    colorScheme: colorScheme
                )
            }
        }
        .textSelection(.enabled)
    }
}

// MARK: - Selectable CSS Property Row

/// Single CSS property row with text selection support
struct SelectableCSSPropertyRow: View {
    let property: String
    let value: String
    let isImportant: Bool
    let isOverridden: Bool
    let colorScheme: ColorScheme

    /// Extract all colors from value
    private var extractedColors: [Color] {
        CSSColorParser.extractColors(from: value).map(\.color)
    }

    /// Full property text for selection
    private var fullPropertyText: AttributedString {
        var result = AttributedString()

        // Property name
        var propAttr = AttributedString(property)
        propAttr.foregroundColor = UIColor(CSSSyntaxColors.property(for: colorScheme))
        propAttr.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        result.append(propAttr)

        // Colon
        var colonAttr = AttributedString(": ")
        colonAttr.foregroundColor = UIColor.tertiaryLabel
        colonAttr.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        result.append(colonAttr)

        // Value
        var valueAttr = AttributedString(value)
        valueAttr.foregroundColor = UIColor(valueColor)
        valueAttr.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        result.append(valueAttr)

        // !important
        if isImportant {
            var importantAttr = AttributedString(" !important")
            importantAttr.foregroundColor = UIColor.systemRed
            importantAttr.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
            result.append(importantAttr)
        }

        // Semicolon
        var semiAttr = AttributedString(";")
        semiAttr.foregroundColor = UIColor.tertiaryLabel
        semiAttr.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        result.append(semiAttr)

        // Apply strikethrough if overridden
        if isOverridden {
            result.strikethroughStyle = .single
            result.strikethroughColor = UIColor.secondaryLabel
        }

        return result
    }

    private var valueColor: Color {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()

        if CSSColorParser.containsColor(trimmed) {
            return CSSSyntaxColors.colorValue(for: colorScheme)
        }
        if trimmed.first?.isNumber == true || trimmed.hasPrefix(".") || trimmed.hasPrefix("-") {
            return CSSSyntaxColors.number(for: colorScheme)
        }
        if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") {
            return CSSSyntaxColors.string(for: colorScheme)
        }
        if trimmed.hasPrefix("url(") {
            return CSSSyntaxColors.url(for: colorScheme)
        }
        return CSSSyntaxColors.keyword(for: colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Color swatches
            ForEach(Array(extractedColors.enumerated()), id: \.offset) { _, color in
                ColorSwatchView(color: color)
            }

            // Selectable text
            Text(fullPropertyText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
        .opacity(isOverridden ? 0.6 : 1.0)
    }
}

// MARK: - Collapsible HTML Block

/// Collapsible block for displaying long HTML content
struct CollapsibleHTMLBlock: View {
    let title: String
    let content: String
    let charCount: Int
    let onCopy: () -> Void

    @State private var isExpanded: Bool = false

    /// Preview text (first 500 chars)
    private var previewText: String {
        if content.count <= 500 {
            return content
        }
        return String(content.prefix(500)) + "..."
    }

    /// Formatted size string
    private var sizeString: String {
        if charCount >= 1000 {
            return String(format: "%.1fK", Double(charCount) / 1000.0)
        }
        return "\(charCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    // Size badge
                    Text(sizeString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())

                    Spacer()

                    CopyIconButton(text: content, onCopy: onCopy)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            // Content
            if isExpanded {
                CodeBlock(code: content, language: .html)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isExpanded = false
                        }
                    }
            } else {
                // Collapsed preview (tap to expand)
                Text(previewText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isExpanded = true
                        }
                    }
            }
        }
    }
}

// MARK: - Computed Styles Group View

/// Collapsible group view for computed styles categories
struct ComputedStylesGroupView: View {
    let category: String
    let properties: [(key: String, value: String)]

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(category)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("\(properties.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            // Properties
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(properties, id: \.key) { item in
                        CSSPropertyRow(property: item.key, value: item.value)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}
