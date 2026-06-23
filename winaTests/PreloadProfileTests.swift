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
            ]
        )

        XCTAssertEqual(profile.enabledBridgeChannelNames, ["request"])
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
