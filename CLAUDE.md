# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wallnut (wina)** - WKWebView & SFSafariViewController 테스터 앱

WKWebView와 SFSafariViewController 설정을 실시간 테스트하는 개발자 도구. SwiftUI 기반, iOS 26.1+ (Tahoe)

**주요 기능**:
- **WKWebView**: 설정 옵션 테스트, DevTools (Console/Network/Storage/Performance/Sources/Accessibility), 스크린샷
- **SFSafariViewController**: Safari 쿠키/세션 공유, Content Blocker, Reader Mode, Safari 확장 지원
- **공통**: URL 테스트, API Capability 감지, 북마크, 반응형 크기 조절

**Recent Focus** (as of Dec 2024):
- Console %c CSS styling (color, background-color, font-weight, font-size)
- Network tab improvements (fetch/XHR consolidation, cross-origin filtering)
- Array chunking for large console outputs (100+ items)

## Quick Reference

### Build & Run
```bash
# Build and run in simulator
open wina.xcodeproj && Cmd+R

# Run on specific device
xcodebuild -project wina.xcodeproj -scheme wina -destination 'platform=iOS,name=iPhone 16,OS=latest'
```

### Code Quality

**Pre-commit checklist**:
```bash
# Lint + auto-fix (required before commit)
swiftlint lint --fix && swiftlint lint

# Optional: Format (avoid with complex SwiftUI views - can cause regressions)
swift format format --in-place wina/SomeFile.swift

# Analyze for unused code (run separately)
xcodebuild clean -project wina.xcodeproj
xcodebuild -project wina.xcodeproj -scheme wina -destination generic/platform=iOS -c Debug -c Analyze analyze

# Check for print() statements (must all be removed)
swiftlint lint | grep "no_print_in_production"
```

**Workflow**:
1. Make changes
2. Run `swiftlint lint --fix` (auto-fixes most issues)
3. Run `swiftlint lint` again (verify all passed)
4. Commit with message in conventional format
5. **DO NOT** push unless user explicitly asks

### Testing
```bash
# Run all tests
xcodebuild test -project wina.xcodeproj -scheme wina -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test file
xcodebuild test -project wina.xcodeproj -scheme wina -only-testing:winaTests/URLValidatorTests

# Run tests with coverage
xcodebuild test -project wina.xcodeproj -scheme wina -enableCodeCoverage YES
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
│   ├── Settings/        # SettingsView, ConfigurationSettingsView, SafariVCSettingsView, EmulationSettingsView
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

### DevTools Manager 패턴 & JavaScript Bridge Architecture

**Core Architecture**:
- All DevTools managers (`ConsoleManager`, `NetworkManager`, `StorageManager`) are owned by `WebViewNavigator`
- Data flows: JavaScript hooks (injected) → message handlers → native managers → UI bindings (@Observable)
- Each manager follows `@Observable` macro pattern (iOS 17+) for reactive updates

**Communication Flow**:
1. JavaScript hook injects code via `evaluateJavaScript()`
2. Message handler catches event via `WKScriptMessageHandler` protocol
3. Manager processes and stores data (atomic updates only)
4. UI observes changes and re-renders

**Key Files** (WebViewScripts series):
- `WebViewScripts.swift` - Base hook injection (setup)
- `WebViewScripts+Console.swift` - console.log, console.dir, console.time handlers
- `WebViewScripts+Network.swift` - fetch/XHR interception + resource timing
- `WebViewScripts+Emulation.swift` - User agent, viewport emulation
- `WebViewScripts+Resource.swift` - Static resource tracking

**Important**: Do NOT use `print()` statements in managers. Use `os_log` or `Logger` instead (SwiftLint enforces this).

### Console Method Implementations (JavaScript 훅)

**WebViewScripts+Console.swift**에서 다양한 console 메서드를 JavaScript hook으로 캡처하여 native로 전달.

#### console.dir() - 객체 검사

```javascript
// 첫 번째 인자를 JSON으로 직렬화하여 objectJSON 필드에 포함
console.dir({name: "John", age: 30})
→ type: "dir", objectJSON: "{\"name\":\"John\",\"age\":30}"
```

**UI 렌더링**: ConsoleValueView에서 `ConsoleValue.object()` tree로 확장 가능하게 표시 (색상 포함)

#### console.time/timeLog/timeEnd() - 성능 타이밍

```javascript
// 타이머 객체 유지, performance.now()로 정확한 측정
console.time("fetch");  // 시작 (밀리초 저장)
...
console.timeLog("fetch");  // "fetch: 123.456ms" (중단 없음)
...
console.timeEnd("fetch");  // "fetch: 456.789ms" (타이머 삭제)
```

**주의사항**:
- `timeLog()` 호출 시에도 타이머는 유지됨 (timeEnd()만 삭제)
- 존재하지 않는 타이머 참조 시 "Timer 'label' does not exist" 에러 메시지 표시
- 밀리초는 3자리 소수점으로 표시 (`.toFixed(3)`)

**Message Handler**: `WebViewContainer.handleConsoleMessage()` - `type: "time" | "timeLog" | "timeEnd"` 모두 처리

#### console %c Styling - CSS 색상 및 포매팅

```javascript
// %c = format specifier, 뒤따르는 문자열 = CSS 스타일
console.log("%cError", "color: red; font-weight: bold");
console.log("%cSuccess%cDetailed", "color: green", "color: gray");
```

**Supported CSS Properties** (WebViewScripts+Console.swift:76):
- `color: <color-name | hex>` - 텍스트 색상 (e.g., "red", "#FF0000")
- `background-color: <color>` - 배경 색상
- `font-weight: bold` - 굵은 텍스트
- `font-size: <number>px` - 글씨 크기

**Implementation** (WebViewScripts+Console.swift line 476):
1. `formatConsoleMessage()` 함수가 %c 감지
2. CSS 문자열을 `parseCSS()` 함수로 파싱 → {color, backgroundColor, isBold, fontSize} 객체로 변환
3. 텍스트와 CSS를 짝으로 묶어 `styledSegments` 필드에 JSON 직렬화
4. `ConsoleValueView`에서 `formattedText(for:)` 확장으로 UI 렌더링 (색상 + 스타일 적용)

**UI Rendering** (ConsoleValueView.swift):
```swift
// 색상: native Color로 변환
// 스타일: SwiftUI 수정자로 적용 (.bold(), .font(.system(size:)))
```

**주의사항**: 복합 색상값(rgb, rgba, hsl) 미지원 (named colors 또는 hex만 가능)

### ConsoleView 필터링 - Info 레벨 추가

**필터 탭 구조** (탭 순서):
1. **All** - 모든 로그 표시
2. **Errors** (빨강) - error 타입만
3. **Warnings** (주황) - warn 타입만
4. **Info** (파랑) - info 타입만 ← **신규**
5. **Log** (기본색) - log 타입만
6. **Debug** (기회색) - debug 타입만

```swift
// ConsoleManager에 infoCount 추가
var infoCount: Int { logs.filter { $0.type == .info }.count }

// ConsoleView에서 Info 필터 탭 생성
FilterTab(label: "Info", count: consoleManager.infoCount, isSelected: filterType == .info, color: .blue) {
    filterType = .info
}
```

**이점**: Eruda와 동일한 필터 구조로 기능 parity 달성

### Network Tab 아키텍처

**Recent Changes**:
- Fetch + XHR 필터 통합 → 단일 "XHR" 탭 (fetch는 XHR로 캡처됨)
- Cross-origin 리소스 도메인 기반 필터링
- Resource timing 정확성 개선

**NetworkManager 데이터 구조**:
```swift
struct NetworkRequest: Identifiable {
    let id: UUID
    let method: String           // GET, POST, etc
    let url: String
    let status: Int?             // nil = pending
    let duration: Double?        // milliseconds
    let resourceType: String     // xhr, fetch, image, stylesheet, etc
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
    let requestBody: String?
    let responseBody: String?
    let initiator: String?       // script file:line that initiated request
}
```

**Domain Filtering Pattern** (NetworkView.swift):
```swift
// 쿠키 필터링 예시
let allDomains = Set(storageManager.domainCookies.keys).sorted()
let filteredCookies = selectedDomain == "All"
    ? storageManager.domainCookies.values.flatMap { $0 }
    : storageManager.domainCookies[selectedDomain] ?? []
```

**Important**: Network tab는 "Preserve Log" 체크박스로 제어됨 (Settings or 내부 toggle)

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

두 가지 광고 타입: **Interstitial** (전체화면, 확률 기반) + **Banner** (하단, 항상 표시)

#### Interstitial 광고 (세션당 id별 1회)

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

**Interstitial 위치**: Info/Settings sheet, DevTools (Console/Network/Storage/Performance/Sources/Accessibility), Screenshot

#### Banner 광고 (하단 고정, 비프리미엄)

```swift
// ContentView 하단에 조건부 표시
if !StoreManager.shared.isAdRemoved {
    BannerAdView()
        .frame(height: 50)
}
```

**동작**:
- 비프리미엄 사용자만 표시 (프리미엄은 숨김)
- URL 입력 시 자동으로 로드 (초기 URL 로드 최적화)
- SafariVC 모드에서도 표시

### Eruda 모드 (in-page 콘솔)

WKWebView 전용 제3자 디버깅 도구. DevTools와 병행 가능.

```swift
// SettingsView에서 활성화
@AppStorage("erudaModeEnabled") var erudaModeEnabled = false

// WebViewContainer에서 로드
if erudaModeEnabled {
    // 에르다 스크립트 주입
    let erudaScript = "..."  // eruda/package.json에서 빌드된 번들
    webView.evaluateJavaScript(erudaScript)
}
```

**특징**:
- ✅ 기본 비활성화 (UX 개선)
- ✅ 사용자가 원할 때 Settings에서 활성화
- ✅ 폐쇄 시 오버레이 상태 유지 (재오픈 빠름)
- ✅ DevTools와 중복되지 않게 배치

**활성화 UI**:
```
Settings → "Eruda Mode" 토글 on → WebView 새로고침 → 오른쪽 하단에 에르다 아이콘
```

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
- **Large Array 렌더링**: ConsoleArray에서 100+ 항목을 100개씩 청크로 분할, 모두 collapsed 상태로 시작 (사용자가 개별 청크 expand 가능)
- ❌ Reflection, 강제 언래핑(`!`), 동기 네트워크

### Array Chunking Pattern (콘솔 큰 배열 처리)

**문제**: console.log([1,2,3,...10000]) 시 10,000개 모두 렌더링 → UI 프리징

**해결책**: ConsoleArray 모델에서 자동으로 청크 계산

```swift
// ConsoleArray.swift - 청크 계산 (100개 단위)
struct ConsoleArray: Equatable {
    let elements: [ConsoleValue]
    let chunkSize: Int = 100

    var chunks: [(range: Range<Int>, label: String, elements: [ConsoleValue])]? {
        guard elements.count > chunkSize else { return nil }

        var result: [(range: Range<Int>, label: String, elements: [ConsoleValue])] = []
        var index = 0
        while index < elements.count {
            let endIndex = min(index + chunkSize, elements.count)
            let range = index..<endIndex
            let chunkElements = Array(elements[range])
            let label = "[​\(index)..​\(endIndex - 1)]"  // Zero-width space
            result.append((range: range, label: label, elements: chunkElements))
            index = endIndex
        }
        return result
    }
}
```

**UI 렌더링** (ConsoleValueView.swift):

```swift
// 큰 배열: 먼저 preview 라인 표시, 그 다음 collapsed 청크들
if let chunks = arr.chunks {
    // 1. Preview: (10000) [0, 1, 2, 3, ...]
    HStack { Text("(\(arr.elements.count))"); Text(arrayPreview(...)) }

    // 2. Chunks: 모두 collapsed 상태로 시작
    ForEach(Array(chunks.enumerated()), id: \.element.label) { chunkIndex, chunk in
        ArrayChunkView(chunk: chunk)  // @State private var isExpanded = false (기본값!)
    }
}
```

**핵심 규칙**:
- ✅ Preview 라인으로 배열 크기와 샘플 아이템 먼저 표시
- ✅ 모든 청크 기본값: collapsed (`isExpanded: Bool = false`)
- ✅ 사용자가 필요한 청크만 expand → 메모리 효율적
- ✅ 100개 이하 배열은 청크 미사용 (모두 표시)

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

---

## 개발 팁 & 트러블슈팅

### Xcode 빌드 실패

**Problem**: `Unable to boot simulator` 또는 시뮬레이터 인식 실패
```bash
# 해결
xcrun simctl erase all         # 모든 시뮬레이터 초기화
xcrun simctl list devices      # 시뮬레이터 목록 확인
killall "Simulator"            # 시뮬레이터 강제 종료
```

**Problem**: `Swift.Runtime error: SIGABRT` 또는 런타임 크래시
```bash
# 1. Derived Data 삭제
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 2. Build folder 삭제
xcodebuild clean -project wina.xcodeproj

# 3. 재빌드
open wina.xcodeproj && Cmd+R
```

### SwiftLint 이슈

**Problem**: `unable to read file` 에러
```bash
# SwiftLint 재설치
brew uninstall swiftlint && brew install swiftlint
```

**Problem**: 자동 수정 후에도 실패
```bash
# 스타일 자동 수정 + 다시 린트
swiftlint lint --fix && swiftlint lint
```

### WebView 디버깅

**Problem**: JavaScript 주입 실패 (CORS 에러)
- ✅ Inline 스크립트만 평가 가능
- ❌ 외부 URL에서 fetch 불가 (WKWebView 정책)
- 해결: `evaluateJavaScript()` 사용, 외부 리소스는 웹페이지에 맡기기

**Problem**: 이전 세션 데이터가 남음
```swift
// Settings에서 "Clean Start" 체크 → WebView 새로 생성
// 또는 수동으로:
defaults delete com.wallnut.wina  // AppStorage 초기화
```

### 네트워크 모니터링 안 됨

**Cause**: `preserveLog` 비활성화 또는 WebView 새로고침
- 해결: Settings → "Preserve Network Log" 활성화
- 또는: Console/Network 탭 열어둔 상태에서 URL 로드

### 성능 문제

**Slow Rendering**: 뷰 복잡도 확인
```bash
# Xcode Debug View Hierarchy (Cmd+Shift+Y) 사용
# LazyVStack으로 자동 렌더링 (1000+ 항목)
```

**High Memory**: DevTools 자주 열기
```swift
// NetworkManager/StorageManager 캐시 정리
networkManager.clearCache()
storageManager.clearCache()
```

---

## 버전 호환성

| 도구 | 버전 | 필수 여부 |
|------|------|---------|
| Xcode | 16.1+ | ✅ 필수 |
| iOS Target | 26.1 (Tahoe)+ | ✅ 필수 |
| SwiftLint | 0.62.2+ | ✅ 필수 (pre-commit) |
| swift-format | 6.2.1+ | 🟡 선택 (복잡한 뷰 제외) |
| Google Mobile Ads SDK | 11.0+ | ✅ 필수 (광고) |
| Runestone | (최신) | ✅ 필수 (Sources 뷰) |

---

## 개발 팁: DevTools 디버깅

### Console 테스트 패턴

```html
<!-- Test file: simple-console-test.html -->
<script>
// 기본 로깅
console.log("plain text");
console.warn("warning");
console.error("error");

// 색상 스타일링 (%c)
console.log("%cInfo", "color: blue");
console.log("%cError%cDetails", "color: red; font-weight: bold", "color: gray");

// 객체 검사
console.dir({name: "John", age: 30, nested: {x: 1}});

// 성능 타이밍
console.time("fetch");
console.timeLog("fetch");
console.timeEnd("fetch");

// 대량 배열 (청크 테스트)
console.log(Array.from({length: 10000}, (_, i) => i));
</script>
```

**Test Files**:
- `simple-console-test.html` - 기본 console 기능 (색상, 타이밍)
- `test-console.html` - 대량 객체 및 배열 스트레스 테스트

### Network 모니터링 팁

1. **Settings → "Preserve Network Log" 활성화** (기본값: 비활성화)
2. Network 탭 열어둔 상태에서 URL 로드 → 자동 캡처
3. 도메인 필터 선택 → 해당 도메인 리소스만 표시
4. Request/Response 탭에서 헤더 및 본문 검사

**Cross-origin 제한**:
- 외부 CDN 리소스 크기: 보안상 0B 반환 (서버의 `Timing-Allow-Origin` 헤더로 우회 불가)
- Status code는 표시됨

### 성능 프로파일링

```bash
# Xcode Instruments로 메모리 누수 확인
xcodebuild test -project wina.xcodeproj -scheme wina \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -c Debug -only-testing:winaTests/PerformanceTests

# 특정 DevTools 탭 메모리 사용 확인
# (Console: large arrays > 100 items, Network: 1000+ requests)
```

### JavaScript 주입 트러블슈팅

**문제**: WebView에서 JavaScript 평가 실패
```swift
// ❌ 외부 스크립트 fetch 불가 (CORS)
evaluateJavaScript("fetch('https://cdn.example.com/app.js')")

// ✅ inline 코드만 가능
evaluateJavaScript("console.log('hello')")

// ✅ 웹페이지가 로드한 스크립트는 접근 가능
evaluateJavaScript("window.myGlobalVar")
```

**해결책**: 외부 리소스는 웹페이지의 HTML/script 태그로 로드, Swift에서는 결과만 조회

## 리소스 & 참고

- **StoreKit 2**: https://developer.apple.com/documentation/storekit
- **WKWebView**: https://developer.apple.com/documentation/webkit/wkwebview
- **SwiftUI**: https://developer.apple.com/xcode/swiftui/
- **Google AdMob**: https://admob.google.com
- **Eruda Console**: https://eruda.liriliri.io/
- **Test Files**: `simple-console-test.html`, `test-console.html` (프로젝트 루트)
