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

    enum LogType: String, CaseIterable {
        case log
        case info
        case warn
        case error
        case debug

        var icon: String {
            switch self {
            case .log: return "chevron.right"
            case .info: return "info.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .debug: return "ant.fill"
            }
        }

        var color: Color {
            switch self {
            case .log: return .secondary
            case .info: return .blue
            case .warn: return .orange
            case .error: return .red
            case .debug: return .purple
            }
        }

        var label: String {
            switch self {
            case .log: return "Log"
            case .info: return "Info"
            case .warn: return "Warnings"
            case .error: return "Errors"
            case .debug: return "Debug"
            }
        }

        var shortLabel: String {
            switch self {
            case .log: return "LOG"
            case .info: return "INFO"
            case .warn: return "WARN"
            case .error: return "ERROR"
            case .debug: return "DEBUG"
            }
        }
    }
}

// MARK: - Console Manager

@Observable
class ConsoleManager {
    var logs: [ConsoleLog] = []
    var isCapturing: Bool = true

    func addLog(type: String, message: String, source: String? = nil) {
        guard isCapturing else { return }

        // Filter CORS "Script error" - uninformative due to cross-origin security
        let msg = message.lowercased()
        if msg.contains("script error") && (source == nil || source?.isEmpty == true) {
            return
        }

        let logType = ConsoleLog.LogType(rawValue: type) ?? .log
        let log = ConsoleLog(type: logType, message: message, source: source, timestamp: Date())
        DispatchQueue.main.async {
            self.logs.append(log)
        }
    }

    func clear() {
        logs.removeAll()
    }

    var errorCount: Int { logs.filter { $0.type == .error }.count }
    var warnCount: Int { logs.filter { $0.type == .warn }.count }
}

// MARK: - Console View

struct ConsoleView: View {
    let consoleManager: ConsoleManager
    @State private var filterType: ConsoleLog.LogType?
    @State private var searchText: String = ""

    private var filteredLogs: [ConsoleLog] {
        var result = consoleManager.logs

        if let filterType {
            result = result.filter { $0.type == filterType }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.message.localizedCaseInsensitiveContains(searchText)
                || ($0.source?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        consoleManager.clear()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(consoleManager.logs.isEmpty ? .tertiary : .primary)
                    }
                    .disabled(consoleManager.logs.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        consoleManager.isCapturing.toggle()
                    } label: {
                        Image(systemName: consoleManager.isCapturing ? "pause.fill" : "play.fill")
                            .foregroundStyle(consoleManager.isCapturing ? .red : .green)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Filter")
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
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
                        LogRow(log: log)
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
    @State private var isExpanded: Bool = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    // Check if message needs expansion
    // - 80+ chars (likely wraps to 2+ lines on screen)
    // - 2+ newline chars (explicit multiline)
    private var needsExpansion: Bool {
        log.message.count > 80 || log.message.filter { $0 == "\n" }.count >= 2
    }

    // Extract JSON from message (returns original, formatted and minified versions)
    private var extractedJSON: (original: String, formatted: String, minified: String)? {
        let trimmed = log.message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if entire message is JSON
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let minified = try? JSONSerialization.data(withJSONObject: json),
           let formattedStr = String(data: formatted, encoding: .utf8),
           let minifiedStr = String(data: minified, encoding: .utf8) {
            return (trimmed, formattedStr, minifiedStr)
        }

        // Try to find JSON object block in message
        if let startRange = trimmed.range(of: "{"), let endRange = trimmed.range(of: "}", options: .backwards) {
            let jsonPart = String(trimmed[startRange.lowerBound...endRange.upperBound])
            if let data = jsonPart.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let minified = try? JSONSerialization.data(withJSONObject: json),
               let formattedStr = String(data: formatted, encoding: .utf8),
               let minifiedStr = String(data: minified, encoding: .utf8) {
                return (jsonPart, formattedStr, minifiedStr)
            }
        }

        // Try array JSON
        if let startRange = trimmed.range(of: "["), let endRange = trimmed.range(of: "]", options: .backwards) {
            let jsonPart = String(trimmed[startRange.lowerBound...endRange.upperBound])
            if let data = jsonPart.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let minified = try? JSONSerialization.data(withJSONObject: json),
               let formattedStr = String(data: formatted, encoding: .utf8),
               let minifiedStr = String(data: minified, encoding: .utf8) {
                return (jsonPart, formattedStr, minifiedStr)
            }
        }

        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Expand indicator (only if expandable)
            if needsExpansion {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
                    .padding(.top, 4)
            }

            // Message + Source + JSON copy button
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 4) {
                    Text(log.message)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(log.type == .error ? .red : .primary)
                        .lineLimit(isExpanded ? nil : 3)
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

            // Right side: Type badge + timestamp
            VStack(alignment: .trailing, spacing: 4) {
                // Type badge (icon + label)
                TypeBadge(type: log.type)

                Text(Self.timeFormatter.string(from: log.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(log.type == .error ? Color.red.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if needsExpansion {
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
                .padding(.leading, 12)
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

#Preview {
    let manager = ConsoleManager()
    manager.addLog(type: "log", message: "Application started", source: "app.js:1")
    manager.addLog(type: "info", message: "User session initialized", source: "auth.js:45")
    manager.addLog(type: "log", message: "Fetching data from API...", source: "api.js:23")
    manager.addLog(type: "warn", message: "Deprecated API usage: navigator.userAgent", source: "utils.js:78")
    manager.addLog(type: "error", message: "Failed to fetch: 404 Not Found", source: "api.js:31")
    manager.addLog(type: "debug", message: "onClick event fired: #submit-btn", source: "button.js:12")
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
