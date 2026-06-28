//
//  PreloadProfileStore.swift
//  wina
//
//  UserDefaults-backed storage for reusable preload profiles.
//

import Foundation
import Observation

enum PreloadProfileStore {
    static let activeProfileKey = "preloadActiveProfile"
    static let savedProfilesKey = "preloadSavedProfiles"
    static let didRemoveLegacyDemoCopyKey = "preloadDidRemoveLegacyDemoCopy"

    static func activeProfile(defaults: UserDefaults = .standard) -> WebViewPreloadProfile {
        guard let data = defaults.data(forKey: activeProfileKey),
            let profile = try? JSONDecoder().decode(WebViewPreloadProfile.self, from: data)
        else {
            return .defaultSavedSetup
        }
        // The active profile is whatever the user explicitly applied; never content-filter it.
        // Once Apply enables a saved "Native Bridge Demo Copy" it becomes byte-identical to the
        // demo preset, so filtering here would silently swap it for the disabled default setup
        // and clear the Home checkmark. Legacy copies are pruned from the saved list only.
        return profile
    }

    static func saveActiveProfile(_ profile: WebViewPreloadProfile, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: activeProfileKey)
    }

    static func savedProfiles(defaults: UserDefaults = .standard) -> [WebViewPreloadProfile] {
        // Pure storage: the saved list is exactly what the user saved. An empty list stays
        // empty so deletes stick — never inject a default entry here, or "Default" would
        // resurrect on every read and become impossible to remove. Legacy auto-generated
        // copies are pruned once via removeLegacyGeneratedDemoCopyIfNeeded, not on each read.
        guard let data = defaults.data(forKey: savedProfilesKey),
            let profiles = try? JSONDecoder().decode([WebViewPreloadProfile].self, from: data)
        else {
            return []
        }
        return profiles
    }

    static func saveProfiles(_ profiles: [WebViewPreloadProfile], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: savedProfilesKey)
    }

    @discardableResult
    static func upsertSavedProfile(
        _ profile: WebViewPreloadProfile,
        defaults: UserDefaults = .standard
    ) -> WebViewPreloadProfile {
        var profiles = savedProfiles(defaults: defaults)
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.insert(profile, at: 0)
        }
        saveProfiles(profiles, defaults: defaults)
        return profile
    }

    /// One-time cleanup of the legacy auto-generated "Native Bridge Demo Copy" saved setup.
    /// Older builds injected this copy automatically; remove it once at launch instead of
    /// filtering on every read — a runtime filter silently swapped user-applied profiles for
    /// the default and could not be undone. Runs exactly once, guarded by a defaults flag, so
    /// a user is free to keep their own "Native Bridge Demo Copy" afterwards.
    static func removeLegacyGeneratedDemoCopyIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: didRemoveLegacyDemoCopyKey) else { return }
        defaults.set(true, forKey: didRemoveLegacyDemoCopyKey)

        guard let data = defaults.data(forKey: savedProfilesKey),
            let profiles = try? JSONDecoder().decode([WebViewPreloadProfile].self, from: data)
        else {
            return
        }
        let cleaned = profiles.filter { !$0.isLegacyGeneratedNativeBridgeDemoCopy }
        if cleaned.count != profiles.count {
            saveProfiles(cleaned, defaults: defaults)
        }
    }
}

// MARK: - Bridge Log

struct PreloadBridgeLogEntry: Identifiable, Equatable {
    enum Direction: Equatable {
        case received
        case responded
    }

    let id = UUID()
    let date: Date
    let channel: String
    let direction: Direction
    let body: String
}

@Observable
final class PreloadBridgeLogManager {
    var entries: [PreloadBridgeLogEntry] = []

    func add(channel: String, direction: PreloadBridgeLogEntry.Direction, body: String) {
        entries.insert(
            PreloadBridgeLogEntry(
                date: Date(),
                channel: channel,
                direction: direction,
                body: PreloadBridgeLogFormatter.truncated(body)
            ),
            at: 0
        )

        if entries.count > 200 {
            entries.removeLast(entries.count - 200)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

enum PreloadBridgeLogFormatter {
    static let maxBodyLength = 20_000

    static func truncated(_ body: String, maxLength: Int = maxBodyLength) -> String {
        guard body.count > maxLength else { return body }
        var omitted = body.count - maxLength
        var suffix = "\n... [truncated \(omitted) characters]"
        var prefixLength = max(0, maxLength - suffix.count)
        omitted = body.count - prefixLength
        suffix = "\n... [truncated \(omitted) characters]"
        prefixLength = max(0, maxLength - suffix.count)
        return "\(body.prefix(prefixLength))\(suffix)"
    }
}
