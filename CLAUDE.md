# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wallnut (wina)** - iOS WKWebView 테스터 앱

WKWebView의 다양한 설정 옵션을 실시간으로 테스트하고 검증하기 위한 도구. 개발자가 WebView 동작을 빠르게 확인하고 디버깅할 수 있도록 지원.

### 주요 기능

- WKWebView 설정 옵션 토글 (JavaScript, 쿠키, 줌, 미디어 자동재생 등)
- User-Agent 커스터마이징
- URL 입력 (실시간 유효성 검사) 및 웹페이지 로딩 테스트
- WKWebView / Safari (SFSafariViewController) 선택 가능
- 북마크 저장 및 관리
- WebView 크기 조절 (반응형 테스트용)
- WKWebView Info: Device, Browser, API Capabilities (46개+), Media Codecs, Performance, Display, Accessibility
- Info 전체 검색: 모든 카테고리에서 통합 검색 가능
- 기기별 UI: iPad/iPhone에 따라 unavailable 플래그 및 info 텍스트 동적 변경
- 권한 관리: Settings에서 Camera, Microphone, Location 권한 요청/확인

## Build & Run

```bash
# Xcode로 빌드
open wina.xcodeproj
# Cmd+R로 실행

# CLI 빌드 (시뮬레이터)
xcodebuild -project wina.xcodeproj -scheme wina -sdk iphonesimulator build

# 특정 시뮬레이터 지정 빌드
xcodebuild -project wina.xcodeproj -scheme wina -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Linting & Formatting

### SwiftLint (필수)

```bash
# 린트 실행
swiftlint lint

# 자동 수정 가능한 이슈 수정
swiftlint --fix
```

### swift-format (선택적 - Xcode 26 내장)

```bash
# 단일 파일 포맷
swift format format --in-place wina/SomeFile.swift

# 전체 프로젝트 포맷 (⚠️ SwiftUI 뷰 빌더에서 컴파일 문제 발생 가능)
swift format format --in-place --recursive wina/
```

> **주의**: swift-format은 복잡한 SwiftUI 뷰 빌더에서 컴파일러 타입 체크 문제를 일으킬 수 있음. 개별 파일에만 선택적으로 사용 권장.

### 설정 파일

- `.swiftlint.yml` - SwiftLint 규칙 설정
- `.swift-format` - swift-format 설정 (4칸 들여쓰기, 120자 줄 길이)

## Architecture

SwiftUI 기반 단일 타겟 iOS 앱. 최소 지원 버전: iOS 26.1 (Tahoe)

```
wina/
├── winaApp.swift              # App entry point (@main), 다크모드 상태 관리
├── ContentView.swift          # Root view, URL 입력 + 유효성 검사 + 북마크 + 최근 URL 기록
├── Features/
│   ├── AppBar/                # 상단/하단 메뉴 바
│   │   ├── OverlayMenuBars.swift      # 메인 메뉴 바 (dual-mode: fixed/overlay)
│   │   ├── ThemeToggleButton.swift
│   │   ├── SettingsButton.swift
│   │   ├── InfoButton.swift
│   │   ├── BookmarkButton.swift
│   │   └── BackButton.swift
│   ├── Settings/              # WebView 설정
│   │   ├── SettingsView.swift         # 메인 Settings 진입점
│   │   ├── ConfigurationSettingsView.swift  # Static settings (WebView 재생성 필요)
│   │   ├── PermissionsSettingsView.swift    # 권한 설정 (Camera, Mic, Location)
│   │   └── SafariVCSettingsView.swift       # SafariVC 전용 설정
│   ├── UserAgent/             # User-Agent 커스터마이징
│   │   ├── UserAgentPickerView.swift  # UA 선택 UI
│   │   ├── UserAgentPresets.swift     # 프리셋 정의
│   │   └── UserAgentBuilder.swift     # UA 문자열 빌더
│   ├── Info/                  # WKWebView 정보 표시
│   │   ├── InfoView.swift             # 메인 뷰 + 검색
│   │   ├── SharedInfoWebView.swift    # WebView 싱글톤 + 캐싱
│   │   ├── InfoComponents.swift       # 공유 UI 컴포넌트
│   │   ├── DeviceInfoView.swift       # 디바이스 정보
│   │   ├── BrowserInfoView.swift      # 브라우저 + API 감지
│   │   ├── APICapabilitiesView.swift  # API 카테고리별 표시
│   │   ├── MediaCodecsView.swift      # 코덱 지원 감지
│   │   ├── PerformanceView.swift      # 벤치마크 + 스코어링
│   │   ├── DisplayFeaturesView.swift  # 디스플레이 기능
│   │   ├── AccessibilityFeaturesView.swift  # 접근성 설정
│   │   ├── ActiveSettingsView.swift   # 현재 설정 표시
│   │   └── SafariVCInfoView.swift     # SafariVC Info
│   └── WebView/               # WebView 컨테이너
│       └── WebViewContainer.swift
├── Shared/
│   ├── Components/            # 재사용 UI 컴포넌트
│   │   ├── GlassIconButton.swift      # 원형 glass effect 버튼
│   │   ├── GlassActionButton.swift    # 액션 버튼 (capsule glass)
│   │   ├── ChipButton.swift           # 탭 가능한 칩 버튼
│   │   ├── FlowLayout.swift           # 자동 줄바꿈 Layout
│   │   ├── InfoPopoverButton.swift    # info/deprecated 버튼 + popover
│   │   ├── SettingToggleRow.swift     # 설정 토글 (InfoPopoverButton 사용)
│   │   ├── ColorPickerRow.swift       # 색상 선택기 (InfoPopoverButton 사용)
│   │   └── WebViewSizeControl.swift   # WebView 크기 조절 컨트롤
│   └── Extensions/            # 공유 확장
│       ├── ColorExtensions.swift      # Color/UIColor hex 변환
│       └── DeviceUtilities.swift      # UIDevice.isIPad, ScreenUtility, SettingsFormatter
└── Resources/Icons/           # 앱 아이콘 원본
```

### 데이터 흐름

- `@AppStorage` 사용하여 설정 값 UserDefaults 영속화
- Sheet 기반 모달 (Settings, Info)
- WKWebView JavaScript 평가로 브라우저 capability 감지
- 최근 URL 기록: 최대 20개 저장, dropdown에 4개 표시 + 스크롤

### WebView 인스턴스 관리

**WebViewNavigator** (`WebViewContainer.swift`): WKWebView의 외부 제어를 위한 @Observable 클래스

```swift
// KVO로 상태 관찰
var canGoBack: Bool
var canGoForward: Bool
var currentURL: URL?

// 네비게이션 제어
func goBack() / goForward() / reload() / stopLoading()
func loadURL(_ urlString: String)  // 같은 인스턴스에서 URL 로드 (히스토리 유지)
func evaluateJavaScript(_ script: String) async -> Any?
```

**인스턴스 재생성 vs 유지**:
- URL 변경: `navigator.loadURL()` 사용 → 히스토리 유지
- Configuration 설정 변경: `webViewID = UUID()` → 새 인스턴스 생성 필요
- SafariVC: 항상 새 인스턴스 생성 (프레임워크 제한)

### Info WebView 모드

**SharedInfoWebView** (`SharedInfoWebView.swift`): Info 시트의 capability 감지용 WebView 관리

- **Test Mode** (기본): 내부 WebView로 example.com 테스트
- **Live Mode**: 실제 로드된 페이지의 WebView 사용

```swift
// Live WebView 연결
SharedInfoWebView.shared.setNavigator(navigator)

// 모드 확인
SharedInfoWebView.shared.isUsingLiveWebView  // true: 실제 페이지, false: 테스트
SharedInfoWebView.shared.currentURL          // Live 모드에서 현재 URL
```

Info 시트 열 때 `navigator` 전달하면 실제 페이지 기준으로 capability 감지.

## Design System

**Liquid Glass UI** - iOS 26 (Tahoe) 공식 Glass Effect

```swift
.glassEffect()                            // 기본
.glassEffect(in: .capsule)                // 캡슐
.glassEffect(in: .circle)                 // 원형
.glassEffect(in: .rect(cornerRadius: 16)) // 라운드 사각형
```

### 디자인 원칙

- `.glassEffect()` modifier 사용 (Material 대신)
- 시스템 기본 배경 유지 (임의 배경색 X)
- `.secondary`, `.primary` 등 시스템 색상 활용

## UI 일관성 규칙

**핵심 원칙**: 유사한 기능은 반드시 동일한 컴포넌트를 사용

### 공유 컴포넌트 사용 필수 (`Shared/Components/`)

| 용도 | 컴포넌트 | 사용처 |
|------|----------|--------|
| 원형 아이콘 버튼 | `GlassIconButton` | AppBar 버튼들 |
| 액션 버튼 | `GlassActionButton` | Reset/Apply/Done (capsule glass) |
| 칩/태그 버튼 | `ChipButton` | 프리셋 선택, 태그 |
| info 버튼 | `InfoPopoverButton` | 모든 info 버튼 (Generic ShapeStyle 지원) |
| deprecated 경고 | `DeprecatedPopoverButton` | iOS 26에서 deprecated된 설정 (SafariVC Colors) |
| 설정 토글 | `SettingToggleRow` | SettingsView 전체 |
| 색상 선택 | `ColorPickerRow` | 색상 설정 (deprecatedInfo 파라미터 지원) |
| 자동 줄바꿈 | `FlowLayout` | 칩 그룹, 태그 목록 |

### Info 뷰 전용 컴포넌트 (`InfoView.swift` 내 private)

| 용도 | 컴포넌트 | 패턴 |
|------|----------|------|
| 라벨-값 표시 | `InfoRow` | `label: String`, `value: String`, `info: String?` |
| 지원 여부 | `CapabilityRow` | `supported: Bool`, `unavailable: Bool` (iPad only 등) |
| 설정 상태 | `ActiveSettingRow` | `enabled: Bool`, checkmark/xmark 아이콘 |
| 벤치마크 | `BenchmarkRow` | `ops: Double?`, ops/s 포맷 |
| 코덱 | `CodecRow` | `CodecSupport` enum (probably/maybe/none) |

### info 버튼 사용법

`InfoPopoverButton` 컴포넌트를 반드시 사용:

```swift
// ✅ 기본 사용 (기본색: .secondary)
InfoPopoverButton(text: "설명 텍스트")

// ✅ 색상 지정 (ShapeStyle 지원)
InfoPopoverButton(text: "설명 텍스트", iconColor: .tertiary)
InfoPopoverButton(text: "설명 텍스트", iconColor: Color.blue)
```

### deprecated 경고 버튼 사용법

iOS 26에서 deprecated된 API에 경고를 표시할 때 `DeprecatedPopoverButton` 사용:

```swift
// ✅ 오렌지색 exclamationmark.triangle.fill 아이콘 + "Deprecated" 헤더 popover
DeprecatedPopoverButton(text: "Deprecated in iOS 26. Interferes with Liquid Glass effects.")
```

ColorPickerRow에서 deprecated 설정 표시:

```swift
// ✅ deprecatedInfo 파라미터로 deprecated 경고 추가
ColorPickerRow(
    title: "Control Tint",
    colorHex: $controlTintColorHex,
    info: "Tint color for buttons and controls.",
    deprecatedInfo: "Deprecated in iOS 26. Interferes with Liquid Glass effects."
)
```

### 액션 버튼 사용법

`GlassActionButton` 컴포넌트를 반드시 사용:

```swift
// ✅ 기본 스타일
GlassActionButton("Done") { dismiss() }

// ✅ 아이콘 + 스타일
GlassActionButton("Reset to Defaults", icon: "arrow.counterclockwise", style: .destructive) {
    resetToDefaults()
}

// ✅ 스타일 옵션: .default, .destructive, .primary
GlassActionButton("Apply", icon: "checkmark", style: .primary) { applyChanges() }
```

### 공유 유틸리티 (`DeviceUtilities.swift`)

```swift
// 디바이스 체크
UIDevice.current.isIPad

// 화면 크기 (iOS 26+ 대응)
ScreenUtility.screenSize

// 설정 값 포매터
SettingsFormatter.contentModeText(mode)           // 0→"Recommended", 1→"Mobile", 2→"Desktop"
SettingsFormatter.dismissButtonStyleText(style)   // 0→"Done", 1→"Close", 2→"Cancel"
SettingsFormatter.activeDataDetectors(phone:links:address:calendar:)
SettingsFormatter.enabledStatus(enabled)          // true→"Enabled", false→"Disabled"
```

### 금지 사항

- ❌ info 버튼 직접 구현 (반드시 `InfoPopoverButton` 사용)
- ❌ `UIDevice.userInterfaceIdiom` 직접 체크 (`UIDevice.current.isIPad` 사용)
- ❌ `UIScreen.main.bounds` 사용 (`ScreenUtility.screenSize` 사용)
- ❌ 유사 기능에 새로운 컴포넌트 생성 (기존 컴포넌트 확장할 것)
- ❌ unavailable 표시에 다른 패턴 사용 (`(iPad only)` + `.tertiary` 통일)

### SwiftUI 터치 영역 규칙

아이콘만 있는 버튼은 터치 영역이 불명확해져 터치가 안 되는 버그 발생:

**왜 `.buttonStyle(.plain)`이 문제인가?**

| ButtonStyle | 터치 영역 |
|-------------|-----------|
| `.automatic` (기본) | label 전체 영역 (`.frame()` 포함) |
| `.plain` | **실제 콘텐츠 픽셀만** (`.frame()` 무시됨) |

`.plain` 스타일은 탭 시 시각적 효과를 제거하지만, 동시에 터치 영역도 Image의 렌더링된 픽셀로 제한됨. 예: 18pt 아이콘 + 48x48 frame → 18pt 영역만 터치 가능.

```swift
// ✅ 올바른 패턴
Button {
    action()
} label: {
    Image(systemName: "xmark.circle.fill")
        .frame(width: 44, height: 44)
        .contentShape(Circle())        // 44x44 원형 전체가 터치 영역
}
.buttonStyle(.plain)

// ❌ 터치 안 되는 패턴 (아이콘 픽셀만 터치 가능)
Button {
    action()
} label: {
    Image(systemName: "xmark.circle.fill")
        .frame(width: 44, height: 44)  // 레이아웃만, 터치 영역 아님
}
.buttonStyle(.plain)
```

**필수 적용 상황**:

- `.buttonStyle(.plain)` 사용하는 아이콘 버튼
- overlay/dropdown 내부 또는 근처 버튼
- HStack/VStack 내 다른 터치 요소와 인접한 버튼

## Code Conventions

| 대상 | 컨벤션 | 예시 |
|------|--------|------|
| 파일명, 타입 | PascalCase | `ContentView.swift` |
| 변수, 함수 | camelCase | `urlText`, `loadPage()` |
| 에셋 | kebab-case | `app-icon` |

### 파일 구성

- 1파일 1컴포넌트 원칙 (public View 기준)
- 150줄 이하 유지 권장
- 해당 파일 전용 helper는 같은 파일에 `private`으로 선언

### 작업 규칙

- 끝나면 항상 문법검사 수행
- 빌드 검증은 통합적인 작업 이후에만 확인 (시간 소요)

## Swift 성능 최적화 (2025)

### 메모리 관리 & ARC

- 앱 크래시의 약 90%가 메모리 문제 관련
- `deinit`에서 observers 명시적 제거
- 클로저에서 `[weak self]` 사용하여 retain cycle 방지

```swift
// ✅ 올바른 패턴
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.updateUI()
}
```

### Value Types 우선

- `struct` > `class` (스택 할당으로 최대 50% 메모리 절감)
- 단순 데이터 모델은 반드시 `struct` 사용
- Generics 활용으로 타입 안전성 + 재사용성 확보

```swift
// ✅ 권장
struct UserSettings {
    var theme: Theme
    var fontSize: Int
}

// ❌ 불필요한 class 사용
class UserSettings { ... }
```

### Lazy Loading & 캐싱

- `lazy var` 사용으로 초기 로드 시간 최대 30% 감소
- 자주 접근하는 데이터는 캐싱
- 불필요한 계산 최소화

```swift
// ✅ 필요할 때만 초기화
lazy var expensiveObject = ExpensiveClass()
```

### 컬렉션 최적화

- 정렬된 데이터: `Array` (O(1) 접근)
- 키-값 조회: `Dictionary` (O(1) 조회)
- 중복 제거: `Set`
- 시간 복잡도 항상 고려

### 반복문 최적화

```swift
// ✅ stride 사용
for i in stride(from: 0, to: 100, by: 2) { }

// ✅ 반복문 밖에서 계산
let count = array.count
for i in 0..<count { }

// ❌ 반복문 내 불필요한 계산
for i in 0..<array.count { }
```

### SwiftUI 렌더링 최적화

- 불필요한 렌더링 방지를 위해 `@State`, `@Binding` 범위 최소화
- 1000개 이상 항목은 `LazyVStack`, `LazyHStack` 사용
- `Equatable` 준수로 불필요한 뷰 업데이트 방지

```swift
// ✅ 필요한 범위만 업데이트
struct ItemView: View, Equatable {
    let item: Item
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item.id == rhs.item.id
    }
}
```

### 피해야 할 것

- ❌ Reflection (런타임 오버헤드)
- ❌ 강제 언래핑 (`!`) - `if let`, `guard let` 사용
- ❌ 동기 네트워크 호출 - `async/await` 사용

## Swift 코드 스타일 가이드 (2025)

### 기본 원칙 (Apple API Design Guidelines)

- **명확성 우선**: 간결함보다 명확성이 중요
- **사용 시점의 명확성**: 선언이 아닌 사용처에서 이해하기 쉽게

### 네이밍

```swift
// ✅ 올바른 네이밍
func removeItem(at index: Int)           // 명확한 파라미터 레이블
var isEnabled: Bool                       // Bool은 is/has/can 접두사
struct UserProfile { }                    // 타입은 UpperCamelCase
let maximumRetryCount = 3                // 상수도 lowerCamelCase

// ❌ 피해야 할 네이밍
func remove(_ i: Int)                     // 불명확한 축약
var enabled: Bool                         // is 접두사 누락
```

### self 사용

```swift
// ✅ self 생략 (Swift 기본)
func updateUI() {
    titleLabel.text = title
}

// ✅ self 필수 (escaping closure, 초기화 시 구분)
init(name: String) {
    self.name = name
}

Timer.scheduledTimer { [weak self] _ in
    self?.refresh()
}
```

### let vs var

```swift
// ✅ 항상 let으로 시작, 필요 시 var로 변경
let configuration = URLSessionConfiguration.default
configuration.timeoutInterval = 30  // 컴파일러가 var 필요 시 알려줌
```

### 코드 구성

- Extension으로 프로토콜 준수 분리
- `// MARK: -` 로 섹션 구분
- 관련 기능을 논리적으로 그룹화

```swift
// MARK: - View
struct ContentView: View {
    var body: some View { ... }
}

// MARK: - Private Methods
private extension ContentView {
    func loadData() { ... }
}
```

### Protocol-Oriented Programming

```swift
// ✅ 프로토콜 + 기본 구현
protocol Loadable {
    func load()
}

extension Loadable {
    func load() { /* 기본 구현 */ }
}

// ❌ 불필요한 상속 계층
class BaseViewController: UIViewController { }
class HomeViewController: BaseViewController { }
```

## 프로젝트 구조 가이드 (2025)

### 이 프로젝트의 구조 원칙

**Feature-Based Organization** 채택:

```
wina/
├── winaApp.swift              # 진입점 (루트 유지)
├── ContentView.swift          # 메인 뷰 (루트 유지)
├── Features/                  # 기능별 그룹화
│   ├── AppBar/
│   ├── Settings/
│   ├── Info/
│   └── WebView/
├── Shared/                    # 공유 컴포넌트
│   ├── Components/
│   └── Extensions/
└── Resources/                 # 에셋, 아이콘
```

### 구조 원칙

1. **Entry Point는 루트에 유지**
   - `App.swift`, `ContentView.swift`는 최상위에 배치
   - 빠른 진입을 위해 폴더 탐색 최소화

2. **Feature 기반 그룹화**
   - 기능별 폴더로 덤핑 그라운드 방지
   - 관련 View, ViewModel, Model 같은 폴더에 배치

3. **Shared는 2개 이상 사용 시에만**
   - 단일 사용 컴포넌트는 해당 Feature 폴더에 유지
   - Rule of Three: 3번 이상 사용되면 Shared로 이동

4. **Xcode 구조 = 파일 시스템 구조**
   - Xcode 그룹과 실제 폴더 구조 일치시킬 것

### 파일 배치 규칙

| 파일 유형 | 위치 | 예시 |
|----------|------|------|
| 앱 진입점 | 루트 | `winaApp.swift` |
| 메인 뷰 | 루트 | `ContentView.swift` |
| 기능별 뷰 | `Features/[Feature]/` | `Features/Settings/SettingsView.swift` |
| 공유 컴포넌트 | `Shared/Components/` | `Shared/Components/ChipButton.swift` |
| 확장 | `Shared/Extensions/` | `Shared/Extensions/ColorExtensions.swift` |
| 에셋 | `Resources/` 또는 `Assets.xcassets/` | `Resources/Icons/app-icon.svg` |

### 금지 사항

- ❌ `Utilities/`, `Helpers/`, `Misc/` 같은 모호한 폴더명
- ❌ 빈 폴더 유지
- ❌ 단일 파일을 위한 폴더 생성
- ❌ 깊은 중첩 (최대 3단계: `Features/Settings/Components/`)

## SwiftUI 레이아웃 주의사항

### 컴파일러 타입 체크 문제

복잡한 뷰 표현식은 컴파일러가 타입 체크하지 못함. **별도 computed property로 분리 필수**:

```swift
// ❌ 컴파일 에러: "unable to type-check this expression in reasonable time"
var body: some View {
    VStack {
        // 중첩된 ForEach, overlay, 복잡한 조건문 등
    }
}

// ✅ 해결: 복잡한 부분을 별도 property로 분리
var body: some View {
    VStack {
        complexPart
    }
}

@ViewBuilder
private var complexPart: some View {
    // 분리된 복잡한 뷰
}
```

### ZStack Overlay에서 터치 이벤트 처리

ZStack에서 상단 바 등 overlay 뷰를 만들 때, **VStack + Spacer 패턴은 터치를 가로챌 수 있음**:

```swift
// ❌ 문제: Spacer가 화면 전체를 덮어 터치 이벤트 가로챔
private var topBar: some View {
    VStack {
        HStack { /* buttons */ }
        Spacer()  // 아래 뷰의 터치를 방해할 수 있음
    }
}

// ✅ 해결: HStack만 사용하고 frame으로 정렬
private var topBar: some View {
    HStack { /* buttons */ }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .frame(maxHeight: .infinity, alignment: .top)
}
```

**핵심**: `.frame(maxHeight: .infinity, alignment: .top)`으로 HStack의 실제 높이(버튼 44pt)만 터치 영역이 되고, 나머지는 아래 뷰로 pass-through됨.

### 제스처 우선순위 (WebView 위 오버레이)

WebView 위에 드래그 가능한 오버레이를 만들 때, WebView가 터치를 먼저 가로챔:

```swift
// ❌ 문제: WebView 스크롤이 드래그 제스처보다 우선
.gesture(dragGesture)

// ✅ 해결: highPriorityGesture로 우선순위 확보
.highPriorityGesture(isOverlayMode ? dragGesture : nil)
```

**OverlayMenuBars 패턴** (`Features/AppBar/OverlayMenuBars.swift`):

```swift
// Dual-mode: isOverlayMode로 동작 분기
struct OverlayMenuBars: View {
    let isOverlayMode: Bool  // true: pull-down drawer, false: fixed position
    let onURLChange: (String) -> Void  // 하단 바에서 URL 변경 시 콜백

    // Fixed mode (App preset ≤82%): 바 항상 표시, 드래그 없음
    // Overlay mode (>82%/fullscreen): 상단에 6pt 핸들만 노출, 드래그로 펼침
    // 하단 바: 현재 URL host 표시 + 탭 시 URL 변경 alert
}
```

### Dropdown을 TextField 아래에 정확히 위치시키기

`.overlay`로 dropdown을 만들 때 **alignmentGuide + zIndex 패턴** 사용:

```swift
// ❌ 문제: overlay가 VStack 중앙 기준으로 배치되어 input을 가림
VStack {
    urlInputField
    quickOptions
}
.overlay { dropdown }

// ✅ 해결: input에 직접 overlay 붙이고 alignmentGuide로 위치 지정
urlInputField
    .overlay(alignment: .bottom) {
        dropdown
            .alignmentGuide(.bottom) { $0[.top] }  // dropdown의 top을 input의 bottom에 맞춤
    }
    .zIndex(1)  // sibling 뷰(quickOptions) 위에 표시
```

**원리**:
- `.overlay(alignment: .bottom)` - overlay 기본 anchor를 base view의 bottom에 맞춤
- `.alignmentGuide(.bottom) { $0[.top] }` - overlay 내부에서 `.bottom`을 재정의해 overlay의 top edge를 사용
- `.zIndex(1)` - 같은 VStack level에서 다른 sibling 뷰 위에 표시 (zIndex는 overlay 내부가 아닌 같은 stack level에 적용해야 함)

### contentShape와 터치 영역

배경 탭으로 키보드/드롭다운을 닫을 때:

```swift
// Color.clear만으로는 터치 영역이 없음
Color.clear
    .contentShape(Rectangle())  // 터치 영역 명시
    .onTapGesture { ... }
```

### Safe Area 동적 처리

하단 바를 홈 인디케이터 위에 배치할 때, 기기별 safe area 차이 대응:

```swift
// ❌ 하드코딩된 값은 기기별로 다르게 보임
.padding(.bottom, -20)

// ✅ GeometryReader로 동적 safe area 계산
GeometryReader { geometry in
    bottomBar
        .padding(.bottom, -(geometry.safeAreaInsets.bottom * 0.6))
}
```

**iOS Safe Area Insets 참고**:
- 상단: 59-62pt (Dynamic Island/노치 기기), SwiftUI가 자동 처리
- 하단: 0pt (홈 버튼), 34pt (Face ID 기기) → 동적 처리 필요

### 로딩 인디케이터

WKWebView 로딩 상태는 KVO로 관찰하여 상단에 얇은 progress bar로 표시:

```swift
// WebViewContainer.swift
.overlay(alignment: .top) {
    if isLoading {
        LoadingProgressBar()  // 3px 애니메이션 그라데이션 바
    }
}
```

- 페이지 로드/네비게이션 시 자동 표시
- 전체 화면 가리지 않아 로딩 중에도 콘텐츠 확인 가능

## iOS 26 주의사항

```swift
// ❌ Deprecated
UIScreen.main.bounds

// ✅ iOS 26+
let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
scene?.screen.bounds
UITraitCollection.current.displayScale
```

## Image Conversion

SVG → PNG 변환 시 `rsvg-convert` 사용 (ImageMagick은 색상이 어둡게 변환됨)

```bash
# 올바른 방법
rsvg-convert -w 1024 -h 1024 input.svg -o output.png

# 사용하지 말 것 (색상 왜곡)
magick input.svg output.png
```

## WKWebView API Capability 체크 주의사항

### Info.plist 권한이 필요한 API

앱에 권한이 선언되지 않으면 WebKit이 API를 노출하지 않아 false 반환:

- **Media Devices / WebRTC**: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`
- **Geolocation**: `NSLocationWhenInUseUsageDescription`

**현재 등록된 권한** (`Info.plist` - 프로젝트 루트):

- `NSCameraUsageDescription`: 카메라 (Media Devices, WebRTC 테스트용)
- `NSMicrophoneUsageDescription`: 마이크 (Media Devices, WebRTC 테스트용)
- `NSLocationWhenInUseUsageDescription`: 위치 (Geolocation 테스트용)

> 실제 권한 요청 다이얼로그를 표시하려면 `WKUIDelegate`의 `requestMediaCapturePermission` 구현 필요

### WKWebView에서 항상 미지원 (WebKit 정책)

Safari에서만 지원되거나 WebKit에서 구현하지 않은 API:

- **Service Workers**: Safari/홈 화면 PWA 전용. WKWebView는 App-Bound Domains 필요
- **Web Push Notifications**: Safari/홈 화면 PWA 전용 (iOS 16.4+)
- **Vibration, Battery, Bluetooth, USB, NFC**: WebKit 보안/개인정보 정책으로 미구현

### iOS 특수 API

- **MediaSource**: iOS 17+에서 `ManagedMediaSource` 사용 (기존 MSE 미지원, WKWebView에서는 N/A)
- **localStorage/sessionStorage**: `loadHTMLString` 사용 시 `baseURL`을 실제 URL로 설정해야 접근 가능

## Performance 벤치마크

3DMark 스타일 점수 시스템. **iPhone 14 Pro = 10,000점** 기준.

### 벤치마크 항목

| 카테고리 | 테스트 |
|----------|--------|
| JavaScript | Math, Array, String, Object, RegExp |
| DOM | Create, Query, Modify |
| Graphics | Canvas 2D, WebGL |
| Memory | Allocation, Operations |
| Crypto | Hash |

### 레퍼런스 값 (iPhone 14 Pro)

`PerformanceInfo.reference` 딕셔너리에 정의됨. 새 기기 측정 시 이 값 업데이트 가능.

### 주의사항

- 벤치마크 JavaScript는 동기 실행 필수 (async/await 사용 시 WKWebView에서 "unsupported type" 에러)
- Canvas/WebGL은 `document.createElement`로 동적 생성 (HTML 내 element는 `baseURL: nil`일 때 접근 불가할 수 있음)

## Info 검색 구조

`InfoView`의 `allItems` computed property가 모든 검색 가능 항목을 통합:

- Active Settings (20개): 현재 WebView 설정 상태 (항상 표시), Settings 바로가기 버튼 포함
- Device, Browser, API, Codecs, Display, Accessibility: 데이터 로드 후 검색 가능
- Performance: 항목만 노출 (`linkToPerformance: true`), 클릭 시 벤치마크 화면으로 이동

검색 결과는 `filteredItems`에서 카테고리별로 그룹화되어 표시.

## Settings 구조

WebView 타입에 따라 다른 Settings 화면이 표시됨:

### WKWebView Settings (SettingsView.swift)

3개 섹션으로 구분:

**Static Settings (WebView 재로드 필요)**

| 카테고리 | 설정 |
|----------|------|
| Configuration | JavaScript, Content JavaScript, Minimum Font Size, Auto-play Media, Inline Playback, AirPlay, PiP, Content Mode, JS Can Open Windows, Fraudulent Website Warning, Element Fullscreen API, Suppress Incremental Rendering, Data Detectors (Phone, Links, Address, Calendar) |
| Privacy & Security | Private Browsing, Upgrade to HTTPS |

**Live Settings (즉시 적용)**

| 카테고리 | 설정 |
|----------|------|
| Navigation & Interaction | Back/Forward Gestures, Link Preview, Ignore Viewport Scale Limits, Text Interaction, Find Interaction |
| Display & Appearance | Page Zoom (50%~300%), Under Page Background Color, Custom User-Agent |
| WebView Size | Width/Height ratio sliders (25%~100%), presets (100%, App, 75%) |

**System**

| 카테고리 | 설정 |
|----------|------|
| Permissions | Camera, Microphone, Location (WebRTC, Geolocation용) |

### SafariVC Settings (SafariVCSettingsView.swift)

SFSafariViewController는 설정 가능 항목이 제한적:

| 카테고리 | 설정 | 비고 |
|----------|------|------|
| Behavior | Reader Mode, Bar Collapsing | |
| UI Style | Dismiss Button Style | Done/Close/Cancel |
| Colors | Control Tint, Bar Tint | ⚠️ iOS 26 deprecated (Liquid Glass 호환성) |

> **Deprecated 경고**: Colors 섹션의 `preferredControlTintColor`, `preferredBarTintColor`는 iOS 26에서 deprecated. Liquid Glass 배경 효과와 충돌하므로 사용 권장하지 않음.

> **WKWebView vs SafariVC 차이점**: SafariVC는 JavaScript 비활성화, Custom User-Agent, Content Mode, Data Detectors 등 대부분의 커스터마이징이 불가능. Safari의 쿠키/비밀번호를 공유하는 대신 앱에서 제어할 수 없음.

### Settings 표시 로직 (ContentView.swift)

```swift
if useSafariWebView {
    SafariVCSettingsView()      // SafariVC 선택 시
} else if showWebView {
    DynamicSettingsView(...)    // WKWebView 로드 후 (Live Settings)
} else {
    SettingsView()              // WKWebView 로드 전 (Static + Live + System)
}
```

모든 설정은 `@AppStorage`로 UserDefaults에 영속화됨.

### Settings 패턴: Local State → Explicit Apply

Configuration, Live Settings는 **명시적 확인** 패턴 사용:

```swift
// 1. @AppStorage (stored) + @State (local) 분리
@AppStorage("settingKey") private var storedValue: Bool = false
@State private var localValue: Bool = false

// 2. 변경 감지
private var hasChanges: Bool {
    localValue != storedValue
}

// 3. 로드/적용/리셋
private func loadFromStorage() {
    localValue = storedValue
}

private func applyChanges() {
    storedValue = localValue
    webViewID = UUID()  // WebView 리로드 트리거
    dismiss()
}

private func resetToDefaults() {
    localValue = false  // 기본값으로 리셋 (저장 X)
}
```

**적용 대상**:

- `ConfigurationSettingsView`: Static settings (WebView 재생성 필요)
- `LiveSettingsView`: Live settings (즉시 적용)
- `SafariVCConfigurationSettingsView`: SafariVC 설정

**UI 패턴**:

- Toolbar: Apply 버튼 (`hasChanges` false면 disabled)
- List 내부: Reset 버튼 (`GlassActionButton` destructive style)
- 변경 시 경고 Section 표시

### UI 컴포넌트

- `SettingsCategoryRow`: 아이콘, 제목, 부가설명이 포함된 NavigationLink 스타일
- `SettingToggleRow`: info 버튼이 포함된 Toggle 스타일
- `InfoCategoryRow`: Info 뷰에서 사용하는 동일 스타일의 카테고리 row
- `SafariSettingToggleRow`: SafariVC용 Toggle 스타일
- `SafariColorPickerRow`: SafariVC용 색상 선택 row

## Info 버튼 컴포넌트

Info 뷰에서 사용되는 재사용 컴포넌트들 (모두 `InfoPopoverButton` 사용):

- `InfoRow`: 라벨-값 쌍 표시, 선택적 info 버튼
- `CapabilityRow`: 지원 여부 체크마크 표시, 선택적 info 버튼, unavailable 플래그
- `ActiveSettingRow`: 설정 상태 표시 (enabled/disabled), 선택적 info 버튼
- `BenchmarkRow`: 벤치마크 결과 표시 (ops/s), 선택적 info 버튼 (`.tertiary` 색상)
- `CodecRow`: 코덱 지원 상태 (probably/maybe/none)
