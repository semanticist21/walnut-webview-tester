//
//  ConfigurationSettingsView.swift
//  wina
//
//  Extracted from SettingsView.swift for file length compliance
//

import SwiftUI

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
                info: "Allows elements to enter fullscreen mode. Full API available on iPad only; iPhone is limited to video elements.",
                disabled: !isIPad
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

#Preview("Configuration Settings") {
    @Previewable @State var id = UUID()
    NavigationStack {
        ConfigurationSettingsView(webViewID: $id)
    }
}
