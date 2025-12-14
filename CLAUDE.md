# CLAUDE.md

## Project Overview

**Wallnut (wina)** - iOS WKWebView 테스터 앱

WKWebView 설정을 실시간 테스트하는 개발자 도구. SwiftUI 기반, iOS 26.1+ (Tahoe)

**주요 기능**: WKWebView/SafariVC 토글, 설정 옵션 테스트, DevTools (Console/Network/Storage/Performance), API Capability 감지, 북마크, 반응형 크기 조절

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
│   ├── Components/      # GlassIconButton, GlassActionButton, ChipButton, InfoPopoverButton, SettingToggleRow, DevToolsHeader, FlowLayout
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
| 원형 아이콘 버튼 | `GlassIconButton` |
| 액션 버튼 | `GlassActionButton` (.default, .destructive, .primary) |
| 칩/태그 | `ChipButton` |
| info 버튼 | `InfoPopoverButton` (Generic ShapeStyle) |
| deprecated 경고 | `DeprecatedPopoverButton` |
| 설정 토글 | `SettingToggleRow` |
| 색상 선택 | `ColorPickerRow` (deprecatedInfo 파라미터) |
| 자동 줄바꿈 | `FlowLayout` |
| DevTools 헤더 | `DevToolsHeader` |

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
