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

// MARK: - Configuration Settings View (Requires WebView Reload)

struct ConfigurationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var webViewID: UUID

    // Store initial values for change detection
    @State private var initialValues: [String: AnyHashable] = [:]

    private var hasChanges: Bool {
        initialValues != currentValues
    }

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

    // Privacy & Security
    @AppStorage("privateBrowsing") private var privateBrowsing: Bool = false
    @AppStorage("upgradeToHTTPS") private var upgradeToHTTPS: Bool = true

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var currentValues: [String: AnyHashable] {
        [
            "enableJavaScript": enableJavaScript,
            "allowsContentJavaScript": allowsContentJavaScript,
            "minimumFontSize": minimumFontSize,
            "mediaAutoplay": mediaAutoplay,
            "inlineMediaPlayback": inlineMediaPlayback,
            "allowsAirPlay": allowsAirPlay,
            "allowsPictureInPicture": allowsPictureInPicture,
            "preferredContentMode": preferredContentMode,
            "javaScriptCanOpenWindows": javaScriptCanOpenWindows,
            "fraudulentWebsiteWarning": fraudulentWebsiteWarning,
            "elementFullscreenEnabled": elementFullscreenEnabled,
            "suppressesIncrementalRendering": suppressesIncrementalRendering,
            "detectPhoneNumbers": detectPhoneNumbers,
            "detectLinks": detectLinks,
            "detectAddresses": detectAddresses,
            "detectCalendarEvents": detectCalendarEvents,
            "privateBrowsing": privateBrowsing,
            "upgradeToHTTPS": upgradeToHTTPS
        ]
    }

    var body: some View {
        List {
            changesWarningSection
            configCoreSection
            configMediaSection
            configContentModeSection
            configBehaviorSection
            configDataDetectorsSection
            configPrivacySection
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { resetAllToDefaults() }
                    .foregroundStyle(.red)
            }
        }
        .onAppear { initialValues = currentValues }
        .onDisappear { if hasChanges { webViewID = UUID() } }
    }

    // MARK: - Configuration Sections

    @ViewBuilder
    private var changesWarningSection: some View {
        if hasChanges {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Changes will reload WebView")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var configCoreSection: some View {
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
    }

    @ViewBuilder
    private var configMediaSection: some View {
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
    }

    @ViewBuilder
    private var configContentModeSection: some View {
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
        }
    }

    @ViewBuilder
    private var configBehaviorSection: some View {
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
                info: isIPad ? "iPad: Full element fullscreen support." : "iPhone: Limited to video elements only.",
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
    }

    @ViewBuilder
    private var configDataDetectorsSection: some View {
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
        }
    }

    @ViewBuilder
    private var configPrivacySection: some View {
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
        } header: {
            Text("Privacy & Security")
        }
    }

    private func resetAllToDefaults() {
        // Core
        enableJavaScript = true
        allowsContentJavaScript = true
        minimumFontSize = 0

        // Media
        mediaAutoplay = false
        inlineMediaPlayback = true
        allowsAirPlay = true
        allowsPictureInPicture = true

        // Content
        suppressesIncrementalRendering = false
        javaScriptCanOpenWindows = false
        fraudulentWebsiteWarning = true
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
    }
}

// MARK: - Live Settings View (Instant Apply)

struct LiveSettingsView: View {
    // Navigation & Gestures (Dynamic)
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = false
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = false
    @AppStorage("textInteractionEnabled") private var textInteractionEnabled: Bool = true

    // Display (Dynamic)
    @AppStorage("pageZoom") private var pageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var underPageBackgroundColorHex: String = ""

    // Features (Dynamic)
    @AppStorage("findInteractionEnabled") private var findInteractionEnabled: Bool = false

    // User Agent (Dynamic)
    @AppStorage("customUserAgent") private var customUserAgent: String = ""

    // WebView Size
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82

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
            } header: {
                Text("Navigation & Interaction")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Page Zoom")
                        Spacer()
                        Text("\(Int(pageZoom * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $pageZoom, in: 0.5...3.0, step: 0.1)
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
            }

            Section {
                WebViewSizeControl(
                    widthRatio: $webViewWidthRatio,
                    heightRatio: $webViewHeightRatio
                )
            } header: {
                Text("WebView Size")
            }
        }
        .navigationTitle("Live Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
    }

    private func resetToDefaults() {
        // Navigation & Gestures
        allowsBackForwardGestures = false
        allowsLinkPreview = true
        allowZoom = false
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

// MARK: - Permissions Settings

struct PermissionsSettingsView: View {
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

// MARK: - Loaded Settings View (WebView Active - Menu Style)

struct LoadedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var webViewID: UUID

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        LiveSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "bolt.fill",
                            iconColor: .green,
                            title: "Live Settings",
                            description: "Changes apply instantly"
                        )
                    }

                    NavigationLink {
                        ConfigurationSettingsView(webViewID: $webViewID)
                    } label: {
                        SettingsCategoryRow(
                            icon: "gearshape.fill",
                            iconColor: .orange,
                            title: "Configuration",
                            description: "Changes reload WebView"
                        )
                    }
                }

                Section {
                    NavigationLink {
                        PermissionsSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "lock.shield.fill",
                            iconColor: .blue,
                            title: "Permissions",
                            description: "Camera, Microphone, Location"
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Category Row (Shared)

struct SettingsCategoryRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Combined Settings View (For Initial Setup)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Core Settings
    @AppStorage("enableJavaScript") private var enableJavaScript: Bool = true
    @AppStorage("allowsContentJavaScript") private var allowsContentJavaScript: Bool = true
    @AppStorage("allowZoom") private var allowZoom: Bool = false
    @AppStorage("minimumFontSize") private var minimumFontSize: Double = 0

    // Media Settings
    @AppStorage("mediaAutoplay") private var mediaAutoplay: Bool = false
    @AppStorage("inlineMediaPlayback") private var inlineMediaPlayback: Bool = true
    @AppStorage("allowsAirPlay") private var allowsAirPlay: Bool = true
    @AppStorage("allowsPictureInPicture") private var allowsPictureInPicture: Bool = true

    // Navigation & Gestures
    @AppStorage("allowsBackForwardGestures") private var allowsBackForwardGestures: Bool = false
    @AppStorage("allowsLinkPreview") private var allowsLinkPreview: Bool = true
    @AppStorage("findInteractionEnabled") private var findInteractionEnabled: Bool = false

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

    // Display
    @AppStorage("pageZoom") private var pageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var underPageBackgroundColorHex: String = ""

    // WebView Size
    @AppStorage("webViewWidthRatio") private var webViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var webViewHeightRatio: Double = 0.82

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        NavigationStack {
            List {
                coreSection
                mediaSection
                contentModeSection
                behaviorSection
                dataDetectorsSection
                privacySection
                navigationSection
                displaySection
                userAgentSection
                webViewSizeSection
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

    // MARK: - Sections

    @ViewBuilder
    private var coreSection: some View {
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
    }

    @ViewBuilder
    private var mediaSection: some View {
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
    }

    @ViewBuilder
    private var contentModeSection: some View {
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
        }
    }

    @ViewBuilder
    private var behaviorSection: some View {
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
                info: isIPad ? "iPad: Full element fullscreen support." : "iPhone: Limited to video elements only.",
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
    }

    @ViewBuilder
    private var dataDetectorsSection: some View {
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
        }
    }

    @ViewBuilder
    private var privacySection: some View {
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
        } header: {
            Text("Privacy & Security")
        }
    }

    @ViewBuilder
    private var navigationSection: some View {
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
        } header: {
            Text("Navigation & Interaction")
        }
    }

    @ViewBuilder
    private var displaySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Page Zoom")
                    Spacer()
                    Text("\(Int(pageZoom * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $pageZoom, in: 0.5...3.0, step: 0.1)
            }

            ColorPickerRow(
                title: "Under Page Background",
                colorHex: $underPageBackgroundColorHex,
                info: "Background color shown when scrolling beyond page bounds."
            )
        } header: {
            Text("Display")
        }
    }

    @ViewBuilder
    private var userAgentSection: some View {
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
        }
    }

    @ViewBuilder
    private var webViewSizeSection: some View {
        Section {
            WebViewSizeControl(
                widthRatio: $webViewWidthRatio,
                heightRatio: $webViewHeightRatio
            )
        } header: {
            Text("WebView Size")
        }
    }

    private func resetAllToDefaults() {
        // Core
        enableJavaScript = true
        allowsContentJavaScript = true
        allowZoom = false
        minimumFontSize = 0

        // Media
        mediaAutoplay = false
        inlineMediaPlayback = true
        allowsAirPlay = true
        allowsPictureInPicture = true

        // Navigation & Gestures
        allowsBackForwardGestures = false
        allowsLinkPreview = true
        findInteractionEnabled = false

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

#Preview("Loaded Settings") {
    @Previewable @State var id = UUID()
    LoadedSettingsView(webViewID: $id)
}

#Preview("Configuration Settings") {
    @Previewable @State var id = UUID()
    NavigationStack {
        ConfigurationSettingsView(webViewID: $id)
    }
}

#Preview("Live Settings") {
    NavigationStack {
        LiveSettingsView()
    }
}
