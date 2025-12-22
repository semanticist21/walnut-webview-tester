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
            VStack(spacing: 8) {
                // URL input row
                urlInputRow

                // History section - 4 items height with scroll
                ScrollView {
                    historySection
                }
                .frame(height: 160)  // ~4 items (40px each)
                .scrollBounceBehavior(.basedOnSize)

                // Cancel button
                Button {
                    urlInputFocused = false
                    showURLInput = false
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
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
        .padding(.leading, 18)
        .padding(.trailing, 10)
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

    @ViewBuilder
    private var historySection: some View {
        let history = urlStorage.history
        let filtered = urlInputText.isEmpty ? history : history.filter {
            $0.localizedCaseInsensitiveContains(urlInputText)
        }

        if filtered.isEmpty {
            Text(history.isEmpty ? "No history yet" : "No matches")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element) { index, url in
                    historyRow(url: url, isLast: index == filtered.count - 1)
                }
            }
        }
    }

    private func historyRow(url: String, isLast: Bool) -> some View {
        Button {
            urlInputText = url
            urlStorage.addToHistory(url)
            onURLChange(url)
            showURLInput = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text(url)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            UIPasteboard.general.string = url
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .overlay(alignment: .trailing) {
            Button {
                urlStorage.removeFromHistory(url)
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.horizontal, 12)
            }
        }
    }
}
