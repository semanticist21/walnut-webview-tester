//
//  StorageView.swift
//  wina
//
//  Web Storage debugging view for WKWebView.
//  Displays localStorage, sessionStorage, and cookies.
//

import SwiftUI

// MARK: - Storage Item Model

struct StorageItem: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
    let storageType: StorageType

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
        lhs.id == rhs.id
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
        let script = """
            (function() {
                try {
                    var cookies = document.cookie;
                    if (!cookies) return JSON.stringify([]);
                    var result = cookies.split(';').map(function(c) {
                        var parts = c.trim().split('=');
                        var key = parts[0];
                        var value = parts.slice(1).join('=');
                        return { key: key, value: decodeURIComponent(value) };
                    });
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
                self.errorMessage = "Cookies: \(error)"
            }
            return nil
        }

        guard let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return nil
        }

        return items.compactMap { dict in
            guard let key = dict["key"], let value = dict["value"] else { return nil }
            return StorageItem(key: key, value: value, storageType: .cookies)
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

        let escapedKey = key.replacingOccurrences(of: "'", with: "\\'")

        let script: String
        switch type {
        case .localStorage:
            script = "localStorage.removeItem('\(escapedKey)'); true;"
        case .sessionStorage:
            script = "sessionStorage.removeItem('\(escapedKey)'); true;"
        case .cookies:
            script = "document.cookie = '\(escapedKey)=; expires=Thu, 01 Jan 1970 00:00:00 GMT'; true;"
        }

        let result = await navigator.evaluateJavaScript(script)
        return result as? Bool == true
    }

    // Clear all items of a type
    @MainActor
    func clearStorage(type: StorageItem.StorageType) async -> Bool {
        guard let navigator else { return false }

        let script: String
        switch type {
        case .localStorage:
            script = "localStorage.clear(); true;"
        case .sessionStorage:
            script = "sessionStorage.clear(); true;"
        case .cookies:
            // Clear all cookies
            script = """
                (function() {
                    document.cookie.split(';').forEach(function(c) {
                        var key = c.trim().split('=')[0];
                        document.cookie = key + '=; expires=Thu, 01 Jan 1970 00:00:00 GMT';
                    });
                    return true;
                })();
                """
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
            StorageShareSheet(content: item.content)
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
        .glassEffect(in: .capsule)
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
        VStack(spacing: 8) {
            Image(systemName: selectedType.icon)
                .font(.system(size: 32))
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var noMatchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No matches")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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

    private var isJson: Bool {
        JsonParser.isValidJson(item.value)
    }

    private var isNumber: Bool {
        Double(item.value) != nil
    }

    private var isBool: Bool {
        item.value.lowercased() == "true" || item.value.lowercased() == "false"
    }

    private var valueType: ValueType {
        if isEmpty { return .empty }
        if isJson { return .json }
        if isBool { return .bool }
        if isNumber { return .number }
        return .string
    }

    private var valueSize: String {
        let bytes = item.value.utf8.count
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1fKB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
        }
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

            // Type badge + Size
            HStack(spacing: 6) {
                typeBadge
                Text(valueSize)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
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

    // MARK: - Type Badge

    @ViewBuilder
    private var typeBadge: some View {
        switch valueType {
        case .json:
            Text("JSON")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.orange, in: Capsule())
        case .number:
            Text("#")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.blue)
        case .bool:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .empty:
            Image(systemName: "circle.dashed")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        case .string:
            EmptyView()
        }
    }

    // MARK: - Search Highlight

    private func highlightedText(_ text: String, searchText: String) -> Text {
        guard !searchText.isEmpty,
              let range = text.range(of: searchText, options: .caseInsensitive)
        else {
            return Text(text)
        }

        let before = String(text[..<range.lowerBound])
        let match = String(text[range])
        let after = String(text[range.upperBound...])

        return Text("\(before)\(Text(match).bold().foregroundColor(.yellow))\(after)")
    }

    // MARK: - Value Type

    private enum ValueType {
        case json, number, bool, string, empty
    }
}

// MARK: - Storage Share Sheet

private struct StorageShareSheet: UIViewControllerRepresentable {
    let content: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [content], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Key", text: $editedKey)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    HStack {
                        Text("Key")
                        Spacer()
                        copyButton(text: editedKey)
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
                        HStack(spacing: 12) {
                            Button {
                                if let encoded = editedValue.addingPercentEncoding(
                                    withAllowedCharacters: .urlQueryAllowed
                                ) {
                                    editedValue = encoded
                                }
                            } label: {
                                Label("Encode", systemImage: "arrow.right.circle")
                                    .font(.caption.weight(.medium))
                            }

                            Button {
                                if let decoded = editedValue.removingPercentEncoding {
                                    editedValue = decoded
                                }
                            } label: {
                                Label("Decode", systemImage: "arrow.left.circle")
                                    .font(.caption.weight(.medium))
                            }
                        }
                        .foregroundStyle(.blue)
                    }
                } header: {
                    HStack {
                        Text("Value")
                        Spacer()
                        copyButton(text: editedValue)
                        if isValueJson {
                            Button {
                                showJsonEditor = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("Edit")
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.fill.tertiary, in: Capsule())
                            }
                            .buttonStyle(.plain)
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
                            Text("\(countJsonElements(editedValue)) items")
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
        }
    }

    private func saveItem() {
        isSaving = true
        Task {
            var success = false

            if keyChanged {
                // Key changed: remove old key first, then set new key
                let removed = await storageManager.removeItem(key: item.key, type: item.storageType)
                if removed {
                    success = await storageManager.setItem(
                        key: editedKey,
                        value: editedValue,
                        type: item.storageType
                    )
                }
            } else {
                // Only value changed
                success = await storageManager.setItem(
                    key: editedKey,
                    value: editedValue,
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

    private func copyButton(text: String) -> some View {
        Button {
            UIPasteboard.general.string = text
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                Text("Copy")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.fill.tertiary, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
    }

    private func countJsonElements(_ jsonString: String) -> Int {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return 0 }
        if let dict = json as? [String: Any] { return dict.count }
        if let array = json as? [Any] { return array.count }
        return 1
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

    private var isValueJson: Bool {
        JsonParser.isValidJson(value)
    }

    private var isDuplicateKey: Bool {
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
                            Button {
                                showJsonEditor = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("Edit")
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.fill.tertiary, in: Capsule())
                            }
                            .buttonStyle(.plain)
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
                            Text("\(countJsonElements(value)) items")
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
            if await storageManager.setItem(key: key, value: value, type: storageType) {
                onSave()
                dismiss()
            }
            isSaving = false
        }
    }

    private func countJsonElements(_ jsonString: String) -> Int {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return 0 }
        if let dict = json as? [String: Any] { return dict.count }
        if let array = json as? [Any] { return array.count }
        return 1
    }
}

#Preview {
    let manager = StorageManager()
    return StorageView(storageManager: manager, navigator: nil)
        .presentationDetents([.fraction(0.35), .medium, .large])
}
