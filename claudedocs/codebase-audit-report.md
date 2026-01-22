# Walnut (wina) Codebase Audit Report

**Date**: 2026-01-22
**Scope**: 121 Swift files, ~15,000 LOC
**Auditor**: Claude Code

---

## Executive Summary

| Category | Critical | Important | Recommended | Total |
|----------|----------|-----------|-------------|-------|
| Bug Patterns | 3 | 4 | 2 | 9 |
| UX/UI Issues | 3 | 15 | 5 | 23 |
| Code Quality | 0 | 5 | 3 | 8 |
| Performance | 2 | 3 | 2 | 7 |
| Memory | 2 | 2 | 1 | 5 |
| **Total** | **10** | **29** | **13** | **52** |

**SwiftLint Status**: ✅ 0 violations (clean)
**TODO/FIXME Comments**: ✅ None found

---

## 1. Bug Patterns & Potential Errors

### 1.1 🔴 CRITICAL: Weak Reference 누락

| File | Line | Issue |
|------|------|-------|
| `NetworkManager.swift` | 181-188 | `DispatchQueue.main.async { self.requests... }` - weak self 누락 |
| `NetworkManager.swift` | 209-221 | `DispatchQueue.main.async { self.requests... }` - 동일 |
| `ResourceManager.swift` | 64-69 | `DispatchQueue.main.async { self.resources... }` - weak self 누락 |

**Fix**:
```swift
DispatchQueue.main.async { [weak self] in
    guard let self else { return }
    // ...
}
```

### 1.2 🔴 CRITICAL: 에러 로깅 없음

| File | Line | Issue |
|------|------|-------|
| `WebViewRecorder.swift` | 84-87 | `catch { return false }` - AVAssetWriter 초기화 실패 원인 불명 |
| `StoreManager.swift` | 52-58 | `catch { /* Silent */ }` - 제품 로딩 실패 무시 |

### 1.3 🟡 IMPORTANT: Force Unwrap (안전하지만 코드 스타일 이슈)

| File | Line | Issue |
|------|------|-------|
| `NetworkView.swift` | 519, 521, 523, 540, 542, 545, 547 | `filteredRequests.first!` - isEmpty 체크 후지만 권장하지 않음 |

**Fix**: `guard let first = filteredRequests.first else { return }` 패턴 사용

### 1.4 🟡 IMPORTANT: MainActor 권장

| File | Line | Current |
|------|------|---------|
| `ConsoleView.swift` | 227 | `DispatchQueue.main.async { ... }` |
| `PermissionsSettingsView.swift` | 95, 107, 178 | `DispatchQueue.main.async { ... }` |

**Fix**: `@MainActor` 함수로 변환 권장 (Swift 5.9+ 모범 사례)

---

## 2. UX/UI 불일치 및 접근성

### 2.1 🔴 CRITICAL: 접근성 누락

**accessibilityLabel 없는 인터랙티브 요소:**

| Component | Files | Impact |
|-----------|-------|--------|
| 스크롤 버튼 | `ScrollNavigationButtons.swift:84-88` | VoiceOver 사용자 조작 불가 |
| 네트워크 필터 칩 | `NetworkView.swift` | 필터 목적 전달 불가 |
| 콘솔 입력 필드 | `ConsoleView.swift:798` | 입력 목적 불명 |
| DOM 트리 노드 | `SourcesRowViews.swift` | 트리 구조 이해 불가 |
| 스토리지 아이템 | `StorageView.swift` | 데이터 유형 전달 불가 |

### 2.2 🔴 CRITICAL: Dynamic Type 미지원

**Hardcoded 폰트 크기 발견 (50+ 개소):**

| Pattern | Files | Count |
|---------|-------|-------|
| `.font(.system(size: 9-14))` | Console, Chip, Copy 등 | 40+ |
| `.font(.system(size: 11-13, weight:))` | 여러 컴포넌트 | 15+ |

**Fix**: `.font(.system(.caption))` 등 시맨틱 스타일 사용

### 2.3 🟡 IMPORTANT: 버튼 스타일 불일치

| Pattern | Usage | Recommendation |
|---------|-------|----------------|
| `GlassIconButton` | AppBar 버튼들 ✅ | 유지 |
| 직접 Button + glassEffect | `BackButton.swift`, `ScrollNavigationButtons.swift` | GlassIconButton으로 통합 |
| Plain Button (glass 없음) | `NetworkDetailView`, `ConsoleView` | glassEffect 추가 |

### 2.4 🟡 IMPORTANT: 색상 관리 불일치

| 용도 | 현재 상태 | 권장 |
|------|-----------|------|
| 선택 상태 | `.blue` 또는 `.mint` 혼용 | 전체 `.mint` 통일 |
| 배경 강조 | `opacity(0.1)`, `opacity(0.15)` 혼용 | Color extension 생성 |
| 정보 색상 | `.cyan`, `.blue` 혼용 | 단일 색상 통일 |

**권장 Color Extension:**
```swift
extension Color {
    static let surfaceLight = Color.secondary.opacity(0.1)
    static let surfaceMedium = Color.secondary.opacity(0.15)
    static let accentTint = Color.mint
}
```

### 2.5 🟡 IMPORTANT: 패딩값 불일치

| Component | Horizontal | Vertical |
|-----------|------------|----------|
| CopyButton | 10 | 6 |
| ChipButton | 12 | 8 |
| GlassActionButton | 16 | 10 |
| HeaderActionButton | 10 | 6 |

**권장**: `SpacingConstants` 생성하여 통일

---

## 3. 코드 품질

### 3.1 🟡 IMPORTANT: Unused Import

| File | Import | Status |
|------|--------|--------|
| `PermissionsSettingsView.swift` | `import Combine` | **UNUSED** - 삭제 가능 |

### 3.2 🟡 IMPORTANT: 불일치하는 Import

| File | Current | Recommended |
|------|---------|-------------|
| `winaApp.swift` | `import os` | `import os.log` |
| `WKWebViewCoordinator+Console.swift` | `import os` | `import OSLog` |

### 3.3 🟡 IMPORTANT: 중복 메서드

| File | Issue |
|------|-------|
| `PermissionsSettingsView.swift:71-89` | `permissionText()` 두 번 오버로드 - 로직 거의 동일 |

### 3.4 🟢 RECOMMENDED: 로컬라이제이션 혼용

- `Text("string")`: 268개 (자동 로컬라이제이션)
- `LocalizedStringKey` 명시: 64개
- `Text(verbatim:)`: 사용 중

**현황**: 대부분 올바르게 사용되나, 일부 하드코딩된 영어 문자열 존재

---

## 4. 성능 이슈

### 4.1 🔴 CRITICAL: View Body 내 Sorting

| File | Line | Issue |
|------|------|-------|
| `PerformanceView.swift` | 668 | `ForEach(resources.sorted(...).prefix(15))` - 매 렌더마다 정렬 |

**Fix**: Computed property로 이동
```swift
private var sortedResources: [ResourceTiming] {
    resources.sorted(by: { $0.displaySize > $1.displaySize }).prefix(15).map { $0 }
}
```

### 4.2 🔴 CRITICAL: 중첩 GeometryReader

| File | Line | Issue |
|------|------|-------|
| `PerformanceView.swift` | 82, 84, 108 | 3단계 중첩 GeometryReader - 불필요한 레이아웃 계산 |

**Fix**: 첫 번째 GeometryReader 제거 (unused), 나머지 통합

### 4.3 🟡 IMPORTANT: Filter-Map 체인

| File | Lines | Pattern |
|------|-------|---------|
| `OverlayMenuBars.swift` | 200, 208, 219, 229 | `.filter { }.map { }` - `compactMap` 권장 |
| `StorageView.swift` | 537 | 이중 정렬 연산 |
| `InfoView.swift` | 250 | `keys.sorted()` 반복 |

### 4.4 🟡 IMPORTANT: Timer in onAppear

| File | Line | Issue |
|------|------|-------|
| `StorageView.swift` | 605 | `Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true)` |

**주의**: Timer 정리 로직 확인 필요 (onDisappear에서 invalidate)

---

## 5. 메모리 이슈

### 5.1 🔴 CRITICAL: Unbounded 배열 성장

| File | Variable | Issue |
|------|----------|-------|
| `ConsoleView.swift` | `logs: [ConsoleLog]` | 무제한 성장, 수동 clear만 가능 |
| `ConsoleView.swift` | `commandHistory: [String]` | 무제한 성장 |

**Fix**: 최대 크기 제한 추가
```swift
private let maxLogs = 5000
private let maxCommandHistory = 100

// 추가 시:
if logs.count > maxLogs {
    logs.removeFirst(logs.count - maxLogs)
}
```

### 5.2 🟡 IMPORTANT: 캐시 만료 없음

| File | Cache | Issue |
|------|-------|-------|
| `NetworkManager.swift` | Response body 파일 캐시 | 수동 삭제만, 자동 만료 없음 |
| `DisplayFeaturesView.swift` | `cachedDisplayInfo` | TTL 없이 영구 저장 |

**Fix**: 시간 기반 캐시 만료 구현

### 5.3 🟢 RECOMMENDED: 필터링 결과 캐싱

| File | Computed Property | Issue |
|------|-------------------|-------|
| `SnippetsView.swift` | `filteredSnippets` | 매번 filter 체인 실행 |

**Fix**: `@State`로 캐싱하고 `onChange`에서 업데이트

---

## 6. Deprecated API 사용

| File | Line | API | Status |
|------|------|-----|--------|
| `SafariVCSettingsView.swift` | 219, 225 | preferredControlTintColor/preferredBarTintColor | iOS 26에서 deprecated (의도적, UI 표시됨) |
| `WebViewContainer.swift` | 502 | 동일 | 의도적 사용 (fallback) |

**현황**: ✅ 올바르게 처리됨 - deprecation 정보 UI에 표시

---

## 7. 권장 수정 우선순위

### 즉시 (이번 릴리스)

1. `NetworkManager.swift`, `ResourceManager.swift` - weak self 추가
2. `ConsoleView.swift` - 로그/히스토리 최대 크기 제한
3. `PerformanceView.swift` - sorted() 를 computed property로 이동
4. `PermissionsSettingsView.swift` - unused Combine import 삭제

### 단기 (다음 릴리스)

5. 접근성: 모든 인터랙티브 요소에 accessibilityLabel 추가
6. 동적 타입: hardcoded 폰트 크기를 시맨틱 스타일로 변환
7. 색상 통일: Color extension 생성 및 적용
8. GeometryReader 중첩 제거

### 장기 (향후 버전)

9. 버튼 스타일 통합 (GlassIconButton)
10. 캐시 만료 로직 구현
11. iPad 최적화
12. MainActor 마이그레이션

---

## 8. 파일별 이슈 카운트

| File | Critical | Important | Recommended |
|------|----------|-----------|-------------|
| NetworkManager.swift | 2 | 1 | 0 |
| ConsoleView.swift | 1 | 2 | 1 |
| PerformanceView.swift | 2 | 1 | 0 |
| ResourceManager.swift | 1 | 0 | 0 |
| StorageView.swift | 0 | 3 | 1 |
| NetworkView.swift | 0 | 2 | 1 |
| ScrollNavigationButtons.swift | 1 | 2 | 0 |
| PermissionsSettingsView.swift | 0 | 2 | 0 |
| WebViewRecorder.swift | 1 | 0 | 0 |
| StoreManager.swift | 1 | 0 | 0 |
| OverlayMenuBars.swift | 0 | 1 | 1 |
| SourcesRowViews.swift | 1 | 1 | 0 |
| (기타 30+ 파일) | 0 | 14 | 9 |

---

## 9. Checklist

```
[ ] 1. Memory Safety
    [ ] NetworkManager weak self 추가
    [ ] ResourceManager weak self 추가
    [ ] Console logs 최대 크기 제한
    [ ] Command history 최대 크기 제한

[ ] 2. Performance
    [ ] PerformanceView sorted() 이동
    [ ] GeometryReader 중첩 제거
    [ ] filter-map → compactMap 변환

[ ] 3. Code Quality
    [ ] Unused import 삭제
    [ ] 에러 로깅 추가

[ ] 4. Accessibility
    [ ] 모든 버튼 accessibilityLabel
    [ ] Dynamic Type 지원

[ ] 5. UI Consistency
    [ ] 색상 통일
    [ ] 버튼 스타일 통일
    [ ] 패딩 상수화
```

---

*Report generated by Claude Code*
