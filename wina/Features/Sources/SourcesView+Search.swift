//
//  SourcesView+Search.swift
//  wina
//
//  Search functionality for SourcesView.
//

import SwiftUI

// MARK: - Search Methods

extension SourcesView {
    func clearSearch() {
        searchText = ""
        currentMatchIndex = 0
        matchingNodePaths = []
        currentRawMatchIndex = 0
        rawMatchLineIndices = []
    }

    func updateMatchingNodes() {
        guard let root = manager.domTree, !debouncedSearchText.isEmpty else {
            matchingNodePaths = []
            currentMatchIndex = 0
            return
        }

        let query = debouncedSearchText.lowercased()

        // Run search on MainActor (DOMNode properties are MainActor-isolated)
        Task {
            let paths = SourcesSearchHelper.collectMatchingPaths(node: root, currentPath: [], query: query)
            matchingNodePaths = paths
            currentMatchIndex = paths.isEmpty ? 0 : min(currentMatchIndex, paths.count - 1)
        }
    }

    func navigateToPreviousMatch() {
        guard !matchingNodePaths.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchingNodePaths.count) % matchingNodePaths.count
    }

    func navigateToNextMatch() {
        guard !matchingNodePaths.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchingNodePaths.count
    }

    func updateRawHTMLMatches() {
        guard !debouncedSearchText.isEmpty else {
            rawMatchLineIndices = []
            currentRawMatchIndex = 0
            return
        }

        let query = debouncedSearchText
        let lines = cachedRawHTMLLines

        // Run search (simple string operations, no actor isolation needed)
        Task {
            let indices = SourcesSearchHelper.findMatchingLineIndices(lines: lines, query: query)
            rawMatchLineIndices = indices
            currentRawMatchIndex = indices.isEmpty ? 0 : min(currentRawMatchIndex, indices.count - 1)
        }
    }

    func navigateToPreviousRawMatch() {
        guard !rawMatchLineIndices.isEmpty else { return }
        currentRawMatchIndex = (currentRawMatchIndex - 1 + rawMatchLineIndices.count) % rawMatchLineIndices.count
    }

    func navigateToNextRawMatch() {
        guard !rawMatchLineIndices.isEmpty else { return }
        currentRawMatchIndex = (currentRawMatchIndex + 1) % rawMatchLineIndices.count
    }

    var currentMatchPath: [String]? {
        guard !matchingNodePaths.isEmpty, currentMatchIndex < matchingNodePaths.count else { return nil }
        return matchingNodePaths[currentMatchIndex]
    }

    func scrollToCurrentMatch(proxy: ScrollViewProxy) {
        guard let path = currentMatchPath, let targetId = path.last else { return }
        // Delay scroll to allow parent nodes to expand first
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        }
    }

    func updateBreadcrumbs(for node: DOMNode, root: DOMNode) {
        // Build path from root to node using path indices
        var path: [DOMNode] = []
        var current: DOMNode? = root

        // The node's path tells us how to navigate from root
        // path[0] is root's index (0), path[1] is first child index, etc.
        for index in node.path.dropFirst() {
            guard let curr = current else { break }
            path.append(curr)
            if index < curr.children.count {
                current = curr.children[index]
            } else {
                break
            }
        }

        // Add the final node
        path.append(node)

        withAnimation(.easeOut(duration: 0.15)) {
            breadcrumbPath = path
        }
    }
}
