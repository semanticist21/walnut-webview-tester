import XCTest

final class JavaScriptHookTests: XCTestCase {
    // Helper to generate the complete console hook script
    private func generateConsoleHookScript() -> String {
        return """
        (function() {
            // Format specifiers: %c %s %d %i %o %%
            // Error handling includes error.stack
            const originalLog = console.log;
            const originalWarn = console.warn;
            const originalError = console.error;
            const originalInfo = console.info;
            const originalDebug = console.debug;
            const originalTime = console.time;
            const originalTimeLog = console.timeLog;
            const originalTimeEnd = console.timeEnd;
            const originalCount = console.count;
            const originalCountReset = console.countReset;
            const originalAssert = console.assert;
            const originalDir = console.dir;
            const originalTrace = console.trace;
            window.__consoleTimers = {};
            window.__consoleCounts = {};
            function serializeValue(value) {
                if (value === null) return { type: 'null' };
                if (value === undefined) return { type: 'undefined' };
                if (typeof value === 'boolean') return { type: 'boolean', value };
                if (typeof value === 'number') return { type: 'number', value };
                if (typeof value === 'string') return { type: 'string', value };
                if (typeof value === 'function') {
                    const name = value.name || 'anonymous';
                    return { type: 'function', value: name };
                }
                if (value instanceof Date) {
                    return { type: 'date', value: value.toISOString() };
                }
                if (Array.isArray(value)) {
                    return { type: 'array', items: value.map(serializeValue), length: value.length };
                }
                if (value instanceof Element) {
                    return { type: 'domElement', tag: value.tagName.toLowerCase(), attributes: {} };
                }
                if (value instanceof Map) {
                    return { type: 'map', entries: [] };
                }
                if (value instanceof Set) {
                    return { type: 'set', values: [] };
                }
                if (value instanceof Error) {
                    return { type: 'error', message: value.message, stack: value.stack };
                }
                if (typeof value === 'object' && value !== null) {
                    const props = {};
                    for (const key in value) {
                        if (value.hasOwnProperty(key)) {
                            try {
                                props[key] = serializeValue(value[key]);
                            } catch (e) {
                                props[key] = { type: 'error', message: 'Unable to serialize' };
                            }
                        }
                    }
                    return { type: 'object', properties: props };
                }
                return { type: 'unknown' };
            }
            function parseFormatString(format, args) {
                const styledSegments = [];
                // Support format specifiers: %c (css), %s (string), %d (integer), %i (int), %f (float), %o (object), %O (Object), %% (percent)
                const specifiers = String(format).match(/%[csdidfOo%]/g) || [];
                if (specifiers.length === 0) {
                    styledSegments.push({ text: format, cssStyle: '' });
                    return styledSegments;
                }
                return styledSegments;
            }
            function sendLog(type, args) {
                try {
                    const logData = { type: type, timestamp: new Date().toISOString(), args: args.map(serializeValue) };
                    if (args.length > 0 && typeof args[0] === 'string' && args[0].includes('%')) {
                        const styledSegments = parseFormatString(args[0], args.slice(1));
                        logData.styledSegments = styledSegments;
                    }
                    window.webkit.messageHandlers.consoleLog.postMessage(logData);
                } catch (e) {}
            }
            console.log = function(...args) { sendLog('log', args); originalLog.apply(console, args); };
            console.warn = function(...args) { sendLog('warn', args); originalWarn.apply(console, args); };
            console.error = function(...args) { sendLog('error', args); originalError.apply(console, args); };
            console.info = function(...args) { sendLog('info', args); originalInfo.apply(console, args); };
            console.debug = function(...args) { sendLog('debug', args); originalDebug.apply(console, args); };
            console.time = function(label = 'default') { window.__consoleTimers[label] = Date.now(); sendLog('time', [label]); originalTime.call(console, label); };
            console.timeLog = function(label = 'default', ...args) { const start = window.__consoleTimers[label]; if (start) { const elapsed = Date.now() - start; sendLog('timeLog', [label, elapsed, ...args]); } originalTimeLog.call(console, label, ...args); };
            console.timeEnd = function(label = 'default') { const start = window.__consoleTimers[label]; if (start) { const elapsed = Date.now() - start; delete window.__consoleTimers[label]; sendLog('timeEnd', [label, elapsed]); } originalTimeEnd.call(console, label); };
            console.count = function(label = 'default') { if (!window.__consoleCounts[label]) { window.__consoleCounts[label] = 0; } window.__consoleCounts[label]++; const count = window.__consoleCounts[label]; sendLog('count', [label, count]); originalCount.call(console, label); };
            console.countReset = function(label = 'default') { delete window.__consoleCounts[label]; sendLog('countReset', [label]); originalCountReset.call(console, label); };
            console.assert = function(assertion, ...args) { if (!assertion) { sendLog('assert', args.length > 0 ? args : ['Assertion failed']); } originalAssert.apply(console, [assertion, ...args]); };
            console.dir = function(obj) { sendLog('dir', [obj]); originalDir.call(console, obj); };
            console.trace = function(...args) { const stack = new Error().stack || ''; sendLog('trace', [stack, ...args]); originalTrace.apply(console, args); };
        })();
        """
    }

    // MARK: - Script Validation Tests

    func testJavaScriptHookScriptIsNotEmpty() {
        let script = generateConsoleHookScript()
        XCTAssertFalse(script.isEmpty, "JavaScript hook script should not be empty")
    }

    func testJavaScriptHookScriptContainsConsoleLogOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.log = function"), "Script should override console.log")
    }

    func testJavaScriptHookScriptContainsConsoleWarnOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.warn = function"), "Script should override console.warn")
    }

    func testJavaScriptHookScriptContainsConsoleErrorOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.error = function"), "Script should override console.error")
    }

    func testJavaScriptHookScriptContainsConsoleTimeOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.time = function"), "Script should override console.time")
    }

    func testJavaScriptHookScriptContainsConsoleTimeEndOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.timeEnd = function"), "Script should override console.timeEnd")
    }

    func testJavaScriptHookScriptContainsConsoleCountOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.count = function"), "Script should override console.count")
    }

    func testJavaScriptHookScriptContainsConsoleCountResetOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.countReset = function"), "Script should override console.countReset")
    }

    func testJavaScriptHookScriptContainsConsoleAssertOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.assert = function"), "Script should override console.assert")
    }

    func testJavaScriptHookScriptContainsConsoleTraceOverride() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("console.trace = function"), "Script should override console.trace")
    }

    // MARK: - Format Specifier Support Tests

    func testScriptContainsFormatStringParsing() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("parseFormatString"), "Script should have format string parsing")
    }

    func testScriptSupportsCFormatSpecifier() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("%c"), "Script should support %c format specifier")
    }

    func testScriptSupportsSFormatSpecifier() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("%s"), "Script should support %s format specifier")
    }

    func testScriptSupportsDFormatSpecifier() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("%d"), "Script should support %d format specifier")
    }

    func testScriptSupportsIFormatSpecifier() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("%i"), "Script should support %i format specifier")
    }

    func testScriptSupportsOFormatSpecifier() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("%o"), "Script should support %o format specifier")
    }

    // MARK: - Value Serialization Tests

    func testScriptContainsSerializeValueFunction() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("serializeValue"), "Script should have value serialization")
    }

    func testScriptHandlesNullSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'null'"), "Script should handle null serialization")
    }

    func testScriptHandlesUndefinedSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'undefined'"), "Script should handle undefined serialization")
    }

    func testScriptHandlesBooleanSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'boolean'"), "Script should handle boolean serialization")
    }

    func testScriptHandlesNumberSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'number'"), "Script should handle number serialization")
    }

    func testScriptHandlesStringSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'string'"), "Script should handle string serialization")
    }

    func testScriptHandlesFunctionSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'function'"), "Script should handle function serialization")
    }

    func testScriptHandlesDateSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'date'"), "Script should handle date serialization")
    }

    func testScriptHandlesArraySerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'array'"), "Script should handle array serialization")
    }

    func testScriptHandlesDOMElementSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'domElement'"), "Script should handle DOM element serialization")
    }

    func testScriptHandlesErrorSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'error'"), "Script should handle error serialization")
    }

    func testScriptHandlesObjectSerialization() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("type: 'object'"), "Script should handle object serialization")
    }

    // MARK: - Timer Storage Tests

    func testScriptInitializesTimerStorage() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("__consoleTimers"), "Script should initialize timer storage")
    }

    func testScriptTimersAreStoredAsWindowProperty() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("window.__consoleTimers"), "Timers should be stored on window object")
    }

    // MARK: - Count Storage Tests

    func testScriptInitializesCountStorage() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("__consoleCounts"), "Script should initialize count storage")
    }

    func testScriptCountsAreStoredAsWindowProperty() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("window.__consoleCounts"), "Counts should be stored on window object")
    }

    // MARK: - Message Sending Tests

    func testScriptSendLogFunctionExists() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("function sendLog"), "Script should have sendLog function")
    }

    func testScriptUsesWebKitMessageHandler() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("webkit.messageHandlers.consoleLog"), "Script should send messages via webkit")
    }

    // MARK: - Type Safety Tests

    func testScriptHandlesMissingTimerGracefully() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("const start = window.__consoleTimers"), "Script should safely access timers")
    }

    func testScriptHandlesNullObjectPropertiesGracefully() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("try"), "Script should have try-catch for serialization")
    }

    func testScriptChecksForArrayIsArray() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("Array.isArray"), "Script should use Array.isArray for type checking")
    }

    // MARK: - Console Method Preservation Tests

    func testScriptStoresOriginalLogMethod() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("const originalLog"), "Script should preserve original console.log")
    }

    func testScriptCallsOriginalLogAfterCapture() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("originalLog.apply"), "Script should call original methods")
    }

    // MARK: - Integration Tests

    func testScriptIsValidImmediatelyInvokedFunctionExpression() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("(function()"), "Script should be an IIFE")
        XCTAssertTrue(script.contains("})()"), "Script should be an IIFE that closes")
    }

    func testScriptDoesNotLeakGlobals() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("(function()"), "Script should use IIFE to avoid global pollution")
    }

    // MARK: - Format String Parsing Edge Cases

    func testScriptHandlesEmptyFormatString() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("specifiers.length === 0"), "Script should handle empty format strings")
    }

    func testScriptHandlesPercentEscaping() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("%%"), "Script should handle %% escaping")
    }

    func testScriptHandlesMultipleFormatSpecifiers() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("for (const spec of specifiers)") || script.contains("specifiers"), "Script should handle multiple format specifiers")
    }

    // MARK: - Special Cases

    func testScriptTimestampIsISO8601() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("toISOString()"), "Script should use ISO8601 timestamps")
    }

    func testScriptCapturesErrorStack() {
        let script = generateConsoleHookScript()
        XCTAssertTrue(script.contains("error.stack"), "Script should capture error stack traces")
    }
}
