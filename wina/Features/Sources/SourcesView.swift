//
//  SourcesView.swift
//  wina
//
//  Chrome DevTools style Sources panel - DOM Tree, Stylesheets, Scripts.
//

import Combine
import Runestone
import SwiftUI
import TreeSitterHTMLRunestone

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

// MARK: - Elements View Mode

enum ElementsViewMode: String, CaseIterable {
    case tree = "Tree"
    case raw = "Raw HTML"

    var icon: String {
        switch self {
        case .tree: return "list.bullet.indent"
        case .raw: return "doc.plaintext"
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
    @Published var rawHTML: String?
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

    // MARK: - Raw HTML

    static let rawHTMLScript = """
    (function() {
        const doctype = document.doctype;
        let doctypeStr = '';
        if (doctype) {
            doctypeStr = '<!DOCTYPE ' + doctype.name;
            if (doctype.publicId) {
                doctypeStr += ' PUBLIC "' + doctype.publicId + '"';
            }
            if (doctype.systemId) {
                doctypeStr += ' "' + doctype.systemId + '"';
            }
            doctypeStr += '>\\n';
        }
        return doctypeStr + document.documentElement.outerHTML;
    })();
    """

    func fetchRawHTML() async {
        guard let navigator else {
            errorMessage = "Navigator not available"
            return
        }

        isLoading = true
        errorMessage = nil

        if let result = await navigator.evaluateJavaScript(Self.rawHTMLScript) as? String {
            rawHTML = result
        } else {
            errorMessage = "Failed to fetch HTML"
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
        rawHTML = nil
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
    @State private var debouncedSearchText: String = ""

    // Elements view mode (tree vs raw HTML)
    @State private var elementsViewMode: ElementsViewMode = .tree

    // Search navigation for Elements (Tree mode)
    @State private var currentMatchIndex: Int = 0
    @State private var matchingNodePaths: [[String]] = []

    // Search navigation for Elements (Raw HTML mode)
    @State private var currentRawMatchIndex: Int = 0
    @State private var rawMatchLineIndices: [Int] = []
    @State private var cachedRawHTMLLines: [String] = []

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
        .task(id: searchText) {
            // Debounce search: wait 200ms before processing
            guard !searchText.isEmpty else {
                debouncedSearchText = ""
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
        }
        .onChange(of: selectedTab) { _, _ in
            // Clear search when switching tabs
            searchText = ""
            currentMatchIndex = 0
            matchingNodePaths = []
            currentRawMatchIndex = 0
            rawMatchLineIndices = []

            Task {
                await fetchCurrentTab()
            }
        }
        .onChange(of: debouncedSearchText) { _, _ in
            // Trigger search when debounced text changes
            if selectedTab == .elements {
                if elementsViewMode == .tree {
                    updateMatchingNodes()
                } else {
                    updateRawHTMLMatches()
                }
            }
        }
        .onChange(of: manager.domTree?.id) { _, _ in
            // Update search results when DOM tree loads
            if !debouncedSearchText.isEmpty && elementsViewMode == .tree {
                updateMatchingNodes()
            }
        }
        .onChange(of: manager.rawHTML) { _, newHTML in
            // Cache raw HTML lines for search
            if let html = newHTML {
                cachedRawHTMLLines = html.components(separatedBy: .newlines)
                // Update search results if needed
                if !debouncedSearchText.isEmpty && elementsViewMode == .raw {
                    updateRawHTMLMatches()
                }
            } else {
                cachedRawHTMLLines = []
            }
        }
        .onChange(of: elementsViewMode) { _, newMode in
            // Update search results when view mode changes
            if !debouncedSearchText.isEmpty {
                if newMode == .tree {
                    updateMatchingNodes()
                } else {
                    updateRawHTMLMatches()
                }
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
            if elementsViewMode == .tree {
                await manager.fetchDOMTree()
            } else {
                await manager.fetchRawHTML()
            }
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
        guard !debouncedSearchText.isEmpty else { return manager.stylesheets }
        return manager.stylesheets.filter {
            $0.href?.localizedCaseInsensitiveContains(debouncedSearchText) == true
        }
    }

    private var filteredScripts: [ScriptInfo] {
        guard !debouncedSearchText.isEmpty else { return manager.scripts }
        return manager.scripts.filter {
            $0.src?.localizedCaseInsensitiveContains(debouncedSearchText) == true
        }
    }

    private func shareCurrentTab() {
        var content = ""
        switch selectedTab {
        case .elements:
            if elementsViewMode == .raw, let html = manager.rawHTML {
                content = html
            } else if let root = manager.domTree {
                content = serializeDOMTree(root, depth: 0)
            }
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

    private func serializeDOMTree(_ node: DOMNode, depth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        var result = ""

        if node.isText {
            if let text = node.textContent {
                result = "\(indent)\(text)\n"
            }
        } else {
            var tag = "<\(node.nodeName.lowercased())"
            for (key, value) in node.attributes {
                tag += " \(key)=\"\(value)\""
            }
            tag += ">"
            result = "\(indent)\(tag)\n"

            for child in node.children {
                result += serializeDOMTree(child, depth: depth + 1)
            }

            result += "\(indent)</\(node.nodeName.lowercased())>\n"
        }

        return result
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(selectedTab == .elements ? "Search" : "Filter", text: $searchText)
                .textFieldStyle(.plain)

            // Search navigation - always reserve space
            Group {
                if selectedTab == .elements && !searchText.isEmpty {
                    searchNavigationView
                }
            }
            .frame(minWidth: 100, alignment: .trailing)

            // Clear button - always reserve space
            Button {
                clearSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(searchText.isEmpty ? 0 : 1)
            .disabled(searchText.isEmpty)

            Divider()
                .frame(height: 20)
                .opacity(selectedTab == .elements ? 1 : 0)

            // View mode toggle - always reserve space
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    elementsViewMode = elementsViewMode == .tree ? .raw : .tree
                }
                Task {
                    await fetchCurrentTab()
                }
            } label: {
                Image(systemName: elementsViewMode.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(elementsViewMode == .raw ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(selectedTab == .elements ? 1 : 0)
            .disabled(selectedTab != .elements)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var searchNavigationView: some View {
        if elementsViewMode == .tree {
            treeSearchNavigation
        } else {
            rawHTMLSearchNavigation
        }
    }

    @ViewBuilder
    private var treeSearchNavigation: some View {
        if matchingNodePaths.isEmpty {
            matchCountBadge("0")
        } else {
            matchCountBadge("\(currentMatchIndex + 1)/\(matchingNodePaths.count)")
            navigationButtons(
                onPrevious: navigateToPreviousMatch,
                onNext: navigateToNextMatch,
                isDisabled: matchingNodePaths.count <= 1
            )
        }
    }

    @ViewBuilder
    private var rawHTMLSearchNavigation: some View {
        if rawMatchLineIndices.isEmpty {
            matchCountBadge("0")
        } else {
            matchCountBadge("\(currentRawMatchIndex + 1)/\(rawMatchLineIndices.count)")
            navigationButtons(
                onPrevious: navigateToPreviousRawMatch,
                onNext: navigateToNextRawMatch,
                isDisabled: rawMatchLineIndices.count <= 1
            )
        }
    }

    private func matchCountBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.1), in: Capsule())
    }

    private func navigationButtons(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        isDisabled: Bool
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            Button(action: onNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
        .foregroundStyle(isDisabled ? .tertiary : .primary)
    }

    private func clearSearch() {
        searchText = ""
        currentMatchIndex = 0
        matchingNodePaths = []
        currentRawMatchIndex = 0
        rawMatchLineIndices = []
    }

    private func updateMatchingNodes() {
        guard let root = manager.domTree, !debouncedSearchText.isEmpty else {
            matchingNodePaths = []
            currentMatchIndex = 0
            return
        }

        let query = debouncedSearchText.lowercased()

        // Run search on background thread
        Task.detached(priority: .userInitiated) {
            let paths = Self.collectMatchingPaths(node: root, currentPath: [], query: query)
            await MainActor.run {
                matchingNodePaths = paths
                currentMatchIndex = paths.isEmpty ? 0 : min(currentMatchIndex, paths.count - 1)
            }
        }
    }

    private static func collectMatchingPaths(node: DOMNode, currentPath: [String], query: String) -> [[String]] {
        let nodePath = currentPath + [node.id.uuidString]
        var paths: [[String]] = []

        let matches =
            node.nodeName.lowercased().contains(query) ||
            (node.attributes["id"]?.lowercased().contains(query) ?? false) ||
            (node.attributes["class"]?.lowercased().contains(query) ?? false) ||
            (node.textContent?.lowercased().contains(query) ?? false)

        if matches && node.isElement {
            paths.append(nodePath)
        }

        for child in node.children {
            paths.append(contentsOf: collectMatchingPaths(node: child, currentPath: nodePath, query: query))
        }

        return paths
    }

    private func navigateToPreviousMatch() {
        guard !matchingNodePaths.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchingNodePaths.count) % matchingNodePaths.count
    }

    private func navigateToNextMatch() {
        guard !matchingNodePaths.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchingNodePaths.count
    }

    private func updateRawHTMLMatches() {
        guard !debouncedSearchText.isEmpty else {
            rawMatchLineIndices = []
            currentRawMatchIndex = 0
            return
        }

        let query = debouncedSearchText.lowercased()
        let lines = cachedRawHTMLLines

        // Run search on background thread
        Task.detached(priority: .userInitiated) {
            var indices: [Int] = []
            for (index, line) in lines.enumerated() where line.lowercased().contains(query) {
                indices.append(index)
            }
            await MainActor.run {
                rawMatchLineIndices = indices
                currentRawMatchIndex = indices.isEmpty ? 0 : min(currentRawMatchIndex, indices.count - 1)
            }
        }
    }

    private func navigateToPreviousRawMatch() {
        guard !rawMatchLineIndices.isEmpty else { return }
        currentRawMatchIndex = (currentRawMatchIndex - 1 + rawMatchLineIndices.count) % rawMatchLineIndices.count
    }

    private func navigateToNextRawMatch() {
        guard !rawMatchLineIndices.isEmpty else { return }
        currentRawMatchIndex = (currentRawMatchIndex + 1) % rawMatchLineIndices.count
    }

    private var currentMatchPath: [String]? {
        guard !matchingNodePaths.isEmpty, currentMatchIndex < matchingNodePaths.count else { return nil }
        return matchingNodePaths[currentMatchIndex]
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
        } else {
            switch elementsViewMode {
            case .tree:
                if let root = manager.domTree {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                DOMNodeRow(
                                    node: root,
                                    depth: 0,
                                    manager: manager,
                                    searchText: searchText,
                                    currentMatchPath: currentMatchPath,
                                    onSelect: { node in
                                        selectedNode = node
                                    }
                                )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: currentMatchIndex) { _, _ in
                            scrollToCurrentMatch(proxy: proxy)
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                } else {
                    emptyView("No DOM tree available")
                }
            case .raw:
                if let html = manager.rawHTML {
                    HTMLSyntaxView(
                        html: html,
                        searchText: searchText,
                        currentMatchLineIndex: rawMatchLineIndices.isEmpty ? nil : currentRawMatchIndex,
                        matchingLineIndices: rawMatchLineIndices
                    )
                } else {
                    emptyView("No HTML available")
                }
            }
        }
    }

    private func scrollToCurrentMatch(proxy: ScrollViewProxy) {
        guard let path = currentMatchPath, let targetId = path.last else { return }
        // Delay scroll to allow parent nodes to expand first
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
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
    let currentMatchPath: [String]?
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

    /// Check if this is the currently focused match
    private var isCurrentMatch: Bool {
        guard let path = currentMatchPath else { return false }
        return path.last == node.id.uuidString
    }

    /// Check if this node is in the path to the current match (for auto-expand)
    private var isInCurrentMatchPath: Bool {
        guard let path = currentMatchPath else { return false }
        return path.contains(node.id.uuidString)
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
                if isCurrentMatch {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.3))
                } else if matchesSearch {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                }
            }
            .id(node.id.uuidString)
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
                        currentMatchPath: currentMatchPath,
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
        .onChange(of: currentMatchPath) { _, _ in
            // Auto-expand if this node is in the path to the current match
            if isInCurrentMatchPath && !isExpanded {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded = true
                }
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

// MARK: - HTML Syntax View (Runestone with Tree-sitter virtualization)

struct HTMLSyntaxView: View {
    let html: String
    let searchText: String
    let currentMatchLineIndex: Int?
    let matchingLineIndices: [Int]

    var body: some View {
        HTMLTextView(
            text: html,
            searchText: searchText,
            currentMatchIndex: currentMatchLineIndex,
            matchingLineIndices: matchingLineIndices
        )
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - HTML Text View (Runestone with virtualization)

struct HTMLTextView: UIViewRepresentable {
    let text: String
    let searchText: String
    let currentMatchIndex: Int?
    let matchingLineIndices: [Int]

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()

        // Read-only mode with text selection
        textView.isEditable = false
        textView.isSelectable = true

        // Disable line wrapping for horizontal scroll
        textView.isLineWrappingEnabled = false

        // Visual settings
        textView.showLineNumbers = true
        textView.backgroundColor = .systemBackground
        textView.lineHeightMultiplier = 1.2

        // Set up theme and state
        context.coordinator.setupTextView(textView, with: text)

        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        let coordinator = context.coordinator

        // Update text if changed
        if coordinator.lastText != text {
            coordinator.lastText = text
            coordinator.setupTextView(textView, with: text)
        }

        // Handle search - Runestone has built-in search support
        if coordinator.lastSearchText != searchText {
            coordinator.lastSearchText = searchText

            if searchText.isEmpty {
                textView.highlightedRanges = []
            } else {
                coordinator.highlightSearchResults(in: textView, searchText: searchText)
            }
        }

        // Scroll to current match
        if coordinator.lastMatchIndex != currentMatchIndex {
            coordinator.lastMatchIndex = currentMatchIndex

            if let matchIdx = currentMatchIndex, matchIdx < matchingLineIndices.count {
                let lineIndex = matchingLineIndices[matchIdx]
                _ = textView.goToLine(lineIndex)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastText: String = ""
        var lastSearchText: String = ""
        var lastMatchIndex: Int?

        func setupTextView(_ textView: TextView, with text: String) {
            // Create state with HTML language for syntax highlighting
            DispatchQueue.global(qos: .userInitiated).async {
                let state = TextViewState(text: text, theme: HTMLViewerTheme(), language: .html)
                DispatchQueue.main.async {
                    textView.setState(state)
                }
            }
        }

        func highlightSearchResults(in textView: TextView, searchText: String) {
            // Use Runestone's built-in search
            let query = SearchQuery(text: searchText, matchMethod: .contains, isCaseSensitive: false)
            let results = textView.search(for: query)

            // Convert search results to highlighted ranges
            let highlightedRanges = results.map { result in
                HighlightedRange(range: result.range, color: .systemYellow.withAlphaComponent(0.4))
            }
            textView.highlightedRanges = highlightedRanges
        }
    }
}

// MARK: - HTML Viewer Theme (Runestone Theme)

final class HTMLViewerTheme: Runestone.Theme {
    let backgroundColor: UIColor = .systemBackground
    let userInterfaceStyle: UIUserInterfaceStyle = .unspecified

    let font: UIFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    let textColor: UIColor = .label

    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .separator

    let lineNumberColor: UIColor = .tertiaryLabel
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 10, weight: .regular)

    let selectedLineBackgroundColor: UIColor = .systemGray6
    let selectedLinesLineNumberColor: UIColor = .secondaryLabel
    let selectedLinesGutterBackgroundColor: UIColor = .tertiarySystemBackground

    let invisibleCharactersColor: UIColor = .tertiaryLabel

    let pageGuideHairlineColor: UIColor = .separator
    let pageGuideBackgroundColor: UIColor = .secondarySystemBackground

    let markedTextBackgroundColor: UIColor = .systemYellow.withAlphaComponent(0.2)

    func textColor(for highlightName: String) -> UIColor? {
        switch highlightName {
        case "tag", "tag.builtin":
            return UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0)
        case "attribute":
            return UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0)
        case "string", "string.special":
            return UIColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1.0)
        case "comment":
            return .secondaryLabel
        case "punctuation", "punctuation.bracket", "punctuation.delimiter":
            return .tertiaryLabel
        default:
            return nil
        }
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        []
    }
}

// MARK: - Preview

#Preview {
    SourcesView(navigator: nil)
}
