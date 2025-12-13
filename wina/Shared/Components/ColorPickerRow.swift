//
//  ColorPickerRow.swift
//  wina
//
//  Shared color picker row component with info popover
//

import SwiftUI

// MARK: - Color Picker Row

/// A color picker row with optional info button and clear functionality
struct ColorPickerRow: View {
    let title: String
    @Binding var colorHex: String
    var info: String?
    var deprecatedInfo: String?

    private var selectedColor: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) ?? .accentColor },
            set: { newValue in
                colorHex = newValue.toHex() ?? ""
            }
        )
    }

    var body: some View {
        HStack {
            Text(title)
            if let deprecatedInfo {
                DeprecatedPopoverButton(text: deprecatedInfo)
            }
            if let info {
                InfoPopoverButton(text: info)
            }
            Spacer()
            if !colorHex.isEmpty {
                Button {
                    colorHex = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            ColorPicker("", selection: selectedColor, supportsOpacity: false)
                .labelsHidden()
        }
    }
}

#Preview {
    List {
        ColorPickerRow(
            title: "Background Color",
            colorHex: .constant("#FF5733"),
            info: "Background color shown when scrolling beyond page bounds."
        )
        ColorPickerRow(
            title: "Tint Color",
            colorHex: .constant("")
        )
    }
}
