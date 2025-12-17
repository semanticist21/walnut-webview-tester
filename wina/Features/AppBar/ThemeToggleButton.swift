//
//  ThemeToggleButton.swift
//  wina
//

import SwiftUI

struct ThemeToggleButton: View {
    /// nil = system, "light" = light mode, "dark" = dark mode
    @AppStorage("colorSchemeOverride") private var colorSchemeOverride: String?
    @Environment(\.colorScheme) private var systemColorScheme

    /// Current effective color scheme (system or override)
    private var effectiveScheme: ColorScheme {
        switch colorSchemeOverride {
        case "light": .light
        case "dark": .dark
        default: systemColorScheme
        }
    }

    private var isDark: Bool {
        effectiveScheme == .dark
    }

    var body: some View {
        GlassIconButton(
            icon: isDark ? "moon.fill" : "sun.max.fill",
            accessibilityLabel: isDark ? "Switch to light mode" : "Switch to dark mode"
        ) {
            // Toggle to opposite of current effective scheme
            // Once user taps, we leave system mode and cycle Light↔Dark
            colorSchemeOverride = isDark ? "light" : "dark"
        }
    }
}

#Preview {
    ThemeToggleButton()
}
