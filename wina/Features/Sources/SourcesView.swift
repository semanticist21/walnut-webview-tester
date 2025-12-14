//
//  SourcesView.swift
//  wina
//
//  Chrome DevTools style Sources panel - DOM Tree, Stylesheets, Scripts.
//

import Combine
import SwiftUI

// MARK: - Source Tab

enum SourceTab: String, CaseIterable {
    case elements = "Elements"
    case styles = "Styles"
    case scripts = "Scripts"

    var icon: String {
        switch self {
        case .elements: return "chevron.left.forwardslash.chevron.right"
        case .styles: return "paintbrush"
        case .scripts: return "doc.text"
        }
    }
}

// MARK: - Models

struct DOMNode: Identifiable, Hashable {
    let id = UUID()
    let nodeType: Int
    let nodeName: String
    let attributes: [String: String]
    let textContent: String?
    var children: [DOMNode]
    var isExpanded: Bool = false

    var isElement: Bool { nodeType == 1 }
    var isText: Bool { nodeType == 3 }

    var displayName: String {
        if isText {
            return textContent ?? ""
        }
        var result = nodeName.lowercased()
        if let id = attributes["id"] {
            result += "#\(id)"
        }
        if let className = attributes["class"], !className.isEmpty {
            let classes = className.split(separator: " ").prefix(2).joined(separator: ".")
            result += ".\(classes)"
        }
        return result
    }
}

struct StylesheetInfo: Identifiable {
    let id = UUID()
    let index: Int
    let href: String?
    let rulesCount: Int
    let isExternal: Bool
    let mediaText: String?
}

struct ScriptInfo: Identifiable {
    let id = UUID()
    let index: Int
    let src: String?
    let isExternal: Bool
    let isModule: Bool
    let isAsync: Bool
    let isDefer: Bool
}

// MARK: - Sources Manager

@MainActor
class SourcesManager: ObservableObject {
    @Published var domTree: DOMNode?
    @Published var stylesheets: [StylesheetInfo] = []
    @Published var scripts: [ScriptInfo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private weak var navigator: WebViewNavigator?

    func setNavigator(_ navigator: WebViewNavigator?) {
        self.navigator = navigator
    }

    // MARK: - DOM Tree

    static let domTreeScript = """
    (function() {
        function serializeNode(node, depth) {
            if (depth > 50) return null;
            const obj = {
                type: node.nodeType,
                name: node.nodeName,
                attrs: {},
                text: null,
                children: []
            };
            if (node.nodeType === 1) {
                for (const attr of node.attributes) {
                    obj.attrs[attr.name] = attr.value;
                }
            }
            if (node.nodeType === 3) {
                const text = node.textContent.trim();
                if (text.length === 0) return null;
                obj.text = text.substring(0, 200);
            }
            for (const child of node.childNodes) {
                const serialized = serializeNode(child, depth + 1);
                if (serialized) obj.children.push(serialized);
            }
            return obj;
        }
        return JSON.stringify(serializeNode(document.documentElement, 0));
    })();
    """

    func fetchDOMTree() async {
        guard let navigator else {
            errorMessage = "Navigator not available"
            return
        }

        isLoading = true
        errorMessage = nil

        if let result = await navigator.evaluateJavaScript(Self.domTreeScript) as? String,
           let data = result.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                domTree = parseNode(json)
            } catch {
                errorMessage = "Failed to parse DOM: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Failed to fetch DOM tree"
        }

        isLoading = false
    }

    private func parseNode(_ json: [String: Any]?) -> DOMNode? {
        guard let json else { return nil }

        let nodeType = json["type"] as? Int ?? 0
        let nodeName = json["name"] as? String ?? ""
        let attrs = json["attrs"] as? [String: String] ?? [:]
        let text = json["text"] as? String
        let childrenJson = json["children"] as? [[String: Any]] ?? []

        let children = childrenJson.compactMap { parseNode($0) }

        return DOMNode(
            nodeType: nodeType,
            nodeName: nodeName,
            attributes: attrs,
            textContent: text,
            children: children
        )
    }

    // MARK: - Stylesheets

    static let stylesheetsScript = """
    (function() {
        const sheets = [];
        for (const sheet of document.styleSheets) {
            let rulesCount = 0;
            try {
                rulesCount = sheet.cssRules ? sheet.cssRules.length : 0;
            } catch(e) {}
            sheets.push({
                href: sheet.href,
                rulesCount: rulesCount,
                isExternal: !!sheet.href,
                media: sheet.media ? sheet.media.mediaText : null
            });
        }
        return JSON.stringify(sheets);
    })();
    """

    func fetchStylesheets() async {
        guard let navigator else {
            errorMessage = "Navigator not available"
            return
        }

        isLoading = true
        errorMessage = nil

        if let result = await navigator.evaluateJavaScript(Self.stylesheetsScript) as? String,
           let data = result.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            stylesheets = jsonArray.enumerated().map { idx, item in
                StylesheetInfo(
                    index: idx,
                    href: item["href"] as? String,
                    rulesCount: item["rulesCount"] as? Int ?? 0,
                    isExternal: item["isExternal"] as? Bool ?? false,
                    mediaText: item["media"] as? String
                )
            }
        } else {
            errorMessage = "Failed to fetch stylesheets"
        }

        isLoading = false
    }

    // MARK: - Scripts

    static let scriptsScript = """
    (function() {
        const scripts = [];
        for (const script of document.scripts) {
            scripts.push({
                src: script.src || null,
                isExternal: !!script.src,
                isModule: script.type === 'module',
                isAsync: script.async,
                isDefer: script.defer
            });
        }
        return JSON.stringify(scripts);
    })();
    """

    func fetchScripts() async {
        guard let navigator else {
            errorMessage = "Navigator not available"
            return
        }

        isLoading = true
        errorMessage = nil

        if let result = await navigator.evaluateJavaScript(Self.scriptsScript) as? String,
           let data = result.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            scripts = jsonArray.enumerated().map { idx, item in
                ScriptInfo(
                    index: idx,
                    src: item["src"] as? String,
                    isExternal: item["isExternal"] as? Bool ?? false,
                    isModule: item["isModule"] as? Bool ?? false,
                    isAsync: item["isAsync"] as? Bool ?? false,
                    isDefer: item["isDefer"] as? Bool ?? false
                )
            }
        } else {
            errorMessage = "Failed to fetch scripts"
        }

        isLoading = false
    }

    func clear() {
        domTree = nil
        stylesheets = []
        scripts = []
        errorMessage = nil
    }
}

// MARK: - Sources View

struct SourcesView: View {
    let navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SourcesManager()
    @State private var selectedTab: SourceTab = .elements
    @State private var shareItem: SourcesShareContent?
    @State private var lastURL: URL?
    @State private var searchText: String = ""

    // Detail view selections
    @State private var selectedNode: DOMNode?
    @State private var selectedStylesheet: StylesheetInfo?
    @State private var selectedScript: ScriptInfo?

    var body: some View {
        VStack(spacing: 0) {
            sourcesHeader

            searchBar

            tabPicker

            Divider()

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .elements:
                    elementsContent
                case .styles:
                    stylesContent
                case .scripts:
                    scriptsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            manager.setNavigator(navigator)
            lastURL = navigator?.currentURL
            Task {
                await fetchCurrentTab()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            Task {
                await fetchCurrentTab()
            }
        }
        .onChange(of: navigator?.currentURL) { _, newURL in
            // Auto-refresh when page URL changes
            if let newURL, newURL != lastURL {
                lastURL = newURL
                Task {
                    // Small delay to let page load
                    try? await Task.sleep(for: .milliseconds(500))
                    await fetchCurrentTab()
                }
            }
        }
        .sheet(item: $shareItem) { item in
            SourcesShareSheet(content: item.content)
        }
        .sheet(item: $selectedNode) { node in
            ElementDetailView(node: node, navigator: navigator)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStylesheet) { sheet in
            StylesheetDetailView(sheet: sheet, index: sheet.index, navigator: navigator)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedScript) { script in
            ScriptDetailView(script: script, index: script.index, navigator: navigator)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
    }

    private func fetchCurrentTab() async {
        switch selectedTab {
        case .elements:
            await manager.fetchDOMTree()
        case .styles:
            await manager.fetchStylesheets()
        case .scripts:
            await manager.fetchScripts()
        }
    }

    private var currentItemCount: Int {
        switch selectedTab {
        case .elements:
            return manager.domTree != nil ? 1 : 0
        case .styles:
            return filteredStylesheets.count
        case .scripts:
            return filteredScripts.count
        }
    }

    private var filteredStylesheets: [StylesheetInfo] {
        guard !searchText.isEmpty else { return manager.stylesheets }
        return manager.stylesheets.filter {
            $0.href?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var filteredScripts: [ScriptInfo] {
        guard !searchText.isEmpty else { return manager.scripts }
        return manager.scripts.filter {
            $0.src?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private func shareCurrentTab() {
        var content = ""
        switch selectedTab {
        case .elements:
            content = "DOM Tree exported"
        case .styles:
            content = filteredStylesheets
                .map { $0.href ?? "<style> tag (\($0.rulesCount) rules)" }
                .joined(separator: "\n")
        case .scripts:
            content = filteredScripts
                .map { $0.src ?? "<inline script>" }
                .joined(separator: "\n")
        }
        shareItem = SourcesShareContent(content: content)
    }

    // MARK: - Header

    private var sourcesHeader: some View {
        DevToolsHeader(
            title: "Sources",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(icon: "arrow.clockwise") {
                    Task {
                        await fetchCurrentTab()
                    }
                },
                .init(
                    icon: "square.and.arrow.up",
                    isDisabled: currentItemCount == 0
                ) {
                    shareCurrentTab()
                }
            ],
            rightButtons: []
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(SourceTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Elements Content

    @ViewBuilder
    private var elementsContent: some View {
        if manager.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
        } else if let error = manager.errorMessage {
            errorView(error)
        } else if let root = manager.domTree {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    DOMNodeRow(
                        node: root,
                        depth: 0,
                        manager: manager,
                        searchText: searchText,
                        onSelect: { node in
                            selectedNode = node
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemBackground))
        } else {
            emptyView("No DOM tree available")
        }
    }

    // MARK: - Styles Content

    @ViewBuilder
    private var stylesContent: some View {
        if manager.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
        } else if let error = manager.errorMessage {
            errorView(error)
        } else if manager.stylesheets.isEmpty {
            emptyView("No stylesheets found")
        } else if filteredStylesheets.isEmpty {
            emptyView(searchText.isEmpty ? "No stylesheets found" : "No matches")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredStylesheets) { sheet in
                        StylesheetRow(sheet: sheet)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStylesheet = sheet
                            }
                        Divider()
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Scripts Content

    @ViewBuilder
    private var scriptsContent: some View {
        if manager.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
        } else if let error = manager.errorMessage {
            errorView(error)
        } else if filteredScripts.isEmpty {
            emptyView(searchText.isEmpty ? "No scripts found" : "No matches")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredScripts) { script in
                        ScriptRow(script: script)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedScript = script
                            }
                        Divider()
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Helper Views

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

    private func emptyView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - DOM Node Row

struct DOMNodeRow: View {
    let node: DOMNode
    let depth: Int
    @ObservedObject var manager: SourcesManager
    let searchText: String
    let onSelect: (DOMNode) -> Void

    // HTML, BODY are expanded by default
    @State private var isExpanded: Bool = false

    private var hasChildren: Bool {
        !node.children.isEmpty
    }

    private var shouldExpandByDefault: Bool {
        let name = node.nodeName.uppercased()
        return name == "HTML" || name == "BODY"
    }

    /// Check if this node matches the search text
    private var matchesSearch: Bool {
        guard !searchText.isEmpty else { return false }
        let query = searchText.lowercased()
        // Match tag name
        if node.nodeName.lowercased().contains(query) { return true }
        // Match id
        if let id = node.attributes["id"], id.lowercased().contains(query) { return true }
        // Match class
        if let cls = node.attributes["class"], cls.lowercased().contains(query) { return true }
        // Match text content
        if let text = node.textContent, text.lowercased().contains(query) { return true }
        return false
    }

    /// Check if any descendant matches the search
    private var hasMatchingDescendant: Bool {
        guard !searchText.isEmpty else { return false }
        return node.children.contains { child in
            nodeOrDescendantMatches(child)
        }
    }

    private func nodeOrDescendantMatches(_ node: DOMNode) -> Bool {
        let query = searchText.lowercased()
        if node.nodeName.lowercased().contains(query) { return true }
        if let id = node.attributes["id"], id.lowercased().contains(query) { return true }
        if let cls = node.attributes["class"], cls.lowercased().contains(query) { return true }
        if let text = node.textContent, text.lowercased().contains(query) { return true }
        return node.children.contains { nodeOrDescendantMatches($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node itself
            HStack(spacing: 4) {
                // Expand/collapse button
                if hasChildren {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }

                // Node content
                if node.isText {
                    Text("\"\(node.textContent ?? "")\"")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    nodeLabel
                }

                Spacer()

                // Info button for element nodes
                if node.isElement {
                    Button {
                        onSelect(node)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.vertical, 4)
            .background {
                if matchesSearch {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasChildren {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Children
            if isExpanded {
                ForEach(node.children) { child in
                    DOMNodeRow(
                        node: child,
                        depth: depth + 1,
                        manager: manager,
                        searchText: searchText,
                        onSelect: onSelect
                    )
                }
            }
        }
        .onAppear {
            // Expand HTML, BODY by default
            if shouldExpandByDefault {
                isExpanded = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Auto-expand if descendants match
            if !newValue.isEmpty && hasMatchingDescendant {
                isExpanded = true
            }
        }
    }

    private var nodeLabel: some View {
        HStack(spacing: 2) {
            Text("<")
                .foregroundStyle(.tertiary)
            Text(node.nodeName.lowercased())
                .foregroundStyle(.primary)

            // Show id and class
            if let id = node.attributes["id"] {
                Text(" id")
                    .foregroundStyle(.secondary)
                Text("=\"\(id)\"")
                    .foregroundStyle(.secondary)
            }
            if let className = node.attributes["class"], !className.isEmpty {
                Text(" class")
                    .foregroundStyle(.tertiary)
                Text("=\"\(className.prefix(30))\(className.count > 30 ? "..." : "")\"")
                    .foregroundStyle(.tertiary)
            }

            Text(hasChildren ? ">" : "/>")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, design: .monospaced))
        .lineLimit(1)
    }
}

// MARK: - Stylesheet Row

struct StylesheetRow: View {
    let sheet: StylesheetInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: sheet.isExternal ? "link" : "doc.text")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack {
                    if let href = sheet.href {
                        Text(URL(string: href)?.lastPathComponent ?? href)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    } else {
                        Text("<style> tag")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(sheet.rulesCount) rules")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }

                // URL (if external)
                if let href = sheet.href {
                    Text(href)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // Media query
                if let media = sheet.mediaText, !media.isEmpty {
                    Text("@media \(media)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Script Row

struct ScriptRow: View {
    let script: ScriptInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon with lock overlay for external scripts
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: script.isExternal ? "link" : "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)

                if script.isExternal {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .offset(x: 2, y: 2)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack {
                    if let src = script.src {
                        Text(URL(string: src)?.lastPathComponent ?? src)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    } else {
                        Text("<inline script>")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Badges
                    HStack(spacing: 4) {
                        if script.isModule {
                            badge("module")
                        }
                        if script.isAsync {
                            badge("async")
                        }
                        if script.isDefer {
                            badge("defer")
                        }
                    }
                }

                // URL (if external)
                if let src = script.src {
                    Text(src)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // CORS notice for external scripts
                if script.isExternal {
                    Text("External (view-only metadata)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.1), in: Capsule())
    }
}

// MARK: - Share Content

struct SourcesShareContent: Identifiable {
    let id = UUID()
    let content: String
}

// MARK: - Share Sheet

struct SourcesShareSheet: UIViewControllerRepresentable {
    let content: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    SourcesView(navigator: nil)
}
