//
//  WebViewNavigator.swift
//  wina
//
//  WebView navigation controller with KVO observation.
//

import Photos
import WebKit

// MARK: - Screenshot Types

enum ScreenshotResult {
    case success
    case permissionDenied
    case failed
}

enum PhotoPermissionStatus {
    case authorized
    case denied
    case notDetermined
}

// MARK: - WebView Navigator

@Observable
class WebViewNavigator {
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: URL?
    /// 최초 입력된 URL (네비게이션 시작점)
    private(set) var initialURL: URL?
    var showScreenshotFlash: Bool = false
    var showScreenshotSavedToast: Bool = false
    let consoleManager = ConsoleManager()
    let networkManager = NetworkManager()
    let performanceManager = PerformanceManager()
    let resourceManager = ResourceManager()
    let accessibilityManager = AccessibilityManager()
    let snippetsManager = SnippetsManager()

    private weak var webView: WKWebView?
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    var isAttached: Bool {
        webView != nil
    }

    func attach(to webView: WKWebView) {
        self.webView = webView

        // Initial state
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url

        // Observe changes (use .initial to get immediate value, .new for updates)
        canGoBackObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.canGoBack = webView.canGoBack
            }
        }
        canGoForwardObservation = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.canGoForward = webView.canGoForward
            }
        }
        urlObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.currentURL = webView.url
                self?.networkManager.pageURL = webView.url
            }
        }
    }

    func detach() {
        canGoBackObservation?.invalidate()
        canGoForwardObservation?.invalidate()
        urlObservation?.invalidate()
        canGoBackObservation = nil
        canGoForwardObservation = nil
        urlObservation = nil
        webView = nil
        canGoBack = false
        canGoForward = false
        currentURL = nil
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    /// 최초 URL로 돌아갈 수 있는지 여부
    var canGoToInitialURL: Bool {
        guard let initialURL else { return false }
        return currentURL != initialURL
    }

    /// 최초 URL 설정 (웹뷰 최초 로드 시 호출)
    func setInitialURL(_ url: URL) {
        initialURL = url
    }

    /// 최초 URL 초기화 (홈으로 돌아갈 때)
    func clearInitialURL() {
        initialURL = nil
    }

    /// 최초 입력된 URL로 이동
    func goToInitialURL() {
        guard let initialURL else { return }
        webView?.load(URLRequest(url: initialURL))
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    /// Load a new URL in the same WebView instance
    func loadURL(_ urlString: String) {
        guard let webView else { return }

        // Normalize URL (add https:// if no scheme)
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.contains("://") {
            normalized = "https://\(normalized)"
        }

        guard let url = URL(string: normalized) else { return }
        webView.load(URLRequest(url: url))
    }

    /// Evaluate JavaScript on the attached WebView
    @MainActor
    func evaluateJavaScript(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return try? await webView.evaluateJavaScript(script)
    }

    /// Evaluate async JavaScript (supports Promises)
    @MainActor
    func callAsyncJavaScript(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return try? await webView.callAsyncJavaScript(
            script,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
    }

    /// Check photo library permission without requesting
    func checkPhotoLibraryPermission() -> PhotoPermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized, .limited:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .authorized
        }
    }

    /// Request photo library permission
    func requestPhotoLibraryPermission() async -> Bool {
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return newStatus == .authorized || newStatus == .limited
    }

    /// Take a screenshot of the WebView and save to Photos
    /// Assumes permission is already granted (call checkPhotoLibraryPermission first)
    @MainActor
    func takeScreenshot() async -> ScreenshotResult {
        guard let webView else { return .failed }

        // Double-check permission (in case called directly)
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return .permissionDenied
        }

        // Take snapshot
        guard let image = await captureSnapshot(from: webView) else {
            return .failed
        }

        // Convert to opaque image (removes unnecessary alpha channel)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let opaqueImage = renderer.image { _ in
            image.draw(at: .zero)
        }

        // Save to Photos
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: opaqueImage)
            }
            return .success
        } catch {
            return .failed
        }
    }

    @MainActor
    private func captureSnapshot(from webView: WKWebView) async -> UIImage? {
        await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Set a cookie using native WKHTTPCookieStore
    func setCookie(_ cookie: HTTPCookie) async {
        guard let webView else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        await cookieStore.setCookie(cookie)
    }

    /// Delete a specific cookie by name/domain/path using native WKHTTPCookieStore
    func deleteCookie(name: String, domain: String?, path: String?) async {
        guard let webView else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()
        for cookie in cookies where cookie.name == name {
            // Narrow by domain/path when provided to avoid over-deleting.
            if let domain, cookie.domain.caseInsensitiveCompare(domain) != .orderedSame {
                continue
            }
            if let path, cookie.path != path {
                continue
            }
            await cookieStore.deleteCookie(cookie)
        }
    }

    /// Delete cookies for a specific domain using native WKHTTPCookieStore
    func deleteCookies(forDomain domain: String) async {
        guard let webView else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()
        let host = domain.lowercased()

        for cookie in cookies {
            let cookieDomain = cookie.domain.lowercased()
            let matches: Bool

            if cookieDomain.hasPrefix(".") {
                let trimmed = String(cookieDomain.dropFirst())
                matches = host == trimmed || host.hasSuffix(".\(trimmed)")
            } else {
                matches = host == cookieDomain
            }

            if matches {
                await cookieStore.deleteCookie(cookie)
            }
        }
    }

    /// Delete all cookies using native WKHTTPCookieStore
    func deleteAllCookies() async {
        guard let webView else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()
        for cookie in cookies {
            await cookieStore.deleteCookie(cookie)
        }
    }

    /// Get all cookies with full metadata using native WKHTTPCookieStore
    func getAllCookies() async -> [HTTPCookie] {
        guard let webView else { return [] }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        return await cookieStore.allCookies()
    }

    // MARK: - Eruda Console

    /// Inject Eruda console into the current page
    /// Eruda is loaded from bundled JS file to bypass CSP restrictions
    func injectEruda() async {
        guard webView != nil else { return }

        // Check if Eruda is already loaded
        let checkEruda = "typeof eruda !== 'undefined'"
        let erudaLoaded = await evaluateJavaScript(checkEruda) as? Bool ?? false

        if erudaLoaded {
            // Already loaded, nothing to do (user can tap Eruda button to open)
            return
        }

        // Load Eruda from bundle
        guard let erudaURL = Bundle.main.url(forResource: "eruda.min", withExtension: "js"),
              let erudaScript = try? String(contentsOf: erudaURL, encoding: .utf8) else {
            // eruda.min.js not found in bundle
            return
        }

        // Inject and initialize Eruda (starts hidden, user taps button to open)
        _ = await evaluateJavaScript(erudaScript)
        _ = await evaluateJavaScript("eruda.init();")
    }

    /// Hide Eruda console if loaded
    func hideEruda() async {
        _ = await evaluateJavaScript("if (typeof eruda !== 'undefined') eruda.hide();")
    }

    /// Destroy Eruda console completely
    func destroyEruda() async {
        _ = await evaluateJavaScript("if (typeof eruda !== 'undefined') eruda.destroy();")
    }
}
