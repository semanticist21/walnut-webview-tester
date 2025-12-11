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

                    // URL parts chips - FlowLayout으로 줄바꿈
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

                        TextField("URL 입력", text: $urlText)
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
                    // 자동완성 드롭다운 (오버레이)
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

            // Top bar
            VStack {
                HStack {
                    HStack(spacing: 12) {
                        ThemeToggleButton()
                        BookmarkButton(showBookmarks: $showBookmarks, hasBookmarks: !bookmarkedURLs.isEmpty)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        InfoButton()
                        SettingsButton(showSettings: $showSettings)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

        // TODO: WebView 로딩 구현
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
        // http/https 스킴이 없으면 https:// 붙여서 검증
        var urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        guard let url = URL(string: urlString),
              let host = url.host,
              !host.isEmpty else {
            return false
        }

        // localhost 허용
        if host == "localhost" {
            return true
        }

        // IP 주소 검증
        if isValidIPAddress(host) {
            return true
        }

        // 도메인 검증: . 으로 분리된 부분이 각각 유효해야 함
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)

        // 최소 2개 파트 필요 (예: example.com)
        guard parts.count >= 2 else { return false }

        // 각 파트가 비어있지 않고, 유효한 문자만 포함해야 함
        for part in parts {
            // 빈 파트 불허 (.com, example. 등)
            guard !part.isEmpty else { return false }
            // 알파벳, 숫자, 하이픈만 허용
            let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
            guard part.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return false }
            // 하이픈으로 시작/끝나면 안됨
            guard !part.hasPrefix("-") && !part.hasSuffix("-") else { return false }
        }

        // TLD가 최소 2글자 이상
        guard let tld = parts.last, tld.count >= 2 else { return false }

        return true
    }

    private func isValidIPAddress(_ string: String) -> Bool {
        // IPv4 검증
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
                                Text("현재 URL 북마크 추가")
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
                        Text("저장된 북마크가 없습니다")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("북마크") {
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
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("북마크")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
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
