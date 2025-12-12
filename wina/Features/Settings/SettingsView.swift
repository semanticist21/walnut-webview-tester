//
//  SettingsView.swift
//  wina
//
//  Created by Claude on 12/7/25.
//

import SwiftUI
import AVFoundation
import Combine
import CoreLocation

// MARK: - Static Settings View (Requires WebView Reload)

struct StaticSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("These settings require WebView reload to take effect.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Section {
                    NavigationLink {
                        ConfigurationSettingsDetailView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "gearshape.2",
                            title: "Configuration",
                            description: "JavaScript, Media, Content Mode, Behavior, Data Detectors"
                        )
                    }

                    NavigationLink {
                        PrivacySecuritySettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "lock.shield",
                            title: "Privacy & Security",
                            description: "Private Browsing, HTTPS Upgrade"
                        )
                    }

                    NavigationLink {
                        PermissionsSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "hand.raised",
                            title: "Permissions",
                            description: "Camera, Microphone, Location for WebRTC & Geolocation"
                        )
                    }
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset All") {
                        resetAllToDefaults()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resetAllToDefaults() {
        // Core
        UserDefaults.standard.set(true, forKey: "enableJavaScript")
        UserDefaults.standard.set(true, forKey: "allowsContentJavaScript")
        UserDefaults.standard.set(0.0, forKey: "minimumFontSize")

        // Media
        UserDefaults.standard.set(false, forKey: "mediaAutoplay")
        UserDefaults.standard.set(true, forKey: "inlineMediaPlayback")
        UserDefaults.standard.set(true, forKey: "allowsAirPlay")
        UserDefaults.standard.set(true, forKey: "allowsPictureInPicture")

        // Content
        UserDefaults.standard.set(false, forKey: "suppressesIncrementalRendering")
        UserDefaults.standard.set(false, forKey: "javaScriptCanOpenWindows")
        UserDefaults.standard.set(true, forKey: "fraudulentWebsiteWarning")
        UserDefaults.standard.set(false, forKey: "elementFullscreenEnabled")

        // Data Detectors
        UserDefaults.standard.set(false, forKey: "detectPhoneNumbers")
        UserDefaults.standard.set(false, forKey: "detectLinks")
        UserDefaults.standard.set(false, forKey: "detectAddresses")
        UserDefaults.standard.set(false, forKey: "detectCalendarEvents")

        // Privacy & Security
        UserDefaults.standard.set(false, forKey: "privateBrowsing")
        UserDefaults.standard.set(true, forKey: "upgradeToHTTPS")

        // Content Mode
        UserDefaults.standard.set(0, forKey: "preferredContentMode")
    }
}

// MARK: - Settings Category Row

private struct SettingsCategoryRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Configuration Settings Detail View

private struct ConfigurationSettingsDetailView: View {
    // Core Settings
    @AppStorage("enableJavaScript") private var enableJavaScript: Bool = true
    @AppStorage("allowsContentJavaScript") private var allowsContentJavaScript: Bool = true
    @AppStorage("minimumFontSize") private var minimumFontSize: Double = 0

    // Media Settings
    @AppStorage("mediaAutoplay") private var mediaAutoplay: Bool = false
    @AppStorage("inlineMediaPlayback") private var inlineMediaPlayback: Bool = true
    @AppStorage("allowsAirPlay") private var allowsAirPlay: Bool = true
    @AppStorage("allowsPictureInPicture") private var allowsPictureInPicture: Bool = true

    // Content Mode
    @AppStorage("preferredContentMode") private var preferredContentMode: Int = 0

    // Behavior Settings
    @AppStorage("javaScriptCanOpenWindows") private var javaScriptCanOpenWindows: Bool = false
    @AppStorage("fraudulentWebsiteWarning") private var fraudulentWebsiteWarning: Bool = true
    @AppStorage("elementFullscreenEnabled") private var elementFullscreenEnabled: Bool = false
    @AppStorage("suppressesIncrementalRendering") private var suppressesIncrementalRendering: Bool = false

    // Data Detectors
    @AppStorage("detectPhoneNumbers") private var detectPhoneNumbers: Bool = false
    @AppStorage("detectLinks") private var detectLinks: Bool = false
    @AppStorage("detectAddresses") private var detectAddresses: Bool = false
    @AppStorage("detectCalendarEvents") private var detectCalendarEvents: Bool = false

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        List {
            Section {
                SettingToggleRow(
                    title: "JavaScript",
                    isOn: $enableJavaScript,
                    info: "Master switch for all JavaScript execution in WebView."
                )
                SettingToggleRow(
                    title: "Content JavaScript",
                    isOn: $allowsContentJavaScript,
                    info: "Controls scripts from web pages only. App-injected scripts still work when disabled."
                )
                HStack {
                    Text("Minimum Font Size")
                    Spacer()
                    TextField("0", value: $minimumFontSize, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("pt")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Core")
            }

            Section {
                SettingToggleRow(
                    title: "Auto-play Media",
                    isOn: $mediaAutoplay,
                    info: "Allows videos with autoplay attribute to start without user interaction."
                )
                SettingToggleRow(
                    title: "Inline Playback",
                    isOn: $inlineMediaPlayback,
                    info: "Plays videos inline instead of fullscreen. Required for background video effects."
                )
                SettingToggleRow(
                    title: "AirPlay",
                    isOn: $allowsAirPlay,
                    info: "Enables streaming media to Apple TV and other AirPlay devices."
                )
                SettingToggleRow(
                    title: "Picture in Picture",
                    isOn: $allowsPictureInPicture,
                    info: "Allows videos to continue playing in a floating window."
                )
            } header: {
                Text("Media")
            }

            Section {
                Picker("Content Mode", selection: $preferredContentMode) {
                    Text("Recommended").tag(0)
                    Text("Mobile").tag(1)
                    Text("Desktop").tag(2)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Content Mode")
            } footer: {
                Text("Recommended: System decides • Mobile: Optimized for small screens • Desktop: Full website")
            }

            Section {
                SettingToggleRow(
                    title: "JS Can Open Windows",
                    isOn: $javaScriptCanOpenWindows,
                    info: "Allows window.open() without user gesture. Disable to block pop-ups."
                )
                SettingToggleRow(
                    title: "Fraudulent Website Warning",
                    isOn: $fraudulentWebsiteWarning,
                    info: "Shows warning for suspected phishing or malware sites."
                )
                SettingToggleRow(
                    title: "Element Fullscreen API",
                    isOn: $elementFullscreenEnabled,
                    info: isIPad ? "iPad: Full element fullscreen support.\nWorks with any HTML element." : "iPhone: Limited to video elements only.\niPad recommended for full support.",
                    disabled: !isIPad,
                    disabledLabel: "(iPad only)"
                )
                SettingToggleRow(
                    title: "Suppress Incremental Rendering",
                    isOn: $suppressesIncrementalRendering,
                    info: "Waits for full page load before displaying. May feel slower but cleaner."
                )
            } header: {
                Text("Behavior")
            }

            Section {
                SettingToggleRow(
                    title: "Phone Numbers",
                    isOn: $detectPhoneNumbers,
                    info: "Makes phone numbers tappable to call."
                )
                SettingToggleRow(
                    title: "Links",
                    isOn: $detectLinks,
                    info: "Converts URL-like text to tappable links."
                )
                SettingToggleRow(
                    title: "Addresses",
                    isOn: $detectAddresses,
                    info: "Makes addresses tappable to open in Maps."
                )
                SettingToggleRow(
                    title: "Calendar Events",
                    isOn: $detectCalendarEvents,
                    info: "Detects dates and times, allowing to add to Calendar."
                )
            } header: {
                Text("Data Detectors")
            } footer: {
                Text("Auto-detect content types and convert to interactive links")
            }
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy & Security Settings

private struct PrivacySecuritySettingsView: View {
    @AppStorage("privateBrowsing") private var privateBrowsing: Bool = false
    @AppStorage("upgradeToHTTPS") private var upgradeToHTTPS: Bool = true

    var body: some View {
        List {
            Section {
                SettingToggleRow(
                    title: "Private Browsing",
                    isOn: $privateBrowsing,
                    info: "Uses non-persistent data store. No cookies or cache saved after session."
                )
                SettingToggleRow(
                    title: "Upgrade to HTTPS",
                    isOn: $upgradeToHTTPS,
                    info: "Automatically upgrades HTTP requests to HTTPS for known secure hosts."
                )
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Permissions Settings

private struct PermissionsSettingsView: View {
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @StateObject private var locationDelegate = LocationManagerDelegate()

    var body: some View {
        List {
            Section {
                PermissionRow(
                    title: "Camera",
                    status: permissionText(for: cameraStatus),
                    granted: cameraStatus == .authorized
                ) {
                    requestCameraPermission()
                }

                PermissionRow(
                    title: "Microphone",
                    status: permissionText(for: microphoneStatus),
                    granted: microphoneStatus == .authorized
                ) {
                    requestMicrophonePermission()
                }

                PermissionRow(
                    title: "Location",
                    status: permissionText(for: locationStatus),
                    granted: locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
                ) {
                    requestLocationPermission()
                }
            } footer: {
                Text("Required for WebRTC, Media Devices, and Geolocation APIs")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updatePermissionStatuses()
        }
    }

    private func updatePermissionStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        locationStatus = locationDelegate.locationManager.authorizationStatus
    }

    private func permissionText(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Granted"
        @unknown default: return "Unknown"
        }
    }

    private func permissionText(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }

    private func requestCameraPermission() {
        if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
        } else {
            openSettings()
        }
    }

    private func requestMicrophonePermission() {
        if microphoneStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                }
            }
        } else {
            openSettings()
        }
    }

    private func requestLocationPermission() {
        if locationStatus == .notDetermined {
            locationDelegate.requestPermission { status in
                locationStatus = status
            }
        } else {
            openSettings()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Dynamic Settings View (Live Updates)

struct DynamicSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var webViewID: UUID

    // Navigation & Gestures (Dynamic)
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = true
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = true
    @AppStorage("textInteractionEnabled") private var textInteractionEnabled: Bool = true

    // Display (Dynamic)
    @AppStorage("pageZoom") private var pageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var underPageBackgroundColorHex: String = ""

    // Features (Dynamic)
    @AppStorage("findInteractionEnabled") private var findInteractionEnabled: Bool = false

    // User Agent (Dynamic)
    @AppStorage("customUserAgent") private var customUserAgent: String = ""

    // WebView Size (Triggers Reload)
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("These settings apply immediately without reload.", systemImage: "bolt.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                Section {
                    NavigationLink {
                        InteractionSettingsDetailView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "hand.draw",
                            title: "Navigation & Interaction",
                            description: "Gestures, Zoom, Text Selection, Find"
                        )
                    }

                    NavigationLink {
                        DisplaySettingsDetailView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "textformat.size",
                            title: "Display & Appearance",
                            description: "Page Zoom, Background Color, User-Agent"
                        )
                    }

                    NavigationLink {
                        WebViewSizeSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "rectangle.dashed",
                            title: "WebView Size",
                            description: "Resize for responsive testing (recreates WebView)"
                        )
                    }
                }
            }
            .navigationTitle("Live Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resetToDefaults() {
        // Navigation & Gestures
        allowsBackForwardGestures = true
        allowsLinkPreview = true
        allowZoom = true
        textInteractionEnabled = true

        // Display
        pageZoom = 1.0
        underPageBackgroundColorHex = ""

        // Features
        findInteractionEnabled = false

        // User Agent
        customUserAgent = ""

        // WebView Size (App preset)
        webViewWidthRatio = 1.0
        webViewHeightRatio = 0.82
    }
}

// MARK: - Interaction Settings Detail View

private struct InteractionSettingsDetailView: View {
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = true
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = true
    @AppStorage("textInteractionEnabled") private var textInteractionEnabled: Bool = true
    @AppStorage("findInteractionEnabled") private var findInteractionEnabled: Bool = false

    var body: some View {
        List {
            Section {
                SettingToggleRow(
                    title: "Back/Forward Gestures",
                    isOn: $allowsBackForwardGestures,
                    info: "Enables swipe from edge to navigate history."
                )
                SettingToggleRow(
                    title: "Link Preview",
                    isOn: $allowsLinkPreview,
                    info: "Shows page preview on long-press or 3D Touch on links."
                )
                SettingToggleRow(
                    title: "Ignore Viewport Scale Limits",
                    isOn: $allowZoom,
                    info: "Allows pinch-to-zoom even when the page disables it via viewport meta tag."
                )
                SettingToggleRow(
                    title: "Text Interaction",
                    isOn: $textInteractionEnabled,
                    info: "Enables text selection, copy, and other text interactions."
                )
                SettingToggleRow(
                    title: "Find Interaction",
                    isOn: $findInteractionEnabled,
                    info: "Enables the system find panel (Cmd+F on iPad with keyboard)."
                )
            }
        }
        .navigationTitle("Navigation & Interaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Display Settings Detail View

private struct DisplaySettingsDetailView: View {
    @AppStorage("pageZoom") private var pageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var underPageBackgroundColorHex: String = ""
    @AppStorage("customUserAgent") private var customUserAgent: String = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Page Zoom")
                        Spacer()
                        Text("\(Int(pageZoom * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $pageZoom, in: 0.5...3.0, step: 0.1)
                    HStack {
                        Text("50%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("300%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                ColorPickerRow(
                    title: "Under Page Background",
                    colorHex: $underPageBackgroundColorHex,
                    info: "Background color shown when scrolling beyond page bounds."
                )
            } header: {
                Text("Display")
            }

            Section {
                TextField("Custom User-Agent", text: $customUserAgent, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.system(size: 14, design: .monospaced))

                if !customUserAgent.isEmpty {
                    Button("Clear User-Agent") {
                        customUserAgent = ""
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text("User-Agent")
            } footer: {
                Text("Override the default browser identification string")
            }
        }
        .navigationTitle("Display & Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WebView Size Settings

private struct WebViewSizeSettingsView: View {
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82

    var body: some View {
        List {
            Section {
                WebViewSizeControl(
                    widthRatio: $webViewWidthRatio,
                    heightRatio: $webViewHeightRatio
                )
            } footer: {
                Text("Resize WebView for responsive testing.\n⚠️ Changing size will recreate the WebView.")
            }
        }
        .navigationTitle("WebView Size")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Combined Settings View (For Initial Setup)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

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

    // WebView Size
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ConfigurationSettingsDetailView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "gearshape.2",
                            title: "Configuration",
                            description: "JavaScript, Media, Content Mode, Behavior, Data Detectors"
                        )
                    }

                    NavigationLink {
                        PrivacySecuritySettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "lock.shield",
                            title: "Privacy & Security",
                            description: "Private Browsing, HTTPS Upgrade"
                        )
                    }
                } header: {
                    Text("Static (Requires Reload)")
                } footer: {
                    Text("Changes require WebView reload to take effect")
                }

                Section {
                    NavigationLink {
                        InteractionSettingsDetailView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "hand.draw",
                            title: "Navigation & Interaction",
                            description: "Gestures, Zoom, Text Selection, Find"
                        )
                    }

                    NavigationLink {
                        DisplaySettingsDetailView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "textformat.size",
                            title: "Display & Appearance",
                            description: "Page Zoom, Background Color, User-Agent"
                        )
                    }

                    NavigationLink {
                        WebViewSizeSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "rectangle.dashed",
                            title: "WebView Size",
                            description: "Resize for responsive testing"
                        )
                    }
                } header: {
                    Text("Live (Instant Apply)")
                } footer: {
                    Text("Changes apply immediately without reload")
                }

                Section {
                    NavigationLink {
                        PermissionsSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "hand.raised",
                            title: "Permissions",
                            description: "Camera, Microphone, Location"
                        )
                    }
                } header: {
                    Text("System")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset All") {
                        resetAllToDefaults()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resetAllToDefaults() {
        // Core
        enableJavaScript = true
        allowsContentJavaScript = true
        allowZoom = true
        minimumFontSize = 0

        // Media
        mediaAutoplay = false
        inlineMediaPlayback = true
        allowsAirPlay = true
        allowsPictureInPicture = true

        // Navigation & Gestures
        allowsBackForwardGestures = true
        allowsLinkPreview = true

        // Content
        suppressesIncrementalRendering = false
        javaScriptCanOpenWindows = false
        fraudulentWebsiteWarning = true
        textInteractionEnabled = true
        elementFullscreenEnabled = false

        // Data Detectors
        detectPhoneNumbers = false
        detectLinks = false
        detectAddresses = false
        detectCalendarEvents = false

        // Privacy & Security
        privateBrowsing = false
        upgradeToHTTPS = true

        // Content Mode
        preferredContentMode = 0

        // User Agent
        customUserAgent = ""

        // WebView Size (App preset)
        webViewWidthRatio = 1.0
        webViewHeightRatio = 0.82
    }
}

// MARK: - WebView Size Control

private struct WebViewSizeControl: View {
    @Binding var widthRatio: Double
    @Binding var heightRatio: Double

    private var appContainerHeightRatio: Double {
        let totalUIHeight: CGFloat = 152
        return 1.0 - (totalUIHeight / screenSize.height)
    }

    private var screenSize: CGSize {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return CGSize(width: 393, height: 852)
        }
        return scene.screen.bounds.size
    }

    private var currentWidth: Int {
        Int(screenSize.width * widthRatio)
    }

    private var currentHeight: Int {
        Int(screenSize.height * heightRatio)
    }

    private var isAppContainerSelected: Bool {
        abs(widthRatio - 1.0) < 0.01 && abs(heightRatio - appContainerHeightRatio) < 0.01
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                PresetButton(label: "100%", isSelected: widthRatio == 1.0 && heightRatio == 1.0) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        widthRatio = 1.0
                        heightRatio = 1.0
                    }
                }
                PresetButton(label: "App", isSelected: isAppContainerSelected) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        widthRatio = 1.0
                        heightRatio = appContainerHeightRatio
                    }
                }
                PresetButton(label: "75%", isSelected: widthRatio == 0.75 && heightRatio == 0.75) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        widthRatio = 0.75
                        heightRatio = 0.75
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Width")
                        .font(.subheadline)
                    Spacer()
                    Text("\(currentWidth)pt")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $widthRatio, in: 0.25...1.0, step: 0.01)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Height")
                        .font(.subheadline)
                    Spacer()
                    Text("\(currentHeight)pt")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $heightRatio, in: 0.25...1.0, step: 0.01)
            }

            HStack {
                Spacer()
                Text("\(currentWidth) × \(currentHeight)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PresetButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let status: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundStyle(granted ? .green : .secondary)
                .font(.subheadline)
            Button {
                action()
            } label: {
                Image(systemName: granted ? "checkmark.circle.fill" : "arrow.right.circle")
                    .foregroundStyle(granted ? .green : .blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Location Manager Delegate

private class LocationManagerDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    private var completion: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestPermission(completion: @escaping (CLAuthorizationStatus) -> Void) {
        self.completion = completion
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.completion?(manager.authorizationStatus)
        }
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Static Settings") {
    StaticSettingsView()
}

#Preview("Dynamic Settings") {
    @Previewable @State var id = UUID()
    DynamicSettingsView(webViewID: $id)
}
