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
            return """
                (function() {
                var response = \(responseLiteral);
                if (typeof window.__winaPreloadMarkNativePostMessage === 'function') {
                    window.__winaPreloadMarkNativePostMessage(response);
                }
                window.postMessage(response, '*');
                })();
                """

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

            window.__winaPreloadNativePostMessageTokenKey = '__winaPreloadNativePostMessageToken';
            window.__winaPreloadNativePostMessageTokens = window.__winaPreloadNativePostMessageTokens || {};
            window.__winaPreloadNativePostMessagePrimitiveQueue = window.__winaPreloadNativePostMessagePrimitiveQueue || [];

            window.__winaPreloadSerializePostMessageValue = function(value) {
                try {
                    return JSON.stringify(value);
                } catch (_) {
                    return String(value);
                }
            };

            window.__winaPreloadMarkNativePostMessage = function(value) {
                if (Array.isArray(value)) {
                    window.__winaPreloadNativePostMessagePrimitiveQueue.push(
                        window.__winaPreloadSerializePostMessageValue(value)
                    );
                    return;
                }

                if (value !== null && (typeof value === 'object' || typeof value === 'function')) {
                    var token = String(Date.now()) + ':' + String(Math.random());
                    window.__winaPreloadNativePostMessageTokens[token] = true;
                    try {
                        Object.defineProperty(value, window.__winaPreloadNativePostMessageTokenKey, {
                            value: token,
                            enumerable: false,
                            configurable: true
                        });
                    } catch (_) {
                        value[window.__winaPreloadNativePostMessageTokenKey] = token;
                    }
                    return;
                }

                window.__winaPreloadNativePostMessagePrimitiveQueue.push(
                    window.__winaPreloadSerializePostMessageValue(value)
                );
                if (window.__winaPreloadNativePostMessagePrimitiveQueue.length > 20) {
                    window.__winaPreloadNativePostMessagePrimitiveQueue.shift();
                }
            };

            window.__winaPreloadConsumeNativePostMessage = function(value) {
                if (value !== null && (typeof value === 'object' || typeof value === 'function')) {
                    var token = value[window.__winaPreloadNativePostMessageTokenKey];
                    if (token && window.__winaPreloadNativePostMessageTokens[token]) {
                        delete window.__winaPreloadNativePostMessageTokens[token];
                        try {
                            delete value[window.__winaPreloadNativePostMessageTokenKey];
                        } catch (_) {}
                        return true;
                    }
                    if (!Array.isArray(value)) {
                        return false;
                    }
                }

                var serialized = window.__winaPreloadSerializePostMessageValue(value);
                var index = window.__winaPreloadNativePostMessagePrimitiveQueue.indexOf(serialized);
                if (index !== -1) {
                    window.__winaPreloadNativePostMessagePrimitiveQueue.splice(index, 1);
                    return true;
                }
                return false;
            };
        """

    private static let postMessageCaptureScript = """
            window.addEventListener('message', function(event) {
                try {
                    if (typeof window.__winaPreloadConsumeNativePostMessage === 'function'
                        && window.__winaPreloadConsumeNativePostMessage(event.data)) {
                        return;
                    }
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
        var rendered = ""
        var cursor = template.startIndex

        while let openRange = template[cursor...].range(of: "{{") {
            rendered += template[cursor..<openRange.lowerBound]

            let tokenStart = openRange.upperBound
            guard let closeRange = template[tokenStart...].range(of: "}}") else {
                rendered += template[openRange.lowerBound...]
                return rendered
            }

            let key = String(template[tokenStart..<closeRange.lowerBound])
            rendered += replacements[key] ?? String(template[openRange.lowerBound..<closeRange.upperBound])
            cursor = closeRange.upperBound
        }

        rendered += template[cursor...]
        return rendered
    }

    static func messageJSONString(_ message: Any) -> String {
        if JSONSerialization.isValidJSONObject(message),
            let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        {
            return JavaScriptLiteral.escapedJavaScriptUnsafeCharacters(text)
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
        replacements[prefix] =
            BridgeMessageValueFormatter.stringValue(
                value,
                escapesStringContent: true,
                nullString: "null"
            ) ?? ""

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
        return BridgeMessageValueFormatter.stringValue(
            current,
            escapesStringContent: false,
            nullString: nil
        )
    }
}

// MARK: - JavaScript Utilities

private enum BridgeMessageValueFormatter {
    static func stringValue(
        _ value: Any,
        escapesStringContent: Bool,
        nullString: String?
    ) -> String? {
        if value is NSNull { return nullString }
        if let text = value as? String {
            return escapesStringContent ? JavaScriptLiteral.escapedStringContent(text) : text
        }
        if let number = value as? NSNumber {
            return isBooleanNumber(number) ? (number.boolValue ? "true" : "false") : number.stringValue
        }
        if JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        {
            return JavaScriptLiteral.escapedJavaScriptUnsafeCharacters(text)
        }
        return String(describing: value)
    }

    private static func isBooleanNumber(_ number: NSNumber) -> Bool {
        CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID()
    }
}

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
        return
            escapedJavaScriptUnsafeCharacters(text)
    }

    nonisolated static func escapedStringContent(_ value: String) -> String {
        let quotedValue = quoted(value)
        guard quotedValue.count >= 2 else { return value }
        return String(quotedValue.dropFirst().dropLast())
    }

    nonisolated static func escapedJavaScriptUnsafeCharacters(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<", with: "\\u003C")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
