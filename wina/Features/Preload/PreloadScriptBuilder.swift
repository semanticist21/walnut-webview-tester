//
//  PreloadScriptBuilder.swift
//  wina
//
//  Builds WKUserScript sources and native bridge response JavaScript.
//

import Foundation

// MARK: - Script Builder

enum PreloadScriptBuilder {
    static func bootstrapScript(for profile: WebViewPreloadProfile) -> String {
        guard profile.isEnabled else { return "" }

        var blocks: [String] = [baseHelpers]

        for item in profile.windowItems where item.isEnabled {
            if let script = windowItemScript(item) {
                blocks.append(script)
            }
        }

        if profile.capturesWindowPostMessage {
            blocks.append(postMessageCaptureScript)
        }

        return """
            (function() {
                if (window.__winaPreloadApplied) return;
                window.__winaPreloadApplied = true;
            \(blocks.joined(separator: "\n\n"))
            })();
            """
    }

    static func customScripts(for profile: WebViewPreloadProfile) -> [(source: String, forMainFrameOnly: Bool)] {
        guard profile.isEnabled else { return [] }
        return profile.customScripts
            .filter { $0.isEnabled && !$0.source.isEmpty }
            .map { customScript in
                (
                    source: """
                    (function() {
                        try {
                    \(customScript.source)
                        } catch (error) {
                            console.warn('[Walnut Preload] custom script failed:', error);
                        }
                    })();
                    """,
                    forMainFrameOnly: customScript.forMainFrameOnly
                )
            }
    }

    static func responseScript(
        for response: BridgeResponse,
        message: Any,
        channel: String
    ) -> String {
        let renderedBody = BridgeTemplateRenderer.render(response.bodyTemplate, message: message)
        let responseLiteral = JavaScriptLiteral.literal(from: renderedBody, valueKind: .json)
        let channelLiteral = JavaScriptLiteral.quoted(channel)

        switch response.target {
        case .postMessage:
            return "window.postMessage(\(responseLiteral), '*');"

        case .customEvent:
            let eventName = JavaScriptLiteral.quoted(response.eventName)
            return "window.dispatchEvent(new CustomEvent(\(eventName), { detail: \(responseLiteral) }));"

        case .callback:
            guard JavaScriptPath.isValid(response.callbackName) else { return "" }
            let pathLiteral = JavaScriptPath.arrayLiteral(response.callbackName)
            return """
                (function() {
                    var callback = window.__winaPreloadGetPath(\(pathLiteral));
                    if (typeof callback === 'function') {
                        callback(\(responseLiteral));
                    }
                })();
                """

        case .customJavaScript:
            let messageLiteral = JavaScriptLiteral.literal(
                from: BridgeTemplateRenderer.messageJSONString(message), valueKind: .json)
            return BridgeTemplateRenderer.render(
                response.customJavaScript,
                replacements: [
                    "message": messageLiteral,
                    "response": responseLiteral,
                    "channel": channelLiteral,
                ]
            )
        }
    }

    private static func windowItemScript(_ item: WindowInjectionItem) -> String? {
        guard JavaScriptPath.isValid(item.name) else { return nil }
        let pathLiteral = JavaScriptPath.arrayLiteral(item.name)

        switch item.kind {
        case .variable:
            return
                "window.__winaPreloadSetPath(\(pathLiteral), \(JavaScriptLiteral.literal(from: item.value, valueKind: item.valueKind)));"

        case .functionReturn:
            let literal = JavaScriptLiteral.literal(from: item.value, valueKind: item.valueKind)
            return "window.__winaPreloadSetPath(\(pathLiteral), function() { return \(literal); });"

        case .functionBody:
            return """
                window.__winaPreloadSetPath(\(pathLiteral), function() {
                \(item.value)
                });
                """
        }
    }

    private static let baseHelpers = """
            window.__wina = window.__wina || {};
            window.__wina.preload = window.__wina.preload || {};

            window.__winaPreloadSetPath = function(parts, value) {
                var target = window;
                for (var i = 0; i < parts.length - 1; i += 1) {
                    var key = parts[i];
                    if (!target[key] || typeof target[key] !== 'object') {
                        target[key] = {};
                    }
                    target = target[key];
                }
                target[parts[parts.length - 1]] = value;
            };

            window.__winaPreloadGetPath = function(parts) {
                var target = window;
                for (var i = 0; i < parts.length; i += 1) {
                    if (target == null) return undefined;
                    target = target[parts[i]];
                }
                return target;
            };
        """

    private static let postMessageCaptureScript = """
            window.addEventListener('message', function(event) {
                try {
                    if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.winaPostMessage) {
                        return;
                    }
                    window.webkit.messageHandlers.winaPostMessage.postMessage({
                        origin: event.origin,
                        data: event.data
                    });
                } catch (_) {}
            });
        """
}

// MARK: - Template Rendering

enum BridgeTemplateRenderer {
    static func render(_ template: String, message: Any) -> String {
        render(template, replacements: messageReplacements(message))
    }

    static func render(_ template: String, replacements: [String: String]) -> String {
        var rendered = template
        for (key, value) in replacements {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return rendered
    }

    static func messageJSONString(_ message: Any) -> String {
        if JSONSerialization.isValidJSONObject(message),
            let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        {
            return text
        }
        if let text = message as? String {
            return JavaScriptLiteral.quoted(text)
        }
        return "null"
    }

    private static func messageReplacements(_ message: Any) -> [String: String] {
        var replacements = ["message": messageJSONString(message)]
        guard let dictionary = message as? [String: Any] else { return replacements }
        collect(prefix: "message", value: dictionary, into: &replacements)
        return replacements
    }

    private static func collect(prefix: String, value: Any, into replacements: inout [String: String]) {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                collect(prefix: "\(prefix).\(key)", value: nested, into: &replacements)
            }
            return
        }

        if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                collect(prefix: "\(prefix).\(index)", value: nested, into: &replacements)
            }
            return
        }

        replacements[prefix] = stringValue(value)
    }

    private static func stringValue(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let text = value as? String { return JavaScriptLiteral.escapedStringContent(text) }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let number = value as? NSNumber { return number.stringValue }
        if JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        {
            return text
        }
        return String(describing: value)
    }
}

// MARK: - Matching

enum BridgeRuleMatcher {
    static func matches(_ matcher: BridgeMatcher, message: Any) -> Bool {
        switch matcher {
        case .any:
            return true

        case .typeEquals(let expected):
            return value(at: "type", in: message) == expected

        case .jsonPathEquals(let path, let expected):
            return value(at: path, in: message) == expected
        }
    }

    static func value(at path: String, in message: Any) -> String? {
        let parts = path.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }

        var current: Any? = message
        for part in parts {
            if let dictionary = current as? [String: Any] {
                current = dictionary[part]
            } else if let array = current as? [Any], let index = Int(part), array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }

        guard let current else { return nil }
        if current is NSNull { return nil }
        if let text = current as? String { return text }
        if let bool = current as? Bool { return bool ? "true" : "false" }
        if let number = current as? NSNumber { return number.stringValue }
        return String(describing: current)
    }
}

// MARK: - JavaScript Utilities

enum BridgeChannelNameValidator {
    static let reservedNames: Set<String> = [
        "consoleLog",
        "networkRequest",
        "resourceTiming",
        PreloadBridgeConstants.postMessageCaptureChannel,
    ]

    nonisolated static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let regex = #"^[A-Za-z_][A-Za-z0-9_]*$"#
        return name.range(of: regex, options: .regularExpression) != nil
    }
}

enum JavaScriptPath {
    nonisolated static func isValid(_ path: String) -> Bool {
        let parts = path.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return false }
        return parts.allSatisfy(BridgeChannelNameValidator.isValid)
    }

    nonisolated static func arrayLiteral(_ path: String) -> String {
        let parts = path.split(separator: ".").map(String.init)
        let quoted = parts.map(JavaScriptLiteral.quoted).joined(separator: ", ")
        return "[\(quoted)]"
    }
}

enum JavaScriptLiteral {
    nonisolated static func literal(from value: String, valueKind: PreloadValueKind) -> String {
        switch valueKind {
        case .string:
            return quoted(value)

        case .json:
            guard let data = value.data(using: .utf8),
                (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
            else {
                return quoted(value)
            }
            return value
        }
    }

    nonisolated static func quoted(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
            let text = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return text
    }

    nonisolated static func escapedStringContent(_ value: String) -> String {
        let quotedValue = quoted(value)
        guard quotedValue.count >= 2 else { return value }
        return String(quotedValue.dropFirst().dropLast())
    }
}
