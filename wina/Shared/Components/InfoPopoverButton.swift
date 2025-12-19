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
                .padding(6)
                .contentShape(Rectangle())
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

// MARK: - Rich Content Info Popover Button

/// A button that shows an info popover with custom content when tapped
struct RichInfoPopoverButton<S: ShapeStyle, Content: View>: View {
    let iconColor: S
    @ViewBuilder let content: () -> Content

    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(iconColor)
                .font(.footnote)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInfo) {
            content()
                .font(.footnote)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}

// Convenience initializer with default color
extension RichInfoPopoverButton where S == Color {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.iconColor = .secondary
        self.content = content
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
                .padding(6)
                .contentShape(Rectangle())
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
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote)
            .padding()
            .frame(maxWidth: 280)
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
