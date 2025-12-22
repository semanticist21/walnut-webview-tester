import XCTest
@testable import wina

final class JavaScriptHookTests: XCTestCase {
    /// 실제 프로덕션 consoleHook 스크립트를 테스트
    private var script: String { WebViewScripts.consoleHook }

    // MARK: - Script Validation Tests

    func testJavaScriptHookScriptIsNotEmpty() {
        XCTAssertFalse(script.isEmpty, "JavaScript hook script should not be empty")
    }

    func testJavaScriptHookScriptContainsConsoleMethodsOverride() {
        // 프로덕션 코드는 methods.forEach로 log, info, warn, error, debug를 한번에 처리
        XCTAssertTrue(script.contains("console[method] = function"), "Script should override console methods")
        XCTAssertTrue(script.contains("'log', 'info', 'warn', 'error', 'debug'"), "Script should include all basic methods")
    }

    func testJavaScriptHookScriptContainsConsoleTimeOverride() {
        XCTAssertTrue(script.contains("console.time = function"), "Script should override console.time")
    }

    func testJavaScriptHookScriptContainsConsoleTimeLogOverride() {
        XCTAssertTrue(script.contains("console.timeLog = function"), "Script should override console.timeLog")
    }

    func testJavaScriptHookScriptContainsConsoleTimeEndOverride() {
        XCTAssertTrue(script.contains("console.timeEnd = function"), "Script should override console.timeEnd")
    }

    func testJavaScriptHookScriptContainsConsoleCountOverride() {
        XCTAssertTrue(script.contains("console.count = function"), "Script should override console.count")
    }

    func testJavaScriptHookScriptContainsConsoleCountResetOverride() {
        XCTAssertTrue(script.contains("console.countReset = function"), "Script should override console.countReset")
    }

    func testJavaScriptHookScriptContainsConsoleDirOverride() {
        XCTAssertTrue(script.contains("console.dir = function"), "Script should override console.dir")
    }

    func testJavaScriptHookScriptContainsConsoleTableOverride() {
        XCTAssertTrue(script.contains("console.table = function"), "Script should override console.table")
    }

    func testJavaScriptHookScriptContainsConsoleGroupOverride() {
        XCTAssertTrue(script.contains("console.group = function"), "Script should override console.group")
        XCTAssertTrue(script.contains("console.groupCollapsed = function"), "Script should override console.groupCollapsed")
        XCTAssertTrue(script.contains("console.groupEnd = function"), "Script should override console.groupEnd")
    }

    // MARK: - Format Specifier Support Tests

    func testScriptContainsFormatMessageFunction() {
        XCTAssertTrue(script.contains("formatConsoleMessage"), "Script should have format message function")
    }

    func testScriptSupportsCFormatSpecifier() {
        XCTAssertTrue(script.contains("%c"), "Script should support %c format specifier")
    }

    func testScriptSupportsSFormatSpecifier() {
        XCTAssertTrue(script.contains("%s"), "Script should support %s format specifier")
    }

    func testScriptSupportsDFormatSpecifier() {
        XCTAssertTrue(script.contains("%d"), "Script should support %d format specifier")
    }

    func testScriptSupportsIFormatSpecifier() {
        XCTAssertTrue(script.contains("%i"), "Script should support %i format specifier")
    }

    func testScriptSupportsOFormatSpecifier() {
        XCTAssertTrue(script.contains("%o"), "Script should support %o format specifier")
    }

    func testScriptSupportsPercentEscaping() {
        XCTAssertTrue(script.contains("%%"), "Script should handle %% escaping")
    }

    // MARK: - CSS Parsing Tests

    func testScriptContainsCSSParser() {
        XCTAssertTrue(script.contains("parseCSS"), "Script should have CSS parsing function")
    }

    func testScriptParsesColorCSS() {
        XCTAssertTrue(script.contains("color"), "Script should parse color CSS property")
    }

    func testScriptParsesBackgroundColorCSS() {
        XCTAssertTrue(script.contains("background-color"), "Script should parse background-color CSS property")
    }

    func testScriptParsesFontWeightCSS() {
        XCTAssertTrue(script.contains("font-weight"), "Script should parse font-weight CSS property")
    }

    func testScriptParsesFontSizeCSS() {
        XCTAssertTrue(script.contains("font-size"), "Script should parse font-size CSS property")
    }

    // MARK: - Value Serialization Tests

    func testScriptContainsSerializeValueFunction() {
        XCTAssertTrue(script.contains("serializeValue"), "Script should have value serialization")
    }

    func testScriptHandlesNullSerialization() {
        XCTAssertTrue(script.contains("type: 'null'"), "Script should handle null serialization")
    }

    func testScriptHandlesUndefinedSerialization() {
        XCTAssertTrue(script.contains("type: 'undefined'"), "Script should handle undefined serialization")
    }

    func testScriptHandlesBooleanSerialization() {
        XCTAssertTrue(script.contains("type: 'boolean'"), "Script should handle boolean serialization")
    }

    func testScriptHandlesNumberSerialization() {
        XCTAssertTrue(script.contains("type: 'number'"), "Script should handle number serialization")
    }

    func testScriptHandlesStringSerialization() {
        XCTAssertTrue(script.contains("type: 'string'"), "Script should handle string serialization")
    }

    func testScriptHandlesFunctionSerialization() {
        XCTAssertTrue(script.contains("type: 'function'"), "Script should handle function serialization")
    }

    func testScriptHandlesDateSerialization() {
        XCTAssertTrue(script.contains("type: 'date'"), "Script should handle date serialization")
    }

    func testScriptHandlesArraySerialization() {
        XCTAssertTrue(script.contains("type: 'array'"), "Script should handle array serialization")
    }

    func testScriptHandlesDOMElementSerialization() {
        XCTAssertTrue(script.contains("type: 'dom'"), "Script should handle DOM element serialization")
    }

    func testScriptHandlesErrorSerialization() {
        XCTAssertTrue(script.contains("type: 'error'"), "Script should handle error serialization")
    }

    func testScriptHandlesObjectSerialization() {
        XCTAssertTrue(script.contains("type: 'object'"), "Script should handle object serialization")
    }

    func testScriptHandlesMapSerialization() {
        XCTAssertTrue(script.contains("type: 'map'"), "Script should handle Map serialization")
    }

    func testScriptHandlesSetSerialization() {
        XCTAssertTrue(script.contains("type: 'set'"), "Script should handle Set serialization")
    }

    func testScriptHandlesRegExpSerialization() {
        XCTAssertTrue(script.contains("type: 'regexp'"), "Script should handle RegExp serialization")
    }

    func testScriptHandlesSymbolSerialization() {
        XCTAssertTrue(script.contains("type: 'symbol'"), "Script should handle Symbol serialization")
    }

    func testScriptHandlesBigIntSerialization() {
        XCTAssertTrue(script.contains("type: 'bigint'"), "Script should handle BigInt serialization")
    }

    // MARK: - Timer Storage Tests

    func testScriptInitializesTimerStorage() {
        XCTAssertTrue(script.contains("const timers = {}"), "Script should initialize timer storage")
    }

    func testScriptTimersTrackStartTime() {
        XCTAssertTrue(script.contains("performance.now()"), "Script should use performance.now() for timing")
    }

    // MARK: - Count Storage Tests

    func testScriptInitializesCountStorage() {
        XCTAssertTrue(script.contains("const counters = {}"), "Script should initialize count storage")
    }

    func testScriptIncrementsCounters() {
        XCTAssertTrue(script.contains("counters[counterLabel]"), "Script should track counter labels")
    }

    // MARK: - Message Sending Tests

    func testScriptSendMessageFunctionExists() {
        XCTAssertTrue(script.contains("function sendMessage"), "Script should have sendMessage function")
    }

    func testScriptUsesWebKitMessageHandler() {
        XCTAssertTrue(script.contains("webkit.messageHandlers.consoleLog"), "Script should send messages via webkit")
    }

    // MARK: - Type Safety Tests

    func testScriptHandlesMissingTimerGracefully() {
        XCTAssertTrue(script.contains("const startTime = timers[timerLabel]"), "Script should safely access timers")
        XCTAssertTrue(script.contains("if (startTime !== undefined)"), "Script should check timer existence")
    }

    func testScriptHandlesNullObjectPropertiesGracefully() {
        XCTAssertTrue(script.contains("try"), "Script should have try-catch for serialization")
    }

    func testScriptChecksForArrayIsArray() {
        XCTAssertTrue(script.contains("Array.isArray"), "Script should use Array.isArray for type checking")
    }

    // MARK: - Console Method Preservation Tests

    func testScriptStoresOriginalMethods() {
        XCTAssertTrue(script.contains("const original = console[method]"), "Script should preserve original methods")
    }

    func testScriptCallsOriginalMethodAfterCapture() {
        XCTAssertTrue(script.contains("original.apply(console, args)"), "Script should call original methods")
    }

    // MARK: - IIFE Tests

    func testScriptIsValidImmediatelyInvokedFunctionExpression() {
        XCTAssertTrue(script.contains("(function()"), "Script should be an IIFE")
        XCTAssertTrue(script.contains("})()"), "Script should be an IIFE that closes")
    }

    func testScriptPreventsDoubleHooking() {
        XCTAssertTrue(script.contains("__consoleHooked"), "Script should prevent double hooking")
    }

    // MARK: - Error Capture Tests

    func testScriptCapturesUncaughtErrors() {
        XCTAssertTrue(script.contains("window.addEventListener('error'"), "Script should capture uncaught errors")
    }

    func testScriptCapturesUnhandledRejections() {
        XCTAssertTrue(script.contains("unhandledrejection"), "Script should capture unhandled promise rejections")
    }

    // MARK: - Source Location Tests

    func testScriptExtractsCallerSource() {
        XCTAssertTrue(script.contains("getCallerSource"), "Script should extract caller source location")
    }

    func testScriptParsesStackTrace() {
        XCTAssertTrue(script.contains("new Error().stack"), "Script should parse stack traces")
    }

    // MARK: - Styled Segments Tests

    func testScriptOutputsStyledSegments() {
        XCTAssertTrue(script.contains("styledSegments"), "Script should output styled segments for %c formatting")
    }

    // MARK: - Circular Reference Tests

    func testScriptHandlesCircularReferences() {
        XCTAssertTrue(script.contains("type: 'circular'"), "Script should handle circular references")
    }

    func testScriptUsesWeakMapForSeen() {
        XCTAssertTrue(script.contains("WeakMap"), "Script should use WeakMap to track seen objects")
    }

    // MARK: - Truncation Tests

    func testScriptTruncatesLargeArrays() {
        XCTAssertTrue(script.contains("maxArrayLength"), "Script should truncate large arrays")
    }

    func testScriptTruncatesDeepObjects() {
        XCTAssertTrue(script.contains("maxDepth"), "Script should truncate deep object nesting")
    }
}
