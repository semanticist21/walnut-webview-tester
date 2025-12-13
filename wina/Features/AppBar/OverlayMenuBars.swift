//
//  OverlayMenuBars.swift
//  wina
//
//  Created by Claude on 12/13/25.
//

import SwiftUI

struct OverlayMenuBars: View {
    let showWebView: Bool
    let hasBookmarks: Bool
    let useSafariVC: Bool
    let isOverlayMode: Bool  // true: pull menu, false: fixed position
    let onHome: () -> Void
    let onURLChange: (String) -> Void
    let navigator: WebViewNavigator?
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showInfo: Bool
    @Binding var showConsole: Bool
    @Binding var showNetwork: Bool

    @State private var isExpanded: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var showURLInput: Bool = false
    @State private var urlInputText: String = ""
    // WKWebView 내부 input 필드의 키보드 표시 상태를 추적한다
    @State private var isKeyboardVisible: Bool = false
    @FocusState private var urlInputFocused: Bool

    private let topBarHeight: CGFloat = 64
    private let bottomBarHeight: CGFloat = 56
    private let topHandleVisible: CGFloat = 6  // Tiny peek for top bar

    // Top bar offset (comes down from top)
    private var topOffset: CGFloat {
        guard isOverlayMode else { return 0 }  // Fixed position
        if isExpanded {
            return dragOffset
        } else {
            return -topBarHeight + topHandleVisible + dragOffset
        }
    }

    // Bottom bar offset (comes up from bottom)
    private var bottomOffset: CGFloat {
        guard isOverlayMode else { return 0 }  // Fixed position
        if isExpanded {
            return -dragOffset
        } else {
            return bottomBarHeight - dragOffset  // Fully hidden
        }
    }

    // 하단 바 표시 여부를 결정한다 (키보드가 올라오면 하단 바를 숨긴다)
    private var showBottomBar: Bool {
        // 키보드가 보이면 하단 바를 숨겨서 입력을 방해하지 않는다
        guard !isKeyboardVisible else { return false }
        // overlay 모드에서는 확장 상태일 때만, fixed 모드에서는 항상 표시한다
        return !isOverlayMode || isExpanded
    }

    var body: some View {
        ZStack {
            // Top bar
            topBar
                .frame(maxHeight: .infinity, alignment: .top)

            // Bottom bar (hidden in overlay mode when collapsed)
            if showBottomBar {
                bottomBar
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
        .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)
        .onAppear {
            isExpanded = !isOverlayMode  // Expanded by default in fixed mode
        }
        .onChange(of: isOverlayMode) { _, newValue in
            isExpanded = !newValue
        }
        // WKWebView 내부 input 필드에서 키보드가 올라올 때 시스템 notification을 수신한다
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        // WKWebView 내부 input 필드에서 키보드가 내려갈 때 시스템 notification을 수신한다
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        // URL 변경 overlay - bottomBar 조건부 렌더링과 독립적으로 유지
        .overlay {
            if showURLInput {
                urlInputOverlay
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 6) {
            // Menu buttons
            HStack(spacing: 12) {
                if showWebView {
                    // WebView mode: Home, Back, Forward, Refresh
                    HomeButton(action: onHome)

                    // Navigation buttons (only for WKWebView, not SafariVC)
                    if !useSafariVC, let nav = navigator {
                        WebBackButton(isEnabled: nav.canGoBack) {
                            nav.goBack()
                        }
                        WebForwardButton(isEnabled: nav.canGoForward) {
                            nav.goForward()
                        }
                        RefreshButton {
                            nav.reload()
                        }
                    }
                } else {
                    ThemeToggleButton()
                    BookmarkButton(showBookmarks: $showBookmarks, hasBookmarks: hasBookmarks)
                }

                Spacer()

                // Info button (always visible)
                InfoSheetButton(showInfo: $showInfo)
                SettingsButton(showSettings: $showSettings)
            }
            .padding(.horizontal, 16)

            // Handle (drag area) - only in overlay mode
            if isOverlayMode {
                Capsule()
                    .frame(width: 36, height: 4)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .glassEffect(in: .capsule)
        .padding(.horizontal, 8)
        .offset(y: topOffset)
        .highPriorityGesture(isOverlayMode ? dragGesture : nil)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                if showWebView {
                    // URL button
                    Button {
                        urlInputText = navigator?.currentURL?.absoluteString ?? ""
                        showURLInput = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 13))
                            Text(navigator?.currentURL?.host() ?? "URL")
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // Console and Network buttons (only for WKWebView)
                    if !useSafariVC {
                        Button {
                            showConsole = true
                        } label: {
                            Image(systemName: "terminal")
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            showNetwork = true
                        } label: {
                            Image(systemName: "network")
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .frame(height: bottomBarHeight)
            .frame(maxWidth: .infinity)
            .glassEffect(in: .capsule)
            .padding(.horizontal, 8)
            // Dynamic: push down by half of safe area to sit nicely above home indicator
            .padding(.bottom, -(geometry.safeAreaInsets.bottom * 0.6))
            .offset(y: bottomOffset)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - URL Input Overlay

    private var urlInputOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    urlInputFocused = false
                    showURLInput = false
                }

            // Input card
            VStack(spacing: 16) {
                Text("Change URL")
                    .font(.headline)

                // URL input with clear button
                HStack(spacing: 8) {
                    TextField("Enter URL", text: $urlInputText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .focused($urlInputFocused)
                        .onSubmit {
                            if !urlInputText.isEmpty {
                                onURLChange(urlInputText)
                                showURLInput = false
                            }
                        }

                    // Clear button
                    if !urlInputText.isEmpty {
                        Button {
                            urlInputText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(in: .capsule)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        urlInputFocused = false
                        showURLInput = false
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(in: .capsule)

                    Button {
                        if !urlInputText.isEmpty {
                            onURLChange(urlInputText)
                            showURLInput = false
                        }
                    } label: {
                        Text("Go")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(in: .capsule)
                    .opacity(urlInputText.isEmpty ? 0.5 : 1)
                    .disabled(urlInputText.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320)
            .glassEffect(in: .rect(cornerRadius: 24))
        }
        .onAppear {
            urlInputFocused = true
        }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.height

                if isExpanded {
                    // When expanded, allow dragging up (negative) to close
                    dragOffset = min(0, translation)
                } else {
                    // When collapsed, allow dragging down (positive) to open
                    dragOffset = max(0, min(topBarHeight, translation))
                }
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height - translation

                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isExpanded {
                        // Close if dragged up enough or with velocity
                        if translation < -30 || velocity < -100 {
                            isExpanded = false
                        }
                    } else {
                        // Open if dragged down enough or with velocity
                        if translation > 30 || velocity > 100 {
                            isExpanded = true
                        }
                    }
                    dragOffset = 0
                }
            }
    }
}

#Preview("Overlay Mode (Fullscreen)") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        OverlayMenuBars(
            showWebView: true,
            hasBookmarks: true,
            useSafariVC: false,
            isOverlayMode: true,
            onHome: {},
            onURLChange: { _ in },
            navigator: nil,
            showSettings: .constant(false),
            showBookmarks: .constant(false),
            showInfo: .constant(false),
            showConsole: .constant(false),
            showNetwork: .constant(false)
        )
    }
}

#Preview("Fixed Mode (App Preset)") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        OverlayMenuBars(
            showWebView: true,
            hasBookmarks: true,
            useSafariVC: false,
            isOverlayMode: false,
            onHome: {},
            onURLChange: { _ in },
            navigator: nil,
            showSettings: .constant(false),
            showBookmarks: .constant(false),
            showInfo: .constant(false),
            showConsole: .constant(false),
            showNetwork: .constant(false)
        )
    }
}
