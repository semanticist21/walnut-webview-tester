//
//  NetworkManager.swift
//  wina
//
//  Network manager and body storage for request monitoring.
//

import Foundation

// MARK: - Log Clear Strategy

/// Strategy for clearing logs during navigation
enum LogClearStrategy: String, CaseIterable {
    case origin  // Clear when navigating to different origin (domain)
    case page    // Clear on every page navigation
    case keep    // Never auto-clear, manual only

    var displayName: String {
        switch self {
        case .origin: return "Same Origin"
        case .page: return "Each Page"
        case .keep: return "Keep All"
        }
    }

    var description: String {
        switch self {
        case .origin: return "Clear when leaving current domain"
        case .page: return "Clear on every navigation"
        case .keep: return "Keep until manually cleared"
        }
    }
}

// MARK: - Network Body Storage (Disk-based)

final class NetworkBodyStorage {
    static let shared = NetworkBodyStorage()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.wina.networkbodystorage", qos: .utility)

    private lazy var cacheDirectory: URL = {
        // Use caches directory, fallback to temp directory if unavailable
        let baseDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = baseDir.appendingPathComponent("NetworkBodies", isDirectory: true)
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

// MARK: - Network Manager

@Observable
class NetworkManager {
    var requests: [NetworkRequest] = []
    var isCapturing: Bool = true
    var pageURL: URL?  // Current page URL for mixed content detection

    // Limits for memory management (only affects request count, not body size)
    private let maxRequestCount = 500
    private let bodyStorage = NetworkBodyStorage.shared

    // Read preserveLog from UserDefaults
    var preserveLog: Bool {
        UserDefaults.standard.bool(forKey: "networkPreserveLog")
    }

    /// Whether the current page is using HTTPS
    var pageIsSecure: Bool {
        pageURL?.scheme?.lowercased() == "https"
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
            pageIsSecure: pageIsSecure,
            requestType: type
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
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

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
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
    var mixedContentCount: Int { requests.filter(\.isMixedContent).count }
}
