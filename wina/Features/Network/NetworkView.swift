//
//  NetworkView.swift
//  wina
//
//  Network request monitoring view for WKWebView.
//  Captures fetch/XMLHttpRequest via JavaScript injection.
//

import SwiftSoup
import SwiftUI

// MARK: - Network Request Model

struct NetworkRequest: Identifiable, Equatable {
    let id: UUID
    let method: String
    let url: String
    let requestHeaders: [String: String]?
    let requestBody: String?
    let startTime: Date
    var status: Int?
    var statusText: String?
    var responseHeaders: [String: String]?
    var responseBody: String?
    var endTime: Date?
    var error: String?
    var requestType: RequestType

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

        // Fallback: detect from body content
        guard let body = responseBody else { return "—" }
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
        lhs.id == rhs.id
    }
}

// MARK: - Network Manager

@Observable
class NetworkManager {
    var requests: [NetworkRequest] = []
    var isCapturing: Bool = true

    // Limits for memory management
    private let maxRequestCount = 500
    private let maxBodySize = 100 * 1024  // 100KB

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
        let truncatedBody = truncateBody(body)
        let request = NetworkRequest(
            id: UUID(uuidString: id) ?? UUID(),
            method: method.uppercased(),
            url: url,
            requestHeaders: headers,
            requestBody: truncatedBody,
            startTime: Date(),
            requestType: type
        )

        DispatchQueue.main.async {
            // Enforce max request count to prevent memory bloat
            if self.requests.count >= self.maxRequestCount {
                self.requests.removeFirst()
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

        let truncatedBody = truncateBody(responseBody)

        DispatchQueue.main.async {
            if let index = self.requests.firstIndex(where: { $0.id == uuid }) {
                self.requests[index].status = status
                self.requests[index].statusText = statusText
                self.requests[index].responseHeaders = responseHeaders
                self.requests[index].responseBody = truncatedBody
                self.requests[index].error = error
                self.requests[index].endTime = Date()
            }
        }
    }

    private func truncateBody(_ body: String?) -> String? {
        guard let body, body.count > maxBodySize else { return body }
        let truncated = String(body.prefix(maxBodySize))
        return truncated + "\n\n... [truncated, \(body.count - maxBodySize) more bytes]"
    }

    func clear() {
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

// MARK: - Network Settings Sheet

private struct NetworkSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("networkPreserveLog") private var preserveLog: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Logging") {
                    Toggle("Preserve Log on Navigation", isOn: $preserveLog)
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
        }
    }

    // MARK: - Summary

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

            Text(request.url)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

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
                DetailTableRow(key: "Type", value: request.requestType.rawValue.capitalized, onCopy: copyToClipboard)
            }

            // Response headers
            if let headers = request.responseHeaders, !headers.isEmpty {
                DetailSection(
                    title: "Response Headers",
                    rawText: formatHeadersForCopy(headers),
                    onCopy: copyToClipboard
                ) {
                    ForEach(headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }), id: \.key) { key, value in
                        DetailTableRow(key: key, value: value, onCopy: copyToClipboard)
                    }
                }
            }

            // Request headers
            if let headers = request.requestHeaders, !headers.isEmpty {
                DetailSection(
                    title: "Request Headers",
                    rawText: formatHeadersForCopy(headers),
                    onCopy: copyToClipboard
                ) {
                    ForEach(headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }), id: \.key) { key, value in
                        DetailTableRow(key: key, value: value, onCopy: copyToClipboard)
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
                        onCopy: copyToClipboard
                    )
                }

                // Query parameters
                if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                    DetailSection(
                        title: "Query Parameters",
                        rawText: queryParametersRawText(queryItems),
                        onCopy: copyToClipboard
                    ) {
                        ForEach(queryItems, id: \.name) { item in
                            DetailTableRow(key: item.name, value: item.value ?? "(empty)", onCopy: copyToClipboard)
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
        VStack(alignment: .leading, spacing: 20) {
            if let body = request.responseBody, !body.isEmpty {
                let contentType = detectContentType(body: body, headers: request.responseHeaders)
                let bodySize = body.data(using: .utf8)?.count ?? 0
                DetailSection(title: "Response Body", rawText: body, onCopy: copyToClipboard) {
                    BodyHeaderView(contentType: contentType, size: bodySize)
                    FormattedBodyView(bodyText: body, contentType: contentType)
                }
            } else {
                emptyState(message: "No response body")
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
}

// MARK: - Detail Section

private struct DetailSection<Content: View>: View {
    let title: String
    let rawText: String?
    var onCopy: ((String, String) -> Void)?
    @ViewBuilder let content: () -> Content
    @State private var showRaw: Bool = false

    init(
        title: String,
        rawText: String? = nil,
        onCopy: ((String, String) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.rawText = rawText
        self.onCopy = onCopy
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header with Raw toggle and Copy button
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

                    // Copy button
                    GlassIconButton(icon: "doc.on.doc", size: .small) {
                        onCopy?(rawText, title)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                if showRaw, let rawText {
                    // Raw text view
                    Text(rawText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
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
            HStack(alignment: .top, spacing: 12) {
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

// MARK: - Content Type Badge

private struct ContentTypeBadge: View {
    let contentType: ContentType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: contentType.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(contentType.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(contentType.color, in: Capsule())
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
            ContentTypeBadge(contentType: contentType)

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

// MARK: - Formatted Body View

private struct FormattedBodyView: View {
    let bodyText: String
    let contentType: ContentType

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(formattedBody)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
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
