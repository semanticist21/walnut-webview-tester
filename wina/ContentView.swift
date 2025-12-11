//
//  ContentView.swift
//  wina
//
//  Created by 박지원 on 12/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var urlText: String = ""
    @State private var isFocused: Bool = false
    @State private var showSettings: Bool = false
    @State private var showBookmarks: Bool = false
    @State private var urlValidationState: URLValidationState = .empty
    @State private var useSafariWebView: Bool = false
    @State private var showWebView: Bool = false
    @State private var loadedURL: String = ""
    @State private var webViewID: UUID = UUID()
    @FocusState private var textFieldFocused: Bool
    @AppStorage("recentURLs") private var recentURLsData: Data = Data()
    @AppStorage("bookmarkedURLs") private var bookmarkedURLsData: Data = Data()

    private enum URLValidationState {
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

    private var recentURLs: [String] {
        (try? JSONDecoder().decode([String].self, from: recentURLsData)) ?? []
    }

    private var bookmarkedURLs: [String] {
        (try? JSONDecoder().decode([String].self, from: bookmarkedURLsData)) ?? []
    }

    private var filteredURLs: [String] {
        if urlText.isEmpty {
            return recentURLs
        }
        return recentURLs.filter { $0.localizedCaseInsensitiveContains(urlText) }
    }

    private let urlParts = [
        "https://", "http://",
        "www.", "m.",
        ".com",
        "192.168.", ":8080", ":3000"
    ]
    private let inputWidth: CGFloat = 340

    var body: some View {
        ZStack {
            if showWebView {
                // WebView screen
                WebViewContainer(urlString: loadedURL, useSafari: useSafariWebView, webViewID: $webViewID)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                // URL input screen
                urlInputView
            }

            // Top bar (always visible)
            topBar
        }
        .sheet(isPresented: $showSettings) {
            if showWebView {
                DynamicSettingsView(webViewID: $webViewID)
            } else {
                SettingsView()
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksSheet(
                bookmarkedURLs: bookmarkedURLs,
                onSelect: { url in
                    urlText = url
                    submitURL()
                },
                onDelete: { url in
                    removeBookmark(url)
                },
                onAddCurrent: !urlText.isEmpty ? {
                    addBookmark(urlText)
                } : nil,
                currentURL: urlText
            )
        }
    }

    private var urlInputView: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Walnut logo
                    if let walnutURL = Bundle.main.url(forResource: "walnut", withExtension: "avif"),
                       let imageData = try? Data(contentsOf: walnutURL),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .padding(.bottom, -12)
                    }

                    // URL parts chips - FlowLayout for wrapping
                    FlowLayout(spacing: 8, alignment: .center) {
                        ForEach(urlParts, id: \.self) { part in
                            ChipButton(label: part) {
                                urlText += part
                            }
                        }
                    }
                    .frame(width: inputWidth)

                // WebView Type Toggle
                Picker("WebView Type", selection: $useSafariWebView) {
                    Text("WKWebView")
                        .tag(false)
                    Text("SafariVC")
                        .tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: inputWidth)

                // URL Input
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: urlValidationState.iconName)
                            .foregroundStyle(urlValidationState.iconColor)
                            .font(.system(size: 16))
                            .contentTransition(.symbolEffect(.replace))

                        TextField("Enter URL", text: $urlText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .font(.system(size: 16))
                            .focused($textFieldFocused)
                            .onSubmit {
                                if urlValidationState == .valid {
                                    isFocused = false
                                    textFieldFocused = false
                                    submitURL()
                                }
                            }
                            .onChange(of: urlText) { _, _ in
                                validateURL()
                            }

                        if !urlText.isEmpty {
                            Button {
                                urlText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(width: urlValidationState == .valid ? inputWidth - 60 : inputWidth)
                    .glassEffect(in: .capsule)

                    if urlValidationState == .valid {
                        Button {
                            isFocused = false
                            textFieldFocused = false
                            submitURL()
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 48, height: 48)
                                .glassEffect(in: .circle)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.animation(.easeOut(duration: 0.15)))
                    }
                }
                .animation(.easeOut(duration: 0.25), value: urlValidationState)
                .overlay(alignment: .top) {
                    // Autocomplete dropdown (overlay)
                    if isFocused && !filteredURLs.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filteredURLs.prefix(4), id: \.self) { url in
                                Button {
                                    urlText = url
                                    isFocused = false
                                    textFieldFocused = false
                                    submitURL()
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 14))
                                        Text(url)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .trailing) {
                                    Button {
                                        removeURL(url)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(.tertiary)
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 18)
                                }

                                if url != filteredURLs.prefix(4).last {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .frame(width: inputWidth)
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .offset(y: 56)
                    }
                }
                .onChange(of: textFieldFocused) { _, newValue in
                    if newValue {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isFocused = true
                        }
                    } else {
                        isFocused = false
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = false
                textFieldFocused = false
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.32)
        }
    }

    private var topBar: some View {
        VStack {
            HStack {
                HStack(spacing: 12) {
                    if showWebView {
                        BackButton {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showWebView = false
                            }
                        }
                    } else {
                        ThemeToggleButton()
                        BookmarkButton(showBookmarks: $showBookmarks, hasBookmarks: !bookmarkedURLs.isEmpty)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    if !showWebView {
                        InfoButton()
                    }
                    SettingsButton(showSettings: $showSettings)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    private func submitURL() {
        guard !urlText.isEmpty else { return }

        var urls = recentURLs
        urls.removeAll { $0 == urlText }
        urls.insert(urlText, at: 0)
        if urls.count > 20 {
            urls = Array(urls.prefix(20))
        }

        if let data = try? JSONEncoder().encode(urls) {
            recentURLsData = data
        }

        loadedURL = urlText
        withAnimation(.easeOut(duration: 0.2)) {
            showWebView = true
        }
    }

    private func removeURL(_ url: String) {
        var urls = recentURLs
        urls.removeAll { $0 == url }

        if let data = try? JSONEncoder().encode(urls) {
            recentURLsData = data
        }
    }

    private func addBookmark(_ url: String) {
        var bookmarks = bookmarkedURLs
        if !bookmarks.contains(url) {
            bookmarks.insert(url, at: 0)
            if let data = try? JSONEncoder().encode(bookmarks) {
                bookmarkedURLsData = data
            }
        }
    }

    private func removeBookmark(_ url: String) {
        var bookmarks = bookmarkedURLs
        bookmarks.removeAll { $0 == url }
        if let data = try? JSONEncoder().encode(bookmarks) {
            bookmarkedURLsData = data
        }
    }

    private func validateURL() {
        guard !urlText.isEmpty else {
            urlValidationState = .empty
            return
        }
        urlValidationState = isValidURL(urlText) ? .valid : .invalid
    }

    private func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Add https:// if no scheme present
        var urlString = trimmed
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        // Special handling for localhost
        if let url = URL(string: urlString), url.host == "localhost" {
            return true
        }

        // Special handling for IP addresses
        if let url = URL(string: urlString), let host = url.host, isValidIPAddress(host) {
            return true
        }

        // URL validation using NSDataDetector (Apple's link detection engine)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }

        let range = NSRange(urlString.startIndex..., in: urlString)
        let matches = detector.matches(in: urlString, options: [], range: range)

        // Exactly one match must cover the entire string
        guard matches.count == 1,
              let match = matches.first,
              match.range.location == 0,
              match.range.length == urlString.utf16.count else {
            return false
        }

        return true
    }

    private func isValidIPAddress(_ string: String) -> Bool {
        // IPv4 validation
        let ipv4Parts = string.split(separator: ".")
        if ipv4Parts.count == 4 {
            return ipv4Parts.allSatisfy { part in
                guard let num = Int(part) else { return false }
                return num >= 0 && num <= 255
            }
        }
        return false
    }
}

// MARK: - Bookmarks Sheet

private struct BookmarksSheet: View {
    let bookmarkedURLs: [String]
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onAddCurrent: (() -> Void)?
    let currentURL: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let onAddCurrent, !currentURL.isEmpty, !bookmarkedURLs.contains(currentURL) {
                    Section {
                        Button {
                            onAddCurrent()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Add Current URL to Bookmarks")
                                Spacer()
                                Text(currentURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                if bookmarkedURLs.isEmpty {
                    Section {
                        Text("No saved bookmarks")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Bookmarks") {
                        ForEach(bookmarkedURLs, id: \.self) { url in
                            Button {
                                onSelect(url)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(.orange)
                                    Text(url)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDelete(url)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
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
}

#Preview {
    ContentView()
}
