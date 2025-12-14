//
//  SourceDetailViews.swift
//  wina
//
//  Detail views for Elements, Stylesheets, and Scripts - Chrome DevTools style.
//

import SwiftUI

// MARK: - Element Detail View

struct ElementDetailView: View {
    let node: DOMNode
    let navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @State private var computedStyles: [String: String] = [:]
    @State private var innerHTML: String = ""
    @State private var outerHTML: String = ""
    @State private var isLoading: Bool = true
    @State private var selectedSection: ElementSection = .attributes

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
                    Button {
                        UIPasteboard.general.string = outerHTML
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
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
                    Button {
                        UIPasteboard.general.string = innerHTML
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
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

        async let stylesResult = navigator.evaluateJavaScript(stylesScript)
        async let htmlResult = navigator.evaluateJavaScript(htmlScript)

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

        isLoading = false
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
        case .styles:
            let text = computedStyles.map { "\($0.key): \($0.value);" }.joined(separator: "\n")
            UIPasteboard.general.string = text
        case .html:
            UIPasteboard.general.string = outerHTML
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
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("External Script")
                .font(.headline)

            Text("Cross-origin scripts cannot be viewed due to browser security restrictions (CORS policy).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let src = script.src {
                VStack(spacing: 8) {
                    Text("Source URL:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(src)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = src
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Text("Only inline <script> content can be viewed in WKWebView.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
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
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
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

    var body: some View {
        HStack(spacing: 4) {
            Text(property)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
            Text(":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
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
        .padding(.vertical, 2)
    }
}

struct CSSRuleInfo: Identifiable {
    let id: Int
    let selector: String
    let cssText: String
}

struct CSSRuleRow: View {
    let rule: CSSRuleInfo
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
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
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(rule.cssText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isExpanded)
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
        sheet: StylesheetInfo(index: 0, href: "styles.css", rulesCount: 42, isExternal: true, mediaText: nil),
        index: 0,
        navigator: nil
    )
}

#Preview("Script Detail") {
    ScriptDetailView(
        script: ScriptInfo(index: 0, src: "app.js", isExternal: true, isModule: true, isAsync: false, isDefer: true),
        index: 0,
        navigator: nil
    )
}
