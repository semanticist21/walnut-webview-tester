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

@Observable
class StorageManager {
    var items: [StorageItem] = []
    var lastRefreshTime: Date?
    var errorMessage: String?

    private weak var navigator: WebViewNavigator?

    func setNavigator(_ navigator: WebViewNavigator?) {
        self.navigator = navigator
    }

    // SWR: Fetch all storage data from WebView (keep stale data while revalidating)
    @MainActor
    func refresh() async {
        guard let navigator else {
            errorMessage = "WebView not connected"
            return
        }

        errorMessage = nil

        // Fetch new data in background (keep existing items visible)
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
        if let cookieData = await fetchCookies(navigator: navigator) {
            newItems.append(contentsOf: cookieData)
        }

        // Update items atomically
        items = newItems
        lastRefreshTime = Date()
    }

    private func fetchStorage(
        type: StorageItem.StorageType,
        navigator: WebViewNavigator
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

    private func fetchCookies(navigator: WebViewNavigator) async -> [StorageItem]? {
        // Use native WKHTTPCookieStore for full cookie metadata
        let cookies = await navigator.getAllCookies()

        return cookies.map { cookie in
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
    @State private var searchText: String = ""
    @State private var shareItem: StorageShareContent?
    @State private var selectedItem: StorageItem?
    @State private var showAddSheet: Bool = false

    private var filteredItems: [StorageItem] {
        var result = storageManager.items.filter { $0.storageType == selectedType }

        if !searchText.isEmpty {
            result = result.filter {
                $0.key.localizedCaseInsensitiveContains(searchText)
                    || $0.value.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            storageHeader
            searchBar
            storageTypePicker

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
                    Task { await storageManager.refresh() }
                },
                onDelete: {
                    Task { await storageManager.refresh() }
                }
            )
        }
        .sheet(isPresented: $showAddSheet) {
            StorageAddSheet(
                storageManager: storageManager,
                storageType: selectedType,
                onSave: {
                    Task { await storageManager.refresh() }
                }
            )
        }
        .task {
            await AdManager.shared.showInterstitialAd(
                options: AdOptions(id: "storage_devtools"),
                adUnitId: AdManager.interstitialAdUnitId
            )
            storageManager.setNavigator(navigator)
            await storageManager.refresh()
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
                    isDisabled: filteredItems.isEmpty
                ) {
                    Task {
                        if await storageManager.clearStorage(type: selectedType) {
                            await storageManager.refresh()
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
                .init(icon: "plus") {
                    showAddSheet = true
                },
                .init(icon: "arrow.clockwise") {
                    Task { await storageManager.refresh() }
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

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("Key")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: keyColumnWidth, alignment: .leading)

            Text("Value")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No \(selectedType.label.lowercased()) data")
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

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    StorageItemRow(
                        item: item,
                        keyColumnWidth: keyColumnWidth,
                        searchText: searchText,
                        onEdit: { selectedItem = $0 },
                        onDelete: { deleteItem($0) },
                        onCopy: { copyToClipboard($0) },
                        onCopyKeyValue: { copyKeyValue($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .scrollContentBackground(.hidden)
    }

    private func deleteItem(_ item: StorageItem) {
        Task {
            if await storageManager.removeItem(key: item.key, type: item.storageType) {
                await storageManager.refresh()
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
        var output = "# \(selectedType.label) Storage Export\n"
        output += "# \(Date().formatted())\n\n"

        for item in filteredItems {
            output += "\(item.key) = \(item.value)\n"
        }

        return output
    }
}

// MARK: - Storage Item Row

private struct StorageItemRow: View {
    let item: StorageItem
    let keyColumnWidth: CGFloat
    let searchText: String
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
                .frame(width: keyColumnWidth, alignment: .leading)

            // Value column with highlight
            highlightedText(displayValue, searchText: searchText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Type label (colored text only in list)
            if valueType != .empty {
                Text(valueType.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(valueType.color)
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

// MARK: - Storage Edit Sheet

private struct StorageEditSheet: View {
    let item: StorageItem
    let storageManager: StorageManager
    let onSave: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedKey: String = ""
    @State private var editedValue: String = ""
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showJsonEditor: Bool = false
    @State private var copiedFeedback: String?

    private var isValueJson: Bool {
        JsonParser.isValidJson(editedValue)
    }

    private var isCookie: Bool {
        item.storageType == .cookies
    }

    private var keyChanged: Bool {
        editedKey != item.key
    }

    private var hasChanges: Bool {
        editedKey != item.key || editedValue != item.value
    }

    private var isDuplicateKey: Bool {
        guard keyChanged else { return false }
        let existingKeys = storageManager.items
            .filter { $0.storageType == item.storageType && $0.key != item.key }
            .map(\.key)
        return existingKeys.contains(editedKey)
    }

    private var valueType: StorageValueType {
        StorageValueType.detect(from: editedValue)
    }

    private var formattedSize: String {
        let bytes = editedValue.utf8.count
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Info section (Type + Size)
                Section("Info") {
                    HStack {
                        Text("Type")
                        Spacer()
                        if let badge = valueType.badge {
                            badge
                        } else {
                            Text(valueType.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Size")
                        Spacer()
                        Text(formattedSize)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Cookie metadata section
                if let metadata = item.cookieMetadata {
                    Section("Cookie Attributes") {
                        LabeledContent("Domain", value: metadata.domain)
                        LabeledContent("Path", value: metadata.path)

                        if let expires = metadata.expiresDate {
                            LabeledContent("Expires") {
                                HStack(spacing: 4) {
                                    Text(expires, style: .date)
                                    Text(expires, style: .time)
                                }
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            LabeledContent("Expires", value: "Session")
                        }

                        if let sameSite = metadata.sameSitePolicy {
                            LabeledContent("SameSite", value: sameSite)
                        }

                        HStack {
                            if metadata.isSecure {
                                TypeBadge(text: "Secure", color: .green, icon: "lock.fill")
                            }
                            if metadata.isHTTPOnly {
                                TypeBadge(text: "HttpOnly", color: .orange, icon: "server.rack")
                            }
                        }
                    }
                }

                Section {
                    TextField("Key", text: $editedKey)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    HStack {
                        Text("Key")
                        Spacer()
                        CopyIconButton(text: editedKey) {
                            showCopiedFeedback("Key")
                        }
                    }
                } footer: {
                    if isDuplicateKey {
                        Text("Key '\(editedKey)' already exists")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextEditor(text: $editedValue)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 120)

                    if isCookie {
                        HStack(spacing: 8) {
                            HeaderActionButton(label: "Encode", icon: "arrow.right.circle") {
                                if let encoded = editedValue.addingPercentEncoding(
                                    withAllowedCharacters: .urlQueryAllowed
                                ) {
                                    editedValue = encoded
                                }
                            }

                            HeaderActionButton(label: "Decode", icon: "arrow.left.circle") {
                                if let decoded = editedValue.removingPercentEncoding {
                                    editedValue = decoded
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Value")
                        Spacer()
                        CopyIconButton(text: editedValue) {
                            showCopiedFeedback("Value")
                        }
                        if isValueJson {
                            HeaderActionButton(label: "Edit", icon: "pencil") {
                                showJsonEditor = true
                            }
                        }
                    }
                }

                // JSON Explorer section (only for valid JSON)
                if isValueJson {
                    Section {
                        JsonExplorerView(jsonText: editedValue)
                            .frame(minHeight: 200)
                            .listRowInsets(EdgeInsets())
                    } header: {
                        HStack {
                            Text("JSON Explorer")
                            Spacer()
                            Text("\(JsonParser.countElements(editedValue)) items")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            GlassActionButton("Delete", icon: "trash", style: .destructive) {
                                deleteItem()
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(isSaving || !hasChanges || editedKey.isEmpty || isDuplicateKey)
                }
            }
            .sheet(isPresented: $showJsonEditor) {
                JsonEditorSheet(jsonText: $editedValue)
            }
            .onAppear {
                editedKey = item.key
                editedValue = item.value
            }
            .overlay(alignment: .bottom) {
                if let feedback = copiedFeedback {
                    CopiedFeedbackToast(message: feedback)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: copiedFeedback)
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

    private func saveItem() {
        isSaving = true
        Task {
            var success = false
            // Minify JSON before saving (storage typically stores compact JSON)
            let valueToSave = JsonParser.minify(editedValue) ?? editedValue

            if keyChanged {
                // Key changed: remove old key first, then set new key
                let removed = await storageManager.removeItem(key: item.key, type: item.storageType)
                if removed {
                    success = await storageManager.setItem(
                        key: editedKey,
                        value: valueToSave,
                        type: item.storageType
                    )
                }
            } else {
                // Only value changed
                success = await storageManager.setItem(
                    key: editedKey,
                    value: valueToSave,
                    type: item.storageType
                )
            }

            if success {
                onSave()
                dismiss()
            }
            isSaving = false
        }
    }

    private func deleteItem() {
        isDeleting = true
        Task {
            if await storageManager.removeItem(key: item.key, type: item.storageType) {
                onDelete()
                dismiss()
            }
            isDeleting = false
        }
    }
}

// MARK: - Storage Add Sheet

private struct StorageAddSheet: View {
    let storageManager: StorageManager
    let storageType: StorageItem.StorageType
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var isSaving: Bool = false
    @State private var showJsonEditor: Bool = false
    @State private var didSave: Bool = false

    private var isValueJson: Bool {
        JsonParser.isValidJson(value)
    }

    private var isDuplicateKey: Bool {
        // Skip duplicate check after successful save (items already updated)
        guard !didSave else { return false }
        let existingKeys = storageManager.items
            .filter { $0.storageType == storageType }
            .map(\.key)
        return existingKeys.contains(key)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Enter key", text: $key)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Key")
                } footer: {
                    if isDuplicateKey {
                        Text("Key '\(key)' already exists")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextEditor(text: $value)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 100)
                } header: {
                    HStack {
                        Text("Value")
                        Spacer()
                        if isValueJson {
                            HeaderActionButton(label: "Edit", icon: "pencil") {
                                showJsonEditor = true
                            }
                        }
                    }
                }

                // JSON Explorer section (only for valid JSON)
                if isValueJson {
                    Section {
                        JsonExplorerView(jsonText: value)
                            .frame(minHeight: 160)
                            .listRowInsets(EdgeInsets())
                    } header: {
                        HStack {
                            Text("JSON Explorer")
                            Spacer()
                            Text("\(JsonParser.countElements(value)) items")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Add to \(storageType.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(isSaving || key.isEmpty || isDuplicateKey)
                }
            }
            .sheet(isPresented: $showJsonEditor) {
                JsonEditorSheet(jsonText: $value)
            }
        }
    }

    private func addItem() {
        isSaving = true
        Task {
            // Minify JSON before saving (storage typically stores compact JSON)
            let valueToSave = JsonParser.minify(value) ?? value
            if await storageManager.setItem(key: key, value: valueToSave, type: storageType) {
                didSave = true
                onSave()
                dismiss()
            }
            isSaving = false
        }
    }
}

#Preview {
    let manager = StorageManager()
    return StorageView(storageManager: manager, navigator: nil)
        .devToolsSheet()
}
