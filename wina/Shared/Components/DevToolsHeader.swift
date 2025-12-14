//
//  DevToolsHeader.swift
//  wina
//
//  Shared header component for Console, Network, Storage views.
//

import SwiftUI

struct DevToolsHeader: View {
    let title: String
    let leftButtons: [HeaderButton]
    let rightButtons: [HeaderButton]

    struct HeaderButton: Identifiable {
        let id = UUID()
        let icon: String
        let activeIcon: String?
        let color: Color
        let activeColor: Color?
        let isActive: Bool
        let isDisabled: Bool
        let action: () -> Void

        init(
            icon: String,
            activeIcon: String? = nil,
            color: Color = .primary,
            activeColor: Color? = nil,
            isActive: Bool = false,
            isDisabled: Bool = false,
            action: @escaping () -> Void
        ) {
            self.icon = icon
            self.activeIcon = activeIcon
            self.color = color
            self.activeColor = activeColor
            self.isActive = isActive
            self.isDisabled = isDisabled
            self.action = action
        }

        var currentIcon: String {
            if isActive, let activeIcon {
                return activeIcon
            }
            return icon
        }

        var currentColor: Color {
            if isActive, let activeColor {
                return activeColor
            }
            return isDisabled ? Color.secondary.opacity(0.5) : color
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Title
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            // Row 2: Button groups
            HStack(spacing: 16) {
                // Left button group
                if !leftButtons.isEmpty {
                    buttonGroup(leftButtons)
                }

                Spacer()

                // Right button group
                if !rightButtons.isEmpty {
                    buttonGroup(rightButtons)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func buttonGroup(_ buttons: [HeaderButton]) -> some View {
        HStack(spacing: 4) {
            ForEach(buttons) { button in
                Button {
                    button.action()
                } label: {
                    Image(systemName: button.currentIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(button.currentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .disabled(button.isDisabled)
            }
        }
        .padding(.horizontal, 6)
        .glassEffect(in: .capsule)
    }
}

#Preview {
    VStack {
        DevToolsHeader(
            title: "Console",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {},
                .init(icon: "trash", isDisabled: true) {},
                .init(icon: "square.and.arrow.up") {}
            ],
            rightButtons: [
                .init(
                    icon: "play.fill",
                    activeIcon: "pause.fill",
                    color: .green,
                    activeColor: .red,
                    isActive: true
                ) {},
                .init(
                    icon: "gearshape",
                    activeIcon: "gearshape.fill",
                    color: .secondary,
                    activeColor: .blue,
                    isActive: false
                ) {}
            ]
        )
        Spacer()
    }
}
