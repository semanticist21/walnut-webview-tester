//
//  CopyButton.swift
//  wina
//
//  Reusable copy button for copying text to clipboard.
//

import SwiftUI

// MARK: - Copy Button (Header Style)

/// Copy button with icon and text label for section headers
struct CopyButton: View {
    let text: String
    var label: String = "Copy"
    var onCopy: (() -> Void)?

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            onCopy?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                Text(label)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.fill.tertiary, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
    }
}

// MARK: - Copy Icon Button

/// Compact copy button with icon only
struct CopyIconButton: View {
    let text: String
    var size: GlassIconButton.Size = .small
    var onCopy: (() -> Void)?

    var body: some View {
        GlassIconButton(icon: "doc.on.doc", size: size) {
            UIPasteboard.general.string = text
            onCopy?()
        }
        .disabled(text.isEmpty)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Key")
            Spacer()
            CopyButton(text: "some-key-value")
        }

        HStack {
            Text("URL")
            Spacer()
            CopyIconButton(text: "https://example.com")
        }
    }
    .padding()
}
