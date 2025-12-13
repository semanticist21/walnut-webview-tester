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

    // AppStorage (persistent)
    @AppStorage("enableJavaScript") private var storedEnableJavaScript: Bool = true
    @AppStorage("allowsContentJavaScript") private var storedAllowsContentJavaScript: Bool = true
    @AppStorage("minimumFontSize") private var storedMinimumFontSize: Double = 0
    @AppStorage("mediaAutoplay") private var storedMediaAutoplay: Bool = false
    @AppStorage("inlineMediaPlayback") private var storedInlineMediaPlayback: Bool = true
    @AppStorage("allowsAirPlay") private var storedAllowsAirPlay: Bool = true
    @AppStorage("allowsPictureInPicture") private var storedAllowsPictureInPicture: Bool = true
    @AppStorage("preferredContentMode") private var storedPreferredContentMode: Int = 0
    @AppStorage("javaScriptCanOpenWindows") private var storedJavaScriptCanOpenWindows: Bool = false
    @AppStorage("fraudulentWebsiteWarning") private var storedFraudulentWebsiteWarning: Bool = true
    @AppStorage("elementFullscreenEnabled") private var storedElementFullscreenEnabled: Bool = false
    @AppStorage("suppressesIncrementalRendering") private var storedSuppressesIncrementalRendering: Bool = false
    @AppStorage("detectPhoneNumbers") private var storedDetectPhoneNumbers: Bool = false
    @AppStorage("detectLinks") private var storedDetectLinks: Bool = false
    @AppStorage("detectAddresses") private var storedDetectAddresses: Bool = false
    @AppStorage("detectCalendarEvents") private var storedDetectCalendarEvents: Bool = false
    @AppStorage("privateBrowsing") private var storedPrivateBrowsing: Bool = false
    @AppStorage("upgradeToHTTPS") private var storedUpgradeToHTTPS: Bool = true

    // Local state (editable)
    @State private var enableJavaScript: Bool = true
    @State private var allowsContentJavaScript: Bool = true
    @State private var minimumFontSize: Double = 0
    @State private var mediaAutoplay: Bool = false
    @State private var inlineMediaPlayback: Bool = true
    @State private var allowsAirPlay: Bool = true
    @State private var allowsPictureInPicture: Bool = true
    @State private var preferredContentMode: Int = 0
    @State private var javaScriptCanOpenWindows: Bool = false
    @State private var fraudulentWebsiteWarning: Bool = true
    @State private var elementFullscreenEnabled: Bool = false
    @State private var suppressesIncrementalRendering: Bool = false
    @State private var detectPhoneNumbers: Bool = false
    @State private var detectLinks: Bool = false
    @State private var detectAddresses: Bool = false
    @State private var detectCalendarEvents: Bool = false
    @State private var privateBrowsing: Bool = false
    @State private var upgradeToHTTPS: Bool = true

    private var isIPad: Bool {
        UIDevice.current.isIPad
    }

    private var hasChanges: Bool {
        enableJavaScript != storedEnableJavaScript ||
        allowsContentJavaScript != storedAllowsContentJavaScript ||
        minimumFontSize != storedMinimumFontSize ||
        mediaAutoplay != storedMediaAutoplay ||
        inlineMediaPlayback != storedInlineMediaPlayback ||
        allowsAirPlay != storedAllowsAirPlay ||
        allowsPictureInPicture != storedAllowsPictureInPicture ||
        preferredContentMode != storedPreferredContentMode ||
        javaScriptCanOpenWindows != storedJavaScriptCanOpenWindows ||
        fraudulentWebsiteWarning != storedFraudulentWebsiteWarning ||
        elementFullscreenEnabled != storedElementFullscreenEnabled ||
        suppressesIncrementalRendering != storedSuppressesIncrementalRendering ||
        detectPhoneNumbers != storedDetectPhoneNumbers ||
        detectLinks != storedDetectLinks ||
        detectAddresses != storedDetectAddresses ||
        detectCalendarEvents != storedDetectCalendarEvents ||
        privateBrowsing != storedPrivateBrowsing ||
        upgradeToHTTPS != storedUpgradeToHTTPS
    }

    var body: some View {
        List {
            configCoreSection
            configMediaSection
            configContentModeSection
            configBehaviorSection
            configDataDetectorsSection
            configPrivacySection
            resetSection
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Apply") { applyChanges() }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if hasChanges {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Changes will reload WebView")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasChanges)
        .onAppear { loadFromStorage() }
    }

    private func loadFromStorage() {
        enableJavaScript = storedEnableJavaScript
        allowsContentJavaScript = storedAllowsContentJavaScript
        minimumFontSize = storedMinimumFontSize
        mediaAutoplay = storedMediaAutoplay
        inlineMediaPlayback = storedInlineMediaPlayback
        allowsAirPlay = storedAllowsAirPlay
        allowsPictureInPicture = storedAllowsPictureInPicture
        preferredContentMode = storedPreferredContentMode
        javaScriptCanOpenWindows = storedJavaScriptCanOpenWindows
        fraudulentWebsiteWarning = storedFraudulentWebsiteWarning
        elementFullscreenEnabled = storedElementFullscreenEnabled
        suppressesIncrementalRendering = storedSuppressesIncrementalRendering
        detectPhoneNumbers = storedDetectPhoneNumbers
        detectLinks = storedDetectLinks
        detectAddresses = storedDetectAddresses
        detectCalendarEvents = storedDetectCalendarEvents
        privateBrowsing = storedPrivateBrowsing
        upgradeToHTTPS = storedUpgradeToHTTPS
    }

    private func applyChanges() {
        storedEnableJavaScript = enableJavaScript
        storedAllowsContentJavaScript = allowsContentJavaScript
        storedMinimumFontSize = minimumFontSize
        storedMediaAutoplay = mediaAutoplay
        storedInlineMediaPlayback = inlineMediaPlayback
        storedAllowsAirPlay = allowsAirPlay
        storedAllowsPictureInPicture = allowsPictureInPicture
        storedPreferredContentMode = preferredContentMode
        storedJavaScriptCanOpenWindows = javaScriptCanOpenWindows
        storedFraudulentWebsiteWarning = fraudulentWebsiteWarning
        storedElementFullscreenEnabled = elementFullscreenEnabled
        storedSuppressesIncrementalRendering = suppressesIncrementalRendering
        storedDetectPhoneNumbers = detectPhoneNumbers
        storedDetectLinks = detectLinks
        storedDetectAddresses = detectAddresses
        storedDetectCalendarEvents = detectCalendarEvents
        storedPrivateBrowsing = privateBrowsing
        storedUpgradeToHTTPS = upgradeToHTTPS
        webViewID = UUID()
        dismiss()
    }

    @ViewBuilder
    private var resetSection: some View {
        Section {
            HStack {
                Spacer()
                GlassActionButton("Reset", icon: "arrow.counterclockwise", style: .destructive) {
                    resetAllToDefaults()
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Configuration Sections

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

// MARK: - Live Settings View (Apply to Save)

struct LiveSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // AppStorage (persistent)
    @AppStorage("allowsBackForwardGestures") private var storedAllowsBackForwardGestures: Bool = false
    @AppStorage("allowsLinkPreview") private var storedAllowsLinkPreview: Bool = true
    @AppStorage("allowZoom") private var storedAllowZoom: Bool = false
    @AppStorage("textInteractionEnabled") private var storedTextInteractionEnabled: Bool = true
    @AppStorage("pageZoom") private var storedPageZoom: Double = 1.0
    @AppStorage("underPageBackgroundColor") private var storedUnderPageBackgroundColorHex: String = ""
    @AppStorage("findInteractionEnabled") private var storedFindInteractionEnabled: Bool = false
    @AppStorage("customUserAgent") private var storedCustomUserAgent: String = ""
    @AppStorage("webViewWidthRatio") private var storedWebViewWidthRatio: Double = 1.0
    @AppStorage("webViewHeightRatio") private var storedWebViewHeightRatio: Double = 0.82

    // Local state (editable)
    @State private var allowsBackForwardGestures: Bool = false
    @State private var allowsLinkPreview: Bool = true
    @State private var allowZoom: Bool = false
    @State private var textInteractionEnabled: Bool = true
    @State private var pageZoom: Double = 1.0
    @State private var underPageBackgroundColorHex: String = ""
    @State private var findInteractionEnabled: Bool = false
    @State private var customUserAgent: String = ""
    @State private var webViewWidthRatio: Double = 1.0
    @State private var webViewHeightRatio: Double = 0.82

    private var hasChanges: Bool {
        allowsBackForwardGestures != storedAllowsBackForwardGestures ||
        allowsLinkPreview != storedAllowsLinkPreview ||
        allowZoom != storedAllowZoom ||
        textInteractionEnabled != storedTextInteractionEnabled ||
        pageZoom != storedPageZoom ||
        underPageBackgroundColorHex != storedUnderPageBackgroundColorHex ||
        findInteractionEnabled != storedFindInteractionEnabled ||
        customUserAgent != storedCustomUserAgent ||
        webViewWidthRatio != storedWebViewWidthRatio ||
        webViewHeightRatio != storedWebViewHeightRatio
    }

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
                NavigationLink {
                    UserAgentPickerView(localUserAgent: $customUserAgent)
                } label: {
                    HStack {
                        Text("User Agent")
                        Spacer()
                        Text(customUserAgent.isEmpty ? "Default" : "Custom")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } header: {
                Text("Identity")
            }

            Section {
                WebViewSizeControl(
                    widthRatio: $webViewWidthRatio,
                    heightRatio: $webViewHeightRatio
                )
            } header: {
                Text("WebView Size")
            }

            Section {
                HStack {
                    Spacer()
                    GlassActionButton("Reset", icon: "arrow.counterclockwise", style: .destructive) {
                        resetToDefaults()
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Live Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Apply") { applyChanges() }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if hasChanges {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Changes will apply to WebView")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasChanges)
        .onAppear { loadFromStorage() }
    }

    private func loadFromStorage() {
        allowsBackForwardGestures = storedAllowsBackForwardGestures
        allowsLinkPreview = storedAllowsLinkPreview
        allowZoom = storedAllowZoom
        textInteractionEnabled = storedTextInteractionEnabled
        pageZoom = storedPageZoom
        underPageBackgroundColorHex = storedUnderPageBackgroundColorHex
        findInteractionEnabled = storedFindInteractionEnabled
        customUserAgent = storedCustomUserAgent
        webViewWidthRatio = storedWebViewWidthRatio
        webViewHeightRatio = storedWebViewHeightRatio
    }

    private func applyChanges() {
        storedAllowsBackForwardGestures = allowsBackForwardGestures
        storedAllowsLinkPreview = allowsLinkPreview
        storedAllowZoom = allowZoom
        storedTextInteractionEnabled = textInteractionEnabled
        storedPageZoom = pageZoom
        storedUnderPageBackgroundColorHex = underPageBackgroundColorHex
        storedFindInteractionEnabled = findInteractionEnabled
        storedCustomUserAgent = customUserAgent
        storedWebViewWidthRatio = webViewWidthRatio
        storedWebViewHeightRatio = webViewHeightRatio
        dismiss()
    }

    private func resetToDefaults() {
        allowsBackForwardGestures = false
        allowsLinkPreview = true
        allowZoom = false
        textInteractionEnabled = true
        pageZoom = 1.0
        underPageBackgroundColorHex = ""
        findInteractionEnabled = false
        customUserAgent = ""
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
    var icon: String? = nil
    var iconColor: Color = .accentColor
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
            }

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
        UIDevice.current.isIPad
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
                resetSection
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

    @ViewBuilder
    private var resetSection: some View {
        Section {
            HStack {
                Spacer()
                GlassActionButton("Reset", icon: "arrow.counterclockwise", style: .destructive) {
                    resetAllToDefaults()
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
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
            NavigationLink {
                UserAgentPickerView()
            } label: {
                HStack {
                    Text("User Agent")
                    Spacer()
                    Text(customUserAgent.isEmpty ? "Default" : "Custom")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } header: {
            Text("Identity")
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
        ScreenUtility.screenSize
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
