//
//  SafariVCSettingsView.swift
//  wina
//
//  Created by Claude on 12/11/25.
//

import SwiftUI

// MARK: - SafariVC Settings View

struct SafariVCSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // SafariVC Configuration
    @AppStorage("safariEntersReaderIfAvailable") private var entersReaderIfAvailable: Bool = false
    @AppStorage("safariBarCollapsingEnabled") private var barCollapsingEnabled: Bool = true
    @AppStorage("safariDismissButtonStyle") private var dismissButtonStyle: Int = 0 // 0: done, 1: close, 2: cancel
    @AppStorage("safariControlTintColorHex") private var controlTintColorHex: String = ""
    @AppStorage("safariBarTintColorHex") private var barTintColorHex: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("SFSafariViewController has limited configuration options compared to WKWebView.", systemImage: "info.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

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

                Section {
                    Picker("Dismiss Button", selection: $dismissButtonStyle) {
                        Text("Done").tag(0)
                        Text("Close").tag(1)
                        Text("Cancel").tag(2)
                    }
                } header: {
                    Text("UI Style")
                } footer: {
                    Text("Style of the button used to dismiss SafariViewController")
                }

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
                } footer: {
                    Text("Leave empty to use system defaults")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features Not Available")
                            .font(.subheadline.weight(.semibold))
                        Text("JavaScript control, Custom User-Agent, Content Mode, Data Detectors, Privacy settings, and most other WKWebView options are not available in SafariViewController.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Limitations")
                }
            }
            .navigationTitle("SafariVC Settings")
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
        entersReaderIfAvailable = false
        barCollapsingEnabled = true
        dismissButtonStyle = 0
        controlTintColorHex = ""
        barTintColorHex = ""
    }
}

#Preview {
    SafariVCSettingsView()
}
