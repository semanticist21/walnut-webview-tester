//
//  SourcesManagerTests.swift
//  winaTests
//
//  Tests for SourcesManager DOM tree, stylesheets, and scripts parsing.
//

import XCTest
@testable import wina

// MARK: - DOMNode Model Tests

final class DOMNodeTests: XCTestCase {

    func testPathBasedStableID() {
        let node = DOMNode(
            path: [0, 1, 3],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        XCTAssertEqual(node.id, "0.1.3")
    }

    func testRootNodeID() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "HTML",
            attributes: [:],
            textContent: nil,
            children: []
        )

        XCTAssertEqual(node.id, "0")
    }

    func testIsElementForNodeType1() {
        let elementNode = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        XCTAssertTrue(elementNode.isElement)
        XCTAssertFalse(elementNode.isText)
    }

    func testIsTextForNodeType3() {
        let textNode = DOMNode(
            path: [0, 0],
            nodeType: 3,
            nodeName: "#text",
            attributes: [:],
            textContent: "Hello World",
            children: []
        )

        XCTAssertTrue(textNode.isText)
        XCTAssertFalse(textNode.isElement)
    }

    func testDisplayNameForElement() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        XCTAssertEqual(node.displayName, "div")
    }

    func testDisplayNameWithId() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "main"],
            textContent: nil,
            children: []
        )

        XCTAssertEqual(node.displayName, "div#main")
    }

    func testDisplayNameWithClass() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["class": "container flex"],
            textContent: nil,
            children: []
        )

        XCTAssertEqual(node.displayName, "div.container.flex")
    }

    func testDisplayNameWithIdAndClass() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "app", "class": "root main wrapper"],
            textContent: nil,
            children: []
        )

        // Only first 2 classes are shown
        XCTAssertEqual(node.displayName, "div#app.root.main")
    }

    func testDisplayNameForTextNode() {
        let node = DOMNode(
            path: [0, 0],
            nodeType: 3,
            nodeName: "#text",
            attributes: [:],
            textContent: "Hello World",
            children: []
        )

        XCTAssertEqual(node.displayName, "Hello World")
    }

    func testDefaultExpandedState() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        XCTAssertFalse(node.isExpanded)
    }

    func testHashable() {
        let node1 = DOMNode(
            path: [0, 1],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        // Identical node
        let node2 = DOMNode(
            path: [0, 1],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        // Different node (different nodeName)
        let node3 = DOMNode(
            path: [0, 1],
            nodeType: 1,
            nodeName: "SPAN",
            attributes: [:],
            textContent: nil,
            children: []
        )

        var set = Set<DOMNode>()
        set.insert(node1)
        set.insert(node2)

        // Identical nodes have same hash
        XCTAssertEqual(set.count, 1)

        // Different nodes have different hash (synthesized Hashable uses all properties)
        set.insert(node3)
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - StylesheetInfo Model Tests

final class StylesheetInfoTests: XCTestCase {

    func testExternalStylesheet() {
        let stylesheet = StylesheetInfo(
            index: 0,
            href: "https://example.com/styles.css",
            rulesCount: 42,
            isExternal: true,
            mediaText: "screen",
            cssContent: nil
        )

        XCTAssertTrue(stylesheet.isExternal)
        XCTAssertEqual(stylesheet.href, "https://example.com/styles.css")
        XCTAssertEqual(stylesheet.rulesCount, 42)
        XCTAssertEqual(stylesheet.mediaText, "screen")
        XCTAssertNil(stylesheet.cssContent)
    }

    func testInlineStylesheet() {
        let css = "body { margin: 0; }"
        let stylesheet = StylesheetInfo(
            index: 1,
            href: nil,
            rulesCount: 1,
            isExternal: false,
            mediaText: nil,
            cssContent: css
        )

        XCTAssertFalse(stylesheet.isExternal)
        XCTAssertNil(stylesheet.href)
        XCTAssertEqual(stylesheet.cssContent, css)
    }

    func testUniqueIDs() {
        let stylesheet1 = StylesheetInfo(
            index: 0,
            href: nil,
            rulesCount: 0,
            isExternal: false,
            mediaText: nil,
            cssContent: nil
        )

        let stylesheet2 = StylesheetInfo(
            index: 1,
            href: nil,
            rulesCount: 0,
            isExternal: false,
            mediaText: nil,
            cssContent: nil
        )

        XCTAssertNotEqual(stylesheet1.id, stylesheet2.id)
    }
}

// MARK: - ScriptInfo Model Tests

final class ScriptInfoTests: XCTestCase {

    func testExternalScript() {
        let script = ScriptInfo(
            index: 0,
            src: "https://example.com/app.js",
            isExternal: true,
            isModule: false,
            isAsync: true,
            isDefer: false,
            content: nil
        )

        XCTAssertTrue(script.isExternal)
        XCTAssertEqual(script.src, "https://example.com/app.js")
        XCTAssertTrue(script.isAsync)
        XCTAssertFalse(script.isDefer)
        XCTAssertNil(script.content)
    }

    func testInlineScript() {
        let code = "console.log('hello');"
        let script = ScriptInfo(
            index: 1,
            src: nil,
            isExternal: false,
            isModule: false,
            isAsync: false,
            isDefer: false,
            content: code
        )

        XCTAssertFalse(script.isExternal)
        XCTAssertNil(script.src)
        XCTAssertEqual(script.content, code)
    }

    func testModuleScript() {
        let script = ScriptInfo(
            index: 0,
            src: "https://example.com/module.js",
            isExternal: true,
            isModule: true,
            isAsync: false,
            isDefer: false,
            content: nil
        )

        XCTAssertTrue(script.isModule)
    }

    func testDeferScript() {
        let script = ScriptInfo(
            index: 0,
            src: "https://example.com/deferred.js",
            isExternal: true,
            isModule: false,
            isAsync: false,
            isDefer: true,
            content: nil
        )

        XCTAssertTrue(script.isDefer)
        XCTAssertFalse(script.isAsync)
    }

    func testUniqueIDs() {
        let script1 = ScriptInfo(
            index: 0,
            src: nil,
            isExternal: false,
            isModule: false,
            isAsync: false,
            isDefer: false,
            content: nil
        )

        let script2 = ScriptInfo(
            index: 1,
            src: nil,
            isExternal: false,
            isModule: false,
            isAsync: false,
            isDefer: false,
            content: nil
        )

        XCTAssertNotEqual(script1.id, script2.id)
    }
}

// MARK: - SourcesManager Tests

@MainActor
final class SourcesManagerTests: XCTestCase {

    var manager: SourcesManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = SourcesManager()
    }

    override func tearDown() async throws {
        manager?.clear()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialDOMTreeIsNil() {
        XCTAssertNil(manager.domTree)
    }

    func testInitialRawHTMLIsNil() {
        XCTAssertNil(manager.rawHTML)
    }

    func testInitialStylesheetsIsEmpty() {
        XCTAssertTrue(manager.stylesheets.isEmpty)
    }

    func testInitialScriptsIsEmpty() {
        XCTAssertTrue(manager.scripts.isEmpty)
    }

    func testInitialLoadingIsFalse() {
        XCTAssertFalse(manager.isLoading)
    }

    func testInitialErrorMessageIsNil() {
        XCTAssertNil(manager.errorMessage)
    }

    // MARK: - Navigator Not Set Tests

    func testFetchDOMTreeWithoutNavigatorSetsError() async {
        await manager.fetchDOMTree()

        XCTAssertEqual(manager.errorMessage, "Navigator not available")
        XCTAssertNil(manager.domTree)
    }

    func testFetchRawHTMLWithoutNavigatorSetsError() async {
        await manager.fetchRawHTML()

        XCTAssertEqual(manager.errorMessage, "Navigator not available")
        XCTAssertNil(manager.rawHTML)
    }

    func testFetchStylesheetsWithoutNavigatorSetsError() async {
        await manager.fetchStylesheets()

        XCTAssertEqual(manager.errorMessage, "Navigator not available")
        XCTAssertTrue(manager.stylesheets.isEmpty)
    }

    func testFetchScriptsWithoutNavigatorSetsError() async {
        await manager.fetchScripts()

        XCTAssertEqual(manager.errorMessage, "Navigator not available")
        XCTAssertTrue(manager.scripts.isEmpty)
    }

    // MARK: - Clear Tests

    func testClearResetsAllState() {
        // Set some state manually for testing
        manager.stylesheets = [
            StylesheetInfo(
                index: 0,
                href: nil,
                rulesCount: 0,
                isExternal: false,
                mediaText: nil,
                cssContent: nil
            )
        ]
        manager.scripts = [
            ScriptInfo(
                index: 0,
                src: nil,
                isExternal: false,
                isModule: false,
                isAsync: false,
                isDefer: false,
                content: nil
            )
        ]
        manager.errorMessage = "Some error"

        manager.clear()

        XCTAssertNil(manager.domTree)
        XCTAssertNil(manager.rawHTML)
        XCTAssertTrue(manager.stylesheets.isEmpty)
        XCTAssertTrue(manager.scripts.isEmpty)
        XCTAssertNil(manager.errorMessage)
    }

    // MARK: - Static Script Property Tests

    func testDOMTreeScriptExists() {
        let script = SourcesManager.domTreeScript
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("serializeNode"))
        XCTAssertTrue(script.contains("document.documentElement"))
    }

    func testRawHTMLScriptExists() {
        let script = SourcesManager.rawHTMLScript
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("doctype"))
        XCTAssertTrue(script.contains("outerHTML"))
    }

    func testStylesheetsScriptExists() {
        let script = SourcesManager.stylesheetsScript
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("styleSheets"))
        XCTAssertTrue(script.contains("cssRules"))
    }

    func testScriptsScriptExists() {
        let script = SourcesManager.scriptsScript
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("document.scripts"))
        XCTAssertTrue(script.contains("textContent"))
    }
}
