//
//  ContentView.swift
//  wina
//
//  Created by 박지원 on 12/6/25.
//

import SwiftUI
import SwiftUIBackports
import WebKit

struct ContentView: View {
    // MARK: - State Properties (internal for extension access)

    @State var urlText: String = ""
    @State var showDropdown: Bool = false
    @State var showSettings: Bool = false
    @State var showBookmarks: Bool = false
    @State var showInfo: Bool = false
    @State private var showConsole: Bool = false
    @State private var showNetwork: Bool = false
    @State private var showStorage: Bool = false
    @State private var showPerformance: Bool = false
    @State private var showEditor: Bool = false
    @State private var showAccessibility: Bool = false
    @State private var showSnippets: Bool = false
    @State private var showSearchText: Bool = false
    @State var showAbout: Bool = false
    @State var urlValidationState: URLValidationState = .empty
    @State var useSafariWebView: Bool = false
    @State var showWebView: Bool = false
    @State private var loadedURL = ""
    @State private var webViewID = UUID()
    @State var validationTask: Task<Void, Never>?
    @State private var webViewNavigator = WebViewNavigator()
    @State private var storageManager = StorageManager()
    @FocusState var textFieldFocused: Bool

    // Shared URL storage
    var urlStorage: URLStorageManager { URLStorageManager.shared }

    // Quick options (synced with Settings)
    @AppStorage("cleanStart") var cleanStart = true
    @AppStorage("privateBrowsing") var privateBrowsing = false

    // Safari configuration settings (for onChange detection)
    @AppStorage("safariEntersReaderIfAvailable") private var safariEntersReaderIfAvailable = false
    @AppStorage("safariBarCollapsingEnabled") private var safariBarCollapsingEnabled = true

    // Eruda mode (third-party in-page console)
    @AppStorage("erudaModeEnabled") private var erudaModeEnabled = false

    // WebView size settings (for fullscreen detection)
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82
    @AppStorage("safariWidthRatio") private var safariWidthRatio: Double = 1.0
    @AppStorage("safariHeightRatio") private var safariHeightRatio: Double = 0.82

    // Bars are expanded (fixed position) when WebView is NOT fullscreen
    // Fullscreen = both width and height at 99%+ (matches isFullSize in WebViewContainer)
    private var shouldBarsBeExpanded: Bool {
        let widthRatio = useSafariWebView ? safariWidthRatio : webViewWidthRatio
        let heightRatio = useSafariWebView ? safariHeightRatio : webViewHeightRatio
        let isFullSize = widthRatio >= 0.99 && heightRatio >= 0.99
        return !isFullSize
    }

    var filteredURLs: [String] {
        urlStorage.filteredHistory(query: urlText)
    }

    let urlParts = [
        "https://", "http://",
        "www.", "m.",
        ".com",
        "192.168.", ":8080", ":3000"
    ]
    let inputWidth: CGFloat = 340

    var body: some View {
        ZStack {
            if showWebView {
                // WebView screen
                WebViewContainer(
                    urlString: loadedURL,
                    useSafari: useSafariWebView,
                    webViewID: $webViewID,
                    navigator: useSafariWebView ? nil : webViewNavigator
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                // URL input screen
                urlInputView
            }

            // Menu bars
            if showWebView {
                OverlayMenuBars(
                    showWebView: showWebView,
                    hasBookmarks: !urlStorage.bookmarks.isEmpty,
                    useSafariVC: useSafariWebView,
                    isOverlayMode: !shouldBarsBeExpanded,
                    erudaModeEnabled: erudaModeEnabled,
                    onHome: {
                        // Close all DevTools sheets before going home
                        showConsole = false
                        showNetwork = false
                        showStorage = false
                        showPerformance = false
                        showEditor = false
                        showAccessibility = false
                        showSettings = false
                        showBookmarks = false
                        showInfo = false

                        // Clear initial URL tracking
                        webViewNavigator.clearInitialURL()

                        withAnimation(.easeOut(duration: 0.2)) {
                            showWebView = false
                        }
                    },
                    onURLChange: { newURL in
                        // Add to history
                        urlStorage.addToHistory(newURL)

                        // Load in same WebView instance (preserves history)
                        if !useSafariWebView {
                            webViewNavigator.loadURL(newURL)
                        } else {
                            // SafariVC needs recreation
                            loadedURL = newURL
                            webViewID = UUID()
                        }
                    },
                    navigator: useSafariWebView ? nil : webViewNavigator,
                    urlStorage: urlStorage,
                    showSettings: $showSettings,
                    showBookmarks: $showBookmarks,
                    showInfo: $showInfo,
                    showConsole: $showConsole,
                    showNetwork: $showNetwork,
                    showStorage: $showStorage,
                    showPerformance: $showPerformance,
                    showEditor: $showEditor,
                    showAccessibility: $showAccessibility,
                    showSnippets: $showSnippets,
                    showSearchText: $showSearchText
                )
            } else if !showWebView {
                topBar
            }
        }
        .sheet(isPresented: $showSettings) {
            if useSafariWebView {
                SafariVCSettingsView(webViewID: $webViewID)
                    .fullSizeSheet()
            } else {
                LoadedSettingsView(
                    webViewID: $webViewID,
                    loadedURL: $loadedURL,
                    navigator: webViewNavigator
                )
                .fullSizeSheet()
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksSheet(
                bookmarkedURLs: urlStorage.bookmarks,
                onSelect: { url in
                    urlText = url
                },
                onDelete: { url in
                    urlStorage.removeBookmark(url)
                },
                onAdd: { url in
                    urlStorage.addBookmark(url)
                },
                currentURL: urlText
            )
        }
        .sheet(isPresented: $showInfo) {
            if useSafariWebView {
                SafariVCInfoView()
                    .fullSizeSheet()
            } else {
                // Pass navigator only when WebView is loaded (for live page testing)
                InfoView(navigator: showWebView ? webViewNavigator : nil)
                    .fullSizeSheet()
            }
        }
        .sheet(isPresented: $showConsole) {
            ConsoleView(consoleManager: webViewNavigator.consoleManager, navigator: webViewNavigator)
                .devToolsSheet()
        }
        .sheet(isPresented: $showNetwork) {
            NetworkView(
                networkManager: webViewNavigator.networkManager,
                resourceManager: webViewNavigator.resourceManager
            )
            .devToolsSheet()
        }
        .sheet(isPresented: $showStorage) {
            StorageView(storageManager: storageManager, navigator: webViewNavigator)
                .devToolsSheet()
        }
        .sheet(isPresented: $showPerformance) {
            PerformanceView(
                performanceManager: webViewNavigator.performanceManager,
                onCollect: {
                    // Collect cached performance data from current page
                    Task {
                        await collectPerformanceData(webViewNavigator, isReload: false)
                    }
                },
                onReload: {
                    // Reload page and collect fresh performance data
                    Task {
                        await collectPerformanceData(webViewNavigator, isReload: true)
                    }
                }
            )
            .devToolsSheet()
        }
        .sheet(isPresented: $showEditor) {
            SourcesView(navigator: webViewNavigator)
                .devToolsSheet()
        }
        .sheet(isPresented: $showAccessibility) {
            AccessibilityAuditView(navigator: webViewNavigator)
                .devToolsSheet()
        }
        .sheet(isPresented: $showSnippets) {
            SnippetsSettingsView(navigator: webViewNavigator)
                .devToolsSheet()
        }
        .overlay {
            if showSearchText {
                SearchTextOverlay(
                    navigator: webViewNavigator,
                    isPresented: $showSearchText
                )
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        // Recreate SafariVC when configuration settings change
        .onChange(of: safariEntersReaderIfAvailable) { _, _ in
            if useSafariWebView && showWebView {
                webViewID = UUID()
            }
        }
        .onChange(of: safariBarCollapsingEnabled) { _, _ in
            if useSafariWebView && showWebView {
                webViewID = UUID()
            }
        }
        // Eruda mode: inject/destroy when toggled
        .onChange(of: erudaModeEnabled) { _, newValue in
            guard showWebView && !useSafariWebView else { return }
            Task {
                if newValue {
                    await webViewNavigator.injectEruda()
                } else {
                    await webViewNavigator.destroyEruda()
                }
            }
        }
        // Inject Eruda when WebView loads (if Eruda mode is enabled)
        .onChange(of: webViewNavigator.currentURL) { _, _ in
            guard erudaModeEnabled && showWebView && !useSafariWebView else { return }
            Task {
                // Small delay to ensure page is ready
                try? await Task.sleep(for: .milliseconds(500))
                await webViewNavigator.injectEruda()
            }
        }
    }

    // MARK: - URL Actions (internal for extension access)

    func submitURL() {
        guard !urlText.isEmpty else { return }

        // Add to history via shared storage
        urlStorage.addToHistory(urlText)

        // Normalize URL for initialURL tracking
        var normalized = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.contains("://") {
            normalized = "https://\(normalized)"
        }
        let initialURLValue = URL(string: normalized)

        // Clean Start: clear all website data and DevTools logs before loading
        if cleanStart {
            Task {
                // 1. Clear all WKWebView website data (cookies, localStorage, cache, etc.)
                let dataStore = WKWebsiteDataStore.default()
                let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                let records = await dataStore.dataRecords(ofTypes: allTypes)
                await dataStore.removeData(ofTypes: allTypes, for: records)

                await MainActor.run {
                    // 2. Clear all DevTools data
                    webViewNavigator.consoleManager.clear()
                    webViewNavigator.networkManager.clear()
                    webViewNavigator.resourceManager.clear()
                    webViewNavigator.performanceManager.clear()
                    webViewNavigator.accessibilityManager.clear()
                    storageManager.clear()

                    // 3. Create fresh navigator instance for completely new session
                    webViewNavigator.detach()
                    webViewNavigator = WebViewNavigator()

                    // Set initial URL for "go to initial" feature
                    if let url = initialURLValue {
                        webViewNavigator.setInitialURL(url)
                    }

                    loadedURL = urlText
                    webViewID = UUID()  // Force new WebView instance
                    withAnimation(.easeOut(duration: 0.2)) {
                        showWebView = true
                    }
                }
            }
        } else {
            // Set initial URL for "go to initial" feature
            if let url = initialURLValue {
                webViewNavigator.setInitialURL(url)
            }

            loadedURL = urlText
            withAnimation(.easeOut(duration: 0.2)) {
                showWebView = true
            }
        }
    }

    func removeURL(_ url: String) {
        urlStorage.removeFromHistory(url)
    }

    func validateURL() {
        guard !urlText.isEmpty else {
            urlValidationState = .empty
            return
        }
        urlValidationState = URLValidator.isValidURL(urlText) ? .valid : .invalid
    }

    // MARK: - Performance Data Collection

    /// Collect performance data with proper page load detection
    @MainActor
    private func collectPerformanceData(_ navigator: WebViewNavigator, isReload: Bool) async {
        let manager = navigator.performanceManager
        manager.isLoading = true
        manager.lastError = nil

        if isReload {
            manager.clear()
            navigator.reload()
            // Wait for page load with polling (max 10s)
            let maxAttempts = 20
            for _ in 0..<maxAttempts {
                try? await Task.sleep(for: .milliseconds(500))
                // Check if page load is complete
                if let ready = await navigator.evaluateJavaScript(
                    "document.readyState === 'complete' && performance.getEntriesByType('navigation')[0]?.loadEventEnd > 0"
                ) as? Bool, ready {
                    break
                }
            }
        }

        // Collect performance data
        if let result = await navigator.evaluateJavaScript(PerformanceManager.collectionScript) as? String {
            manager.parseData(from: result)
            // Verify we got valid data (navigation timing should have loadEventTime > 0)
            if manager.data.navigation == nil && manager.data.paints.isEmpty {
                manager.lastError = "Page load incomplete. Try refreshing again."
            }
        } else {
            manager.lastError = "Failed to collect performance data. Make sure a page is loaded."
        }

        manager.isLoading = false
    }
}

#Preview {
    ContentView()
}
