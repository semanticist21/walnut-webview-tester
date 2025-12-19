# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wallnut (wina)** - WKWebView & SFSafariViewController 테스터 앱

WKWebView와 SFSafariViewController 설정을 실시간 테스트하는 개발자 도구. SwiftUI 기반, iOS 26.1+ (Tahoe)

**주요 기능**:
- **WKWebView**: 설정 옵션 테스트, DevTools (Console/Network/Storage/Performance/Sources/Accessibility), 스크린샷
- **SFSafariViewController**: Safari 쿠키/세션 공유, Content Blocker, Reader Mode, Safari 확장 지원
- **공통**: URL 테스트, API Capability 감지, 북마크, 반응형 크기 조절

## Quick Reference

```bash
# Build & Run
open wina.xcodeproj && Cmd+R

# Linting (필수)
swiftlint lint && swiftlint --fix

# swift-format (선택적 - SwiftUI 복잡 뷰에서 문제 발생 가능)
swift format format --in-place wina/SomeFile.swift

# Tests
xcodebuild test -project wina.xcodeproj -scheme wina -destination 'platform=iOS Simulator,name=iPhone 16'

# Single test file
xcodebuild test -project wina.xcodeproj -scheme wina -only-testing:winaTests/URLValidatorTests

# SwiftLint Analyzer (unused imports/declarations)
swiftlint analyze --compiler-log-path /tmp/xcodebuild.log

# Check for print() statements (custom SwiftLint rule)
swiftlint lint | grep "no_print_in_production"
```

## Architecture

```
wina/
├── winaApp.swift                        # App entry point
├── ContentView.swift                    # Main view (split into extensions below)
├── ContentView+URLInput.swift           # URL input handling extension
├── ContentViewSheets.swift              # Sheet presentations extension
├── Features/
│   ├── Ad/              # AdManager (Google AdMob interstitial)
│   ├── Accessibility/   # AccessibilityAuditView (axe-core 기반)
│   ├── AppBar/          # OverlayMenuBars (+URLInput extension), 버튼들
│   ├── Settings/        # SettingsView, ConfigurationSettingsView, SafariVCSettingsView
│   ├── Console/         # ConsoleManager + UI (JS console 캡처)
│   ├── Network/         # NetworkManager + UI (fetch/XHR 모니터링 + 리소스 목록 통합)
│   ├── Storage/         # StorageManager + UI (localStorage/sessionStorage/cookies, SWR 패턴)
│   ├── Performance/     # Web Vitals + Navigation Timing
│   ├── Sources/         # DOM Tree, Stylesheets, Scripts (Chrome DevTools 스타일)
│   ├── Resources/       # Network 탭 내부 모듈 (리소스 크기, 타이밍)
│   ├── Info/            # SharedInfoWebView, API Capability 감지, 벤치마크
│   ├── UserAgent/       # UA 커스터마이징
│   ├── WebView/         # WebViewContainer, WebViewNavigator
│   └── About/           # AboutView, StoreManager (IAP)
├── Shared/
│   ├── Components/      # GlassIconButton, GlassActionButton, ChipButton, InfoPopoverButton, SettingToggleRow, DevToolsHeader, FlowLayout, JsonEditor/
│   ├── Constants/       # BarConstants (레이아웃 상수)
│   └── Extensions/      # ColorExtensions, DeviceUtilities, URLValidator
└── Resources/Icons/
```

## Core Patterns

### WebView 인스턴스 관리

```swift
// URL 변경 → 히스토리 유지
navigator.loadURL(urlString)

// Configuration 변경 → 새 인스턴스 (현재 URL 기준)
webViewID = UUID()

// SafariVC → 항상 새 인스턴스 (최초 URL만 가능)
```

### Settings 패턴: Local State → Explicit Apply

```swift
@AppStorage("key") private var storedValue: Bool = false
@State private var localValue: Bool = false

private var hasChanges: Bool { localValue != storedValue }

func loadFromStorage() { localValue = storedValue }
func applyChanges() { storedValue = localValue; webViewID = UUID(); dismiss() }
func resetToDefaults() { localValue = false }  // 저장 X
```

### WebView 크기 초기화 패턴

App preset 계산은 `BarConstants.appContainerHeightRatio(for:)` 사용 (중앙화).

```swift
// ✅ 동적 계산 (기기별 정확한 값)
let heightRatio = BarConstants.appContainerHeightRatio(for: ScreenUtility.screenSize.height)

// ❌ 하드코딩 (특정 기기에만 맞음)
let heightRatio = 0.82
```

**초기화 시점**: `winaApp.init()` 대신 `ContentView.onAppear`에서 실행 (Scene 준비 후 `ScreenUtility.screenSize` 정확함)

### SWR 패턴 (StorageManager)

로딩 인디케이터 없이 기존 데이터 표시 → 백그라운드 갱신 → atomic 업데이트

### DevTools Manager 패턴

`ConsoleManager`, `NetworkManager`, `StorageManager` 모두 `WebViewNavigator`에 포함. JavaScript 인젝션으로 캡처.

### 스크린샷 패턴

WKWebView 전용 (`SFSafariViewController`는 내부 웹뷰 접근 불가).

```swift
// WebViewNavigator에서 스크린샷 + 사진앱 저장
func takeScreenshot() async -> Bool {
    guard let webView else { return false }
    return await withCheckedContinuation { continuation in
        webView.takeSnapshot(with: nil) { image, _ in
            guard let image else { return continuation.resume(returning: false) }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            continuation.resume(returning: true)
        }
    }
}

// 플래시 효과: navigator.showScreenshotFlash 상태로 WebViewContainer에서 오버레이 표시
// 사운드: AudioServicesPlaySystemSound(1108) - 시스템 카메라 셔터
```

**권한**: `Info.plist`에 `NSPhotoLibraryAddUsageDescription` 필요

### JavaScript 문자열 Escape

Swift → JavaScript 문자열 전달 시 `JSONSerialization` 사용 (newline, 따옴표 등 자동 escape)

```swift
// ❌ 특수문자 깨짐
let script = "storage.setItem('\(key)', '\(value)');"

// ✅ JSONSerialization으로 안전하게 escape
guard let keyData = try? JSONSerialization.data(withJSONObject: key),
      let valueData = try? JSONSerialization.data(withJSONObject: value),
      let jsonKey = String(data: keyData, encoding: .utf8),
      let jsonValue = String(data: valueData, encoding: .utf8)
else { return }
let script = "storage.setItem(\(jsonKey), \(jsonValue));"  // 따옴표 포함됨
```

### Tree View Expand/Collapse

UUID 대신 경로 기반 stable ID 사용 (렌더링마다 새 UUID 생성되면 상태 유실)

```swift
// ❌ 매번 새 ID → expand 상태 유실
struct Node: Identifiable {
    let id = UUID()  // 렌더링마다 새로 생성
}

// ✅ 경로 기반 stable ID
struct Node: Identifiable {
    let path: [String]
    var id: String { path.joined(separator: ".") }
}
```

### StoreKit 2 IAP 패턴 (StoreManager)

싱글톤 기반, 앱 시작 시 자동 초기화. Best practices 준수.

```swift
// winaApp.swift에서 초기화
_ = StoreManager.shared

// StoreManager 핵심 구조
@Observable
final class StoreManager {
    static let shared = StoreManager()

    private init() {
        updateListenerTask = listenForTransactions()  // 환불/백그라운드 구매 감지
        Task {
            await processUnfinishedTransactions()     // 앱 종료 중 완료된 구매
            await checkEntitlements()                 // 현재 구매 상태
        }
    }
}
```

**필수 체크리스트:**
- ✅ `Transaction.updates` 리스너 (앱 시작 즉시)
- ✅ `Transaction.unfinished` 처리 (중단된 구매)
- ✅ `transaction.finish()` 항상 호출
- ✅ `revocationDate` 체크 (환불 처리)
- ✅ `Task.detached` 백그라운드 실행

### Theme/ColorScheme 패턴

시스템 기본 → 사용자 선택 시 Light↔Dark 토글

```swift
// winaApp.swift
@AppStorage("colorSchemeOverride") private var colorSchemeOverride: String?
// nil = system, "light" = light mode, "dark" = dark mode

.preferredColorScheme(preferredScheme)  // nil이면 시스템 따름

// ThemeToggleButton.swift
@Environment(\.colorScheme) private var systemColorScheme

// 버튼 탭 시: 현재 effective scheme의 반대로 설정 (시스템 모드 해제)
colorSchemeOverride = isDark ? "light" : "dark"
```

### BarConstants (중앙 집중 레이아웃 상수)

```swift
// Shared/Constants/BarConstants.swift
enum BarConstants {
    static let barHeight: CGFloat = 64           // 상단/하단 바 높이
    static let horizontalPadding: CGFloat = 8    // 바 좌우 패딩
    static let bottomBarSafeAreaRatio: CGFloat = 0.5  // 하단 바가 safe area로 들어가는 비율
    static let webViewOffsetRatio: CGFloat = 0.375    // WebView 수직 오프셋 비율
    static let additionalSpacing: CGFloat = 64        // "App" 프리셋용 추가 여백
    static var totalUIHeight: CGFloat { barHeight * 2 + additionalSpacing }
}
```

### Sheet Modifier 패턴

두 가지 sheet 스타일 제공 (`Shared/Extensions/SheetModifiers.swift`):

| Modifier | 용도 | 동작 |
|----------|------|------|
| `.devToolsSheet()` | DevTools (Console, Network, Storage, Performance, Sources) | detent 선택 가능 (35%, medium, large), iPad는 `.form` sizing |
| `.fullSizeSheet()` | Settings, Info | 항상 large, `.page` sizing (iOS/iPad 동일) |

```swift
// DevTools - 리사이즈 가능한 sheet
.sheet(isPresented: $showConsole) {
    ConsoleView(...)
        .devToolsSheet()
}

// Settings/Info - 항상 풀사이즈
.sheet(isPresented: $showSettings) {
    SettingsView(...)
        .fullSizeSheet()
}
```

**iPad 지원**:
- `devToolsSheet()`: `.presentationSizing(.form)` + iPad 기본 `.large` detent
- `fullSizeSheet()`: `.presentationSizing(.page)` 항상 풀스크린

### AdManager 광고 패턴

확률 기반 interstitial 광고. 세션당 id별 1회 표시.

```swift
// 기본 30% 확률
await AdManager.shared.showInterstitialAd(
    options: AdOptions(id: "feature_name"),
    adUnitId: AdManager.interstitialAdUnitId
)

// 커스텀 확률 (50%)
AdOptions(id: "feature_name", probability: 0.5)
```

**체크 순서**:
1. `isAdRemoved` (IAP 구매) → true면 skip
2. `shownAdIds` (세션 내 이미 표시) → skip
3. 확률 체크 (기본 30%) → 실패 시 skip
4. 광고 로드 및 표시

**광고 위치**: Info/Settings sheet, DevTools (Console/Network/Storage/Performance/Sources/Accessibility), Screenshot

### CSS Property Override 표시 (Sources DevTools)

JavaScript에서 specificity + !important 기반으로 override 계산:

```swift
// CSSProperty struct with override tracking
struct CSSProperty: Identifiable {
    let property: String
    let value: String
    let isImportant: Bool   // !important flag (score +10000)
    var isOverridden: Bool  // Overridden by higher specificity rule
}

// UI에서 취소선 + opacity 적용
FormattedCSSPropertyRow(property: prop.property, value: prop.value, isOverridden: prop.isOverridden)
    .strikethrough(isOverridden, color: .secondary)
    .opacity(isOverridden ? 0.6 : 1.0)
```

### Runestone (Sources Raw HTML View)

대용량 HTML 표시 시 Runestone + Tree-sitter 사용 (virtualization + syntax highlighting)

```swift
import Runestone
import TreeSitterHTMLRunestone

// TextView with HTML syntax highlighting
let state = TextViewState(text: html, theme: HTMLViewerTheme(), language: .html)
textView.setState(state)

// Built-in search support
let query = SearchQuery(text: searchText, matchMethod: .contains, isCaseSensitive: false)
let results = textView.search(for: query)
```

**장점**: LazyVStack 대비 양방향 스크롤 + 텍스트 선택 + 메모리 효율 (virtualization)

---

## ⚠️ 실수하기 쉬운 패턴

### 1. `.buttonStyle(.plain)` 터치 영역 문제

`.plain` 스타일은 **아이콘 픽셀만** 터치 가능 (frame 무시됨)

```swift
// ❌ 터치 안 됨
Button { } label: {
    Image(systemName: "xmark")
        .frame(width: 44, height: 44)
}
.buttonStyle(.plain)

// ✅ 해결
Button { } label: {
    Image(systemName: "xmark")
        .frame(width: 44, height: 44)
        .contentShape(Circle())  // 필수!
}
.buttonStyle(.plain)
```

### 2. 컴파일러 타입 체크 실패

복잡한 뷰 표현식 → "unable to type-check" 에러

```swift
// ❌ body에 복잡한 중첩
var body: some View {
    VStack { /* ForEach, overlay, 조건문... */ }
}

// ✅ 분리
var body: some View { VStack { complexPart } }

@ViewBuilder
private var complexPart: some View { /* ... */ }
```

### 3. ZStack Overlay 터치 가로채기

VStack + Spacer는 화면 전체 터치를 가로챔

```swift
// ❌ Spacer가 터치 가로챔
VStack { HStack { buttons }; Spacer() }

// ✅ frame으로 정렬
HStack { buttons }
    .frame(maxHeight: .infinity, alignment: .top)
```

### 4. WebView 위 제스처 우선순위

```swift
// ❌ WebView 스크롤이 우선
.gesture(dragGesture)

// ✅ 오버레이 제스처 우선
.highPriorityGesture(isOverlayMode ? dragGesture : nil)
```

### 5. Dropdown 위치 (alignmentGuide + zIndex)

```swift
// ✅ input 아래에 dropdown 배치
urlInputField
    .overlay(alignment: .bottom) {
        dropdown.alignmentGuide(.bottom) { $0[.top] }
    }
    .zIndex(1)  // sibling 위에 표시
```

### 6. Color.clear 터치 영역

```swift
// ❌ 터치 영역 없음
Color.clear.onTapGesture { }

// ✅ 터치 영역 명시
Color.clear.contentShape(Rectangle()).onTapGesture { }
```

### 7. Safe Area 하드코딩

```swift
// ❌ 기기별로 다름
.padding(.bottom, -20)

// ✅ 동적 계산
GeometryReader { geo in
    view.padding(.bottom, -(geo.safeAreaInsets.bottom * 0.6))
}
```

### 8. iOS 26 Deprecated API

```swift
// ❌ Deprecated
UIScreen.main.bounds

// ✅ iOS 26+
ScreenUtility.screenSize  // DeviceUtilities.swift
UIDevice.current.isIPad   // Extension
```

### 9. @Observable vs ObservableObject

`@Observable` 매크로는 `objectWillChange` 퍼블리셔가 없음

```swift
// ❌ @Observable에서 사용 불가
.onReceive(navigator?.objectWillChange ?? Empty().eraseToAnyPublisher())

// ✅ 특정 프로퍼티 관찰
.onChange(of: navigator?.currentURL) { _, newURL in ... }
```

### 10. 확장/축소 리스트 Layout Shift

```swift
// ❌ VStack 기본 spacing + 조건부 렌더링 (layout shift)
VStack(spacing: 4) {
    Button { withAnimation { isExpanded.toggle() } } ...
    if isExpanded { content }
}

// ✅ spacing: 0 + 컨테이너 애니메이션 + chevron 회전
VStack(spacing: 0) {
    HStack {
        Image(systemName: "chevron.right")
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
        Text(title)
    }
    if isExpanded {
        content
            .padding(.bottom, 8)
            .fixedSize(horizontal: false, vertical: true)
    }
}
.animation(.easeOut(duration: 0.15), value: isExpanded)
```

**핵심**: `spacing: 0` + 명시적 padding (VStack 기본 spacing이 콘텐츠에 따라 변함)

### 11. @Observable 배열 요소 업데이트

배열 내 struct 속성 개별 수정 시 뷰 갱신 안 됨

```swift
// ❌ 개별 속성 수정 - 뷰 갱신 안 됨
requests[index].status = 200
requests[index].endTime = Date()

// ✅ 전체 struct 교체 - 뷰 갱신 됨
var updated = requests[index]
updated.status = 200
updated.endTime = Date()
requests[index] = updated
```

### 12. UIViewRepresentable 높이 계산 (iOS 16+)

UITextView 등 intrinsic size 계산이 필요한 뷰는 `sizeThatFits` 구현

```swift
// ✅ iOS 16+ sizeThatFits로 정확한 높이 계산
func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width > 0 else { return nil }
    let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: size.height)
}
```

```swift
// ❌ 커스텀 구현 (layout shift)
Button { isExpanded.toggle() } label: { ... }
if isExpanded { content }

// ✅ DisclosureGroup (네이티브 애니메이션)
DisclosureGroup(isExpanded: $isExpanded) {
    content
} label: {
    labelView
}
```

### 13. Equatable에서 id만 비교 시 뷰 갱신 안 됨

변경되는 속성이 있는 struct는 Equatable에 해당 속성 포함 필수

```swift
// ❌ id만 비교 - 속성 변경 감지 못함
static func == (lhs: Request, rhs: Request) -> Bool {
    lhs.id == rhs.id
}

// ✅ 변경되는 속성도 비교
static func == (lhs: Request, rhs: Request) -> Bool {
    lhs.id == rhs.id &&
    lhs.status == rhs.status &&
    lhs.endTime == rhs.endTime
}
```

### 14. 조건부 뷰 간 Layout Shift (Sheet에서 특히 중요)

emptyState와 contentList 간 전환 시 레이아웃 동작이 다르면 header가 밀리는 등 layout shift 발생

```swift
// ❌ VStack + Spacer는 ScrollView와 다른 레이아웃 동작
var emptyState: some View {
    VStack {
        Spacer()
        Text("No data")
        Spacer()
    }
}

// ✅ ScrollView로 감싸서 동일한 레이아웃 동작 보장
var emptyState: some View {
    GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Image(systemName: "tray")
                Text("No data")
                Spacer(minLength: 0)
            }
            .frame(width: geometry.size.width)
            .frame(minHeight: geometry.size.height)
        }
    }
    .background(Color(uiColor: .systemBackground))
}
```

**핵심**: `Spacer(minLength: 0)` + `minHeight`로 중앙 정렬, ScrollView로 contentList와 동일한 레이아웃 동작

### 15. Sheet 내부 스크롤 우선순위

Sheet 내부에 ScrollView가 있을 때, sheet resize 제스처가 스크롤보다 우선됨

```swift
// ❌ sheet resize가 스크롤보다 우선 (리스트 스크롤 안 됨)
.sheet(item: $item) {
    ScrollView { content }
        .presentationDetents([.medium, .large])
}

// ✅ 스크롤이 sheet resize보다 우선
.sheet(item: $item) {
    ScrollView { content }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
}
```

### 16. JSONSerialization String 크래시

`JSONSerialization.data(withJSONObject:)`는 top-level이 Array/Dictionary여야 함

```swift
// ❌ String을 직접 넣으면 크래시
JSONSerialization.data(withJSONObject: "string")

// ✅ fragmentsAllowed 옵션 필요
JSONSerialization.data(withJSONObject: "string", options: .fragmentsAllowed)
```

### 17. Color.secondary/tertiary는 Color가 아님

`Color.secondary`, `Color.tertiary`는 `some ShapeStyle`을 반환, `Color` 타입 필요 시 사용 불가

```swift
// ❌ Color 타입 반환해야 하는 곳에서 컴파일 에러
var color: Color {
    case .string: return .secondary  // ShapeStyle 반환
    case .empty: return .tertiary    // ShapeStyle 반환
}

// ✅ 명시적 Color 사용
var color: Color {
    case .string: return .gray
    case .empty: return .gray.opacity(0.5)
}
```

**참고**: `.foregroundStyle(.secondary)` 처럼 ShapeStyle 받는 곳에서는 OK

### 18. LazyVStack 양방향 스크롤 + 텍스트 선택 불가

`LazyVStack`은 수직 virtualization만 지원, 좌우 스크롤과 텍스트 드래그 선택 동시 불가

```swift
// ❌ LazyVStack - 수평 스크롤 안 됨, 중앙 정렬 문제
ScrollView([.horizontal, .vertical]) {
    LazyVStack { ForEach(lines) { Text($0) } }
}

// ❌ LazyVStack + fixedSize - 여전히 수평 스크롤 안 됨
LazyVStack {
    Text(line).fixedSize(horizontal: true, vertical: false)
}

// ✅ UIScrollView + UITextView 조합 (양방향 스크롤 + 텍스트 선택)
struct HTMLTextView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true  // 드래그 선택 가능
        textView.isScrollEnabled = false  // 외부 스크롤뷰 사용
        textView.textContainer.widthTracksTextView = false  // 수평 확장
        textView.textContainer.size.width = .greatestFiniteMagnitude
        scrollView.addSubview(textView)
        return scrollView
    }
}
```

**주의**: UITextView는 virtualization 없음 (메모리에 전체 텍스트 로드). 대용량 시 maxLines 제한 필수.

**핵심**: 양방향 스크롤 + 텍스트 선택 필요 시 → UIScrollView + UITextView 조합, 10000줄 이상은 제한

### 19. JavaScript → Swift 파싱 시 타입 주의

```swift
// ❌ [String: String]으로 파싱 - Bool 필드 누락
let propsArray = item["properties"] as? [[String: String]] ?? []

// ✅ [String: Any]로 파싱 - Bool, Int 등 다양한 타입 지원
let propsArray = item["properties"] as? [[String: Any]] ?? []
let isImportant = propDict["i"] as? Bool ?? false
let specificity = propDict["specificity"] as? Int ?? 0
```

---

## Design System

**Liquid Glass UI** (iOS 26)

```swift
.glassEffect()                            // 기본
.glassEffect(in: .capsule)                // 캡슐
.glassEffect(in: .circle)                 // 원형
.glassEffect(in: .rect(cornerRadius: 16)) // 라운드
```

**원칙**: `.glassEffect()` 사용 (Material X), 시스템 배경 유지, `.primary`/`.secondary` 색상 활용

## 공유 컴포넌트 (Shared/Components/)

| 용도 | 컴포넌트 |
|------|----------|
| 원형 아이콘 버튼 | `GlassIconButton` (.regular 44×44, .small 28×28) |
| 액션 버튼 | `GlassActionButton` (.default, .destructive, .primary) |
| 헤더 액션 버튼 | `HeaderActionButton` (capsule, section header용) |
| 복사 버튼 | `CopyButton` (header), `CopyIconButton` (icon only), `CopiedFeedbackToast` |
| 타입 배지 | `TypeBadge` (text + color + icon) |
| 칩/태그 | `ChipButton`, `ToggleChipButton` (toggle state) |
| info 버튼 | `InfoPopoverButton` (Generic ShapeStyle) |
| deprecated 경고 | `DeprecatedPopoverButton` |
| 보안 제한 배너 | `SecurityRestrictionBanner` (crossOriginTiming, crossOriginStylesheet, staticResourceBody) |
| 설정 토글 | `SettingToggleRow` |
| 색상 선택 | `ColorPickerRow` (deprecatedInfo 파라미터) |
| 자동 줄바꿈 | `FlowLayout` |
| DevTools 헤더 | `DevToolsHeader` |
| WebView 크기 조절 | `WebViewSizeControl` |

### DevToolsHeader 레이아웃

2행 구조로 버튼이 많아도 제목이 밀리지 않음:

```
        [Title]              ← Row 1: 중앙 정렬
[Left Buttons] ⟷ [Right Buttons]  ← Row 2: 좌우 분리
```

**버튼 배치 규칙**:
- Left: Close (xmark.circle.fill) → Actions (trash, share)
- Right: Toggles (play/pause, settings)

**사용 뷰**: Console, Network, Storage, Performance, Sources (모두 동일 패턴)

### 금지 사항

- ❌ info 버튼 직접 구현 → `InfoPopoverButton` 사용
- ❌ `UIDevice.userInterfaceIdiom` → `UIDevice.current.isIPad`
- ❌ `UIScreen.main.bounds` → `ScreenUtility.screenSize`
- ❌ 유사 기능에 새 컴포넌트 생성 → 기존 확장

---

## Code Conventions

| 대상 | 컨벤션 |
|------|--------|
| 파일명, 타입 | PascalCase |
| 변수, 함수 | camelCase |
| 에셋 | kebab-case |
| 테스트 파일 | `winaTests/[Feature]Tests.swift` |

- **Logging**: `os_log` 또는 `Logger` 사용 (`print()` 금지 - SwiftLint 규칙)
- 1파일 1컴포넌트, 150줄 이하 권장
- Feature 전용 helper는 같은 파일에 `private`
- Extension으로 프로토콜 준수 분리
- `// MARK: -` 로 섹션 구분

---

## Swift 성능 핵심

- **메모리**: `[weak self]` 클로저, `deinit`에서 observers 제거
- **Value Types**: `struct` > `class` (단순 모델)
- **Lazy**: `lazy var`로 지연 초기화
- **컬렉션**: Array(정렬), Dictionary(조회), Set(중복제거) 적절히 선택
- **SwiftUI**: `@State` 범위 최소화, 1000+ 항목은 `LazyVStack`
- ❌ Reflection, 강제 언래핑(`!`), 동기 네트워크

---

## WKWebView 주의사항

### Info.plist 권한 필요 API

```
NSCameraUsageDescription             # Media Devices, WebRTC
NSMicrophoneUsageDescription         # Media Devices, WebRTC
NSLocationWhenInUseUsageDescription  # Geolocation
NSUserTrackingUsageDescription       # ATT (AdMob 개인화 광고)
NSPhotoLibraryAddUsageDescription    # 스크린샷 저장
```

### WKWebView에서 항상 미지원

- Service Workers, Web Push (Safari/PWA 전용)
- Vibration, Battery, Bluetooth, USB, NFC (WebKit 정책)

### CORS 제한 (외부 스크립트/리소스)

WKWebView는 CORS 정책을 강제 적용. 외부 스크립트 콘텐츠 fetch 불가.

```swift
// ❌ 외부 스크립트 fetch 시도 → CORS 에러
navigator.evaluateJavaScript("fetch('https://cdn.example.com/app.js')")

// ✅ inline 스크립트만 접근 가능
navigator.evaluateJavaScript("document.scripts[0].textContent")
```

**DevTools Sources 탭**: 외부 스크립트는 URL/메타데이터만 표시, 콘텐츠 조회 불가 안내

### Resource Timing API 제한

Cross-origin 리소스(외부 CDN 이미지, 폰트 등)는 보안상 크기 정보 0B 반환

```javascript
// transferSize, encodedBodySize, decodedBodySize 모두 0
// 서버에서 Timing-Allow-Origin 헤더 필요 (우회 불가)
```

**displaySize fallback 패턴**: `transferSize` → `encodedBodySize` → `decodedBodySize`

### 벤치마크 주의

- JavaScript는 **동기 실행 필수** (async/await → "unsupported type" 에러)
- Canvas/WebGL은 `document.createElement`로 동적 생성

---

## 프로젝트 구조 원칙

1. Entry Point (`winaApp.swift`, `ContentView.swift`)는 루트에
2. Feature 기반 그룹화 (`Features/[Name]/`)
3. Shared는 2개+ 사용 시에만 (Rule of Three)
4. Xcode 그룹 = 파일 시스템 구조

**금지**: `Utilities/`, `Helpers/` 같은 모호한 폴더, 빈 폴더, 깊은 중첩 (최대 3단계)

---

## Image Conversion

```bash
# ✅ SVG → PNG (색상 정확)
rsvg-convert -w 1024 -h 1024 input.svg -o output.png

# ❌ ImageMagick (색상 왜곡)
magick input.svg output.png
```

---

## App Store 배포

### 빌드 및 업로드

```bash
# Archive
xcodebuild -project wina.xcodeproj -scheme wina -configuration Release \
  -archivePath /tmp/wina.xcarchive archive -destination 'generic/platform=iOS'

# App Store Connect 업로드 (API Key 사용)
xcodebuild -exportArchive -archivePath /tmp/wina.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/export \
  -authenticationKeyPath /path/to/AuthKey.p8 \
  -authenticationKeyID <KEY_ID> \
  -authenticationKeyIssuerID <ISSUER_ID> \
  -allowProvisioningUpdates
```

### ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>X6M5USK89L</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

### 앱 아이콘 요구사항

- ❌ **Alpha channel 금지** (App Store 거부됨)
- 확인: `sips -g hasAlpha wina/Assets.xcassets/AppIcon.appiconset/app-icon-1024.png`
- 제거: `magick input.png -background white -alpha remove -alpha off output.png`

### Export Compliance

`ITSAppUsesNonExemptEncryption = NO` 설정됨 → 수출 규정 질문 자동 스킵 (HTTPS만 사용, 자체 암호화 없음)
