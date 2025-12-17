//
//  SourceSupportViews.swift
//  wina
//
//  Supporting views for Sources detail views.
//

import SwiftUI

// MARK: - Source Info Row

struct SourceInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                UIPasteboard.general.string = value
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Attribute Row

struct AttributeRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = "\(name)=\"\(value)\""
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - CSS Property Row

struct CSSPropertyRow: View {
    let property: String
    let value: String

    @State private var isExpanded: Bool = false

    /// Threshold for showing expand/collapse
    private var isLongValue: Bool {
        value.count > 40
    }

    /// Parsed color from value (if any)
    private var parsedColor: Color? {
        CSSColorParser.parse(value)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(property)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
            Text(":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Color preview swatch (before value)
            if let color = parsedColor {
                ColorSwatchView(color: color)
            }

            if isLongValue && !isExpanded {
                Text(value.prefix(35) + "...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if isLongValue {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                UIPasteboard.general.string = "\(property): \(value);"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Expandable URL View

/// Expandable URL view with collapse/expand for long URLs
struct ExpandableURLView: View {
    let url: String
    var onCopy: (() -> Void)?
    @State private var isExpanded: Bool = false

    private var isLongURL: Bool {
        url.count > 60
    }

    private var displayURL: String {
        if isLongURL && !isExpanded {
            // Show domain + truncated path
            if let urlObj = URL(string: url) {
                let host = urlObj.host ?? ""
                let path = urlObj.path
                let truncatedPath = path.count > 20 ? String(path.prefix(20)) + "..." : path
                return host + truncatedPath
            }
            return String(url.prefix(50)) + "..."
        }
        return url
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Source URL:")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                if isLongURL {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if isLongURL {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    Text(displayURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(isExpanded ? .leading : .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .textSelection(.enabled)

            GlassActionButton("Copy URL", icon: "doc.on.doc") {
                UIPasteboard.general.string = url
                onCopy?()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Color Swatch View

/// Small color swatch for CSS color preview
struct ColorSwatchView: View {
    let color: Color

    var body: some View {
        ZStack {
            // Checkerboard for transparent colors
            CheckerboardPattern()
                .frame(width: 14, height: 14)

            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Checkerboard Pattern

/// Checkerboard pattern for showing transparency
private struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 4
            let rows = Int(ceil(size.height / cellSize))
            let cols = Int(ceil(size.width / cellSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? .white : Color(white: 0.85))
                    )
                }
            }
        }
    }
}
