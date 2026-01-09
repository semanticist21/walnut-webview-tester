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
                        AppSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "app.badge.fill",
                            iconColor: .cyan,
                            title: "App Settings",
                            description: "Language, preferences"
                        )
                    }
                } header: {
                    Text("App")
                }

                Section {
                    NavigationLink {
                        SafariVCMenuSettingsView()
                    } label: {
                        SettingsCategoryRow(
                            icon: "menubar.rectangle",
                            iconColor: .indigo,
                            title: "Menu",
                            description: "Customize toolbar & app bar"
                        )
                    }
                } header: {
                    Text("Developer Tools Settings")
                }

                Section {
                    NavigationLink {
                        SafariVCConfigurationSettingsView(webViewID: $webViewID)
                    } label: {
                        SettingsCategoryRow(
                            icon: "gearshape.fill",
                            iconColor: .orange,
                            title: "Configuration",
                            description: "All changes reload SafariVC"
                        )
                    }
                } header: {
                    Text("SafariVC Settings")
                }
            }
            .navigationTitle(Text(verbatim: "SafariVC Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Show interstitial ad (30% probability, once per session)
                await AdManager.shared.showInterstitialAd(
                    options: AdOptions(id: "settings_sheet"),
                    adUnitId: AdManager.interstitialAdUnitId
                )
            }
        }
    }
}

// MARK: - SafariVC Configuration Settings

struct SafariVCConfigurationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var webViewID: UUID

    // AppStorage (persistent)
    @AppStorage("safariEntersReaderIfAvailable") private var storedEntersReaderIfAvailable: Bool = false
    @AppStorage("safariBarCollapsingEnabled") private var storedBarCollapsingEnabled: Bool = true
    @AppStorage("safariDismissButtonStyle") private var storedDismissButtonStyle: Int = 0
    @AppStorage("safariControlTintColorHex") private var storedControlTintColorHex: String = ""
    @AppStorage("safariBarTintColorHex") private var storedBarTintColorHex: String = ""
    @AppStorage("safariWidthRatio") private var storedWidthRatio: Double = 1.0
    @AppStorage("safariHeightRatio") private var storedHeightRatio: Double = 0.82

    // Local state (editable)
    @State private var entersReaderIfAvailable: Bool = false
    @State private var barCollapsingEnabled: Bool = true
    @State private var dismissButtonStyle: Int = 0
    @State private var controlTintColorHex: String = ""
    @State private var barTintColorHex: String = ""
    @State private var widthRatio: Double = 1.0
    @State private var heightRatio: Double = 0.82

    private var hasChanges: Bool {
        entersReaderIfAvailable != storedEntersReaderIfAvailable ||
        barCollapsingEnabled != storedBarCollapsingEnabled ||
        dismissButtonStyle != storedDismissButtonStyle ||
        controlTintColorHex != storedControlTintColorHex ||
        barTintColorHex != storedBarTintColorHex ||
        abs(widthRatio - storedWidthRatio) > 0.001 ||
        abs(heightRatio - storedHeightRatio) > 0.001
    }

    var body: some View {
        List {
            behaviorSection
            uiStyleSection
            colorsSection
            sizeSection
            resetSection
        }
        .navigationTitle(Text(verbatim: "Configuration"))
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
                    Text("Changes will reload SafariVC")
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
        entersReaderIfAvailable = storedEntersReaderIfAvailable
        barCollapsingEnabled = storedBarCollapsingEnabled
        dismissButtonStyle = storedDismissButtonStyle
        controlTintColorHex = storedControlTintColorHex
        barTintColorHex = storedBarTintColorHex
        widthRatio = storedWidthRatio
        heightRatio = storedHeightRatio
    }

    private func applyChanges() {
        storedEntersReaderIfAvailable = entersReaderIfAvailable
        storedBarCollapsingEnabled = barCollapsingEnabled
        storedDismissButtonStyle = dismissButtonStyle
        storedControlTintColorHex = controlTintColorHex
        storedBarTintColorHex = barTintColorHex
        storedWidthRatio = widthRatio
        storedHeightRatio = heightRatio
        webViewID = UUID()
        dismiss()
    }

    // MARK: - Sections

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
                info: "Tint color for buttons and other controls.",
                deprecatedInfo: "Deprecated in iOS 26. Interferes with Liquid Glass background effects."
            )
            ColorPickerRow(
                title: "Bar Tint",
                colorHex: $barTintColorHex,
                info: "Background color of the navigation bar.",
                deprecatedInfo: "Deprecated in iOS 26. Interferes with Liquid Glass background effects."
            )
        } header: {
            Text("Colors")
        } footer: {
            Text("These options are deprecated in iOS 26 and may not have visible effects.")
        }
    }

    @ViewBuilder
    private var sizeSection: some View {
        Section {
            WebViewSizeControl(
                widthRatio: $widthRatio,
                heightRatio: $heightRatio
            )
        } header: {
            Text("Size")
        }
    }

    @ViewBuilder
    private var resetSection: some View {
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

    private func resetToDefaults() {
        entersReaderIfAvailable = false
        barCollapsingEnabled = true
        dismissButtonStyle = 0
        controlTintColorHex = ""
        barTintColorHex = ""
        widthRatio = 1.0
        heightRatio = 0.82
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
