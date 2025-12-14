import GoogleMobileAds
import os.log
import SwiftUI

private let logger = Logger(subsystem: "com.wallnut.wina", category: "AdManager")

// MARK: - Ad Options

struct AdOptions {
    /// Unique identifier for tracking shown ads in memory.
    /// If an ad with this id has been shown once, it won't be shown again during the session.
    let id: String
}

// MARK: - Ad Manager

@MainActor
@Observable
final class AdManager: NSObject {
    static let shared = AdManager()

    private var interstitialAd: InterstitialAd?
    private var shownAdIds: Set<String> = []
    private var isLoading = false

    override private init() {
        super.init()
    }

    // MARK: - SDK Initialization

    func initialize() {
        MobileAds.shared.start()
    }

    // MARK: - Interstitial Ad

    /// Loads an interstitial ad with the given ad unit ID.
    /// - Parameter adUnitId: The AdMob ad unit ID for interstitial ads.
    func loadInterstitialAd(adUnitId: String) async {
        guard !isLoading else { return }
        isLoading = true

        do {
            interstitialAd = try await InterstitialAd.load(
                with: adUnitId,
                request: Request()
            )
            interstitialAd?.fullScreenContentDelegate = self
        } catch {
            logger.error("Failed to load interstitial ad: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Shows an interstitial ad if not already shown for the given options.id.
    /// - Parameters:
    ///   - options: Ad options containing the unique id for tracking.
    ///   - adUnitId: The AdMob ad unit ID. If ad is not loaded, it will be loaded first.
    /// - Returns: `true` if ad was shown, `false` if skipped (already shown) or failed.
    @discardableResult
    func showInterstitialAd(options: AdOptions, adUnitId: String) async -> Bool {
        // Skip if already shown for this id
        guard !shownAdIds.contains(options.id) else {
            logger.info("Ad already shown for id: \(options.id), skipping")
            return false
        }

        // Load ad if not available
        if interstitialAd == nil {
            await loadInterstitialAd(adUnitId: adUnitId)
        }

        guard let ad = interstitialAd else {
            logger.warning("No ad available to show")
            return false
        }

        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            logger.error("Could not find root view controller")
            return false
        }

        // Mark as shown and present
        shownAdIds.insert(options.id)
        ad.present(from: rootViewController)
        return true
    }

    /// Checks if an ad has been shown for the given id.
    /// - Parameter id: The unique identifier to check.
    /// - Returns: `true` if ad was already shown for this id.
    func hasShownAd(for id: String) -> Bool {
        shownAdIds.contains(id)
    }

    /// Resets the shown state for a specific id.
    /// - Parameter id: The unique identifier to reset.
    func resetShownState(for id: String) {
        shownAdIds.remove(id)
    }

    /// Resets all shown states.
    func resetAllShownStates() {
        shownAdIds.removeAll()
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            interstitialAd = nil
        }
    }

    nonisolated func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        logger.error("Ad failed to present: \(error.localizedDescription)")
        Task { @MainActor in
            interstitialAd = nil
        }
    }

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        logger.info("Ad will present")
    }
}
