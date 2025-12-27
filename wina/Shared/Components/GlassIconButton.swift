//
//  GlassIconButton.swift
//  wina
//

import SwiftUI
import SwiftUIBackports

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
    var accessibilityLabel: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize))
                // Disabled 상태에서 opacity 적용 (Color 타입 유지)
                .foregroundStyle(color.opacity(isDisabled ? 0.3 : 1.0))
                .frame(width: size.frame, height: size.frame)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .backport.glassEffect(in: .circle)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel ?? "Button")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack(spacing: 16) {
        GlassIconButton(icon: "gearshape") {}
        GlassIconButton(icon: "doc.on.doc", size: .small) {}
    }
}
