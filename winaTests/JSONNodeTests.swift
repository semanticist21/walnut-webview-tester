//
//  JSONNodeTests.swift
//  winaTests
//

import XCTest
@testable import wina

final class JSONNodeTests: XCTestCase {

    func testStableIdsAreDeterministic() throws {
        let jsonString = """
        {
            "name": "example",
            "items": [1, 2],
            "meta": { "enabled": true }
        }
        """
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let first = JSONNode.parse(json)
        let second = JSONNode.parse(json)

        XCTAssertEqual(collectIDs(from: first), collectIDs(from: second))
    }

    func testIdsContainPathComponents() throws {
        let jsonString = """
        { "items": [ { "name": "one" } ] }
        """
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let root = JSONNode.parse(json)
        let ids = collectIDs(from: root)

        XCTAssertTrue(ids.contains("root.items.[0].name"))
    }

    private func collectIDs(from node: JSONNode) -> [String] {
        var result = [node.id]
        switch node {
        case .array(_, let values, _):
            values.forEach { result.append(contentsOf: collectIDs(from: $0)) }
        case .object(_, let pairs, _):
            pairs.forEach { result.append(contentsOf: collectIDs(from: $0.1)) }
        default:
            break
        }
        return result
    }
}
