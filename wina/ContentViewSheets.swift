//
//  ContentViewSheets.swift
//  wina
//
//  Sheet presentations and helper views for ContentView.
//

import SwiftUI
import UIKit

// MARK: - URL Validation State

enum URLValidationState {
    case empty
    case valid
    case invalid

    var iconName: String {
        switch self {
        case .empty: return "globe"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .empty: return .secondary
        case .valid: return .green
        case .invalid: return .red
        }
    }
}

// MARK: - Bookmarks Sheet

struct BookmarksSheet: View {
    let bookmarkedURLs: [String]
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onAdd: (String) -> Void
    let currentURL: String

    @Environment(\.dismiss) private var dismiss
    @State private var newURL: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                addSection
                bookmarksListSection
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var addSection: some View {
        Section {
            HStack {
                TextField("URL", text: $newURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($isInputFocused)

                if !newURL.isEmpty {
                    Button {
                        onAdd(newURL)
                        newURL = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Quick add current URL
            if !currentURL.isEmpty && !bookmarkedURLs.contains(currentURL) {
                Button {
                    onAdd(currentURL)
                } label: {
                    HStack {
                        Text("Add")
                            .foregroundStyle(.blue)
                        Text(currentURL)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Add")
        }
    }

    @ViewBuilder
    private var bookmarksListSection: some View {
        if bookmarkedURLs.isEmpty {
            Section {
                Text("No bookmarks")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                ForEach(bookmarkedURLs, id: \.self) { url in
                    Button {
                        onSelect(url)
                        dismiss()
                    } label: {
                        Text(url)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .onLongPressGesture {
                        UIPasteboard.general.string = url
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(url)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Saved")
            }
        }
    }
}
