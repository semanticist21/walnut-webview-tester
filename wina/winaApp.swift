//
//  winaApp.swift
//  wina
//
//  Created by 박지원 on 12/6/25.
//

import AppTrackingTransparency
import os
import SwiftUI

@main
struct winaApp: App {
    /// nil = system, "light" = light mode, "dark" = dark mode
    @AppStorage("colorSchemeOverride") private var colorSchemeOverride: String?

    private var preferredScheme: ColorScheme? {
        switch colorSchemeOverride {
        case "light": .light
        case "dark": .dark
        default: nil  // System
        }
    }

    init() {
        // Clear network body cache from previous session (unless preserveLog is enabled)
        NetworkBodyStorage.shared.clearOnLaunchIfNeeded()

        // Initialize Google Mobile Ads SDK
        AdManager.shared.initialize()

        // Initialize StoreKit (starts transaction listener, checks entitlements)
        _ = StoreManager.shared

        // Request ATT authorization after a short delay
        Task.detached {
            // Give the app a moment to launch and UI to settle before showing the ATT prompt
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                Self.requestATTAuthorization()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
        }
    }

    private static func requestATTAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            let logger = Logger(subsystem: "com.wallnut.wina", category: "ATT")
            switch status {
            case .authorized:
                logger.info("User granted tracking permission")
            case .denied:
                logger.info("User denied tracking permission")
            case .notDetermined:
                logger.debug("Tracking permission not determined")
            case .restricted:
                logger.info("Tracking permission restricted")
            @unknown default:
                logger.warning("Unknown tracking authorization status")
            }
        }
    }
}
