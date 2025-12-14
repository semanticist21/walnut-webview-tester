//
//  GlassIconButton.swift
//  wina
//

import SwiftUI

struct GlassIconButton: View {
    enum Size {
        case regular  // 44×44, 18pt - header level
        case small    // 28×28, 12pt - sheet internal

        var frame: CGFloat {
            switch self {
            case .regular: return 44
            case .small: return 28
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .regular: return 18
            case .small: return 12
            }
        }
    }

    let icon: String
    var size: Size = .regular
    var color: Color = .primary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : color)
                .frame(width: size.frame, height: size.frame)
                .contentShape(Circle())
                .glassEffect(in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    HStack(spacing: 16) {
        GlassIconButton(icon: "gearshape") {}
        GlassIconButton(icon: "doc.on.doc", size: .small) {}
    }
}
