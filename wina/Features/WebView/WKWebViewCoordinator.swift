//
//  WKWebViewCoordinator.swift
//  wina
//
//  Coordinator for WKWebViewRepresentable handling navigation and script messages.
//

import OSLog
import SwiftUI
import WebKit

// MARK: - WKWebView Coordinator

class WKWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    @Binding var isLoading: Bool
    let navigator: WebViewNavigator?

    private var loadingObservation: NSKeyValueObservation?
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "wina", category: "ConsoleBridge")

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

    // MARK: - Clear Strategy

    private func applyClearStrategy(currentURL: URL?, newURL: URL?) {
        let strategyRaw = UserDefaults.standard.string(forKey: "logClearStrategy") ?? LogClearStrategy.keep.rawValue
        let strategy = LogClearStrategy(rawValue: strategyRaw) ?? .keep

        switch strategy {
        case .keep:
            // Never auto-clear
            return
        case .page:
            // Clear on every navigation
            clearAllLogs()
        case .origin:
            // Clear only when origin changes
            guard let currentHost = currentURL?.host,
                  let newHost = newURL?.host,
                  currentHost != newHost else { return }
            clearAllLogs()
        }
    }

    private func clearAllLogs() {
        navigator?.consoleManager.clear()
        navigator?.networkManager.clear()
        navigator?.resourceManager.clear()
    }

    // Track pending document request (only one at a time for main frame)
    private var pendingDocumentRequestId: String?

    // Handle navigation actions (link clicks, reload, etc.)
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Handle reload: use preserveLog setting
        if navigationAction.navigationType == .reload {
            navigator?.consoleManager.clearIfNotPreserved()
            navigator?.networkManager.clearIfNotPreserved()
            navigator?.resourceManager.clearIfNotPreserved()
        } else if navigationAction.targetFrame?.isMainFrame == true {
            // Handle navigation: use clearStrategy
            applyClearStrategy(
                currentURL: webView.url,
                newURL: navigationAction.request.url
            )
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
