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
                }
            }
            .navigationTitle("Info")
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

                Section("Display") {
                    InfoRow(label: "Color Depth", value: info.colorDepth)
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
                    CapabilityRow(label: "Web Workers", supported: info.supportsWebWorkers)
                    CapabilityRow(label: "Service Workers", supported: info.supportsServiceWorkers)
                    CapabilityRow(label: "Shared Workers", supported: info.supportsSharedWorkers)
                }

                Section("Graphics & Media") {
                    CapabilityRow(label: "WebGL", supported: info.supportsWebGL)
                    CapabilityRow(label: "WebGL 2", supported: info.supportsWebGL2)
                    CapabilityRow(label: "Web Audio", supported: info.supportsWebAudio)
                    CapabilityRow(label: "Media Devices", supported: info.supportsMediaDevices)
                    CapabilityRow(label: "Media Recorder", supported: info.supportsMediaRecorder)
                    CapabilityRow(label: "Media Source", supported: info.supportsMediaSource)
                    CapabilityRow(label: "Picture in Picture", supported: info.supportsPictureInPicture)
                    CapabilityRow(label: "Fullscreen", supported: info.supportsFullscreen)
                }

                Section("Storage") {
                    CapabilityRow(label: "Cookies", supported: info.cookiesEnabled)
                    CapabilityRow(label: "LocalStorage", supported: info.supportsLocalStorage)
                    CapabilityRow(label: "SessionStorage", supported: info.supportsSessionStorage)
                    CapabilityRow(label: "IndexedDB", supported: info.supportsIndexedDB)
                    CapabilityRow(label: "Cache API", supported: info.supportsCacheAPI)
                }

                Section("Network") {
                    CapabilityRow(label: "Online", supported: info.isOnline)
                    CapabilityRow(label: "WebSocket", supported: info.supportsWebSocket)
                    CapabilityRow(label: "WebRTC", supported: info.supportsWebRTC)
                    CapabilityRow(label: "Fetch", supported: info.supportsFetch)
                    CapabilityRow(label: "Beacon", supported: info.supportsBeacon)
                    CapabilityRow(label: "Event Source", supported: info.supportsEventSource)
                }

                Section("Device APIs") {
                    CapabilityRow(label: "Geolocation", supported: info.supportsGeolocation)
                    CapabilityRow(label: "Device Orientation", supported: info.supportsDeviceOrientation)
                    CapabilityRow(label: "Device Motion", supported: info.supportsDeviceMotion)
                    CapabilityRow(label: "Vibration", supported: info.supportsVibration)
                    CapabilityRow(label: "Battery", supported: info.supportsBattery)
                    CapabilityRow(label: "Bluetooth", supported: info.supportsBluetooth)
                    CapabilityRow(label: "USB", supported: info.supportsUSB)
                    CapabilityRow(label: "NFC", supported: info.supportsNFC)
                }

                Section("UI & Interaction") {
                    CapabilityRow(label: "Clipboard", supported: info.supportsClipboard)
                    CapabilityRow(label: "Web Share", supported: info.supportsWebShare)
                    CapabilityRow(label: "Notifications", supported: info.supportsNotifications)
                    CapabilityRow(label: "Pointer Events", supported: info.supportsPointerEvents)
                    CapabilityRow(label: "Touch Events", supported: info.supportsTouchEvents)
                    CapabilityRow(label: "Gamepad", supported: info.supportsGamepad)
                    CapabilityRow(label: "Drag and Drop", supported: info.supportsDragDrop)
                }

                Section("Observers") {
                    CapabilityRow(label: "Intersection Observer", supported: info.supportsIntersectionObserver)
                    CapabilityRow(label: "Resize Observer", supported: info.supportsResizeObserver)
                    CapabilityRow(label: "Mutation Observer", supported: info.supportsMutationObserver)
                    CapabilityRow(label: "Performance Observer", supported: info.supportsPerformanceObserver)
                }

                Section("Security & Payments") {
                    CapabilityRow(label: "Crypto", supported: info.supportsCrypto)
                    CapabilityRow(label: "Credentials", supported: info.supportsCredentials)
                    CapabilityRow(label: "Payment Request", supported: info.supportsPaymentRequest)
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

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red)
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

#Preview {
    InfoView()
}
