//
//  NetworkView.swift
//  wina
//
//  Network request monitoring view for WKWebView.
//  Captures fetch/XMLHttpRequest via JavaScript injection.
//

import SwiftSoup
import SwiftUI

// MARK: - Network Body Storage (Disk-based)

final class NetworkBodyStorage {
    static let shared = NetworkBodyStorage()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.wina.networkbodystorage", qos: .utility)

    private lazy var cacheDirectory: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("NetworkBodies", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    enum BodyType: String {
        case request
        case response
    }

    private init() {}

    // MARK: - Public API

    func save(id: UUID, type: BodyType, body: String) {
        queue.async { [weak self] in
            guard let self, !body.isEmpty else { return }
            let url = self.fileURL(for: id, type: type)
            try? body.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func load(id: UUID, type: BodyType) -> String? {
        let url = fileURL(for: id, type: type)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func loadAsync(id: UUID, type: BodyType, completion: @escaping (String?) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let result = self.load(id: id, type: type)
            DispatchQueue.main.async { completion(result) }
        }
    }

    func delete(id: UUID) {
        queue.async { [weak self] in
            guard let self else { return }
            try? self.fileManager.removeItem(at: self.fileURL(for: id, type: .request))
            try? self.fileManager.removeItem(at: self.fileURL(for: id, type: .response))
        }
    }

    func delete(ids: [UUID]) {
        queue.async { [weak self] in
            guard let self else { return }
            for id in ids {
                try? self.fileManager.removeItem(at: self.fileURL(for: id, type: .request))
                try? self.fileManager.removeItem(at: self.fileURL(for: id, type: .response))
            }
        }
    }

    func clearAll() {
        queue.async { [weak self] in
            guard let self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // Clear cache on app launch (previous session data)
    func clearOnLaunchIfNeeded() {
        // Only clear if not preserving logs
        let preserveLog = UserDefaults.standard.bool(forKey: "networkPreserveLog")
        if !preserveLog {
            clearAll()
        }
    }

    // MARK: - Private

    private func fileURL(for id: UUID, type: BodyType) -> URL {
        cacheDirectory.appendingPathComponent("\(id.uuidString)_\(type.rawValue).txt")
    }
}

// MARK: - Network Request Model

struct NetworkRequest: Identifiable, Equatable {
    let id: UUID
    let method: String
    let url: String
    let requestHeaders: [String: String]?
    let requestBodyPreview: String?  // First 500 chars for list display
    let startTime: Date
    var status: Int?
    var statusText: String?
    var responseHeaders: [String: String]?
    var responseBodyPreview: String?  // First 500 chars for list display
    var endTime: Date?
    var error: String?
    var requestType: RequestType

    // Preview length for memory storage
    static let previewLength = 500

    // Load full body from disk (for detail view, copy, share)
    func loadFullRequestBody() -> String? {
        NetworkBodyStorage.shared.load(id: id, type: .request)
    }

    func loadFullResponseBody() -> String? {
        NetworkBodyStorage.shared.load(id: id, type: .response)
    }

    // Convenience: return full body if available, otherwise preview
    var requestBody: String? {
        loadFullRequestBody() ?? requestBodyPreview
    }

    var responseBody: String? {
        loadFullResponseBody() ?? responseBodyPreview
    }

    enum RequestType: String, CaseIterable {
        case fetch
        case xhr
        case document
        case other

        var icon: String {
            switch self {
            case .fetch: return "arrow.down.doc"
            case .xhr: return "arrow.triangle.2.circlepath"
            case .document: return "doc.text"
            case .other: return "questionmark.circle"
            }
        }

        var label: String {
            switch self {
            case .fetch: return "Fetch"
            case .xhr: return "XHR"
            case .document: return "Doc"
            case .other: return "Other"
            }
        }
    }

    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var durationText: String {
        guard let duration else { return "..." }
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }

    var statusColor: Color {
        guard let status else { return .secondary }
        switch status {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500...: return .red
        default: return .secondary
        }
    }

    var isComplete: Bool {
        endTime != nil || error != nil
    }

    var isPending: Bool {
        !isComplete
    }

    // Extract host from URL
    var host: String {
        guard let parsedURL = URL(string: url) else { return url }
        return parsedURL.host ?? url
    }

    // Extract path from URL
    var path: String {
        guard let url = URL(string: url) else { return self.url }
        return url.path.isEmpty ? "/" : url.path
    }

    // Response content type from headers or body detection
    var responseContentType: String {
        // Check Content-Type header first
        if let contentTypeHeader = responseHeaders?["Content-Type"] ?? responseHeaders?["content-type"] {
            if contentTypeHeader.contains("application/json") {
                return "JSON"
            } else if contentTypeHeader.contains("text/html") {
                return "HTML"
            } else if contentTypeHeader.contains("text/xml") || contentTypeHeader.contains("application/xml") {
                return "XML"
            } else if contentTypeHeader.contains("text/plain") {
                return "Text"
            } else if contentTypeHeader.contains("text/css") {
                return "CSS"
            } else if contentTypeHeader.contains("javascript") {
                return "JS"
            } else if contentTypeHeader.contains("image/") {
                return "Image"
            } else if contentTypeHeader.contains("font/") {
                return "Font"
            }
        }

        // Fallback: detect from body content (use preview to avoid disk I/O)
        guard let body = responseBodyPreview else { return "—" }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return "JSON"
        }
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
            return "HTML"
        }
        if trimmed.hasPrefix("<?xml") {
            return "XML"
        }
        return "Text"
    }

    // Color for response content type
    var responseContentTypeColor: Color {
        switch responseContentType {
        case "JSON": return .purple
        case "HTML": return .orange
        case "XML": return .teal
        case "CSS": return .pink
        case "JS": return .yellow
        case "Image": return .green
        case "Font": return .cyan
        case "Text": return .gray
        default: return Color(uiColor: .tertiaryLabel)
        }
    }

    static func == (lhs: NetworkRequest, rhs: NetworkRequest) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.endTime == rhs.endTime &&
        lhs.error == rhs.error
    }
}

// MARK: - Network Manager

@Observable
class NetworkManager {
    var requests: [NetworkRequest] = []
    var isCapturing: Bool = true

    // Limits for memory management (only affects request count, not body size)
    private let maxRequestCount = 500
    private let bodyStorage = NetworkBodyStorage.shared

    // Read preserveLog from UserDefaults
    var preserveLog: Bool {
        UserDefaults.standard.bool(forKey: "networkPreserveLog")
    }

    func addRequest(
        id: String,
        method: String,
        url: String,
        requestType: String,
        headers: [String: String]?,
        body: String?
    ) {
        guard isCapturing else { return }

        let type = NetworkRequest.RequestType(rawValue: requestType) ?? .other
        let uuid = UUID(uuidString: id) ?? UUID()

        // Save full body to disk
        if let body, !body.isEmpty {
            bodyStorage.save(id: uuid, type: .request, body: body)
        }

        // Store only preview in memory
        let preview = body.map { String($0.prefix(NetworkRequest.previewLength)) }

        let request = NetworkRequest(
            id: uuid,
            method: method.uppercased(),
            url: url,
            requestHeaders: headers,
            requestBodyPreview: preview,
            startTime: Date(),
            requestType: type
        )

        DispatchQueue.main.async {
            // Enforce max request count - delete disk files for removed requests
            if self.requests.count >= self.maxRequestCount {
                let removedRequest = self.requests.removeFirst()
                self.bodyStorage.delete(id: removedRequest.id)
            }
            self.requests.append(request)
        }
    }

    func updateRequest(
        id: String,
        status: Int?,
        statusText: String?,
        responseHeaders: [String: String]?,
        responseBody: String?,
        error: String?
    ) {
        guard let uuid = UUID(uuidString: id) else { return }

        // Save full response body to disk
        if let responseBody, !responseBody.isEmpty {
            bodyStorage.save(id: uuid, type: .response, body: responseBody)
        }

        // Store only preview in memory
        let preview = responseBody.map { String($0.prefix(NetworkRequest.previewLength)) }

        DispatchQueue.main.async {
            if let index = self.requests.firstIndex(where: { $0.id == uuid }) {
                // Replace entire struct to ensure @Observable detects the change
                var updated = self.requests[index]
                updated.status = status
                updated.statusText = statusText
                updated.responseHeaders = responseHeaders
                updated.responseBodyPreview = preview
                updated.error = error
                updated.endTime = Date()
                self.requests[index] = updated
            }
        }
    }

    func clear() {
        // Delete all disk files
        let ids = requests.map(\.id)
        bodyStorage.delete(ids: ids)
        requests.removeAll()
    }

    func clearIfNotPreserved() {
        guard !preserveLog else { return }
        clear()
    }

    var pendingCount: Int { requests.filter(\.isPending).count }
    var errorCount: Int { requests.filter { $0.error != nil || ($0.status ?? 0) >= 400 }.count }
}

// MARK: - Network View

// Identifiable wrapper for share content
struct NetworkShareContent: Identifiable {
    let id = UUID()
    let content: String
}

struct NetworkView: View {
    let networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss
    @State private var filterType: NetworkRequest.RequestType?
    @State private var showErrorsOnly: Bool = false
    @State private var searchText: String = ""
    @State private var shareItem: NetworkShareContent?
    @State private var showSettings: Bool = false
    @State private var selectedRequest: NetworkRequest?
    @AppStorage("networkPreserveLog") private var preserveLog: Bool = false

    private var filteredRequests: [NetworkRequest] {
        var result = networkManager.requests

        if showErrorsOnly {
            result = result.filter { $0.error != nil || ($0.status ?? 0) >= 400 }
        } else if let filterType {
            result = result.filter { $0.requestType == filterType }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.url.localizedCaseInsensitiveContains(searchText)
                    || $0.method.localizedCaseInsensitiveContains(searchText)
                    || ($0.statusText?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var settingsActive: Bool {
        preserveLog
    }

    var body: some View {
        VStack(spacing: 0) {
            networkHeader
            searchBar
            filterTabs

            Divider()

            if filteredRequests.isEmpty {
                emptyState
            } else {
                requestList
            }
        }
        .sheet(item: $shareItem) { item in
            NetworkShareSheet(content: item.content)
        }
        .sheet(isPresented: $showSettings) {
            NetworkSettingsSheet()
        }
        .sheet(item: $selectedRequest) { request in
            NetworkDetailView(request: request)
        }
    }

    // MARK: - Network Header

    private var networkHeader: some View {
        DevToolsHeader(
            title: "Network",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(
                    icon: "trash",
                    isDisabled: networkManager.requests.isEmpty
                ) {
                    networkManager.clear()
                },
                .init(
                    icon: "square.and.arrow.up",
                    isDisabled: networkManager.requests.isEmpty
                ) {
                    shareItem = NetworkShareContent(content: exportAsText())
                }
            ],
            rightButtons: [
                .init(
                    icon: "play.fill",
                    activeIcon: "pause.fill",
                    color: .green,
                    activeColor: .red,
                    isActive: networkManager.isCapturing
                ) {
                    networkManager.isCapturing.toggle()
                },
                .init(
                    icon: "gearshape",
                    activeIcon: "gearshape.fill",
                    color: .secondary,
                    activeColor: .blue,
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
            TextField("Filter", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                NetworkFilterTab(
                    label: "All",
                    count: networkManager.requests.count,
                    isSelected: filterType == nil && !showErrorsOnly
                ) {
                    filterType = nil
                    showErrorsOnly = false
                }

                ForEach(NetworkRequest.RequestType.allCases, id: \.self) { type in
                    NetworkFilterTab(
                        label: type.label,
                        count: networkManager.requests.filter { $0.requestType == type }.count,
                        isSelected: filterType == type && !showErrorsOnly
                    ) {
                        filterType = type
                        showErrorsOnly = false
                    }
                }

                NetworkFilterTab(
                    label: "Errors",
                    count: networkManager.errorCount,
                    isSelected: showErrorsOnly,
                    color: .red
                ) {
                    filterType = nil
                    showErrorsOnly = true
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
            Image(systemName: "network")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(networkManager.requests.isEmpty ? "No requests" : "No matches")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !networkManager.isCapturing {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Request List

    private var requestList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRequests) { request in
                        NetworkRequestRow(request: request)
                            .id(request.id)
                            .onTapGesture {
                                selectedRequest = request
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .scrollContentBackground(.hidden)
            .onChange(of: networkManager.requests.count) { _, _ in
                if let lastRequest = filteredRequests.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastRequest.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Export

    private func exportAsText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        // Build header with filter info
        var header = "Network Log Export"
        if let filterType {
            header += " (Filter: \(filterType.label))"
        }
        if !searchText.isEmpty {
            header += " (Search: \(searchText))"
        }
        header += "\nExported: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))"
        header += "\nTotal: \(filteredRequests.count) requests"
        header += "\n" + String(repeating: "─", count: 50) + "\n\n"

        let body = filteredRequests
            .map { req in
                var line = "[\(dateFormatter.string(from: req.startTime))] \(req.method) \(req.url)"
                if let status = req.status {
                    line += " → \(status)"
                }
                if let duration = req.duration {
                    line += " (\(String(format: "%.0fms", duration * 1000)))"
                }
                if let error = req.error {
                    line += " ERROR: \(error)"
                }
                return line
            }
            .joined(separator: "\n\n")

        return header + body
    }
}

// MARK: - Network Filter Tab

private struct NetworkFilterTab: View {
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
                        .background(
                            isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
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

// MARK: - Network Request Row

private struct NetworkRequestRow: View {
    let request: NetworkRequest

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Status indicator
            Circle()
                .fill(request.isPending ? Color.orange : request.statusColor)
                .frame(width: 8, height: 8)

            // Method badge
            Text(request.method)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(methodColor, in: RoundedRectangle(cornerRadius: 4))

            // URL
            VStack(alignment: .leading, spacing: 2) {
                Text(request.path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(request.host)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Right side info
            VStack(alignment: .trailing, spacing: 2) {
                // Status code or pending
                if let status = request.status {
                    Text("\(status)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(request.statusColor)
                } else if request.error != nil {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                // Duration
                Text(request.durationText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Response content type
            Text(request.responseContentType)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(request.responseContentTypeColor)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(request.error != nil ? Color.red.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 12)
        }
    }

    private var methodColor: Color {
        switch request.method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        default: return .secondary
        }
    }
}

// MARK: - Network Share Sheet

private struct NetworkShareSheet: UIViewControllerRepresentable {
    let content: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [content], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Network File Share Sheet

// Extension to make URL work with sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private struct NetworkFileShareSheet: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Network Settings Sheet

private struct NetworkSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("networkPreserveLog") private var preserveLog: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Logging") {
                    Toggle("Preserve Log on Reload", isOn: $preserveLog)
                }
            }
            .navigationTitle("Network Settings")
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

// MARK: - Network Detail View

private struct NetworkDetailView: View {
    let request: NetworkRequest
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .headers
    @State private var copiedFeedback: String?
    @State private var shareItem: NetworkShareContent?
    @State private var shareFileURL: URL?

    // Response search state
    @State private var responseSearchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    // URL expand/collapse state
    @State private var isURLExpanded: Bool = false
    private let urlCollapseThreshold = 80

    enum DetailTab: String, CaseIterable {
        case headers = "Headers"
        case request = "Request"
        case response = "Response"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                requestSummary

                Divider()

                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case .headers:
                        headersContent
                    case .request:
                        requestContent
                    case .response:
                        responseContent
                    }
                }
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        shareRequest()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let feedback = copiedFeedback {
                    CopiedFeedbackToast(message: feedback)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: copiedFeedback)
            .sheet(item: $shareItem) { item in
                NetworkShareSheet(content: item.content)
            }
            .sheet(item: $shareFileURL) { url in
                NetworkFileShareSheet(fileURL: url)
            }
        }
    }

    // MARK: - Summary

    private var isURLLong: Bool {
        request.url.count > urlCollapseThreshold
    }

    private var requestSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.method)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(methodColor, in: RoundedRectangle(cornerRadius: 6))

                if let status = request.status {
                    Text("\(status)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(request.statusColor)
                }

                Text(request.durationText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Quick copy URL button
                GlassIconButton(icon: "doc.on.doc", size: .small) {
                    copyToClipboard(request.url, label: "URL")
                }
            }

            // Collapsible URL with selectable text
            if isURLLong {
                VStack(alignment: .leading, spacing: 4) {
                    if isURLExpanded {
                        SelectableTextView(
                            text: request.url,
                            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                            padding: .zero
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(String(request.url.prefix(urlCollapseThreshold)) + "...")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isURLExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isURLExpanded ? "Show less" : "Show full URL")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: isURLExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            } else {
                SelectableTextView(
                    text: request.url,
                    font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                    padding: .zero
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = request.error {
                Text("Error: \(error)")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Headers Tab

    @ViewBuilder
    private var headersContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // General info section
            DetailSection(title: "General", rawText: generalRawText, onCopy: copyToClipboard) {
                DetailTableRow(key: "Request URL", value: request.url, onCopy: copyToClipboard)
                DetailTableRow(key: "Request Method", value: request.method, onCopy: copyToClipboard)
                if let status = request.status, let statusText = request.statusText {
                    DetailTableRow(key: "Status Code", value: "\(status) \(statusText)", onCopy: copyToClipboard)
                } else if let status = request.status {
                    DetailTableRow(key: "Status Code", value: "\(status)", onCopy: copyToClipboard)
                }
                DetailTableRow(key: "Type", value: request.requestType.rawValue.capitalized, onCopy: copyToClipboard, showBorder: false)
            }

            // Response headers
            if let headers = request.responseHeaders, !headers.isEmpty {
                let sortedHeaders = headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
                DetailSection(
                    title: "Response Headers",
                    rawText: formatHeadersForCopy(headers),
                    onCopy: copyToClipboard
                ) {
                    ForEach(Array(sortedHeaders.enumerated()), id: \.element.key) { index, pair in
                        DetailTableRow(
                            key: pair.key,
                            value: pair.value,
                            onCopy: copyToClipboard,
                            showBorder: index < sortedHeaders.count - 1
                        )
                    }
                }
            }

            // Request headers
            if let headers = request.requestHeaders, !headers.isEmpty {
                let sortedHeaders = headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
                DetailSection(
                    title: "Request Headers",
                    rawText: formatHeadersForCopy(headers),
                    onCopy: copyToClipboard
                ) {
                    ForEach(Array(sortedHeaders.enumerated()), id: \.element.key) { index, pair in
                        DetailTableRow(
                            key: pair.key,
                            value: pair.value,
                            onCopy: copyToClipboard,
                            showBorder: index < sortedHeaders.count - 1
                        )
                    }
                }
            }

            if request.requestHeaders == nil && request.responseHeaders == nil {
                emptyState(message: "No headers available")
            }
        }
        .padding()
    }

    private var generalRawText: String {
        var lines: [String] = []
        lines.append("Request URL: \(request.url)")
        lines.append("Request Method: \(request.method)")
        if let status = request.status, let statusText = request.statusText {
            lines.append("Status Code: \(status) \(statusText)")
        } else if let status = request.status {
            lines.append("Status Code: \(status)")
        }
        lines.append("Type: \(request.requestType.rawValue.capitalized)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Request Tab

    @ViewBuilder
    private var requestContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // URL breakdown
            if let urlComponents = URLComponents(string: request.url) {
                DetailSection(title: "URL", rawText: urlRawText(urlComponents), onCopy: copyToClipboard) {
                    if let scheme = urlComponents.scheme {
                        DetailTableRow(key: "Scheme", value: scheme, onCopy: copyToClipboard)
                    }
                    if let host = urlComponents.host {
                        DetailTableRow(key: "Host", value: host, onCopy: copyToClipboard)
                    }
                    if let port = urlComponents.port {
                        DetailTableRow(key: "Port", value: "\(port)", onCopy: copyToClipboard)
                    }
                    DetailTableRow(
                        key: "Path",
                        value: urlComponents.path.isEmpty ? "/" : urlComponents.path,
                        onCopy: copyToClipboard,
                        showBorder: false
                    )
                }

                // Query parameters
                if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                    DetailSection(
                        title: "Query Parameters",
                        rawText: queryParametersRawText(queryItems),
                        onCopy: copyToClipboard
                    ) {
                        ForEach(Array(queryItems.enumerated()), id: \.element.name) { index, item in
                            DetailTableRow(
                                key: item.name,
                                value: item.value ?? "(empty)",
                                onCopy: copyToClipboard,
                                showBorder: index < queryItems.count - 1
                            )
                        }
                    }
                }
            }

            // Request body
            if let body = request.requestBody, !body.isEmpty {
                let contentType = detectContentType(body: body, headers: request.requestHeaders)
                let bodySize = body.data(using: .utf8)?.count ?? 0
                DetailSection(title: "Request Body", rawText: body, onCopy: copyToClipboard) {
                    BodyHeaderView(contentType: contentType, size: bodySize)
                    FormattedBodyView(bodyText: body, contentType: contentType)
                }
            } else {
                emptyState(message: "No request body")
            }
        }
        .padding()
    }

    private func urlRawText(_ components: URLComponents) -> String {
        var lines: [String] = []
        if let scheme = components.scheme {
            lines.append("Scheme: \(scheme)")
        }
        if let host = components.host {
            lines.append("Host: \(host)")
        }
        if let port = components.port {
            lines.append("Port: \(port)")
        }
        lines.append("Path: \(components.path.isEmpty ? "/" : components.path)")
        return lines.joined(separator: "\n")
    }

    private func queryParametersRawText(_ items: [URLQueryItem]) -> String {
        items.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
    }

    // MARK: - Response Tab

    @ViewBuilder
    private var responseContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let body = request.responseBody, !body.isEmpty {
                // Search bar
                ResponseSearchBar(
                    searchText: $responseSearchText,
                    currentMatch: currentMatchIndex,
                    totalMatches: totalMatches,
                    onPrevious: {
                        if totalMatches > 0 {
                            currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
                        }
                    },
                    onNext: {
                        if totalMatches > 0 {
                            currentMatchIndex = (currentMatchIndex + 1) % totalMatches
                        }
                    }
                )
                .onChange(of: responseSearchText) { _, _ in
                    currentMatchIndex = 0
                }

                VStack(alignment: .leading, spacing: 20) {
                    let contentType = detectContentType(body: body, headers: request.responseHeaders)
                    let bodySize = body.data(using: .utf8)?.count ?? 0
                    DetailSection(
                        title: "Response Body",
                        rawText: body,
                        onCopy: copyToClipboard,
                        onShare: {
                            shareResponseBodyAsFile(body: body, contentType: contentType)
                        },
                        content: {
                            BodyHeaderView(contentType: contentType, size: bodySize)
                            FormattedBodyView(
                                bodyText: body,
                                contentType: contentType,
                                searchText: responseSearchText,
                                currentMatchIndex: currentMatchIndex,
                                onMatchCountChanged: { count in
                                    totalMatches = count
                                }
                            )
                        }
                    )
                }
                .padding()
            } else {
                emptyState(
                    message: "Unable to capture response body",
                    subtitle: "Static resources (scripts, stylesheets) cannot be intercepted"
                )
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(message: String, subtitle: String? = nil) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "eye.slash")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 40)
    }

    private func copyToClipboard(_ text: String, label: String) {
        UIPasteboard.general.string = text
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

    private func formatHeadersForCopy(_ headers: [String: String]) -> String {
        headers
            .sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    private func generateCurlCommand() -> String {
        var parts = ["curl"]

        // Method
        if request.method != "GET" {
            parts.append("-X \(request.method)")
        }

        // Headers
        if let headers = request.requestHeaders {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                let escapedValue = value.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("-H '\(key): \(escapedValue)'")
            }
        }

        // Body
        if let body = request.requestBody, !body.isEmpty {
            let escapedBody = body.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escapedBody)'")
        }

        // URL
        parts.append("'\(request.url)'")

        return parts.joined(separator: " \\\n  ")
    }

    private func shareRequest() {
        var text = """
        \(request.method) \(request.url)
        Status: \(request.status.map { "\($0)" } ?? "Pending")
        Duration: \(request.durationText)
        Type: \(request.requestType.rawValue.capitalized)
        """

        if let headers = request.requestHeaders, !headers.isEmpty {
            text += "\n\n--- Request Headers ---\n"
            text += formatHeadersForCopy(headers)
        }

        if let body = request.requestBody, !body.isEmpty {
            text += "\n\n--- Request Body ---\n"
            text += body
        }

        if let headers = request.responseHeaders, !headers.isEmpty {
            text += "\n\n--- Response Headers ---\n"
            text += formatHeadersForCopy(headers)
        }

        if let body = request.responseBody, !body.isEmpty {
            text += "\n\n--- Response Body ---\n"
            text += body
        }

        shareItem = NetworkShareContent(content: text)
    }

    private func shareResponseBodyAsFile(body: String, contentType: ContentType) {
        // Determine file extension based on content type
        let fileExtension: String
        switch contentType {
        case .json:
            fileExtension = "json"
        case .html:
            fileExtension = "html"
        case .xml:
            fileExtension = "xml"
        case .formUrlEncoded, .text:
            fileExtension = "txt"
        }

        // Build filename: host_path_timestamp.ext
        let host = request.host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: ".", with: "_")
        let pathComponent = request.path.split(separator: "/").last.map(String.init) ?? "response"
        let sanitizedPath = pathComponent.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let timestamp = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HHmmss"
            return formatter.string(from: Date())
        }()
        let fileName = "\(host)_\(sanitizedPath)_\(timestamp).\(fileExtension)"

        // Write to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
            shareFileURL = fileURL
        } catch {
            // Fallback to text share if file creation fails
            shareItem = NetworkShareContent(content: body)
        }
    }

    private var methodColor: Color {
        switch request.method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        default: return .secondary
        }
    }

    private func detectContentType(body: String, headers: [String: String]?) -> ContentType {
        // Check Content-Type header first
        if let contentTypeHeader = headers?["Content-Type"] ?? headers?["content-type"] {
            if contentTypeHeader.contains("application/json") {
                return .json
            } else if contentTypeHeader.contains("text/html") {
                return .html
            } else if contentTypeHeader.contains("text/xml") || contentTypeHeader.contains("application/xml") {
                return .xml
            } else if contentTypeHeader.contains("text/plain") {
                return .text
            } else if contentTypeHeader.contains("application/x-www-form-urlencoded") {
                return .formUrlEncoded
            }
        }

        // Fallback: detect from body content
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            // Validate JSON
            if let data = body.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .json
            }
        }
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
            return .html
        }
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<") {
            return .xml
        }
        if trimmed.contains("=") && trimmed.contains("&") {
            return .formUrlEncoded
        }
        return .text
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Content Type

private enum ContentType: String {
    case json = "JSON"
    case html = "HTML"
    case xml = "XML"
    case text = "Text"
    case formUrlEncoded = "Form Data"

    var color: Color {
        switch self {
        case .json: return .purple
        case .html: return .orange
        case .xml: return .teal
        case .text: return .secondary
        case .formUrlEncoded: return .blue
        }
    }

    var icon: String {
        switch self {
        case .json: return "curlybraces"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .formUrlEncoded: return "list.bullet.rectangle"
        }
    }

    var badge: TypeBadge {
        TypeBadge(text: rawValue, color: color, icon: icon)
    }
}

// MARK: - Detail Section

private struct DetailSection<Content: View>: View {
    let title: String
    let rawText: String?
    var onCopy: ((String, String) -> Void)?
    var onShare: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @State private var showRaw: Bool = false

    init(
        title: String,
        rawText: String? = nil,
        onCopy: ((String, String) -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.rawText = rawText
        self.onCopy = onCopy
        self.onShare = onShare
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header with Raw toggle, Share, and Copy buttons
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let rawText, !rawText.isEmpty {
                    // Raw/Table toggle button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRaw.toggle()
                        }
                    } label: {
                        Text(showRaw ? "Table" : "Raw")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(in: .capsule)

                    // Share button (optional)
                    if let onShare {
                        GlassIconButton(icon: "square.and.arrow.up", size: .small) {
                            onShare()
                        }
                    }

                    // Copy button
                    GlassIconButton(icon: "doc.on.doc", size: .small) {
                        onCopy?(rawText, title)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                if showRaw, let rawText {
                    // Raw text view with UITextView for proper text selection
                    SelectableTextView(text: rawText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    content()
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Detail Table Row

private struct DetailTableRow: View {
    let key: String
    let value: String
    var onCopy: ((String, String) -> Void)?
    var showBorder: Bool = true
    @State private var isExpanded: Bool = false

    init(key: String, value: String, onCopy: ((String, String) -> Void)? = nil, showBorder: Bool = true) {
        self.key = key
        self.value = value
        self.onCopy = onCopy
        self.showBorder = showBorder
    }

    private var isLongValue: Bool {
        value.count > 60 || value.contains("\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.blue)
                    .frame(width: 100, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)

                if isLongValue && !isExpanded {
                    Text(value.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(value)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isLongValue {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isLongValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if showBorder {
                Divider()
                    .background(Color(uiColor: .separator))
            }
        }
        .contextMenu {
            Button {
                onCopy?(value, key)
            } label: {
                Label("Copy Value", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Copied Feedback Toast

private struct CopiedFeedbackToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.8), in: Capsule())
            .padding(.bottom, 20)
    }
}

// MARK: - Body Header View

private struct BodyHeaderView: View {
    let contentType: ContentType
    let size: Int

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            contentType.badge

            Text(formatBytes(size))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - Selectable Text View (UITextView Wrapper)

private struct SelectableTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var textColor = UIColor.label
    var padding = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    func makeUIView(context: Context) -> AutoSizingTextView {
        let textView = AutoSizingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = padding
        textView.font = font
        textView.textColor = textColor
        textView.dataDetectorTypes = []
        textView.alwaysBounceVertical = false
        textView.isScrollEnabled = false

        // Wrap text properly
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true

        return textView
    }

    func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
        uiView.text = text
        uiView.font = font
        uiView.textColor = textColor
        uiView.textContainerInset = padding
        uiView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: AutoSizingTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

// Custom UITextView that properly calculates intrinsic content size
private class AutoSizingTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let fixedWidth = bounds.width > 0 ? bounds.width : ScreenUtility.screenSize.width - 64
        let size = sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Searchable Text View

private struct SearchableTextView: UIViewRepresentable {
    let text: String
    let searchText: String
    let currentMatchIndex: Int
    var font: UIFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var textColor = UIColor.label
    var onMatchCountChanged: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> AutoSizingTextView {
        let textView = AutoSizingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.dataDetectorTypes = []
        textView.alwaysBounceVertical = false
        textView.isScrollEnabled = false

        // Prevent horizontal expansion
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor
            ]
        )

        // Apply search highlighting
        var matchRanges: [NSRange] = []
        if !searchText.isEmpty {
            let nsText = text as NSString
            var searchRange = NSRange(location: 0, length: nsText.length)

            while searchRange.location < nsText.length {
                let foundRange = nsText.range(
                    of: searchText,
                    options: .caseInsensitive,
                    range: searchRange
                )
                if foundRange.location != NSNotFound {
                    matchRanges.append(foundRange)
                    searchRange.location = foundRange.location + foundRange.length
                    searchRange.length = nsText.length - searchRange.location
                } else {
                    break
                }
            }

            // Highlight all matches
            for (index, range) in matchRanges.enumerated() {
                let isCurrentMatch = index == currentMatchIndex
                attributedText.addAttributes([
                    .backgroundColor: isCurrentMatch
                        ? UIColor.systemYellow
                        : UIColor.systemYellow.withAlphaComponent(0.3)
                ], range: range)
            }
        }

        uiView.attributedText = attributedText
        uiView.invalidateIntrinsicContentSize()

        // Report match count
        DispatchQueue.main.async {
            onMatchCountChanged?(matchRanges.count)
        }

        // Scroll to current match
        if !matchRanges.isEmpty && currentMatchIndex < matchRanges.count {
            let targetRange = matchRanges[currentMatchIndex]
            DispatchQueue.main.async {
                uiView.scrollRangeToVisible(targetRange)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: AutoSizingTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    class Coordinator {
        weak var textView: AutoSizingTextView?
    }
}

// MARK: - JSON Tree View (Chrome DevTools Style)

private enum JSONNode: Identifiable {
    case null(key: String?)
    case bool(key: String?, value: Bool)
    case number(key: String?, value: Double)
    case string(key: String?, value: String)
    case array(key: String?, values: [JSONNode])
    case object(key: String?, pairs: [(String, JSONNode)])

    var id: String {
        switch self {
        case .null(let key): return "null-\(key ?? "root")-\(UUID().uuidString)"
        case .bool(let key, _): return "bool-\(key ?? "root")-\(UUID().uuidString)"
        case .number(let key, _): return "number-\(key ?? "root")-\(UUID().uuidString)"
        case .string(let key, _): return "string-\(key ?? "root")-\(UUID().uuidString)"
        case .array(let key, _): return "array-\(key ?? "root")-\(UUID().uuidString)"
        case .object(let key, _): return "object-\(key ?? "root")-\(UUID().uuidString)"
        }
    }

    var key: String? {
        switch self {
        case .null(let key), .bool(let key, _), .number(let key, _),
             .string(let key, _), .array(let key, _), .object(let key, _):
            return key
        }
    }

    var isExpandable: Bool {
        switch self {
        case .array, .object: return true
        default: return false
        }
    }

    var childCount: Int {
        switch self {
        case .array(_, let values): return values.count
        case .object(_, let pairs): return pairs.count
        default: return 0
        }
    }

    static func parse(_ json: Any, key: String? = nil) -> JSONNode {
        switch json {
        case is NSNull:
            return .null(key: key)
        case let bool as Bool:
            return .bool(key: key, value: bool)
        case let number as NSNumber:
            return .number(key: key, value: number.doubleValue)
        case let string as String:
            return .string(key: key, value: string)
        case let array as [Any]:
            let nodes = array.enumerated().map { parse($1, key: "[\($0)]") }
            return .array(key: key, values: nodes)
        case let dict as [String: Any]:
            let pairs = dict.sorted { $0.key < $1.key }.map { ($0.key, parse($0.value, key: $0.key)) }
            return .object(key: key, pairs: pairs)
        default:
            return .string(key: key, value: String(describing: json))
        }
    }
}

private struct JSONTreeView: View {
    let jsonString: String

    var body: some View {
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) {
            let rootNode = JSONNode.parse(json)
            ScrollView(.horizontal, showsIndicators: false) {
                JSONNodeView(node: rootNode, depth: 0, isLast: true)
                    .padding(12)
            }
        } else {
            Text("Invalid JSON")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}

private struct JSONNodeView: View {
    let node: JSONNode
    let depth: Int
    let isLast: Bool
    @State private var isExpanded: Bool = false

    // Auto-expand first level
    init(node: JSONNode, depth: Int, isLast: Bool) {
        self.node = node
        self.depth = depth
        self.isLast = isLast
        self._isExpanded = State(initialValue: depth == 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current node row
            HStack(spacing: 0) {
                // Expand/collapse button for expandable nodes
                if node.isExpandable {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 20)
                }

                // Key (if exists) - Chrome DevTools style: plain text
                if let key = node.key {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(": ")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Value or preview
                valueView
            }
            .frame(minHeight: 20)

            // Children (if expanded)
            if isExpanded {
                childrenView
            }
        }
        .padding(.leading, CGFloat(depth) * 10)
    }

    // Chrome DevTools style: strings = red, primitives = blue, containers = gray
    private let primitiveColor = Color(red: 0.0, green: 0.45, blue: 0.73)  // Blue
    private let stringColor = Color(red: 0.77, green: 0.1, blue: 0.09)     // Red

    @ViewBuilder
    private var valueView: some View {
        switch node {
        case .null:
            Text("null")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primitiveColor)
        case .bool(_, let value):
            Text(value ? "true" : "false")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primitiveColor)
        case .number(_, let value):
            Text(formatNumber(value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primitiveColor)
        case .string(_, let value):
            Text("\"\(value)\"")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(stringColor)
                .lineLimit(isExpanded ? nil : 1)
        case .array(_, let values):
            Text("Array[\(values.count)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.5))
        case .object(_, let pairs):
            Text("Object{\(pairs.count)}")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.5))
        }
    }

    @ViewBuilder
    private var childrenView: some View {
        switch node {
        case .array(_, let values):
            ForEach(Array(values.enumerated()), id: \.offset) { index, childNode in
                JSONNodeView(
                    node: childNode,
                    depth: depth + 1,
                    isLast: index == values.count - 1
                )
            }
        case .object(_, let pairs):
            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                JSONNodeView(
                    node: pair.1,
                    depth: depth + 1,
                    isLast: index == pairs.count - 1
                )
            }
        default:
            EmptyView()
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(value)
    }
}

// MARK: - Response Search Bar

private struct ResponseSearchBar: View {
    @Binding var searchText: String
    let currentMatch: Int
    let totalMatches: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                TextField("Search in response...", text: $searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

            if !searchText.isEmpty && totalMatches > 0 {
                Text("\(currentMatch + 1)/\(totalMatches)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)

                HStack(spacing: 4) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(totalMatches == 0)

                    Button(action: onNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(totalMatches == 0)
                }
                .foregroundStyle(totalMatches > 0 ? .primary : .tertiary)
            } else if !searchText.isEmpty {
                Text("No matches")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - Formatted Body View

private struct FormattedBodyView: View {
    let bodyText: String
    let contentType: ContentType
    var searchText: String = ""
    var currentMatchIndex: Int = 0
    var onMatchCountChanged: ((Int) -> Void)?
    @State private var showTreeView: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // JSON: Show tree/raw toggle and appropriate view
            if contentType == .json && searchText.isEmpty {
                // Toggle between Tree and Raw view
                HStack {
                    Spacer()
                    Picker("View Mode", selection: $showTreeView) {
                        Text("Tree").tag(true)
                        Text("Raw").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                }

                if showTreeView {
                    JSONTreeView(jsonString: bodyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    SelectableTextView(text: formattedBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if !searchText.isEmpty {
                SearchableTextView(
                    text: formattedBody,
                    searchText: searchText,
                    currentMatchIndex: currentMatchIndex,
                    onMatchCountChanged: onMatchCountChanged
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SelectableTextView(text: formattedBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var formattedBody: String {
        switch contentType {
        case .json:
            return formatJSON(bodyText)
        case .html, .xml:
            return formatMarkup(bodyText)
        case .formUrlEncoded:
            return formatFormData(bodyText)
        case .text:
            return bodyText
        }
    }

    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                  withJSONObject: jsonObject,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }

    private func formatMarkup(_ markup: String) -> String {
        // Try to use SwiftSoup for HTML parsing
        do {
            let document = try SwiftSoup.parse(markup)
            // Use SwiftSoup's output settings for indentation
            document.outputSettings()
                .indentAmount(indentAmount: 2)
                .outline(outlineMode: false)
            let formatted = try document.html()
            return formatted
        } catch {
            // Fallback to manual formatting if SwiftSoup fails
            return formatMarkupManual(markup)
        }
    }

    private func formatMarkupManual(_ markup: String) -> String {
        var result = ""
        var indentLevel = 0
        let indentString = "  "

        // Normalize: add newlines around tags
        let normalized = markup
            .replacingOccurrences(of: ">", with: ">\n")
            .replacingOccurrences(of: "<", with: "\n<")

        let lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            // Check if it's a closing tag
            if line.hasPrefix("</") {
                indentLevel = max(0, indentLevel - 1)
                result += String(repeating: indentString, count: indentLevel) + line + "\n"
            }
            // Self-closing tag or DOCTYPE/comment
            else if line.hasSuffix("/>") ||
                        line.hasPrefix("<!") ||
                        line.hasPrefix("<?") {
                result += String(repeating: indentString, count: indentLevel) + line + "\n"
            }
            // Opening tag
            else if line.hasPrefix("<") && !line.hasPrefix("</") {
                result += String(repeating: indentString, count: indentLevel) + line + "\n"
                // Don't indent for void elements
                let voidElements = [
                    "area", "base", "br", "col", "embed", "hr", "img",
                    "input", "link", "meta", "param", "source", "track", "wbr"
                ]
                let tagName = extractTagName(from: line)
                if !voidElements.contains(tagName.lowercased()) {
                    indentLevel += 1
                }
            }
            // Text content
            else {
                result += String(repeating: indentString, count: indentLevel) + line + "\n"
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTagName(from tag: String) -> String {
        var name = tag
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "/", with: "")

        // Get just the tag name (before any attributes)
        if let spaceIndex = name.firstIndex(of: " ") {
            name = String(name[..<spaceIndex])
        }
        return name
    }

    private func formatFormData(_ formString: String) -> String {
        formString
            .components(separatedBy: "&")
            .map { pair -> String in
                let parts = pair.components(separatedBy: "=")
                let key = parts.first?.removingPercentEncoding ?? parts.first ?? ""
                let value = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
                return "\(key) = \(value)"
            }
            .joined(separator: "\n")
    }
}

#Preview {
    let manager = NetworkManager()
    manager.addRequest(
        id: UUID().uuidString,
        method: "GET",
        url: "https://api.example.com/users",
        requestType: "fetch",
        headers: ["Authorization": "Bearer token123"],
        body: nil
    )

    return NetworkView(networkManager: manager)
        .presentationDetents([.fraction(0.35), .medium, .large])
}
