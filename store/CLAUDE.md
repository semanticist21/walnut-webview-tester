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
| en-US | Quickly see how web content behaves in WKWebView and SafariVC. Track root causes with Console, Network, Storage, Performance, and Sources. |
| ko | WKWebView와 SafariVC에서 웹 콘텐츠가 실제로 어떻게 동작하는지 빠르게 확인할 수 있는 개발자용 도구입니다. 콘솔·네트워크·스토리지·성능·소스로 원인을 추적할 수 있습니다. |
| ja | WKWebViewとSafariVCでWebコンテンツがどう動くかを素早く確認できます。Console、Network、Storage、Performance、Sourcesで原因を追えます。 |
| zh-Hans | 快速查看网页内容在WKWebView和SafariVC中的实际表现。通过Console、Network、Storage、Performance和Sources追踪原因。 |
| zh-Hant | 快速查看網頁內容在WKWebView與SafariVC中的實際表現。透過Console、Network、Storage、Performance與Sources追蹤原因。 |
| de-DE | Sehen Sie schnell, wie sich Webinhalte in WKWebView und SafariVC verhalten. Finden Sie Ursachen mit Console, Network, Storage, Performance und Sources. |
| fr-FR | Vérifiez rapidement le comportement du contenu web dans WKWebView et SafariVC. Repérez la cause avec Console, Network, Storage, Performance et Sources. |
| es-ES | Compruebe rápidamente cómo se comporta el contenido web en WKWebView y SafariVC. Localice la causa con Console, Network, Storage, Performance y Sources. |

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
