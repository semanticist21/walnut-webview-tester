//
//  OverlayMenuBars.swift
//  wina
//
//  Created by Claude on 12/13/25.
//

import AudioToolbox
import SwiftUI
import SwiftUIBackports

struct OverlayMenuBars: View {
    let showWebView: Bool
    let hasBookmarks: Bool
    let useSafariVC: Bool
    let isOverlayMode: Bool  // true: pull menu, false: fixed position
    let erudaModeEnabled: Bool
    let onHome: () -> Void
    let onURLChange: (String) -> Void
    let navigator: WebViewNavigator?
    let urlStorage: URLStorageManager
    @Binding var showURLInput: Bool
    @Binding var urlInputText: String
    @Binding var showSettings: Bool
    @Binding var showBookmarks: Bool
    @Binding var showInfo: Bool
    @Binding var showConsole: Bool
    @Binding var showNetwork: Bool
    @Binding var showStorage: Bool
    @Binding var showPerformance: Bool
    @Binding var showEditor: Bool
    @Binding var showAccessibility: Bool
    @Binding var showSnippets: Bool
    @Binding var showSearchText: Bool

    @State private var isExpanded: Bool = false
    @State private var dragOffset: CGFloat = 0
    // WKWebView 내부 input 필드의 키보드 표시 상태를 추적한다
    @State private var isKeyboardVisible: Bool = false
    @State private var showPhotoPermissionAlert: Bool = false

    // Toolbar customization
    @AppStorage("toolbarItemsOrder") private var toolbarItemsOrderData = Data()
    @AppStorage("appBarItemsOrder") private var appBarItemsOrderData = Data()

    private var visibleToolbarItems: [DevToolsMenuItem] {
        guard let items = try? JSONDecoder().decode([ToolbarItemState].self, from: toolbarItemsOrderData),
              !items.isEmpty else {
            return DevToolsMenuItem.defaultOrder
        }
        return items.filter { $0.isVisible }.map { $0.menuItem }
    }

    private var visibleAppBarItems: [AppBarMenuItem] {
        guard let items = try? JSONDecoder().decode([AppBarItemState].self, from: appBarItemsOrderData),
              !items.isEmpty else {
            return AppBarMenuItem.defaultOrder
        }
        return items.filter { $0.isVisible }.map { $0.menuItem }
    }

    private let topBarHeight: CGFloat = BarConstants.barHeight
    private let bottomBarHeight: CGFloat = BarConstants.barHeight
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
                URLInputOverlayView(
                    urlInputText: $urlInputText,
                    showURLInput: $showURLInput,
                    showBookmarks: $showBookmarks,
                    urlStorage: urlStorage,
                    currentURL: navigator?.currentURL?.absoluteString,
                    onURLChange: onURLChange
                )
            }
        }
        .alert("Photo Access Required", isPresented: $showPhotoPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow photo library access in Settings to save screenshots.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 6) {
            // Menu buttons (all scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if showWebView {
                        // WebView mode: Navigation buttons based on user customization
                        ForEach(visibleAppBarItems) { item in
                            appBarButton(for: item)
                        }
                    } else {
                        ThemeToggleButton()
                        BookmarkButton(showBookmarks: $showBookmarks, hasBookmarks: hasBookmarks)
                    }

                    // Info & Settings buttons (always visible)
                    InfoSheetButton(showInfo: $showInfo)
                    SettingsButton(showSettings: $showSettings)
                }
                .frame(height: 44)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)

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
        .backport.glassEffect(in: .capsule)
        .clipShape(Capsule())  // Capsule 모양에 맞게 overflow 숨김
        .padding(.horizontal, 8)
        .offset(y: topOffset)
        .highPriorityGesture(isOverlayMode ? dragGesture : nil)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if showWebView {
                        // URL button (glassEffect capsule 통일)
                        Button {
                            showSearchText = false  // 검색바 자동 닫기
                            urlInputText = navigator?.currentURL?.absoluteString ?? ""
                            showURLInput = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 15))
                                Text(navigator?.currentURL?.host() ?? "URL")
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .backport.glassEffect(in: .capsule)

                        // WKWebView-only buttons
                        if !useSafariVC {
                            // DevTools buttons based on user customization
                            // Eruda mode hides DevTools except Search and Screenshot
                            ForEach(visibleToolbarItems) { item in
                                // Skip DevTools items when Eruda mode is enabled
                                if erudaModeEnabled && !item.isAlwaysVisible {
                                    EmptyView()
                                } else {
                                    BottomBarIconButton(icon: item.icon) {
                                        handleToolbarItemTap(item)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: bottomBarHeight)
                .contentShape(Rectangle())  // 전체 높이를 터치 영역으로
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)  // 패딩 영역까지 스크롤 가능
            .scrollBounceBehavior(.basedOnSize)  // overscroll 방지
            .frame(height: bottomBarHeight)
            .frame(width: geometry.size.width - 16)  // 기기 너비 - 좌우 padding
            .backport.glassEffect(in: .capsule)
            .clipShape(Capsule())  // Capsule 모양에 맞게 overflow 숨김
            .padding(.horizontal, 8)
            // Dynamic: push down by portion of safe area to sit above home indicator
            .padding(.bottom, -(geometry.safeAreaInsets.bottom * BarConstants.bottomBarSafeAreaRatio))
            .offset(y: bottomOffset)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - AppBar Button Builder

    @ViewBuilder
    private func appBarButton(for item: AppBarMenuItem) -> some View {
        switch item {
        case .home:
            HomeButton {
                urlInputText = ""
                onHome()
            }
        case .initialURL:
            if !useSafariVC, let nav = navigator {
                InitialURLButton(isEnabled: nav.canGoToInitialURL) {
                    nav.goToInitialURL()
                }
            }
        case .back:
            if !useSafariVC, let nav = navigator {
                WebBackButton(isEnabled: nav.canGoBack) {
                    nav.goBack()
                }
            }
        case .forward:
            if !useSafariVC, let nav = navigator {
                WebForwardButton(isEnabled: nav.canGoForward) {
                    nav.goForward()
                }
            }
        case .refresh:
            if !useSafariVC, let nav = navigator {
                RefreshButton {
                    nav.reload()
                }
            }
        }
    }

    // MARK: - Toolbar Item Actions

    private func handleToolbarItemTap(_ item: DevToolsMenuItem) {
        switch item {
        case .console:
            showSearchText = false
            showConsole = true
        case .sources:
            showSearchText = false
            showEditor = true
        case .network:
            showSearchText = false
            showNetwork = true
        case .storage:
            showSearchText = false
            showStorage = true
        case .performance:
            showSearchText = false
            showPerformance = true
        case .accessibility:
            showSearchText = false
            showAccessibility = true
        case .snippets:
            showSearchText = false
            showSnippets = true
        case .searchInPage:
            showSearchText.toggle()
        case .screenshot:
            takeScreenshotWithFeedback()
        }
    }

    // MARK: - Screenshot

    private func takeScreenshotWithFeedback() {
        Task {
            // Check permission first (before any feedback)
            let permission = navigator?.checkPhotoLibraryPermission() ?? .denied

            switch permission {
            case .notDetermined:
                let granted = await navigator?.requestPhotoLibraryPermission() ?? false
                if !granted {
                    await MainActor.run { showPhotoPermissionAlert = true }
                    return
                }
            case .denied:
                await MainActor.run { showPhotoPermissionAlert = true }
                return
            case .authorized:
                break
            }

            // Permission granted - now play feedback and capture
            AudioServicesPlaySystemSound(1108)

            await MainActor.run {
                withAnimation(.easeIn(duration: 0.05)) {
                    navigator?.showScreenshotFlash = true
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) {
                    navigator?.showScreenshotFlash = false
                }
            }

            try? await Task.sleep(for: .milliseconds(50))
            let result = await navigator?.takeScreenshot() ?? .failed

            if result == .success {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        navigator?.showScreenshotSavedToast = true
                    }
                }
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        navigator?.showScreenshotSavedToast = false
                    }
                }
            }
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

// MARK: - Bottom Bar Icon Button

/// Bottom bar icon button matching header button size (44×44, 18pt icon)
/// GlassIconButton과 동일한 스타일 적용 (glassEffect 통일)
private struct BottomBarIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .backport.glassEffect(in: .circle)
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
            erudaModeEnabled: false,
            onHome: {},
            onURLChange: { _ in },
            navigator: nil,
            urlStorage: .shared,
            showURLInput: .constant(false),
            urlInputText: .constant(""),
            showSettings: .constant(false),
            showBookmarks: .constant(false),
            showInfo: .constant(false),
            showConsole: .constant(false),
            showNetwork: .constant(false),
            showStorage: .constant(false),
            showPerformance: .constant(false),
            showEditor: .constant(false),
            showAccessibility: .constant(false),
            showSnippets: .constant(false),
            showSearchText: .constant(false)
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
            erudaModeEnabled: false,
            onHome: {},
            onURLChange: { _ in },
            navigator: nil,
            urlStorage: .shared,
            showURLInput: .constant(false),
            urlInputText: .constant(""),
            showSettings: .constant(false),
            showBookmarks: .constant(false),
            showInfo: .constant(false),
            showConsole: .constant(false),
            showNetwork: .constant(false),
            showStorage: .constant(false),
            showPerformance: .constant(false),
            showEditor: .constant(false),
            showAccessibility: .constant(false),
            showSnippets: .constant(false),
            showSearchText: .constant(false)
        )
    }
}
