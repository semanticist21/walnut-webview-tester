//
//  SourcesSearchLogic.swift
//  wina
//
//  Search logic for Sources panel.
//

import Foundation

// MARK: - DOM Tree Search

enum SourcesSearchHelper {
    /// Check if a node matches the search query (shared logic for counting and highlighting)
    static func nodeMatches(_ node: DOMNode, query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        // Match tag name
        if node.nodeName.lowercased().contains(lowercasedQuery) { return true }
        // Match id attribute
        if let id = node.attributes["id"], id.lowercased().contains(lowercasedQuery) { return true }
        // Match class attribute
        if let cls = node.attributes["class"], cls.lowercased().contains(lowercasedQuery) { return true }
        // Match text content
        if let text = node.textContent, text.lowercased().contains(lowercasedQuery) { return true }
        return false
    }

    /// Collect paths to all matching nodes in the DOM tree
    @MainActor
    static func collectMatchingPaths(node: DOMNode, currentPath: [String], query: String) -> [[String]] {
        let nodePath = currentPath + [node.id]
        var paths: [[String]] = []

        if nodeMatches(node, query: query) {
            paths.append(nodePath)
        }

        for child in node.children {
            paths.append(contentsOf: collectMatchingPaths(node: child, currentPath: nodePath, query: query))
        }

        return paths
    }

    /// Find line indices containing the search query
    static func findMatchingLineIndices(lines: [String], query: String) -> [Int] {
        var indices: [Int] = []
        let lowercasedQuery = query.lowercased()
        for (index, line) in lines.enumerated() where line.lowercased().contains(lowercasedQuery) {
            indices.append(index)
        }
        return indices
    }
}

// MARK: - DOM Tree Serialization

enum DOMTreeSerializer {
    /// Serialize DOM tree to string representation
    static func serialize(_ node: DOMNode, depth: Int = 0) -> String {
        let indent = String(repeating: "  ", count: depth)
        var result = ""

        if node.isText {
            if let text = node.textContent {
                result = "\(indent)\(text)\n"
            }
        } else {
            var tag = "<\(node.nodeName.lowercased())"
            for (key, value) in node.attributes {
                tag += " \(key)=\"\(value)\""
            }
            tag += ">"
            result = "\(indent)\(tag)\n"

            for child in node.children {
                result += serialize(child, depth: depth + 1)
            }

            result += "\(indent)</\(node.nodeName.lowercased())>\n"
        }

        return result
    }
}
