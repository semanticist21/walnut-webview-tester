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
    static let defaultSavedProfiles: [WebViewPreloadProfile] = [.defaultSavedSetup]

    static func activeProfile(defaults: UserDefaults = .standard) -> WebViewPreloadProfile {
        guard let data = defaults.data(forKey: activeProfileKey),
            let profile = try? JSONDecoder().decode(WebViewPreloadProfile.self, from: data)
        else {
            return .defaultSavedSetup
        }
        guard !profile.isLegacyGeneratedNativeBridgeDemoCopy else {
            return .defaultSavedSetup
        }
        return profile
    }

    static func saveActiveProfile(_ profile: WebViewPreloadProfile, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: activeProfileKey)
    }

    static func savedProfiles(defaults: UserDefaults = .standard) -> [WebViewPreloadProfile] {
        guard let data = defaults.data(forKey: savedProfilesKey),
            let profiles = try? JSONDecoder().decode([WebViewPreloadProfile].self, from: data)
        else {
            return defaultSavedProfiles
        }
        let filteredProfiles = profiles.filter { !$0.isLegacyGeneratedNativeBridgeDemoCopy }
        return filteredProfiles.isEmpty ? defaultSavedProfiles : filteredProfiles
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
                body: body
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
