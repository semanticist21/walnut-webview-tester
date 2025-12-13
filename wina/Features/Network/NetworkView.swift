//
//  NetworkView.swift
//  wina
//
//  Network request monitoring view for WKWebView.
//  Captures fetch/XMLHttpRequest via JavaScript injection.
//

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

    static func == (lhs: NetworkRequest, rhs: NetworkRequest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Network Manager

@Observable
class NetworkManager {
    var requests: [NetworkRequest] = []
    var isCapturing: Bool = true

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
        let request = NetworkRequest(
            id: UUID(uuidString: id) ?? UUID(),
            method: method.uppercased(),
            url: url,
            requestHeaders: headers,
            requestBody: body,
            startTime: Date(),
            requestType: type
        )

        DispatchQueue.main.async {
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

        DispatchQueue.main.async {
            if let index = self.requests.firstIndex(where: { $0.id == uuid }) {
                self.requests[index].status = status
                self.requests[index].statusText = statusText
                self.requests[index].responseHeaders = responseHeaders
                self.requests[index].responseBody = responseBody
                self.requests[index].error = error
                self.requests[index].endTime = Date()
            }
        }
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
    @State private var filterType: NetworkRequest.RequestType?
    @State private var searchText: String = ""
    @State private var shareItem: NetworkShareContent?
    @State private var showSettings: Bool = false
    @State private var selectedRequest: NetworkRequest?
    @AppStorage("networkPreserveLog") private var preserveLog: Bool = false

    private var filteredRequests: [NetworkRequest] {
        var result = networkManager.requests

        if let filterType {
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
        HStack(spacing: 16) {
            // Left button group: trash + export
            HStack(spacing: 4) {
                Button {
                    networkManager.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(networkManager.requests.isEmpty ? .tertiary : .primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .disabled(networkManager.requests.isEmpty)

                Button {
                    shareItem = NetworkShareContent(content: exportAsText())
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(networkManager.requests.isEmpty ? .tertiary : .primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .disabled(networkManager.requests.isEmpty)
            }
            .padding(.horizontal, 6)
            .glassEffect(in: .capsule)

            Spacer()

            Text("Network")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Right button group: pause/play + settings
            HStack(spacing: 4) {
                Button {
                    networkManager.isCapturing.toggle()
                } label: {
                    Image(systemName: networkManager.isCapturing ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(networkManager.isCapturing ? .red : .green)
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
                    isSelected: filterType == nil
                ) {
                    filterType = nil
                }

                ForEach(NetworkRequest.RequestType.allCases, id: \.self) { type in
                    NetworkFilterTab(
                        label: type.label,
                        count: networkManager.requests.filter { $0.requestType == type }.count,
                        isSelected: filterType == type
                    ) {
                        filterType = type
                    }
                }

                NetworkFilterTab(
                    label: "Errors",
                    count: networkManager.errorCount,
                    isSelected: false,
                    color: .red
                ) {
                    // Filter by error status
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

        return networkManager.requests
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

            // Type badge
            Image(systemName: request.requestType.icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 20)
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

    enum DetailTab: String, CaseIterable {
        case headers = "Headers"
        case request = "Request"
        case response = "Response"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary
                requestSummary

                Divider()

                // Tab picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab content
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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

    @ViewBuilder
    private var headersContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let headers = request.requestHeaders, !headers.isEmpty {
                headerSection(title: "Request Headers", headers: headers)
            }

            if let headers = request.responseHeaders, !headers.isEmpty {
                headerSection(title: "Response Headers", headers: headers)
            }

            if request.requestHeaders == nil && request.responseHeaders == nil {
                Text("No headers available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
        }
        .padding()
    }

    private func headerSection(title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top) {
                    Text(key)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.blue)
                    Text(value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private var requestContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let body = request.requestBody, !body.isEmpty {
                Text(body)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding()
            } else {
                Text("No request body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
        }
    }

    @ViewBuilder
    private var responseContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let body = request.responseBody, !body.isEmpty {
                Text(body)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding()
            } else {
                Text("No response body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
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
