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
                    SafariSettingToggleRow(
                        title: "Reader Mode",
                        isOn: $entersReaderIfAvailable,
                        info: "Automatically enters Reader mode if available for the page."
                    )
                    SafariSettingToggleRow(
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
                    SafariColorPickerRow(
                        title: "Control Tint",
                        colorHex: $controlTintColorHex,
                        info: "Tint color for buttons and other controls."
                    )
                    SafariColorPickerRow(
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

// MARK: - Safari Setting Toggle Row

private struct SafariSettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let info: String?

    @State private var showInfo = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Text(title)
                if let info {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showInfo) {
                        Text(info)
                            .font(.footnote)
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
    }
}

// MARK: - Safari Color Picker Row

private struct SafariColorPickerRow: View {
    let title: String
    @Binding var colorHex: String
    let info: String?

    @State private var showInfo: Bool = false
    @State private var selectedColor: Color = .clear

    init(title: String, colorHex: Binding<String>, info: String? = nil) {
        self.title = title
        self._colorHex = colorHex
        self.info = info
        self._selectedColor = State(initialValue: Color(hex: colorHex.wrappedValue) ?? .clear)
    }

    var body: some View {
        HStack {
            Text(title)
            if let info {
                Button {
                    showInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.caption)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer()
            if !colorHex.isEmpty {
                Button {
                    colorHex = ""
                    selectedColor = .clear
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { _, newValue in
                    colorHex = newValue.toHex() ?? ""
                }
        }
    }
}

// MARK: - Color Extensions

private extension Color {
    init?(hex: String) {
        guard !hex.isEmpty else { return nil }
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    SafariVCSettingsView()
}
