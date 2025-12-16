//
//  OverlayMenuBars+URLInput.swift
//  wina
//
//  URL Input overlay view for OverlayMenuBars.
//

import SwiftUI
import SwiftUIBackports

// MARK: - URL Input Overlay View

struct URLInputOverlayView: View {
    @Binding var urlInputText: String
    @Binding var showURLInput: Bool
    @Binding var showBookmarks: Bool
    let urlStorage: URLStorageManager
    let currentURL: String?
    let onURLChange: (String) -> Void

    @FocusState private var urlInputFocused: Bool

    private var filteredHistory: [String] {
        urlStorage.filteredHistory(query: urlInputText)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    urlInputFocused = false
                    showURLInput = false
                }

            // Input card
            VStack(spacing: 12) {
                // URL input row
                urlInputRow

                // History section
                if !filteredHistory.isEmpty || urlInputText.isEmpty {
                    ScrollView {
                        historySection
                    }
                    .frame(maxHeight: 240)
                    .scrollBounceBehavior(.basedOnSize)
                }

                // Cancel button
                Button {
                    urlInputFocused = false
                    showURLInput = false
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(width: 340)
            .backport.glassEffect(in: .rect(cornerRadius: 24))
        }
        .onAppear {
            urlInputFocused = true
        }
    }

    // MARK: - URL Input Row

    private var urlInputRow: some View {
        HStack(spacing: 8) {
            // URL TextField
            TextField("Enter URL", text: $urlInputText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($urlInputFocused)
                .onSubmit {
                    submitURL()
                }

            // Clear button
            if !urlInputText.isEmpty {
                Button {
                    urlInputText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Bookmark button - opens bookmark modal
            Button {
                urlInputFocused = false
                showURLInput = false
                showBookmarks = true
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            // Bookmark toggle for current URL
            if let currentURL, !currentURL.isEmpty {
                let isBookmarked = urlStorage.isBookmarked(currentURL)
                Button {
                    urlStorage.toggleBookmark(currentURL)
                } label: {
                    Image(systemName: isBookmarked ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundStyle(isBookmarked ? .yellow : .secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Go button
            Button {
                submitURL()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(urlInputText.isEmpty ? .secondary : .blue)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(urlInputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .backport.glassEffect(in: .capsule)
    }

    private func submitURL() {
        guard !urlInputText.isEmpty else { return }
        urlStorage.addToHistory(urlInputText)
        onURLChange(urlInputText)
        showURLInput = false
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("History")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            if filteredHistory.isEmpty {
                Text("No history yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            } else {
                ForEach(filteredHistory, id: \.self) { url in
                    historyRow(url: url)
                }
            }
        }
    }

    private func historyRow(url: String) -> some View {
        Button {
            urlInputText = url
            urlStorage.addToHistory(url)
            onURLChange(url)
            showURLInput = false
        } label: {
            HStack(spacing: 8) {
                Text(url)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
