//
//  PreloadProfileTests.swift
//  winaTests
//

import XCTest

@testable import wina

final class PreloadProfileTests: XCTestCase {
    func testNativeBridgeDemoPresetProvidesReusableCase() {
        let preset = WebViewPreloadProfile.nativeBridgeDemoPreset

        XCTAssertTrue(preset.isEnabled)
        XCTAssertEqual(preset.name, "Native Bridge Demo")
        XCTAssertEqual(preset.cookies.first?.name, "walnut_session")
        XCTAssertEqual(preset.bridgeChannels.first?.name, "request")
        XCTAssertTrue(preset.enabledBridgeChannelNames.contains("request"))
        XCTAssertTrue(preset.enabledBridgeChannelNames.contains("winaPostMessage"))
    }

    func testBootstrapScriptContainsWindowItemsAndPostMessageCapture() {
        let script = PreloadScriptBuilder.bootstrapScript(for: .nativeBridgeDemoPreset)

        XCTAssertTrue(script.contains("__winaPreloadSetPath"))
        XCTAssertTrue(script.contains("\"appVersion\""))
        XCTAssertTrue(script.contains("\"getAuthToken\""))
        XCTAssertTrue(script.contains("window.addEventListener('message'"))
        XCTAssertTrue(script.contains("messageHandlers.winaPostMessage"))
    }

    func testTemplateRendererReplacesNestedMessageValues() {
        let message: [String: Any] = [
            "id": "req-1",
            "type": "getAuthToken",
            "payload": [
                "action": "login"
            ],
        ]

        let rendered = BridgeTemplateRenderer.render(
            #"{"id":"{{message.id}}","action":"{{message.payload.action}}"}"#,
            message: message
        )

        XCTAssertEqual(rendered, #"{"id":"req-1","action":"login"}"#)
    }

    func testTemplateRendererEscapesStringValuesInsideJSON() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"id":"{{message.id}}"}"#,
            message: ["id": #"quote"and\slash"#]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(object["id"], #"quote"and\slash"#)
    }

    func testTemplateRendererPreservesBooleanAndNumberTypesInJSON() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"ok":{{message.payload.ok}},"count":{{message.payload.count}}}"#,
            message: [
                "payload": [
                    "ok": true,
                    "count": 3,
                ]
            ]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["ok"] as? Bool, true)
        XCTAssertEqual((object["count"] as? NSNumber)?.intValue, 3)
    }

    func testBridgeRuleMatcherSupportsTypeAndJSONPath() {
        let message: [String: Any] = [
            "type": "getAuthToken",
            "payload": [
                "action": "login"
            ],
        ]

        XCTAssertTrue(BridgeRuleMatcher.matches(.typeEquals("getAuthToken"), message: message))
        XCTAssertTrue(
            BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.action", value: "login"), message: message))
        XCTAssertFalse(
            BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.action", value: "logout"), message: message))
    }

    func testBridgeRuleMatcherUsesBooleanTextValues() {
        let message: [String: Any] = [
            "payload": [
                "ok": true,
                "cached": NSNumber(value: false),
            ]
        ]

        XCTAssertTrue(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.ok", value: "true"), message: message))
        XCTAssertTrue(
            BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.cached", value: "false"), message: message))
        XCTAssertFalse(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.ok", value: "1"), message: message))
    }

    func testResponseScriptPostsRenderedMessage() {
        let response = BridgeResponse(
            target: .postMessage,
            bodyTemplate: #"{"id":"{{message.id}}","ok":true}"#
        )
        let script = PreloadScriptBuilder.responseScript(
            for: response,
            message: ["id": "req-1"],
            channel: "request"
        )

        XCTAssertTrue(script.contains("window.postMessage"))
        XCTAssertTrue(script.contains(#""id":"req-1""#))
        XCTAssertTrue(script.contains(#""ok":true"#))
    }

    func testInvalidChannelNamesAreExcluded() {
        let profile = WebViewPreloadProfile(
            isEnabled: true,
            bridgeChannels: [
                BridgeChannel(name: "request"),
                BridgeChannel(name: "bad-name"),
                BridgeChannel(name: "consoleLog"),
                BridgeChannel(name: "winaPostMessage"),
            ]
        )

        XCTAssertEqual(profile.enabledBridgeChannelNames, ["request"])
    }

    func testStoreKeepsBuiltInPresetSyntheticAndUpdatesSavedCopy() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(PreloadProfileStore.savedProfiles(defaults: defaults).map(\.name), ["Native Bridge Demo"])

        let firstCopy = PreloadProfileStore.upsertSavedProfile(.nativeBridgeDemoPreset, defaults: defaults)
        var editedCopy = firstCopy
        editedCopy.windowItems.append(WindowInjectionItem(name: "savedAfterCopy", value: "yes"))
        let secondSave = PreloadProfileStore.upsertSavedProfile(editedCopy, defaults: defaults)
        let profiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(secondSave.id, firstCopy.id)
        XCTAssertEqual(profiles.map(\.name), ["Native Bridge Demo", "Native Bridge Demo Copy"])
        XCTAssertEqual(profiles.last?.windowItems.last?.name, "savedAfterCopy")
    }

    func testStoreKeepsUserProfileWithSameNameAsBuiltIn() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userProfile = WebViewPreloadProfile(
            name: WebViewPreloadProfile.nativeBridgeDemoPreset.name,
            isEnabled: true,
            cookies: [PreloadCookie(name: "custom", value: "value")]
        )

        PreloadProfileStore.upsertSavedProfile(userProfile, defaults: defaults)
        let profiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].id, WebViewPreloadProfile.nativeBridgeDemoPresetID)
        XCTAssertEqual(profiles[1].id, userProfile.id)
        XCTAssertEqual(profiles[1].cookies.first?.name, "custom")
    }

    func testActiveProfileRoundTripsAllPreloadCollections() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let profile = WebViewPreloadProfile(
            name: "Round Trip",
            isEnabled: true,
            cookies: [PreloadCookie(name: "session", value: "abc")],
            windowItems: [WindowInjectionItem(name: "app.flag", valueKind: .json, value: "true")],
            bridgeChannels: [
                BridgeChannel(
                    name: "request",
                    responseRules: [
                        BridgeResponseRule(name: "ok", matcher: .jsonPathEquals(path: "payload.ok", value: "true"))
                    ]
                )
            ],
            capturesWindowPostMessage: true,
            customScripts: [PreloadCustomScript(name: "Boot", source: "window.ready = true;")]
        )

        PreloadProfileStore.saveActiveProfile(profile, defaults: defaults)
        let restored = PreloadProfileStore.activeProfile(defaults: defaults)

        XCTAssertEqual(restored, profile)
    }

    func testPreloadSettingsStateDoesNotReloadOverDraftAfterNavigationReturn() {
        var state = PreloadProfileSettingsState()
        var loadCount = 0
        let storedProfile = WebViewPreloadProfile(name: "Stored", isEnabled: true)

        state.loadIfNeeded(
            activeProfile: {
                loadCount += 1
                return storedProfile
            },
            savedProfiles: { [.nativeBridgeDemoPreset] }
        )

        state.profile.cookies.append(PreloadCookie(name: "session", value: "demo"))
        state.profile.windowItems.append(WindowInjectionItem(name: "appVersion", value: "1.0.0"))
        state.profile.bridgeChannels.append(
            BridgeChannel(
                name: "request",
                responseRules: [BridgeResponseRule(name: "Reply", matcher: .any)]
            )
        )
        state.profile.customScripts.append(PreloadCustomScript(name: "Boot", source: "window.ready = true;"))

        state.loadIfNeeded(
            activeProfile: {
                loadCount += 1
                return WebViewPreloadProfile(name: "Reloaded")
            },
            savedProfiles: { [] }
        )

        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(state.profile.name, "Stored")
        XCTAssertEqual(state.profile.cookies.map(\.name), ["session"])
        XCTAssertEqual(state.profile.windowItems.map(\.name), ["appVersion"])
        XCTAssertEqual(state.profile.bridgeChannels.map(\.name), ["request"])
        XCTAssertEqual(state.profile.bridgeChannels.first?.responseRules.map(\.name), ["Reply"])
        XCTAssertEqual(state.profile.customScripts.map(\.name), ["Boot"])
    }

    func testCurrentHostCookieUsesNavigationHost() {
        let cookie = PreloadCookie(name: "session", value: "abc", domainMode: .currentHost)
        let httpCookie = PreloadCookieApplicator.makeHTTPCookie(
            from: cookie,
            url: URL(string: "https://example.com/path")!
        )

        XCTAssertEqual(httpCookie?.name, "session")
        XCTAssertEqual(httpCookie?.value, "abc")
        XCTAssertEqual(httpCookie?.domain, "example.com")
        XCTAssertEqual(httpCookie?.path, "/")
    }

}
