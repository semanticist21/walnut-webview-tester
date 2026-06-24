//
//  PreloadProfileTests.swift
//  winaTests
//

import JavaScriptCore
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
            #"{"ok":{{message.payload.ok}},"count":{{message.payload.count}},"one":{{message.payload.one}},"zero":{{message.payload.zero}}}"#,
            message: [
                "payload": [
                    "ok": true,
                    "count": 3,
                    "one": 1,
                    "zero": NSNumber(value: 0),
                ]
            ]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(rendered, #"{"ok":true,"count":3,"one":1,"zero":0}"#)
        XCTAssertEqual(object["ok"] as? Bool, true)
        XCTAssertEqual((object["count"] as? NSNumber)?.intValue, 3)
        XCTAssertEqual((object["one"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual((object["zero"] as? NSNumber)?.intValue, 0)
    }

    func testTemplateRendererReplacesNullObjectAndArrayValues() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"payload":{{message.payload}},"first":"{{message.payload.items.0.name}}","missing":{{message.payload.missing}}}"#,
            message: [
                "payload": [
                    "items": [
                        ["name": "first"],
                        ["name": "second"],
                    ],
                    "missing": NSNull(),
                ]
            ]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let payload = try XCTUnwrap(object["payload"] as? [String: Any])
        let items = try XCTUnwrap(payload["items"] as? [[String: String]])

        XCTAssertEqual(items.map { $0["name"] }, ["first", "second"])
        XCTAssertTrue(payload["missing"] is NSNull)
        XCTAssertEqual(object["first"] as? String, "first")
        XCTAssertTrue(object["missing"] is NSNull)
    }

    func testTemplateRendererDoesNotReExpandMessageControlledTokens() {
        let rendered = BridgeTemplateRenderer.render(
            #"{"a":"{{message.a}}","b":"{{message.b}}"}"#,
            message: [
                "a": "{{message.b}}",
                "b": "INJECTED",
            ]
        )

        XCTAssertEqual(rendered, #"{"a":"{{message.b}}","b":"INJECTED"}"#)
    }

    func testJavaScriptLiteralEscapesLineSeparators() {
        let literal = JavaScriptLiteral.quoted("first\u{2028}second\u{2029}third")

        XCTAssertEqual(literal, #""first\u2028second\u2029third""#)
    }

    func testJavaScriptLiteralEscapesScriptClosingTags() {
        let literal = JavaScriptLiteral.quoted("</script>")

        XCTAssertTrue(literal.contains(#"\u003C"#))
        XCTAssertFalse(literal.contains("</script>"))
    }

    func testTemplateRendererEscapesLineSeparatorsInsideJSONStrings() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"value":"{{message.value}}"}"#,
            message: ["value": "first\u{2028}second\u{2029}third"]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(rendered, #"{"value":"first\u2028second\u2029third"}"#)
        XCTAssertEqual(object["value"], "first\u{2028}second\u{2029}third")
    }

    func testTemplateRendererEscapesLineSeparatorsInsideObjectPathJSON() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"payload":{{message.payload}}}"#,
            message: [
                "payload": [
                    "value": "first\u{2028}second\u{2029}third"
                ]
            ]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let payload = try XCTUnwrap(object["payload"] as? [String: String])

        XCTAssertEqual(rendered, #"{"payload":{"value":"first\u2028second\u2029third"}}"#)
        XCTAssertEqual(payload["value"], "first\u{2028}second\u{2029}third")
    }

    func testTemplateRendererEscapesLineSeparatorsInsideRootMessageJSON() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"message":{{message}}}"#,
            message: [
                "value": "first\u{2028}second\u{2029}third"
            ]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let message = try XCTUnwrap(object["message"] as? [String: String])

        XCTAssertEqual(rendered, #"{"message":{"value":"first\u2028second\u2029third"}}"#)
        XCTAssertEqual(message["value"], "first\u{2028}second\u{2029}third")
    }

    func testTemplateRendererEscapesScriptClosingTagsInsideObjectPathJSON() throws {
        let rendered = BridgeTemplateRenderer.render(
            #"{"payload":{{message.payload}}}"#,
            message: [
                "payload": [
                    "html": "</script>"
                ]
            ]
        )
        let data = try XCTUnwrap(rendered.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let payload = try XCTUnwrap(object["payload"] as? [String: String])

        XCTAssertTrue(rendered.contains(#"\u003C"#))
        XCTAssertFalse(rendered.contains("</script>"))
        XCTAssertEqual(payload["html"], "</script>")
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
                "one": NSNumber(value: 1),
                "zero": NSNumber(value: 0),
            ]
        ]

        XCTAssertTrue(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.ok", value: "true"), message: message))
        XCTAssertTrue(
            BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.cached", value: "false"), message: message))
        XCTAssertFalse(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.ok", value: "1"), message: message))
        XCTAssertTrue(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.one", value: "1"), message: message))
        XCTAssertTrue(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.zero", value: "0"), message: message))
        XCTAssertFalse(BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.one", value: "true"), message: message))
        XCTAssertFalse(
            BridgeRuleMatcher.matches(.jsonPathEquals(path: "payload.zero", value: "false"), message: message))
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

    func testBootstrapScriptExecutesWindowItemsInJavaScriptContext() throws {
        let profile = WebViewPreloadProfile(
            isEnabled: true,
            windowItems: [
                WindowInjectionItem(name: "app.version", kind: .variable, valueKind: .string, value: "1.2.3"),
                WindowInjectionItem(name: "feature.enabled", kind: .variable, valueKind: .json, value: "true"),
                WindowInjectionItem(name: "native.token", kind: .functionReturn, valueKind: .string, value: "secret"),
                WindowInjectionItem(
                    name: "native.payload", kind: .functionBody, value: #"return { ok: true, count: 2 };"#),
            ]
        )
        let context = makeJavaScriptContext()

        context.evaluateScript("var window = this;")
        context.evaluateScript(PreloadScriptBuilder.bootstrapScript(for: profile))

        XCTAssertEqual(context.evaluateScript("window.app.version").toString(), "1.2.3")
        XCTAssertTrue(context.evaluateScript("window.feature.enabled").toBool())
        XCTAssertEqual(context.evaluateScript("window.native.token()").toString(), "secret")
        XCTAssertEqual(
            context.evaluateScript("JSON.stringify(window.native.payload())").toString(), #"{"ok":true,"count":2}"#)
    }

    func testResponseScriptExecutesPostMessageInJavaScriptContext() throws {
        let response = BridgeResponse(
            target: .postMessage,
            bodyTemplate: #"{"id":"{{message.id}}","ok":{{message.payload.ok}},"count":{{message.payload.count}}}"#
        )
        let script = PreloadScriptBuilder.responseScript(
            for: response,
            message: [
                "id": "req-1",
                "payload": [
                    "ok": NSNumber(value: true),
                    "count": NSNumber(value: 1),
                ],
            ],
            channel: "request"
        )
        let context = makeJavaScriptContext()

        context.evaluateScript(
            """
            var window = this;
            var posted = null;
            window.postMessage = function(body, target) {
                posted = { body: body, target: target };
            };
            """
        )
        context.evaluateScript(script)

        XCTAssertEqual(context.evaluateScript("posted.target").toString(), "*")
        XCTAssertEqual(
            context.evaluateScript("JSON.stringify(posted.body)").toString(), #"{"id":"req-1","ok":true,"count":1}"#)
    }

    func testPostMessageCaptureSkipsOnlyTaggedNativeBridgeResponses() throws {
        let profile = WebViewPreloadProfile(
            isEnabled: true,
            capturesWindowPostMessage: true
        )
        let response = BridgeResponse(
            target: .postMessage,
            bodyTemplate: #"{"type":"nativeResponse"}"#
        )
        let responseScript = PreloadScriptBuilder.responseScript(
            for: response,
            message: [:],
            channel: "request"
        )
        let context = makeJavaScriptContext()

        context.evaluateScript(
            """
            var window = this;
            var captured = [];
            var pageObserved = [];
            window.webkit = {
                messageHandlers: {
                    winaPostMessage: {
                        postMessage: function(body) { captured.push(body); }
                    }
                }
            };
            var listeners = [];
            window.addEventListener = function(name, listener) {
                if (name === 'message') listeners.push(listener);
            };
            var queuedMessages = [];
            window.postMessage = function(body, target) {
                queuedMessages.push({ origin: 'test://page', data: body });
            };
            function flushQueuedMessages() {
                while (queuedMessages.length > 0) {
                    var event = queuedMessages.shift();
                    listeners.forEach(function(listener) {
                        listener(event);
                    });
                }
            }
            """
        )
        context.evaluateScript(PreloadScriptBuilder.bootstrapScript(for: profile))
        context.evaluateScript(
            """
            window.addEventListener('message', function(event) {
                pageObserved.push(event.data);
            });
            """
        )
        context.evaluateScript("window.postMessage({ type: 'pageMessage' }, '*');")
        context.evaluateScript(responseScript)
        context.evaluateScript("flushQueuedMessages();")

        XCTAssertEqual(context.evaluateScript("captured.length").toInt32(), 1)
        XCTAssertEqual(context.evaluateScript("captured[0].data.type").toString(), "pageMessage")
        XCTAssertEqual(context.evaluateScript("pageObserved.length").toInt32(), 2)
        XCTAssertEqual(context.evaluateScript("pageObserved[1].type").toString(), "nativeResponse")
        XCTAssertTrue(
            context.evaluateScript("pageObserved[1].__winaPreloadNativePostMessageToken === undefined").toBool())
    }

    func testNativePostMessageTokenIsNotEnumerable() throws {
        let profile = WebViewPreloadProfile(
            isEnabled: true,
            capturesWindowPostMessage: true
        )
        let context = makeJavaScriptContext()

        context.evaluateScript("var window = this; window.addEventListener = function() {};")
        context.evaluateScript(PreloadScriptBuilder.bootstrapScript(for: profile))
        context.evaluateScript(
            """
            var message = { type: 'nativeResponse' };
            window.__winaPreloadMarkNativePostMessage(message);
            var tokenKey = window.__winaPreloadNativePostMessageTokenKey;
            var hasToken = message[tokenKey] !== undefined;
            var enumerableKeys = Object.keys(message);
            """
        )

        XCTAssertTrue(context.evaluateScript("hasToken").toBool())
        XCTAssertFalse(context.evaluateScript("enumerableKeys.indexOf(tokenKey) !== -1").toBool())
    }

    func testPostMessageCaptureSkipsNativePrimitiveResponses() throws {
        let profile = WebViewPreloadProfile(
            isEnabled: true,
            capturesWindowPostMessage: true
        )
        let response = BridgeResponse(
            target: .postMessage,
            bodyTemplate: #""nativeResponse""#
        )
        let responseScript = PreloadScriptBuilder.responseScript(
            for: response,
            message: [:],
            channel: "request"
        )
        let context = makeJavaScriptContext()

        context.evaluateScript(
            """
            var window = this;
            var captured = [];
            window.webkit = {
                messageHandlers: {
                    winaPostMessage: {
                        postMessage: function(body) { captured.push(body); }
                    }
                }
            };
            var listeners = [];
            window.addEventListener = function(name, listener) {
                if (name === 'message') listeners.push(listener);
            };
            window.postMessage = function(body, target) {
                listeners.forEach(function(listener) {
                    listener({ origin: 'test://page', data: body });
                });
            };
            """
        )
        context.evaluateScript(PreloadScriptBuilder.bootstrapScript(for: profile))
        context.evaluateScript(responseScript)
        context.evaluateScript("window.postMessage({ type: 'pageMessage' }, '*');")

        XCTAssertEqual(context.evaluateScript("captured.length").toInt32(), 1)
        XCTAssertEqual(context.evaluateScript("captured[0].data.type").toString(), "pageMessage")
    }

    func testPostMessageCaptureSkipsNativeArrayResponses() throws {
        let profile = WebViewPreloadProfile(
            isEnabled: true,
            capturesWindowPostMessage: true
        )
        let response = BridgeResponse(
            target: .postMessage,
            bodyTemplate: #"[{"type":"nativeResponse"}]"#
        )
        let responseScript = PreloadScriptBuilder.responseScript(
            for: response,
            message: [:],
            channel: "request"
        )
        let context = makeJavaScriptContext()

        context.evaluateScript(
            """
            var window = this;
            var captured = [];
            window.webkit = {
                messageHandlers: {
                    winaPostMessage: {
                        postMessage: function(body) { captured.push(body); }
                    }
                }
            };
            var listeners = [];
            window.addEventListener = function(name, listener) {
                if (name === 'message') listeners.push(listener);
            };
            window.postMessage = function(body, target) {
                listeners.forEach(function(listener) {
                    listener({ origin: 'test://page', data: body });
                });
            };
            """
        )
        context.evaluateScript(PreloadScriptBuilder.bootstrapScript(for: profile))
        context.evaluateScript(responseScript)
        context.evaluateScript("window.postMessage({ type: 'pageMessage' }, '*');")

        XCTAssertEqual(context.evaluateScript("captured.length").toInt32(), 1)
        XCTAssertEqual(context.evaluateScript("captured[0].data.type").toString(), "pageMessage")
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

    func testStoreStartsWithEmptyDefaultSetupAndSupportsCreateReadDelete() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initialProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)
        XCTAssertEqual(initialProfiles.map(\.name), ["Default"])
        XCTAssertEqual(initialProfiles.first?.id, WebViewPreloadProfile.defaultSavedSetupID)
        XCTAssertFalse(initialProfiles.first?.isEnabled ?? true)
        XCTAssertEqual(initialProfiles.first?.cookies, [])
        XCTAssertEqual(initialProfiles.first?.windowItems, [])
        XCTAssertEqual(initialProfiles.first?.bridgeChannels, [])
        XCTAssertEqual(initialProfiles.first?.customScripts, [])

        let customProfile = WebViewPreloadProfile(name: "Custom", isEnabled: true)
        PreloadProfileStore.upsertSavedProfile(customProfile, defaults: defaults)
        let createdProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(createdProfiles.map(\.name), ["Custom", "Default"])
        XCTAssertEqual(createdProfiles.first?.id, customProfile.id)

        PreloadProfileStore.saveProfiles(
            createdProfiles.filter { $0.id != customProfile.id },
            defaults: defaults
        )
        let deletedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(deletedProfiles.map(\.name), ["Default"])
        XCTAssertNil(deletedProfiles.first { $0.id == customProfile.id })
    }

    func testActiveProfileFallbackMatchesSavedDefaultSetup() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        let savedDefault = PreloadProfileStore.savedProfiles(defaults: defaults).first

        XCTAssertEqual(activeProfile.id, WebViewPreloadProfile.defaultSavedSetupID)
        XCTAssertEqual(activeProfile.id, savedDefault?.id)
        XCTAssertEqual(activeProfile.name, "Default")
        XCTAssertFalse(activeProfile.isEnabled)
    }

    func testSavingInitialDefaultSetupDoesNotCreateDuplicateDefault() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var state = PreloadProfileSettingsState()
        state.loadIfNeeded(
            activeProfile: { PreloadProfileStore.activeProfile(defaults: defaults) },
            savedProfiles: { PreloadProfileStore.savedProfiles(defaults: defaults) }
        )

        state.saveCurrentProfile(defaults: defaults)

        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)
        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        XCTAssertEqual(savedProfiles.map(\.name), ["Default"])
        XCTAssertEqual(savedProfiles.first?.id, WebViewPreloadProfile.defaultSavedSetupID)
        XCTAssertEqual(activeProfile.id, WebViewPreloadProfile.defaultSavedSetupID)
        XCTAssertTrue(activeProfile.isEnabled)
        XCTAssertTrue(savedProfiles.first?.isEnabled ?? false)
    }

    func testSaveCurrentProfileActivatesEmptySetupAndReplacesPreviousActiveProfile() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var previousActive = WebViewPreloadProfile.nativeBridgeDemoPreset
        previousActive.id = UUID()
        previousActive.name = "Native Bridge Demo Copy"
        PreloadProfileStore.saveActiveProfile(previousActive, defaults: defaults)
        PreloadProfileStore.saveProfiles([previousActive, .defaultSavedSetup], defaults: defaults)

        var state = PreloadProfileSettingsState()
        state.loadIfNeeded(
            activeProfile: { PreloadProfileStore.activeProfile(defaults: defaults) },
            savedProfiles: { PreloadProfileStore.savedProfiles(defaults: defaults) }
        )

        state.startEmptySetup()
        state.saveCurrentProfile(defaults: defaults)

        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(activeProfile.id, state.profile.id)
        XCTAssertEqual(activeProfile.name, "Untitled Setup")
        XCTAssertTrue(activeProfile.isEnabled)
        XCTAssertEqual(activeProfile.cookies, [])
        XCTAssertFalse(savedProfiles.contains { $0.name == "Native Bridge Demo Copy" })
        XCTAssertTrue(savedProfiles.contains { $0.id == state.profile.id && $0.name == "Untitled Setup" })
    }

    func testStoreFiltersLegacyGeneratedNativeBridgeDemoCopy() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var legacyCopy = WebViewPreloadProfile.nativeBridgeDemoPreset
        legacyCopy.id = UUID()
        legacyCopy.name = "Native Bridge Demo Copy"
        PreloadProfileStore.saveActiveProfile(legacyCopy, defaults: defaults)
        PreloadProfileStore.saveProfiles([legacyCopy], defaults: defaults)

        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(activeProfile.id, WebViewPreloadProfile.defaultSavedSetupID)
        XCTAssertEqual(savedProfiles.map(\.name), ["Default"])
        XCTAssertFalse(savedProfiles.contains { $0.name == "Native Bridge Demo Copy" })
    }

    func testStoreKeepsEditedNativeBridgeDemoCopy() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var editedCopy = WebViewPreloadProfile.nativeBridgeDemoPreset
        editedCopy.id = UUID()
        editedCopy.name = "Native Bridge Demo Copy"
        editedCopy.cookies[0].value = "user-edited-session"
        PreloadProfileStore.saveActiveProfile(editedCopy, defaults: defaults)
        PreloadProfileStore.saveProfiles([editedCopy], defaults: defaults)

        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(activeProfile.id, editedCopy.id)
        XCTAssertEqual(activeProfile.cookies.first?.value, "user-edited-session")
        XCTAssertEqual(savedProfiles.map(\.name), ["Native Bridge Demo Copy"])
        XCTAssertEqual(savedProfiles.first?.cookies.first?.value, "user-edited-session")
    }

    func testStoreCanSaveNativeBridgeDemoAsOrdinarySavedSetup() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let demoProfile = WebViewPreloadProfile.nativeBridgeDemoPreset

        PreloadProfileStore.upsertSavedProfile(demoProfile, defaults: defaults)
        let profiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles.map(\.name), ["Native Bridge Demo", "Default"])
        XCTAssertEqual(profiles[0].id, WebViewPreloadProfile.nativeBridgeDemoPresetID)
        XCTAssertEqual(profiles[1].id, WebViewPreloadProfile.defaultSavedSetupID)
    }

    func testSettingsStateStartsEmptySetupWithoutSaving() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var state = PreloadProfileSettingsState()
        state.loadIfNeeded(
            activeProfile: { .empty },
            savedProfiles: { PreloadProfileStore.savedProfiles(defaults: defaults) }
        )

        state.startEmptySetup()

        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        XCTAssertEqual(savedProfiles.map(\.name), ["Default"])
        XCTAssertEqual(state.profile.name, "Untitled Setup")
        XCTAssertFalse(state.profile.isEnabled)
        XCTAssertEqual(state.profile.cookies, [])
        XCTAssertEqual(state.profile.windowItems, [])
        XCTAssertEqual(state.profile.bridgeChannels, [])
        XCTAssertEqual(state.profile.customScripts, [])
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

    func testApplyCurrentProfileDoesNotOverwriteMatchingSavedSetup() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let savedProfile = WebViewPreloadProfile(name: "Saved", isEnabled: true)
        PreloadProfileStore.upsertSavedProfile(savedProfile, defaults: defaults)
        var state = PreloadProfileSettingsState()
        state.loadIfNeeded(
            activeProfile: { savedProfile },
            savedProfiles: { PreloadProfileStore.savedProfiles(defaults: defaults) }
        )

        state.profile.cookies.append(PreloadCookie(name: "session", value: "updated"))
        state.applyCurrentProfile(defaults: defaults)

        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)
        let originalSavedProfile = savedProfiles.first { $0.id == savedProfile.id }

        XCTAssertEqual(activeProfile.cookies.map(\.name), ["session"])
        XCTAssertEqual(originalSavedProfile?.cookies, [])
    }

    func testApplyCurrentProfileDoesNotOverwriteSavedDemoSetup() {
        let suiteName = "PreloadProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let savedDemo = PreloadProfileStore.upsertSavedProfile(
            .nativeBridgeDemoPreset,
            defaults: defaults
        )
        var state = PreloadProfileSettingsState()
        state.loadIfNeeded(
            activeProfile: { savedDemo },
            savedProfiles: { PreloadProfileStore.savedProfiles(defaults: defaults) }
        )

        state.profile.cookies.append(PreloadCookie(name: "edited", value: "yes"))
        state.applyCurrentProfile(defaults: defaults)

        let activeProfile = PreloadProfileStore.activeProfile(defaults: defaults)
        let savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)

        let persistedDemo = savedProfiles.first { $0.id == savedDemo.id }

        XCTAssertEqual(activeProfile.id, savedDemo.id)
        XCTAssertEqual(activeProfile.cookies.last?.name, "edited")
        XCTAssertEqual(persistedDemo?.cookies.map(\.name), savedDemo.cookies.map(\.name))
        XCTAssertFalse(persistedDemo?.cookies.contains { $0.name == "edited" } ?? true)
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

    func testCookieSecurePropertyIsOnlySetWhenEnabled() {
        let plainCookie = PreloadCookie(name: "plain", value: "abc", isSecure: false)
        let secureCookie = PreloadCookie(name: "secure", value: "abc", isSecure: true)

        let plainHTTPCookie = PreloadCookieApplicator.makeHTTPCookie(
            from: plainCookie,
            url: URL(string: "https://example.com/path")!
        )
        let secureHTTPCookie = PreloadCookieApplicator.makeHTTPCookie(
            from: secureCookie,
            url: URL(string: "https://example.com/path")!
        )

        XCTAssertNil(plainHTTPCookie?.properties?[.secure])
        XCTAssertEqual(plainHTTPCookie?.isSecure, false)
        XCTAssertEqual(secureHTTPCookie?.properties?[.secure] as? String, "TRUE")
        XCTAssertEqual(secureHTTPCookie?.isSecure, true)
    }

    private func makeJavaScriptContext(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> JSContext {
        let context = JSContext()!
        context.exceptionHandler = { _, exception in
            XCTFail("JavaScript exception: \(exception?.toString() ?? "unknown")", file: file, line: line)
        }
        return context
    }
}
