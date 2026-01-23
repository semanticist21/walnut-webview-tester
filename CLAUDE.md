# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Walnut (wina)** - WKWebView & SFSafariViewController 테스터 앱

WKWebView와 SFSafariViewController 설정을 실시간 테스트하는 개발자 도구. SwiftUI 기반, iOS 18.4+, ~100 Swift files

**주요 기능**:
- **WKWebView**: 설정 옵션 테스트, DevTools (Console/Network/Storage/Performance/Sources/Accessibility), 스크린샷/녹화
- **SFSafariViewController**: Safari 쿠키/세션 공유, Content Blocker, Reader Mode, Safari 확장 지원
- **공통**: URL 테스트, API Capability 감지, 북마크, 반응형 크기 조절

**Dependencies** (SPM):
- GoogleMobileAds - 광고
- UAParserSwift - User-Agent 파싱
- SwiftSoup - HTML 파싱
- Runestone + TreeSitterHTMLRunestone - 코드 하이라이팅
- SwiftUIBackports - iOS 하위 버전 호환성

## Quick Reference

### Build & Run
```bash
# Build and run in simulator
open wina.xcodeproj && Cmd+R

# Run on specific device
xcodebuild -project wina.xcodeproj -scheme wina -destination 'platform=iOS,name=iPhone 16,OS=latest'
```

### Code Quality (필수 - 커밋 전)
```bash
# Lint + auto-fix (필수)
swiftlint lint --fix && swiftlint lint

# Optional: Format (avoid with complex SwiftUI views - can cause regressions)
swift format format --in-place wina/SomeFile.swift

# Analyzer (separate, optional)
xcodebuild analyze -project wina.xcodeproj -scheme wina -destination generic/platform=iOS
```

**Workflow**:
1. Make changes
2. Run `swiftlint lint --fix` (auto-fixes most issues)
3. Run `swiftlint lint` again (verify all passed)
4. Commit with conventional format message
5. **DO NOT push** unless user explicitly asks

### Testing
```bash
# Run all tests
xcodebuild test -project wina.xcodeproj -scheme wina -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test file
xcodebuild test -project wina.xcodeproj -scheme wina -only-testing:winaTests/URLValidatorTests

# Run with coverage
xcodebuild test -project wina.xcodeproj -scheme wina -enableCodeCoverage YES
```

## Architecture

```
wina/
├── winaApp.swift                        # App entry point
├── ContentView.swift                    # Main view (split into extensions)
├── ContentView+URLInput.swift           # URL input handling
├── ContentViewSheets.swift              # Sheet presentations
├── Features/
│   ├── About/           # AboutView, StoreManager (IAP)
│   ├── Accessibility/   # AccessibilityAuditView (axe-core 기반)
│   ├── Ad/              # AdManager (Google AdMob interstitial + banner)
│   ├── AppBar/          # OverlayMenuBars, 버튼들
│   ├── Callback/        # URL scheme callback testing (walnut://)
│   ├── Console/         # ConsoleManager + UI (JS console 캡처 + %c styling + array chunking)
│   ├── Info/            # SharedInfoWebView, API Capability 감지, 벤치마크
│   ├── Network/         # NetworkManager + UI (fetch/XHR + scroll buttons + domain filtering)
│   ├── Performance/     # Web Vitals + Navigation Timing
│   ├── Resources/       # Network 탭 리소스 타이밍 & 크기
│   ├── SearchText/      # SearchTextOverlay (in-page text search, Cmd+F style)
│   ├── Settings/        # SettingsView, ConfigurationSettingsView, SafariVCSettingsView, EmulationSettingsView
│   ├── Snippets/        # SnippetsView (JavaScript snippet execution)
│   ├── Sources/         # DOM Tree, Stylesheets, Scripts, CSS parsing/specificity, search
│   ├── Storage/         # Storage UI (localStorage/sessionStorage/cookies via WebViewNavigator)
│   ├── UserAgent/       # UA 커스터마이징
│   └── WebView/         # WebViewContainer, WebViewNavigator, WebViewScripts
├── Shared/
│   ├── Components/      # GlassIconButton, GlassActionButton, ChipButton, ScrollNavigationButtons, ShareSheet, JsonEditor/
│   ├── Constants/       # BarConstants (레이아웃 상수)
│   ├── Extensions/      # ColorExtensions, DeviceUtilities, URLValidator, SheetModifiers
│   └── URLStorageManager.swift  # Bookmarks & history (singleton)
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

### JavaScript Bridge Architecture

**Core Data Flow**:
- JavaScript hook injection → WKScriptMessageHandler → @Observable Manager → SwiftUI binding

**DevTools Managers** (`WebViewNavigator`에 포함):
- `ConsoleManager` - console.log/dir/time, %c formatting, array chunking
- `NetworkManager` - fetch/XHR interception, resource timing
- `StorageManager` - localStorage, sessionStorage, cookies (SWR pattern)

**Key Files** (WebViewScripts series):
- `WebViewScripts.swift` - Base hook injection
- `WebViewScripts+Console.swift` - console methods + %c CSS parsing
- `WebViewScripts+Network.swift` - fetch/XHR + timing API
- `WebViewScripts+Emulation.swift` - User agent, viewport
- `WebViewScripts+Resource.swift` - Static resource tracking

### JavaScript String Escape

Always use `JSONSerialization` for string safety:
```swift
// ❌ Breaks on special chars
let script = "storage.setItem('\(key)', '\(value)');"

// ✅ Safe escape
guard let keyData = try? JSONSerialization.data(withJSONObject: key, options: .fragmentsAllowed),
      let jsonKey = String(data: keyData, encoding: .utf8) else { return }
let script = "storage.setItem(\(jsonKey), ...);"  // quotes included
```

### Tree View Expand/Collapse

Use path-based stable IDs, not UUID:
```swift
// ✅ Stable ID (preserves expand state across renders)
var id: String { path.joined(separator: ".") }

// ❌ Unstable ID (loses state on re-render)
let id = UUID()  // new UUID every time
```

### Sheet Modifiers

Two styles (Shared/Extensions/SheetModifiers.swift):

| Modifier | Use | Behavior |
|----------|-----|----------|
| `.devToolsSheet()` | DevTools | Resizable (35%, medium, large), auto-expands to large on keyboard |
| `.fullSizeSheet()` | Settings/Info | Always large, `.page` sizing |

**Keyboard handling in sheets**:
```swift
// Auto-dismiss keyboard when tapping outside (use in sheet content)
.dismissKeyboardOnTap()

// DevToolsSheet auto-expands to .large when keyboard appears
```

### StoreKit 2 IAP (StoreManager)

Singleton initialized at app start:
- ✅ `Transaction.updates` listener (app start)
- ✅ `Transaction.unfinished` processing
- ✅ `transaction.finish()` always called
- ✅ `revocationDate` check (refunds)

### AdManager (Interstitial + Banner)

```swift
// Interstitial (per-session per-id, 30% probability)
await AdManager.shared.showInterstitialAd(
    options: AdOptions(id: "feature_name"),
    adUnitId: AdManager.interstitialAdUnitId
)

// Banner (non-premium only)
if !StoreManager.shared.isAdRemoved {
    BannerAdView().frame(height: 50)
}
```

---

## Design System

### Liquid Glass UI (iOS 26)

**Always use `.backport.glassEffect()` for iOS < 26 compatibility via SwiftUIBackports.**

```swift
.backport.glassEffect()                            // default
.backport.glassEffect(in: .capsule)                // capsule
.backport.glassEffect(in: .circle)                 // circle
.backport.glassEffect(in: .rect(cornerRadius: 16)) // rounded
```

**Critical: Apply to Button, not to label inside**
```swift
// ❌ WRONG - modifier on label
Button { action() } label: {
    Image(systemName: "chevron.up.circle.fill")
        .backport.glassEffect(in: .circle)  // Wrong!
}

// ✅ CORRECT - modifier on Button
Button { action() } label: {
    Image(systemName: "chevron.up.circle.fill")
}
.backport.glassEffect(in: .circle)  // Correct!
```

**State visualization pattern**:
```swift
.disabled(!canScroll)
.opacity(canScroll ? 1 : 0.3)  // Liquid Glass preserves subtle visibility
.animation(.easeInOut(duration: 0.2), value: canScroll)
```

### BarConstants (중앙화된 레이아웃)

```swift
enum BarConstants {
    static let barHeight: CGFloat = 64
    static let horizontalPadding: CGFloat = 8
    static let bottomBarSafeAreaRatio: CGFloat = 0.5
    static let webViewOffsetRatio: CGFloat = 0.375
    static let additionalSpacing: CGFloat = 64  // "App" preset
    static var totalUIHeight: CGFloat { barHeight * 2 + additionalSpacing }
    static let sheetDetents: Set<PresentationDetent> = [.fraction(0.35), .medium, .large]
    static let defaultSheetDetent: PresentationDetent = .medium
}
```

---

## Shared Components (Shared/Components/)

| Purpose | Component |
|---------|-----------|
| Circular icon button | `GlassIconButton` (.regular 44×44/18pt, .small 28×28/12pt) |
| Action button | `GlassActionButton` (.default, .destructive, .primary) |
| Copy button | `CopyButton` (text + feedback toast) |
| Type indicator | `TypeBadge` (colored label: JSON/Number/Bool/Text) |
| Chip/tag | `ChipButton`, `ToggleChipButton` |
| Info button | `InfoPopoverButton` |
| DevTools header | `DevToolsHeader` (title + button groups, String/LocalizedStringKey) |
| Scroll buttons | `ScrollNavigationButtons` + `.scrollNavigationOverlay()` |
| Settings row | `SettingToggleRow`, `ColorPickerRow` |
| WebView sizing | `WebViewSizeControl` |
| Layout | `FlowLayout` (tag/chip wrapping) |
| Security banner | `SecurityRestrictionBanner` (SafariVC warning) |
| Share sheet | `ShareSheet` (UIActivityViewController wrapper) |
| JSON editor | `JsonEditor/` (syntax-highlighted editing) |

---

## Code Conventions

| Target | Convention |
|--------|-----------|
| File names, types | PascalCase |
| Variables, functions | camelCase |
| Assets | kebab-case |
| Test files | `winaTests/[Feature]Tests.swift` |

- **Logging**: `os_log` or `Logger` (not `print()` - enforced by SwiftLint)
- 1 file 1 component, ~150 lines ideal
- Sections: `// MARK: -`
- **No barrel exports** (no index.swift)

---

## Localization (Korean)

**Settings 메뉴 번역 규칙**:
- **타이틀**: 영어 원문 유지 (App Settings, Configuration, Emulation 등)
- **설명**: 자연스러운 문장형 한국어

**LocalizedStringKey 패턴**:
- 컴포넌트 파라미터는 `LocalizedStringKey` 사용 (자동 로컬라이제이션)
- `Text(stringVariable)` where `stringVariable: String` → 로컬라이제이션 안됨
- `Text(localizedKey)` where `localizedKey: LocalizedStringKey` → 로컬라이제이션 됨

---

## SwiftLint Configuration

See `.swiftlint.yml` for full rules. Key settings:

**Disabled** (handled by swift-format):
- trailing_whitespace, trailing_comma, opening_brace, colon, comma, line_length

**Limits**:
| Rule | Warning | Error |
|------|---------|-------|
| cyclomatic_complexity | 15 | 25 |
| file_length | 1000 | 3000 |
| function_body_length | 100 | 300 |
| type_body_length | 500 | 800 |
| function_parameter_count | 6 | 8 |

**Custom rule**: `no_print_in_production` - use `os_log` or `Logger`

---

## Common Pitfalls

### 1. `.buttonStyle(.plain)` Touch Area
```swift
// ❌ Only touches icon/text pixels
Button { } label: {
    HStack { ... }
        .padding()
}
.buttonStyle(.plain)
.frame(maxWidth: .infinity)
.contentShape(Rectangle())  // WRONG: outside label

// ✅ Fix - frame + contentShape INSIDE label, after padding
Button { } label: {
    HStack { ... }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())  // CORRECT: inside label
}
.buttonStyle(.plain)
```

### 2. Compiler Type-Check Failure
```swift
// ✅ Extract complex views to @ViewBuilder
@ViewBuilder
private var complexPart: some View { ... }
```

### 3. @Observable Array Element Updates
```swift
// ❌ No update
requests[index].status = 200

// ✅ Replace entire struct
var updated = requests[index]
updated.status = 200
requests[index] = updated
```

### 4. Manager Class Missing @Observable
```swift
// ❌ UI 업데이트 안됨
class SomeManager { var isLoading = false }

// ✅ 정상 작동
@Observable
class SomeManager { var isLoading = false }
```

### 5. JSONSerialization Fragment Strings
```swift
// ✅ Option needed for top-level String
JSONSerialization.data(withJSONObject: "string", options: .fragmentsAllowed)
```

### 6. Sheet Internal Scroll Priority
```swift
.sheet(item: $item) {
    ScrollView { content }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)  // Enable scroll priority
}
```

### 7. Color.secondary/tertiary Type Mismatch
```swift
// These return ShapeStyle, not Color
// ✅ Use explicit Color for type requirements
var color: Color { .gray }

// ✅ But fine in foregroundStyle
.foregroundStyle(.secondary)
```

### 8. GeometryReader + Keyboard: Static Value Bug
```swift
// ❌ bottomPadding is let constant - won't update when keyboard appears
.overlay {
    GeometryReader { proxy in
        MyView(bottomPadding: calculatePadding(proxy.safeAreaInsets.bottom))
    }
}

// ✅ Move GeometryReader inside, or pass calculator closure
struct MyView: View {
    let paddingCalculator: (CGFloat) -> CGFloat

    var body: some View {
        GeometryReader { proxy in
            let padding = paddingCalculator(proxy.safeAreaInsets.bottom)
            // content uses dynamic padding
        }
    }
}
```

### 9. @MainActor Singleton Manager Pattern
```swift
// ✅ Correct pattern for UI-bound singleton managers
@Observable
@MainActor
final class SomeManager {
    static let shared = SomeManager()
    private init() {}

    // All properties automatically MainActor-isolated
    var someState: Bool = false
}

// Usage - no await needed when already on MainActor
func viewAction() {
    SomeManager.shared.someState = true
}
```

---

## Troubleshooting

### Xcode Build Failures
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean -project wina.xcodeproj
```

### SwiftLint "Unable to Read File"
```bash
brew uninstall swiftlint && brew install swiftlint
```

### WebView JavaScript Injection Fails
- Only inline scripts work (external fetch blocked by CORS)
- Use `evaluateJavaScript()` only

### Network Monitoring Missing
- Enable "Preserve Network Log" toggle
- SafariVC: network data unavailable (security)

---

## Version Requirements

| Tool | Version | Required |
|------|---------|----------|
| Xcode | 16.0+ | ✅ |
| iOS Target | 18.4+ | ✅ |
| SwiftLint | 0.62.2+ | ✅ (pre-commit) |
| swift-format | 6.2.1+ | 🟡 (optional) |
| Google Mobile Ads | 11.0+ | ✅ |
| Runestone | latest | ✅ |
