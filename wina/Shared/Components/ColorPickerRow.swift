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
