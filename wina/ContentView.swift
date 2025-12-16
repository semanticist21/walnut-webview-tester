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

    // WebView size settings (for fullscreen detection)
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82
    @AppStorage("safariWidthRatio") private var safariWidthRatio: Double = 1.0
    @AppStorage("safariHeightRatio") private var safariHeightRatio: Double = 0.82

    // App preset: heightRatio = 0.82
    // Use 0.83 threshold to handle floating point comparison
    private var shouldBarsBeExpanded: Bool {
        let heightRatio = useSafariWebView ? safariHeightRatio : webViewHeightRatio
        return heightRatio <= 0.83
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
                    showAccessibility: $showAccessibility
                )
            } else {
                topBar
            }
        }
        .sheet(isPresented: $showSettings) {
            if useSafariWebView {
                SafariVCSettingsView(webViewID: $webViewID)
            } else {
                LoadedSettingsView(
                    webViewID: $webViewID,
                    loadedURL: $loadedURL,
                    navigator: webViewNavigator
                )
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
            } else {
                // Pass navigator only when WebView is loaded (for live page testing)
                InfoView(navigator: showWebView ? webViewNavigator : nil)
            }
        }
        .sheet(isPresented: $showConsole) {
            ConsoleView(consoleManager: webViewNavigator.consoleManager)
                .presentationDetents([.fraction(0.35), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNetwork) {
            NetworkView(
                networkManager: webViewNavigator.networkManager,
                resourceManager: webViewNavigator.resourceManager
            )
            .presentationDetents([.fraction(0.35), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStorage) {
            StorageView(storageManager: storageManager, navigator: webViewNavigator)
                .presentationDetents([.fraction(0.35), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPerformance) {
            PerformanceView(
                performanceManager: webViewNavigator.performanceManager,
                onCollect: {
                    // Collect cached performance data from current page
                    Task {
                        webViewNavigator.performanceManager.isLoading = true
                        if let result = await webViewNavigator.evaluateJavaScript(PerformanceManager.collectionScript) as? String {
                            webViewNavigator.performanceManager.parseData(from: result)
                        }
                        webViewNavigator.performanceManager.isLoading = false
                    }
                },
                onReload: {
                    // Reload page and collect fresh performance data
                    Task {
                        webViewNavigator.performanceManager.isLoading = true
                        webViewNavigator.performanceManager.clear()
                        webViewNavigator.reload()
                        // Wait for page load then collect
                        try? await Task.sleep(for: .seconds(2))
                        if let result = await webViewNavigator.evaluateJavaScript(PerformanceManager.collectionScript) as? String {
                            webViewNavigator.performanceManager.parseData(from: result)
                        }
                        webViewNavigator.performanceManager.isLoading = false
                    }
                }
            )
            .presentationDetents([.fraction(0.35), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditor) {
            SourcesView(navigator: webViewNavigator)
                .presentationDetents([.fraction(0.35), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAccessibility) {
            AccessibilityAuditView(navigator: webViewNavigator)
                .presentationDetents([.medium, .large], selection: .constant(.medium))
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
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
    }

    // MARK: - URL Actions (internal for extension access)

    func submitURL() {
        guard !urlText.isEmpty else { return }

        // Add to history via shared storage
        urlStorage.addToHistory(urlText)

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
                    storageManager.clear()

                    // 3. Create fresh navigator instance for completely new session
                    webViewNavigator.detach()
                    webViewNavigator = WebViewNavigator()

                    loadedURL = urlText
                    webViewID = UUID()  // Force new WebView instance
                    withAnimation(.easeOut(duration: 0.2)) {
                        showWebView = true
                    }
                }
            }
        } else {
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
}

#Preview {
    ContentView()
}
