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

## Design System

**Glassmorphism UI** - iOS Tahoe (iOS 26) 스타일의 글래스 UI를 목표로 함.

주요 디자인 원칙:
- 반투명 배경 (`.ultraThinMaterial`, `.regularMaterial`)
- 블러 효과와 미묘한 그림자
- 부드러운 모서리 처리
- 배경과 조화로운 색상 오버레이

## Build & Run

```bash
# Xcode로 빌드
open wina.xcodeproj
# Cmd+R로 실행

# CLI 빌드
xcodebuild -project wina.xcodeproj -scheme wina -sdk iphonesimulator build
```

## Architecture

```
wina/
├── winaApp.swift      # App entry point (@main)
├── ContentView.swift  # Root view
└── Assets.xcassets/   # App icons, colors
```

SwiftUI 기반 단일 타겟 iOS 앱. 최소 지원 버전: iOS 26.1 (Tahoe)

## Tech Stack

- SwiftUI
- WKWebView (WebKit)
- Swift 5.0
- Xcode 16+
