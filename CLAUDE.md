# CLAUDE.md

## Project Overview

**Wallnut (wina)** - iOS WKWebView 테스터 앱

WKWebView 설정을 실시간 테스트하는 개발자 도구. SwiftUI 기반, iOS 26.1+ (Tahoe)

**주요 기능**: WKWebView/SafariVC 토글, 설정 옵션 테스트, DevTools (Console/Network/Storage/Performance), API Capability 감지, 북마크, 반응형 크기 조절, 스크린샷 (WKWebView 전용)

## Quick Reference

```bash
# Build & Run
open wina.xcodeproj && Cmd+R

# Linting (필수)
swiftlint lint && swiftlint --fix

# swift-format (선택적 - SwiftUI 복잡 뷰에서 문제 발생 가능)
swift format format --in-place wina/SomeFile.swift
```

## Architecture

```
wina/
├── winaApp.swift / ContentView.swift    # Entry points
├── Features/
│   ├── AppBar/          # OverlayMenuBars (dual-mode), 버튼들
│   ├── Settings/        # SettingsView, ConfigurationSettingsView, SafariVCSettingsView
│   ├── Console/         # ConsoleManager + UI (JS console 캡처)
│   ├── Network/         # NetworkManager + UI (fetch/XHR 모니터링)
│   ├── Storage/         # StorageManager + UI (localStorage/sessionStorage/cookies, SWR 패턴)
│   ├── Performance/     # Web Vitals + Navigation Timing
│   ├── Info/            # SharedInfoWebView, API Capability 감지, 벤치마크
│   ├── UserAgent/       # UA 커스터마이징
│   └── WebView/         # WebViewContainer, WebViewNavigator
├── Shared/
│   ├── Components/      # GlassIconButton, GlassActionButton, ChipButton, InfoPopoverButton, SettingToggleRow, DevToolsHeader, FlowLayout, JsonEditor/
│   └── Extensions/      # ColorExtensions, DeviceUtilities
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

### 14. 조건부 뷰 간 Layout Shift

emptyState와 contentList 간 전환 시 frame 제약이 다르면 layout shift 발생

```swift
// ❌ 서로 다른 sizing 동작
if items.isEmpty {
    emptyState  // VStack + Spacer
} else {
    ScrollView { ... }  // frame 제약 없음
}

// ✅ 동일한 frame 제약
var emptyState: some View {
    VStack { ... }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
var contentList: some View {
    ScrollView { ... }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

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
| 칩/태그 | `ChipButton` |
| info 버튼 | `InfoPopoverButton` (Generic ShapeStyle) |
| deprecated 경고 | `DeprecatedPopoverButton` |
| 설정 토글 | `SettingToggleRow` |
| 색상 선택 | `ColorPickerRow` (deprecatedInfo 파라미터) |
| 자동 줄바꿈 | `FlowLayout` |
| DevTools 헤더 | `DevToolsHeader` |

### DevToolsHeader 레이아웃

2행 구조로 버튼이 많아도 제목이 밀리지 않음:

```
        [Title]              ← Row 1: 중앙 정렬
[Left Buttons] ⟷ [Right Buttons]  ← Row 2: 좌우 분리
```

**버튼 배치 규칙**:
- Left: Close (xmark.circle.fill) → Actions (trash, share)
- Right: Toggles (play/pause, settings)

**사용 뷰**: Console, Network, Storage, Performance (모두 동일 패턴)

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
NSCameraUsageDescription        # Media Devices, WebRTC
NSMicrophoneUsageDescription    # Media Devices, WebRTC
NSLocationWhenInUseUsageDescription  # Geolocation
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
