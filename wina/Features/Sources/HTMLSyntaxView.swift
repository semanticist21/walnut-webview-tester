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

    var body: some View {
        HTMLTextView(
            text: html,
            searchText: searchText,
            currentMatchIndex: currentMatchLineIndex,
            matchingLineIndices: matchingLineIndices
        )
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - HTML Text View (Runestone with virtualization)

struct HTMLTextView: UIViewRepresentable {
    let text: String
    let searchText: String
    let currentMatchIndex: Int?
    let matchingLineIndices: [Int]

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
        context.coordinator.setupTextView(textView, with: text)

        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        let coordinator = context.coordinator

        // Update text if changed
        if coordinator.lastText != text {
            coordinator.lastText = text
            coordinator.setupTextView(textView, with: text)
        }

        // Handle search - Runestone has built-in search support
        if coordinator.lastSearchText != searchText {
            coordinator.lastSearchText = searchText

            if searchText.isEmpty {
                textView.highlightedRanges = []
            } else {
                coordinator.highlightSearchResults(in: textView, searchText: searchText)
            }
        }

        // Scroll to current match
        if coordinator.lastMatchIndex != currentMatchIndex {
            coordinator.lastMatchIndex = currentMatchIndex

            if let matchIdx = currentMatchIndex, matchIdx < matchingLineIndices.count {
                let lineIndex = matchingLineIndices[matchIdx]
                _ = textView.goToLine(lineIndex)
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

        func setupTextView(_ textView: TextView, with text: String) {
            // Create state with HTML language for syntax highlighting
            // Theme must be created on MainActor since HTMLViewerTheme conforms to @MainActor Theme protocol
            Task { @MainActor in
                let theme = HTMLViewerTheme()
                let state = TextViewState(text: text, theme: theme, language: .html)
                textView.setState(state)
            }
        }

        func highlightSearchResults(in textView: TextView, searchText: String) {
            // Use Runestone's built-in search
            let query = SearchQuery(text: searchText, matchMethod: .contains, isCaseSensitive: false)
            let results = textView.search(for: query)

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

    let font: UIFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    let textColor: UIColor = .label

    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .separator

    let lineNumberColor: UIColor = .tertiaryLabel
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 10, weight: .regular)

    let selectedLineBackgroundColor: UIColor = .systemGray6
    let selectedLinesLineNumberColor: UIColor = .secondaryLabel
    let selectedLinesGutterBackgroundColor: UIColor = .tertiarySystemBackground

    let invisibleCharactersColor: UIColor = .tertiaryLabel

    let pageGuideHairlineColor: UIColor = .separator
    let pageGuideBackgroundColor: UIColor = .secondarySystemBackground

    let markedTextBackgroundColor: UIColor = .systemYellow.withAlphaComponent(0.2)

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
