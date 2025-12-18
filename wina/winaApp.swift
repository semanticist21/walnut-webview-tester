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

        // Request ATT authorization after a short delay, then preload ads
        Task.detached {
            // Give the app a moment to launch and UI to settle before showing the ATT prompt
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                Self.requestATTAuthorization()
            }

            // Wait for StoreManager to check entitlements (determines if user is premium)
            await StoreManager.shared.checkEntitlements()

            // Preload interstitial ad after ATT prompt (skips if premium user)
            // This triggers local network permission prompt early (if needed by AdMob SDK)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds after ATT
            await AdManager.shared.loadInterstitialAd(adUnitId: AdManager.interstitialAdUnitId)
        }
    }

    /// Initialize WebView size ratios to "App" preset on first launch
    /// Must be called after Scene is ready (UIWindowScene available)
    static func initializeWebViewSizeIfNeeded() {
        let defaults = UserDefaults.standard
        let hasInitializedKey = "hasInitializedWebViewSize"

        guard !defaults.bool(forKey: hasInitializedKey) else { return }

        // Calculate "App" preset height ratio based on device screen
        let screenHeight = ScreenUtility.screenSize.height
        let appContainerHeightRatio = BarConstants.appContainerHeightRatio(for: screenHeight)

        // Set both WKWebView and SafariVC to "App" preset
        defaults.set(1.0, forKey: "webViewWidthRatio")
        defaults.set(appContainerHeightRatio, forKey: "webViewHeightRatio")
        defaults.set(1.0, forKey: "safariWidthRatio")
        defaults.set(appContainerHeightRatio, forKey: "safariHeightRatio")

        defaults.set(true, forKey: hasInitializedKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
                .onAppear {
                    // Initialize WebView size after Scene is ready
                    Self.initializeWebViewSizeIfNeeded()
                }
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
