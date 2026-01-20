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
    var timestamp: Date
    var groupLevel: Int = 0  // Indentation level for groups
    var groupId: UUID?  // For groupCollapsed toggle
    var isCollapsed: Bool = false  // For groupCollapsed
    var tableData: [[String: String]]?  // For console.table

    // ✨ Timer Support (console.time/timeLog/timeEnd)
    var timerLabel: String?
    var timerElapsed: TimeInterval?

    // ✨ Count Support (console.count/countReset)
    var countLabel: String?
    var countValue: Int?

    // ✨ Trace Support (console.trace)
    var stackTrace: String?

    // ✨ Styled Segments Support (console.log("%c..."))
    var styledSegments: [[String: Any]]?  // Raw JSON from JavaScript

    // ✨ Inline Segments Support (console.log("label", 1, true))
    var inlineSegments: [ConsoleInlineSegment]?

    // ✨ Object Support (console.dir, console.log with objects)
    var objectValue: ConsoleValue?
    var repeatCount: Int = 1

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
        // ✨ New types
        case time           // console.time
        case timeLog        // console.timeLog
        case timeEnd        // console.timeEnd
        case count          // console.count
        case countReset     // console.countReset
        case assert         // console.assert
        case dir            // console.dir
        case trace          // console.trace
        case command        // User input command
        case result         // Command execution result

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
            case .time, .timeLog, .timeEnd: return "stopwatch.fill"
            case .count, .countReset: return "number.circle.fill"
            case .assert: return "exclamationmark.circle.fill"
            case .dir: return "tree"
            case .trace: return "arrow.down.right.circle.fill"
            case .command: return "chevron.right.circle.fill"
            case .result: return "checkmark.circle.fill"
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
            case .time, .timeLog, .timeEnd: return .mint
            case .count, .countReset: return .indigo
            case .assert: return .orange
            case .dir: return .blue
            case .trace: return .gray
            case .command: return .cyan
            case .result: return .green
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
            case .time: return "Timer"
            case .timeLog: return "Timer"
            case .timeEnd: return "Timer"
            case .count: return "Count"
            case .countReset: return "Count"
            case .assert: return "Assert"
            case .dir: return "Dir"
            case .trace: return "Trace"
            case .command: return "Command"
            case .result: return "Result"
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
            case .time: return "TIME"
            case .timeLog: return "TIME"
            case .timeEnd: return "TIME"
            case .count: return "COUNT"
            case .countReset: return "COUNT"
            case .assert: return "ASSERT"
            case .dir: return "DIR"
            case .trace: return "TRACE"
            case .command: return "CMD"
            case .result: return "RES"
            }
        }

        // Types shown in filter tabs
        static var filterTypes: [LogType] {
            [.error, .warn, .info, .log, .debug, .assert, .trace]
        }

        // Types that can be displayed (excludes internal types like groupEnd)
        static var displayableTypes: [LogType] {
            [
                .log, .info, .warn, .error, .debug, .group, .groupCollapsed, .table,
                .time, .timeLog, .timeEnd, .count, .countReset, .assert, .dir, .trace,
                .command, .result
            ]
        }

        // Types shown in settings (one representative per label group)
        static var settingsDisplayTypes: [LogType] {
            [.log, .info, .warn, .error, .debug, .group, .table, .time, .count, .assert, .dir, .trace, .command, .result]
        }

        // Related types controlled by a representative type (for settings toggles)
        var relatedTypes: [LogType] {
            switch self {
            case .group: return [.group, .groupCollapsed]
            case .time: return [.time, .timeLog, .timeEnd]
            case .count: return [.count, .countReset]
            default: return [self]
            }
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

    // ✨ Timer support (console.time/timeEnd)
    private var timerContexts: [String: Date] = [:]

    // ✨ Count support (console.count/countReset)
    private var countContexts: [String: Int] = [:]

    // Read preserveLog from UserDefaults (set via @AppStorage in ConsoleSettingsSheet)
    var preserveLog: Bool {
        UserDefaults.standard.bool(forKey: "consolePreserveLog")
    }

    func addLog(
        type: String,
        message: String,
        source: String? = nil,
        tableData: [[String: String]]? = nil,
        objectValue: ConsoleValue? = nil,
        styledSegments: [[String: Any]]? = nil,
        inlineSegments: [ConsoleInlineSegment]? = nil
    ) {
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
            log.objectValue = objectValue
            log.styledSegments = styledSegments
            log.inlineSegments = inlineSegments

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

            if self.shouldCollapseRepeat(log: log), let lastIndex = self.logs.indices.last {
                var updated = self.logs[lastIndex]
                if self.isSameRepeat(lhs: updated, rhs: log) {
                    updated.repeatCount += 1
                    updated.timestamp = log.timestamp
                    self.logs[lastIndex] = updated
                    return
                }
            }

            self.logs.append(log)
        }
    }

    private func shouldCollapseRepeat(log: ConsoleLog) -> Bool {
        switch log.type {
        case .log, .info, .warn, .error, .debug, .dir, .trace:
            return true
        default:
            return false
        }
    }

    private func isSameRepeat(lhs: ConsoleLog, rhs: ConsoleLog) -> Bool {
        guard lhs.type == rhs.type,
              lhs.message == rhs.message,
              lhs.source == rhs.source,
              lhs.groupLevel == rhs.groupLevel,
              lhs.groupId == rhs.groupId,
              lhs.tableData == rhs.tableData,
              lhs.objectValue == rhs.objectValue,
              lhs.inlineSegments == rhs.inlineSegments else {
            return false
        }
        return styledSegmentsEqual(lhs.styledSegments, rhs.styledSegments)
    }

    private func styledSegmentsEqual(_ lhs: [[String: Any]]?, _ rhs: [[String: Any]]?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhsArray?, rhsArray?):
            return NSArray(array: lhsArray).isEqual(rhsArray)
        default:
            return false
        }
    }

    func toggleGroup(_ groupId: UUID) {
        if collapsedGroups.contains(groupId) {
            collapsedGroups.remove(groupId)
        } else {
            collapsedGroups.insert(groupId)
        }
    }

    // MARK: - Timer Methods (console.time/timeLog/timeEnd)

    /// console.time(label) - 타이머 시작
    func time(label: String = "default") {
        DispatchQueue.main.async {
            self.timerContexts[label] = Date()
            var log = ConsoleLog(type: .time, message: "Timer '\(label)' started", source: nil, timestamp: Date())
            log.timerLabel = label
            self.logs.append(log)
        }
    }

    /// console.timeLog(label) - 현재까지 경과 시간 로깅
    func timeLog(label: String = "default") {
        DispatchQueue.main.async {
            guard let startTime = self.timerContexts[label] else {
                self.addLog(type: "error", message: "Timer '\(label)' not found")
                return
            }
            let elapsed = Date().timeIntervalSince(startTime) * 1000  // milliseconds
            var log = ConsoleLog(type: .timeLog, message: "\(label): \(String(format: "%.3f", elapsed))ms", source: nil, timestamp: Date())
            log.timerLabel = label
            log.timerElapsed = elapsed / 1000
            self.logs.append(log)
        }
    }

    /// console.timeEnd(label) - 타이머 종료 및 결과 로깅
    func timeEnd(label: String = "default") {
        DispatchQueue.main.async {
            guard let startTime = self.timerContexts[label] else {
                self.addLog(type: "error", message: "Timer '\(label)' not found")
                return
            }
            let elapsed = Date().timeIntervalSince(startTime) * 1000  // milliseconds
            self.timerContexts.removeValue(forKey: label)
            var log = ConsoleLog(type: .timeEnd, message: "\(label): \(String(format: "%.3f", elapsed))ms", source: nil, timestamp: Date())
            log.timerLabel = label
            log.timerElapsed = elapsed / 1000
            self.logs.append(log)
        }
    }

    // MARK: - Count Methods (console.count/countReset)

    /// console.count(label) - 카운트 증가 및 로깅
    func count(label: String = "default") {
        DispatchQueue.main.async {
            let newCount = (self.countContexts[label] ?? 0) + 1
            self.countContexts[label] = newCount
            var log = ConsoleLog(type: .count, message: "\(label): \(newCount)", source: nil, timestamp: Date())
            log.countLabel = label
            log.countValue = newCount
            self.logs.append(log)
        }
    }

    /// console.countReset(label) - 카운트 리셋
    func countReset(label: String = "default") {
        DispatchQueue.main.async {
            let previousCount = self.countContexts[label] ?? 0
            self.countContexts.removeValue(forKey: label)
            self.addLog(type: "countReset", message: "\(label) count reset (was \(previousCount))")
        }
    }

    /// console.assert(condition, message) - 조건 검증
    func assert(_ condition: Bool, message: String) {
        guard !condition else { return }
        DispatchQueue.main.async {
            self.addLog(type: "assert", message: "Assertion failed: \(message)")
        }
    }

    func clear() {
        logs.removeAll()
        currentGroupLevel = 0
        groupStack.removeAll()
        collapsedGroups.removeAll()
        timerContexts.removeAll()
        countContexts.removeAll()
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

// MARK: - Scroll Metrics

struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
}

// MARK: - Console View

// Identifiable wrapper for share content to fix sheet timing issue
struct ShareContent: Identifiable {
    let id = UUID()
    let content: String
}

struct ConsoleView: View {
    let consoleManager: ConsoleManager
    var navigator: WebViewNavigator?  // Optional - for JS execution
    @Environment(\.dismiss) private var dismiss
    @State private var filterType: ConsoleLog.LogType?
    @State private var searchText: String = ""
    @State private var useRegex: Bool = false
    @State private var shareItem: ShareContent?
    @State private var showSettings: Bool = false
    // Log types to show in "All" tab (user configurable)
    @State private var enabledLogTypes: Set<ConsoleLog.LogType> = Set(ConsoleLog.LogType.displayableTypes)
    // AppStorage for settings indicator (matches ConsoleSettingsSheet)
    @AppStorage("consolePreserveLog") private var preserveLog: Bool = false
    @AppStorage("logClearStrategy") private var clearStrategyRaw: String = LogClearStrategy.keep.rawValue
    // JavaScript input
    @State private var jsInput: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @FocusState private var isInputFocused: Bool
    // Scroll navigation state
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?

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
        useRegex || preserveLog ||
        clearStrategyRaw != LogClearStrategy.keep.rawValue ||
        enabledLogTypes.count != ConsoleLog.LogType.displayableTypes.count
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

            // JavaScript execution input (only shown when navigator is available)
            if navigator != nil {
                jsInputField
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
        .task {
            await AdManager.shared.showInterstitialAd(
                options: AdOptions(id: "console_devtools"),
                adUnitId: AdManager.interstitialAdUnitId
            )
        }
    }

    // MARK: - Console Header

    private var consoleHeader: some View {
        DevToolsHeader(
            title: "Console",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(
                    icon: "trash",
                    isDisabled: consoleManager.logs.isEmpty
                ) {
                    consoleManager.clear()
                },
                .init(
                    icon: "square.and.arrow.up",
                    isDisabled: filteredLogs.isEmpty
                ) {
                    shareItem = ShareContent(content: ConsoleExporter.exportAsText(filteredLogs))
                }
            ],
            rightButtons: [
                .init(
                    icon: "play.fill",
                    activeIcon: "pause.fill",
                    color: .green,
                    activeColor: .red,
                    isActive: consoleManager.isCapturing
                ) {
                    consoleManager.isCapturing.toggle()
                },
                .init(
                    icon: "gearshape",
                    activeIcon: "gearshape.fill",
                    isActive: settingsActive
                ) {
                    showSettings = true
                }
            ]
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(useRegex ? "Regex" : "Filter", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Console View Extensions

extension ConsoleView {
    // MARK: - Filter Tabs

    var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ConsoleFilterTab(label: "All", count: consoleManager.logs.count, isSelected: filterType == nil) {
                    filterType = nil
                }

                ConsoleFilterTab(label: "Errors", count: consoleManager.errorCount, isSelected: filterType == .error, color: .red) {
                    filterType = .error
                }

                ConsoleFilterTab(label: "Warnings", count: consoleManager.warnCount, isSelected: filterType == .warn, color: .orange) {
                    filterType = .warn
                }

                ForEach([ConsoleLog.LogType.info, .log, .debug], id: \.self) { type in
                    ConsoleFilterTab(
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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
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
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
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
            .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                ScrollMetrics(
                    offset: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.visibleRect.height
                )
            } action: { oldValue, newValue in
                // Batch update to reduce state changes
                if oldValue != newValue {
                    scrollOffset = newValue.offset
                    contentHeight = newValue.contentHeight
                    scrollViewHeight = newValue.viewportHeight
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: consoleManager.logs.count) { _, _ in
                if let lastLog = filteredLogs.last {
                    proxy.scrollTo(lastLog.id, anchor: .bottom)
                }
            }
            // 스크롤 네비게이션 버튼 오버레이
            .scrollNavigationOverlay(
                scrollOffset: scrollOffset,
                contentHeight: contentHeight,
                viewportHeight: scrollViewHeight,
                onScrollUp: { scrollUp(proxy: scrollProxy) },
                onScrollDown: { scrollDown(proxy: scrollProxy) }
            )
        }
    }

    // MARK: - Scroll Navigation

    private func scrollUp(proxy: ScrollViewProxy?) {
        guard let proxy, let firstLog = filteredLogs.first else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(firstLog.id, anchor: .top)
        }
    }

    private func scrollDown(proxy: ScrollViewProxy?) {
        guard let proxy, let lastLog = filteredLogs.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastLog.id, anchor: .bottom)
        }
    }

    // MARK: - JavaScript Input Field

    private var jsInputField: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 8) {
                // Prompt symbol
                Text(">")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)

                // Input field
                TextField("JavaScript to execute...", text: $jsInput, axis: .vertical)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeJavaScript()
                    }
                    .submitLabel(.send)

                // History navigation buttons (only when there's history)
                if !commandHistory.isEmpty {
                    HStack(spacing: 4) {
                        Button {
                            navigateHistory(direction: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .disabled(historyIndex >= commandHistory.count - 1)

                        Button {
                            navigateHistory(direction: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .disabled(historyIndex <= 0)
                    }
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }

                // Execute button
                Button {
                    executeJavaScript()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(jsInput.isEmpty ? Color.gray : Color.cyan, in: Circle())
                }
                .disabled(jsInput.isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }

    // MARK: - JavaScript Execution

    /// Replace iOS smart quotes with straight quotes for valid JavaScript
    private func sanitizeSmartQuotes(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\u{2018}", with: "'")  // '
            .replacingOccurrences(of: "\u{2019}", with: "'")  // '
            .replacingOccurrences(of: "\u{201C}", with: "\"") // "
            .replacingOccurrences(of: "\u{201D}", with: "\"") // "
    }

    private func executeJavaScript() {
        let rawCommand = jsInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = sanitizeSmartQuotes(rawCommand)
        guard !command.isEmpty, let nav = navigator else { return }

        // Add to history
        if commandHistory.last != command {
            commandHistory.append(command)
        }
        historyIndex = -1

        // Log the command
        consoleManager.addLog(type: "command", message: command, source: "user input")

        // Clear input
        jsInput = ""

        // Execute and log result
        Task {
            let result = await nav.evaluateJavaScript(command)
            await MainActor.run {
                let resultText: String
                if let result {
                    resultText = formatJSResult(result)
                } else {
                    resultText = "undefined"
                }
                consoleManager.addLog(type: "result", message: resultText, source: nil)
            }
        }
    }

    private func formatJSResult(_ result: Any) -> String {
        switch result {
        case let string as String:
            return "\"\(string)\""
        case let number as NSNumber:
            // Check if it's a boolean
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case let array as [Any]:
            let items = array.map { formatJSResult($0) }.joined(separator: ", ")
            return "[\(items)]"
        case let dict as [String: Any]:
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return String(describing: dict)
        default:
            return String(describing: result)
        }
    }

    private func navigateHistory(direction: Int) {
        let newIndex = historyIndex - direction
        if newIndex >= 0 && newIndex < commandHistory.count {
            historyIndex = newIndex
            jsInput = commandHistory[commandHistory.count - 1 - historyIndex]
        } else if newIndex < 0 {
            historyIndex = -1
            jsInput = ""
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
        .devToolsSheet()
}
