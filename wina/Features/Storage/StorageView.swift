//
//  StorageView.swift
//  wina
//
//  Web Storage debugging view for WKWebView.
//  Displays localStorage, sessionStorage, and cookies.
//

import SwiftUI
import SwiftUIBackports

// MARK: - Cookie Metadata

struct CookieMetadata: Equatable {
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    let sameSitePolicy: String?

    var isSession: Bool { expiresDate == nil }

    init(from cookie: HTTPCookie) {
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
        if let policy = cookie.sameSitePolicy {
            self.sameSitePolicy = policy.rawValue
        } else {
            self.sameSitePolicy = nil
        }
    }
}

// MARK: - Storage Item Model

struct StorageItem: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
    let storageType: StorageType
    var cookieMetadata: CookieMetadata?

    enum StorageType: String, CaseIterable {
        case localStorage
        case sessionStorage
        case cookies

        var icon: String {
            switch self {
            case .localStorage: return "internaldrive"
            case .sessionStorage: return "clock"
            case .cookies: return "birthday.cake"
            }
        }

        var label: String {
            switch self {
            case .localStorage: return "Local"
            case .sessionStorage: return "Session"
            case .cookies: return "Cookies"
            }
        }

        var sortOrder: Int {
            switch self {
            case .localStorage: return 0
            case .sessionStorage: return 1
            case .cookies: return 2
            }
        }

        var tintColor: Color {
            switch self {
            case .localStorage: return .blue
            case .sessionStorage: return .orange
            case .cookies: return .green
            }
        }
    }

    static func == (lhs: StorageItem, rhs: StorageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.key == rhs.key &&
        lhs.value == rhs.value &&
        lhs.storageType == rhs.storageType &&
        lhs.cookieMetadata == rhs.cookieMetadata
    }
}

// MARK: - Storage Value Type

enum StorageValueType {
    case json, number, bool, string, empty

    static func detect(from value: String) -> StorageValueType {
        if value.isEmpty { return .empty }
        if JsonParser.isValidJson(value) { return .json }
        if value.lowercased() == "true" || value.lowercased() == "false" { return .bool }
        if Double(value) != nil { return .number }
        return .string
    }

    var color: Color {
        switch self {
        case .json: return .purple
        case .number: return .blue
        case .bool: return .green
        case .string: return .gray
        case .empty: return .gray.opacity(0.5)
        }
    }

    var badge: TypeBadge? {
        switch self {
        case .json:
            return TypeBadge(text: "JSON", color: .purple, icon: "curlybraces")
        case .number:
            return TypeBadge(text: "Number", color: .blue, icon: "number")
        case .bool:
            return TypeBadge(text: "Boolean", color: .green, icon: "checkmark")
        case .string:
            return TypeBadge(text: "Text", color: .gray, icon: "textformat")
        case .empty:
            return nil
        }
    }

    var label: String {
        switch self {
        case .json: return "JSON"
        case .number: return "Number"
        case .bool: return "Boolean"
        case .string: return "Text"
        case .empty: return "Empty"
        }
    }
}

// MARK: - Storage Manager

protocol StorageNavigator: AnyObject {
    func evaluateJavaScript(_ script: String) async -> Any?
    func getAllCookies() async -> [HTTPCookie]
    func deleteCookie(name: String) async
    func deleteAllCookies() async
}

@Observable
class StorageManager {
    var items: [StorageItem] = []
    var lastRefreshTime: Date?
    var errorMessage: String?
    var currentURL: URL?

    private weak var navigator: StorageNavigator?

    func setNavigator(_ navigator: StorageNavigator?) {
        self.navigator = navigator
    }

    // SWR: Fetch all storage data from WebView (keep stale data while revalidating)
    @MainActor
    func refresh(pageURL: URL? = nil) async {
        guard let navigator else {
            errorMessage = "WebView not connected"
            return
        }

        // If URL changed, clear items immediately to avoid stale data flashing
        if let newURL = pageURL, currentURL != newURL {
            currentURL = newURL
            items.removeAll()
        }
        currentURL = pageURL

        errorMessage = nil

        // Fetch new data in background
        var newItems: [StorageItem] = []

        // Fetch localStorage
        if let localData = await fetchStorage(type: .localStorage, navigator: navigator) {
            newItems.append(contentsOf: localData)
        }

        // Fetch sessionStorage
        if let sessionData = await fetchStorage(type: .sessionStorage, navigator: navigator) {
            newItems.append(contentsOf: sessionData)
        }

        // Fetch cookies
        if let cookieData = await fetchCookies(
            navigator: navigator,
            pageURL: pageURL
        ) {
            newItems.append(contentsOf: cookieData)
        }

        // Update items atomically
        items = newItems
        lastRefreshTime = Date()
    }

    private func fetchStorage(
        type: StorageItem.StorageType,
        navigator: StorageNavigator
    ) async -> [StorageItem]? {
        let storageName = type == .localStorage ? "localStorage" : "sessionStorage"
        let script = """
            (function() {
                try {
                    var result = [];
                    for (var i = 0; i < \(storageName).length; i++) {
                        var key = \(storageName).key(i);
                        var value = \(storageName).getItem(key);
                        result.push({ key: key, value: value });
                    }
                    return JSON.stringify(result);
                } catch(e) {
                    return JSON.stringify({ error: e.message });
                }
            })();
            """

        guard let result = await navigator.evaluateJavaScript(script) as? String,
              let data = result.data(using: .utf8) else {
            return nil
        }

        // Check for error
        if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let error = errorDict["error"] {
            await MainActor.run {
                self.errorMessage = "\(type.label): \(error)"
            }
            return nil
        }

        guard let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return nil
        }

        return items.compactMap { dict in
            guard let key = dict["key"], let value = dict["value"] else { return nil }
            return StorageItem(key: key, value: value, storageType: type)
        }
    }

    private func fetchCookies(
        navigator: StorageNavigator,
        pageURL: URL?
    ) async -> [StorageItem]? {
        // Use native WKHTTPCookieStore for full cookie metadata
        let cookies = await navigator.getAllCookies()
        let host = pageURL?.host?.lowercased()

        let filteredCookies = cookies.filter { cookie in
            guard let host else { return false }
            let domain = cookie.domain.lowercased()
            if domain.hasPrefix(".") {
                let trimmed = domain.dropFirst()
                return host == trimmed || host.hasSuffix(".\(trimmed)")
            }
            return host == domain
        }

        return filteredCookies.map { cookie in
            StorageItem(
                key: cookie.name,
                value: cookie.value,
                storageType: .cookies,
                cookieMetadata: CookieMetadata(from: cookie)
            )
        }
    }

    // Set item in storage
    @MainActor
    func setItem(key: String, value: String, type: StorageItem.StorageType) async -> Bool {
        guard let navigator else { return false }

        // Use JSON encoding for safe JavaScript string escaping
        guard let keyData = try? JSONSerialization.data(withJSONObject: key, options: .fragmentsAllowed),
              let valueData = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
              let jsonKey = String(data: keyData, encoding: .utf8),
              let jsonValue = String(data: valueData, encoding: .utf8)
        else { return false }

        let script: String
        switch type {
        case .localStorage:
            script = "localStorage.setItem(\(jsonKey), \(jsonValue)); true;"
        case .sessionStorage:
            script = "sessionStorage.setItem(\(jsonKey), \(jsonValue)); true;"
        case .cookies:
            let escapedKey = key.replacingOccurrences(of: "=", with: "%3D")
            let escapedValue = value.replacingOccurrences(of: ";", with: "%3B")
            script = "document.cookie = '\(escapedKey)=\(escapedValue)'; true;"
        }

        let result = await navigator.evaluateJavaScript(script)
        return result as? Bool == true
    }

    // Remove item from storage
    @MainActor
    func removeItem(key: String, type: StorageItem.StorageType) async -> Bool {
        guard let navigator else { return false }

        // Use native WKHTTPCookieStore for cookies (more reliable)
        if type == .cookies {
            await navigator.deleteCookie(name: key)
            return true
        }

        let escapedKey = key.replacingOccurrences(of: "'", with: "\\'")

        let script: String
        switch type {
        case .localStorage:
            script = "localStorage.removeItem('\(escapedKey)'); true;"
        case .sessionStorage:
            script = "sessionStorage.removeItem('\(escapedKey)'); true;"
        case .cookies:
            return false  // Handled above
        }

        let result = await navigator.evaluateJavaScript(script)
        return result as? Bool == true
    }

    // Clear all items of a type
    @MainActor
    func clearStorage(type: StorageItem.StorageType) async -> Bool {
        guard let navigator else { return false }

        // Use native WKHTTPCookieStore for cookies (more reliable)
        if type == .cookies {
            await navigator.deleteAllCookies()
            return true
        }

        let script: String
        switch type {
        case .localStorage:
            script = "localStorage.clear(); true;"
        case .sessionStorage:
            script = "sessionStorage.clear(); true;"
        case .cookies:
            return false  // Handled above
        }

        let result = await navigator.evaluateJavaScript(script)
        return result as? Bool == true
    }

    func clear() {
        items.removeAll()
        lastRefreshTime = nil
        errorMessage = nil
    }
}

extension WebViewNavigator: StorageNavigator {}

// MARK: - Storage View

struct StorageShareContent: Identifiable {
    let id = UUID()
    let content: String
}

struct StorageView: View {
    let storageManager: StorageManager
    let navigator: WebViewNavigator?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: StorageItem.StorageType = .localStorage
    @State private var showsAllStorage: Bool = false
    @State private var searchText: String = ""
    @State private var shareItem: StorageShareContent?
    @State private var selectedItem: StorageItem?
    @State private var showAddSheet: Bool = false
    @State private var lastObservedURL: URL?
    @State private var urlCheckTimer: Timer?
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?

    private var filteredItems: [StorageItem] {
        var result: [StorageItem]
        if showsAllStorage {
            result = storageManager.items
        } else {
            result = storageManager.items.filter { $0.storageType == selectedType }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.key.localizedCaseInsensitiveContains(searchText)
                    || $0.value.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { lhs, rhs in
            if showsAllStorage, lhs.storageType != rhs.storageType {
                return lhs.storageType.sortOrder < rhs.storageType.sortOrder
            }
            return lhs.key < rhs.key
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            storageHeader
            searchBar
            if !showsAllStorage {
                storageTypePicker
            }

            Divider()

            if filteredItems.isEmpty && searchText.isEmpty {
                emptyState
            } else if filteredItems.isEmpty {
                noMatchState
            } else {
                tableHeader
                itemList
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(content: item.content)
        }
        .sheet(item: $selectedItem) { item in
            StorageEditSheet(
                item: item,
                storageManager: storageManager,
                onSave: {
                    Task { await storageManager.refresh(pageURL: navigator?.currentURL) }
                },
                onDelete: {
                    Task { await storageManager.refresh(pageURL: navigator?.currentURL) }
                }
            )
        }
        .sheet(isPresented: $showAddSheet) {
            StorageAddSheet(
                storageManager: storageManager,
                storageType: selectedType,
                onSave: {
                    Task { await storageManager.refresh(pageURL: navigator?.currentURL) }
                }
            )
        }
        .task {
            await AdManager.shared.showInterstitialAd(
                options: AdOptions(id: "storage_devtools"),
                adUnitId: AdManager.interstitialAdUnitId
            )
            storageManager.setNavigator(navigator)
            lastObservedURL = navigator?.currentURL
            await storageManager.refresh(pageURL: navigator?.currentURL)
        }
        .onChange(of: navigator?.currentURL) { _, newURL in
            if newURL != lastObservedURL {
                lastObservedURL = newURL
                Task { await storageManager.refresh(pageURL: newURL) }
            }
        }
        .onAppear {
            // Start timer to detect URL changes even during swipe navigation
            urlCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                if navigator?.currentURL != lastObservedURL {
                    lastObservedURL = navigator?.currentURL
                    Task { await storageManager.refresh(pageURL: navigator?.currentURL) }
                }
            }
        }
        .onDisappear {
            // Stop timer when drawer closes
            urlCheckTimer?.invalidate()
            urlCheckTimer = nil
        }
    }

    // MARK: - Storage Header

    private var storageHeader: some View {
        DevToolsHeader(
            title: "Storage",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(
                    icon: "trash",
                    isDisabled: filteredItems.isEmpty || showsAllStorage
                ) {
                    Task {
                        if await storageManager.clearStorage(type: selectedType) {
                            await storageManager.refresh(pageURL: navigator?.currentURL)
                        }
                    }
                },
                .init(
                    icon: "square.and.arrow.up",
                    isDisabled: filteredItems.isEmpty
                ) {
                    shareItem = StorageShareContent(content: exportAsText())
                }
            ],
            rightButtons: [
                .init(
                    icon: "square.stack.3d.up",
                    activeIcon: "square.stack.3d.up.fill",
                    color: .secondary,
                    activeColor: .blue,
                    isActive: showsAllStorage
                ) {
                    showsAllStorage.toggle()
                },
                .init(
                    icon: "plus",
                    isDisabled: showsAllStorage
                ) {
                    showAddSheet = true
                },
                .init(icon: "arrow.clockwise") {
                    Task { await storageManager.refresh(pageURL: navigator?.currentURL) }
                }
            ]
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter by key or value", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .backport.glassEffect(in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Storage Type Picker

    private var storageTypePicker: some View {
        Picker("Storage Type", selection: $selectedType) {
            ForEach(StorageItem.StorageType.allCases, id: \.self) { type in
                Text(type.label).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Table Header

    private let keyColumnWidth: CGFloat = 140
    private let storageTypeColumnWidth: CGFloat = 72

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("Key")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .frame(width: keyColumnWidth, alignment: .leading)

            Text("Value")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsAllStorage {
                Text("Storage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: storageTypeColumnWidth, alignment: .trailing)
            }

            // Placeholder for chevron alignment
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - States

    private var emptyState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: showsAllStorage ? "tray.full" : selectedType.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(showsAllStorage ? "No storage data" : "No \(selectedType.label.lowercased()) data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let error = storageManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var noMatchState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No matches")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Item List

    private func scrollUp(proxy: ScrollViewProxy?) {
        guard let proxy else { return }
        guard !filteredItems.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("item-\(filteredItems.first!.id)", anchor: .top)
        }
    }

    private func scrollDown(proxy: ScrollViewProxy?) {
        guard let proxy else { return }
        guard !filteredItems.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("item-\(filteredItems.last!.id)", anchor: .bottom)
        }
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeo in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            StorageItemRow(
                                item: item,
                                keyColumnWidth: keyColumnWidth,
                                storageTypeColumnWidth: storageTypeColumnWidth,
                                searchText: searchText,
                                showsStorageType: showsAllStorage,
                                onEdit: { selectedItem = $0 },
                                onDelete: { deleteItem($0) },
                                onCopy: { copyToClipboard($0) },
                                onCopyKeyValue: { copyKeyValue($0) }
                            )
                            .id("item-\(item.id)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        GeometryReader { innerGeo in
                            Color.clear
                                .onAppear {
                                    contentHeight = innerGeo.size.height
                                }
                                .onChange(of: innerGeo.size.height) { _, newHeight in
                                    contentHeight = newHeight
                                }
                        }
                    )
                }
                .background(Color(uiColor: .systemBackground))
                .scrollContentBackground(.hidden)
                .onScrollGeometryChange(for: Double.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newValue in
                    scrollOffset = newValue
                }
                .onAppear {
                    scrollViewHeight = outerGeo.size.height
                }
                .onChange(of: outerGeo.size.height) { _, newHeight in
                    scrollViewHeight = newHeight
                }
                .scrollNavigationOverlay(
                    scrollOffset: scrollOffset,
                    contentHeight: contentHeight,
                    viewportHeight: scrollViewHeight,
                    onScrollUp: { scrollUp(proxy: scrollProxy) },
                    onScrollDown: { scrollDown(proxy: scrollProxy) }
                )
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteItem(_ item: StorageItem) {
        Task {
            if await storageManager.removeItem(key: item.key, type: item.storageType) {
                await storageManager.refresh(pageURL: navigator?.currentURL)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func copyKeyValue(_ item: StorageItem) {
        UIPasteboard.general.string = "\(item.key)=\(item.value)"
    }

    // MARK: - Export

    private func exportAsText() -> String {
        let title = showsAllStorage ? "All Storage Export" : "\(selectedType.label) Storage Export"
        var output = "# \(title)\n"
        output += "# \(Date().formatted())\n\n"

        for item in filteredItems {
            if showsAllStorage {
                output += "[\(item.storageType.label)] \(item.key) = \(item.value)\n"
            } else {
                output += "\(item.key) = \(item.value)\n"
            }
        }

        return output
    }
}

// MARK: - Storage Item Row

private struct StorageItemRow: View {
    let item: StorageItem
    let keyColumnWidth: CGFloat
    let storageTypeColumnWidth: CGFloat
    let searchText: String
    let showsStorageType: Bool
    let onEdit: (StorageItem) -> Void
    let onDelete: (StorageItem) -> Void
    let onCopy: (String) -> Void
    let onCopyKeyValue: (StorageItem) -> Void

    // MARK: - Value Analysis

    private var isEmpty: Bool {
        item.value.isEmpty
    }

    private var valueType: StorageValueType {
        StorageValueType.detect(from: item.value)
    }

    private var displayValue: String {
        if isEmpty { return "(empty)" }
        let truncated = item.value.replacingOccurrences(of: "\n", with: " ")
        if truncated.count > 50 {
            return String(truncated.prefix(50)) + "…"
        }
        return truncated
    }

    // MARK: - Body

    var body: some View {
        Button {
            onEdit(item)
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onCopy(item.value)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onEdit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button {
                onCopy(item.key)
            } label: {
                Label("Copy Key", systemImage: "doc.on.doc")
            }

            Button {
                onCopy(item.value)
            } label: {
                Label("Copy Value", systemImage: "doc.on.doc.fill")
            }

            Button {
                onCopyKeyValue(item)
            } label: {
                Label("Copy Key=Value", systemImage: "equal.circle")
            }

            Divider()

            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(spacing: 8) {
            // Key column with highlight
            highlightedText(item.key, searchText: searchText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.leading, 4)
                .frame(width: keyColumnWidth, alignment: .leading)

            // Value column with highlight
            highlightedText(displayValue, searchText: searchText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Type label (colored text only in list)
            if valueType != .empty {
                Text(valueType.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(valueType.color)
            }

            if showsStorageType {
                Text(item.storageType.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(item.storageType.tintColor)
                    .frame(width: storageTypeColumnWidth, alignment: .trailing)
            }

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 16)
        }
    }

    // MARK: - Search Highlight

    private func highlightedText(_ text: String, searchText: String) -> Text {
        guard !searchText.isEmpty,
              let range = text.range(of: searchText, options: .caseInsensitive)
        else {
            return Text(text)
        }

        var attributed = AttributedString(text)
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].font = .body.bold()
            attributed[attrRange].foregroundColor = .yellow
        }
        return Text(attributed)
    }
}

#Preview {
    let manager = StorageManager()
    return StorageView(storageManager: manager, navigator: nil)
        .devToolsSheet()
}
