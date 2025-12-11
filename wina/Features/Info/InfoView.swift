//
//  InfoView.swift
//  wina
//

import Metal
import SwiftUI
import WebKit

struct InfoView: View {
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
    @AppStorage("allowZoom") private var allowZoom: Bool = true
    @AppStorage("minimumFontSize") private var minimumFontSize: Double = 0
    @AppStorage("mediaAutoplay") private var mediaAutoplay: Bool = false
    @AppStorage("inlineMediaPlayback") private var inlineMediaPlayback: Bool = true
    @AppStorage("allowsAirPlay") private var allowsAirPlay: Bool = true
    @AppStorage("allowsPictureInPicture") private var allowsPictureInPicture: Bool = true
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = true
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

    private var contentModeText: String {
        switch preferredContentMode {
        case 1: return "Mobile"
        case 2: return "Desktop"
        default: return "Recommended"
        }
    }

    private var activeDataDetectors: String {
        var detectors: [String] = []
        if detectPhoneNumbers { detectors.append("Phone") }
        if detectLinks { detectors.append("Links") }
        if detectAddresses { detectors.append("Address") }
        if detectCalendarEvents { detectors.append("Calendar") }
        return detectors.isEmpty ? "None" : detectors.joined(separator: ", ")
    }

    private var allItems: [InfoSearchItem] {
        var items: [InfoSearchItem] = []

        // Active Settings (always available)
        items.append(contentsOf: [
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
            InfoSearchItem(category: "Active Settings", label: "Custom User-Agent", value: customUserAgent.isEmpty ? "Default" : "Custom")
        ])

        // Device items
        if let info = deviceInfo {
            items.append(contentsOf: [
                InfoSearchItem(category: "Device", label: "Model", value: info.model),
                InfoSearchItem(category: "Device", label: "Model Identifier", value: info.modelIdentifier),
                InfoSearchItem(category: "Device", label: "System", value: "\(info.systemName) \(info.systemVersion)"),
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
            ])
        }

        // Browser & API items from WebViewInfo
        if let info = webViewInfo {
            // Browser
            items.append(contentsOf: [
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
            ])

            // API Capabilities
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
            for (label, supported, infoText) in apis {
                items.append(InfoSearchItem(category: "API", label: label, value: supported ? "Supported" : "Not Supported", info: infoText))
            }
        }

        // Media Codecs
        if let info = codecInfo {
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
        }

        // Display
        if let info = displayInfo {
            items.append(contentsOf: [
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
            ])
        }

        // Accessibility
        if let info = accessibilityInfo {
            items.append(contentsOf: [
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
            ])
        }

        // Performance (items only, values require benchmark execution)
        let perfPlaceholder = "Run benchmark"
        items.append(contentsOf: [
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
        ])

        return items
    }

    private var filteredItems: [String: [InfoSearchItem]] {
        let filtered = searchText.isEmpty ? allItems : allItems.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
            $0.value.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: filtered, by: { $0.category })
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    // Search results view
                    List {
                        ForEach(filteredItems.keys.sorted(), id: \.self) { category in
                            Section(category) {
                                ForEach(filteredItems[category] ?? []) { item in
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
                            }
                        }
                    }
                    .overlay {
                        if filteredItems.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                } else {
                    // Default menu view
                    List {
                        Section {
                            NavigationLink {
                                ActiveSettingsView(showSettings: $showSettings)
                            } label: {
                                Label("Active Settings", systemImage: "slider.horizontal.3")
                            }
                        } header: {
                            Text("Current Configuration")
                        }

                        Section {
                            NavigationLink {
                                DeviceInfoView()
                            } label: {
                                Label("Device", systemImage: "iphone")
                            }

                            NavigationLink {
                                BrowserInfoView()
                            } label: {
                                Label("Browser", systemImage: "safari")
                            }

                            NavigationLink {
                                APICapabilitiesView()
                            } label: {
                                Label("API Capabilities", systemImage: "checklist")
                            }

                            NavigationLink {
                                MediaCodecsView()
                            } label: {
                                Label("Media Codecs", systemImage: "play.rectangle")
                            }

                            NavigationLink {
                                PerformanceView()
                            } label: {
                                Label("Performance", systemImage: "gauge.with.needle")
                            }

                            NavigationLink {
                                DisplayFeaturesView()
                            } label: {
                                Label("Display", systemImage: "sparkles.rectangle.stack")
                            }

                            NavigationLink {
                                AccessibilityFeaturesView()
                            } label: {
                                Label("Accessibility", systemImage: "accessibility")
                            }
                        } header: {
                            Text("WebView Capabilities")
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all info")
            .navigationTitle("WKWebView Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            deviceInfo = await DeviceInfo.load()
            webViewInfo = await WebViewInfo.load { status in
                loadingStatus = status
            }
            async let codec = MediaCodecInfo.load { _ in }
            async let display = DisplayInfo.load { _ in }
            async let accessibility = AccessibilityInfo.load { _ in }

            codecInfo = await codec
            displayInfo = await display
            accessibilityInfo = await accessibility
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Info Search Item

private struct InfoSearchItem: Identifiable {
    let id = UUID()
    let category: String
    let label: String
    let value: String
    var info: String?
    var linkToPerformance: Bool = false
}

// MARK: - Device Information

struct DeviceInfoView: View {
    @State private var deviceInfo: DeviceInfo?

    var body: some View {
        List {
            if let info = deviceInfo {
                Section("Hardware") {
                    InfoRow(label: "Model", value: info.model)
                    InfoRow(label: "Model Identifier", value: info.modelIdentifier)
                    InfoRow(label: "System Name", value: info.systemName)
                    InfoRow(label: "System Version", value: info.systemVersion)
                }

                Section("Processor") {
                    InfoRow(label: "CPU Cores", value: info.cpuCores, info: "Total logical cores.\niPhone uses ARM big.LITTLE:\nPerformance + Efficiency cores.")
                    InfoRow(label: "Active Cores", value: info.activeCores, info: "Currently active cores.\nMay throttle based on:\nThermal state, Low Power Mode.")
                    InfoRow(label: "GPU", value: info.gpuName, info: "Apple GPU integrated in SoC.\nMetal API supported.\nShared memory with CPU.")
                }

                Section("Memory & Power") {
                    InfoRow(label: "Physical Memory", value: info.physicalMemory, info: "Total device RAM.\nShared between system and apps.\niPhone: 4-8GB typically.")
                    InfoRow(label: "Thermal State", value: info.thermalState, info: "Nominal: Normal operation\nFair: Slightly warm\nSerious: Performance throttled\nCritical: Aggressive throttling")
                    CapabilityRow(label: "Low Power Mode", supported: info.isLowPowerMode, info: "Settings > Battery toggle.\nReduces CPU/GPU performance.\nDisables background refresh.")
                }

                Section("Display") {
                    InfoRow(label: "Screen Size", value: info.screenSize, info: "Logical size in points.\n1 point = 2-3 pixels depending on device.")
                    InfoRow(label: "Screen Scale", value: info.screenScale, info: "Points to pixels ratio.\n@2x = Retina, @3x = Super Retina.")
                    InfoRow(label: "Native Scale", value: info.nativeScale, info: "Physical pixel density.\nMay differ from Screen Scale\non some devices.")
                    InfoRow(label: "Brightness", value: info.brightness, info: "Current screen brightness.\n0.0 (min) to 1.0 (max).\nUser or auto-brightness controlled.")
                }

                Section("Locale") {
                    InfoRow(label: "Language", value: info.language)
                    InfoRow(label: "Region", value: info.region)
                    InfoRow(label: "Timezone", value: info.timezone)
                }

                Section("Network") {
                    InfoRow(label: "Host Name", value: info.hostName)
                }
            }
        }
        .overlay {
            if deviceInfo == nil {
                ProgressView()
            }
        }
        .navigationTitle("Device Information")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            deviceInfo = await DeviceInfo.load()
        }
    }
}

// MARK: - Browser Information

struct BrowserInfoView: View {
    @State private var webViewInfo: WebViewInfo?
    @State private var loadingStatus = "Launching WebView process..."

    var body: some View {
        List {
            if let info = webViewInfo {
                Section("Browser") {
                    InfoRow(label: "Type", value: info.browserType)
                    InfoRow(label: "Vendor", value: info.vendor)
                    InfoRow(label: "Platform", value: info.platform)
                    InfoRow(label: "Language", value: info.language)
                    InfoRow(label: "Languages", value: info.languages)
                }

                Section("Engine") {
                    InfoRow(label: "WebKit Version", value: info.webKitVersion, info: "Safari's rendering engine.\nShared across all iOS browsers.\nUpdated with iOS releases.")
                    InfoRow(label: "JavaScript Core", value: info.jsCoreVersion, info: "Apple's JS engine (Nitro).\nJIT compilation for speed.\nSame engine as Safari.")
                }

                Section("User Agent") {
                    UserAgentText(userAgent: info.userAgent)
                }

                Section("WebGL") {
                    InfoRow(label: "Renderer", value: info.webGLRenderer)
                    InfoRow(label: "Vendor", value: info.webGLVendor)
                    InfoRow(label: "Version", value: info.webGLVersion)
                }

                Section("Input") {
                    InfoRow(label: "Max Touch Points", value: info.maxTouchPoints, info: "Max simultaneous touches.\niPhone/iPad: Usually 5.\nAffects multi-touch gestures.")
                }
            }
        }
        .overlay {
            if webViewInfo == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Browser")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            webViewInfo = await WebViewInfo.load { status in
                loadingStatus = status
            }
        }
    }
}

// MARK: - API Capabilities

struct APICapabilitiesView: View {
    @State private var webViewInfo: WebViewInfo?
    @State private var loadingStatus = "Launching WebView process..."

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var capabilities: [CapabilitySection] {
        guard let info = webViewInfo else { return [] }
        return [
            CapabilitySection(name: "Core APIs", items: [
                CapabilityItem(label: "JavaScript", supported: info.supportsJavaScript),
                CapabilityItem(label: "WebAssembly", supported: info.supportsWebAssembly),
                CapabilityItem(label: "Web Workers", supported: info.supportsWebWorkers),
                CapabilityItem(label: "Service Workers", supported: info.supportsServiceWorkers, info: "Background scripts for offline.\nOnly in Safari or home screen apps.\nNot available in embedded browsers.", unavailable: true),
                CapabilityItem(label: "Shared Workers", supported: info.supportsSharedWorkers)
            ]),
            CapabilitySection(name: "Graphics & Media", items: [
                CapabilityItem(label: "WebGL", supported: info.supportsWebGL),
                CapabilityItem(label: "WebGL 2", supported: info.supportsWebGL2),
                CapabilityItem(label: "Web Audio", supported: info.supportsWebAudio),
                CapabilityItem(label: "Media Devices", supported: info.supportsMediaDevices, info: "Camera and microphone access.\nRequires user permission.\nUsed for video calls, recording."),
                CapabilityItem(label: "Media Recorder", supported: info.supportsMediaRecorder, info: "Record audio/video streams.\niOS: MP4/H.264 only.\nWebM/VP8 not supported."),
                CapabilityItem(label: "Media Source", supported: info.supportsMediaSource, info: "MSE for adaptive streaming.\niOS 17+: ManagedMediaSource.\nOlder iOS: Not supported."),
                CapabilityItem(label: "Picture in Picture", supported: info.supportsPictureInPicture, info: "Video plays in floating window.\nWorks on video elements.\nUser must initiate."),
                CapabilityItem(label: "Fullscreen", supported: info.supportsFullscreen, info: isIPad ? "iPad: Full support.\nAny element can go fullscreen.\nVideos, games, presentations." : "iPhone: Not supported.\nOnly videos can go fullscreen.\niPad has full API support.", unavailable: !isIPad)
            ]),
            CapabilitySection(name: "Storage", items: [
                CapabilityItem(label: "Cookies", supported: info.cookiesEnabled, info: "Website cookies enabled.\nStores login sessions, preferences.\nPrivate mode clears on exit."),
                CapabilityItem(label: "LocalStorage", supported: info.supportsLocalStorage, info: "Persistent key-value storage.\n~5MB limit per website.\nSurvives browser restart."),
                CapabilityItem(label: "SessionStorage", supported: info.supportsSessionStorage, info: "Tab-scoped storage.\nCleared when tab closes.\nSame origin policy applies."),
                CapabilityItem(label: "IndexedDB", supported: info.supportsIndexedDB, info: "Client-side database.\nData may clear after 7 days idle.\nLarger storage than LocalStorage."),
                CapabilityItem(label: "Cache API", supported: info.supportsCacheAPI, info: "Service Worker cache storage.\nData may clear after 7 days idle.\nGood for offline resources.")
            ]),
            CapabilitySection(name: "Network", items: [
                CapabilityItem(label: "Online", supported: info.isOnline, info: "navigator.onLine status.\nDevice network connectivity.\nMay not reflect actual internet."),
                CapabilityItem(label: "WebSocket", supported: info.supportsWebSocket, info: "Full-duplex communication.\nPersistent connection to server.\nGood for real-time apps."),
                CapabilityItem(label: "WebRTC", supported: info.supportsWebRTC, info: "Peer-to-peer communication.\nNeeds camera/mic permissions.\nVideo calls, screen sharing."),
                CapabilityItem(label: "Fetch", supported: info.supportsFetch, info: "Modern HTTP requests API.\nPromise-based, replaces XHR.\nSupports streaming."),
                CapabilityItem(label: "Beacon", supported: info.supportsBeacon, info: "Send data on page unload.\nGuaranteed delivery attempt.\nGood for analytics."),
                CapabilityItem(label: "Event Source", supported: info.supportsEventSource, info: "Server-Sent Events (SSE).\nOne-way server → client.\nAuto-reconnection built-in.")
            ]),
            CapabilitySection(name: "Device APIs", items: [
                CapabilityItem(label: "Geolocation", supported: info.supportsGeolocation, info: "GPS/network location access.\nRequires user permission.\nUsed for maps, local search."),
                CapabilityItem(label: "Device Orientation", supported: info.supportsDeviceOrientation, info: "Gyroscope data access.\nalpha/beta/gamma rotation.\niOS 13+: User permission needed."),
                CapabilityItem(label: "Device Motion", supported: info.supportsDeviceMotion, info: "Accelerometer data access.\naccelerationIncludingGravity.\niOS 13+: User permission needed."),
                CapabilityItem(label: "Vibration", supported: info.supportsVibration, info: "Haptic feedback from websites.\niOS: Not supported for privacy.\nNative apps can use haptics.", unavailable: true),
                CapabilityItem(label: "Battery", supported: info.supportsBattery, info: "Battery level info for websites.\niOS: Not supported for privacy.\nPrevents device fingerprinting.", unavailable: true),
                CapabilityItem(label: "Bluetooth", supported: info.supportsBluetooth, info: "Connect Bluetooth devices.\niOS: Not supported in browsers.\nUse native apps instead.", unavailable: true),
                CapabilityItem(label: "USB", supported: info.supportsUSB, info: "Connect USB devices.\niOS: Not supported in browsers.\nUse native apps instead.", unavailable: true),
                CapabilityItem(label: "NFC", supported: info.supportsNFC, info: "Read/write NFC tags.\niOS: Not supported in browsers.\nUse native apps instead.", unavailable: true)
            ]),
            CapabilitySection(name: "UI & Interaction", items: [
                CapabilityItem(label: "Clipboard", supported: info.supportsClipboard, info: "Async clipboard API.\nNeeds user gesture to write.\nRead may need permission."),
                CapabilityItem(label: "Web Share", supported: info.supportsWebShare, info: "Native iOS share sheet.\nOnly in Safari browser.\nShare links, text, files.", unavailable: true),
                CapabilityItem(label: "Notifications", supported: info.supportsNotifications, info: "Push notifications from websites.\nOnly in Safari or home screen apps.\niOS 16.4+ required.", unavailable: true),
                CapabilityItem(label: "Pointer Events", supported: info.supportsPointerEvents, info: "Unified input events.\nMouse, touch, pen combined.\nModern event handling."),
                CapabilityItem(label: "Touch Events", supported: info.supportsTouchEvents, info: "Multi-touch support.\ntouchstart/move/end events.\niOS native touch handling."),
                CapabilityItem(label: "Gamepad", supported: info.supportsGamepad, info: "Game controller input.\nMFi controllers supported.\nPS/Xbox may work too."),
                CapabilityItem(label: "Drag and Drop", supported: info.supportsDragDrop, info: isIPad ? "iPad: Full drag/drop support.\nBetween apps, within app.\nSplit View compatible." : "iPhone: Limited support.\nGesture conflicts with scroll.\niPad recommended.", unavailable: !isIPad)
            ]),
            CapabilitySection(name: "Observers", items: [
                CapabilityItem(label: "Intersection Observer", supported: info.supportsIntersectionObserver, info: "Element visibility detection.\nLazy loading, infinite scroll.\nPerformant scroll handling."),
                CapabilityItem(label: "Resize Observer", supported: info.supportsResizeObserver, info: "Element size changes.\nResponsive components.\nBetter than window.resize."),
                CapabilityItem(label: "Mutation Observer", supported: info.supportsMutationObserver, info: "DOM change detection.\nReplaces Mutation Events.\nAttribute, child, subtree."),
                CapabilityItem(label: "Performance Observer", supported: info.supportsPerformanceObserver, info: "Performance metrics.\nLCP, FID, CLS measurement.\nReal user monitoring.")
            ]),
            CapabilitySection(name: "Security & Payments", items: [
                CapabilityItem(label: "Crypto", supported: info.supportsCrypto, info: "Web Cryptography API.\nHashing, encryption, signing.\nHTTPS required for full API."),
                CapabilityItem(label: "Credentials", supported: info.supportsCredentials, info: "Credential Management API.\nPasswords, federated login.\nLimited iOS support."),
                CapabilityItem(label: "Payment Request", supported: info.supportsPaymentRequest, info: "Standardized checkout API.\nApple Pay integration.\nHTTPS + merchant setup needed.")
            ])
        ]
    }

    var body: some View {
        List {
            ForEach(capabilities) { section in
                Section(section.name) {
                    ForEach(section.items) { item in
                        CapabilityRow(label: item.label, supported: item.supported, info: item.info, unavailable: item.unavailable)
                    }
                }
            }
        }
        .overlay {
            if webViewInfo == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("API Capabilities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            webViewInfo = await WebViewInfo.load { status in
                loadingStatus = status
            }
        }
    }
}

// MARK: - Capability Data Models

private struct CapabilitySection: Identifiable {
    let id = UUID()
    let name: String
    let items: [CapabilityItem]
}

private struct CapabilityItem: Identifiable {
    let id = UUID()
    let label: String
    let supported: Bool
    var info: String?
    var unavailable: Bool = false
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let label: String
    let value: String
    var info: String? = nil

    @State private var showingInfo = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            if let info {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tertiary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer()
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct CapabilityRow: View {
    let label: String
    let supported: Bool
    var info: String? = nil
    var unavailable: Bool = false  // WebKit policy: never supported

    @State private var showingInfo = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(unavailable ? .secondary : .primary)
            if let info {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer()
            if unavailable {
                Text("N/A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(supported ? .green : .red)
            }
        }
    }
}

private struct UserAgentText: View {
    let userAgent: String

    var body: some View {
        Text(formattedUserAgent)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
    }

    private var formattedUserAgent: AttributedString {

        // Pattern: key/value or parenthesized content
        let patterns: [(pattern: String, color: Color)] = [
            ("Mozilla/[\\d.]+", .blue),
            ("AppleWebKit/[\\d.]+", .orange),
            ("Version/[\\d.]+", .purple),
            ("Mobile/[\\w]+", .green),
            ("Safari/[\\d.]+", .pink),
            ("\\([^)]+\\)", .secondary),
        ]

        var text = userAgent

        // Add line breaks at major separators
        text = text.replacingOccurrences(of: ") ", with: ")\n")

        var attributed = AttributedString(text)

        for (pattern, color) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(text.startIndex..., in: text)
                for match in regex.matches(in: text, range: nsRange) {
                    if let range = Range(match.range, in: text),
                       let attrRange = Range(range, in: attributed)
                    {
                        attributed[attrRange].foregroundColor = color
                    }
                }
            }
        }

        return attributed
    }
}

// MARK: - Device Info Model

private struct DeviceInfo: Sendable {
    let model: String
    let modelIdentifier: String
    let systemName: String
    let systemVersion: String
    let cpuCores: String
    let activeCores: String
    let physicalMemory: String
    let thermalState: String
    let isLowPowerMode: Bool
    let gpuName: String
    let screenSize: String
    let screenScale: String
    let nativeScale: String
    let brightness: String
    let language: String
    let region: String
    let timezone: String
    let hostName: String

    @MainActor
    static func load() async -> DeviceInfo {
        let device = UIDevice.current
        let locale = Locale.current
        let processInfo = ProcessInfo.processInfo

        // Get screen from active window scene
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let screen = windowScene?.screen
        let traitCollection = windowScene?.traitCollection

        let gpuName = MTLCreateSystemDefaultDevice()?.name ?? "Unknown"

        let memoryGB = Double(processInfo.physicalMemory) / 1_073_741_824
        let memoryString = String(format: "%.1f GB", memoryGB)

        let thermalStateString: String = {
            switch processInfo.thermalState {
            case .nominal: return "Nominal"
            case .fair: return "Fair"
            case .serious: return "Serious"
            case .critical: return "Critical"
            @unknown default: return "Unknown"
            }
        }()

        let brightnessPercent = screen.map { Int($0.brightness * 100) } ?? 0
        let screenBounds = screen?.bounds ?? .zero
        let displayScale = traitCollection?.displayScale ?? 1.0

        return DeviceInfo(
            model: device.model,
            modelIdentifier: getModelIdentifier(),
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            cpuCores: "\(processInfo.processorCount)",
            activeCores: "\(processInfo.activeProcessorCount)",
            physicalMemory: memoryString,
            thermalState: thermalStateString,
            isLowPowerMode: processInfo.isLowPowerModeEnabled,
            gpuName: gpuName,
            screenSize: "\(Int(screenBounds.width)) x \(Int(screenBounds.height)) pt",
            screenScale: "\(displayScale)x",
            nativeScale: screen.map { "\($0.nativeScale)x" } ?? "Unknown",
            brightness: "\(brightnessPercent)%",
            language: locale.language.languageCode?.identifier ?? "Unknown",
            region: locale.region?.identifier ?? "Unknown",
            timezone: TimeZone.current.identifier,
            hostName: processInfo.hostName
        )
    }

    private static func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - WebView Info Model

private struct WebViewInfo: Sendable {
    // Browser
    let browserType: String
    let vendor: String
    let platform: String
    let language: String
    let languages: String

    // Engine
    let userAgent: String
    let webKitVersion: String
    let jsCoreVersion: String

    // Display
    let colorDepth: String

    // WebGL
    let webGLRenderer: String
    let webGLVendor: String
    let webGLVersion: String

    // Core APIs
    let supportsJavaScript: Bool
    let supportsWebAssembly: Bool
    let supportsWebWorkers: Bool
    let supportsServiceWorkers: Bool
    let supportsSharedWorkers: Bool

    // Graphics & Media
    let supportsWebGL: Bool
    let supportsWebGL2: Bool
    let supportsWebAudio: Bool
    let supportsMediaDevices: Bool
    let supportsMediaRecorder: Bool
    let supportsMediaSource: Bool
    let supportsPictureInPicture: Bool
    let supportsFullscreen: Bool

    // Storage
    let cookiesEnabled: Bool
    let supportsLocalStorage: Bool
    let supportsSessionStorage: Bool
    let supportsIndexedDB: Bool
    let supportsCacheAPI: Bool

    // Network
    let isOnline: Bool
    let supportsWebSocket: Bool
    let supportsWebRTC: Bool
    let supportsFetch: Bool
    let supportsBeacon: Bool
    let supportsEventSource: Bool

    // Device APIs
    let supportsGeolocation: Bool
    let supportsDeviceOrientation: Bool
    let supportsDeviceMotion: Bool
    let supportsVibration: Bool
    let supportsBattery: Bool
    let supportsBluetooth: Bool
    let supportsUSB: Bool
    let supportsNFC: Bool

    // UI & Interaction
    let supportsClipboard: Bool
    let supportsWebShare: Bool
    let supportsNotifications: Bool
    let supportsPointerEvents: Bool
    let supportsTouchEvents: Bool
    let supportsGamepad: Bool
    let supportsDragDrop: Bool

    // Observers
    let supportsIntersectionObserver: Bool
    let supportsResizeObserver: Bool
    let supportsMutationObserver: Bool
    let supportsPerformanceObserver: Bool

    // Security & Payments
    let supportsCrypto: Bool
    let supportsCredentials: Bool
    let supportsPaymentRequest: Bool

    // Input
    let maxTouchPoints: String

    @MainActor
    static func load(onStatusUpdate: @escaping (String) -> Void) async -> WebViewInfo {
        onStatusUpdate("Launching WebView process...")

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        // Load blank HTML and wait for actual load completion
        // Use a real URL as baseURL to enable localStorage/sessionStorage access
        onStatusUpdate("Initializing WebView...")
        await webView.loadHTMLStringAsync("<html><body></body></html>", baseURL: URL(string: "https://example.com"))

        // Get browser info
        onStatusUpdate("Detecting browser info...")
        let browserInfoScript = """
        (function() {
            return {
                userAgent: navigator.userAgent,
                vendor: navigator.vendor || 'Unknown',
                platform: navigator.platform || 'Unknown',
                language: navigator.language || 'Unknown',
                languages: (navigator.languages || []).join(', ') || 'Unknown',
                colorDepth: screen.colorDepth + ' bit',
                isOnline: navigator.onLine
            };
        })()
        """
        let browserInfo = await webView.evaluateJavaScriptAsync(browserInfoScript) as? [String: Any] ?? [:]

        let userAgent = browserInfo["userAgent"] as? String ?? "Unknown"
        let vendor = browserInfo["vendor"] as? String ?? "Unknown"
        let platform = browserInfo["platform"] as? String ?? "Unknown"
        let language = browserInfo["language"] as? String ?? "Unknown"
        let languages = browserInfo["languages"] as? String ?? "Unknown"
        let colorDepth = browserInfo["colorDepth"] as? String ?? "Unknown"
        let isOnline = browserInfo["isOnline"] as? Bool ?? false

        // Parse WebKit version from UA
        var webKitVersion = "Unknown"
        if let range = userAgent.range(of: "AppleWebKit/") {
            let start = range.upperBound
            if let end = userAgent[start...].firstIndex(of: " ") {
                webKitVersion = String(userAgent[start..<end])
            }
        }

        // Determine browser type
        let browserType = "WKWebView"

        // Check all capabilities
        onStatusUpdate("Checking capabilities...")
        let capabilitiesScript = """
        (function() {
            var isSecure = window.isSecureContext;
            return {
                // Core APIs
                javaScript: true,
                webAssembly: typeof WebAssembly !== 'undefined',
                webWorkers: (function() {
                    try {
                        var blob = new Blob([''], { type: 'application/javascript' });
                        var url = URL.createObjectURL(blob);
                        var worker = new Worker(url);
                        worker.terminate();
                        URL.revokeObjectURL(url);
                        return true;
                    } catch(e) { return false; }
                })(),
                serviceWorkers: 'serviceWorker' in navigator,
                sharedWorkers: typeof SharedWorker !== 'undefined',

                // Graphics & Media
                webGL: typeof WebGLRenderingContext !== 'undefined',
                webGL2: typeof WebGL2RenderingContext !== 'undefined',
                webAudio: typeof AudioContext !== 'undefined' || typeof webkitAudioContext !== 'undefined',
                mediaDevices: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia),
                mediaRecorder: typeof MediaRecorder !== 'undefined',
                mediaSource: typeof ManagedMediaSource !== 'undefined' || typeof MediaSource !== 'undefined',
                pictureInPicture: 'pictureInPictureEnabled' in document,
                fullscreen: !!document.documentElement.requestFullscreen || !!document.documentElement.webkitRequestFullscreen,

                // Storage - test actual read/write capability
                cookies: navigator.cookieEnabled,
                localStorage: (function() {
                    try {
                        var key = '__test__';
                        localStorage.setItem(key, '1');
                        localStorage.removeItem(key);
                        return true;
                    } catch(e) { return false; }
                })(),
                sessionStorage: (function() {
                    try {
                        var key = '__test__';
                        sessionStorage.setItem(key, '1');
                        sessionStorage.removeItem(key);
                        return true;
                    } catch(e) { return false; }
                })(),
                indexedDB: (function() {
                    try {
                        return typeof indexedDB !== 'undefined' && indexedDB !== null;
                    } catch(e) { return false; }
                })(),
                cacheAPI: (function() {
                    try {
                        return 'caches' in window && typeof caches.open === 'function';
                    } catch(e) { return false; }
                })(),

                // Network
                webSocket: typeof WebSocket !== 'undefined',
                webRTC: typeof RTCPeerConnection !== 'undefined',
                fetch: typeof fetch !== 'undefined',
                beacon: 'sendBeacon' in navigator,
                eventSource: typeof EventSource !== 'undefined',

                // Device APIs
                geolocation: 'geolocation' in navigator,
                deviceOrientation: 'DeviceOrientationEvent' in window,
                deviceMotion: 'DeviceMotionEvent' in window,
                vibration: 'vibrate' in navigator,
                battery: 'getBattery' in navigator,
                bluetooth: 'bluetooth' in navigator,
                usb: 'usb' in navigator,
                nfc: 'NDEFReader' in window,

                // UI & Interaction
                clipboard: (function() {
                    if (navigator.clipboard && navigator.clipboard.writeText) return true;
                    return document.queryCommandSupported && document.queryCommandSupported('copy');
                })(),
                webShare: 'share' in navigator,
                notifications: 'Notification' in window && Notification.permission !== 'denied',
                pointerEvents: 'PointerEvent' in window,
                touchEvents: 'ontouchstart' in window,
                gamepad: 'getGamepads' in navigator,
                dragDrop: 'draggable' in document.createElement('div'),

                // Observers
                intersectionObserver: typeof IntersectionObserver !== 'undefined',
                resizeObserver: typeof ResizeObserver !== 'undefined',
                mutationObserver: typeof MutationObserver !== 'undefined',
                performanceObserver: typeof PerformanceObserver !== 'undefined',

                // Security & Payments (require secure context)
                crypto: isSecure && !!(window.crypto && window.crypto.subtle),
                credentials: isSecure && 'credentials' in navigator,
                paymentRequest: isSecure && typeof PaymentRequest !== 'undefined'
            };
        })()
        """
        let caps = await webView.evaluateJavaScriptAsync(capabilitiesScript) as? [String: Bool] ?? [:]

        // Get WebGL info
        onStatusUpdate("Detecting WebGL renderer...")
        let webGLScript = """
        (function() {
            var canvas = document.createElement('canvas');
            var gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
            if (!gl) return { renderer: 'N/A', vendor: 'N/A', version: 'N/A' };
            var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
            return {
                renderer: debugInfo ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
                vendor: debugInfo ? gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR),
                version: gl.getParameter(gl.VERSION)
            };
        })()
        """
        let webGLInfo = await webView.evaluateJavaScriptAsync(webGLScript) as? [String: String] ?? [:]
        let webGLRenderer = webGLInfo["renderer"] ?? "N/A"
        let webGLVendor = webGLInfo["vendor"] ?? "N/A"
        let webGLVersion = webGLInfo["version"] ?? "N/A"

        // Get touch points
        let maxTouchPoints = await webView.evaluateJavaScriptAsync("navigator.maxTouchPoints") as? Int ?? 0

        return WebViewInfo(
            browserType: browserType,
            vendor: vendor,
            platform: platform,
            language: language,
            languages: languages,
            userAgent: userAgent,
            webKitVersion: webKitVersion,
            jsCoreVersion: "JavaScriptCore \(UIDevice.current.systemVersion)",
            colorDepth: colorDepth,
            webGLRenderer: webGLRenderer,
            webGLVendor: webGLVendor,
            webGLVersion: webGLVersion,
            // Core APIs
            supportsJavaScript: caps["javaScript"] ?? false,
            supportsWebAssembly: caps["webAssembly"] ?? false,
            supportsWebWorkers: caps["webWorkers"] ?? false,
            supportsServiceWorkers: caps["serviceWorkers"] ?? false,
            supportsSharedWorkers: caps["sharedWorkers"] ?? false,
            // Graphics & Media
            supportsWebGL: caps["webGL"] ?? false,
            supportsWebGL2: caps["webGL2"] ?? false,
            supportsWebAudio: caps["webAudio"] ?? false,
            supportsMediaDevices: caps["mediaDevices"] ?? false,
            supportsMediaRecorder: caps["mediaRecorder"] ?? false,
            supportsMediaSource: caps["mediaSource"] ?? false,
            supportsPictureInPicture: caps["pictureInPicture"] ?? false,
            supportsFullscreen: caps["fullscreen"] ?? false,
            // Storage
            cookiesEnabled: caps["cookies"] ?? false,
            supportsLocalStorage: caps["localStorage"] ?? false,
            supportsSessionStorage: caps["sessionStorage"] ?? false,
            supportsIndexedDB: caps["indexedDB"] ?? false,
            supportsCacheAPI: caps["cacheAPI"] ?? false,
            // Network
            isOnline: isOnline,
            supportsWebSocket: caps["webSocket"] ?? false,
            supportsWebRTC: caps["webRTC"] ?? false,
            supportsFetch: caps["fetch"] ?? false,
            supportsBeacon: caps["beacon"] ?? false,
            supportsEventSource: caps["eventSource"] ?? false,
            // Device APIs
            supportsGeolocation: caps["geolocation"] ?? false,
            supportsDeviceOrientation: caps["deviceOrientation"] ?? false,
            supportsDeviceMotion: caps["deviceMotion"] ?? false,
            supportsVibration: caps["vibration"] ?? false,
            supportsBattery: caps["battery"] ?? false,
            supportsBluetooth: caps["bluetooth"] ?? false,
            supportsUSB: caps["usb"] ?? false,
            supportsNFC: caps["nfc"] ?? false,
            // UI & Interaction
            supportsClipboard: caps["clipboard"] ?? false,
            supportsWebShare: caps["webShare"] ?? false,
            supportsNotifications: caps["notifications"] ?? false,
            supportsPointerEvents: caps["pointerEvents"] ?? false,
            supportsTouchEvents: caps["touchEvents"] ?? false,
            supportsGamepad: caps["gamepad"] ?? false,
            supportsDragDrop: caps["dragDrop"] ?? false,
            // Observers
            supportsIntersectionObserver: caps["intersectionObserver"] ?? false,
            supportsResizeObserver: caps["resizeObserver"] ?? false,
            supportsMutationObserver: caps["mutationObserver"] ?? false,
            supportsPerformanceObserver: caps["performanceObserver"] ?? false,
            // Security & Payments
            supportsCrypto: caps["crypto"] ?? false,
            supportsCredentials: caps["credentials"] ?? false,
            supportsPaymentRequest: caps["paymentRequest"] ?? false,
            // Input
            maxTouchPoints: "\(maxTouchPoints)"
        )
    }

    private static func checkFeature(_ webView: WKWebView, _ script: String) async -> Bool {
        let result = await webView.evaluateJavaScriptAsync(script)
        return (result as? Bool) ?? false
    }
}

extension WKWebView {
    func evaluateJavaScriptAsync(_ script: String) async -> Any? {
        await withCheckedContinuation { continuation in
            evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("[WKWebView] JavaScript error: \(error.localizedDescription)")
                }
                continuation.resume(returning: result)
            }
        }
    }

    @MainActor
    func loadHTMLStringAsync(_ string: String, baseURL: URL?) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let delegate = WebViewLoadDelegate {
                continuation.resume()
            }
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(self, &WebViewLoadDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            self.navigationDelegate = delegate
            self.loadHTMLString(string, baseURL: baseURL)
        }
    }
}

private class WebViewLoadDelegate: NSObject, WKNavigationDelegate {
    static var associatedKey: UInt8 = 0
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completion()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion()
    }
}

// MARK: - Media Codecs

struct MediaCodecsView: View {
    @State private var codecInfo: MediaCodecInfo?
    @State private var loadingStatus = "Launching WebView process..."

    var body: some View {
        List {
            Section {
                Text("Codec support may vary depending on device and OS version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .listSectionSpacing(0)

            if let info = codecInfo {
                Section("Video Codecs") {
                    CodecRow(label: "H.264 (AVC)", support: info.h264)
                    CodecRow(label: "H.265 (HEVC)", support: info.hevc)
                    CodecRow(label: "VP8", support: info.vp8)
                    CodecRow(label: "VP9", support: info.vp9)
                    CodecRow(label: "AV1", support: info.av1)
                    CodecRow(label: "Theora", support: info.theora)
                }

                Section("Audio Codecs") {
                    CodecRow(label: "AAC", support: info.aac)
                    CodecRow(label: "MP3", support: info.mp3)
                    CodecRow(label: "Opus", support: info.opus)
                    CodecRow(label: "Vorbis", support: info.vorbis)
                    CodecRow(label: "FLAC", support: info.flac)
                    CodecRow(label: "WAV (PCM)", support: info.wav)
                }

                Section("Containers") {
                    CodecRow(label: "MP4", support: info.mp4)
                    CodecRow(label: "WebM", support: info.webm)
                    CodecRow(label: "Ogg", support: info.ogg)
                    CodecRow(label: "HLS (m3u8)", support: info.hls)
                }

                Section("Media Capabilities API") {
                    CapabilityRow(label: "MediaCapabilities", supported: info.supportsMediaCapabilities)
                    CapabilityRow(
                        label: "MediaSource Extensions",
                        supported: false,
                        info: "API for adaptive streaming (e.g., DASH). Not supported in WKWebView.",
                        unavailable: true
                    )
                    CapabilityRow(label: "Encrypted Media", supported: info.supportsEME)
                }
            }
        }
        .overlay {
            if codecInfo == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Media Codecs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            codecInfo = await MediaCodecInfo.load { status in
                loadingStatus = status
            }
        }
    }
}

private struct CodecRow: View {
    let label: String
    let support: CodecSupport

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: support.icon)
                .foregroundStyle(support.color)
        }
    }
}

enum CodecSupport: String {
    case probably = "probably"
    case maybe = "maybe"
    case none = ""

    var icon: String {
        switch self {
        case .probably: return "checkmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .none: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .probably: return .green
        case .maybe: return .orange
        case .none: return .red
        }
    }

    var displayValue: String {
        switch self {
        case .probably: return "Supported"
        case .maybe: return "Maybe"
        case .none: return "Not Supported"
        }
    }
}

private struct MediaCodecInfo: Sendable {
    // Video
    let h264: CodecSupport
    let hevc: CodecSupport
    let vp8: CodecSupport
    let vp9: CodecSupport
    let av1: CodecSupport
    let theora: CodecSupport

    // Audio
    let aac: CodecSupport
    let mp3: CodecSupport
    let opus: CodecSupport
    let vorbis: CodecSupport
    let flac: CodecSupport
    let wav: CodecSupport

    // Containers
    let mp4: CodecSupport
    let webm: CodecSupport
    let ogg: CodecSupport
    let hls: CodecSupport

    // APIs
    let supportsMediaCapabilities: Bool
    let supportsMSE: Bool
    let supportsEME: Bool

    @MainActor
    static func load(onStatusUpdate: @escaping (String) -> Void) async -> MediaCodecInfo {
        onStatusUpdate("Launching WebView process...")

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        onStatusUpdate("Initializing WebView...")
        await webView.loadHTMLStringAsync("<html><body></body></html>", baseURL: URL(string: "https://example.com"))

        onStatusUpdate("Detecting media codecs...")
        let script = """
        (function() {
            var video = document.createElement('video');
            var audio = document.createElement('audio');

            function check(el, type) {
                var result = el.canPlayType(type);
                return result || 'no';
            }

            return {
                // Video codecs
                h264: check(video, 'video/mp4; codecs="avc1.42E01E"'),
                hevc: check(video, 'video/mp4; codecs="hvc1.1.6.L93.B0"'),
                vp8: check(video, 'video/webm; codecs="vp8"'),
                vp9: check(video, 'video/webm; codecs="vp9"'),
                av1: check(video, 'video/mp4; codecs="av01.0.01M.08"'),
                theora: check(video, 'video/ogg; codecs="theora"'),

                // Audio codecs
                aac: check(audio, 'audio/mp4; codecs="mp4a.40.2"'),
                mp3: check(audio, 'audio/mpeg; codecs="mp3"'),
                opus: check(audio, 'audio/ogg; codecs="opus"'),
                vorbis: check(audio, 'audio/ogg; codecs="vorbis"'),
                flac: check(audio, 'audio/flac'),
                wav: check(audio, 'audio/wav'),

                // Containers (with common codec for accurate detection)
                mp4: check(video, 'video/mp4; codecs="avc1.42E01E"'),
                webm: check(video, 'video/webm; codecs="vp8"'),
                ogg: check(video, 'video/ogg; codecs="theora"'),
                hls: check(video, 'application/vnd.apple.mpegurl; codecs="avc1.42E01E"'),

                // APIs
                mediaCapabilities: 'mediaCapabilities' in navigator,
                mse: 'ManagedMediaSource' in window || 'MediaSource' in window,
                eme: 'requestMediaKeySystemAccess' in navigator
            };
        })()
        """

        let result = await webView.evaluateJavaScriptAsync(script) as? [String: Any] ?? [:]

        func parseSupport(_ value: Any?) -> CodecSupport {
            guard let str = value as? String else { return .none }
            switch str {
            case "probably": return .probably
            case "maybe": return .maybe
            default: return .none
            }
        }

        return MediaCodecInfo(
            h264: parseSupport(result["h264"]),
            hevc: parseSupport(result["hevc"]),
            vp8: parseSupport(result["vp8"]),
            vp9: parseSupport(result["vp9"]),
            av1: parseSupport(result["av1"]),
            theora: parseSupport(result["theora"]),
            aac: parseSupport(result["aac"]),
            mp3: parseSupport(result["mp3"]),
            opus: parseSupport(result["opus"]),
            vorbis: parseSupport(result["vorbis"]),
            flac: parseSupport(result["flac"]),
            wav: parseSupport(result["wav"]),
            mp4: parseSupport(result["mp4"]),
            webm: parseSupport(result["webm"]),
            ogg: parseSupport(result["ogg"]),
            hls: parseSupport(result["hls"]),
            supportsMediaCapabilities: result["mediaCapabilities"] as? Bool ?? false,
            supportsMSE: result["mse"] as? Bool ?? false,
            supportsEME: result["eme"] as? Bool ?? false
        )
    }
}

// MARK: - Performance

struct PerformanceView: View {
    @State private var perfInfo: PerformanceInfo?
    @State private var loadingStatus = "Launching WebView process..."
    @State private var isRunning = false

    var body: some View {
        List {
            if let info = perfInfo {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("\(info.totalScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text("iPhone 14 Pro ≈ 10,000")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("System") {
                    InfoRow(label: "Logical Cores", value: info.hardwareConcurrency, info: "navigator.hardwareConcurrency.\nJS thread pool sizing.\nMay be capped for privacy.")
                    InfoRow(label: "Timer Resolution", value: info.timerResolution, info: "performance.now() precision.\nReduced for Spectre mitigation.\nTypically 1ms in WKWebView.")
                }

                Section("JavaScript") {
                    BenchmarkRow(label: "Math", ops: info.mathOps, info: "Math.sqrt, sin, cos, random.\nTests JIT optimization.\nCore computation speed.")
                    BenchmarkRow(label: "Array", ops: info.arrayOps, info: "map, filter, reduce, sort.\nFunctional programming ops.\nMemory allocation intensive.")
                    BenchmarkRow(label: "String", ops: info.stringOps, info: "split, join, indexOf, replace.\nText processing speed.\nCommon in web apps.")
                    BenchmarkRow(label: "Object", ops: info.objectOps, info: "Object.keys/values, spread.\nJSON parse/stringify.\nData manipulation speed.")
                    BenchmarkRow(label: "RegExp", ops: info.regexpOps, info: "match, replace, test.\nPattern matching speed.\nValidation performance.")
                }

                Section("DOM") {
                    BenchmarkRow(label: "Create", ops: info.domCreate, info: "createElement, appendChild.\nNode creation overhead.\nVirtual DOM comparison.")
                    BenchmarkRow(label: "Query", ops: info.domQuery, info: "querySelector(All), getElement*.\nDOM traversal speed.\nSelector engine perf.")
                    BenchmarkRow(label: "Modify", ops: info.domModify, info: "style, className, attribute.\nReflow/repaint triggers.\nAnimation performance.")
                }

                Section("Graphics") {
                    BenchmarkRow(label: "Canvas 2D", ops: info.canvas2d, info: "2D drawing operations.\nfillRect, arc, stroke.\nSoftware rendering.")
                    BenchmarkRow(label: "WebGL", ops: info.webgl, info: "GPU-accelerated graphics.\nclear, bindBuffer.\nHardware rendering.")
                }

                Section("Memory") {
                    BenchmarkRow(label: "Allocation", ops: info.memoryAlloc, info: "ArrayBuffer, TypedArray.\nMemory allocation speed.\nGC pressure indicator.")
                    BenchmarkRow(label: "Operations", ops: info.memoryOps, info: "Fill, copy, sort arrays.\nMemory bandwidth test.\nCPU cache efficiency.")
                }

                Section("Crypto") {
                    BenchmarkRow(label: "Hash", ops: info.cryptoHash, info: "Hashing algorithm test.\nCPU-intensive operations.\nSecurity computation speed.")
                }

                Section {
                    Button {
                        Task {
                            isRunning = true
                            perfInfo = await PerformanceInfo.load { status in
                                loadingStatus = status
                            }
                            isRunning = false
                        }
                    } label: {
                        HStack {
                            Text("Run Again")
                            Spacer()
                            if isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isRunning)
                }
            }
        }
        .overlay {
            if perfInfo == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            perfInfo = await PerformanceInfo.load { status in
                loadingStatus = status
            }
        }
    }
}

private struct BenchmarkRow: View {
    let label: String
    let ops: String
    var info: String? = nil

    @State private var showingInfo = false

    var body: some View {
        HStack {
            Text(label)
            if let info {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tertiary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer()
            Text(ops)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PerformanceInfo: Sendable {
    // System
    let hardwareConcurrency: String
    let timerResolution: String

    // JS Benchmark
    let mathOps: String
    let arrayOps: String
    let stringOps: String
    let objectOps: String
    let regexpOps: String

    // DOM Benchmark
    let domCreate: String
    let domQuery: String
    let domModify: String

    // Graphics Benchmark
    let canvas2d: String
    let webgl: String

    // Memory Benchmark
    let memoryAlloc: String
    let memoryOps: String

    // Crypto Benchmark
    let cryptoHash: String

    // Total
    let totalScore: Int

    // iPhone 14 Pro reference values (ops/sec) - calibrated to score 10,000
    private static let reference: [String: Double] = [
        "math": 21_100_000,
        "array": 19_900_000,
        "string": 11_600_000,
        "object": 4_900_000,
        "regexp": 18_300_000,
        "domCreate": 4_600_000,
        "domQuery": 8_300_000,
        "domModify": 2_900_000,
        "canvas2d": 828_000,
        "webgl": 5_800_000,
        "memoryAlloc": 3_500_000,
        "memoryOps": 3_000_000,
        "cryptoHash": 10_700_000
    ]

    @MainActor
    static func load(onStatusUpdate: @escaping (String) -> Void) async -> PerformanceInfo {
        onStatusUpdate("Launching WebView process...")

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        onStatusUpdate("Initializing WebView...")
        await webView.loadHTMLStringAsync("<html><body><div id='test'></div></body></html>", baseURL: nil)

        onStatusUpdate("Running benchmarks...")
        let script = """
        (function() {
            try {
                function bench(fn, duration) {
                    var ops = 0;
                    var start = performance.now();
                    var end = start + duration;
                    while (performance.now() < end) {
                        fn();
                        ops++;
                    }
                    var elapsed = performance.now() - start;
                    return Math.round(ops / (elapsed / 1000));
                }

                // Measure timer resolution by finding minimum time difference
                var times = [];
                var iterations = 0;
                var maxIterations = 10000;
                var last = performance.now();
                while (times.length < 20 && iterations < maxIterations) {
                    var now = performance.now();
                    if (now > last) {
                        times.push(now - last);
                        last = now;
                    }
                    iterations++;
                }
                var resolution = times.length > 0 ? Math.min.apply(null, times) : -1;

                var mathOps = bench(function() {
                    Math.sqrt(Math.random() * 10000);
                    Math.sin(Math.random());
                    Math.cos(Math.random());
                }, 100);

                var arrayOps = bench(function() {
                    var arr = [1,2,3,4,5];
                    arr.map(function(x) { return x * 2; });
                    arr.filter(function(x) { return x > 2; });
                    arr.reduce(function(a,b) { return a + b; }, 0);
                }, 100);

                var stringOps = bench(function() {
                    var s = 'hello world';
                    s.split(' ').join('-');
                    s.toUpperCase();
                    s.indexOf('world');
                }, 100);

                var objectOps = bench(function() {
                    var obj = {a: 1, b: 2, c: 3};
                    Object.keys(obj);
                    Object.values(obj);
                    JSON.parse(JSON.stringify(obj));
                }, 100);

                var regexpOps = bench(function() {
                    var re = /[0-9]+/g;
                    'test123abc456'.match(re);
                    'hello'.replace(/l/g, 'x');
                }, 100);

                // DOM benchmarks
                var container = document.createElement('div');
                document.body.appendChild(container);

                var domCreate = bench(function() {
                    var el = document.createElement('div');
                    el.className = 'test-class';
                    el.textContent = 'test';
                }, 100);

                for (var i = 0; i < 100; i++) {
                    var div = document.createElement('div');
                    div.className = 'item item-' + i;
                    div.id = 'item-' + i;
                    container.appendChild(div);
                }

                var domQuery = bench(function() {
                    document.querySelectorAll('.item');
                    document.getElementById('item-50');
                    document.getElementsByClassName('item');
                }, 100);

                var targetEl = document.getElementById('item-25');
                var domModify = 0;
                if (targetEl) {
                    domModify = bench(function() {
                        targetEl.style.color = 'red';
                        targetEl.setAttribute('data-test', 'value');
                        targetEl.classList.toggle('active');
                    }, 100);
                }

                // Canvas 2D benchmark
                var canvas2d = 0;
                try {
                    var canvas = document.createElement('canvas');
                    canvas.width = 256;
                    canvas.height = 256;
                    var ctx = canvas.getContext('2d');
                    if (ctx) {
                        canvas2d = bench(function() {
                            ctx.fillStyle = 'rgb(' + Math.floor(Math.random()*255) + ',0,0)';
                            ctx.fillRect(Math.random()*200, Math.random()*200, 50, 50);
                            ctx.beginPath();
                            ctx.arc(128, 128, 50, 0, Math.PI * 2);
                            ctx.stroke();
                        }, 100);
                    }
                } catch(e) {}

                // WebGL benchmark
                var webgl = 0;
                try {
                    var glCanvas = document.createElement('canvas');
                    glCanvas.width = 256;
                    glCanvas.height = 256;
                    var gl = glCanvas.getContext('webgl') || glCanvas.getContext('experimental-webgl');
                    if (gl) {
                        webgl = bench(function() {
                            gl.clearColor(Math.random(), Math.random(), Math.random(), 1.0);
                            gl.clear(gl.COLOR_BUFFER_BIT);
                        }, 100);
                    }
                } catch(e) {}

                // Memory benchmark - ArrayBuffer allocation
                var memoryAlloc = bench(function() {
                    var buf = new ArrayBuffer(1024);
                    var view = new Uint8Array(buf);
                    view[0] = 255;
                }, 100);

                // Memory benchmark - Large array operations
                var memoryOps = bench(function() {
                    var arr = new Float64Array(100);
                    for (var i = 0; i < 100; i++) {
                        arr[i] = i * 1.5;
                    }
                    arr.sort();
                }, 100);

                // Crypto benchmark - simple hash simulation (sync)
                var cryptoHash = bench(function() {
                    var data = 'benchmark test string for hashing';
                    var hash = 0;
                    for (var i = 0; i < data.length; i++) {
                        var char = data.charCodeAt(i);
                        hash = ((hash << 5) - hash) + char;
                        hash = hash & hash;
                    }
                    return hash;
                }, 100);

                return {
                    hardwareConcurrency: navigator.hardwareConcurrency || 0,
                    timerResolution: resolution,
                    mathOps: mathOps,
                    arrayOps: arrayOps,
                    stringOps: stringOps,
                    objectOps: objectOps,
                    regexpOps: regexpOps,
                    domCreate: domCreate,
                    domQuery: domQuery,
                    domModify: domModify,
                    canvas2d: canvas2d,
                    webgl: webgl,
                    memoryAlloc: memoryAlloc,
                    memoryOps: memoryOps,
                    cryptoHash: cryptoHash
                };
            } catch(e) {
                return { error: e.message };
            }
        })()
        """

        let rawResult = await webView.evaluateJavaScriptAsync(script)
        let result = rawResult as? [String: Any] ?? [:]

        func formatOps(_ value: Int) -> String {
            if value >= 1_000_000 {
                return String(format: "%.1fM ops/s", Double(value) / 1_000_000)
            } else if value >= 1_000 {
                return String(format: "%.0fK ops/s", Double(value) / 1_000)
            } else {
                return "\(value) ops/s"
            }
        }

        func toInt(_ value: Any?) -> Int {
            if let i = value as? Int { return i }
            if let d = value as? Double { return Int(d) }
            return 0
        }

        let cores = toInt(result["hardwareConcurrency"])
        let resolution = result["timerResolution"] as? Double ?? 0

        let mathOps = toInt(result["mathOps"])
        let arrayOps = toInt(result["arrayOps"])
        let stringOps = toInt(result["stringOps"])
        let objectOps = toInt(result["objectOps"])
        let regexpOps = toInt(result["regexpOps"])
        let domCreate = toInt(result["domCreate"])
        let domQuery = toInt(result["domQuery"])
        let domModify = toInt(result["domModify"])
        let canvas2d = toInt(result["canvas2d"])
        let webgl = toInt(result["webgl"])
        let memoryAlloc = toInt(result["memoryAlloc"])
        let memoryOps = toInt(result["memoryOps"])
        let cryptoHash = toInt(result["cryptoHash"])

        // Calculate score relative to iPhone 14 Pro (= 10,000 points)
        let scores: [(Int, String)] = [
            (mathOps, "math"),
            (arrayOps, "array"),
            (stringOps, "string"),
            (objectOps, "object"),
            (regexpOps, "regexp"),
            (domCreate, "domCreate"),
            (domQuery, "domQuery"),
            (domModify, "domModify"),
            (canvas2d, "canvas2d"),
            (webgl, "webgl"),
            (memoryAlloc, "memoryAlloc"),
            (memoryOps, "memoryOps"),
            (cryptoHash, "cryptoHash")
        ]

        var totalRatio = 0.0
        for (ops, key) in scores {
            if let ref = reference[key], ref > 0 {
                totalRatio += Double(ops) / ref
            }
        }
        let averageRatio = totalRatio / Double(scores.count)
        let totalScore = Int(averageRatio * 10000) // iPhone 14 Pro = 10,000

        return PerformanceInfo(
            hardwareConcurrency: cores > 0 ? "\(cores)" : "N/A",
            timerResolution: resolution >= 0 ? String(format: "%.2f ms", resolution) : "Restricted",
            mathOps: formatOps(mathOps),
            arrayOps: formatOps(arrayOps),
            stringOps: formatOps(stringOps),
            objectOps: formatOps(objectOps),
            regexpOps: formatOps(regexpOps),
            domCreate: formatOps(domCreate),
            domQuery: formatOps(domQuery),
            domModify: formatOps(domModify),
            canvas2d: formatOps(canvas2d),
            webgl: formatOps(webgl),
            memoryAlloc: formatOps(memoryAlloc),
            memoryOps: formatOps(memoryOps),
            cryptoHash: formatOps(cryptoHash),
            totalScore: totalScore
        )
    }
}

// MARK: - Display Features

struct DisplayFeaturesView: View {
    @State private var displayInfo: DisplayInfo?
    @State private var loadingStatus = "Launching WebView process..."

    var body: some View {
        List {
            if let info = displayInfo {
                Section("Screen") {
                    InfoRow(label: "Width", value: info.screenWidth)
                    InfoRow(label: "Height", value: info.screenHeight)
                    InfoRow(label: "Available Width", value: info.availWidth, info: "Screen width minus system UI elements.")
                    InfoRow(label: "Available Height", value: info.availHeight, info: "Screen height minus system UI elements.")
                    InfoRow(label: "Device Pixel Ratio", value: info.devicePixelRatio, info: "CSS pixels to device pixels ratio.")
                    InfoRow(label: "Orientation", value: info.orientation)
                }

                Section("Color") {
                    InfoRow(label: "Color Depth", value: info.colorDepth, info: "Bits per pixel for color.\n24-bit = 16.7M colors\n30-bit = 1B colors (HDR)")
                    InfoRow(label: "Pixel Depth", value: info.pixelDepth, info: "Bits per pixel including alpha.\nUsually equals Color Depth.")
                    CapabilityRow(label: "sRGB", supported: info.supportsSRGB, info: "Standard color space.\nCovers ~35% of visible colors.\nUsed by most web content.")
                    CapabilityRow(label: "Display-P3", supported: info.supportsP3, info: "Wide gamut (~25% more than sRGB).\nAll iPhones since iPhone 7.\nVivid reds, greens, oranges.")
                    CapabilityRow(label: "Rec. 2020", supported: info.supportsRec2020, info: "Ultra-wide gamut (~75% of visible).\nPro Display XDR, some iPad Pro.\niPhone: Not supported yet.")
                }

                Section("HDR") {
                    CapabilityRow(label: "HDR Display", supported: info.supportsHDR, info: "High Dynamic Range display.\nBrighter highlights, deeper blacks.\niPhone 12+ supports HDR10/Dolby Vision.")
                    InfoRow(label: "Dynamic Range", value: info.dynamicRange)
                }

                Section("Media Queries") {
                    CapabilityRow(label: "Inverted Colors", supported: info.invertedColors, info: "Settings > Accessibility > Display.\nInverts all screen colors.\nCSS: prefers-color-scheme alternative.")
                    CapabilityRow(label: "Forced Colors", supported: info.forcedColors, info: "High contrast mode.\niOS: Not used (Windows feature).\nCSS: forced-colors media query.")
                }
            }
        }
        .overlay {
            if displayInfo == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Display")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            displayInfo = await DisplayInfo.load { status in
                loadingStatus = status
            }
        }
    }
}

private struct DisplayInfo: Sendable {
    // Screen
    let screenWidth: String
    let screenHeight: String
    let availWidth: String
    let availHeight: String
    let devicePixelRatio: String
    let orientation: String

    // Color
    let colorDepth: String
    let pixelDepth: String
    let supportsSRGB: Bool
    let supportsP3: Bool
    let supportsRec2020: Bool

    // HDR
    let supportsHDR: Bool
    let dynamicRange: String

    // Media Queries
    let colorScheme: String
    let invertedColors: Bool
    let forcedColors: Bool

    @MainActor
    static func load(onStatusUpdate: @escaping (String) -> Void) async -> DisplayInfo {
        onStatusUpdate("Launching WebView process...")

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        onStatusUpdate("Initializing WebView...")
        await webView.loadHTMLStringAsync("<html><body></body></html>", baseURL: URL(string: "https://example.com"))

        onStatusUpdate("Detecting display features...")
        let script = """
        (function() {
            function mq(query) {
                return window.matchMedia(query).matches;
            }

            var orientation = 'Unknown';
            if (screen.orientation) {
                orientation = screen.orientation.type;
            } else if (window.orientation !== undefined) {
                orientation = Math.abs(window.orientation) === 90 ? 'landscape' : 'portrait';
            }

            return {
                // Screen
                screenWidth: screen.width,
                screenHeight: screen.height,
                availWidth: screen.availWidth,
                availHeight: screen.availHeight,
                devicePixelRatio: window.devicePixelRatio,
                orientation: orientation,

                // Color
                colorDepth: screen.colorDepth,
                pixelDepth: screen.pixelDepth,
                supportsSRGB: mq('(color-gamut: srgb)'),
                supportsP3: mq('(color-gamut: p3)'),
                supportsRec2020: mq('(color-gamut: rec2020)'),

                // HDR
                supportsHDR: mq('(dynamic-range: high)'),
                dynamicRange: mq('(dynamic-range: high)') ? 'High (HDR)' : 'Standard (SDR)',

                // Media Queries
                colorScheme: mq('(prefers-color-scheme: dark)') ? 'Dark' : 'Light',
                invertedColors: mq('(inverted-colors: inverted)'),
                forcedColors: mq('(forced-colors: active)')
            };
        })()
        """

        let result = await webView.evaluateJavaScriptAsync(script) as? [String: Any] ?? [:]

        func formatPx(_ value: Any?) -> String {
            if let num = value as? Int {
                return "\(num) px"
            } else if let num = value as? Double {
                return "\(Int(num)) px"
            }
            return "N/A"
        }

        return DisplayInfo(
            screenWidth: formatPx(result["screenWidth"]),
            screenHeight: formatPx(result["screenHeight"]),
            availWidth: formatPx(result["availWidth"]),
            availHeight: formatPx(result["availHeight"]),
            devicePixelRatio: "\(result["devicePixelRatio"] as? Double ?? 1.0)x",
            orientation: result["orientation"] as? String ?? "Unknown",
            colorDepth: "\(result["colorDepth"] as? Int ?? 0) bit",
            pixelDepth: "\(result["pixelDepth"] as? Int ?? 0) bit",
            supportsSRGB: result["supportsSRGB"] as? Bool ?? false,
            supportsP3: result["supportsP3"] as? Bool ?? false,
            supportsRec2020: result["supportsRec2020"] as? Bool ?? false,
            supportsHDR: result["supportsHDR"] as? Bool ?? false,
            dynamicRange: result["dynamicRange"] as? String ?? "Unknown",
            colorScheme: result["colorScheme"] as? String ?? "Unknown",
            invertedColors: result["invertedColors"] as? Bool ?? false,
            forcedColors: result["forcedColors"] as? Bool ?? false
        )
    }
}

// MARK: - Accessibility Features

struct AccessibilityFeaturesView: View {
    @State private var a11yInfo: AccessibilityInfo?
    @State private var loadingStatus = "Launching WebView process..."

    var body: some View {
        List {
            if let info = a11yInfo {
                Section("User Preferences") {
                    InfoRow(label: "Reduced Motion", value: info.reducedMotion)
                    InfoRow(label: "Reduced Transparency", value: info.reducedTransparency)
                    InfoRow(label: "Contrast", value: info.contrast)
                    InfoRow(label: "Color Scheme", value: info.colorScheme)
                }

                Section("Data & Power") {
                    InfoRow(label: "Reduced Data", value: info.reducedData)
                    InfoRow(label: "Prefers Reduced Data", value: info.prefersReducedData)
                }

                Section("Display") {
                    InfoRow(label: "Inverted Colors", value: info.invertedColors)
                    InfoRow(label: "Forced Colors", value: info.forcedColors)
                    InfoRow(label: "Color Gamut", value: info.colorGamut)
                }

                Section("Pointer & Input") {
                    InfoRow(label: "Pointer Type", value: info.pointerType)
                    InfoRow(label: "Any Pointer", value: info.anyPointer)
                    InfoRow(label: "Hover", value: info.hover)
                    InfoRow(label: "Any Hover", value: info.anyHover)
                }
            }
        }
        .overlay {
            if a11yInfo == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            a11yInfo = await AccessibilityInfo.load { status in
                loadingStatus = status
            }
        }
    }
}

private struct AccessibilityInfo: Sendable {
    // User Preferences
    let reducedMotion: String
    let reducedTransparency: String
    let contrast: String
    let colorScheme: String

    // Data & Power
    let reducedData: String
    let prefersReducedData: String

    // Display
    let invertedColors: String
    let forcedColors: String
    let colorGamut: String

    // Pointer & Input
    let pointerType: String
    let anyPointer: String
    let hover: String
    let anyHover: String

    @MainActor
    static func load(onStatusUpdate: @escaping (String) -> Void) async -> AccessibilityInfo {
        onStatusUpdate("Launching WebView process...")

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        onStatusUpdate("Initializing WebView...")
        await webView.loadHTMLStringAsync("<html><body></body></html>", baseURL: URL(string: "https://example.com"))

        onStatusUpdate("Detecting accessibility preferences...")
        let script = """
        (function() {
            function mq(query) {
                return window.matchMedia(query).matches;
            }

            function detectValue(queries) {
                for (var i = 0; i < queries.length; i++) {
                    if (mq(queries[i].query)) return queries[i].value;
                }
                return 'no-preference';
            }

            return {
                // User Preferences
                reducedMotion: mq('(prefers-reduced-motion: reduce)') ? 'Reduce' : 'No Preference',
                reducedTransparency: mq('(prefers-reduced-transparency: reduce)') ? 'Reduce' : 'No Preference',
                contrast: detectValue([
                    { query: '(prefers-contrast: more)', value: 'More' },
                    { query: '(prefers-contrast: less)', value: 'Less' },
                    { query: '(prefers-contrast: custom)', value: 'Custom' }
                ]),
                colorScheme: mq('(prefers-color-scheme: dark)') ? 'Dark' : 'Light',

                // Data & Power
                reducedData: mq('(prefers-reduced-data: reduce)') ? 'Reduce' : 'No Preference',
                prefersReducedData: 'connection' in navigator && navigator.connection.saveData ? 'Enabled' : 'Disabled',

                // Display
                invertedColors: mq('(inverted-colors: inverted)') ? 'Inverted' : 'None',
                forcedColors: mq('(forced-colors: active)') ? 'Active' : 'None',
                colorGamut: detectValue([
                    { query: '(color-gamut: rec2020)', value: 'Rec. 2020' },
                    { query: '(color-gamut: p3)', value: 'Display-P3' },
                    { query: '(color-gamut: srgb)', value: 'sRGB' }
                ]),

                // Pointer & Input
                pointerType: detectValue([
                    { query: '(pointer: fine)', value: 'Fine (mouse/stylus)' },
                    { query: '(pointer: coarse)', value: 'Coarse (touch)' },
                    { query: '(pointer: none)', value: 'None' }
                ]),
                anyPointer: detectValue([
                    { query: '(any-pointer: fine)', value: 'Fine available' },
                    { query: '(any-pointer: coarse)', value: 'Coarse only' },
                    { query: '(any-pointer: none)', value: 'None' }
                ]),
                hover: mq('(hover: hover)') ? 'Supported' : 'Not supported',
                anyHover: mq('(any-hover: hover)') ? 'Available' : 'Not available'
            };
        })()
        """

        let result = await webView.evaluateJavaScriptAsync(script) as? [String: String] ?? [:]

        return AccessibilityInfo(
            reducedMotion: result["reducedMotion"] ?? "Unknown",
            reducedTransparency: result["reducedTransparency"] ?? "Unknown",
            contrast: result["contrast"] ?? "Unknown",
            colorScheme: result["colorScheme"] ?? "Unknown",
            reducedData: result["reducedData"] ?? "Unknown",
            prefersReducedData: result["prefersReducedData"] ?? "Unknown",
            invertedColors: result["invertedColors"] ?? "Unknown",
            forcedColors: result["forcedColors"] ?? "Unknown",
            colorGamut: result["colorGamut"] ?? "Unknown",
            pointerType: result["pointerType"] ?? "Unknown",
            anyPointer: result["anyPointer"] ?? "Unknown",
            hover: result["hover"] ?? "Unknown",
            anyHover: result["anyHover"] ?? "Unknown"
        )
    }
}

// MARK: - Active Settings

struct ActiveSettingsView: View {
    @Binding var showSettings: Bool

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

    // Navigation
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = true
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true

    // Behavior
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

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var contentModeText: String {
        switch preferredContentMode {
        case 1: return "Mobile"
        case 2: return "Desktop"
        default: return "Recommended"
        }
    }

    private var activeDataDetectors: String {
        var detectors: [String] = []
        if detectPhoneNumbers { detectors.append("Phone") }
        if detectLinks { detectors.append("Links") }
        if detectAddresses { detectors.append("Address") }
        if detectCalendarEvents { detectors.append("Calendar") }
        return detectors.isEmpty ? "None" : detectors.joined(separator: ", ")
    }

    var body: some View {
        List {
            Section {
                Text("Current WebView configuration. Modify these in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .listSectionSpacing(0)

            Section("Core") {
                ActiveSettingRow(label: "JavaScript", enabled: enableJavaScript, info: "Enable/disable all JavaScript.\nOff = No scripts run at all.\nMost websites won't work.")
                ActiveSettingRow(label: "Content JavaScript", enabled: allowsContentJavaScript, info: "Scripts from web pages.\nOff = Block page scripts only.\nApp features still work.")
                ActiveSettingRow(label: "Ignore Viewport Scale Limits", enabled: allowZoom, info: "Force pinch-to-zoom.\nOverrides pages that disable zoom.\nBetter accessibility.")
                InfoRow(label: "Minimum Font Size", value: minimumFontSize == 0 ? "Default" : "\(Int(minimumFontSize)) pt", info: "Minimum text size.\nMakes small text readable.\n0 = Use page's font sizes.")
            }

            Section("Media") {
                ActiveSettingRow(label: "Auto-play Media", enabled: mediaAutoplay, info: "Videos play automatically.\nOff = Tap to play videos.\nSaves battery and data.")
                ActiveSettingRow(label: "Inline Playback", enabled: inlineMediaPlayback, info: "Play videos in page.\nOff = Always fullscreen.\nNeeded for background videos.")
                ActiveSettingRow(label: "AirPlay", enabled: allowsAirPlay, info: "Stream to Apple TV.\nOff = Hide AirPlay button.\nFor local-only playback.")
                ActiveSettingRow(label: "Picture in Picture", enabled: allowsPictureInPicture, info: "Floating video window.\nWatch while using other apps.\nSwipe up or tap button.")
            }

            Section("Navigation") {
                ActiveSettingRow(label: "Back/Forward Gestures", enabled: allowsBackForwardGestures, info: "Swipe to go back/forward.\nOff = Use buttons only.\nAvoids conflicts with page gestures.")
                ActiveSettingRow(label: "Link Preview", enabled: allowsLinkPreview, info: "Preview links before opening.\nLong-press or 3D Touch.\nSee page without leaving.")
                InfoRow(label: "Content Mode", value: contentModeText, info: "Mobile or desktop sites.\nRecommended: Auto-detect.\nDesktop useful on iPad.")
            }

            Section("Behavior") {
                ActiveSettingRow(label: "JS Can Open Windows", enabled: javaScriptCanOpenWindows, info: "Allow popup windows.\nOff = Block popups.\nSome sites need this on.")
                ActiveSettingRow(label: "Fraudulent Website Warning", enabled: fraudulentWebsiteWarning, info: "Warn about dangerous sites.\nPhishing and malware alerts.\nKeep on for safety.")
                ActiveSettingRow(label: "Text Interaction", enabled: textInteractionEnabled, info: "Select and copy text.\nOff = No text selection.\nDisable for game-like pages.")
                ActiveSettingRow(label: "Element Fullscreen API", enabled: elementFullscreenEnabled, info: isIPad ? "iPad: Full fullscreen support.\nAny element can go fullscreen.\nVideos, games, presentations." : "iPhone: Video fullscreen only.\nFull API on iPad only.\nVideos still work normally.", unavailable: !isIPad)
                ActiveSettingRow(label: "Suppress Incremental Rendering", enabled: suppressesIncrementalRendering, info: "Wait for full page load.\nCleaner appearance.\nFeels slower to load.")
            }

            Section("Data Detectors") {
                InfoRow(label: "Active", value: activeDataDetectors, info: "Auto-link special content.\nPhone numbers, addresses, dates.\nTap to call, map, or add event.")
            }

            Section("Privacy & Security") {
                ActiveSettingRow(label: "Private Browsing", enabled: privateBrowsing, info: "No history saved.\nCookies cleared on exit.\nLike incognito mode.")
                ActiveSettingRow(label: "Upgrade to HTTPS", enabled: upgradeToHTTPS, info: "Auto-secure connections.\nHTTP → HTTPS upgrade.\nProtects your data.")
            }

            Section("User-Agent") {
                if customUserAgent.isEmpty {
                    InfoRow(label: "Status", value: "Default")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom")
                            .foregroundStyle(.secondary)
                        Text(customUserAgent)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Active Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

private struct ActiveSettingRow: View {
    let label: String
    let enabled: Bool
    var info: String? = nil
    var unavailable: Bool = false

    @State private var showingInfo = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(unavailable ? .secondary : .primary)
            if unavailable {
                Text("(iPad only)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let info {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer()
            if unavailable {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(enabled ? .green : .secondary)
            }
        }
    }
}

#Preview {
    InfoView()
}
