//
//  PreloadProfile.swift
//  wina
//
//  Reusable WKWebView preload and bridge mock profile models.
//

import Foundation

// MARK: - Profile

struct WebViewPreloadProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var cookies: [PreloadCookie]
    var windowItems: [WindowInjectionItem]
    var bridgeChannels: [BridgeChannel]
    var capturesWindowPostMessage: Bool
    var customScripts: [PreloadCustomScript]

    init(
        id: UUID = UUID(),
        name: String = "Default",
        isEnabled: Bool = false,
        cookies: [PreloadCookie] = [],
        windowItems: [WindowInjectionItem] = [],
        bridgeChannels: [BridgeChannel] = [],
        capturesWindowPostMessage: Bool = false,
        customScripts: [PreloadCustomScript] = []
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.cookies = cookies
        self.windowItems = windowItems
        self.bridgeChannels = bridgeChannels
        self.capturesWindowPostMessage = capturesWindowPostMessage
        self.customScripts = customScripts
    }

    var enabledBridgeChannelNames: [String] {
        guard isEnabled else { return [] }
        var names =
            bridgeChannels
            .filter(\.isEnabled)
            .map(\.name)
            .filter { BridgeChannelNameValidator.isValid($0) && !BridgeChannelNameValidator.reservedNames.contains($0) }

        if capturesWindowPostMessage {
            names.append(PreloadBridgeConstants.postMessageCaptureChannel)
        }

        return Array(Set(names)).sorted()
    }

    var enabledSummary: String {
        guard isEnabled else { return "Off" }
        let count =
            cookies.filter(\.isEnabled).count + windowItems.filter(\.isEnabled).count
            + bridgeChannels.filter(\.isEnabled).count + customScripts.filter(\.isEnabled).count
        return count == 0 ? "On" : "\(count) items"
    }

    static var empty: WebViewPreloadProfile {
        WebViewPreloadProfile()
    }

    static var nativeBridgeDemoPreset: WebViewPreloadProfile {
        WebViewPreloadProfile(
            name: "Native Bridge Demo",
            isEnabled: true,
            cookies: [
                PreloadCookie(
                    name: "walnut_session",
                    value: "demo-session",
                    domainMode: .currentHost,
                    path: "/",
                    expires: .session,
                    isSecure: true,
                    sameSite: .lax
                )
            ],
            windowItems: [
                WindowInjectionItem(
                    name: "appVersion",
                    kind: .variable,
                    valueKind: .string,
                    value: "1.0.0-demo"
                ),
                WindowInjectionItem(
                    name: "getAuthToken",
                    kind: .functionReturn,
                    valueKind: .string,
                    value: "demo-token"
                ),
            ],
            bridgeChannels: [
                BridgeChannel(
                    name: "request",
                    responseRules: [
                        BridgeResponseRule(
                            name: "getAuthToken",
                            matcher: .typeEquals("getAuthToken"),
                            response: BridgeResponse(
                                target: .postMessage,
                                bodyTemplate: """
                                    {
                                      "id": "{{message.id}}",
                                      "type": "getAuthToken:response",
                                      "payload": {
                                        "token": "demo-token",
                                        "source": "Walnut Preload"
                                      }
                                    }
                                    """
                            ),
                            delayMilliseconds: 300
                        )
                    ]
                )
            ],
            capturesWindowPostMessage: true
        )
    }
}

// MARK: - Cookies

struct PreloadCookie: Codable, Equatable, Identifiable {
    var id: UUID
    var isEnabled: Bool
    var name: String
    var value: String
    var domainMode: PreloadCookieDomainMode
    var customDomain: String
    var path: String
    var expires: PreloadCookieExpiration
    var isSecure: Bool
    var isHTTPOnly: Bool
    var sameSite: PreloadCookieSameSite

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "",
        value: String = "",
        domainMode: PreloadCookieDomainMode = .currentHost,
        customDomain: String = "",
        path: String = "/",
        expires: PreloadCookieExpiration = .session,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: PreloadCookieSameSite = .lax
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.value = value
        self.domainMode = domainMode
        self.customDomain = customDomain
        self.path = path
        self.expires = expires
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }
}

enum PreloadCookieDomainMode: String, Codable, CaseIterable, Equatable {
    case currentHost
    case custom

    var title: String {
        switch self {
        case .currentHost: "Current host"
        case .custom: "Custom domain"
        }
    }
}

enum PreloadCookieExpiration: String, Codable, CaseIterable, Equatable {
    case session
    case oneHour
    case oneDay
    case sevenDays

    var title: String {
        switch self {
        case .session: "Session"
        case .oneHour: "1 hour"
        case .oneDay: "1 day"
        case .sevenDays: "7 days"
        }
    }

    var expiresDate: Date? {
        switch self {
        case .session: nil
        case .oneHour: Date(timeIntervalSinceNow: 60 * 60)
        case .oneDay: Date(timeIntervalSinceNow: 60 * 60 * 24)
        case .sevenDays: Date(timeIntervalSinceNow: 60 * 60 * 24 * 7)
        }
    }
}

enum PreloadCookieSameSite: String, Codable, CaseIterable, Equatable {
    case lax
    case strict
    case none

    var title: String { rawValue.capitalized }

    var httpCookieString: String {
        switch self {
        case .lax: "Lax"
        case .strict: "Strict"
        case .none: "None"
        }
    }
}

// MARK: - Window Injection

struct WindowInjectionItem: Codable, Equatable, Identifiable {
    var id: UUID
    var isEnabled: Bool
    var name: String
    var kind: WindowInjectionKind
    var valueKind: PreloadValueKind
    var value: String

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "",
        kind: WindowInjectionKind = .variable,
        valueKind: PreloadValueKind = .string,
        value: String = ""
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.kind = kind
        self.valueKind = valueKind
        self.value = value
    }
}

enum WindowInjectionKind: String, Codable, CaseIterable, Equatable {
    case variable
    case functionReturn
    case functionBody

    var title: String {
        switch self {
        case .variable: "Variable"
        case .functionReturn: "Function returns value"
        case .functionBody: "Raw function body"
        }
    }
}

enum PreloadValueKind: String, Codable, CaseIterable, Equatable {
    case string
    case json

    var title: String {
        switch self {
        case .string: "String"
        case .json: "JSON"
        }
    }
}

// MARK: - Bridge

enum PreloadBridgeConstants {
    static let postMessageCaptureChannel = "winaPostMessage"
}

struct BridgeChannel: Codable, Equatable, Identifiable {
    var id: UUID
    var isEnabled: Bool
    var name: String
    var responseRules: [BridgeResponseRule]

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "request",
        responseRules: [BridgeResponseRule] = []
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.responseRules = responseRules
    }
}

struct BridgeResponseRule: Codable, Equatable, Identifiable {
    var id: UUID
    var isEnabled: Bool
    var name: String
    var matcher: BridgeMatcher
    var response: BridgeResponse
    var delayMilliseconds: Int

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "Response",
        matcher: BridgeMatcher = .any,
        response: BridgeResponse = BridgeResponse(),
        delayMilliseconds: Int = 0
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.matcher = matcher
        self.response = response
        self.delayMilliseconds = delayMilliseconds
    }
}

enum BridgeMatcher: Codable, Equatable {
    case any
    case typeEquals(String)
    case jsonPathEquals(path: String, value: String)
}

struct BridgeResponse: Codable, Equatable {
    var target: BridgeResponseTarget
    var bodyTemplate: String
    var eventName: String
    var callbackName: String
    var customJavaScript: String

    init(
        target: BridgeResponseTarget = .postMessage,
        bodyTemplate: String = "{\n  \"ok\": true\n}",
        eventName: String = "nativeMessage",
        callbackName: String = "onNativeResponse",
        customJavaScript: String = ""
    ) {
        self.target = target
        self.bodyTemplate = bodyTemplate
        self.eventName = eventName
        self.callbackName = callbackName
        self.customJavaScript = customJavaScript
    }
}

enum BridgeResponseTarget: String, Codable, CaseIterable, Equatable {
    case postMessage
    case customEvent
    case callback
    case customJavaScript

    var title: String {
        switch self {
        case .postMessage: "window.postMessage"
        case .customEvent: "CustomEvent"
        case .callback: "Callback function"
        case .customJavaScript: "Custom JS"
        }
    }
}

// MARK: - Custom Script

struct PreloadCustomScript: Codable, Equatable, Identifiable {
    var id: UUID
    var isEnabled: Bool
    var name: String
    var source: String
    var forMainFrameOnly: Bool

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String = "Custom Script",
        source: String = "",
        forMainFrameOnly: Bool = false
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.source = source
        self.forMainFrameOnly = forMainFrameOnly
    }
}
