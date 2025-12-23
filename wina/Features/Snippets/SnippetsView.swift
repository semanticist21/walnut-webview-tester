//
//  SnippetsView.swift
//  wina
//
//  Pre-built debugging utilities for quick page inspection.
//  Based on Eruda's Snippets feature.
//

import SwiftUI

// MARK: - Snippet Definition

struct DebugSnippet: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let iconColor: Color
    let isToggleable: Bool
    let script: String
    let undoScript: String?

    init(
        id: String,
        name: String,
        description: String,
        icon: String,
        iconColor: Color = .blue,
        isToggleable: Bool = false,
        script: String,
        undoScript: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.isToggleable = isToggleable
        self.script = script
        self.undoScript = undoScript
    }
}

// MARK: - Snippets Manager

@Observable
class SnippetsManager {
    var activeSnippets: Set<String> = []

    static let defaultSnippets: [DebugSnippet] = [
        DebugSnippet(
            id: "border_all",
            name: "Border All",
            description: "Add colored borders to all elements for layout debugging",
            icon: "square.dashed",
            iconColor: .orange,
            isToggleable: true,
            script: """
                (function() {
                    const id = '__wina_border_style__';
                    if (document.getElementById(id)) return;
                    const style = document.createElement('style');
                    style.id = id;
                    style.textContent = `
                        * { outline: 1px solid rgba(255,0,0,0.3) !important; }
                        *:nth-child(2n) { outline-color: rgba(0,255,0,0.3) !important; }
                        *:nth-child(3n) { outline-color: rgba(0,0,255,0.3) !important; }
                        *:nth-child(4n) { outline-color: rgba(255,255,0,0.3) !important; }
                        *:nth-child(5n) { outline-color: rgba(255,0,255,0.3) !important; }
                    `;
                    document.head.appendChild(style);
                    return 'Borders enabled';
                })();
                """,
            undoScript: """
                (function() {
                    const el = document.getElementById('__wina_border_style__');
                    if (el) el.remove();
                    return 'Borders disabled';
                })();
                """
        ),
        DebugSnippet(
            id: "edit_page",
            name: "Edit Page",
            description: "Make page content editable (contentEditable)",
            icon: "pencil.line",
            iconColor: .green,
            isToggleable: true,
            script: """
                (function() {
                    document.body.contentEditable = 'true';
                    document.designMode = 'on';
                    return 'Page is now editable';
                })();
                """,
            undoScript: """
                (function() {
                    document.body.contentEditable = 'false';
                    document.designMode = 'off';
                    return 'Page editing disabled';
                })();
                """
        ),
        DebugSnippet(
            id: "show_elements",
            name: "Show Hidden",
            description: "Show all hidden elements (display:none, visibility:hidden)",
            icon: "eye",
            iconColor: .purple,
            isToggleable: true,
            script: """
                (function() {
                    const id = '__wina_show_hidden_style__';
                    if (document.getElementById(id)) return;
                    const style = document.createElement('style');
                    style.id = id;
                    style.textContent = `
                        [style*="display: none"], [style*="display:none"],
                        [hidden], .hidden,
                        [style*="visibility: hidden"], [style*="visibility:hidden"] {
                            display: block !important;
                            visibility: visible !important;
                            opacity: 0.5 !important;
                            outline: 2px dashed red !important;
                        }
                    `;
                    document.head.appendChild(style);
                    return 'Hidden elements revealed';
                })();
                """,
            undoScript: """
                (function() {
                    const el = document.getElementById('__wina_show_hidden_style__');
                    if (el) el.remove();
                    return 'Hidden elements restored';
                })();
                """
        ),
        DebugSnippet(
            id: "disable_css",
            name: "Disable CSS",
            description: "Remove all stylesheets to see raw HTML structure",
            icon: "paintbrush.slash",
            iconColor: .red,
            isToggleable: true,
            script: """
                (function() {
                    window.__wina_disabled_styles__ = [];
                    document.querySelectorAll('link[rel="stylesheet"], style').forEach(el => {
                        window.__wina_disabled_styles__.push({el, parent: el.parentNode, next: el.nextSibling});
                        el.remove();
                    });
                    return 'CSS disabled (' + window.__wina_disabled_styles__.length + ' stylesheets removed)';
                })();
                """,
            undoScript: """
                (function() {
                    if (!window.__wina_disabled_styles__) return 'No styles to restore';
                    window.__wina_disabled_styles__.forEach(({el, parent, next}) => {
                        if (next) parent.insertBefore(el, next);
                        else parent.appendChild(el);
                    });
                    const count = window.__wina_disabled_styles__.length;
                    window.__wina_disabled_styles__ = null;
                    return 'CSS restored (' + count + ' stylesheets)';
                })();
                """
        ),
        DebugSnippet(
            id: "log_dom_stats",
            name: "DOM Stats",
            description: "Log DOM statistics (element count, depth, etc.)",
            icon: "chart.bar.doc.horizontal",
            iconColor: .cyan,
            script: """
                (function() {
                    const all = document.querySelectorAll('*');
                    const tags = {};
                    let maxDepth = 0;
                    function getDepth(el) {
                        let d = 0, node = el;
                        while (node.parentElement) { d++; node = node.parentElement; }
                        return d;
                    }
                    all.forEach(el => {
                        const tag = el.tagName.toLowerCase();
                        tags[tag] = (tags[tag] || 0) + 1;
                        maxDepth = Math.max(maxDepth, getDepth(el));
                    });
                    const sorted = Object.entries(tags).sort((a,b) => b[1] - a[1]).slice(0, 10);
                    console.group('DOM Statistics');
                    console.log('Total elements:', all.length);
                    console.log('Max depth:', maxDepth);
                    console.log('Unique tags:', Object.keys(tags).length);
                    console.table(Object.fromEntries(sorted.map(([k,v]) => [k, v])));
                    console.groupEnd();
                    return 'DOM stats logged to console';
                })();
                """
        ),
        DebugSnippet(
            id: "log_images",
            name: "Log Images",
            description: "Log all images with dimensions and sources",
            icon: "photo.on.rectangle",
            iconColor: .indigo,
            script: """
                (function() {
                    const imgs = document.querySelectorAll('img');
                    const data = Array.from(imgs).map((img, i) => ({
                        '#': i + 1,
                        'Natural': img.naturalWidth + 'x' + img.naturalHeight,
                        'Display': img.width + 'x' + img.height,
                        'Src': img.src.substring(0, 60) + (img.src.length > 60 ? '...' : ''),
                        'Alt': (img.alt || '-').substring(0, 30)
                    }));
                    console.group('Images (' + imgs.length + ')');
                    console.table(data);
                    console.groupEnd();
                    return imgs.length + ' images logged to console';
                })();
                """
        ),
        DebugSnippet(
            id: "log_links",
            name: "Log Links",
            description: "Log all links and their targets",
            icon: "link",
            iconColor: .blue,
            script: """
                (function() {
                    const links = document.querySelectorAll('a[href]');
                    const internal = [], external = [];
                    const host = location.hostname;
                    links.forEach(a => {
                        try {
                            const url = new URL(a.href);
                            const item = {text: (a.innerText || a.href).substring(0, 40), href: a.href};
                            if (url.hostname === host) internal.push(item);
                            else external.push(item);
                        } catch(e) {}
                    });
                    console.group('Links (' + links.length + ' total)');
                    console.log('Internal links:', internal.length);
                    console.table(internal.slice(0, 20));
                    console.log('External links:', external.length);
                    console.table(external.slice(0, 20));
                    console.groupEnd();
                    return links.length + ' links logged to console';
                })();
                """
        ),
        DebugSnippet(
            id: "log_event_listeners",
            name: "Event Listeners",
            description: "Log elements with event listeners (requires getEventListeners)",
            icon: "hand.tap",
            iconColor: .mint,
            script: """
                (function() {
                    // This is a simplified version - full getEventListeners is Chrome-only
                    const clickable = document.querySelectorAll('[onclick], button, a, input, [role="button"]');
                    console.group('Interactive Elements (' + clickable.length + ')');
                    clickable.forEach((el, i) => {
                        if (i < 30) {
                            console.log(i + 1, el.tagName, el.className || el.id || '(no class/id)', el);
                        }
                    });
                    if (clickable.length > 30) console.log('... and', clickable.length - 30, 'more');
                    console.groupEnd();
                    return clickable.length + ' interactive elements found';
                })();
                """
        ),
        DebugSnippet(
            id: "highlight_headings",
            name: "Highlight Headings",
            description: "Highlight all heading elements (h1-h6)",
            icon: "textformat.size",
            iconColor: .yellow,
            isToggleable: true,
            script: """
                (function() {
                    const id = '__wina_heading_style__';
                    if (document.getElementById(id)) return;
                    const style = document.createElement('style');
                    style.id = id;
                    style.textContent = `
                        h1 { outline: 3px solid #FF5733 !important; background: rgba(255,87,51,0.1) !important; }
                        h2 { outline: 3px solid #33FF57 !important; background: rgba(51,255,87,0.1) !important; }
                        h3 { outline: 3px solid #3357FF !important; background: rgba(51,87,255,0.1) !important; }
                        h4 { outline: 3px solid #FF33F5 !important; background: rgba(255,51,245,0.1) !important; }
                        h5 { outline: 3px solid #33FFF5 !important; background: rgba(51,255,245,0.1) !important; }
                        h6 { outline: 3px solid #F5FF33 !important; background: rgba(245,255,51,0.1) !important; }
                        h1::before { content: 'H1 ' !important; color: #FF5733; font-size: 10px; }
                        h2::before { content: 'H2 ' !important; color: #33FF57; font-size: 10px; }
                        h3::before { content: 'H3 ' !important; color: #3357FF; font-size: 10px; }
                        h4::before { content: 'H4 ' !important; color: #FF33F5; font-size: 10px; }
                        h5::before { content: 'H5 ' !important; color: #33FFF5; font-size: 10px; }
                        h6::before { content: 'H6 ' !important; color: #F5FF33; font-size: 10px; }
                    `;
                    document.head.appendChild(style);
                    const counts = {h1:0,h2:0,h3:0,h4:0,h5:0,h6:0};
                    'h1,h2,h3,h4,h5,h6'.split(',').forEach(t => counts[t] = document.querySelectorAll(t).length);
                    console.log('Headings:', counts);
                    return 'Headings highlighted';
                })();
                """,
            undoScript: """
                (function() {
                    const el = document.getElementById('__wina_heading_style__');
                    if (el) el.remove();
                    return 'Heading highlights removed';
                })();
                """
        ),
        DebugSnippet(
            id: "clear_storage",
            name: "Clear Storage",
            description: "Clear localStorage and sessionStorage",
            icon: "trash",
            iconColor: .red,
            script: """
                (function() {
                    const lsCount = localStorage.length;
                    const ssCount = sessionStorage.length;
                    localStorage.clear();
                    sessionStorage.clear();
                    return 'Cleared ' + lsCount + ' localStorage + ' + ssCount + ' sessionStorage items';
                })();
                """
        )
    ]

    func isActive(_ snippetId: String) -> Bool {
        activeSnippets.contains(snippetId)
    }

    func toggle(_ snippetId: String) {
        if activeSnippets.contains(snippetId) {
            activeSnippets.remove(snippetId)
        } else {
            activeSnippets.insert(snippetId)
        }
    }

    func deactivate(_ snippetId: String) {
        activeSnippets.remove(snippetId)
    }
}

// MARK: - Snippets Settings View (Navigation Destination)

struct SnippetsSettingsView: View {
    let navigator: WebViewNavigator
    @State private var executionResult: String?
    @State private var showResult: Bool = false

    private var snippetsManager: SnippetsManager {
        navigator.snippetsManager
    }

    var body: some View {
        List {
            Section {
                ForEach(SnippetsManager.defaultSnippets) { snippet in
                    SnippetSettingsRow(
                        snippet: snippet,
                        isActive: snippetsManager.isActive(snippet.id),
                        onTap: {
                            executeSnippet(snippet)
                        }
                    )
                }
            } header: {
                Text("Tap to run. Toggle snippets stay active until disabled.")
            }
        }
        .navigationTitle("Debug Snippets")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if showResult, let result = executionResult {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(result)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showResult)
    }

    private func executeSnippet(_ snippet: DebugSnippet) {
        let isCurrentlyActive = snippetsManager.isActive(snippet.id)
        let script: String

        if snippet.isToggleable {
            snippetsManager.toggle(snippet.id)
            script = isCurrentlyActive ? (snippet.undoScript ?? snippet.script) : snippet.script
        } else {
            script = snippet.script
        }

        Task {
            let result = await navigator.evaluateJavaScript(script)
            await MainActor.run {
                if let resultStr = result as? String {
                    executionResult = resultStr
                } else {
                    executionResult = snippet.isToggleable
                        ? (isCurrentlyActive ? "\(snippet.name) disabled" : "\(snippet.name) enabled")
                        : "\(snippet.name) executed"
                }
                showResult = true

                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        showResult = false
                    }
                }
            }
        }
    }
}

// MARK: - Snippet Settings Row

private struct SnippetSettingsRow: View {
    let snippet: DebugSnippet
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: snippet.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? .white : snippet.iconColor)
                    .frame(width: 32, height: 32)
                    .background(
                        isActive ? snippet.iconColor : snippet.iconColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(snippet.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)

                        if snippet.isToggleable {
                            Text(isActive ? "ON" : "Toggle")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isActive ? .white : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    isActive ? Color.green : Color.secondary.opacity(0.2),
                                    in: Capsule()
                                )
                        }
                    }

                    Text(snippet.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(isActive ? snippet.iconColor.opacity(0.08) : Color.clear)
    }
}

#Preview {
    NavigationStack {
        SnippetsSettingsView(navigator: WebViewNavigator())
    }
}
