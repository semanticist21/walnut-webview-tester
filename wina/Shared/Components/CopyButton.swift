//
//  CopyButton.swift
//  wina
//
//  Reusable button components for section headers and actions.
//

import SwiftUI

// MARK: - Header Action Button

/// Compact action button for section headers with icon and text label
struct HeaderActionButton: View {
    let label: String
    let icon: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .capsule)
        .disabled(isDisabled)
    }
}

// MARK: - Copy Button (Header Style)

/// Copy button with icon and text label for section headers
struct CopyButton: View {
    let text: String
    var label: String = "Copy"
    var onCopy: (() -> Void)?

    var body: some View {
        Button {
            guard !text.isEmpty else { return }
            UIPasteboard.general.string = text
            onCopy?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                Text(label)
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .capsule)
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
            guard !text.isEmpty else { return }
            UIPasteboard.general.string = text
            onCopy?()
        }
        .disabled(text.isEmpty)
    }
}

// MARK: - Copied Feedback Toast

/// Toast message for copy feedback
struct CopiedFeedbackToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.8), in: Capsule())
            .padding(.bottom, 20)
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
            Text("Actions")
            Spacer()
            HeaderActionButton(label: "Edit", icon: "pencil") { }
            HeaderActionButton(label: "Encode", icon: "arrow.right.circle") { }
        }

        HStack {
            Text("URL")
            Spacer()
            CopyIconButton(text: "https://example.com")
        }
    }
    .padding()
}
