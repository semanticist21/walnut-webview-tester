//
//  InfoView.swift
//  wina
//

import SwiftUI

// MARK: - InfoView

struct InfoView: View {
    /// External navigator for live page testing (nil = use test WebView with example.com)
    var navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var webViewInfo: WebViewInfo?
    @State private var deviceInfo: DeviceInfo?
    @State private var codecInfo: MediaCodecInfo?
    @State private var displayInfo: DisplayInfo?
    @State private var accessibilityInfo: AccessibilityInfo?
    @State private var loadingStatus = "Loading..."
    @State private var isLoading = true
    @State private var showSettings = false

    // Instance Settings from AppStorage
    @AppStorage("enableJavaScript") private var enableJavaScript: Bool = true
    @AppStorage("allowsContentJavaScript") private var allowsContentJavaScript: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = false
    @AppStorage("minimumFontSize") private var minimumFontSize: Double = 0
    @AppStorage("mediaAutoplay") private var mediaAutoplay: Bool = false
    @AppStorage("inlineMediaPlayback") private var inlineMediaPlayback: Bool = true
    @AppStorage("allowsAirPlay") private var allowsAirPlay: Bool = true
    @AppStorage("allowsPictureInPicture") private var allowsPictureInPicture: Bool = true
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = false
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true
    @AppStorage("suppressesIncrementalRendering") private var suppressesIncrementalRendering: Bool = false
    @AppStorage("javaScriptCanOpenWindows") private var javaScriptCanOpenWindows: Bool = false
    @AppStorage("fraudulentWebsiteWarning") private var fraudulentWebsiteWarning: Bool = true
    @AppStorage("textInteractionEnabled") private var textInteractionEnabled: Bool = true
    @AppStorage("elementFullscreenEnabled") private var elementFullscreenEnabled: Bool = false
    @AppStorage("detectPhoneNumbers") private var detectPhoneNumbers: Bool = false
    @AppStorage("detectLinks") private var detectLinks: Bool = false
    @AppStorage("detectAddresses") private var detectAddresses: Bool = false
    @AppStorage("detectCalendarEvents") private var detectCalendarEvents: Bool = false
    @AppStorage("privateBrowsing") private var privateBrowsing: Bool = false
    @AppStorage("upgradeToHTTPS") private var upgradeToHTTPS: Bool = true
    @AppStorage("preferredContentMode") private var preferredContentMode: Int = 0
    @AppStorage("customUserAgent") private var customUserAgent: String = ""
    @AppStorage("findInteractionEnabled") private var findInteractionEnabled: Bool = false
    @AppStorage("pageZoom") private var pageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var underPageBackgroundColorHex: String = ""
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82
    @AppStorage("cachedSystemUserAgent") private var cachedSystemUserAgent: String = ""

    private var contentModeText: String {
        SettingsFormatter.contentModeText(preferredContentMode)
    }

    private var activeDataDetectors: String {
        SettingsFormatter.activeDataDetectors(
            phone: detectPhoneNumbers,
            links: detectLinks,
            address: detectAddresses,
            calendar: detectCalendarEvents
        )
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if isSearching {
                    searchResultsView
                } else {
                    defaultMenuView
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all info")
            .navigationTitle("WKWebView Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            // Set navigator for live page testing (or nil for test WebView)
            SharedInfoWebView.shared.setNavigator(navigator)
            await loadAllInfo()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(loadingStatus)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Default Menu View

    private var defaultMenuView: some View {
        List {
            Section {
                if let url = navigator?.currentURL {
                    Text("Tested with loaded page (\(url.host() ?? url.absoluteString)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tested with temporary WebView (example.com). Actual results may vary.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)

            Section {
                NavigationLink {
                    ActiveSettingsView(showSettings: $showSettings)
                } label: {
                    InfoCategoryRow(
                        icon: "slider.horizontal.3",
                        title: "Active Settings",
                        description: "Current WebView configuration values"
                    )
                }
            } header: {
                Text("Current Configuration")
            }

            Section {
                NavigationLink {
                    DeviceInfoView()
                } label: {
                    InfoCategoryRow(
                        icon: "iphone",
                        title: "Device",
                        description: "Hardware, CPU, Memory, Display, Locale"
                    )
                }

                NavigationLink {
                    BrowserInfoView()
                } label: {
                    InfoCategoryRow(
                        icon: "safari",
                        title: "Browser",
                        description: "User Agent, WebKit Version, WebGL Info"
                    )
                }

                NavigationLink {
                    APICapabilitiesView()
                } label: {
                    InfoCategoryRow(
                        icon: "checklist",
                        title: "API Capabilities",
                        description: "46+ Web APIs support status"
                    )
                }

                NavigationLink {
                    MediaCodecsView()
                } label: {
                    InfoCategoryRow(
                        icon: "play.rectangle",
                        title: "Media Codecs",
                        description: "Video, Audio, Container format support"
                    )
                }

                NavigationLink {
                    PerformanceView()
                } label: {
                    InfoCategoryRow(
                        icon: "gauge.with.needle",
                        title: "Performance",
                        description: "JavaScript, DOM, Graphics benchmarks"
                    )
                }

                NavigationLink {
                    DisplayFeaturesView()
                } label: {
                    InfoCategoryRow(
                        icon: "sparkles.rectangle.stack",
                        title: "Display",
                        description: "Screen size, Color gamut, HDR support"
                    )
                }

                NavigationLink {
                    AccessibilityFeaturesView()
                } label: {
                    InfoCategoryRow(
                        icon: "accessibility",
                        title: "Accessibility",
                        description: "Motion, Contrast, Color scheme preferences"
                    )
                }
            } header: {
                Text("WebView Capabilities")
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        List {
            ForEach(filteredItems.keys.sorted(), id: \.self) { category in
                Section(category) {
                    ForEach(filteredItems[category] ?? []) { item in
                        searchResultRow(for: item)
                    }
                }
            }
        }
        .overlay {
            if filteredItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    @ViewBuilder
    private func searchResultRow(for item: InfoSearchItem) -> some View {
        if item.linkToPerformance {
            NavigationLink {
                PerformanceView()
            } label: {
                HStack {
                    Text(item.label)
                    Spacer()
                    Text(item.value)
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                }
            }
        } else {
            HStack {
                Text(item.label)
                Spacer()
                if item.value == "Supported" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if item.value == "Not Supported" {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.value)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadAllInfo() async {
        // Start device info loading in parallel with WebView init (no WebView needed)
        async let device = DeviceInfo.load()

        // Pre-initialize shared WebView in background
        await SharedInfoWebView.shared.initialize { status in
            loadingStatus = status
        }

        // Load all info using shared WebView (parallel)
        async let webView = WebViewInfo.load { _ in }
        async let codec = MediaCodecInfo.load { _ in }
        async let display = DisplayInfo.load { _ in }
        async let accessibility = AccessibilityInfo.load { _ in }

        // Await all results (device likely already completed)
        deviceInfo = await device
        webViewInfo = await webView
        codecInfo = await codec
        displayInfo = await display
        accessibilityInfo = await accessibility
        isLoading = false

        // Cache system user agent for UserAgentPickerView
        if let ua = webViewInfo?.userAgent, !ua.isEmpty, ua != "Unknown" {
            cachedSystemUserAgent = ua
        }
    }

    // MARK: - Search Data

    private var filteredItems: [String: [InfoSearchItem]] {
        let filtered = searchText.isEmpty ? allItems : allItems.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
            $0.value.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: filtered, by: { $0.category })
    }

    private var allItems: [InfoSearchItem] {
        var items: [InfoSearchItem] = []

        // Active Settings (always available)
        items.append(contentsOf: activeSettingsItems)

        // Device items
        if let info = deviceInfo {
            items.append(contentsOf: deviceItems(from: info))
        }

        // Browser & API items from WebViewInfo
        if let info = webViewInfo {
            items.append(contentsOf: browserItems(from: info))
            items.append(contentsOf: apiItems(from: info))
        }

        // Media Codecs
        if let info = codecInfo {
            items.append(contentsOf: codecItems(from: info))
        }

        // Display
        if let info = displayInfo {
            items.append(contentsOf: displayItems(from: info))
        }

        // Accessibility
        if let info = accessibilityInfo {
            items.append(contentsOf: accessibilityItems(from: info))
        }

        // Performance (items only, values require benchmark execution)
        items.append(contentsOf: performanceItems)

        return items
    }

    // MARK: - Search Item Builders

    private var activeSettingsItems: [InfoSearchItem] {
        [
            InfoSearchItem(category: "Active Settings", label: "JavaScript", value: enableJavaScript ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Content JavaScript", value: allowsContentJavaScript ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Ignore Viewport Scale Limits", value: allowZoom ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Minimum Font Size", value: minimumFontSize == 0 ? "Default" : "\(Int(minimumFontSize)) pt"),
            InfoSearchItem(category: "Active Settings", label: "Auto-play Media", value: mediaAutoplay ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Inline Playback", value: inlineMediaPlayback ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "AirPlay", value: allowsAirPlay ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Picture in Picture", value: allowsPictureInPicture ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Back/Forward Gestures", value: allowsBackForwardGestures ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Link Preview", value: allowsLinkPreview ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Content Mode", value: contentModeText),
            InfoSearchItem(category: "Active Settings", label: "JS Can Open Windows", value: javaScriptCanOpenWindows ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Fraudulent Website Warning", value: fraudulentWebsiteWarning ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Text Interaction", value: textInteractionEnabled ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Element Fullscreen API", value: elementFullscreenEnabled ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Suppress Incremental Rendering", value: suppressesIncrementalRendering ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Data Detectors", value: activeDataDetectors),
            InfoSearchItem(category: "Active Settings", label: "Private Browsing", value: privateBrowsing ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Upgrade to HTTPS", value: upgradeToHTTPS ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Custom User-Agent", value: customUserAgent.isEmpty ? "Default" : "Custom"),
            InfoSearchItem(category: "Active Settings", label: "Find Interaction", value: findInteractionEnabled ? "Enabled" : "Disabled"),
            InfoSearchItem(category: "Active Settings", label: "Page Zoom", value: "\(Int(pageZoom * 100))%"),
            InfoSearchItem(category: "Active Settings", label: "Under Page Background", value: underPageBackgroundColorHex.isEmpty ? "Default" : underPageBackgroundColorHex),
            InfoSearchItem(category: "Active Settings", label: "WebView Width", value: "\(Int(webViewWidthRatio * 100))%"),
            InfoSearchItem(category: "Active Settings", label: "WebView Height", value: "\(Int(webViewHeightRatio * 100))%")
        ]
    }

    private func deviceItems(from info: DeviceInfo) -> [InfoSearchItem] {
        [
            InfoSearchItem(category: "Device", label: "Model", value: info.model),
            InfoSearchItem(category: "Device", label: "Model Identifier", value: info.modelIdentifier),
            InfoSearchItem(category: "Device", label: "System", value: "\(info.systemName) \(info.systemVersion)"),
            InfoSearchItem(category: "Device", label: "OS Build", value: info.osBuild),
            InfoSearchItem(category: "Device", label: "CPU Cores", value: info.cpuCores),
            InfoSearchItem(category: "Device", label: "Active Cores", value: info.activeCores),
            InfoSearchItem(category: "Device", label: "Physical Memory", value: info.physicalMemory),
            InfoSearchItem(category: "Device", label: "Thermal State", value: info.thermalState),
            InfoSearchItem(category: "Device", label: "GPU", value: info.gpuName),
            InfoSearchItem(category: "Device", label: "Screen Size", value: info.screenSize),
            InfoSearchItem(category: "Device", label: "Screen Scale", value: info.screenScale),
            InfoSearchItem(category: "Device", label: "Native Scale", value: info.nativeScale),
            InfoSearchItem(category: "Device", label: "Brightness", value: info.brightness),
            InfoSearchItem(category: "Device", label: "Language", value: info.language),
            InfoSearchItem(category: "Device", label: "Region", value: info.region),
            InfoSearchItem(category: "Device", label: "Timezone", value: info.timezone)
        ]
    }

    private func browserItems(from info: WebViewInfo) -> [InfoSearchItem] {
        [
            InfoSearchItem(category: "Browser", label: "User Agent", value: info.userAgent),
            InfoSearchItem(category: "Browser", label: "Language", value: info.language),
            InfoSearchItem(category: "Browser", label: "Languages", value: info.languages),
            InfoSearchItem(category: "Browser", label: "Platform", value: info.platform),
            InfoSearchItem(category: "Browser", label: "Vendor", value: info.vendor),
            InfoSearchItem(category: "Browser", label: "WebKit Version", value: info.webKitVersion),
            InfoSearchItem(category: "Browser", label: "JavaScriptCore Version", value: info.jsCoreVersion),
            InfoSearchItem(category: "Browser", label: "Color Depth", value: info.colorDepth),
            InfoSearchItem(category: "Browser", label: "WebGL Renderer", value: info.webGLRenderer),
            InfoSearchItem(category: "Browser", label: "WebGL Vendor", value: info.webGLVendor),
            InfoSearchItem(category: "Browser", label: "WebGL Version", value: info.webGLVersion)
        ]
    }

    private func apiItems(from info: WebViewInfo) -> [InfoSearchItem] {
        let apis: [(String, Bool, String?)] = [
            ("JavaScript", info.supportsJavaScript, nil),
            ("WebAssembly", info.supportsWebAssembly, nil),
            ("Web Workers", info.supportsWebWorkers, nil),
            ("Service Workers", info.supportsServiceWorkers, "Only in Safari or home screen web apps."),
            ("Shared Workers", info.supportsSharedWorkers, nil),
            ("WebGL", info.supportsWebGL, nil),
            ("WebGL 2", info.supportsWebGL2, nil),
            ("Web Audio", info.supportsWebAudio, nil),
            ("Media Devices", info.supportsMediaDevices, "Requires camera & microphone permission."),
            ("Media Recorder", info.supportsMediaRecorder, "Supports MP4 format only."),
            ("Media Source", info.supportsMediaSource, "iOS 17+ only."),
            ("Picture in Picture", info.supportsPictureInPicture, nil),
            ("Fullscreen", info.supportsFullscreen, "Video only on iPhone, full support on iPad."),
            ("Cookies", info.cookiesEnabled, nil),
            ("LocalStorage", info.supportsLocalStorage, "5MB limit per website."),
            ("SessionStorage", info.supportsSessionStorage, nil),
            ("IndexedDB", info.supportsIndexedDB, "Data may be cleared after 7 days of inactivity."),
            ("Cache API", info.supportsCacheAPI, "Data may be cleared after 7 days of inactivity."),
            ("Online", info.isOnline, nil),
            ("WebSocket", info.supportsWebSocket, nil),
            ("WebRTC", info.supportsWebRTC, "Requires camera & microphone permission."),
            ("Fetch", info.supportsFetch, nil),
            ("Beacon", info.supportsBeacon, nil),
            ("Event Source", info.supportsEventSource, "Real-time server updates."),
            ("Geolocation", info.supportsGeolocation, "Requires location permission."),
            ("Device Orientation", info.supportsDeviceOrientation, nil),
            ("Device Motion", info.supportsDeviceMotion, nil),
            ("Vibration", info.supportsVibration, "Not supported on iOS."),
            ("Battery", info.supportsBattery, "Not supported for privacy."),
            ("Bluetooth", info.supportsBluetooth, "Use native app instead."),
            ("USB", info.supportsUSB, "Use native app instead."),
            ("NFC", info.supportsNFC, "Use native app instead."),
            ("Clipboard", info.supportsClipboard, "Requires user interaction."),
            ("Web Share", info.supportsWebShare, "Requires HTTPS and user gesture. Safari only."),
            ("Notifications", info.supportsNotifications, "Only in Safari or home screen web apps."),
            ("Pointer Events", info.supportsPointerEvents, nil),
            ("Touch Events", info.supportsTouchEvents, nil),
            ("Gamepad", info.supportsGamepad, "Works with MFi controllers."),
            ("Drag and Drop", info.supportsDragDrop, "Full support on iPad only."),
            ("Intersection Observer", info.supportsIntersectionObserver, nil),
            ("Resize Observer", info.supportsResizeObserver, nil),
            ("Mutation Observer", info.supportsMutationObserver, nil),
            ("Performance Observer", info.supportsPerformanceObserver, nil),
            ("Crypto", info.supportsCrypto, "Requires HTTPS."),
            ("Credentials", info.supportsCredentials, nil),
            ("Payment Request", info.supportsPaymentRequest, "Apple Pay integration. Requires HTTPS.")
        ]
        return apis.map { label, supported, infoText in
            InfoSearchItem(category: "API", label: label, value: supported ? "Supported" : "Not Supported", info: infoText)
        }
    }

    private func codecItems(from info: MediaCodecInfo) -> [InfoSearchItem] {
        var items: [InfoSearchItem] = []

        let videoCodecs: [(String, CodecSupport)] = [
            ("H.264 (AVC)", info.h264),
            ("H.265 (HEVC)", info.hevc),
            ("VP8", info.vp8),
            ("VP9", info.vp9),
            ("AV1", info.av1),
            ("Theora", info.theora)
        ]
        for (label, support) in videoCodecs {
            items.append(InfoSearchItem(category: "Video Codecs", label: label, value: support.displayValue))
        }

        let audioCodecs: [(String, CodecSupport)] = [
            ("AAC", info.aac),
            ("MP3", info.mp3),
            ("Opus", info.opus),
            ("Vorbis", info.vorbis),
            ("FLAC", info.flac),
            ("WAV (PCM)", info.wav)
        ]
        for (label, support) in audioCodecs {
            items.append(InfoSearchItem(category: "Audio Codecs", label: label, value: support.displayValue))
        }

        let containers: [(String, CodecSupport)] = [
            ("MP4", info.mp4),
            ("WebM", info.webm),
            ("Ogg", info.ogg),
            ("HLS", info.hls)
        ]
        for (label, support) in containers {
            items.append(InfoSearchItem(category: "Containers", label: label, value: support.displayValue))
        }

        return items
    }

    private func displayItems(from info: DisplayInfo) -> [InfoSearchItem] {
        [
            InfoSearchItem(category: "Display", label: "Screen Width", value: info.screenWidth),
            InfoSearchItem(category: "Display", label: "Screen Height", value: info.screenHeight),
            InfoSearchItem(category: "Display", label: "Available Width", value: info.availWidth),
            InfoSearchItem(category: "Display", label: "Available Height", value: info.availHeight),
            InfoSearchItem(category: "Display", label: "Device Pixel Ratio", value: info.devicePixelRatio),
            InfoSearchItem(category: "Display", label: "Orientation", value: info.orientation),
            InfoSearchItem(category: "Display", label: "Color Depth", value: info.colorDepth),
            InfoSearchItem(category: "Display", label: "Pixel Depth", value: info.pixelDepth),
            InfoSearchItem(category: "Display", label: "sRGB", value: info.supportsSRGB ? "Supported" : "Not Supported"),
            InfoSearchItem(category: "Display", label: "Display P3", value: info.supportsP3 ? "Supported" : "Not Supported"),
            InfoSearchItem(category: "Display", label: "Rec.2020", value: info.supportsRec2020 ? "Supported" : "Not Supported"),
            InfoSearchItem(category: "Display", label: "HDR", value: info.supportsHDR ? "Supported" : "Not Supported"),
            InfoSearchItem(category: "Display", label: "Dynamic Range", value: info.dynamicRange),
            InfoSearchItem(category: "Display", label: "Color Scheme", value: info.colorScheme),
            InfoSearchItem(category: "Display", label: "Inverted Colors", value: info.invertedColors ? "Yes" : "No"),
            InfoSearchItem(category: "Display", label: "Forced Colors", value: info.forcedColors ? "Yes" : "No")
        ]
    }

    private func accessibilityItems(from info: AccessibilityInfo) -> [InfoSearchItem] {
        [
            InfoSearchItem(category: "Accessibility", label: "Reduced Motion", value: info.reducedMotion),
            InfoSearchItem(category: "Accessibility", label: "Reduced Transparency", value: info.reducedTransparency),
            InfoSearchItem(category: "Accessibility", label: "Contrast", value: info.contrast),
            InfoSearchItem(category: "Accessibility", label: "Color Scheme", value: info.colorScheme),
            InfoSearchItem(category: "Accessibility", label: "Reduced Data", value: info.reducedData),
            InfoSearchItem(category: "Accessibility", label: "Prefers Reduced Data", value: info.prefersReducedData),
            InfoSearchItem(category: "Accessibility", label: "Inverted Colors", value: info.invertedColors),
            InfoSearchItem(category: "Accessibility", label: "Forced Colors", value: info.forcedColors),
            InfoSearchItem(category: "Accessibility", label: "Color Gamut", value: info.colorGamut),
            InfoSearchItem(category: "Accessibility", label: "Pointer Type", value: info.pointerType),
            InfoSearchItem(category: "Accessibility", label: "Any Pointer", value: info.anyPointer),
            InfoSearchItem(category: "Accessibility", label: "Hover", value: info.hover),
            InfoSearchItem(category: "Accessibility", label: "Any Hover", value: info.anyHover)
        ]
    }

    private var performanceItems: [InfoSearchItem] {
        let perfPlaceholder = "Run benchmark"
        return [
            InfoSearchItem(category: "Performance", label: "Math", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "Array", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "String", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "Object", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "RegExp", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "DOM Create", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "DOM Query", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "DOM Modify", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "Canvas 2D", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "WebGL", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "Memory Allocation", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "Memory Operations", value: perfPlaceholder, linkToPerformance: true),
            InfoSearchItem(category: "Performance", label: "Crypto Hash", value: perfPlaceholder, linkToPerformance: true)
        ]
    }
}
