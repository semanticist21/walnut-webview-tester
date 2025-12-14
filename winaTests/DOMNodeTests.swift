//
//  DOMNodeTests.swift
//  winaTests
//
//  Tests for DOMNode path-based stable IDs.
//  Ensures expand/collapse state is preserved across re-parses.
//

import Testing
@testable import wina

// MARK: - DOMNode ID Stability Tests

@Suite("DOMNode ID Stability")
struct DOMNodeIdStabilityTests {

    // MARK: - Path-Based ID Generation

    @Test("ID is derived from path")
    func testIdDerivedFromPath() {
        let node = DOMNode(
            path: [0, 1, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        #expect(node.id == "0.1.2")
    }

    @Test("Root node has simple ID")
    func testRootNodeId() {
        let root = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "HTML",
            attributes: [:],
            textContent: nil,
            children: []
        )

        #expect(root.id == "0")
    }

    @Test("Same path produces same ID")
    func testSamePathSameId() {
        let node1 = DOMNode(
            path: [0, 1, 3],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "first"],
            textContent: nil,
            children: []
        )
        let node2 = DOMNode(
            path: [0, 1, 3],
            nodeType: 1,
            nodeName: "SPAN",
            attributes: ["id": "second"],
            textContent: nil,
            children: []
        )

        #expect(node1.id == node2.id, "Same path should produce same ID regardless of content")
    }

    @Test("Different paths produce different IDs")
    func testDifferentPathsDifferentIds() {
        let node1 = DOMNode(
            path: [0, 1],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )
        let node2 = DOMNode(
            path: [0, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        #expect(node1.id != node2.id)
    }

    // MARK: - ID Stability Across Re-Parses

    @Test("ID remains stable when DOM is re-parsed")
    func testIdStableAcrossReparses() {
        // Simulate first parse
        let firstParse = DOMNode(
            path: [0, 1, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["class": "container"],
            textContent: nil,
            children: []
        )

        // Simulate second parse (same structure, different instance)
        let secondParse = DOMNode(
            path: [0, 1, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["class": "container updated"],
            textContent: nil,
            children: []
        )

        #expect(firstParse.id == secondParse.id, "ID should remain stable across re-parses for SwiftUI state preservation")
    }
}

// MARK: - DOMNode Display Name Tests

@Suite("DOMNode Display Name")
struct DOMNodeDisplayNameTests {

    @Test("Element display name shows tag")
    func testElementDisplayName() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        #expect(node.displayName == "div")
    }

    @Test("Element with ID shows id")
    func testElementWithId() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "main"],
            textContent: nil,
            children: []
        )

        #expect(node.displayName == "div#main")
    }

    @Test("Element with class shows classes")
    func testElementWithClass() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["class": "container flex"],
            textContent: nil,
            children: []
        )

        #expect(node.displayName == "div.container.flex")
    }

    @Test("Element with ID and class shows both")
    func testElementWithIdAndClass() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["id": "main", "class": "container"],
            textContent: nil,
            children: []
        )

        #expect(node.displayName == "div#main.container")
    }

    @Test("Text node shows content")
    func testTextNodeDisplayName() {
        let node = DOMNode(
            path: [0, 1],
            nodeType: 3,
            nodeName: "#text",
            attributes: [:],
            textContent: "Hello World",
            children: []
        )

        #expect(node.displayName == "Hello World")
    }

    @Test("Only first two classes shown")
    func testClassLimit() {
        let node = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: ["class": "one two three four"],
            textContent: nil,
            children: []
        )

        #expect(node.displayName == "div.one.two")
    }
}

// MARK: - DOMNode Type Checks

@Suite("DOMNode Type Checks")
struct DOMNodeTypeTests {

    @Test("Element node type is 1")
    func testElementNodeType() {
        let element = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        #expect(element.isElement == true)
        #expect(element.isText == false)
    }

    @Test("Text node type is 3")
    func testTextNodeType() {
        let text = DOMNode(
            path: [0, 1],
            nodeType: 3,
            nodeName: "#text",
            attributes: [:],
            textContent: "content",
            children: []
        )

        #expect(text.isElement == false)
        #expect(text.isText == true)
    }
}

// MARK: - DOMNode Hashable Tests

@Suite("DOMNode Hashable")
struct DOMNodeHashableTests {

    @Test("Same node instance hashes consistently")
    func testSameNodeHashesConsistently() {
        let node = DOMNode(
            path: [0, 1, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        // Same instance should always produce same hash
        #expect(node.hashValue == node.hashValue)
    }

    @Test("Identical nodes hash equally")
    func testIdenticalNodesHashEqually() {
        let node1 = DOMNode(
            path: [0, 1, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )
        let node2 = DOMNode(
            path: [0, 1, 2],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )

        #expect(node1.hashValue == node2.hashValue)
    }

    @Test("Can be used in Set")
    func testSetUsage() {
        let node1 = DOMNode(
            path: [0],
            nodeType: 1,
            nodeName: "DIV",
            attributes: [:],
            textContent: nil,
            children: []
        )
        let node2 = DOMNode(
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

        #expect(set.count == 2)
    }
}
