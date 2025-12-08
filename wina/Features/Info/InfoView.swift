//
//  InfoView.swift
//  wina
//

import Metal
import SwiftUI
import WebKit

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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
                }
            }
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
    }
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
                    InfoRow(label: "CPU Cores", value: info.cpuCores)
                    InfoRow(label: "Active Cores", value: info.activeCores)
                    InfoRow(label: "Physical Memory", value: info.physicalMemory)
                    InfoRow(label: "Thermal State", value: info.thermalState)
                    CapabilityRow(label: "Low Power Mode", supported: info.isLowPowerMode)
                }

                Section("Graphics") {
                    InfoRow(label: "GPU", value: info.gpuName)
                }

                Section("Display") {
                    InfoRow(label: "Screen Size", value: info.screenSize)
                    InfoRow(label: "Screen Scale", value: info.screenScale)
                    InfoRow(label: "Native Scale", value: info.nativeScale)
                    InfoRow(label: "Brightness", value: info.brightness)
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
                    InfoRow(label: "WebKit Version", value: info.webKitVersion)
                    InfoRow(label: "JavaScript Core", value: info.jsCoreVersion)
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
                    InfoRow(label: "Max Touch Points", value: info.maxTouchPoints)
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

    var body: some View {
        List {
            if let info = webViewInfo {
                Section("Core APIs") {
                    CapabilityRow(label: "JavaScript", supported: true)
                    CapabilityRow(label: "WebAssembly", supported: info.supportsWebAssembly)
                    CapabilityRow(label: "Web Workers", supported: info.supportsWebWorkers, info: "Web Workers may fail with 'SecurityError' when loading from local HTML in WKWebView.")
                    CapabilityRow(label: "Service Workers", supported: info.supportsServiceWorkers, info: "Service Workers are not available in WKWebView by default. Only Safari and home screen web apps support them.")
                    CapabilityRow(label: "Shared Workers", supported: info.supportsSharedWorkers, info: "Shared Workers are supported since Safari 16.0 (2022). They allow multiple tabs to share the same worker.")
                }

                Section("Graphics & Media") {
                    CapabilityRow(label: "WebGL", supported: info.supportsWebGL)
                    CapabilityRow(label: "WebGL 2", supported: info.supportsWebGL2, info: "WebGL 2 is supported since Safari 15 (2021). Uses Metal-based ANGLE implementation.")
                    CapabilityRow(label: "Web Audio", supported: info.supportsWebAudio)
                    CapabilityRow(label: "Media Devices", supported: info.supportsMediaDevices, info: "getUserMedia is available in WKWebView since iOS 14.3.")
                    CapabilityRow(label: "Media Recorder", supported: info.supportsMediaRecorder, info: "MediaRecorder supports MP4/H.264/AAC format. WebM is not supported.")
                    CapabilityRow(label: "Media Source", supported: info.supportsMediaSource, info: "Media Source Extensions enable adaptive bitrate streaming. Supported since Safari 8.")
                    CapabilityRow(label: "Picture in Picture", supported: info.supportsPictureInPicture, info: "Picture-in-Picture is supported on iOS since Safari 14 (iOS 14).")
                    CapabilityRow(label: "Fullscreen", supported: info.supportsFullscreen, info: "Fullscreen API works on iPadOS with webkit prefix. On iOS, only video elements support fullscreen.")
                }

                Section("Storage") {
                    CapabilityRow(label: "Cookies", supported: info.cookiesEnabled)
                    CapabilityRow(label: "LocalStorage", supported: info.supportsLocalStorage, info: "LocalStorage is limited to 5MB per origin.")
                    CapabilityRow(label: "SessionStorage", supported: info.supportsSessionStorage)
                    CapabilityRow(label: "IndexedDB", supported: info.supportsIndexedDB, info: "Data may be evicted after 7 days without user interaction. PWAs added to home screen are exempt.")
                    CapabilityRow(label: "Cache API", supported: info.supportsCacheAPI, info: "Cache API data may be evicted after 7 days without user interaction.")
                }

                Section("Network") {
                    CapabilityRow(label: "Online", supported: info.isOnline)
                    CapabilityRow(label: "WebSocket", supported: info.supportsWebSocket)
                    CapabilityRow(label: "WebRTC", supported: info.supportsWebRTC, info: "WebRTC is supported since iOS 11. Requires user permission for camera/microphone access.")
                    CapabilityRow(label: "Fetch", supported: info.supportsFetch)
                    CapabilityRow(label: "Beacon", supported: info.supportsBeacon, info: "Beacon API sends small data to server without waiting for response. Useful for analytics.")
                    CapabilityRow(label: "Event Source", supported: info.supportsEventSource, info: "Server-Sent Events (SSE) for one-way server-to-client streaming.")
                }

                Section("Device APIs") {
                    CapabilityRow(label: "Geolocation", supported: info.supportsGeolocation, info: "Geolocation may not work in cross-origin iframes within WKWebView.")
                    CapabilityRow(label: "Device Orientation", supported: info.supportsDeviceOrientation)
                    CapabilityRow(label: "Device Motion", supported: info.supportsDeviceMotion)
                    CapabilityRow(label: "Vibration", supported: info.supportsVibration, info: "Vibration API is not supported in Safari/WebKit.")
                    CapabilityRow(label: "Battery", supported: info.supportsBattery, info: "Battery Status API is not supported in Safari/WebKit for privacy reasons.")
                    CapabilityRow(label: "Bluetooth", supported: info.supportsBluetooth, info: "Web Bluetooth is not supported in Safari/WebKit. Use native APIs instead.")
                    CapabilityRow(label: "USB", supported: info.supportsUSB, info: "WebUSB is not supported in Safari/WebKit. Use native APIs instead.")
                    CapabilityRow(label: "NFC", supported: info.supportsNFC, info: "Web NFC is not supported in Safari/WebKit. Use native APIs instead.")
                }

                Section("UI & Interaction") {
                    CapabilityRow(label: "Clipboard", supported: info.supportsClipboard, info: "Clipboard API requires user gesture. Reading clipboard needs user permission.")
                    CapabilityRow(label: "Web Share", supported: info.supportsWebShare, info: "Web Share API allows sharing text, URLs, and files to native apps.")
                    CapabilityRow(label: "Notifications", supported: info.supportsNotifications, info: "Web Push Notifications are not supported in WKWebView. Only Safari supports them.")
                    CapabilityRow(label: "Pointer Events", supported: info.supportsPointerEvents)
                    CapabilityRow(label: "Touch Events", supported: info.supportsTouchEvents)
                    CapabilityRow(label: "Gamepad", supported: info.supportsGamepad, info: "Gamepad API is supported since Safari 10.1. Works with MFi controllers.")
                    CapabilityRow(label: "Drag and Drop", supported: info.supportsDragDrop, info: "Drag and Drop API works on iPadOS. Limited support on iOS due to touch-based interaction.")
                }

                Section("Observers") {
                    CapabilityRow(label: "Intersection Observer", supported: info.supportsIntersectionObserver, info: "Detects element visibility in viewport. Useful for lazy loading and infinite scroll.")
                    CapabilityRow(label: "Resize Observer", supported: info.supportsResizeObserver, info: "Observes element size changes. Supported since Safari 13.1.")
                    CapabilityRow(label: "Mutation Observer", supported: info.supportsMutationObserver, info: "Monitors DOM tree changes. Replacement for deprecated Mutation Events.")
                    CapabilityRow(label: "Performance Observer", supported: info.supportsPerformanceObserver, info: "Collects performance metrics like paint timing and resource loading.")
                }

                Section("Security & Payments") {
                    CapabilityRow(label: "Crypto", supported: info.supportsCrypto, info: "Web Crypto API provides cryptographic primitives. Requires HTTPS in production.")
                    CapabilityRow(label: "Credentials", supported: info.supportsCredentials, info: "Credential Management API for password and federated login management.")
                    CapabilityRow(label: "Payment Request", supported: info.supportsPaymentRequest, info: "Payment Request API integrates with Apple Pay. Requires HTTPS.")
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

// MARK: - Supporting Views

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
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

    @State private var showingInfo = false

    var body: some View {
        HStack {
            Text(label)
            if info != nil {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red)
        }
        .alert(label, isPresented: $showingInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(info ?? "")
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

        // 패턴: key/value 또는 괄호 내용
        let patterns: [(pattern: String, color: Color)] = [
            ("Mozilla/[\\d.]+", .blue),
            ("AppleWebKit/[\\d.]+", .orange),
            ("Version/[\\d.]+", .purple),
            ("Mobile/[\\w]+", .green),
            ("Safari/[\\d.]+", .pink),
            ("\\([^)]+\\)", .secondary),
        ]

        var text = userAgent

        // 주요 구분자에서 줄바꿈 추가
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
        onStatusUpdate("Initializing WebView...")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                continuation.resume()
            }
        }

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
            return {
                // Core APIs
                webAssembly: typeof WebAssembly !== 'undefined',
                webWorkers: typeof Worker !== 'undefined',
                serviceWorkers: 'serviceWorker' in navigator,
                sharedWorkers: typeof SharedWorker !== 'undefined',

                // Graphics & Media
                webGL: typeof WebGLRenderingContext !== 'undefined',
                webGL2: typeof WebGL2RenderingContext !== 'undefined',
                webAudio: typeof AudioContext !== 'undefined' || typeof webkitAudioContext !== 'undefined',
                mediaDevices: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia),
                mediaRecorder: typeof MediaRecorder !== 'undefined',
                mediaSource: typeof MediaSource !== 'undefined',
                pictureInPicture: 'pictureInPictureEnabled' in document,
                fullscreen: !!(document.fullscreenEnabled || document.webkitFullscreenEnabled),

                // Storage
                cookies: navigator.cookieEnabled,
                localStorage: (function() { try { return !!window.localStorage; } catch(e) { return false; } })(),
                sessionStorage: (function() { try { return !!window.sessionStorage; } catch(e) { return false; } })(),
                indexedDB: typeof indexedDB !== 'undefined',
                cacheAPI: 'caches' in window,

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
                clipboard: !!(navigator.clipboard && navigator.clipboard.writeText),
                webShare: 'share' in navigator,
                notifications: 'Notification' in window,
                pointerEvents: 'PointerEvent' in window,
                touchEvents: 'ontouchstart' in window,
                gamepad: 'getGamepads' in navigator,
                dragDrop: 'draggable' in document.createElement('div'),

                // Observers
                intersectionObserver: typeof IntersectionObserver !== 'undefined',
                resizeObserver: typeof ResizeObserver !== 'undefined',
                mutationObserver: typeof MutationObserver !== 'undefined',
                performanceObserver: typeof PerformanceObserver !== 'undefined',

                // Security & Payments
                crypto: !!(window.crypto && window.crypto.subtle),
                credentials: 'credentials' in navigator,
                paymentRequest: typeof PaymentRequest !== 'undefined'
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
            evaluateJavaScript(script) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Media Codecs

struct MediaCodecsView: View {
    @State private var codecInfo: MediaCodecInfo?
    @State private var loadingStatus = "Launching WebView process..."

    var body: some View {
        List {
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
                    CapabilityRow(label: "MediaSource Extensions", supported: info.supportsMSE)
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
            Text(support.rawValue)
                .foregroundStyle(support.color)
        }
    }
}

enum CodecSupport: String {
    case probably = "probably"
    case maybe = "maybe"
    case none = "no"

    var color: Color {
        switch self {
        case .probably: return .green
        case .maybe: return .orange
        case .none: return .red
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                continuation.resume()
            }
        }

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
                mp3: check(audio, 'audio/mpeg'),
                opus: check(audio, 'audio/ogg; codecs="opus"'),
                vorbis: check(audio, 'audio/ogg; codecs="vorbis"'),
                flac: check(audio, 'audio/flac'),
                wav: check(audio, 'audio/wav'),

                // Containers
                mp4: check(video, 'video/mp4'),
                webm: check(video, 'video/webm'),
                ogg: check(video, 'video/ogg'),
                hls: check(video, 'application/vnd.apple.mpegurl'),

                // APIs
                mediaCapabilities: 'mediaCapabilities' in navigator,
                mse: 'MediaSource' in window,
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
                            Text("/ 1000")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } footer: {
                    HStack(spacing: 16) {
                        GradeLegend(color: .pink, label: "Best")
                        GradeLegend(color: .blue, label: "Good")
                        GradeLegend(color: .green, label: "Normal")
                        GradeLegend(color: .orange, label: "Bad")
                        GradeLegend(color: .red, label: "Worst")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }

                Section("System") {
                    InfoRow(label: "Logical Cores", value: info.hardwareConcurrency)
                    InfoRow(label: "Timer Resolution", value: info.timerResolution)
                }

                Section {
                    BenchmarkRow(label: "Math", ops: info.mathOps, grade: info.mathGrade)
                    BenchmarkRow(label: "Array", ops: info.arrayOps, grade: info.arrayGrade)
                    BenchmarkRow(label: "String", ops: info.stringOps, grade: info.stringGrade)
                    BenchmarkRow(label: "Object", ops: info.objectOps, grade: info.objectGrade)
                    BenchmarkRow(label: "RegExp", ops: info.regexpOps, grade: info.regexpGrade)
                } header: {
                    Text("JavaScript")
                }

                Section {
                    BenchmarkRow(label: "Create", ops: info.domCreate, grade: info.domCreateGrade)
                    BenchmarkRow(label: "Query", ops: info.domQuery, grade: info.domQueryGrade)
                    BenchmarkRow(label: "Modify", ops: info.domModify, grade: info.domModifyGrade)
                } header: {
                    Text("DOM")
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
    let grade: BenchmarkGrade

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(ops)
                .foregroundStyle(grade.color)
        }
    }
}

private struct GradeLegend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

enum BenchmarkGrade {
    case best, good, normal, bad, worst

    var color: Color {
        switch self {
        case .best: return .pink
        case .good: return .blue
        case .normal: return .green
        case .bad: return .orange
        case .worst: return .red
        }
    }

    var score: Int {
        switch self {
        case .best: return 100
        case .good: return 80
        case .normal: return 60
        case .bad: return 40
        case .worst: return 20
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

    // Grades
    let mathGrade: BenchmarkGrade
    let arrayGrade: BenchmarkGrade
    let stringGrade: BenchmarkGrade
    let objectGrade: BenchmarkGrade
    let regexpGrade: BenchmarkGrade
    let domCreateGrade: BenchmarkGrade
    let domQueryGrade: BenchmarkGrade
    let domModifyGrade: BenchmarkGrade

    // Total
    let totalScore: Int

    // Grade thresholds based on ops/sec (desktop browser baseline)
    private static func gradeFor(ops: Int, thresholds: [Int]) -> BenchmarkGrade {
        // thresholds: [best, good, normal, bad] (descending)
        if ops >= thresholds[0] { return .best }
        if ops >= thresholds[1] { return .good }
        if ops >= thresholds[2] { return .normal }
        if ops >= thresholds[3] { return .bad }
        return .worst
    }

    @MainActor
    static func load(onStatusUpdate: @escaping (String) -> Void) async -> PerformanceInfo {
        onStatusUpdate("Launching WebView process...")

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        onStatusUpdate("Initializing WebView...")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webView.loadHTMLString("<html><body><div id='test'></div></body></html>", baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                continuation.resume()
            }
        }

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

                // DOM benchmarks - create container dynamically
                var container = document.createElement('div');
                document.body.appendChild(container);

                var domCreate = bench(function() {
                    var el = document.createElement('div');
                    el.className = 'test-class';
                    el.textContent = 'test';
                }, 100);

                // Setup for query test
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
                    domModify: domModify
                };
            } catch(e) {
                return { error: e.message };
            }
        })()
        """

        let rawResult = await webView.evaluateJavaScriptAsync(script)
        let result = rawResult as? [String: Any] ?? [:]

        // Debug: print result
        print("Benchmark raw result type: \(type(of: rawResult))")
        print("Benchmark result: \(result)")
        if let error = result["error"] as? String {
            print("Benchmark error: \(error)")
        }

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

        // Thresholds: [best, good, normal, bad] - Mobile baseline (iPhone 14 Pro ≈ Good)
        let mathGrade = gradeFor(ops: mathOps, thresholds: [25_000_000, 18_000_000, 10_000_000, 5_000_000])
        let arrayGrade = gradeFor(ops: arrayOps, thresholds: [25_000_000, 18_000_000, 10_000_000, 5_000_000])
        let stringGrade = gradeFor(ops: stringOps, thresholds: [15_000_000, 11_000_000, 6_000_000, 3_000_000])
        let objectGrade = gradeFor(ops: objectOps, thresholds: [6_000_000, 4_000_000, 2_000_000, 1_000_000])
        let regexpGrade = gradeFor(ops: regexpOps, thresholds: [25_000_000, 16_000_000, 10_000_000, 5_000_000])
        let domCreateGrade = gradeFor(ops: domCreate, thresholds: [6_000_000, 4_000_000, 2_000_000, 1_000_000])
        let domQueryGrade = gradeFor(ops: domQuery, thresholds: [10_000_000, 7_000_000, 4_000_000, 2_000_000])
        let domModifyGrade = gradeFor(ops: domModify, thresholds: [4_000_000, 2_500_000, 1_500_000, 800_000])

        let grades = [mathGrade, arrayGrade, stringGrade, objectGrade, regexpGrade, domCreateGrade, domQueryGrade, domModifyGrade]
        let totalScore = grades.map { $0.score }.reduce(0, +) * 100 / (grades.count * 100)
        let scaledScore = Int(Double(totalScore) * 10.0) // 0-1000 scale

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
            mathGrade: mathGrade,
            arrayGrade: arrayGrade,
            stringGrade: stringGrade,
            objectGrade: objectGrade,
            regexpGrade: regexpGrade,
            domCreateGrade: domCreateGrade,
            domQueryGrade: domQueryGrade,
            domModifyGrade: domModifyGrade,
            totalScore: scaledScore
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
                    InfoRow(label: "Available Width", value: info.availWidth)
                    InfoRow(label: "Available Height", value: info.availHeight)
                    InfoRow(label: "Device Pixel Ratio", value: info.devicePixelRatio)
                    InfoRow(label: "Orientation", value: info.orientation)
                }

                Section("Color") {
                    InfoRow(label: "Color Depth", value: info.colorDepth)
                    InfoRow(label: "Pixel Depth", value: info.pixelDepth)
                    CapabilityRow(label: "sRGB", supported: info.supportsSRGB)
                    CapabilityRow(label: "Display-P3", supported: info.supportsP3)
                    CapabilityRow(label: "Rec. 2020", supported: info.supportsRec2020)
                }

                Section("HDR") {
                    CapabilityRow(label: "HDR Display", supported: info.supportsHDR)
                    InfoRow(label: "Dynamic Range", value: info.dynamicRange)
                }

                Section("Media Queries") {
                    CapabilityRow(label: "Inverted Colors", supported: info.invertedColors)
                    CapabilityRow(label: "Forced Colors", supported: info.forcedColors)
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                continuation.resume()
            }
        }

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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                continuation.resume()
            }
        }

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

#Preview {
    InfoView()
}
