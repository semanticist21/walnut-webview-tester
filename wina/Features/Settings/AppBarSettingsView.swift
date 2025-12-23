//
//  AppBarSettingsView.swift
//  wina
//
//  Created by Claude on 12/23/25.
//

import SwiftUI

// MARK: - AppBar Menu Item

enum AppBarMenuItem: String, CaseIterable, Identifiable {
    case home
    case initialURL
    case back
    case forward
    case refresh

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .initialURL: return "arrow.uturn.backward"
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .refresh: return "arrow.clockwise"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .initialURL: return "Initial URL"
        case .back: return "Back"
        case .forward: return "Forward"
        case .refresh: return "Refresh"
        }
    }

    var description: String {
        switch self {
        case .home: return "Return to home screen"
        case .initialURL: return "Go to first loaded URL"
        case .back: return "Navigate to previous page"
        case .forward: return "Navigate to next page"
        case .refresh: return "Reload current page"
        }
    }

    /// Default order of all items
    static var defaultOrder: [AppBarMenuItem] {
        allCases
    }
}

// MARK: - AppBar Settings View

struct AppBarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    // Stored (persistent)
    @AppStorage("appBarItemsOrder") private var storedItemsData = Data()

    // Local state (editable)
    @State private var localItems: [AppBarItemState] = []

    private var hasChanges: Bool {
        guard let storedItems = try? JSONDecoder().decode([AppBarItemState].self, from: storedItemsData) else {
            // No stored data yet - check if local differs from default
            let defaultItems = AppBarMenuItem.defaultOrder.map { AppBarItemState(menuItem: $0, isVisible: true) }
            return localItems != defaultItems
        }
        return localItems != storedItems
    }

    var body: some View {
        List {
            Section {
                ForEach($localItems) { $item in
                    AppBarItemRow(item: $item)
                }
                .onMove(perform: moveItems)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Navigation Buttons")
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
            } footer: {
                Text("Info and Settings buttons are always visible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .navigationTitle("App Bar")
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
                    Text("Changes will apply to app bar")
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
        if let decoded = try? JSONDecoder().decode([AppBarItemState].self, from: storedItemsData),
           !decoded.isEmpty {
            // Merge with any new items that might have been added
            var loadedItems = decoded
            let loadedIds = Set(loadedItems.map { $0.menuItem })

            // Add any missing items at the end
            for menuItem in AppBarMenuItem.allCases where !loadedIds.contains(menuItem) {
                loadedItems.append(AppBarItemState(menuItem: menuItem, isVisible: true))
            }

            localItems = loadedItems
        } else {
            // First time: all items visible in default order
            localItems = AppBarMenuItem.defaultOrder.map { AppBarItemState(menuItem: $0, isVisible: true) }
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
            localItems = AppBarMenuItem.defaultOrder.map { AppBarItemState(menuItem: $0, isVisible: true) }
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

// MARK: - AppBar Item State

struct AppBarItemState: Identifiable, Codable, Equatable {
    var id: String { menuItem.rawValue }
    let menuItem: AppBarMenuItem
    var isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case menuItem
        case isVisible
    }

    init(menuItem: AppBarMenuItem, isVisible: Bool) {
        self.menuItem = menuItem
        self.isVisible = isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .menuItem)
        guard let item = AppBarMenuItem(rawValue: rawValue) else {
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

// MARK: - AppBar Item Row

private struct AppBarItemRow: View {
    @Binding var item: AppBarItemState

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

// MARK: - Helper for Reading AppBar Settings

struct AppBarSettings {
    static func getVisibleItems() -> [AppBarMenuItem] {
        guard let data = UserDefaults.standard.data(forKey: "appBarItemsOrder"),
              let items = try? JSONDecoder().decode([AppBarItemState].self, from: data) else {
            // Default: all items visible
            return AppBarMenuItem.defaultOrder
        }

        return items.filter { $0.isVisible }.map { $0.menuItem }
    }
}

#Preview {
    NavigationStack {
        AppBarSettingsView()
    }
}
