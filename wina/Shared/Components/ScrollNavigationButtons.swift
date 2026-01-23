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

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Hysteresis State

    /// Tracks button visibility with hysteresis to prevent flickering
    @State private var upButtonVisible: Bool = false
    @State private var downButtonVisible: Bool = true

    // MARK: - Thresholds (Hysteresis)

    /// Threshold to show button (needs more scroll to appear)
    private let showThreshold: CGFloat = 40
    /// Threshold to hide button (needs to be closer to edge to disappear)
    private let hideThreshold: CGFloat = 15

    // MARK: - Computed Properties

    private var canScroll: Bool {
        contentHeight > viewportHeight + 20
    }

    private var isNearTop: Bool {
        scrollOffset <= hideThreshold
    }

    private var isNearBottom: Bool {
        (contentHeight - scrollOffset - viewportHeight) <= hideThreshold
    }

    private var distanceFromTop: CGFloat {
        scrollOffset
    }

    private var distanceFromBottom: CGFloat {
        contentHeight - scrollOffset - viewportHeight
    }

    var body: some View {
        if canScroll {
            VStack(spacing: 6) {
                // Up button - always in layout, visibility controlled by opacity
                scrollButton(
                    icon: "chevron.up.circle.fill",
                    isVisible: !minimalMode || upButtonVisible,
                    isEnabled: !isNearTop,
                    action: {
                        triggerHaptic()
                        onScrollUp()
                    }
                )

                // Down button
                scrollButton(
                    icon: "chevron.down.circle.fill",
                    isVisible: !minimalMode || downButtonVisible,
                    isEnabled: !isNearBottom,
                    action: {
                        triggerHaptic()
                        onScrollDown()
                    }
                )
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
            .onChange(of: scrollOffset) { _, _ in
                updateButtonVisibility()
            }
            .onAppear {
                updateButtonVisibility()
            }
        }
    }

    // MARK: - Hysteresis Logic

    private func updateButtonVisibility() {
        // Up button: show when scrolled down enough, hide when near top
        if distanceFromTop > showThreshold && !upButtonVisible {
            upButtonVisible = true
        } else if distanceFromTop < hideThreshold && upButtonVisible {
            upButtonVisible = false
        }

        // Down button: show when far from bottom, hide when near bottom
        if distanceFromBottom > showThreshold && !downButtonVisible {
            downButtonVisible = true
        } else if distanceFromBottom < hideThreshold && downButtonVisible {
            downButtonVisible = false
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
            Image(systemName: icon.replacingOccurrences(of: ".circle.fill", with: ""))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? .black : .white)
                .frame(width: 32, height: 32)
                .background(colorScheme == .dark ? Color.white : Color.blue)
                .clipShape(Circle())
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
