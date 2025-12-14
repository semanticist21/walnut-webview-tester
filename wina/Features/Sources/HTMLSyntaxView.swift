//
//  HTMLSyntaxView.swift
//  wina
//
//  Runestone-based HTML syntax view with virtualization.
//

import Runestone
import SwiftUI
import TreeSitterHTMLRunestone

// MARK: - HTML Syntax View

struct HTMLSyntaxView: View {
    let html: String
    let searchText: String
    let currentMatchLineIndex: Int?
    let matchingLineIndices: [Int]

    @AppStorage("htmlViewerFontSize") private var fontSize: Double = 12

    private let minFontSize: Double = 8
    private let maxFontSize: Double = 24

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HTMLTextView(
                text: html,
                searchText: searchText,
                currentMatchIndex: currentMatchLineIndex,
                matchingLineIndices: matchingLineIndices,
                fontSize: fontSize
            )

            // Font size controls
            fontSizeControls
                .padding(12)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var fontSizeControls: some View {
        HStack(spacing: 0) {
            Button {
                if fontSize > minFontSize {
                    fontSize = max(minFontSize, fontSize - 2)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(fontSize <= minFontSize)

            Text("\(Int(fontSize))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(width: 24)

            Button {
                if fontSize < maxFontSize {
                    fontSize = min(maxFontSize, fontSize + 2)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(fontSize >= maxFontSize)
        }
        .foregroundStyle(.secondary)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - HTML Text View (Runestone with virtualization)

struct HTMLTextView: UIViewRepresentable {
    let text: String
    let searchText: String
    let currentMatchIndex: Int?
    let matchingLineIndices: [Int]
    let fontSize: Double

    /// Calculate character offset for the start of a given line (0-based)
    private func lineStartOffset(for lineIndex: Int) -> Int {
        let lines = text.components(separatedBy: "\n")
        var offset = 0
        for i in 0..<min(lineIndex, lines.count) {
            offset += lines[i].count + 1  // +1 for newline
        }
        return offset
    }

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()

        // Read-only mode with text selection
        textView.isEditable = false
        textView.isSelectable = true

        // Disable line wrapping for horizontal scroll
        textView.isLineWrappingEnabled = false

        // Visual settings
        textView.showLineNumbers = true
        textView.backgroundColor = .systemBackground
        textView.lineHeightMultiplier = 1.2

        // Set up theme and state
        context.coordinator.lastFontSize = fontSize
        context.coordinator.setupTextView(textView, with: text, fontSize: fontSize)

        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        let coordinator = context.coordinator

        // Update text or font size if changed
        if coordinator.lastText != text || coordinator.lastFontSize != fontSize {
            coordinator.lastText = text
            coordinator.lastFontSize = fontSize
            coordinator.setupTextView(textView, with: text, fontSize: fontSize)
        }

        // Handle search - Runestone has built-in search support
        if coordinator.lastSearchText != searchText {
            coordinator.lastSearchText = searchText

            if searchText.isEmpty {
                textView.highlightedRanges = []
                coordinator.searchResultRanges = []
            } else {
                coordinator.highlightSearchResults(in: textView, searchText: searchText)
            }
        }

        // Scroll to current match using stored search result ranges
        if coordinator.lastMatchIndex != currentMatchIndex {
            coordinator.lastMatchIndex = currentMatchIndex

            if let matchIdx = currentMatchIndex, matchIdx < matchingLineIndices.count {
                let targetLineIndex = matchingLineIndices[matchIdx]
                let targetOffset = lineStartOffset(for: targetLineIndex)

                // Find first search result on or after the target line
                if let range = coordinator.searchResultRanges.first(where: { $0.location >= targetOffset }) {
                    textView.scrollRangeToVisible(range)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastText: String = ""
        var lastSearchText: String = ""
        var lastMatchIndex: Int?
        var lastFontSize: Double = 12
        var searchResultRanges: [NSRange] = []

        func setupTextView(_ textView: TextView, with text: String, fontSize: Double) {
            // Create state with HTML language for syntax highlighting
            // Theme must be created on MainActor since HTMLViewerTheme conforms to @MainActor Theme protocol
            Task { @MainActor in
                let theme = HTMLViewerTheme(fontSize: fontSize)
                let state = TextViewState(text: text, theme: theme, language: .html)
                textView.setState(state)
            }
        }

        func highlightSearchResults(in textView: TextView, searchText: String) {
            // Use Runestone's built-in search
            let query = SearchQuery(text: searchText, matchMethod: .contains, isCaseSensitive: false)
            let results = textView.search(for: query)

            // Store ranges for navigation
            searchResultRanges = results.map(\.range)

            // Convert search results to highlighted ranges
            let highlightedRanges = results.map { result in
                HighlightedRange(range: result.range, color: .systemYellow.withAlphaComponent(0.4))
            }
            textView.highlightedRanges = highlightedRanges
        }
    }
}

// MARK: - HTML Viewer Theme (Runestone Theme)

final class HTMLViewerTheme: Runestone.Theme {
    let backgroundColor: UIColor = .systemBackground
    let userInterfaceStyle: UIUserInterfaceStyle = .unspecified

    let font: UIFont
    let textColor: UIColor = .label

    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .separator

    let lineNumberColor: UIColor = .tertiaryLabel
    let lineNumberFont: UIFont

    let selectedLineBackgroundColor: UIColor = .systemGray6
    let selectedLinesLineNumberColor: UIColor = .secondaryLabel
    let selectedLinesGutterBackgroundColor: UIColor = .tertiarySystemBackground

    let invisibleCharactersColor: UIColor = .tertiaryLabel

    let pageGuideHairlineColor: UIColor = .separator
    let pageGuideBackgroundColor: UIColor = .secondarySystemBackground

    let markedTextBackgroundColor: UIColor = .systemYellow.withAlphaComponent(0.2)

    init(fontSize: Double = 12) {
        self.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        self.lineNumberFont = .monospacedSystemFont(ofSize: max(8, fontSize - 2), weight: .regular)
    }

    func textColor(for highlightName: String) -> UIColor? {
        switch highlightName {
        case "tag", "tag.builtin":
            return UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0)
        case "attribute":
            return UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0)
        case "string", "string.special":
            return UIColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1.0)
        case "comment":
            return .secondaryLabel
        case "punctuation", "punctuation.bracket", "punctuation.delimiter":
            return .tertiaryLabel
        default:
            return nil
        }
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        []
    }
}
