//
//  ConsoleView.swift
//  wina
//
//  Created by Claude on 12/13/25.
//

import SwiftUI

// MARK: - Console Log Model

struct ConsoleLog: Identifiable, Equatable {
    let id = UUID()
    let type: LogType
    let message: String
    let source: String?  // e.g., "main.js:45"
    let timestamp: Date
    var groupLevel: Int = 0  // Indentation level for groups
    var groupId: UUID?  // For groupCollapsed toggle
    var isCollapsed: Bool = false  // For groupCollapsed
    var tableData: [[String: String]]?  // For console.table

    enum LogType: String, CaseIterable {
        case log
        case info
        case warn
        case error
        case debug
        case group
        case groupCollapsed
        case groupEnd
        case table

        var icon: String {
            switch self {
            case .log: return "chevron.right"
            case .info: return "info.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .debug: return "ant.fill"
            case .group, .groupCollapsed: return "folder"
            case .groupEnd: return "folder"
            case .table: return "tablecells"
            }
        }

        var color: Color {
            switch self {
            case .log: return .secondary
            case .info: return .blue
            case .warn: return .orange
            case .error: return .red
            case .debug: return .purple
            case .group, .groupCollapsed, .groupEnd: return .secondary
            case .table: return .cyan
            }
        }

        var label: String {
            switch self {
            case .log: return "Log"
            case .info: return "Info"
            case .warn: return "Warnings"
            case .error: return "Errors"
            case .debug: return "Debug"
            case .group, .groupCollapsed: return "Group"
            case .groupEnd: return "GroupEnd"
            case .table: return "Table"
            }
        }

        var shortLabel: String {
            switch self {
            case .log: return "LOG"
            case .info: return "INFO"
            case .warn: return "WARN"
            case .error: return "ERROR"
            case .debug: return "DEBUG"
            case .group: return "GROUP"
            case .groupCollapsed: return "GROUP"
            case .groupEnd: return "END"
            case .table: return "TABLE"
            }
        }

        // Types shown in filter tabs
        static var filterTypes: [LogType] {
            [.error, .warn, .info, .log, .debug]
        }

        // Types that can be displayed (excludes internal types like groupEnd)
        static var displayableTypes: [LogType] {
            [.log, .info, .warn, .error, .debug, .group, .groupCollapsed, .table]
        }
    }

    static func == (lhs: ConsoleLog, rhs: ConsoleLog) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Console Manager

@Observable
class ConsoleManager {
    var logs: [ConsoleLog] = []
    var isCapturing: Bool = true
    var collapsedGroups: Set<UUID> = []
    private var currentGroupLevel: Int = 0
    private var groupStack: [UUID] = []

    // Read preserveLog from UserDefaults (set via @AppStorage in ConsoleSettingsSheet)
    var preserveLog: Bool {
        UserDefaults.standard.bool(forKey: "consolePreserveLog")
    }

    func addLog(type: String, message: String, source: String? = nil, tableData: [[String: String]]? = nil) {
        guard isCapturing else { return }

        // Filter CORS "Script error" - uninformative due to cross-origin security
        let msg = message.lowercased()
        if msg.contains("script error") && (source == nil || source?.isEmpty == true) {
            return
        }

        let logType = ConsoleLog.LogType(rawValue: type) ?? .log

        DispatchQueue.main.async {
            var log = ConsoleLog(type: logType, message: message, source: source, timestamp: Date())
            log.tableData = tableData

            // Handle group levels
            switch logType {
            case .group:
                log.groupLevel = self.currentGroupLevel
                let groupId = UUID()
                log.groupId = groupId
                self.groupStack.append(groupId)
                self.currentGroupLevel += 1
            case .groupCollapsed:
                log.groupLevel = self.currentGroupLevel
                let groupId = UUID()
                log.groupId = groupId
                log.isCollapsed = true
                self.groupStack.append(groupId)
                self.collapsedGroups.insert(groupId)
                self.currentGroupLevel += 1
            case .groupEnd:
                if self.currentGroupLevel > 0 {
                    self.currentGroupLevel -= 1
                    _ = self.groupStack.popLast()
                }
                log.groupLevel = self.currentGroupLevel
            default:
                log.groupLevel = self.currentGroupLevel
                if let currentGroup = self.groupStack.last {
                    log.groupId = currentGroup
                }
            }

            self.logs.append(log)
        }
    }

    func toggleGroup(_ groupId: UUID) {
        if collapsedGroups.contains(groupId) {
            collapsedGroups.remove(groupId)
        } else {
            collapsedGroups.insert(groupId)
        }
    }

    func clear() {
        logs.removeAll()
        currentGroupLevel = 0
        groupStack.removeAll()
        collapsedGroups.removeAll()
    }

    func clearIfNotPreserved() {
        guard !preserveLog else { return }
        clear()
    }

    var errorCount: Int { logs.filter { $0.type == .error }.count }
    var warnCount: Int { logs.filter { $0.type == .warn }.count }

    // Export logs as formatted text
    func exportAsText() -> String {
        ConsoleExporter.exportAsText(logs)
    }

    // Export logs as JSON
    func exportAsJSON() -> String {
        ConsoleExporter.exportAsJSON(logs)
    }
}

// MARK: - Console View

// Identifiable wrapper for share content to fix sheet timing issue
struct ShareContent: Identifiable {
    let id = UUID()
    let content: String
}

struct ConsoleView: View {
    let consoleManager: ConsoleManager
    @State private var filterType: ConsoleLog.LogType?
    @State private var searchText: String = ""
    @State private var useRegex: Bool = false
    @State private var shareItem: ShareContent?
    @State private var showSettings: Bool = false
    // Log types to show in "All" tab (user configurable)
    @State private var enabledLogTypes: Set<ConsoleLog.LogType> = Set(ConsoleLog.LogType.displayableTypes)
    // AppStorage for settings indicator (matches ConsoleSettingsSheet)
    @AppStorage("consolePreserveLog") private var preserveLog: Bool = false

    private var filteredLogs: [ConsoleLog] {
        var result = consoleManager.logs

        // Filter out groupEnd (internal tracking only, not displayed)
        result = result.filter { $0.type != .groupEnd }

        // Filter out logs inside collapsed groups
        result = result.filter { log in
            // If this log belongs to a group, check if any ancestor is collapsed
            if let groupId = log.groupId, log.type != .group && log.type != .groupCollapsed {
                return !consoleManager.collapsedGroups.contains(groupId)
            }
            return true
        }

        if let filterType {
            result = result.filter { $0.type == filterType }
        } else {
            // "All" tab - filter by user-selected log types
            result = result.filter { enabledLogTypes.contains($0.type) }
        }

        if !searchText.isEmpty {
            if useRegex, case .success(let regex) = RegexFilter.compile(searchText) {
                result = result.filter { log in
                    RegexFilter.matchesLog(message: log.message, source: log.source, regex: regex)
                }
            } else if !useRegex {
                result = result.filter {
                    $0.message.localizedCaseInsensitiveContains(searchText)
                    || ($0.source?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        return result
    }

    // Settings button highlight when any setting is active
    private var settingsActive: Bool {
        useRegex || preserveLog || enabledLogTypes.count != ConsoleLog.LogType.displayableTypes.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar - full control over layout
            consoleHeader

            // Search bar
            searchBar

            // Filter tabs (Chrome DevTools style)
            filterTabs

            Divider()

            // Log list
            if filteredLogs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(content: item.content)
        }
        .sheet(isPresented: $showSettings) {
            ConsoleSettingsSheet(
                useRegex: $useRegex,
                enabledLogTypes: $enabledLogTypes
            )
        }
    }

    // MARK: - Console Header

    private var consoleHeader: some View {
        HStack(spacing: 16) {
            // Left button group: trash + export
            HStack(spacing: 4) {
                Button {
                    consoleManager.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(consoleManager.logs.isEmpty ? .tertiary : .primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .disabled(consoleManager.logs.isEmpty)

                Button {
                    shareItem = ShareContent(content: ConsoleExporter.exportAsText(filteredLogs))
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(filteredLogs.isEmpty ? .tertiary : .primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .disabled(filteredLogs.isEmpty)
            }
            .padding(.horizontal, 6)
            .glassEffect(in: .capsule)

            Spacer()

            // Center: Title
            Text("Console")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Right button group: pause/play + settings
            HStack(spacing: 4) {
                Button {
                    consoleManager.isCapturing.toggle()
                } label: {
                    Image(systemName: consoleManager.isCapturing ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(consoleManager.isCapturing ? .red : .green)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: settingsActive ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(settingsActive ? .blue : .secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
            }
            .padding(.horizontal, 6)
            .glassEffect(in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(useRegex ? "Regex" : "Filter", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let content: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [content], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Console View Extensions

extension ConsoleView {
    // MARK: - Filter Tabs

    var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                FilterTab(label: "All", count: consoleManager.logs.count, isSelected: filterType == nil) {
                    filterType = nil
                }

                FilterTab(label: "Errors", count: consoleManager.errorCount, isSelected: filterType == .error, color: .red) {
                    filterType = .error
                }

                FilterTab(label: "Warnings", count: consoleManager.warnCount, isSelected: filterType == .warn, color: .orange) {
                    filterType = .warn
                }

                ForEach([ConsoleLog.LogType.info, .log, .debug], id: \.self) { type in
                    FilterTab(
                        label: type.label,
                        count: consoleManager.logs.filter { $0.type == type }.count,
                        isSelected: filterType == type
                    ) {
                        filterType = type
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(consoleManager.logs.isEmpty ? "No logs" : "No matches")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !consoleManager.isCapturing {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLogs) { log in
                        LogRow(log: log, consoleManager: consoleManager)
                            .id(log.id)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .scrollContentBackground(.hidden)
            .onChange(of: consoleManager.logs.count) { _, _ in
                if let lastLog = filteredLogs.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Filter Tab

private struct FilterTab: View {
    let label: String
    let count: Int
    let isSelected: Bool
    var color: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if count != 0 {  // swiftlint:disable:this empty_count
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.15), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? color : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(color)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Log Row

private struct LogRow: View {
    let log: ConsoleLog
    let consoleManager: ConsoleManager
    @State private var isExpanded: Bool = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    // Indentation based on group level (12pt per level)
    private var indentation: CGFloat {
        CGFloat(log.groupLevel) * 12
    }

    // Check if this is a group header
    private var isGroupHeader: Bool {
        log.type == .group || log.type == .groupCollapsed
    }

    // Check if group is collapsed
    private var isGroupCollapsed: Bool {
        guard let groupId = log.groupId else { return false }
        return consoleManager.collapsedGroups.contains(groupId)
    }

    // Check if message needs expansion
    // - 80+ chars (likely wraps to 2+ lines on screen)
    // - 2+ newline chars (explicit multiline)
    private var needsExpansion: Bool {
        guard log.type != .table else { return false }
        return log.message.count > 80 || log.message.filter { $0 == "\n" }.count >= 2
    }

    // Parse table data from message JSON
    private var parsedTableData: [[String: String]]? {
        guard log.type == .table else { return nil }
        if let tableData = log.tableData { return tableData }
        return JSONParser.parseTableData(from: log.message)
    }

    // Extract JSON from message (returns original, formatted and minified versions)
    private var extractedJSON: JSONParser.ParsedJSON? {
        guard log.type != .table else { return nil }
        return JSONParser.extract(from: log.message)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Group toggle or expand indicator
            if isGroupHeader {
                Button {
                    if let groupId = log.groupId {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            consoleManager.toggleGroup(groupId)
                        }
                    }
                } label: {
                    Image(systemName: isGroupCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                        .padding(.top, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if needsExpansion {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
                    .padding(.top, 4)
            }

            // Content area
            VStack(alignment: .leading, spacing: 2) {
                if log.type == .table, let tableData = parsedTableData {
                    // Table rendering
                    tableView(data: tableData)
                } else {
                    // Regular message
                    HStack(alignment: .top, spacing: 4) {
                        // Group header has folder icon
                        if isGroupHeader {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Text(isExpanded || !needsExpansion ? log.message : String(log.message.prefix(120)) + "...")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(log.type == .error ? .red : (isGroupHeader ? .secondary : .primary))
                            .fontWeight(isGroupHeader ? .semibold : .regular)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // JSON copy button (only if JSON detected)
                        if let json = extractedJSON {
                            Menu {
                                Button {
                                    UIPasteboard.general.string = json.formatted
                                } label: {
                                    Label("Copy Formatted", systemImage: "doc.on.doc")
                                }
                                Button {
                                    UIPasteboard.general.string = json.minified
                                } label: {
                                    Label("Copy Minified", systemImage: "arrow.right.arrow.left")
                                }
                            } label: {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }

                    // Source location (if available)
                    if let source = log.source {
                        Text(source)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Right side: Type badge + timestamp
            VStack(alignment: .trailing, spacing: 4) {
                // Type badge (icon + label)
                TypeBadge(type: log.type)

                Text(Self.timeFormatter.string(from: log.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 12 + indentation)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(log.type == .error ? Color.red.opacity(0.08) : (isGroupHeader ? Color.secondary.opacity(0.05) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            if isGroupHeader, let groupId = log.groupId {
                withAnimation(.easeInOut(duration: 0.2)) {
                    consoleManager.toggleGroup(groupId)
                }
            } else if needsExpansion {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = log.message
            } label: {
                Label("Copy Message", systemImage: "doc.on.doc")
            }

            if let source = log.source {
                Button {
                    UIPasteboard.general.string = source
                } label: {
                    Label("Copy Source", systemImage: "link")
                }
            }

            Divider()

            Button {
                var full = "[\(log.type.shortLabel)] \(log.message)"
                if let source = log.source {
                    full += " (\(source))"
                }
                UIPasteboard.general.string = full
            } label: {
                Label("Copy All", systemImage: "doc.on.clipboard")
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 12 + indentation)
        }
    }

    // MARK: - Table View

    @ViewBuilder
    private func tableView(data: [[String: String]]) -> some View {
        // Sort columns with (index) first, then alphabetically
        let allColumns = data.first?.keys.sorted() ?? []
        let columns = allColumns.sorted { a, b in
            if a == "(index)" { return true }
            if b == "(index)" { return false }
            return a < b
        }

        if columns.isEmpty {
            Text("(empty table)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { column in
                            Text(column)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: column == "(index)" ? 50 : 60, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                        }
                    }

                    // Data rows
                    ForEach(Array(data.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            ForEach(columns, id: \.self) { column in
                                Text(row[column] ?? "")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(column == "(index)" ? .tertiary : .primary)
                                    .frame(minWidth: column == "(index)" ? 50 : 60, alignment: .leading)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                            }
                        }
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.03))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - Type Badge

private struct TypeBadge: View {
    let type: ConsoleLog.LogType

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.icon)
                .font(.system(size: 8))
            Text(type.shortLabel)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(type.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(type.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Console Settings Sheet

private struct ConsoleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var useRegex: Bool
    @AppStorage("consolePreserveLog") private var preserveLog: Bool = false
    @Binding var enabledLogTypes: Set<ConsoleLog.LogType>

    var body: some View {
        NavigationStack {
            List {
                Section("Search") {
                    Toggle("Regex Filter", isOn: $useRegex)
                }

                Section("Logging") {
                    Toggle("Preserve Log on Navigation", isOn: $preserveLog)
                }

                Section("Log Types in 'All' Tab") {
                    ForEach(ConsoleLog.LogType.displayableTypes, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { enabledLogTypes.contains(type) },
                            set: { isEnabled in
                                if isEnabled {
                                    enabledLogTypes.insert(type)
                                } else {
                                    enabledLogTypes.remove(type)
                                }
                            }
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.color)
                                    .frame(width: 20)
                                Text(type.label)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Console Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let manager = ConsoleManager()
    manager.addLog(type: "log", message: "Application started", source: "app.js:1")
    manager.addLog(type: "info", message: "User session initialized", source: "auth.js:45")

    // Console group example
    manager.addLog(type: "group", message: "User Data Loading", source: "user.js:10")
    manager.addLog(type: "log", message: "Fetching user profile...", source: "user.js:12")
    manager.addLog(type: "log", message: "User ID: 12345", source: "user.js:15")
    manager.addLog(type: "groupEnd", message: "", source: nil)

    // Collapsed group example
    manager.addLog(type: "groupCollapsed", message: "Debug Info (collapsed)", source: "debug.js:1")
    manager.addLog(type: "debug", message: "This should be hidden", source: "debug.js:2")
    manager.addLog(type: "groupEnd", message: "", source: nil)

    manager.addLog(type: "warn", message: "Deprecated API usage: navigator.userAgent", source: "utils.js:78")
    manager.addLog(type: "error", message: "Failed to fetch: 404 Not Found", source: "api.js:31")

    // Console table example
    manager.addLog(
        type: "table",
        message: "[{\"name\":\"Alice\",\"age\":\"25\",\"city\":\"Seoul\"},{\"name\":\"Bob\",\"age\":\"30\",\"city\":\"Tokyo\"},{\"name\":\"Carol\",\"age\":\"28\",\"city\":\"NYC\"}]",
        source: "data.js:50"
    )

    // Long message to test expansion
    manager.addLog(
        type: "log",
        message: """
            Response: {
              "status": "ok",
              "data": [1, 2, 3, 4, 5],
              "metadata": {
                "page": 1,
                "total": 100,
                "hasMore": true
              }
            }
            """,
        source: "api.js:45"
    )
    manager.addLog(
        type: "error",
        message: "Uncaught TypeError: Cannot read property 'map' of undefined\n    at processData (main.js:123)\n    at handleResponse (api.js:45)\n    at XMLHttpRequest.onload (fetch.js:89)",
        source: "main.js:123"
    )

    return ConsoleView(consoleManager: manager)
        .presentationDetents([.fraction(0.35), .medium, .large])
}
