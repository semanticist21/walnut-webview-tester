//
//  InfoPopoverButton.swift
//  wina
//
//  Reusable info button with popover
//

import SwiftUI

// MARK: - Info Popover Button

/// A button that shows an info popover when tapped
struct InfoPopoverButton<S: ShapeStyle>: View {
    let text: String
    let iconColor: S

    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(iconColor)
                .font(.footnote)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInfo) {
            Text(text)
                .font(.footnote)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}

// Convenience initializer with default color
extension InfoPopoverButton where S == Color {
    init(text: String) {
        self.text = text
        self.iconColor = .secondary
    }
}

// MARK: - Deprecated Popover Button

/// A button that shows a deprecation warning popover when tapped
struct DeprecatedPopoverButton: View {
    let text: String

    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.footnote)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInfo) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Deprecated")
                        .fontWeight(.semibold)
                }
                Text(text)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}

#Preview {
    HStack {
        Text("Setting Name")
        InfoPopoverButton(text: "This is helpful information about the setting.")
        Spacer()
    }
    .padding()
}

#Preview("Deprecated") {
    HStack {
        Text("Bar Tint")
        DeprecatedPopoverButton(text: "Deprecated in iOS 26. Interferes with Liquid Glass effects.")
        Spacer()
    }
    .padding()
}
