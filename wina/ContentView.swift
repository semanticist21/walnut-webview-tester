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
    @FocusState private var textFieldFocused: Bool
    @AppStorage("recentURLs") private var recentURLsData: Data = Data()

    private var recentURLs: [String] {
        (try? JSONDecoder().decode([String].self, from: recentURLsData)) ?? []
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
                    // URL parts chips - FlowLayout으로 줄바꿈
                    FlowLayout(spacing: 8, alignment: .center) {
                        ForEach(urlParts, id: \.self) { part in
                            ChipButton(label: part) {
                                urlText += part
                            }
                        }
                    }
                    .frame(width: inputWidth)

                // URL Input
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))

                    TextField("URL 입력", text: $urlText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .font(.system(size: 16))
                        .focused($textFieldFocused)
                        .onSubmit {
                            isFocused = false
                            textFieldFocused = false
                            submitURL()
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
                .frame(width: inputWidth)
                .glassEffect(in: .capsule)
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFocused = true
                        }
                    } else {
                        isFocused = false  // 애니메이션 없이 즉시 사라짐
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
                    ThemeToggleButton()

                    Spacer()

                    HStack(spacing: 12) {
                        CompatibilityCheckButton()
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
}

#Preview {
    ContentView()
}
