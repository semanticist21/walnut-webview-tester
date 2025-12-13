//
//  WebViewContainer.swift
//  wina
//
//  Created by Claude on 12/11/25.
//

import SwiftUI
import WebKit
import SafariServices

// MARK: - WebView Navigator

@Observable
class WebViewNavigator {
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: URL?
    let consoleManager = ConsoleManager()
    let networkManager = NetworkManager()

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
}

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

    // Console hooking script - intercepts console methods and forwards to native
    private static let consoleHookScript = """
        (function() {
            if (window.__consoleHooked) return;
            window.__consoleHooked = true;

            // Parse stack trace to get caller location
            function getCallerSource() {
                try {
                    const stack = new Error().stack;
                    if (!stack) return null;
                    const lines = stack.split('\\n');
                    // Skip: Error, our hook function, console.method wrapper
                    // Find the first line that's not our code
                    for (let i = 3; i < lines.length; i++) {
                        const line = lines[i];
                        if (!line) continue;
                        // Match patterns like "at func (url:line:col)" or "url:line:col"
                        const match = line.match(/(?:at\\s+)?(?:[^(]+\\s+\\()?([^)\\s]+):(\\d+)(?::\\d+)?\\)?/);
                        if (match) {
                            let url = match[1];
                            const lineNum = match[2];
                            // Simplify URL: extract filename or hostname+path
                            try {
                                const parsed = new URL(url);
                                const path = parsed.pathname;
                                url = path.split('/').pop() || parsed.hostname + path;
                            } catch(e) {
                                // Use as-is if not a valid URL
                                url = url.split('/').pop() || url;
                            }
                            return url + ':' + lineNum;
                        }
                    }
                } catch(e) {}
                return null;
            }

            // Helper to format arguments
            function formatArg(arg) {
                if (arg === null) return 'null';
                if (arg === undefined) return 'undefined';
                if (typeof arg === 'function') return '[Function: ' + (arg.name || 'anonymous') + ']';
                if (typeof arg === 'symbol') return arg.toString();
                if (typeof arg === 'bigint') return arg.toString() + 'n';
                if (arg instanceof Error) return arg.name + ': ' + arg.message + (arg.stack ? '\\n' + arg.stack : '');
                if (arg instanceof Element) return '<' + arg.tagName.toLowerCase() + (arg.id ? '#' + arg.id : '') + (arg.className ? '.' + arg.className.split(' ').join('.') : '') + '>';
                if (arg instanceof RegExp) return arg.toString();
                if (arg instanceof Date) return 'Date(' + arg.toISOString() + ')';
                if (arg instanceof Promise) return 'Promise {<pending>}';
                if (arg instanceof Map) return 'Map(' + arg.size + ') {' + Array.from(arg.entries()).map(function(e) { return e[0] + ' => ' + e[1]; }).join(', ') + '}';
                if (arg instanceof Set) return 'Set(' + arg.size + ') {' + Array.from(arg).join(', ') + '}';
                if (ArrayBuffer.isView(arg)) return arg.constructor.name + '(' + arg.length + ') [' + Array.from(arg.slice(0, 10)).join(', ') + (arg.length > 10 ? ', ...' : '') + ']';
                if (arg instanceof ArrayBuffer) return 'ArrayBuffer(' + arg.byteLength + ')';
                if (typeof arg === 'object') {
                    try {
                        const str = JSON.stringify(arg, null, 2);
                        return str === '{}' && Object.keys(arg).length === 0 ? '{}' : (str === '{}' ? '[object ' + (arg.constructor?.name || 'Object') + ']' : str);
                    }
                    catch(e) { return '[object ' + (arg.constructor?.name || 'Object') + ']'; }
                }
                return String(arg);
            }

            const methods = ['log', 'info', 'warn', 'error', 'debug'];
            methods.forEach(function(method) {
                const original = console[method];
                console[method] = function(...args) {
                    try {
                        const message = args.map(formatArg).join(' ');
                        const source = getCallerSource();
                        window.webkit.messageHandlers.consoleLog.postMessage({
                            type: method,
                            message: message,
                            source: source
                        });
                    } catch(e) {}
                    original.apply(console, args);
                };
            });

            // console.group
            const originalGroup = console.group;
            console.group = function(...args) {
                try {
                    const message = args.length > 0 ? args.map(formatArg).join(' ') : 'group';
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'group',
                        message: message,
                        source: getCallerSource()
                    });
                } catch(e) {}
                originalGroup.apply(console, args);
            };

            // console.groupCollapsed
            const originalGroupCollapsed = console.groupCollapsed;
            console.groupCollapsed = function(...args) {
                try {
                    const message = args.length > 0 ? args.map(formatArg).join(' ') : 'group';
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'groupCollapsed',
                        message: message,
                        source: getCallerSource()
                    });
                } catch(e) {}
                originalGroupCollapsed.apply(console, args);
            };

            // console.groupEnd
            const originalGroupEnd = console.groupEnd;
            console.groupEnd = function() {
                try {
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'groupEnd',
                        message: '',
                        source: null
                    });
                } catch(e) {}
                originalGroupEnd.apply(console);
            };

            // console.table
            const originalTable = console.table;
            console.table = function(data, columns) {
                try {
                    let tableData = [];
                    if (Array.isArray(data)) {
                        tableData = data.map(function(item, index) {
                            if (typeof item === 'object' && item !== null) {
                                const row = { '(index)': String(index) };
                                const keys = columns || Object.keys(item);
                                keys.forEach(function(key) {
                                    row[key] = formatArg(item[key]);
                                });
                                return row;
                            }
                            return { '(index)': String(index), 'Value': formatArg(item) };
                        });
                    } else if (typeof data === 'object' && data !== null) {
                        Object.keys(data).forEach(function(key) {
                            const item = data[key];
                            if (typeof item === 'object' && item !== null) {
                                const row = { '(index)': key };
                                const keys = columns || Object.keys(item);
                                keys.forEach(function(k) {
                                    row[k] = formatArg(item[k]);
                                });
                                tableData.push(row);
                            } else {
                                tableData.push({ '(index)': key, 'Value': formatArg(item) });
                            }
                        });
                    }
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'table',
                        message: JSON.stringify(tableData),
                        source: getCallerSource()
                    });
                } catch(e) {}
                originalTable.apply(console, arguments);
            };

            // Capture uncaught errors
            window.addEventListener('error', function(e) {
                let source = null;
                if (e.filename) {
                    try {
                        const parsed = new URL(e.filename);
                        const path = parsed.pathname;
                        source = (path.split('/').pop() || parsed.hostname + path) + ':' + e.lineno;
                    } catch(err) {
                        source = e.filename + ':' + e.lineno;
                    }
                }
                window.webkit.messageHandlers.consoleLog.postMessage({
                    type: 'error',
                    message: 'Uncaught: ' + e.message,
                    source: source
                });
            });

            // Capture unhandled promise rejections
            window.addEventListener('unhandledrejection', function(e) {
                window.webkit.messageHandlers.consoleLog.postMessage({
                    type: 'error',
                    message: 'Unhandled Promise: ' + String(e.reason),
                    source: null
                });
            });
        })();
        """

    // Network hooking script - intercepts fetch and XMLHttpRequest
    private static let networkHookScript = """
        (function() {
            if (window.__networkHooked) return;
            window.__networkHooked = true;

            // Generate unique request ID
            function generateId() {
                return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                    var r = Math.random() * 16 | 0;
                    var v = c === 'x' ? r : (r & 0x3 | 0x8);
                    return v.toString(16);
                });
            }

            // Safely stringify headers
            function headersToObject(headers) {
                if (!headers) return null;
                var obj = {};
                if (headers.forEach) {
                    headers.forEach(function(value, key) {
                        obj[key] = value;
                    });
                } else if (typeof headers === 'object') {
                    for (var key in headers) {
                        if (headers.hasOwnProperty(key)) {
                            obj[key] = headers[key];
                        }
                    }
                }
                return Object.keys(obj).length > 0 ? obj : null;
            }

            // Truncate body for large payloads
            function truncateBody(body, maxLen) {
                maxLen = maxLen || 10000;
                if (!body) return null;
                if (typeof body !== 'string') {
                    try { body = JSON.stringify(body); } catch(e) { body = String(body); }
                }
                if (body.length > maxLen) {
                    return body.substring(0, maxLen) + '... (truncated)';
                }
                return body;
            }

            // Hook fetch
            var originalFetch = window.fetch;
            window.fetch = function(input, init) {
                var requestId = generateId();
                var url = typeof input === 'string' ? input : (input.url || String(input));
                var method = (init && init.method) || (input && input.method) || 'GET';
                var headers = (init && init.headers) || (input && input.headers) || null;
                var body = (init && init.body) || null;

                try {
                    window.webkit.messageHandlers.networkRequest.postMessage({
                        action: 'start',
                        id: requestId,
                        method: method,
                        url: url,
                        type: 'fetch',
                        headers: headersToObject(headers),
                        body: truncateBody(body)
                    });
                } catch(e) {}

                return originalFetch.apply(this, arguments)
                    .then(function(response) {
                        var responseHeaders = {};
                        response.headers.forEach(function(value, key) {
                            responseHeaders[key] = value;
                        });

                        // Clone response to read body
                        var cloned = response.clone();
                        cloned.text().then(function(text) {
                            try {
                                window.webkit.messageHandlers.networkRequest.postMessage({
                                    action: 'complete',
                                    id: requestId,
                                    status: response.status,
                                    statusText: response.statusText,
                                    headers: responseHeaders,
                                    body: truncateBody(text)
                                });
                            } catch(e) {}
                        }).catch(function() {
                            try {
                                window.webkit.messageHandlers.networkRequest.postMessage({
                                    action: 'complete',
                                    id: requestId,
                                    status: response.status,
                                    statusText: response.statusText,
                                    headers: responseHeaders,
                                    body: null
                                });
                            } catch(e) {}
                        });

                        return response;
                    })
                    .catch(function(error) {
                        try {
                            window.webkit.messageHandlers.networkRequest.postMessage({
                                action: 'error',
                                id: requestId,
                                error: error.message || String(error)
                            });
                        } catch(e) {}
                        throw error;
                    });
            };

            // Hook XMLHttpRequest
            var XHR = XMLHttpRequest;
            var originalOpen = XHR.prototype.open;
            var originalSend = XHR.prototype.send;
            var originalSetRequestHeader = XHR.prototype.setRequestHeader;

            XHR.prototype.open = function(method, url) {
                this.__networkRequestId = generateId();
                this.__networkMethod = method;
                this.__networkUrl = url;
                this.__networkHeaders = {};
                return originalOpen.apply(this, arguments);
            };

            XHR.prototype.setRequestHeader = function(name, value) {
                if (this.__networkHeaders) {
                    this.__networkHeaders[name] = value;
                }
                return originalSetRequestHeader.apply(this, arguments);
            };

            XHR.prototype.send = function(body) {
                var xhr = this;
                var requestId = xhr.__networkRequestId;

                try {
                    window.webkit.messageHandlers.networkRequest.postMessage({
                        action: 'start',
                        id: requestId,
                        method: xhr.__networkMethod || 'GET',
                        url: xhr.__networkUrl || '',
                        type: 'xhr',
                        headers: xhr.__networkHeaders,
                        body: truncateBody(body)
                    });
                } catch(e) {}

                xhr.addEventListener('load', function() {
                    var responseHeaders = {};
                    var headerString = xhr.getAllResponseHeaders();
                    if (headerString) {
                        headerString.split('\\r\\n').forEach(function(line) {
                            var parts = line.split(': ');
                            if (parts.length === 2) {
                                responseHeaders[parts[0]] = parts[1];
                            }
                        });
                    }

                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'complete',
                            id: requestId,
                            status: xhr.status,
                            statusText: xhr.statusText,
                            headers: Object.keys(responseHeaders).length > 0 ? responseHeaders : null,
                            body: truncateBody(xhr.responseText)
                        });
                    } catch(e) {}
                });

                xhr.addEventListener('error', function() {
                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'error',
                            id: requestId,
                            error: 'Network error'
                        });
                    } catch(e) {}
                });

                xhr.addEventListener('abort', function() {
                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'error',
                            id: requestId,
                            error: 'Request aborted'
                        });
                    } catch(e) {}
                });

                xhr.addEventListener('timeout', function() {
                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'error',
                            id: requestId,
                            error: 'Request timeout'
                        });
                    } catch(e) {}
                });

                return originalSend.apply(this, arguments);
            };
        })();
        """

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, navigator: navigator)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Add console and network hook scripts and message handlers to configuration
        let userContentController = configuration.userContentController

        // Console hook
        userContentController.add(context.coordinator, name: "consoleLog")
        let consoleScript = WKUserScript(
            source: Self.consoleHookScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(consoleScript)

        // Network hook
        userContentController.add(context.coordinator, name: "networkRequest")
        let networkScript = WKUserScript(
            source: Self.networkHookScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(networkScript)

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
            // Allow default WKWebView behavior (including universal links opening external apps)
            decisionHandler(.allow)
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
            completionHandler()
        }

        // Handle JavaScript confirms
        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }

        // Handle JavaScript prompts
        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            completionHandler(defaultText)
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
