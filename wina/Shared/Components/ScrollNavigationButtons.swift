//
//  ScrollNavigationButtons.swift
//  wina
//
//  Reusable scroll navigation overlay with minimal design and haptic feedback.
//

import SwiftUI
import SwiftUIBackports

// MARK: - Scroll Navigation Buttons

struct ScrollNavigationButtons: View {
    let scrollOffset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
    let onScrollUp: () -> Void
    let onScrollDown: () -> Void

    /// Minimal mode: show only relevant button based on position
    var minimalMode: Bool = true

    // MARK: - Computed Properties

    private var canScroll: Bool {
        contentHeight > viewportHeight + 20
    }

    private var isNearTop: Bool {
        scrollOffset <= 20
    }

    private var isNearBottom: Bool {
        (contentHeight - scrollOffset - viewportHeight) <= 20
    }

    private var showUpButton: Bool {
        !minimalMode || !isNearTop
    }

    private var showDownButton: Bool {
        !minimalMode || !isNearBottom
    }

    var body: some View {
        if canScroll {
            VStack(spacing: 6) {
                // Up button - always in layout, visibility controlled by opacity
                scrollButton(
                    icon: "chevron.up.circle.fill",
                    isVisible: showUpButton,
                    isEnabled: !isNearTop,
                    action: {
                        triggerHaptic()
                        onScrollUp()
                    }
                )

                // Down button
                scrollButton(
                    icon: "chevron.down.circle.fill",
                    isVisible: showDownButton,
                    isEnabled: !isNearBottom,
                    action: {
                        triggerHaptic()
                        onScrollDown()
                    }
                )
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Scroll Button

    @ViewBuilder
    private func scrollButton(
        icon: String,
        isVisible: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.primary)
        }
        .backport
        .glassEffect(in: .circle)
        .disabled(!isVisible || !isEnabled)
        .opacity(isVisible ? (isEnabled ? 1 : 0.3) : 0)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }

    // MARK: - Haptic

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    /// Adds scroll navigation buttons overlay to a ScrollView
    func scrollNavigationOverlay(
        scrollOffset: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        minimalMode: Bool = true,
        onScrollUp: @escaping () -> Void,
        onScrollDown: @escaping () -> Void
    ) -> some View {
        self.overlay(alignment: .bottomTrailing) {
            ScrollNavigationButtons(
                scrollOffset: scrollOffset,
                contentHeight: contentHeight,
                viewportHeight: viewportHeight,
                onScrollUp: onScrollUp,
                onScrollDown: onScrollDown,
                minimalMode: minimalMode
            )
        }
    }
}

#Preview {
    VStack {
        // Both buttons visible
        ScrollNavigationButtons(
            scrollOffset: 100,
            contentHeight: 1000,
            viewportHeight: 400,
            onScrollUp: {},
            onScrollDown: {},
            minimalMode: false
        )

        Divider()

        // Minimal mode - near top (only down visible)
        ScrollNavigationButtons(
            scrollOffset: 10,
            contentHeight: 1000,
            viewportHeight: 400,
            onScrollUp: {},
            onScrollDown: {}
        )

        Divider()

        // Minimal mode - near bottom (only up visible)
        ScrollNavigationButtons(
            scrollOffset: 590,
            contentHeight: 1000,
            viewportHeight: 400,
            onScrollUp: {},
            onScrollDown: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
