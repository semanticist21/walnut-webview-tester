//
//  ContentView.swift
//  wina
//
//  Created by 박지원 on 12/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var urlText: String = ""
    @State private var showDropdown: Bool = false
    @State private var showSettings: Bool = false
    @State private var showBookmarks: Bool = false
    @State private var urlValidationState: URLValidationState = .empty
    @State private var useSafariWebView: Bool = false
    @State private var showWebView: Bool = false
    @State private var loadedURL: String = ""
    @State private var webViewID: UUID = UUID()
    @State private var bookmarks: [String] = []
    @State private var cachedRecentURLs: [String] = []
    @State private var validationTask: Task<Void, Never>?
    @FocusState private var textFieldFocused: Bool
    @AppStorage("recentURLs") private var recentURLsData: Data = Data()
    @AppStorage("bookmarkedURLs") private var bookmarkedURLsData: Data = Data()

    // Cached NSDataDetector for URL validation (expensive to create)
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    // Safari configuration settings (for onChange detection)
    @AppStorage("safariEntersReaderIfAvailable") private var safariEntersReaderIfAvailable = false
    @AppStorage("safariBarCollapsingEnabled") private var safariBarCollapsingEnabled = true

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

    private func decodeRecentURLs() -> [String] {
        (try? JSONDecoder().decode([String].self, from: recentURLsData)) ?? []
    }

    private func loadBookmarks() -> [String] {
        (try? JSONDecoder().decode([String].self, from: bookmarkedURLsData)) ?? []
    }

    private var filteredURLs: [String] {
        if urlText.isEmpty {
            return cachedRecentURLs
        }
        return cachedRecentURLs.filter { $0.localizedCaseInsensitiveContains(urlText) }
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
            if useSafariWebView {
                SafariVCSettingsView(webViewID: $webViewID)
            } else {
                LoadedSettingsView(webViewID: $webViewID)
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksSheet(
                bookmarkedURLs: bookmarks,
                onSelect: { url in
                    urlText = url
                },
                onDelete: { url in
                    removeBookmark(url)
                },
                onAdd: { url in
                    addBookmark(url)
                },
                currentURL: urlText
            )
        }
        // Recreate SafariVC when configuration settings change
        .onChange(of: safariEntersReaderIfAvailable) { _, _ in
            if useSafariWebView && showWebView {
                webViewID = UUID()
            }
        }
        .onChange(of: safariBarCollapsingEnabled) { _, _ in
            if useSafariWebView && showWebView {
                webViewID = UUID()
            }
        }
        .task {
            cachedRecentURLs = decodeRecentURLs()
            bookmarks = loadBookmarks()
        }
        .onChange(of: recentURLsData) { _, _ in
            cachedRecentURLs = decodeRecentURLs()
        }
        .onChange(of: bookmarkedURLsData) { _, _ in
            bookmarks = loadBookmarks()
        }
    }

    private var urlInputView: some View {
        GeometryReader { geometry in
            // Background tap to dismiss keyboard and dropdown
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    textFieldFocused = false
                    showDropdown = false
                }

            VStack(spacing: 16) {
                // Walnut logo
                Image("walnut")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.bottom, -12)

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
                                    textFieldFocused = false
                                    showDropdown = false
                                    submitURL()
                                }
                            }
                            .onChange(of: urlText) { _, _ in
                                // Debounced URL validation
                                validationTask?.cancel()
                                validationTask = Task {
                                    try? await Task.sleep(for: .milliseconds(150))
                                    guard !Task.isCancelled else { return }
                                    validateURL()
                                }
                            }

                        Button {
                            urlText = ""
                            textFieldFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(urlText.isEmpty ? 0 : 1)
                        .disabled(urlText.isEmpty)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(width: urlValidationState == .valid ? inputWidth - 60 : inputWidth)
                    .contentShape(Capsule())
                    .onTapGesture {
                        textFieldFocused = true
                    }
                    .glassEffect(in: .capsule)

                    if urlValidationState == .valid {
                        Button {
                            textFieldFocused = false
                            showDropdown = false
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
                // Autocomplete dropdown as overlay
                .overlay(alignment: .top) {
                    if showDropdown && !filteredURLs.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filteredURLs.prefix(4), id: \.self) { url in
                                Button {
                                    urlText = url
                                    textFieldFocused = false
                                    showDropdown = false
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
                                    .contentShape(Rectangle()) // 전체 영역 터치 가능
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .trailing) {
                                    Button {
                                        removeURL(url)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(.tertiary)
                                            .font(.system(size: 12))
                                            .padding(8) // 터치 영역 확대
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 10)
                                }

                                if url != filteredURLs.prefix(4).last {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .frame(width: inputWidth)
                        .glassEffect(in: .rect(cornerRadius: 16))
                        .offset(y: 60)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.32)
            .onChange(of: textFieldFocused) { _, newValue in
                withAnimation(.easeOut(duration: 0.15)) {
                    showDropdown = newValue && !filteredURLs.isEmpty
                }
            }
            .onChange(of: filteredURLs) { _, newValue in
                if textFieldFocused {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showDropdown = !newValue.isEmpty
                    }
                }
            }
        }
    }

    private var topBar: some View {
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
                    BookmarkButton(showBookmarks: $showBookmarks, hasBookmarks: !bookmarks.isEmpty)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if !showWebView {
                    InfoButton(useSafariVC: useSafariWebView)
                }
                SettingsButton(showSettings: $showSettings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func submitURL() {
        guard !urlText.isEmpty else { return }

        var urls = cachedRecentURLs
        urls.removeAll { $0 == urlText }
        urls.insert(urlText, at: 0)
        if urls.count > 20 {
            urls = Array(urls.prefix(20))
        }
        cachedRecentURLs = urls

        // Background JSON encoding
        let urlsToSave = urls
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(urlsToSave) {
                await MainActor.run { recentURLsData = data }
            }
        }

        loadedURL = urlText
        withAnimation(.easeOut(duration: 0.2)) {
            showWebView = true
        }
    }

    private func removeURL(_ url: String) {
        var urls = cachedRecentURLs
        urls.removeAll { $0 == url }
        cachedRecentURLs = urls

        // Background JSON encoding
        let urlsToSave = urls
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(urlsToSave) {
                await MainActor.run { recentURLsData = data }
            }
        }
    }

    private func addBookmark(_ url: String) {
        guard !bookmarks.contains(url) else { return }
        bookmarks.insert(url, at: 0)

        // Background JSON encoding
        let bookmarksToSave = bookmarks
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(bookmarksToSave) {
                await MainActor.run { bookmarkedURLsData = data }
            }
        }
    }

    private func removeBookmark(_ url: String) {
        bookmarks.removeAll { $0 == url }

        // Background JSON encoding
        let bookmarksToSave = bookmarks
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(bookmarksToSave) {
                await MainActor.run { bookmarkedURLsData = data }
            }
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

        guard let url = URL(string: urlString), let host = url.host else {
            return false
        }

        // Special handling for localhost
        if host == "localhost" {
            return true
        }

        // Special handling for IP addresses
        if isValidIPAddress(host) {
            return true
        }

        // Host must contain at least one dot (for TLD)
        // This rejects "www.naver" but allows "www.naver.com"
        guard host.contains(".") else {
            return false
        }

        // URL validation using cached NSDataDetector (Apple's link detection engine)
        guard let detector = Self.linkDetector else {
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
    let onAdd: (String) -> Void
    let currentURL: String

    @Environment(\.dismiss) private var dismiss
    @State private var newURL: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                // Add new bookmark section
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

                // Bookmarks list
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
