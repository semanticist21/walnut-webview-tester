//
//  WebViewNavigator.swift
//  wina
//
//  WebView navigation controller with KVO observation.
//

import WebKit

// MARK: - WebView Navigator

@Observable
class WebViewNavigator {
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: URL?
    var showScreenshotFlash: Bool = false
    var showScreenshotSavedToast: Bool = false
    let consoleManager = ConsoleManager()
    let networkManager = NetworkManager()
    let performanceManager = PerformanceManager()

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
    func evaluateJavaScript(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return try? await webView.evaluateJavaScript(script)
    }

    /// Evaluate async JavaScript (supports Promises)
    func callAsyncJavaScript(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return try? await webView.callAsyncJavaScript(
            script,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
    }

    /// Take a screenshot of the WebView and save to Photos
    func takeScreenshot() async -> Bool {
        guard let webView else { return false }

        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                guard let image else {
                    continuation.resume(returning: false)
                    return
                }
                // Convert to opaque image (removes unnecessary alpha channel)
                let format = UIGraphicsImageRendererFormat()
                format.opaque = true
                let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
                let opaqueImage = renderer.image { _ in
                    image.draw(at: .zero)
                }
                UIImageWriteToSavedPhotosAlbum(opaqueImage, nil, nil, nil)
                continuation.resume(returning: true)
            }
        }
    }

    /// Delete a specific cookie by name using native WKHTTPCookieStore
    func deleteCookie(name: String) async {
        guard let webView else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await cookieStore.allCookies()
        for cookie in cookies where cookie.name == name {
            await cookieStore.deleteCookie(cookie)
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
}
