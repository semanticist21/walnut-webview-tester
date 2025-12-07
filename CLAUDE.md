# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wallnut (wina)** - iOS WKWebView 테스터 앱

WKWebView의 다양한 설정 옵션을 실시간으로 테스트하고 검증하기 위한 도구. 개발자가 WebView 동작을 빠르게 확인하고 디버깅할 수 있도록 지원.

### 주요 기능 (계획)
- WKWebView 설정 옵션 토글 (JavaScript, 쿠키, 줌, 미디어 자동재생 등)
- User-Agent 커스터마이징
- URL 입력 및 웹페이지 로딩 테스트
- WebView 이벤트/콜백 로깅

## Build & Run

```bash
# Xcode로 빌드
open wina.xcodeproj
# Cmd+R로 실행

# CLI 빌드 (시뮬레이터)
xcodebuild -project wina.xcodeproj -scheme wina -sdk iphonesimulator build

# 문법 검사만 (빠름)
xcodebuild -project wina.xcodeproj -scheme wina -sdk iphonesimulator build -dry-run 2>&1 | head -50
```

## Architecture

SwiftUI 기반 단일 타겟 iOS 앱. 최소 지원 버전: iOS 26.1 (Tahoe)

### 현재 구조
```
wina/
├── winaApp.swift      # App entry point (@main)
├── ContentView.swift  # Root view + 재사용 컴포넌트
└── Assets.xcassets/   # App icons, colors
```

### 확장 시 목표 구조
```
wina/
├── App/                 # App entry point
├── Features/            # 기능별 모듈 (WebView/, Settings/)
├── Shared/Components/   # 재사용 컴포넌트
└── Resources/           # Assets
```

### 현재 구현된 컴포넌트 (ContentView.swift)
- `ChipButton` - Glass effect가 적용된 탭 가능한 칩 버튼
- `FlowLayout` - 자동 줄바꿈되는 커스텀 Layout 프로토콜 구현

## Design System

**Liquid Glass UI** - iOS 26 (Tahoe) 공식 Glass Effect 사용

### 핵심 API
```swift
.glassEffect()                           // 기본
.glassEffect(in: .capsule)               // 캡슐 shape
.glassEffect(in: .rect(cornerRadius: 16)) // 라운드 사각형
.glassEffect(.regular, in: .capsule)     // 스타일 지정
```

### 디자인 원칙
- `.glassEffect()` modifier 사용 (Material 대신)
- 시스템 기본 배경 유지 (임의 배경색 X)
- `.secondary`, `.primary` 등 시스템 색상 활용

## Code Conventions

### Naming

| 대상 | 컨벤션 | 예시 |
|------|--------|------|
| 파일명, 타입 | PascalCase | `ContentView.swift`, `struct SettingsView` |
| 변수, 함수 | camelCase | `urlText`, `func loadPage()` |
| 에셋 | kebab-case | `app-icon` |

### File Organization
- **1파일 1컴포넌트** 원칙 (public View 기준)
- 150줄 이하 유지 권장
- 해당 파일 전용 helper는 같은 파일에 `private`으로 선언 가능

### 작업 규칙
- 끝나면 항상 문법검사 수행
- 빌드 검증은 통합적인 작업 이후에만 확인 (시간 소요)

## Image Conversion

SVG → PNG 변환 시 `rsvg-convert` 사용 (ImageMagick은 색상이 어둡게 변환됨)

```bash
# 올바른 방법
rsvg-convert -w 1024 -h 1024 input.svg -o output.png

# 사용하지 말 것 (색상 왜곡)
magick input.svg output.png
```
