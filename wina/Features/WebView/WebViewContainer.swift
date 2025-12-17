//
//  WebViewContainer.swift
//  wina
//
//  WebView container with WKWebView and SafariViewController support.
//

import SwiftUI
import WebKit
import SafariServices

// MARK: - WebView Container

struct WebViewContainer: View {
    let urlString: String
    let useSafari: Bool
    @Binding var webViewID: UUID
    let navigator: WebViewNavigator?

    // Loading State
    @State private var isLoading: Bool = true

    // Core Settings
    @AppStorage("enableJavaScript") private var enableJavaScript: Bool = true
    @AppStorage("allowsContentJavaScript") private var allowsContentJavaScript: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = true
    @AppStorage("minimumFontSize") private var minimumFontSize: Double = 0

    // Media Settings
    @AppStorage("mediaAutoplay") private var mediaAutoplay: Bool = false
    @AppStorage("inlineMediaPlayback") private var inlineMediaPlayback: Bool = true
    @AppStorage("allowsAirPlay") private var allowsAirPlay: Bool = true
    @AppStorage("allowsPictureInPicture") private var allowsPictureInPicture: Bool = true

    // Navigation & Gestures
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = true
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true

    // Content Settings
    @AppStorage("suppressesIncrementalRendering") private var suppressesIncrementalRendering: Bool = false
    @AppStorage("javaScriptCanOpenWindows") private var javaScriptCanOpenWindows: Bool = false
    @AppStorage("fraudulentWebsiteWarning") private var fraudulentWebsiteWarning: Bool = true
    @AppStorage("textInteractionEnabled") private var textInteractionEnabled: Bool = true
    @AppStorage("elementFullscreenEnabled") private var elementFullscreenEnabled: Bool = false

    // Data Detectors
    @AppStorage("detectPhoneNumbers") private var detectPhoneNumbers: Bool = false
    @AppStorage("detectLinks") private var detectLinks: Bool = false
    @AppStorage("detectAddresses") private var detectAddresses: Bool = false
    @AppStorage("detectCalendarEvents") private var detectCalendarEvents: Bool = false

    // Privacy & Security
    @AppStorage("privateBrowsing") private var privateBrowsing: Bool = false
    @AppStorage("upgradeToHTTPS") private var upgradeToHTTPS: Bool = true

    // Content Mode
    @AppStorage("preferredContentMode") private var preferredContentMode: Int = 0

    // User Agent
    @AppStorage("customUserAgent") private var customUserAgent: String = ""

    // WKWebView Size
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82

    // SafariVC Size (separate settings)
    @AppStorage("safariWidthRatio") private var safariWidthRatio: Double = 1.0
    @AppStorage("safariHeightRatio") private var safariHeightRatio: Double = 0.82

    private var currentWidthRatio: Double {
        useSafari ? safariWidthRatio : webViewWidthRatio
    }

    private var currentHeightRatio: Double {
        useSafari ? safariHeightRatio : webViewHeightRatio
    }

    private var isFullSize: Bool {
        currentWidthRatio >= 0.99 && currentHeightRatio >= 0.99
    }

    var body: some View {
        GeometryReader { geometry in
            let webViewWidth = geometry.size.width * currentWidthRatio
            let webViewHeight = geometry.size.height * currentHeightRatio

            ZStack {
                // Background (only shown when size is less than 100%)
                if !isFullSize {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()

                    // Checkerboard pattern (to indicate transparent area)
                    CheckerboardPattern()
                        .ignoresSafeArea()
                }

                // WebView
                if useSafari {
                    SafariWebView(urlString: normalizedURL)
                        .id(webViewID)
                        .frame(width: webViewWidth, height: webViewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: isFullSize ? 0 : 12))
                        .shadow(color: .black.opacity(isFullSize ? 0 : 0.15), radius: 8, y: 2)
                } else {
                    WKWebViewRepresentable(
                        urlString: normalizedURL,
                        configuration: webViewConfiguration,
                        isLoading: $isLoading,
                        navigator: navigator
                    )
                    .id(webViewID)
                    .frame(width: webViewWidth, height: webViewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: isFullSize ? 0 : 12))
                    .shadow(color: .black.opacity(isFullSize ? 0 : 0.15), radius: 8, y: 2)
                    .overlay(alignment: .top) {
                        // Subtle top loading bar
                        if isLoading {
                            LoadingProgressBar()
                        }
                    }
                    .overlay {
                        // Screenshot flash effect
                        if navigator?.showScreenshotFlash == true {
                            Color.white
                                .opacity(0.7)
                                .clipShape(RoundedRectangle(cornerRadius: isFullSize ? 0 : 12))
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        // Screenshot saved toast
                        if navigator?.showScreenshotSavedToast == true {
                            CopiedFeedbackToast(message: "Saved to Photos")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: webViewWidthRatio) { _, _ in
                if !useSafari { webViewID = UUID() }
            }
            .onChange(of: webViewHeightRatio) { _, _ in
                if !useSafari { webViewID = UUID() }
            }
            .onChange(of: safariWidthRatio) { _, _ in
                if useSafari { webViewID = UUID() }
            }
            .onChange(of: safariHeightRatio) { _, _ in
                if useSafari { webViewID = UUID() }
            }
        }
    }

    private var normalizedURL: String {
        var url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
            url = "https://" + url
        }
        return url
    }

    private var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()

        // Core
        prefs.allowsContentJavaScript = enableJavaScript && allowsContentJavaScript
        config.defaultWebpagePreferences = prefs
        config.preferences.javaScriptCanOpenWindowsAutomatically = javaScriptCanOpenWindows
        config.preferences.isFraudulentWebsiteWarningEnabled = fraudulentWebsiteWarning
        config.preferences.minimumFontSize = CGFloat(minimumFontSize)

        // Media
        if mediaAutoplay {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else {
            config.mediaTypesRequiringUserActionForPlayback = .all
        }
        config.allowsInlineMediaPlayback = inlineMediaPlayback
        config.allowsAirPlayForMediaPlayback = allowsAirPlay
        config.allowsPictureInPictureMediaPlayback = allowsPictureInPicture

        // Content Mode
        switch preferredContentMode {
        case 1:
            prefs.preferredContentMode = .mobile
        case 2:
            prefs.preferredContentMode = .desktop
        default:
            prefs.preferredContentMode = .recommended
        }

        // Data Detectors
        var dataDetectorTypes: WKDataDetectorTypes = []
        if detectPhoneNumbers { dataDetectorTypes.insert(.phoneNumber) }
        if detectLinks { dataDetectorTypes.insert(.link) }
        if detectAddresses { dataDetectorTypes.insert(.address) }
        if detectCalendarEvents { dataDetectorTypes.insert(.calendarEvent) }
        config.dataDetectorTypes = dataDetectorTypes

        // Privacy
        if privateBrowsing {
            config.websiteDataStore = .nonPersistent()
        }
        config.upgradeKnownHostsToHTTPS = upgradeToHTTPS

        // Suppresses Incremental Rendering
        config.suppressesIncrementalRendering = suppressesIncrementalRendering

        return config
    }
}

// MARK: - WKWebView Representable

struct WKWebViewRepresentable: UIViewRepresentable {
    let urlString: String
    let configuration: WKWebViewConfiguration
    @Binding var isLoading: Bool
    let navigator: WebViewNavigator?

    // Navigation & Gestures
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = true
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = true
    @AppStorage("textInteractionEnabled") private var textInteractionEnabled: Bool = true

    // Display
    @AppStorage("pageZoom") private var pageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var underPageBackgroundColorHex: String = ""

    // Features
    @AppStorage("findInteractionEnabled") private var findInteractionEnabled: Bool = false

    // User Agent
    @AppStorage("customUserAgent") private var customUserAgent: String = ""

    // Emulation
    @AppStorage("emulationColorScheme") private var emulationColorScheme: String = "system"
    @AppStorage("emulationReducedMotion") private var emulationReducedMotion: Bool = false
    @AppStorage("emulationHighContrast") private var emulationHighContrast: Bool = false
    @AppStorage("emulationReducedTransparency") private var emulationReducedTransparency: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, navigator: navigator)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Add console and network hook scripts and message handlers to configuration
        let userContentController = configuration.userContentController

        // Console hook
        userContentController.add(context.coordinator, name: "consoleLog")
        let consoleScript = WKUserScript(
            source: WebViewScripts.consoleHook,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(consoleScript)

        // Network hook
        userContentController.add(context.coordinator, name: "networkRequest")
        let networkScript = WKUserScript(
            source: WebViewScripts.networkHook,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(networkScript)

        // Resource timing hook
        userContentController.add(context.coordinator, name: "resourceTiming")
        let resourceScript = WKUserScript(
            source: WebViewScripts.resourceTimingHook,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(resourceScript)

        // Performance observer hook (for LCP, CLS)
        let performanceScript = WKUserScript(
            source: WebViewScripts.performanceObserver,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(performanceScript)

        // Emulation: config script first, then bootstrap (order matters)
        let emulationConfigScript = WKUserScript(
            source: WebViewScripts.emulationConfigScript(
                colorScheme: emulationColorScheme,
                reducedMotion: emulationReducedMotion,
                highContrast: emulationHighContrast,
                reducedTransparency: emulationReducedTransparency
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(emulationConfigScript)

        let emulationBootstrapScript = WKUserScript(
            source: WebViewScripts.emulationBootstrap,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(emulationBootstrapScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = allowsBackForwardGestures
        webView.allowsLinkPreview = allowsLinkPreview

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        webView.configuration.ignoresViewportScaleLimits = allowZoom

        // Page zoom
        webView.pageZoom = pageZoom

        // Under page background color
        if let color = UIColor(hex: underPageBackgroundColorHex) {
            webView.underPageBackgroundColor = color
        }

        // Find interaction
        webView.isFindInteractionEnabled = findInteractionEnabled

        if !customUserAgent.isEmpty {
            webView.customUserAgent = customUserAgent
        }

        // Set up KVO for loading progress
        context.coordinator.observeWebView(webView)

        // Attach navigator for external control
        context.coordinator.navigator?.attach(to: webView)

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Dynamic properties - can be updated without recreating WebView
        webView.allowsBackForwardNavigationGestures = allowsBackForwardGestures
        webView.allowsLinkPreview = allowsLinkPreview
        webView.configuration.ignoresViewportScaleLimits = allowZoom

        // Page zoom
        webView.pageZoom = pageZoom

        // Under page background color
        if let color = UIColor(hex: underPageBackgroundColorHex) {
            webView.underPageBackgroundColor = color
        } else {
            webView.underPageBackgroundColor = nil
        }

        // Find interaction
        webView.isFindInteractionEnabled = findInteractionEnabled

        if !customUserAgent.isEmpty {
            webView.customUserAgent = customUserAgent
        } else {
            webView.customUserAgent = nil
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Explicit cleanup before deallocation
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        // Remove message handlers to prevent retain cycle
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "networkRequest")
        coordinator.invalidateObservation()
        coordinator.navigator?.detach()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        @Binding var isLoading: Bool
        let navigator: WebViewNavigator?

        private var loadingObservation: NSKeyValueObservation?

        init(isLoading: Binding<Bool>, navigator: WebViewNavigator?) {
            _isLoading = isLoading
            self.navigator = navigator
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "consoleLog" {
                handleConsoleMessage(message)
            } else if message.name == "networkRequest" {
                handleNetworkMessage(message)
            } else if message.name == "resourceTiming" {
                handleResourceTimingMessage(message)
            }
        }

        private func handleConsoleMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let msg = body["message"] as? String else {
                return
            }
            let source = body["source"] as? String
            navigator?.consoleManager.addLog(type: type, message: msg, source: source)
        }

        private func handleNetworkMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String,
                  let requestId = body["id"] as? String else {
                return
            }

            switch action {
            case "start":
                let method = body["method"] as? String ?? "GET"
                let url = body["url"] as? String ?? ""
                let requestType = body["type"] as? String ?? "other"
                let headers = body["headers"] as? [String: String]
                let requestBody = body["body"] as? String
                navigator?.networkManager.addRequest(
                    id: requestId,
                    method: method,
                    url: url,
                    requestType: requestType,
                    headers: headers,
                    body: requestBody
                )

            case "complete":
                let status = body["status"] as? Int
                let statusText = body["statusText"] as? String
                let headers = body["headers"] as? [String: String]
                let responseBody = body["body"] as? String
                navigator?.networkManager.updateRequest(
                    id: requestId,
                    status: status,
                    statusText: statusText,
                    responseHeaders: headers,
                    responseBody: responseBody,
                    error: nil
                )

            case "error":
                let error = body["error"] as? String
                navigator?.networkManager.updateRequest(
                    id: requestId,
                    status: nil,
                    statusText: nil,
                    responseHeaders: nil,
                    responseBody: nil,
                    error: error
                )

            default:
                break
            }
        }

        private func handleResourceTimingMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else {
                return
            }

            if action == "entries", let entries = body["entries"] as? [[String: Any]] {
                navigator?.resourceManager.addResources(from: entries)
            }
        }

        func observeWebView(_ webView: WKWebView) {
            loadingObservation = webView.observe(\.isLoading, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.isLoading = webView.isLoading
                }
            }
        }

        func invalidateObservation() {
            loadingObservation?.invalidate()
            loadingObservation = nil
        }

        // Track pending document request (only one at a time for main frame)
        private var pendingDocumentRequestId: String?

        // Handle navigation actions (link clicks, reload, etc.)
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Clear console and network logs only on reload (unless preserveLog is enabled)
            // Normal navigation (links, URL changes) preserves logs
            if navigationAction.navigationType == .reload {
                navigator?.consoleManager.clearIfNotPreserved()
                navigator?.networkManager.clearIfNotPreserved()
            }

            // Track document navigation for main frame only
            if navigationAction.targetFrame?.isMainFrame == true,
               let url = navigationAction.request.url?.absoluteString {

                // If there's already a pending request, it must be a redirect
                // Mark it as 302 before creating the new request
                if let previousId = pendingDocumentRequestId {
                    navigator?.networkManager.updateRequest(
                        id: previousId,
                        status: 302,
                        statusText: "Redirect",
                        responseHeaders: nil,
                        responseBody: nil,
                        error: nil
                    )
                }

                // Create new request
                let requestId = UUID().uuidString
                pendingDocumentRequestId = requestId

                navigator?.networkManager.addRequest(
                    id: requestId,
                    method: navigationAction.request.httpMethod ?? "GET",
                    url: url,
                    requestType: "document",
                    headers: nil,
                    body: nil
                )
            }

            // Allow default WKWebView behavior (including universal links opening external apps)
            decisionHandler(.allow)
        }

        // Get response status and headers for document navigation
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            // Update document request with response info
            if navigationResponse.isForMainFrame,
               let requestId = pendingDocumentRequestId,
               let httpResponse = navigationResponse.response as? HTTPURLResponse {
                var headers: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    headers[String(describing: key)] = String(describing: value)
                }

                navigator?.networkManager.updateRequest(
                    id: requestId,
                    status: httpResponse.statusCode,
                    statusText: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    responseHeaders: headers.isEmpty ? nil : headers,
                    responseBody: nil,
                    error: nil
                )
            }
            decisionHandler(.allow)
        }

        // Mark document navigation as complete
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pendingDocumentRequestId = nil
        }

        // Handle document navigation failure
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if let requestId = pendingDocumentRequestId {
                navigator?.networkManager.updateRequest(
                    id: requestId,
                    status: nil,
                    statusText: nil,
                    responseHeaders: nil,
                    responseBody: nil,
                    error: error.localizedDescription
                )
            }
            pendingDocumentRequestId = nil
        }

        // Handle provisional navigation failure
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if let requestId = pendingDocumentRequestId {
                navigator?.networkManager.updateRequest(
                    id: requestId,
                    status: nil,
                    statusText: nil,
                    responseHeaders: nil,
                    responseBody: nil,
                    error: error.localizedDescription
                )
            }
            pendingDocumentRequestId = nil
        }

        // Handle new window requests (target="_blank")
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Load in same webView instead of opening new window
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // Handle JavaScript alerts
        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                completionHandler()
            }))
            presentAlertController(alertController)
        }

        // Handle JavaScript confirms
        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                completionHandler(true)
            }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                completionHandler(false)
            }))
            presentAlertController(alertController)
        }

        // Handle JavaScript prompts
        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alertController.addTextField { textField in
                textField.text = defaultText
            }
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                completionHandler(alertController.textFields?.first?.text)
            }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                completionHandler(nil)
            }))
            presentAlertController(alertController)
        }

        private func presentAlertController(_ alertController: UIAlertController) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else {
                return
            }
            // Find topmost presented view controller
            var topVC = rootViewController
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(alertController, animated: true)
        }

        deinit {
            invalidateObservation()
        }
    }
}

// MARK: - Loading Progress Bar

private struct LoadingProgressBar: View {
    @State private var animationOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width * 0.3

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .accentColor.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: barWidth, height: 3)
                .offset(x: animationOffset * (geometry.size.width + barWidth) - barWidth / 2)
        }
        .frame(height: 3)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                animationOffset = 1
            }
        }
    }
}

// MARK: - Checkerboard Pattern

private struct CheckerboardPattern: View {
    let squareSize: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))

            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(.secondary.opacity(0.08)))
                }
            }
        }
    }
}

// MARK: - Safari WebView

struct SafariWebView: UIViewControllerRepresentable {
    let urlString: String

    // Configuration settings (require recreation)
    @AppStorage("safariEntersReaderIfAvailable") var entersReaderIfAvailable = false
    @AppStorage("safariBarCollapsingEnabled") var barCollapsingEnabled = true

    // Runtime-changeable settings
    @AppStorage("safariDismissButtonStyle") var dismissButtonStyle = 0
    @AppStorage("safariControlTintColorHex") var controlTintColorHex = ""
    @AppStorage("safariBarTintColorHex") var barTintColorHex = ""

    func makeUIViewController(context: Context) -> SFSafariViewController {
        guard let url = URL(string: urlString) else {
            return SFSafariViewController(url: URL(string: "about:blank")!)
        }
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = entersReaderIfAvailable
        config.barCollapsingEnabled = barCollapsingEnabled
        let vc = SFSafariViewController(url: url, configuration: config)

        // Apply runtime settings
        applyRuntimeSettings(to: vc)

        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // Only runtime-changeable properties can be updated
        applyRuntimeSettings(to: uiViewController)
    }

    private func applyRuntimeSettings(to vc: SFSafariViewController) {
        // Dismiss button style
        switch dismissButtonStyle {
        case 1: vc.dismissButtonStyle = .close
        case 2: vc.dismissButtonStyle = .cancel
        default: vc.dismissButtonStyle = .done
        }

        // Note: preferredControlTintColor and preferredBarTintColor were deprecated in iOS 26.0
        // as they interfere with Liquid Glass background effects that the system provides.
    }
}

#Preview {
    @Previewable @State var id = UUID()
    WebViewContainer(urlString: "https://apple.com", useSafari: false, webViewID: $id, navigator: nil)
}
