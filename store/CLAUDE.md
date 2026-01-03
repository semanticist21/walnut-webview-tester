# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

App Store Connect metadata and screenshot management for Walnut iOS app. Contains localized metadata (39 languages) and screenshot generation tools.

## Commands

### Upload Metadata to App Store Connect
```bash
# Requires venv with dependencies
cd store && source .venv/bin/activate
python3 upload-metadata.py
```

### Generate Localized Screenshots
```bash
python3 generate-localized-screenshots.py
```

### SVG to PNG Conversion
```bash
# Single file
magick en/1.svg en/1.png

# Note: magick may not render gradients correctly
# For production, use direct composition:
magick -size 1320x2868 gradient:'#E8F4FD-#D4E7F7' bg.png
magick bg.png mockup.png -gravity center -composite output.png
```

## Structure

```
store/
├── {locale}/              # 39 language folders (ar-SA, ca, cs, ..., zh-Hant)
│   ├── 1.svg - 3.svg     # iPhone 6.9" screenshots (1320x2868)
│   └── ipad-1.svg - 3.svg # iPad 13" screenshots (2064x2752)
├── en/                    # English source screenshots
├── screenshots/           # Source mockup PNGs
├── screenshot-template-*.svg  # SVG templates
├── upload-metadata.py     # App Store Connect API uploader
└── generate-localized-screenshots.py  # Screenshot localizer
```

## Key Files

### upload-metadata.py
- Uploads name, subtitle, description, keywords, whatsNew, promotionalText
- Uses App Store Connect API with JWT auth
- METADATA dict contains all 39 language translations
- Fallback locales: en-AU/CA/GB→en-US, es-MX→es-ES, fr-CA→fr-FR, pt-PT→pt-BR

### generate-localized-screenshots.py
- Generates localized SVG screenshots from English templates
- TRANSLATIONS dict: (title1, desc1, title2, desc2, title3, desc3, title_ipad3, desc_ipad3)
- Replaces text in SVG templates with localized strings

## App Store Limits

| Field | Max Length |
|-------|------------|
| Name | 30 chars |
| Subtitle | 30 chars |
| Keywords | 100 chars |
| Description | 4000 chars |
| Promotional Text | 170 chars |

## App Store Metadata Rules

- **No "iOS" keyword in promotional text**: Apple rejects promotional text containing "iOS". Use feature-focused descriptions instead.
- **API submission permission**: `appStoreVersionSubmissions` may reject `CREATE` with 403 unless the API key has sufficient App Store Connect role (e.g., Admin/App Manager). If blocked, submit via UI or use a higher-privilege key.

### Promotional Text Reference (170 chars max)

All locales use this canonical text pattern. Update upload-metadata.py when changing.

| Locale | Promotional Text |
|--------|------------------|
| en-US | Test WebView easily with Walnut. Quick URL management with bookmarks and history, plus debugging with Console, Network, and SourceView. |
| ko | Walnut으로 WebView 테스트를 쉽게 해보세요. 북마크·히스토리 기반 URL 관리와 Console, Network, SourceView 내장 도구로 디버깅이 쉽습니다. |
| ja | WalnutでWebViewテストを簡単に。ブックマーク/履歴でURL管理が速く、Console・Network・SourceViewなど内蔵ツールでデバッグも簡単です。 |
| zh-Hans | 用Walnut轻松测试WebView。通过书签/历史管理URL快速访问，并用Console、Network、SourceView等内置工具轻松调试。 |
| zh-Hant | 用Walnut輕鬆測試WebView。透過書籤/歷史管理URL快速存取，並用Console、Network、SourceView等內建工具輕鬆除錯。 |
| de-DE | WebView-Tests ganz einfach mit Walnut. Schneller URL-Zugriff über Lesezeichen und Verlauf, Debugging mit Console, Network und SourceView. |
| fr-FR | Testez WebView facilement avec Walnut. Gestion rapide des URL via favoris et historique, et débogage avec Console, Network et SourceView. |
| es-ES | Pruebe WebView fácilmente con Walnut. Gestión rápida de URL con marcadores e historial, y depuración con Console, Network y SourceView. |

See `upload-metadata.py` METADATA dict for all 39 translations.

## Screenshot Specs

| Device | Size |
|--------|------|
| iPhone 6.9" | 1320x2868 |
| iPad 13" | 2064x2752 |

## Python Environment

```bash
# Setup (one-time)
python3 -m venv .venv
source .venv/bin/activate
pip install PyJWT requests cryptography
```
