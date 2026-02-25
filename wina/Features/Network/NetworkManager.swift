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

    // 각 DevTools 별로 clear 전략을 독립 저장하기 위한 UserDefaults 키
    static let consoleDefaultsKey = "consoleLogClearStrategy"
    static let networkDefaultsKey = "networkLogClearStrategy"
    // 과거 단일 전략 키(1회 마이그레이션 전용)
    static let legacyDefaultsKey = "logClearStrategy"
    // 1회 마이그레이션 완료 플래그
    static let migrationFlagKey = "didMigrateLogClearStrategyKeys"

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

// MARK: - Log Clear Strategy Resolver

struct LogClearStrategyResolver {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // 마이그레이션을 먼저 보장한 뒤 콘솔/네트워크 전략을 각각 해석합니다.
    func resolveStrategies() -> (console: LogClearStrategy, network: LogClearStrategy) {
        migrateLegacyStrategyIfNeeded()
        return (
            resolvedStrategy(forKey: LogClearStrategy.consoleDefaultsKey),
            resolvedStrategy(forKey: LogClearStrategy.networkDefaultsKey)
        )
    }

    // 저장된 rawValue가 유효하지 않으면 안전하게 keep으로 폴백합니다.
    func resolvedStrategy(forKey key: String) -> LogClearStrategy {
        if let strategyRaw = defaults.string(forKey: key),
           let strategy = LogClearStrategy(rawValue: strategyRaw) {
            return strategy
        }
        return .keep
    }

    // 레거시 단일 키를 분리 키로 1회만 옮기고 재주입을 막습니다.
    func migrateLegacyStrategyIfNeeded() {
        guard !defaults.bool(forKey: LogClearStrategy.migrationFlagKey) else { return }

        let hasConsole = defaults.string(forKey: LogClearStrategy.consoleDefaultsKey) != nil
        let hasNetwork = defaults.string(forKey: LogClearStrategy.networkDefaultsKey) != nil

        if let legacyRaw = defaults.string(forKey: LogClearStrategy.legacyDefaultsKey),
           let legacyStrategy = LogClearStrategy(rawValue: legacyRaw) {
            if !hasConsole {
                defaults.set(legacyStrategy.rawValue, forKey: LogClearStrategy.consoleDefaultsKey)
            }
            if !hasNetwork {
                defaults.set(legacyStrategy.rawValue, forKey: LogClearStrategy.networkDefaultsKey)
            }
        }

        defaults.removeObject(forKey: LogClearStrategy.legacyDefaultsKey)
        defaults.set(true, forKey: LogClearStrategy.migrationFlagKey)
    }

    // URL 전환 시 clear 여부를 정책별로 일관되게 계산합니다.
    static func shouldClear(
        strategy: LogClearStrategy,
        currentURL: URL?,
        newURL: URL?
    ) -> Bool {
        switch strategy {
        case .keep:
            return false
        case .page:
            return true
        case .origin:
            guard let currentOrigin = normalizedOrigin(from: currentURL),
                  let nextOrigin = normalizedOrigin(from: newURL) else { return false }
            return currentOrigin != nextOrigin
        }
    }

    // 스킴/호스트/정규화된 포트로 Same Origin 비교 기준 문자열을 생성합니다.
    static func normalizedOrigin(from url: URL?) -> String? {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else { return nil }

        let normalizedPort: Int? = if let explicitPort = url.port {
            explicitPort
        } else {
            switch scheme {
            case "http":
                80
            case "https":
                443
            default:
                nil
            }
        }

        if let normalizedPort {
            return "\(scheme)://\(host):\(normalizedPort)"
        }

        return "\(scheme)://\(host)"
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
