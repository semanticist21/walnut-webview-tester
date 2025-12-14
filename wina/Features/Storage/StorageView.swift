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

        let escapedKey = key.replacingOccurrences(of: "'", with: "\\'")
        let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")

        let script: String
        switch type {
        case .localStorage:
            script = "localStorage.setItem('\(escapedKey)', '\(escapedValue)'); true;"
        case .sessionStorage:
            script = "sessionStorage.setItem('\(escapedKey)', '\(escapedValue)'); true;"
        case .cookies:
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
                .init(icon: "arrow.clockwise", color: .blue) {
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
            Spacer()
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
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noMatchState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No matches")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    StorageItemRow(item: item, keyColumnWidth: keyColumnWidth)
                        .onTapGesture {
                            selectedItem = item
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .scrollContentBackground(.hidden)
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

    // Check if value needs truncation
    private var needsTruncation: Bool {
        item.value.count > 50 || item.value.contains("\n")
    }

    private var displayValue: String {
        if needsTruncation {
            let truncated = item.value.replacingOccurrences(of: "\n", with: " ")
            return String(truncated.prefix(50)) + "…"
        }
        return item.value
    }

    var body: some View {
        HStack(spacing: 12) {
            // Key column
            Text(item.key)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: keyColumnWidth, alignment: .leading)

            // Value column
            Text(displayValue)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

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
    @State private var editedValue: String = ""
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Key") {
                    Text(item.key)
                        .font(.system(size: 14, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("Value") {
                    TextEditor(text: $editedValue)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 120)
                }

                Section {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            GlassActionButton("Delete", icon: "trash", style: .destructive) {
                                showDeleteConfirm = true
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
                    .disabled(isSaving || editedValue == item.value)
                }
            }
            .confirmationDialog(
                "Delete \"\(item.key)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            }
            .onAppear {
                editedValue = item.value
            }
        }
    }

    private func saveItem() {
        isSaving = true
        Task {
            if await storageManager.setItem(
                key: item.key,
                value: editedValue,
                type: item.storageType
            ) {
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

    var body: some View {
        NavigationStack {
            List {
                Section("Key") {
                    TextField("Enter key", text: $key)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Value") {
                    TextEditor(text: $value)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 100)
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
                    .disabled(isSaving || key.isEmpty)
                }
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
}

#Preview {
    let manager = StorageManager()
    return StorageView(storageManager: manager, navigator: nil)
        .presentationDetents([.fraction(0.35), .medium, .large])
}
