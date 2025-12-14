//
//  SourceDetailViews.swift
//  wina
//
//  Detail views for Elements, Stylesheets, and Scripts - Chrome DevTools style.
//

import SwiftUI

// MARK: - Element Detail View

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
    @State private var copiedFeedback: String?

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
        Group {
            if matchedRules.isEmpty {
                Text("No matched rules")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    /// Group matched rules by source for display
    private var groupedMatchedRules: [(source: MatchedCSSRule.CSSSource, rules: [MatchedCSSRule])] {
        let grouped = Dictionary(grouping: matchedRules) { $0.source.displayName }
        return grouped
            .compactMap { _, rules -> (source: MatchedCSSRule.CSSSource, rules: [MatchedCSSRule])? in
                guard let firstRule = rules.first else { return nil }
                return (firstRule.source, rules)
            }
            .sorted { $0.source.sortOrder < $1.source.sortOrder }
    }

    private var computedStylesContent: some View {
        Group {
            if computedStyles.isEmpty {
                Text("No computed styles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(computedStyles.keys.sorted()), id: \.self) { property in
                        if let value = computedStyles[property] {
                            CSSPropertyRow(property: property, value: value)
                        }
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

    private func fetchDetails() async {
        guard let navigator else {
            isLoading = false
            return
        }

        // Build selector from node path (simplified - uses id or first matching tag)
        let selector = buildSelector()

        // Fetch computed styles
        let stylesScript = """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return '{}';
            const styles = window.getComputedStyle(el);
            const result = {};
            const important = ['display', 'position', 'width', 'height', 'margin', 'padding',
                'color', 'background', 'font-size', 'font-family', 'border', 'flex', 'grid'];
            for (const prop of important) {
                const val = styles.getPropertyValue(prop);
                if (val && val !== 'none' && val !== 'auto' && val !== 'normal') {
                    result[prop] = val;
                }
            }
            return JSON.stringify(result);
        })();
        """

        // Fetch HTML
        let htmlScript = """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return '{}';
            return JSON.stringify({
                outer: el.outerHTML.substring(0, 5000),
                inner: el.innerHTML.substring(0, 5000)
            });
        })();
        """

        // Fetch matched CSS rules
        let matchedRulesScript = """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return '[]';

            const rules = [];
            let ruleId = 0;

            // Helper: calculate specificity (simplified)
            function calcSpecificity(sel) {
                if (!sel) return 0;
                const ids = (sel.match(/#/g) || []).length;
                const classes = (sel.match(/\\./g) || []).length + (sel.match(/\\[/g) || []).length;
                const tags = (sel.match(/^[a-z]/gi) || []).length;
                return ids * 100 + classes * 10 + tags;
            }

            // Helper: parse CSS text to properties
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

            // 1. Inline styles (element.style)
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

            // 2. Iterate stylesheets
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
                        if (rule.type !== 1) continue; // CSSStyleRule only

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
                        } catch(e) { /* selector may be invalid */ }
                    }
                } catch(e) {
                    // CORS: cannot access cssRules - add blocked entry
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

            return JSON.stringify(rules.slice(0, 50)); // Limit to 50 rules
        })();
        """

        async let stylesResult = navigator.evaluateJavaScript(stylesScript)
        async let htmlResult = navigator.evaluateJavaScript(htmlScript)
        async let matchedResult = navigator.evaluateJavaScript(matchedRulesScript)

        if let stylesJSON = await stylesResult as? String,
           let data = stylesJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            computedStyles = parsed
        }

        if let htmlJSON = await htmlResult as? String,
           let data = htmlJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            outerHTML = parsed["outer"] ?? ""
            innerHTML = parsed["inner"] ?? ""
        }

        if let matchedJSON = await matchedResult as? String,
           let data = matchedJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            matchedRules = parseMatchedRules(from: parsed)
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

// MARK: - Stylesheet Detail View

struct StylesheetDetailView: View {
    let sheet: StylesheetInfo
    let index: Int
    let navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @State private var cssRules: [CSSRuleInfo] = []
    @State private var rawCSS: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showRaw: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if let error = errorMessage {
                errorView(error)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .task {
            await fetchDetails()
        }
    }

    private var header: some View {
        DevToolsHeader(
            title: sheet.href.flatMap { URL(string: $0)?.lastPathComponent } ?? "<style>",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                }
            ],
            rightButtons: [
                .init(icon: showRaw ? "list.bullet" : "doc.plaintext") {
                    showRaw.toggle()
                },
                .init(icon: "doc.on.doc") {
                    UIPasteboard.general.string = rawCSS
                }
            ]
        )
    }

    @ViewBuilder
    private var content: some View {
        if showRaw {
            ScrollView {
                CodeBlock(code: rawCSS, language: .css)
                    .padding()
            }
            .background(Color(uiColor: .systemBackground))
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(cssRules) { rule in
                        CSSRuleRow(rule: rule)
                        Divider()
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func fetchDetails() async {
        guard let navigator else {
            errorMessage = "Navigator not available"
            isLoading = false
            return
        }

        let script = """
        (function() {
            const sheet = document.styleSheets[\(index)];
            if (!sheet) return JSON.stringify({error: 'Sheet not found'});
            const rules = [];
            let rawCSS = '';
            try {
                for (const rule of sheet.cssRules) {
                    rules.push({
                        selector: rule.selectorText || rule.cssText.substring(0, 50),
                        text: rule.cssText
                    });
                    rawCSS += rule.cssText + '\\n\\n';
                }
            } catch(e) {
                return JSON.stringify({error: 'Cannot access rules (CORS)'});
            }
            return JSON.stringify({rules: rules, raw: rawCSS});
        })();
        """

        if let result = await navigator.evaluateJavaScript(script) as? String,
           let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String {
                errorMessage = error
            } else if let rulesArray = json["rules"] as? [[String: String]] {
                cssRules = rulesArray.enumerated().map { idx, item in
                    CSSRuleInfo(
                        id: idx,
                        selector: item["selector"] ?? "",
                        cssText: item["text"] ?? ""
                    )
                }
                rawCSS = json["raw"] as? String ?? ""
            }
        } else {
            errorMessage = "Failed to fetch stylesheet"
        }

        isLoading = false
    }
}

// MARK: - Script Detail View

struct ScriptDetailView: View {
    let script: ScriptInfo
    let index: Int
    let navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @State private var scriptContent: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var copiedFeedback: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            metadataBadges

            Divider()

            if let error = errorMessage {
                errorView(error)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if script.isExternal {
                corsLimitationView
            } else {
                ScrollView(.vertical) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        CodeBlock(code: scriptContent, language: .javascript)
                            .padding()
                    }
                }
                .background(Color(uiColor: .systemBackground))
            }
        }
        .overlay(alignment: .bottom) {
            if let feedback = copiedFeedback {
                CopiedFeedbackToast(message: feedback)
                    .padding(.bottom, 16)
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
            title: script.src.flatMap { URL(string: $0)?.lastPathComponent } ?? "<script>",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                }
            ],
            rightButtons: [
                .init(icon: "doc.on.doc") {
                    UIPasteboard.general.string = scriptContent
                }
            ]
        )
    }

    private var metadataBadges: some View {
        HStack(spacing: 8) {
            if script.isModule {
                badge("module")
            }
            if script.isAsync {
                badge("async")
            }
            if script.isDefer {
                badge("defer")
            }
            if script.isExternal {
                badge("external")
            } else {
                badge("inline")
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.secondary.opacity(0.1), in: Capsule())
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    /// View explaining CORS limitation for external scripts
    private var corsLimitationView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)

                Text("External Script")
                    .font(.headline)

                Text("Content unavailable due to CORS policy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let src = script.src {
                    ExpandableURLView(url: src) {
                        showCopiedFeedback()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func showCopiedFeedback() {
        copiedFeedback = "URL copied"
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copiedFeedback = nil
        }
    }

    private func fetchDetails() async {
        guard let navigator else {
            errorMessage = "Navigator not available"
            isLoading = false
            return
        }

        if script.isExternal {
            // External scripts cannot be fetched due to CORS
            // Show limitation view instead of trying to fetch
            isLoading = false
            return
        } else {
            // Get inline script content
            let script = """
            (function() {
                const scripts = document.scripts;
                if (\(index) >= scripts.length) return JSON.stringify({error: 'Script not found'});
                return JSON.stringify({content: scripts[\(index)].textContent.substring(0, 50000)});
            })();
            """

            if let result = await navigator.evaluateJavaScript(script) as? String,
               let data = result.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                if let error = json["error"] {
                    errorMessage = error
                } else {
                    scriptContent = json["content"] ?? ""
                }
            } else {
                errorMessage = "Failed to fetch script"
            }
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

private struct SourceInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                UIPasteboard.general.string = value
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

struct AttributeRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = "\(name)=\"\(value)\""
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct CSSPropertyRow: View {
    let property: String
    let value: String

    @State private var isExpanded: Bool = false

    /// Threshold for showing expand/collapse
    private var isLongValue: Bool {
        value.count > 40
    }

    /// Parsed color from value (if any)
    private var parsedColor: Color? {
        CSSColorParser.parse(value)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Color preview swatch
            if let color = parsedColor {
                ColorSwatchView(color: color)
            }

            Text(property)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
            Text(":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

            if isLongValue && !isExpanded {
                Text(value.prefix(35) + "...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if isLongValue {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                UIPasteboard.general.string = "\(property): \(value);"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

/// Expandable URL view with collapse/expand for long URLs
private struct ExpandableURLView: View {
    let url: String
    var onCopy: (() -> Void)?
    @State private var isExpanded: Bool = false

    private var isLongURL: Bool {
        url.count > 60
    }

    private var displayURL: String {
        if isLongURL && !isExpanded {
            // Show domain + truncated path
            if let urlObj = URL(string: url) {
                let host = urlObj.host ?? ""
                let path = urlObj.path
                let truncatedPath = path.count > 20 ? String(path.prefix(20)) + "..." : path
                return host + truncatedPath
            }
            return String(url.prefix(50)) + "..."
        }
        return url
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Source URL:")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                if isLongURL {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if isLongURL {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    Text(displayURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(isExpanded ? .leading : .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .textSelection(.enabled)

            GlassActionButton("Copy URL", icon: "doc.on.doc") {
                UIPasteboard.general.string = url
                onCopy?()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Small color swatch for CSS color preview
private struct ColorSwatchView: View {
    let color: Color

    var body: some View {
        ZStack {
            // Checkerboard for transparent colors
            CheckerboardPattern()
                .frame(width: 14, height: 14)

            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

/// Checkerboard pattern for showing transparency
private struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 4
            let rows = Int(ceil(size.height / cellSize))
            let cols = Int(ceil(size.width / cellSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? .white : Color(white: 0.85))
                    )
                }
            }
        }
    }
}

struct CSSRuleInfo: Identifiable {
    let id: Int
    let selector: String
    let cssText: String
}

/// Represents parsed CSS content - either flat properties or nested blocks
enum ParsedCSSContent {
    case properties([(property: String, value: String)])
    case keyframes([(selector: String, properties: [(property: String, value: String)])])
}

struct CSSRuleRow: View {
    let rule: CSSRuleInfo
    @State private var isExpanded: Bool = false

    /// Parsed CSS content from cssText
    private var parsedContent: ParsedCSSContent {
        CSSFormatter.parseRule(from: rule.cssText)
    }

    /// Count for badge display
    private var itemCount: Int {
        switch parsedContent {
        case .properties(let props):
            return props.count
        case .keyframes(let frames):
            return frames.count
        }
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
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(rule.selector)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(itemCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch parsedContent {
        case .properties(let props):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(props.enumerated()), id: \.offset) { _, prop in
                    FormattedCSSPropertyRow(property: prop.property, value: prop.value)
                }
            }
        case .keyframes(let frames):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(frames.enumerated()), id: \.offset) { _, frame in
                    KeyframeBlockView(selector: frame.selector, properties: frame.properties)
                }
            }
        }
    }
}

/// View for displaying a keyframe block (e.g., "0% { transform: ... }")
private struct KeyframeBlockView: View {
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

/// Formatted CSS property row with syntax highlighting and color preview
private struct FormattedCSSPropertyRow: View {
    let property: String
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    private var parsedColor: Color? {
        CSSColorParser.parse(value)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Color swatch if applicable
            if let color = parsedColor {
                ColorSwatchView(color: color)
            }

            // Property name (keyword color)
            Text(property)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CSSSyntaxColors.property(for: colorScheme))

            Text(":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

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

/// Syntax highlighted value text
private struct FormattedValueText: View {
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(value)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(valueColor)
    }

    private var valueColor: Color {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()

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

/// CSS syntax highlighting colors with dark/light mode support
/// Based on WCAG accessibility guidelines (4.5:1 contrast ratio)
private enum CSSSyntaxColors {
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

// MARK: - Previews

#Preview("Element Detail") {
    ElementDetailView(
        node: DOMNode(
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "main", "class": "container flex"],
            textContent: nil,
            children: []
        ),
        navigator: nil
    )
}

#Preview("Stylesheet Detail") {
    StylesheetDetailView(
        sheet: StylesheetInfo(index: 0, href: "styles.css", rulesCount: 42, isExternal: true, mediaText: nil, cssContent: nil),
        index: 0,
        navigator: nil
    )
}

#Preview("Script Detail") {
    ScriptDetailView(
        script: ScriptInfo(index: 0, src: "app.js", isExternal: true, isModule: true, isAsync: false, isDefer: true, content: nil),
        index: 0,
        navigator: nil
    )
}
