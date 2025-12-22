# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wallnut (wina)** - WKWebView & SFSafariViewController 테스터 앱

WKWebView와 SFSafariViewController 설정을 실시간 테스트하는 개발자 도구. SwiftUI 기반, iOS 26.1+ (Tahoe), ~100 Swift files

**주요 기능**:
- **WKWebView**: 설정 옵션 테스트, DevTools (Console/Network/Storage/Performance/Sources/Accessibility), 스크린샷
- **SFSafariViewController**: Safari 쿠키/세션 공유, Content Blocker, Reader Mode, Safari 확장 지원
- **공통**: URL 테스트, API Capability 감지, 북마크, 반응형 크기 조절

**Recent Focus** (as of Dec 22, 2024):
- ✅ Scroll buttons implementation (NetworkView, PerformanceView, StorageView, AccessibilityAuditView)
  - glassEffect modifier placement fix: apply to Button, not label
  - .backport.glassEffect(in: .circle) for iOS compatibility
  - State-based opacity/disabled visualization with smooth animations
- ✅ StorageView UX: URL change detection (Timer-based polling) even during drawer interaction
- Console %c CSS styling (color, background-color, font-weight, font-size)
- Console array chunking for large outputs (100+ items → collapsed groups)
- Network tab scroll buttons (bottom-right, Liquid Glass design)
- Fetch/XHR filter separation in Network tab

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

# Check for print() - must be 0 results
swiftlint lint | grep "no_print_in_production"
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
│   ├── Ad/              # AdManager (Google AdMob interstitial)
│   ├── Accessibility/   # AccessibilityAuditView (axe-core 기반)
│   ├── AppBar/          # OverlayMenuBars, 버튼들
│   ├── Settings/        # SettingsView, ConfigurationSettingsView, SafariVCSettingsView, EmulationSettingsView
│   ├── Console/         # ConsoleManager + UI (JS console 캡처 + %c styling + array chunking)
│   ├── Network/         # NetworkManager + UI (fetch/XHR + scroll buttons + domain filtering)
│   ├── Storage/         # StorageManager + UI (localStorage/sessionStorage/cookies, SWR 패턴)
│   ├── Performance/     # Web Vitals + Navigation Timing
│   ├── Sources/         # DOM Tree, Stylesheets, Scripts, CSS specificity override tracking
│   ├── Resources/       # Network 탭 리소스 타이밍 & 크기
│   ├── Info/            # SharedInfoWebView, API Capability 감지, 벤치마크
│   ├── UserAgent/       # UA 커스터마이징
│   ├── WebView/         # WebViewContainer, WebViewNavigator, WebViewScripts
│   └── About/           # AboutView, StoreManager (IAP)
├── Shared/
│   ├── Components/      # GlassIconButton, GlassActionButton, ChipButton, InfoPopoverButton, SettingToggleRow, DevToolsHeader, FlowLayout, JsonEditor/
│   ├── Constants/       # BarConstants (레이아웃 상수)
│   └── Extensions/      # ColorExtensions, DeviceUtilities, URLValidator, SheetModifiers
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
- `ConsoleManager` - console.log, console.dir, console.time, %c formatting, styled segments
- `NetworkManager` - fetch/XHR interception, resource timing, cross-origin filtering
- `StorageManager` - localStorage, sessionStorage, cookies (with SWR pattern)

**Key Files** (WebViewScripts series):
- `WebViewScripts.swift` - Base hook injection
- `WebViewScripts+Console.swift` - console methods + %c CSS parsing + styledSegments JSON
- `WebViewScripts+Network.swift` - fetch/XHR + timing API
- `WebViewScripts+Emulation.swift` - User agent, viewport
- `WebViewScripts+Resource.swift` - Static resource tracking

**Important**: No `print()` in managers. Use `os_log` or `Logger` (SwiftLint enforces: `no_print_in_production`)

### Console Features

#### %c CSS Styling (WebViewScripts+Console.swift:76)
```javascript
console.log("%cRed Bold", "color: red; font-weight: bold");
console.log("%cSuccess%cDetailed", "color: green", "color: gray");
```

Supported CSS:
- `color: <color-name | hex>` - text color (red, #FF0000)
- `background-color: <color>` - background
- `font-weight: bold` - bold text
- `font-size: <number>px` - font size

**Implementation**: `formatConsoleMessage()` detects %c → `parseCSS()` parses → `styledSegments` JSON → ConsoleValueView renders with SwiftUI modifiers

#### Array Chunking (ConsoleValue.swift:133)
Large arrays (100+ items) auto-divide into 100-item chunks with collapsed UI:
```swift
var chunks: [(range: Range<Int>, label: String, elements: [ConsoleValue])]? {
    guard elements.count > chunkSize else { return nil }
    // [0...99], [100...199], etc. with item counts
}
```

Shows preview + collapsed chunks, user expands as needed. Memory efficient for 10K+ items.

#### console.time/timeLog/timeEnd
```javascript
console.time("fetch");  // start
console.timeLog("fetch");  // "fetch: 123.456ms" (continue timing)
console.timeEnd("fetch");  // "fetch: 456.789ms" (delete timer)
```

Timer maintained across timeLog, only deleted on timeEnd. 3-digit millisecond precision.

### Network Tab Architecture

**Recent Changes**:
- Fetch + XHR unified filter (both captured as fetch hooks)
- Separate `.fetch` and `.xhr` cases in `NetworkResourceFilter` enum
- Cross-origin resource domain-based filtering
- Scroll buttons (bottom-right, Liquid Glass 0.3 opacity when inactive)

**Scroll Buttons** (NetworkView.swift):
- Uses `onScrollGeometryChange(for: Double.self)` (iOS 26 standard API)
- Position: `.bottomTrailing` with fixed frame (prevents layout shifts)
- Opacity: 0.3 inactive, 1.0 active (Liquid Glass principle)
- Animation: 0.2s easeInOut fade

**NetworkManager struct**:
```swift
struct NetworkRequest: Identifiable {
    let id: UUID
    let method: String
    let url: String
    let status: Int?
    let duration: Double?  // milliseconds
    let resourceType: String  // xhr, fetch, image, etc
    let requestHeaders, responseHeaders: [String: String]
    let requestBody, responseBody: String?
    let initiator: String?  // script file:line
}
```

### 스크린샷 (WKWebView only)

```swift
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
```

Flash effect via navigator.showScreenshotFlash state. Sound: `AudioServicesPlaySystemSound(1108)`. Requires `NSPhotoLibraryAddUsageDescription` in Info.plist.

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

### StoreKit 2 IAP (StoreManager)

Singleton initialized at app start. Best practices:
```swift
// winaApp.swift
_ = StoreManager.shared

// StoreManager
@Observable
final class StoreManager {
    static let shared = StoreManager()
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await processUnfinishedTransactions()
            await checkEntitlements()
        }
    }
}
```

**Checklist**:
- ✅ `Transaction.updates` listener (app start)
- ✅ `Transaction.unfinished` processing
- ✅ `transaction.finish()` always called
- ✅ `revocationDate` check (refunds)
- ✅ `Task.detached` background execution

### Theme/ColorScheme

System default → user toggle Light↔Dark:
```swift
// winaApp.swift
@AppStorage("colorSchemeOverride") private var colorSchemeOverride: String?
// nil = system, "light" = light, "dark" = dark
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
}
```

Always use for layout (not hardcoded values).

### Sheet Modifiers

Two styles (Shared/Extensions/SheetModifiers.swift):

| Modifier | Use | Behavior |
|----------|-----|----------|
| `.devToolsSheet()` | DevTools | Resizable (35%, medium, large), iPad `.form` |
| `.fullSizeSheet()` | Settings/Info | Always large, `.page` sizing |

```swift
.sheet(isPresented: $showConsole) {
    ConsoleView(...)
        .devToolsSheet()  // resizable
}

.sheet(isPresented: $showSettings) {
    SettingsView(...)
        .fullSizeSheet()  // always full
}
```

### AdManager (Interstitial + Banner)

**Interstitial** (full-screen, per-session per-id):
```swift
await AdManager.shared.showInterstitialAd(
    options: AdOptions(id: "feature_name"),  // 30% probability default
    adUnitId: AdManager.interstitialAdUnitId
)
```

Check order: `isAdRemoved` → `shownAdIds` → probability → load

**Banner** (bottom fixed, non-premium only):
```swift
if !StoreManager.shared.isAdRemoved {
    BannerAdView().frame(height: 50)
}
```

### Eruda Mode (in-page console)

WKWebView only. Third-party debugging tool, parallel with DevTools.
```swift
@AppStorage("erudaModeEnabled") var erudaModeEnabled = false

if erudaModeEnabled {
    let erudaScript = "..."  // injected bundle
    webView.evaluateJavaScript(erudaScript)
}
```

Features: opt-in, preserves state on close, no DevTools overlap.

---

## ⚠️ Common Pitfalls

### 1. `.buttonStyle(.plain)` Touch Area

`.plain` only touches icon pixels:
```swift
// ❌ No touch
Button { } label: {
    Image(systemName: "xmark")
        .frame(width: 44, height: 44)
}.buttonStyle(.plain)

// ✅ Fix
.contentShape(Circle())  // Enable full area
```

### 2. Compiler Type-Check Failure

Complex view expressions in `body`:
```swift
// ✅ Extract to @ViewBuilder
@ViewBuilder
private var complexPart: some View { ... }
var body: some View { VStack { complexPart } }
```

### 3. ZStack Overlay Gesture Conflict

Spacer captures touch:
```swift
// ✅ Use frame instead
HStack { buttons }
    .frame(maxHeight: .infinity, alignment: .top)
```

### 4. WebView Gesture Priority

```swift
// ✅ Overlay gesture priority
.highPriorityGesture(isOverlayMode ? dragGesture : nil)
```

### 5. @Observable Array Element Updates

Changing struct properties individually doesn't trigger UI update:
```swift
// ❌ No update
requests[index].status = 200

// ✅ Replace entire struct
var updated = requests[index]
updated.status = 200
requests[index] = updated
```

### 6. UIViewRepresentable Height Calculation

Use `sizeThatFits` for intrinsic size:
```swift
// ✅ iOS 16+
func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width > 0 else { return nil }
    let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: size.height)
}
```

### 7. Equatable Property Comparison

Must compare all mutable properties:
```swift
// ✅ Include all fields that can change
static func == (lhs: Request, rhs: Request) -> Bool {
    lhs.id == rhs.id &&
    lhs.status == rhs.status &&
    lhs.endTime == rhs.endTime
}
```

### 8. Layout Shift in Empty State

ScrollView behavior differs from VStack:
```swift
// ✅ Wrap in ScrollView for consistent layout
var emptyState: some View {
    GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("No data")
                Spacer(minLength: 0)
            }
            .frame(width: geometry.size.width)
            .frame(minHeight: geometry.size.height)
        }
    }
}
```

### 9. Sheet Internal Scroll Priority

Enable scroll priority with `.presentationContentInteraction(.scrolls)`:
```swift
.sheet(item: $item) {
    ScrollView { content }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
}
```

### 10. JSONSerialization Fragment Strings

Top-level string needs `.fragmentsAllowed`:
```swift
// ✅ Option needed for String
JSONSerialization.data(withJSONObject: "string", options: .fragmentsAllowed)
```

### 11. Color.secondary/tertiary Type Mismatch

These return `ShapeStyle`, not `Color`:
```swift
// ✅ Use explicit Color
var color: Color {
    case .string: return .gray
    case .empty: return .gray.opacity(0.5)
}

// ✅ But fine in foregroundStyle
.foregroundStyle(.secondary)
```

### 12. LazyVStack Limitations

Can't do bidirectional scroll + text selection:
```swift
// ✅ Use UIScrollView + UITextView for HTML/code
struct HTMLTextView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.textContainer.widthTracksTextView = false
        scrollView.addSubview(textView)
        return scrollView
    }
}
```

Caution: UITextView loads entire text in memory. Cap large text at maxLines.

### 13. JavaScript Type Casting

Use `[String: Any]` not `[String: String]`:
```swift
// ✅ Preserves Bool, Int types
let props = item["properties"] as? [[String: Any]] ?? []
let isImportant = propDict["i"] as? Bool ?? false
```

### 14. glassEffect Modifier on Button vs Label

**❌ WRONG**: Applying to Image/label inside Button:
```swift
Button(
    action: { action() },
    label: {
        Image(systemName: "chevron.up.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white)
            .backport
            .glassEffect(in: .circle)  // Wrong placement!
    }
)
```

**✅ CORRECT**: Apply to Button itself:
```swift
Button(
    action: { action() },
    label: {
        Image(systemName: "chevron.up.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white)
    }
)
.backport
.glassEffect(in: .circle)  // Apply to Button, not label
```

**Why**: The modifier chain matters. Modifiers on the label don't affect the button's touch area or full background. Apply modifiers to the Button itself for proper Liquid Glass effect and interaction.

**iOS Compatibility**: Always use `.backport.glassEffect()` for iOS < 26 support via SwiftUIBackports.

---

## Design System

**Liquid Glass UI** (iOS 26):
```swift
.backport.glassEffect()                            // default
.backport.glassEffect(in: .capsule)                // capsule
.backport.glassEffect(in: .circle)                 // circle
.backport.glassEffect(in: .rect(cornerRadius: 16)) // rounded
```

**Important**: Always use `.backport.glassEffect()` for iOS < 26 compatibility via SwiftUIBackports extension.

Principle: Use `.glassEffect()`, maintain system background, use `.primary`/`.secondary` colors.

For inactive/translucent state, use `.opacity(0.3)` (Liquid Glass principle preserves subtle visibility).

**Scroll Button Pattern** (NetworkView, PerformanceView, StorageView, AccessibilityAuditView):
```swift
Button(
    action: { scrollUp(proxy: scrollProxy) },
    label: {
        Image(systemName: "chevron.up.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white)
    }
)
.backport
.glassEffect(in: .circle)
.disabled(!canScroll || scrollOffset <= 20)
.opacity(canScroll && scrollOffset > 20 ? 1 : 0.3)
.animation(.easeInOut(duration: 0.2), value: canScroll && scrollOffset > 20)
```

Key points:
- Apply `.glassEffect()` to Button, not to Image label inside
- Use `.backport` for iOS compatibility
- Combine with `.disabled()` and `.opacity()` for state visualization
- Use `.animation()` for smooth opacity transitions

---

## Shared Components (Shared/Components/)

| Purpose | Component |
|---------|-----------|
| Circular icon button | `GlassIconButton` (.regular 44×44, .small 28×28) |
| Action button | `GlassActionButton` (.default, .destructive, .primary) |
| Copy button | `CopyButton`, `CopyIconButton`, `CopiedFeedbackToast` |
| Type badge | `TypeBadge` |
| Chip/tag | `ChipButton`, `ToggleChipButton` |
| Info button | `InfoPopoverButton` (Generic ShapeStyle) |
| Deprecation warning | `DeprecatedPopoverButton` |
| Security restriction | `SecurityRestrictionBanner` |
| Settings toggle | `SettingToggleRow` |
| Color picker | `ColorPickerRow` |
| Auto-wrap layout | `FlowLayout` |
| DevTools header | `DevToolsHeader` (2-row: title center, buttons split) |
| WebView size control | `WebViewSizeControl` |

### DevToolsHeader Layout

2-row structure keeps title from shifting:
```
        [Title]              ← Row 1: center
[Left Buttons] ⟷ [Right Buttons]  ← Row 2: split
```

Left: Close → Actions. Right: Toggles.

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
- Feature-local helpers: `private` in same file
- Protocols: separate Extension
- Sections: `// MARK: -`
- **No barrel exports** (no index.swift exporting everything)

---

## SwiftLint Configuration

See `.swiftlint.yml` for rules. Key points:

**Disabled** (handled by swift-format or too noisy):
- trailing_whitespace, trailing_comma, opening_brace, colon, comma, line_length, multiline_arguments

**Enabled rules** emphasize clarity:
- cyclomatic_complexity (warning: 15, error: 25)
- file_length (warning: 1000, error: 3000)
- function_body_length (warning: 100, error: 300)
- identifier_name (min: 2, excluded: i, j, k, id, ok, etc)

**Custom rules**:
- `no_print_in_production` - use `os_log` or `Logger`

---

## Performance Notes

### Array Rendering
- <100 items: render all
- 100-10K items: chunked (100 per group, collapsed by default)
- 10K+ items: smooth interaction after initial load (~200-500ms for 1000 chunks)

### Memory Management
- @Observable patterns preferred (no retain cycle issues vs ObservableObject)
- [weak self] in closures
- Remove observers in deinit
- Lazy var for deferred initialization

### SwiftUI
- @State scope: minimal
- 1000+ items: LazyVStack (but watch bidirectional scroll/selection limits)
- Avoid Reflection, force unwrap (!), synchronous network calls
- Value types (struct) > classes for models

---

## Recent Session Work

**Latest Changes** (Dec 2024):
- ✅ Fixed SwiftLint violations in ResponseFormatterView.swift (cyclomatic complexity, duplicate conditions, unused parameters)
- ✅ Fixed StackTraceView button closure syntax (trailing closure)
- ✅ Fixed ConsoleValue identifier names (s→stringValue, n→numberValue, l→lhsValue)
- ✅ Fixed ConsoleValueView unused parameters and trailing closure syntax
- ✅ Verified 0 violations in all modified files

**Know When to Lint**: After EVERY change. Run `swiftlint lint --fix && swiftlint lint` before commit.

---

## Troubleshooting

### Xcode Build Failures
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean -project wina.xcodeproj
open wina.xcodeproj && Cmd+R
```

### SwiftLint "Unable to Read File"
```bash
brew uninstall swiftlint && brew install swiftlint
```

### WebView JavaScript Injection Fails
- Only inline scripts work (external fetch blocked by CORS)
- Use `evaluateJavaScript()` only
- Console logging works: `console.log()` hooks captured

### Network Monitoring Missing
- Enable "Preserve Network Log" toggle
- Keep console/network tabs open during load
- SafariVC: network data unavailable (security)

### High Memory Usage
- Close DevTools periodically
- Check ConsoleManager/NetworkManager cache sizes
- Consider clearing on app background

---

## Version Requirements

| Tool | Version | Required |
|------|---------|----------|
| Xcode | 16.1+ | ✅ |
| iOS Target | 26.1+ | ✅ |
| SwiftLint | 0.62.2+ | ✅ (pre-commit) |
| swift-format | 6.2.1+ | 🟡 (optional, avoid complex SwiftUI) |
| Google Mobile Ads | 11.0+ | ✅ (ads) |
| Runestone | latest | ✅ (Sources view) |
