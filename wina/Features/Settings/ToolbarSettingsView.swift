//
//  ToolbarSettingsView.swift
//  wina
//
//  Created by Claude on 12/23/25.
//

import SwiftUI

// MARK: - DevTools Menu Item

enum DevToolsMenuItem: String, CaseIterable, Identifiable {
    case console
    case sources
    case network
    case storage
    case performance
    case accessibility
    case snippets
    case searchInPage
    case screenshot

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .console: return "terminal"
        case .sources: return "chevron.left.forwardslash.chevron.right"
        case .network: return "network"
        case .storage: return "externaldrive"
        case .performance: return "gauge.with.dots.needle.bottom.50percent"
        case .accessibility: return "accessibility"
        case .snippets: return "scroll"
        case .searchInPage: return "doc.text.magnifyingglass"
        case .screenshot: return "camera"
        }
    }

    var label: String {
        switch self {
        case .console: return "Console"
        case .sources: return "Sources"
        case .network: return "Network"
        case .storage: return "Storage"
        case .performance: return "Performance"
        case .accessibility: return "Accessibility"
        case .snippets: return "Snippets"
        case .searchInPage: return "Search in Page"
        case .screenshot: return "Screenshot"
        }
    }

    var description: String {
        switch self {
        case .console: return "JavaScript console logs"
        case .sources: return "DOM tree, stylesheets, scripts"
        case .network: return "Network requests monitoring"
        case .storage: return "localStorage, sessionStorage, cookies"
        case .performance: return "Web Vitals & timing metrics"
        case .accessibility: return "Accessibility audit (axe-core)"
        case .snippets: return "Run JavaScript snippets"
        case .searchInPage: return "Find text in page"
        case .screenshot: return "Capture page screenshot"
        }
    }

    /// Items that remain visible even when Eruda mode is enabled
    var isAlwaysVisible: Bool {
        switch self {
        case .searchInPage, .screenshot:
            return true
        default:
            return false
        }
    }

    /// Default order of all items
    static var defaultOrder: [DevToolsMenuItem] {
        allCases
    }
}

// MARK: - Toolbar Settings View

struct ToolbarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    // Stored (persistent)
    @AppStorage("toolbarItemsOrder") private var storedItemsData = Data()

    // Local state (editable)
    @State private var localItems: [ToolbarItemState] = []

    private var hasChanges: Bool {
        guard let storedItems = try? JSONDecoder().decode([ToolbarItemState].self, from: storedItemsData) else {
            // No stored data yet - check if local differs from default
            let defaultItems = DevToolsMenuItem.defaultOrder.map { ToolbarItemState(menuItem: $0, isVisible: true) }
            return localItems != defaultItems
        }
        return localItems != storedItems
    }

    var body: some View {
        List {
            Section {
                ForEach($localItems) { $item in
                    ToolbarItemRow(item: $item)
                }
                .onMove(perform: moveItems)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Toolbar Items")
                        Spacer()
                        Button("All") { enableAll() }
                            .font(.caption)
                        Text("/")
                            .foregroundStyle(.tertiary)
                        Button("None") { disableAll() }
                            .font(.caption)
                    }
                    Text("Drag to reorder. Toggle to show/hide.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
            }

            Section {
                HStack {
                    Spacer()
                    GlassActionButton("Reset", icon: "arrow.counterclockwise", style: .destructive) {
                        resetToDefaults()
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Toolbar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Apply") { applyChanges() }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if hasChanges {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Changes will apply to toolbar")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasChanges)
        .onAppear {
            loadFromStorage()
            // Start in edit mode for drag reordering
            editMode?.wrappedValue = .active
        }
    }

    private func loadFromStorage() {
        if let decoded = try? JSONDecoder().decode([ToolbarItemState].self, from: storedItemsData),
           !decoded.isEmpty {
            // Merge with any new items that might have been added
            var loadedItems = decoded
            let loadedIds = Set(loadedItems.map { $0.menuItem })

            // Add any missing items at the end
            for menuItem in DevToolsMenuItem.allCases where !loadedIds.contains(menuItem) {
                loadedItems.append(ToolbarItemState(menuItem: menuItem, isVisible: true))
            }

            localItems = loadedItems
        } else {
            // First time: all items visible in default order
            localItems = DevToolsMenuItem.defaultOrder.map { ToolbarItemState(menuItem: $0, isVisible: true) }
        }
    }

    private func applyChanges() {
        if let encoded = try? JSONEncoder().encode(localItems) {
            storedItemsData = encoded
        }
        dismiss()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        localItems.move(fromOffsets: source, toOffset: destination)
    }

    private func resetToDefaults() {
        withAnimation {
            localItems = DevToolsMenuItem.defaultOrder.map { ToolbarItemState(menuItem: $0, isVisible: true) }
        }
    }

    private func enableAll() {
        withAnimation {
            for index in localItems.indices {
                localItems[index].isVisible = true
            }
        }
    }

    private func disableAll() {
        withAnimation {
            for index in localItems.indices {
                localItems[index].isVisible = false
            }
        }
    }
}

// MARK: - Toolbar Item State

struct ToolbarItemState: Identifiable, Codable, Equatable {
    var id: String { menuItem.rawValue }
    let menuItem: DevToolsMenuItem
    var isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case menuItem
        case isVisible
    }

    init(menuItem: DevToolsMenuItem, isVisible: Bool) {
        self.menuItem = menuItem
        self.isVisible = isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .menuItem)
        guard let item = DevToolsMenuItem(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .menuItem,
                in: container,
                debugDescription: "Unknown menu item: \(rawValue)"
            )
        }
        self.menuItem = item
        self.isVisible = try container.decode(Bool.self, forKey: .isVisible)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(menuItem.rawValue, forKey: .menuItem)
        try container.encode(isVisible, forKey: .isVisible)
    }
}

// MARK: - Toolbar Item Row

private struct ToolbarItemRow: View {
    @Binding var item: ToolbarItemState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.menuItem.icon)
                .font(.system(size: 18))
                .foregroundStyle(item.isVisible ? .primary : .tertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.menuItem.label)
                    .foregroundStyle(item.isVisible ? .primary : .secondary)
                Text(item.menuItem.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $item.isVisible)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Helper for Reading Toolbar Settings

struct ToolbarSettings {
    static func getVisibleItems() -> [DevToolsMenuItem] {
        guard let data = UserDefaults.standard.data(forKey: "toolbarItemsOrder"),
              let items = try? JSONDecoder().decode([ToolbarItemState].self, from: data) else {
            // Default: all items visible
            return DevToolsMenuItem.defaultOrder
        }

        return items.filter { $0.isVisible }.map { $0.menuItem }
    }
}

#Preview {
    NavigationStack {
        ToolbarSettingsView()
    }
}
