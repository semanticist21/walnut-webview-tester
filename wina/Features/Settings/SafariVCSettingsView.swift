//
//  SafariVCSettingsView.swift
//  wina
//
//  Created by Claude on 12/11/25.
//

import SwiftUI

// MARK: - SafariVC Settings View (Menu Style - Unified)

struct SafariVCSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var webViewID: UUID

    init(webViewID: Binding<UUID> = .constant(UUID())) {
        self._webViewID = webViewID
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SafariVCConfigurationSettingsView(webViewID: $webViewID)
                    } label: {
                        SettingsCategoryRow(
                            icon: "gearshape.fill",
                            iconColor: .orange,
                            title: "Configuration",
                            description: "Behavior, Style, Colors"
                        )
                    }
                } footer: {
                    Text("All SafariVC settings are applied at creation time. Changes require reload.")
                        .font(.caption)
                }
            }
            .navigationTitle("SafariVC Settings")
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

// MARK: - SafariVC Configuration Settings

struct SafariVCConfigurationSettingsView: View {
    @Binding var webViewID: UUID

    // Store initial values for change detection
    @State private var initialValues: [String: AnyHashable] = [:]

    private var hasChanges: Bool {
        initialValues != currentValues
    }

    // SafariVC Configuration
    @AppStorage("safariEntersReaderIfAvailable") private var entersReaderIfAvailable: Bool = false
    @AppStorage("safariBarCollapsingEnabled") private var barCollapsingEnabled: Bool = true
    @AppStorage("safariDismissButtonStyle") private var dismissButtonStyle: Int = 0
    @AppStorage("safariControlTintColorHex") private var controlTintColorHex: String = ""
    @AppStorage("safariBarTintColorHex") private var barTintColorHex: String = ""

    private var currentValues: [String: AnyHashable] {
        [
            "entersReaderIfAvailable": entersReaderIfAvailable,
            "barCollapsingEnabled": barCollapsingEnabled,
            "dismissButtonStyle": dismissButtonStyle,
            "controlTintColorHex": controlTintColorHex,
            "barTintColorHex": barTintColorHex
        ]
    }

    var body: some View {
        List {
            changesWarningSection
            behaviorSection
            uiStyleSection
            colorsSection
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .onAppear {
            initialValues = currentValues
        }
        .onDisappear {
            if hasChanges {
                webViewID = UUID()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var changesWarningSection: some View {
        if hasChanges {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Changes will reload SafariVC")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var behaviorSection: some View {
        Section {
            SettingToggleRow(
                title: "Reader Mode",
                isOn: $entersReaderIfAvailable,
                info: "Automatically enters Reader mode if available for the page."
            )
            SettingToggleRow(
                title: "Bar Collapsing",
                isOn: $barCollapsingEnabled,
                info: "Allows the navigation bar to collapse when scrolling down."
            )
        } header: {
            Text("Behavior")
        }
    }

    @ViewBuilder
    private var uiStyleSection: some View {
        Section {
            Picker("Dismiss Button", selection: $dismissButtonStyle) {
                Text("Done").tag(0)
                Text("Close").tag(1)
                Text("Cancel").tag(2)
            }
        } header: {
            Text("UI Style")
        }
    }

    @ViewBuilder
    private var colorsSection: some View {
        Section {
            ColorPickerRow(
                title: "Control Tint",
                colorHex: $controlTintColorHex,
                info: "Tint color for buttons and other controls."
            )
            ColorPickerRow(
                title: "Bar Tint",
                colorHex: $barTintColorHex,
                info: "Background color of the navigation bar."
            )
        } header: {
            Text("Colors")
        }
    }

    private func resetToDefaults() {
        entersReaderIfAvailable = false
        barCollapsingEnabled = true
        dismissButtonStyle = 0
        controlTintColorHex = ""
        barTintColorHex = ""
    }
}

#Preview("SafariVC Settings") {
    SafariVCSettingsView()
}

#Preview("SafariVC Configuration") {
    @Previewable @State var id = UUID()
    NavigationStack {
        SafariVCConfigurationSettingsView(webViewID: $id)
    }
}
