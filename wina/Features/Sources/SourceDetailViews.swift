//
//  SourceDetailViews.swift
//  wina
//
//  Element detail view for DOM inspection - Chrome DevTools style.
//

import SwiftUI

// MARK: - Matched CSS Rule

/// Represents a matched CSS rule with its source
struct MatchedCSSRule: Identifiable {
    let id: Int
    let selector: String
    let source: CSSSource
    let properties: [(property: String, value: String)]
    let specificity: Int  // For sorting
    let isCORSBlocked: Bool  // True if stylesheet couldn't be accessed due to CORS

    init(
        id: Int,
        selector: String,
        source: CSSSource,
        properties: [(property: String, value: String)],
        specificity: Int,
        isCORSBlocked: Bool = false
    ) {
        self.id = id
        self.selector = selector
        self.source = source
        self.properties = properties
        self.specificity = specificity
        self.isCORSBlocked = isCORSBlocked
    }

    enum CSSSource: Equatable {
        case inline              // element.style
        case styleTag(Int)       // <style> tag (index)
        case stylesheet(String)  // External file (href)
        case unknown

        var displayName: String {
            switch self {
            case .inline: return "element.style"
            case .styleTag(let idx): return "<style> #\(idx + 1)"
            case .stylesheet(let href):
                if let url = URL(string: href) {
                    // Show host + filename for external
                    if let host = url.host, host != url.lastPathComponent {
                        return "\(host)/\(url.lastPathComponent)"
                    }
                    return url.lastPathComponent
                }
                return href
            case .unknown: return "unknown"
            }
        }

        var sortOrder: Int {
            switch self {
            case .inline: return 0
            case .styleTag: return 1
            case .stylesheet: return 2
            case .unknown: return 3
            }
        }
    }
}

// MARK: - Element Detail View

struct ElementDetailView: View {
    let node: DOMNode
    let navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @State private var computedStyles: [String: String] = [:]
    @State private var matchedRules: [MatchedCSSRule] = []
    @State private var innerHTML: String = ""
    @State private var outerHTML: String = ""
    @State private var isLoading: Bool = true
    @State private var selectedSection: ElementSection = .attributes
    @State private var showMatchedRules: Bool = true  // Toggle between matched/computed
    @State private var computedStylesFilter: String = ""
    @State private var copiedFeedback: String?
    @State private var corsBlockedCount: Int = 0

    enum ElementSection: String, CaseIterable {
        case attributes = "Attributes"
        case styles = "Styles"
        case html = "HTML"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            sectionPicker
            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    content
                        .padding()
                }
                .background(Color(uiColor: .systemBackground))
            }
        }
        .overlay(alignment: .bottom) {
            if let feedback = copiedFeedback {
                CopiedFeedbackToast(message: feedback)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copiedFeedback)
        .task {
            await fetchDetails()
        }
    }

    private var header: some View {
        DevToolsHeader(
            title: node.displayName,
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                }
            ],
            rightButtons: [
                .init(icon: "doc.on.doc") {
                    copyToClipboard()
                }
            ]
        )
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(ElementSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .attributes:
            attributesContent
        case .styles:
            stylesContent
        case .html:
            htmlContent
        }
    }

    private var attributesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tag name
            SourceInfoRow(label: "Tag", value: node.nodeName.lowercased())

            // Attributes
            if node.attributes.isEmpty {
                Text("No attributes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(node.attributes.keys.sorted()), id: \.self) { key in
                    if let value = node.attributes[key] {
                        AttributeRow(name: key, value: value)
                    }
                }
            }
        }
    }

    private var stylesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Toggle between matched rules and computed styles
            stylesModeToggle

            if showMatchedRules {
                matchedRulesContent
            } else {
                computedStylesContent
            }
        }
    }

    private var stylesModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    showMatchedRules = true
                }
            } label: {
                Text("Matched")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(showMatchedRules ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if showMatchedRules {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    showMatchedRules = false
                }
            } label: {
                Text("Computed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(!showMatchedRules ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if !showMatchedRules {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var matchedRulesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // CORS warning banner if applicable
            if corsBlockedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("\(corsBlockedCount) external stylesheet\(corsBlockedCount > 1 ? "s" : "") blocked by CORS")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            // Rules content
            if accessibleMatchedRules.isEmpty {
                VStack(spacing: 8) {
                    Text("No matched rules found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if corsBlockedCount > 0 {
                        Text("Styles from CDN (Tailwind, Bootstrap, etc.) cannot be inspected due to browser security")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(groupedMatchedRules, id: \.source.displayName) { group in
                        MatchedRulesGroupView(
                            source: group.source,
                            rules: group.rules
                        )
                    }
                }
            }
        }
    }

    /// Matched rules excluding CORS-blocked entries
    private var accessibleMatchedRules: [MatchedCSSRule] {
        matchedRules.filter { !$0.isCORSBlocked }
    }

    /// Group matched rules by source for display (excluding CORS-blocked)
    private var groupedMatchedRules: [(source: MatchedCSSRule.CSSSource, rules: [MatchedCSSRule])] {
        let accessible = accessibleMatchedRules
        let grouped = Dictionary(grouping: accessible) { $0.source.displayName }
        return grouped
            .compactMap { _, rules -> (source: MatchedCSSRule.CSSSource, rules: [MatchedCSSRule])? in
                guard let firstRule = rules.first else { return nil }
                return (firstRule.source, rules)
            }
            .sorted { $0.source.sortOrder < $1.source.sortOrder }
    }

    private var filteredComputedStyles: [(key: String, value: String)] {
        let sorted = computedStyles.sorted { $0.key < $1.key }
        if computedStylesFilter.isEmpty {
            return sorted.map { (key: $0.key, value: $0.value) }
        }
        let filter = computedStylesFilter.lowercased()
        return sorted
            .filter { $0.key.lowercased().contains(filter) || $0.value.lowercased().contains(filter) }
            .map { (key: $0.key, value: $0.value) }
    }

    private var computedStylesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Filter properties", text: $computedStylesFilter)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                if !computedStylesFilter.isEmpty {
                    Button {
                        computedStylesFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            // Count indicator
            HStack {
                Text("\(filteredComputedStyles.count) properties")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Properties list
            if computedStyles.isEmpty {
                Text("No computed styles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if filteredComputedStyles.isEmpty {
                Text("No matching properties")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredComputedStyles, id: \.key) { item in
                        CSSPropertyRow(property: item.key, value: item.value)
                    }
                }
            }
        }
    }

    private var htmlContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // outerHTML
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("outerHTML")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    CopyIconButton(text: outerHTML) {
                        showCopiedFeedback("outerHTML")
                    }
                }

                CodeBlock(code: outerHTML, language: .html)
            }

            // innerHTML
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("innerHTML")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    CopyIconButton(text: innerHTML) {
                        showCopiedFeedback("innerHTML")
                    }
                }

                CodeBlock(code: innerHTML, language: .html)
            }
        }
    }

    // MARK: - Data Fetching

    private func fetchDetails() async {
        guard let navigator else {
            isLoading = false
            return
        }

        let selector = buildSelector()

        // Execute all JavaScript fetches concurrently
        async let stylesResult = navigator.evaluateJavaScript(ElementDetailScripts.computedStyles(selector: selector))
        async let htmlResult = navigator.evaluateJavaScript(ElementDetailScripts.htmlContent(selector: selector))
        async let matchedResult = navigator.evaluateJavaScript(ElementDetailScripts.matchedRules(selector: selector))

        // Parse computed styles
        if let stylesJSON = await stylesResult as? String,
           let data = stylesJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            computedStyles = parsed
        }

        // Parse HTML content
        if let htmlJSON = await htmlResult as? String,
           let data = htmlJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            outerHTML = parsed["outer"] ?? ""
            innerHTML = parsed["inner"] ?? ""
        }

        // Parse matched CSS rules
        if let matchedJSON = await matchedResult as? String,
           let data = matchedJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let rules = parseMatchedRules(from: parsed)
            matchedRules = rules
            corsBlockedCount = rules.filter { $0.isCORSBlocked }.count
        }

        isLoading = false
    }

    /// Parse matched rules from JavaScript result
    private func parseMatchedRules(from jsonArray: [[String: Any]]) -> [MatchedCSSRule] {
        return jsonArray.compactMap { item -> MatchedCSSRule? in
            guard let id = item["id"] as? Int,
                  let sourceDict = item["source"] as? [String: Any] else {
                return nil
            }

            let selector = item["selector"] as? String ?? ""
            let propsArray = item["properties"] as? [[String: String]] ?? []
            let specificity = item["specificity"] as? Int ?? 0
            let corsBlocked = item["corsBlocked"] as? Bool ?? false

            // Parse source
            let source: MatchedCSSRule.CSSSource
            if let type = sourceDict["type"] as? String {
                switch type {
                case "inline":
                    source = .inline
                case "styleTag":
                    let index = sourceDict["index"] as? Int ?? 0
                    source = .styleTag(index)
                case "external":
                    let href = sourceDict["href"] as? String ?? ""
                    source = .stylesheet(href)
                default:
                    source = .unknown
                }
            } else {
                source = .unknown
            }

            // Parse properties
            let properties = propsArray.compactMap { propDict -> (String, String)? in
                guard let prop = propDict["p"], let val = propDict["v"] else { return nil }
                return (prop, val)
            }

            return MatchedCSSRule(
                id: id,
                selector: selector,
                source: source,
                properties: properties,
                specificity: specificity,
                isCORSBlocked: corsBlocked
            )
        }
    }

    private func buildSelector() -> String {
        if let id = node.attributes["id"], !id.isEmpty {
            return "#\(id)"
        }
        return node.nodeName.lowercased()
    }

    private func copyToClipboard() {
        switch selectedSection {
        case .attributes:
            let text = node.attributes.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: "\n")
            UIPasteboard.general.string = text
            showCopiedFeedback("Attributes")
        case .styles:
            let text = computedStyles.map { "\($0.key): \($0.value);" }.joined(separator: "\n")
            UIPasteboard.general.string = text
            showCopiedFeedback("Styles")
        case .html:
            UIPasteboard.general.string = outerHTML
            showCopiedFeedback("HTML")
        }
    }

    private func showCopiedFeedback(_ label: String) {
        copiedFeedback = "\(label) copied"
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                if copiedFeedback == "\(label) copied" {
                    copiedFeedback = nil
                }
            }
        }
    }
}

// MARK: - Element Detail Scripts

/// JavaScript scripts for element detail fetching
private enum ElementDetailScripts {
    /// Script to fetch computed styles that differ from defaults
    static func computedStyles(selector: String) -> String {
        """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return '{}';

            // Create a reference element of the same tag to compare defaults
            const tagName = el.tagName.toLowerCase();
            const ref = document.createElement(tagName);
            ref.style.cssText = 'position:absolute;visibility:hidden;pointer-events:none;';
            document.body.appendChild(ref);

            const styles = window.getComputedStyle(el);
            const refStyles = window.getComputedStyle(ref);
            const result = {};

            // Compare and keep only non-default values
            for (let i = 0; i < styles.length; i++) {
                const prop = styles[i];
                const val = styles.getPropertyValue(prop);
                const refVal = refStyles.getPropertyValue(prop);

                // Keep if different from default or is a custom property
                if (val !== refVal || prop.startsWith('--')) {
                    if (val && val.trim()) {
                        result[prop] = val;
                    }
                }
            }

            // Cleanup
            document.body.removeChild(ref);

            return JSON.stringify(result);
        })();
        """
    }

    /// Script to fetch HTML content
    static func htmlContent(selector: String) -> String {
        """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return '{}';
            return JSON.stringify({
                outer: el.outerHTML.substring(0, 5000),
                inner: el.innerHTML.substring(0, 5000)
            });
        })();
        """
    }

    /// Script to fetch matched CSS rules
    static func matchedRules(selector: String) -> String {
        """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return '[]';

            const rules = [];
            let ruleId = 0;

            function calcSpecificity(sel) {
                if (!sel) return 0;
                const ids = (sel.match(/#/g) || []).length;
                const classes = (sel.match(/\\./g) || []).length + (sel.match(/\\[/g) || []).length;
                const tags = (sel.match(/^[a-z]/gi) || []).length;
                return ids * 100 + classes * 10 + tags;
            }

            function parseProps(cssText) {
                const props = [];
                const match = cssText.match(/\\{([^}]*)\\}/);
                if (!match) return props;
                const decls = match[1].split(';');
                for (const decl of decls) {
                    const parts = decl.split(':');
                    if (parts.length >= 2) {
                        const prop = parts[0].trim();
                        const val = parts.slice(1).join(':').trim();
                        if (prop && val) props.push({p: prop, v: val});
                    }
                }
                return props;
            }

            if (el.style.length > 0) {
                const inlineProps = [];
                for (let i = 0; i < el.style.length; i++) {
                    const prop = el.style[i];
                    const val = el.style.getPropertyValue(prop);
                    if (val) inlineProps.push({p: prop, v: val});
                }
                if (inlineProps.length > 0) {
                    rules.push({
                        id: ruleId++,
                        selector: 'element.style',
                        source: {type: 'inline'},
                        properties: inlineProps,
                        specificity: 1000
                    });
                }
            }

            let styleTagIndex = 0;
            for (let i = 0; i < document.styleSheets.length; i++) {
                const sheet = document.styleSheets[i];
                let sourceInfo;

                if (sheet.href) {
                    sourceInfo = {type: 'external', href: sheet.href};
                } else {
                    sourceInfo = {type: 'styleTag', index: styleTagIndex++};
                }

                try {
                    const cssRules = sheet.cssRules || sheet.rules;
                    if (!cssRules) continue;

                    for (const rule of cssRules) {
                        if (rule.type !== 1) continue;

                        try {
                            if (el.matches(rule.selectorText)) {
                                const props = parseProps(rule.cssText);
                                if (props.length > 0) {
                                    rules.push({
                                        id: ruleId++,
                                        selector: rule.selectorText,
                                        source: sourceInfo,
                                        properties: props,
                                        specificity: calcSpecificity(rule.selectorText)
                                    });
                                }
                            }
                        } catch(e) {}
                    }
                } catch(e) {
                    if (sheet.href) {
                        rules.push({
                            id: ruleId++,
                            selector: '',
                            source: sourceInfo,
                            properties: [],
                            specificity: 0,
                            corsBlocked: true
                        });
                    }
                }
            }

            return JSON.stringify(rules.slice(0, 50));
        })();
        """
    }
}

// MARK: - Matched Rules Group View

/// Displays a group of matched CSS rules from a single source
private struct MatchedRulesGroupView: View {
    let source: MatchedCSSRule.CSSSource
    let rules: [MatchedCSSRule]

    @Environment(\.colorScheme) private var colorScheme

    /// Check if this group is CORS blocked
    private var isCORSBlocked: Bool {
        rules.first?.isCORSBlocked ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Source header
            HStack {
                sourceIcon
                Text(source.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
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
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
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
private struct MatchedRuleRowView: View {
    let rule: MatchedCSSRule
    @State private var isExpanded: Bool = false

    @Environment(\.colorScheme) private var colorScheme

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
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(rule.properties.enumerated()), id: \.offset) { _, prop in
                        FormattedCSSPropertyRow(property: prop.0, value: prop.1)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
        }
    }
}

// MARK: - Previews

#Preview("Element Detail") {
    ElementDetailView(
        node: DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "main", "class": "container flex"],
            textContent: nil,
            children: []
        ),
        navigator: nil
    )
}
