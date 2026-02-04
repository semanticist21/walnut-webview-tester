//
//  SourcesRowViews.swift
//  wina
//
//  Row views for Sources panel lists.
//

import SwiftUI

// MARK: - DOM Node Row

struct DOMNodeRow: View {
    let node: DOMNode
    let depth: Int
    let manager: SourcesManager
    let searchText: String
    let currentMatchPath: [String]?
    let onSelect: (DOMNode) -> Void
    var onBreadcrumbTap: ((DOMNode) -> Void)?

    // HTML, BODY are expanded by default
    @State private var isExpanded: Bool = false

    private var hasChildren: Bool {
        !node.children.isEmpty
    }

    private var shouldExpandByDefault: Bool {
        let name = node.nodeName.uppercased()
        return name == "HTML" || name == "BODY"
    }

    /// Check if this node matches the search text (uses shared logic)
    private var matchesSearch: Bool {
        guard !searchText.isEmpty else { return false }
        return SourcesSearchHelper.nodeMatches(node, query: searchText)
    }

    /// Check if this is the currently focused match
    private var isCurrentMatch: Bool {
        guard let path = currentMatchPath else { return false }
        return path.last == node.id
    }

    /// Check if this node is in the path to the current match (for auto-expand)
    private var isInCurrentMatchPath: Bool {
        guard let path = currentMatchPath else { return false }
        return path.contains(node.id)
    }

    /// Check if any descendant matches the search
    private var hasMatchingDescendant: Bool {
        guard !searchText.isEmpty else { return false }
        return node.children.contains { child in
            nodeOrDescendantMatches(child)
        }
    }

    private func nodeOrDescendantMatches(_ node: DOMNode) -> Bool {
        if SourcesSearchHelper.nodeMatches(node, query: searchText) { return true }
        return node.children.contains { nodeOrDescendantMatches($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node itself
            HStack(spacing: 4) {
                // Expand/collapse button
                if hasChildren {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }

                // Node content
                if node.isText {
                    Text("\"\(node.textContent ?? "")\"")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    nodeLabel
                }

                Spacer()

                // Info button for element nodes
                if node.isElement {
                    Button {
                        onSelect(node)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.vertical, 4)
            .background {
                if isCurrentMatch {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.3))
                } else if matchesSearch {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                }
            }
            .id("row-\(node.id)")
            .contentShape(Rectangle())
            .onTapGesture {
                // Update breadcrumbs when element is tapped
                onBreadcrumbTap?(node)

                if hasChildren {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Children
            if isExpanded {
                ForEach(node.children) { child in
                    DOMNodeRow(
                        node: child,
                        depth: depth + 1,
                        manager: manager,
                        searchText: searchText,
                        currentMatchPath: currentMatchPath,
                        onSelect: onSelect,
                        onBreadcrumbTap: onBreadcrumbTap
                    )
                }
            }
        }
        .onAppear {
            // Expand HTML, BODY by default
            if shouldExpandByDefault {
                isExpanded = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Auto-expand if descendants match
            if !newValue.isEmpty && hasMatchingDescendant {
                isExpanded = true
            }
        }
        .onChange(of: currentMatchPath) { _, _ in
            // Auto-expand if this node is in the path to the current match
            if isInCurrentMatchPath && !isExpanded {
                withAnimation(.easeOut(duration: 0.15)) {
                    isExpanded = true
                }
            }
        }
    }

    private var nodeLabel: some View {
        HStack(spacing: 2) {
            Text("<")
                .foregroundStyle(.tertiary)
            Text(node.nodeName.lowercased())
                .foregroundStyle(.primary)

            // Show id and class
            if let id = node.attributes["id"] {
                Text(" id")
                    .foregroundStyle(.secondary)
                Text("=\"\(id)\"")
                    .foregroundStyle(.secondary)
            }
            if let className = node.attributes["class"], !className.isEmpty {
                Text(" class")
                    .foregroundStyle(.tertiary)
                Text("=\"\(className.prefix(30))\(className.count > 30 ? "..." : "")\"")
                    .foregroundStyle(.tertiary)
            }

            Text(hasChildren ? ">" : "/>")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, design: .monospaced))
        .lineLimit(1)
    }
}

// MARK: - Stylesheet Row

struct StylesheetRow: View {
    let sheet: StylesheetInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: sheet.isExternal ? "link" : "doc.text")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack {
                    if let href = sheet.href {
                        Text(URL(string: href)?.lastPathComponent ?? href)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    } else {
                        Text("<style> tag")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(sheet.rulesCount) rules")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }

                // URL (if external)
                if let href = sheet.href {
                    Text(href)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // Media query
                if let media = sheet.mediaText, !media.isEmpty {
                    Text("@media \(media)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Script Row

struct ScriptRow: View {
    let script: ScriptInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon with lock overlay for external scripts
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: script.isExternal ? "link" : "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)

                if script.isExternal {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .offset(x: 2, y: 2)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack {
                    if let src = script.src {
                        Text(URL(string: src)?.lastPathComponent ?? src)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    } else {
                        Text("<inline script>")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Badges
                    HStack(spacing: 4) {
                        if script.isModule {
                            badge("module")
                        }
                        if script.isAsync {
                            badge("async")
                        }
                        if script.isDefer {
                            badge("defer")
                        }
                    }
                }

                // URL (if external)
                if let src = script.src {
                    Text(src)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // CORS notice for external scripts
                if script.isExternal {
                    Text("External (view-only metadata)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.1), in: Capsule())
    }
}
