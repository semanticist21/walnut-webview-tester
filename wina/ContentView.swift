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
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // URL parts chips - FlowLayout으로 줄바꿈
                FlowLayout(spacing: 8) {
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
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.25)
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

struct ChipButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .capsule)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    ContentView()
}
