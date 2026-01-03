#!/usr/bin/env python3
"""
App Store Connect API - Metadata Upload Script
Uploads app metadata for all supported languages
"""

import jwt
import time
import requests
import json
from pathlib import Path

# API Credentials
ISSUER_ID = "a7524762-b1db-463b-84a8-bbee51a37cc2"
KEY_ID = "74HC92L9NA"
PRIVATE_KEY_PATH = Path.home() / "Documents/API/AuthKey_74HC92L9NA.p8"

# App Store Connect API Base URL
BASE_URL = "https://api.appstoreconnect.apple.com/v1"

# Create session with timeout
session = requests.Session()
session.request = lambda method, url, **kwargs: requests.Session.request(session, method, url, timeout=kwargs.pop('timeout', 30), **kwargs)

# All supported locales (40 languages)
LOCALES = [
    "ar-SA", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA", "en-GB", "en-US",
    "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "he", "hi", "hr", "hu", "id",
    "it", "ja", "ko", "ms", "nl-NL", "no", "pl", "pt-BR", "pt-PT", "ro",
    "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"
]

# Metadata translations
# Format: name (30 chars max), subtitle (30 chars max), description (4000 chars max), keywords (100 chars max)
METADATA = {
    "en-US": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """The ultimate developer tool for testing WKWebView and SFSafariViewController configurations in real-time.

KEY FEATURES

WKWebView Testing
• Real-time configuration testing with 20+ options
• Built-in DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript injection and snippet execution
• Custom User-Agent emulation
• Viewport and device emulation

SFSafariViewController Testing
• Safari cookie/session sharing
• Content Blocker support
• Reader Mode configuration
• Safari extension compatibility

Developer Tools
• Console: Capture console.log with %c CSS styling support
• Network: Monitor fetch/XHR requests with timing data
• Storage: View/edit localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) and Navigation Timing
• Sources: DOM tree inspection, stylesheets, scripts
• Accessibility: axe-core based accessibility auditing

Additional Features
• Bookmark management for quick URL access
• Responsive viewport resizing (iPhone, iPad, Desktop presets)
• Screenshot capture
• API capability detection
• Dark mode support

Perfect for iOS developers who need to test web content rendering, debug JavaScript, analyze network requests, and ensure accessibility compliance.
""",
        "keywords": "webview,developer,debug,console,network,safari,wkwebview,devtools,test,inspect,ios,javascript,html",
        "whatsNew": "Bug fixes and performance improvements.",
        "promotionalText": "Quickly see how web content behaves in WKWebView and SafariVC. Track root causes with Console, Network, Storage, Performance, and Sources."
    },
    "en-AU": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """The ultimate developer tool for testing WKWebView and SFSafariViewController configurations in real-time.

KEY FEATURES

WKWebView Testing
• Real-time configuration testing with 20+ options
• Built-in DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript injection and snippet execution
• Custom User-Agent emulation
• Viewport and device emulation

SFSafariViewController Testing
• Safari cookie/session sharing
• Content Blocker support
• Reader Mode configuration
• Safari extension compatibility

Developer Tools
• Console: Capture console.log with %c CSS styling support
• Network: Monitor fetch/XHR requests with timing data
• Storage: View/edit localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) and Navigation Timing
• Sources: DOM tree inspection, stylesheets, scripts
• Accessibility: axe-core based accessibility auditing

Additional Features
• Bookmark management for quick URL access
• Responsive viewport resizing (iPhone, iPad, Desktop presets)
• Screenshot capture
• API capability detection
• Dark mode support

Perfect for iOS developers who need to test web content rendering, debug JavaScript, analyze network requests, and ensure accessibility compliance.
""",
        "keywords": "webview,developer,debug,console,network,safari,wkwebview,devtools,test,inspect,ios,javascript,html",
        "whatsNew": "Bug fixes and performance improvements.",
        "promotionalText": "Quickly see how web content behaves in WKWebView and SafariVC. Track root causes with Console, Network, Storage, Performance, and Sources."
    },
    "en-CA": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """The ultimate developer tool for testing WKWebView and SFSafariViewController configurations in real-time.

KEY FEATURES

WKWebView Testing
• Real-time configuration testing with 20+ options
• Built-in DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript injection and snippet execution
• Custom User-Agent emulation
• Viewport and device emulation

SFSafariViewController Testing
• Safari cookie/session sharing
• Content Blocker support
• Reader Mode configuration
• Safari extension compatibility

Developer Tools
• Console: Capture console.log with %c CSS styling support
• Network: Monitor fetch/XHR requests with timing data
• Storage: View/edit localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) and Navigation Timing
• Sources: DOM tree inspection, stylesheets, scripts
• Accessibility: axe-core based accessibility auditing

Additional Features
• Bookmark management for quick URL access
• Responsive viewport resizing (iPhone, iPad, Desktop presets)
• Screenshot capture
• API capability detection
• Dark mode support

Perfect for iOS developers who need to test web content rendering, debug JavaScript, analyze network requests, and ensure accessibility compliance.
""",
        "keywords": "webview,developer,debug,console,network,safari,wkwebview,devtools,test,inspect,ios,javascript,html",
        "whatsNew": "Bug fixes and performance improvements.",
        "promotionalText": "Quickly see how web content behaves in WKWebView and SafariVC. Track root causes with Console, Network, Storage, Performance, and Sources."
    },
    "en-GB": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """The ultimate developer tool for testing WKWebView and SFSafariViewController configurations in real-time.

KEY FEATURES

WKWebView Testing
• Real-time configuration testing with 20+ options
• Built-in DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript injection and snippet execution
• Custom User-Agent emulation
• Viewport and device emulation

SFSafariViewController Testing
• Safari cookie/session sharing
• Content Blocker support
• Reader Mode configuration
• Safari extension compatibility

Developer Tools
• Console: Capture console.log with %c CSS styling support
• Network: Monitor fetch/XHR requests with timing data
• Storage: View/edit localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) and Navigation Timing
• Sources: DOM tree inspection, stylesheets, scripts
• Accessibility: axe-core based accessibility auditing

Additional Features
• Bookmark management for quick URL access
• Responsive viewport resizing (iPhone, iPad, Desktop presets)
• Screenshot capture
• API capability detection
• Dark mode support

Perfect for iOS developers who need to test web content rendering, debug JavaScript, analyze network requests, and ensure accessibility compliance.
""",
        "keywords": "webview,developer,debug,console,network,safari,wkwebview,devtools,test,inspect,ios,javascript,html",
        "whatsNew": "Bug fixes and performance improvements.",
        "promotionalText": "Quickly see how web content behaves in WKWebView and SafariVC. Track root causes with Console, Network, Storage, Performance, and Sources."
    },
    "ko": {
        "name": "Walnut: 웹뷰 테스터 & 디버그",
        "subtitle": "WKWebView & SafariVC 테스트",
        "description": """WKWebView와 SFSafariViewController 설정을 실시간으로 테스트하는 개발자 도구입니다.

주요 기능

WKWebView 테스트
• 20개 이상의 옵션으로 실시간 설정 테스트
• 내장 DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript 주입 및 스니펫 실행
• 커스텀 User-Agent 에뮬레이션
• 뷰포트 및 디바이스 에뮬레이션

SFSafariViewController 테스트
• Safari 쿠키/세션 공유
• Content Blocker 지원
• Reader Mode 설정
• Safari 확장 프로그램 호환

개발자 도구
• Console: %c CSS 스타일링을 지원하는 console.log 캡처
• Network: 타이밍 데이터와 함께 fetch/XHR 요청 모니터링
• Storage: localStorage, sessionStorage, 쿠키 조회/편집
• Performance: Web Vitals (LCP, FID, CLS) 및 Navigation Timing
• Sources: DOM 트리 검사, 스타일시트, 스크립트
• Accessibility: axe-core 기반 접근성 감사

추가 기능
• 빠른 URL 접근을 위한 북마크 관리
• 반응형 뷰포트 크기 조절 (iPhone, iPad, Desktop 프리셋)
• 스크린샷 캡처
• API 기능 감지
• 다크 모드 지원

웹 콘텐츠 렌더링 테스트, JavaScript 디버깅, 네트워크 요청 분석, 접근성 준수 확인이 필요한 iOS 개발자에게 적합합니다.
""",
        "keywords": "웹뷰,개발자,디버그,콘솔,네트워크,사파리,devtools,테스트,검사,ios,자바스크립트,html,css,쿠키,성능,접근성,개발도구,브라우저,앱,모바일,웹킷,사파리뷰",
        "whatsNew": "버그 수정 및 성능 개선.",
        "promotionalText": "WKWebView와 SafariVC에서 웹 콘텐츠가 실제로 어떻게 동작하는지 빠르게 확인할 수 있는 개발자용 도구입니다. 콘솔·네트워크·스토리지·성능·소스로 원인을 추적할 수 있습니다."
    },
    "ja": {
        "name": "Walnut: Webviewテスター&デバッグ",
        "subtitle": "WKWebView & SafariVCテスト",
        "description": """WKWebViewとSFSafariViewControllerの設定をリアルタイムでテストする開発者ツールです。

主な機能

WKWebViewテスト
• 20以上のオプションでリアルタイム設定テスト
• 内蔵DevTools：Console、Network、Storage、Performance、Sources、Accessibility
• JavaScript注入とスニペット実行
• カスタムUser-Agentエミュレーション
• ビューポートとデバイスエミュレーション

SFSafariViewControllerテスト
• Safariクッキー/セッション共有
• Content Blockerサポート
• Reader Mode設定
• Safari拡張機能との互換性

開発者ツール
• Console：%c CSSスタイリングをサポートするconsole.logキャプチャ
• Network：タイミングデータ付きfetch/XHRリクエスト監視
• Storage：localStorage、sessionStorage、クッキーの表示/編集
• Performance：Web Vitals（LCP、FID、CLS）とNavigation Timing
• Sources：DOMツリー検査、スタイルシート、スクリプト
• Accessibility：axe-coreベースのアクセシビリティ監査

追加機能
• クイックURLアクセス用ブックマーク管理
• レスポンシブビューポートサイズ変更（iPhone、iPad、Desktopプリセット）
• スクリーンショットキャプチャ
• API機能検出
• ダークモードサポート

Webコンテンツのレンダリングテスト、JavaScriptデバッグ、ネットワークリクエスト分析、アクセシビリティ準拠の確認が必要なiOS開発者に最適です。
""",
        "keywords": "webview,開発者,デバッグ,コンソール,ネットワーク,safari,devtools,テスト,検査,ios,javascript,html,css,開発ツール,ブラウザ,アプリ",
        "whatsNew": "バグ修正とパフォーマンス改善。",
        "promotionalText": "WKWebViewとSafariVCでWebコンテンツがどう動くかを素早く確認できます。Console、Network、Storage、Performance、Sourcesで原因を追えます。"
    },
    "zh-Hans": {
        "name": "Walnut: Webview测试和调试",
        "subtitle": "测试WKWebView和SafariVC",
        "description": """实时测试WKWebView和SFSafariViewController配置的开发者工具。

主要功能

WKWebView测试
• 20多个选项的实时配置测试
• 内置DevTools：Console、Network、Storage、Performance、Sources、Accessibility
• JavaScript注入和代码片段执行
• 自定义User-Agent模拟
• 视口和设备模拟

SFSafariViewController测试
• Safari Cookie/会话共享
• Content Blocker支持
• Reader Mode配置
• Safari扩展兼容性

开发者工具
• Console：支持%c CSS样式的console.log捕获
• Network：带时间数据的fetch/XHR请求监控
• Storage：查看/编辑localStorage、sessionStorage、cookies
• Performance：Web Vitals（LCP、FID、CLS）和Navigation Timing
• Sources：DOM树检查、样式表、脚本
• Accessibility：基于axe-core的可访问性审计

其他功能
• 快速URL访问的书签管理
• 响应式视口大小调整（iPhone、iPad、Desktop预设）
• 截图捕获
• API功能检测
• 深色模式支持

非常适合需要测试网页内容渲染、调试JavaScript、分析网络请求和确保可访问性合规的iOS开发者。
""",
        "keywords": "webview,开发者,调试,控制台,网络,safari,devtools,测试,检查,ios,javascript,html,css,cookie,性能,开发工具,浏览器,应用,工具",
        "whatsNew": "错误修复和性能改进。",
        "promotionalText": "快速查看网页内容在WKWebView和SafariVC中的实际表现。通过Console、Network、Storage、Performance和Sources追踪原因。"
    },
    "zh-Hant": {
        "name": "Walnut: Webview測試和除錯",
        "subtitle": "測試WKWebView和SafariVC",
        "description": """即時測試WKWebView和SFSafariViewController配置的開發者工具。

主要功能

WKWebView測試
• 20多個選項的即時配置測試
• 內建DevTools：Console、Network、Storage、Performance、Sources、Accessibility
• JavaScript注入和程式碼片段執行
• 自訂User-Agent模擬
• 視口和裝置模擬

SFSafariViewController測試
• Safari Cookie/工作階段共享
• Content Blocker支援
• Reader Mode配置
• Safari擴充功能相容性

開發者工具
• Console：支援%c CSS樣式的console.log擷取
• Network：帶時間資料的fetch/XHR請求監控
• Storage：檢視/編輯localStorage、sessionStorage、cookies
• Performance：Web Vitals（LCP、FID、CLS）和Navigation Timing
• Sources：DOM樹檢查、樣式表、指令碼
• Accessibility：基於axe-core的無障礙稽核

其他功能
• 快速URL存取的書籤管理
• 響應式視口大小調整（iPhone、iPad、Desktop預設）
• 螢幕截圖擷取
• API功能偵測
• 深色模式支援

非常適合需要測試網頁內容呈現、除錯JavaScript、分析網路請求和確保無障礙合規的iOS開發者。
""",
        "keywords": "webview,開發者,除錯,控制台,網路,safari,devtools,測試,檢查,ios,javascript,html,css,cookie,效能,開發工具,瀏覽器,應用,工具",
        "whatsNew": "錯誤修復和效能改善。",
        "promotionalText": "快速查看網頁內容在WKWebView與SafariVC中的實際表現。透過Console、Network、Storage、Performance與Sources追蹤原因。"
    },
    "de-DE": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "WKWebView & SafariVC testen",
        "description": """Das ultimative Entwicklertool zum Testen von WKWebView- und SFSafariViewController-Konfigurationen in Echtzeit.

HAUPTFUNKTIONEN

WKWebView-Tests
• Echtzeit-Konfigurationstests mit über 20 Optionen
• Integrierte DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript-Injection und Snippet-Ausführung
• Benutzerdefinierte User-Agent-Emulation
• Viewport- und Geräte-Emulation

SFSafariViewController-Tests
• Safari-Cookie-/Sitzungsfreigabe
• Content Blocker-Unterstützung
• Reader Mode-Konfiguration
• Safari-Erweiterungskompatibilität

Entwicklertools
• Console: console.log-Erfassung mit %c CSS-Styling-Unterstützung
• Network: Fetch/XHR-Anfragen mit Timing-Daten überwachen
• Storage: localStorage, sessionStorage, Cookies anzeigen/bearbeiten
• Performance: Web Vitals (LCP, FID, CLS) und Navigation Timing
• Sources: DOM-Baum-Inspektion, Stylesheets, Skripte
• Accessibility: axe-core-basierte Barrierefreiheitsprüfung

Zusätzliche Funktionen
• Lesezeichenverwaltung für schnellen URL-Zugriff
• Responsive Viewport-Größenanpassung (iPhone, iPad, Desktop-Presets)
• Screenshot-Erfassung
• API-Fähigkeitserkennung
• Dunkelmodus-Unterstützung

Perfekt für iOS-Entwickler, die Web-Content-Rendering testen, JavaScript debuggen, Netzwerkanfragen analysieren und Barrierefreiheit sicherstellen müssen.
""",
        "keywords": "webview,entwickler,debug,konsole,netzwerk,safari,devtools,test,inspektor,ios,javascript,html,browser",
        "whatsNew": "Fehlerbehebungen und Leistungsverbesserungen.",
        "promotionalText": "Sehen Sie schnell, wie sich Webinhalte in WKWebView und SafariVC verhalten. Finden Sie Ursachen mit Console, Network, Storage, Performance und Sources."
    },
    "fr-FR": {
        "name": "Walnut: Webview Test & Débogage",
        "subtitle": "Tester WKWebView & SafariVC",
        "description": """L'outil ultime pour les développeurs pour tester les configurations WKWebView et SFSafariViewController en temps réel.

FONCTIONNALITÉS PRINCIPALES

Tests WKWebView
• Tests de configuration en temps réel avec plus de 20 options
• DevTools intégrés : Console, Network, Storage, Performance, Sources, Accessibility
• Injection JavaScript et exécution de snippets
• Émulation User-Agent personnalisée
• Émulation de viewport et d'appareil

Tests SFSafariViewController
• Partage de cookies/sessions Safari
• Support Content Blocker
• Configuration Reader Mode
• Compatibilité extensions Safari

Outils de développement
• Console : Capture console.log avec support du style CSS %c
• Network : Surveillance des requêtes fetch/XHR avec données de timing
• Storage : Afficher/modifier localStorage, sessionStorage, cookies
• Performance : Web Vitals (LCP, FID, CLS) et Navigation Timing
• Sources : Inspection de l'arbre DOM, feuilles de style, scripts
• Accessibility : Audit d'accessibilité basé sur axe-core

Fonctionnalités supplémentaires
• Gestion des favoris pour un accès URL rapide
• Redimensionnement de viewport réactif (préréglages iPhone, iPad, Desktop)
• Capture d'écran
• Détection des capacités API
• Support du mode sombre

Parfait pour les développeurs iOS qui doivent tester le rendu de contenu web, déboguer JavaScript, analyser les requêtes réseau et assurer la conformité d'accessibilité.
""",
        "keywords": "webview,développeur,debug,console,réseau,safari,devtools,test,inspecteur,ios,javascript,html,cookie",
        "whatsNew": "Corrections de bugs et améliorations de performances.",
        "promotionalText": "Vérifiez rapidement le comportement du contenu web dans WKWebView et SafariVC. Repérez la cause avec Console, Network, Storage, Performance et Sources."
    },
    "fr-CA": {
        "name": "Walnut: Webview Test & Débogage",
        "subtitle": "Tester WKWebView & SafariVC",
        "description": """L'outil ultime pour les développeurs pour tester les configurations WKWebView et SFSafariViewController en temps réel.

FONCTIONNALITÉS PRINCIPALES

Tests WKWebView
• Tests de configuration en temps réel avec plus de 20 options
• DevTools intégrés : Console, Network, Storage, Performance, Sources, Accessibility
• Injection JavaScript et exécution de snippets
• Émulation User-Agent personnalisée
• Émulation de viewport et d'appareil

Tests SFSafariViewController
• Partage de cookies/sessions Safari
• Support Content Blocker
• Configuration Reader Mode
• Compatibilité extensions Safari

Outils de développement
• Console : Capture console.log avec support du style CSS %c
• Network : Surveillance des requêtes fetch/XHR avec données de timing
• Storage : Afficher/modifier localStorage, sessionStorage, cookies
• Performance : Web Vitals (LCP, FID, CLS) et Navigation Timing
• Sources : Inspection de l'arbre DOM, feuilles de style, scripts
• Accessibility : Audit d'accessibilité basé sur axe-core

Fonctionnalités supplémentaires
• Gestion des favoris pour un accès URL rapide
• Redimensionnement de viewport réactif (préréglages iPhone, iPad, Desktop)
• Capture d'écran
• Détection des capacités API
• Support du mode sombre

Parfait pour les développeurs iOS qui doivent tester le rendu de contenu web, déboguer JavaScript, analyser les requêtes réseau et assurer la conformité d'accessibilité.
""",
        "keywords": "webview,développeur,debug,console,réseau,safari,devtools,test,inspecteur,ios,javascript,html,cookie",
        "whatsNew": "Corrections de bugs et améliorations de performances.",
        "promotionalText": "Vérifiez rapidement le comportement du contenu web dans WKWebView et SafariVC. Repérez la cause avec Console, Network, Storage, Performance et Sources."
    },
    "es-ES": {
        "name": "Walnut: Webview Test & Debug",
        "subtitle": "Probar WKWebView y SafariVC",
        "description": """La herramienta definitiva para desarrolladores para probar configuraciones de WKWebView y SFSafariViewController en tiempo real.

CARACTERÍSTICAS PRINCIPALES

Pruebas de WKWebView
• Pruebas de configuración en tiempo real con más de 20 opciones
• DevTools integradas: Console, Network, Storage, Performance, Sources, Accessibility
• Inyección de JavaScript y ejecución de snippets
• Emulación de User-Agent personalizado
• Emulación de viewport y dispositivo

Pruebas de SFSafariViewController
• Compartir cookies/sesiones de Safari
• Soporte de Content Blocker
• Configuración de Reader Mode
• Compatibilidad con extensiones de Safari

Herramientas de desarrollo
• Console: Captura de console.log con soporte de estilo CSS %c
• Network: Monitoreo de solicitudes fetch/XHR con datos de tiempo
• Storage: Ver/editar localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) y Navigation Timing
• Sources: Inspección del árbol DOM, hojas de estilo, scripts
• Accessibility: Auditoría de accesibilidad basada en axe-core

Características adicionales
• Gestión de marcadores para acceso rápido a URLs
• Redimensionamiento de viewport responsivo (presets iPhone, iPad, Desktop)
• Captura de pantalla
• Detección de capacidades de API
• Soporte de modo oscuro

Perfecto para desarrolladores iOS que necesitan probar el renderizado de contenido web, depurar JavaScript, analizar solicitudes de red y asegurar el cumplimiento de accesibilidad.
""",
        "keywords": "webview,desarrollador,debug,consola,red,safari,devtools,prueba,inspector,ios,javascript,html,cookie",
        "whatsNew": "Correcciones de errores y mejoras de rendimiento.",
        "promotionalText": "Compruebe rápidamente cómo se comporta el contenido web en WKWebView y SafariVC. Localice la causa con Console, Network, Storage, Performance y Sources."
    },
    "es-MX": {
        "name": "Walnut: Webview Test & Debug",
        "subtitle": "Probar WKWebView y SafariVC",
        "description": """La herramienta definitiva para desarrolladores para probar configuraciones de WKWebView y SFSafariViewController en tiempo real.

CARACTERÍSTICAS PRINCIPALES

Pruebas de WKWebView
• Pruebas de configuración en tiempo real con más de 20 opciones
• DevTools integradas: Console, Network, Storage, Performance, Sources, Accessibility
• Inyección de JavaScript y ejecución de snippets
• Emulación de User-Agent personalizado
• Emulación de viewport y dispositivo

Pruebas de SFSafariViewController
• Compartir cookies/sesiones de Safari
• Soporte de Content Blocker
• Configuración de Reader Mode
• Compatibilidad con extensiones de Safari

Herramientas de desarrollo
• Console: Captura de console.log con soporte de estilo CSS %c
• Network: Monitoreo de solicitudes fetch/XHR con datos de tiempo
• Storage: Ver/editar localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) y Navigation Timing
• Sources: Inspección del árbol DOM, hojas de estilo, scripts
• Accessibility: Auditoría de accesibilidad basada en axe-core

Características adicionales
• Gestión de marcadores para acceso rápido a URLs
• Redimensionamiento de viewport responsivo (presets iPhone, iPad, Desktop)
• Captura de pantalla
• Detección de capacidades de API
• Soporte de modo oscuro

Perfecto para desarrolladores iOS que necesitan probar el renderizado de contenido web, depurar JavaScript, analizar solicitudes de red y asegurar el cumplimiento de accesibilidad.
""",
        "keywords": "webview,desarrollador,debug,consola,red,safari,devtools,prueba,inspector,ios,javascript,html,cookie",
        "whatsNew": "Correcciones de errores y mejoras de rendimiento.",
        "promotionalText": "Compruebe rápidamente cómo se comporta el contenido web en WKWebView y SafariVC. Localice la causa con Console, Network, Storage, Performance y Sources."
    },
    "it": {
        "name": "Walnut: Webview Test & Debug",
        "subtitle": "Testa WKWebView e SafariVC",
        "description": """Lo strumento definitivo per sviluppatori per testare le configurazioni di WKWebView e SFSafariViewController in tempo reale.

CARATTERISTICHE PRINCIPALI

Test WKWebView
• Test di configurazione in tempo reale con oltre 20 opzioni
• DevTools integrati: Console, Network, Storage, Performance, Sources, Accessibility
• Iniezione JavaScript ed esecuzione di snippet
• Emulazione User-Agent personalizzata
• Emulazione viewport e dispositivo

Test SFSafariViewController
• Condivisione cookie/sessioni Safari
• Supporto Content Blocker
• Configurazione Reader Mode
• Compatibilità estensioni Safari

Strumenti per sviluppatori
• Console: Cattura console.log con supporto stile CSS %c
• Network: Monitoraggio richieste fetch/XHR con dati di timing
• Storage: Visualizza/modifica localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) e Navigation Timing
• Sources: Ispezione albero DOM, fogli di stile, script
• Accessibility: Audit accessibilità basato su axe-core

Funzionalità aggiuntive
• Gestione segnalibri per accesso URL rapido
• Ridimensionamento viewport responsivo (preset iPhone, iPad, Desktop)
• Cattura screenshot
• Rilevamento capacità API
• Supporto modalità scura

Perfetto per sviluppatori iOS che devono testare il rendering di contenuti web, debuggare JavaScript, analizzare richieste di rete e garantire la conformità all'accessibilità.
""",
        "keywords": "webview,sviluppatore,debug,console,rete,safari,devtools,test,ispettore,ios,javascript,html,css",
        "whatsNew": "Correzioni di bug e miglioramenti delle prestazioni.",
        "promotionalText": "Verifica rapidamente come si comportano i contenuti web in WKWebView e SafariVC. Trova le cause con Console, Network, Storage, Performance e Sources."
    },
    "pt-BR": {
        "name": "Walnut: Webview Teste & Debug",
        "subtitle": "Testar WKWebView e SafariVC",
        "description": """A ferramenta definitiva para desenvolvedores testarem configurações de WKWebView e SFSafariViewController em tempo real.

RECURSOS PRINCIPAIS

Testes de WKWebView
• Testes de configuração em tempo real com mais de 20 opções
• DevTools integradas: Console, Network, Storage, Performance, Sources, Accessibility
• Injeção de JavaScript e execução de snippets
• Emulação de User-Agent personalizado
• Emulação de viewport e dispositivo

Testes de SFSafariViewController
• Compartilhamento de cookies/sessões do Safari
• Suporte a Content Blocker
• Configuração do Reader Mode
• Compatibilidade com extensões do Safari

Ferramentas de desenvolvedor
• Console: Captura de console.log com suporte a estilo CSS %c
• Network: Monitoramento de requisições fetch/XHR com dados de tempo
• Storage: Visualizar/editar localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) e Navigation Timing
• Sources: Inspeção da árvore DOM, folhas de estilo, scripts
• Accessibility: Auditoria de acessibilidade baseada em axe-core

Recursos adicionais
• Gerenciamento de favoritos para acesso rápido a URLs
• Redimensionamento de viewport responsivo (presets iPhone, iPad, Desktop)
• Captura de tela
• Detecção de capacidades de API
• Suporte ao modo escuro

Perfeito para desenvolvedores iOS que precisam testar renderização de conteúdo web, depurar JavaScript, analisar requisições de rede e garantir conformidade de acessibilidade.
""",
        "keywords": "webview,desenvolvedor,debug,console,rede,safari,devtools,teste,inspetor,ios,javascript,html,cookie",
        "whatsNew": "Correções de bugs e melhorias de desempenho.",
        "promotionalText": "Veja rapidamente como o conteúdo web se comporta no WKWebView e no SafariVC. Encontre a causa com Console, Network, Storage, Performance e Sources."
    },
    "pt-PT": {
        "name": "Walnut: Webview Teste & Debug",
        "subtitle": "Testar WKWebView e SafariVC",
        "description": """A ferramenta definitiva para desenvolvedores testarem configurações de WKWebView e SFSafariViewController em tempo real.

RECURSOS PRINCIPAIS

Testes de WKWebView
• Testes de configuração em tempo real com mais de 20 opções
• DevTools integradas: Console, Network, Storage, Performance, Sources, Accessibility
• Injeção de JavaScript e execução de snippets
• Emulação de User-Agent personalizado
• Emulação de viewport e dispositivo

Testes de SFSafariViewController
• Compartilhamento de cookies/sessões do Safari
• Suporte a Content Blocker
• Configuração do Reader Mode
• Compatibilidade com extensões do Safari

Ferramentas de desenvolvedor
• Console: Captura de console.log com suporte a estilo CSS %c
• Network: Monitoramento de requisições fetch/XHR com dados de tempo
• Storage: Visualizar/editar localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) e Navigation Timing
• Sources: Inspeção da árvore DOM, folhas de estilo, scripts
• Accessibility: Auditoria de acessibilidade baseada em axe-core

Recursos adicionais
• Gerenciamento de favoritos para acesso rápido a URLs
• Redimensionamento de viewport responsivo (presets iPhone, iPad, Desktop)
• Captura de tela
• Detecção de capacidades de API
• Suporte ao modo escuro

Perfeito para desenvolvedores iOS que precisam testar renderização de conteúdo web, depurar JavaScript, analisar requisições de rede e garantir conformidade de acessibilidade.
""",
        "keywords": "webview,desenvolvedor,debug,console,rede,safari,devtools,teste,inspetor,ios,javascript,html,cookie",
        "whatsNew": "Correções de bugs e melhorias de desempenho.",
        "promotionalText": "Veja rapidamente como o conteúdo web se comporta no WKWebView e no SafariVC. Encontre a causa com Console, Network, Storage, Performance e Sources."
    },
    "ru": {
        "name": "Walnut: Webview Тест и Отладка",
        "subtitle": "Тест WKWebView и SafariVC",
        "description": """Идеальный инструмент разработчика для тестирования конфигураций WKWebView и SFSafariViewController в реальном времени.

ОСНОВНЫЕ ФУНКЦИИ

Тестирование WKWebView
• Тестирование конфигурации в реальном времени с более чем 20 опциями
• Встроенные DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• Инъекция JavaScript и выполнение сниппетов
• Эмуляция пользовательского User-Agent
• Эмуляция viewport и устройства

Тестирование SFSafariViewController
• Общий доступ к cookies/сессиям Safari
• Поддержка Content Blocker
• Настройка Reader Mode
• Совместимость с расширениями Safari

Инструменты разработчика
• Console: Захват console.log с поддержкой стилей CSS %c
• Network: Мониторинг запросов fetch/XHR с данными тайминга
• Storage: Просмотр/редактирование localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) и Navigation Timing
• Sources: Инспекция дерева DOM, таблицы стилей, скрипты
• Accessibility: Аудит доступности на основе axe-core

Дополнительные функции
• Управление закладками для быстрого доступа к URL
• Адаптивное изменение размера viewport (пресеты iPhone, iPad, Desktop)
• Захват скриншотов
• Обнаружение возможностей API
• Поддержка тёмного режима

Идеально подходит для iOS-разработчиков, которым нужно тестировать рендеринг веб-контента, отлаживать JavaScript, анализировать сетевые запросы и обеспечивать соответствие требованиям доступности.
""",
        "keywords": "webview,разработчик,отладка,консоль,сеть,safari,devtools,тест,инспектор,ios,javascript,html,css",
        "whatsNew": "Исправления ошибок и улучшения производительности.",
        "promotionalText": "Быстро проверьте, как веб-контент ведет себя в WKWebView и SafariVC. Найдите причину с Console, Network, Storage, Performance и Sources."
    },
    "ar-SA": {
        "name": "Walnut: Webview اختبار وتصحيح",
        "subtitle": "اختبار WKWebView و SafariVC",
        "description": """الأداة المثالية للمطورين لاختبار إعدادات WKWebView و SFSafariViewController في الوقت الفعلي.

الميزات الرئيسية

اختبار WKWebView
• اختبار الإعدادات في الوقت الفعلي مع أكثر من 20 خياراً
• أدوات DevTools مدمجة: Console, Network, Storage, Performance, Sources, Accessibility
• حقن JavaScript وتنفيذ المقتطفات
• محاكاة User-Agent مخصصة
• محاكاة منفذ العرض والجهاز

اختبار SFSafariViewController
• مشاركة ملفات تعريف الارتباط/الجلسات في Safari
• دعم حاجب المحتوى
• إعدادات وضع القارئ
• توافق إضافات Safari

أدوات المطور
• Console: التقاط console.log مع دعم تنسيق CSS %c
• Network: مراقبة طلبات fetch/XHR مع بيانات التوقيت
• Storage: عرض/تحرير localStorage و sessionStorage وملفات تعريف الارتباط
• Performance: Web Vitals (LCP, FID, CLS) و Navigation Timing
• Sources: فحص شجرة DOM وأوراق الأنماط والبرامج النصية
• Accessibility: تدقيق إمكانية الوصول بناءً على axe-core

ميزات إضافية
• إدارة الإشارات المرجعية للوصول السريع لعناوين URL
• تغيير حجم منفذ العرض التكيفي (إعدادات iPhone و iPad و Desktop)
• التقاط لقطات الشاشة
• اكتشاف قدرات API
• دعم الوضع الداكن

مثالية لمطوري iOS الذين يحتاجون إلى اختبار عرض محتوى الويب وتصحيح أخطاء JavaScript وتحليل طلبات الشبكة وضمان الامتثال لإمكانية الوصول.
""",
        "keywords": "webview,مطور,تصحيح,وحدة التحكم,شبكة,safari,devtools,اختبار,فحص,ios,javascript,html,css,متصفح,أداة",
        "whatsNew": "إصلاحات الأخطاء وتحسينات الأداء.",
        "promotionalText": "تعرّف بسرعة على كيفية عمل محتوى الويب في WKWebView وSafariVC. تتبّع السبب عبر Console وNetwork وStorage وPerformance وSources."
    },
    "hi": {
        "name": "Walnut: Webview टेस्ट और डीबग",
        "subtitle": "WKWebView और SafariVC टेस्ट",
        "description": """WKWebView और SFSafariViewController कॉन्फ़िगरेशन को रीयल-टाइम में टेस्ट करने के लिए परम डेवलपर टूल।

मुख्य विशेषताएं

WKWebView टेस्टिंग
• 20+ विकल्पों के साथ रीयल-टाइम कॉन्फ़िगरेशन टेस्टिंग
• बिल्ट-इन DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript इंजेक्शन और स्निपेट निष्पादन
• कस्टम User-Agent एमुलेशन
• व्यूपोर्ट और डिवाइस एमुलेशन

SFSafariViewController टेस्टिंग
• Safari कुकी/सेशन शेयरिंग
• Content Blocker सपोर्ट
• Reader Mode कॉन्फ़िगरेशन
• Safari एक्सटेंशन संगतता

डेवलपर टूल्स
• Console: %c CSS स्टाइलिंग सपोर्ट के साथ console.log कैप्चर
• Network: टाइमिंग डेटा के साथ fetch/XHR रिक्वेस्ट मॉनिटर करें
• Storage: localStorage, sessionStorage, cookies देखें/संपादित करें
• Performance: Web Vitals (LCP, FID, CLS) और Navigation Timing
• Sources: DOM ट्री इंस्पेक्शन, स्टाइलशीट्स, स्क्रिप्ट्स
• Accessibility: axe-core आधारित एक्सेसिबिलिटी ऑडिटिंग

अतिरिक्त विशेषताएं
• त्वरित URL एक्सेस के लिए बुकमार्क प्रबंधन
• रेस्पॉन्सिव व्यूपोर्ट रीसाइज़िंग (iPhone, iPad, Desktop प्रीसेट)
• स्क्रीनशॉट कैप्चर
• API क्षमता पहचान
• डार्क मोड सपोर्ट

iOS डेवलपर्स के लिए परफेक्ट जिन्हें वेब कंटेंट रेंडरिंग टेस्ट करना है, JavaScript डीबग करना है, नेटवर्क रिक्वेस्ट एनालाइज़ करना है और एक्सेसिबिलिटी कंप्लायंस सुनिश्चित करना है।
""",
        "keywords": "webview,डेवलपर,डीबग,कंसोल,नेटवर्क,safari,devtools,टेस्ट,इंस्पेक्ट,ios,javascript,html,css,ब्राउज़र",
        "whatsNew": "बग फिक्स और प्रदर्शन सुधार।",
        "promotionalText": "WKWebView और SafariVC में वेब सामग्री कैसे व्यवहार करती है, यह जल्दी देखें। Console, Network, Storage, Performance और Sources से कारण खोजें।"
    },
    "th": {
        "name": "Walnut: Webview ทดสอบและดีบัก",
        "subtitle": "ทดสอบ WKWebView & SafariVC",
        "description": """เครื่องมือสำหรับนักพัฒนาเพื่อทดสอบการกำหนดค่า WKWebView และ SFSafariViewController แบบเรียลไทม์

คุณสมบัติหลัก

การทดสอบ WKWebView
• การทดสอบการกำหนดค่าแบบเรียลไทม์พร้อมตัวเลือกกว่า 20 รายการ
• DevTools ในตัว: Console, Network, Storage, Performance, Sources, Accessibility
• การฉีด JavaScript และการรันโค้ดสั้น
• การจำลอง User-Agent แบบกำหนดเอง
• การจำลอง Viewport และอุปกรณ์

การทดสอบ SFSafariViewController
• การแชร์ Cookie/เซสชัน Safari
• รองรับ Content Blocker
• การกำหนดค่า Reader Mode
• ความเข้ากันได้กับส่วนขยาย Safari

เครื่องมือสำหรับนักพัฒนา
• Console: จับ console.log พร้อมรองรับการจัดรูปแบบ CSS %c
• Network: ตรวจสอบคำขอ fetch/XHR พร้อมข้อมูลเวลา
• Storage: ดู/แก้ไข localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) และ Navigation Timing
• Sources: ตรวจสอบ DOM tree, สไตล์ชีต, สคริปต์
• Accessibility: การตรวจสอบการเข้าถึงตาม axe-core

คุณสมบัติเพิ่มเติม
• การจัดการบุ๊กมาร์กสำหรับการเข้าถึง URL อย่างรวดเร็ว
• การปรับขนาด Viewport แบบตอบสนอง (พรีเซ็ต iPhone, iPad, Desktop)
• การจับภาพหน้าจอ
• การตรวจจับความสามารถของ API
• รองรับโหมดมืด

เหมาะสำหรับนักพัฒนา iOS ที่ต้องการทดสอบการแสดงผลเนื้อหาเว็บ ดีบัก JavaScript วิเคราะห์คำขอเครือข่าย และรับรองการปฏิบัติตามการเข้าถึง
""",
        "keywords": "webview,นักพัฒนา,ดีบัก,คอนโซล,เครือข่าย,safari,devtools,ทดสอบ,ตรวจสอบ,ios,javascript,html,css",
        "whatsNew": "แก้ไขข้อบกพร่องและปรับปรุงประสิทธิภาพ",
        "promotionalText": "ดูอย่างรวดเร็วว่าเนื้อหาเว็บทำงานอย่างไรใน WKWebView และ SafariVC. ค้นหาสาเหตุด้วย Console, Network, Storage, Performance และ Sources."
    },
    "vi": {
        "name": "Walnut: Webview Test & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """Công cụ dành cho nhà phát triển để kiểm thử cấu hình WKWebView và SFSafariViewController theo thời gian thực.

TÍNH NĂNG CHÍNH

Kiểm thử WKWebView
• Kiểm thử cấu hình thời gian thực với hơn 20 tùy chọn
• DevTools tích hợp: Console, Network, Storage, Performance, Sources, Accessibility
• Tiêm JavaScript và thực thi đoạn mã
• Giả lập User-Agent tùy chỉnh
• Giả lập viewport và thiết bị

Kiểm thử SFSafariViewController
• Chia sẻ cookie/phiên Safari
• Hỗ trợ Content Blocker
• Cấu hình Reader Mode
• Tương thích tiện ích mở rộng Safari

Công cụ phát triển
• Console: Ghi nhận console.log với hỗ trợ định dạng CSS %c
• Network: Giám sát yêu cầu fetch/XHR với dữ liệu thời gian
• Storage: Xem/chỉnh sửa localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) và Navigation Timing
• Sources: Kiểm tra cây DOM, stylesheet, script
• Accessibility: Kiểm tra khả năng truy cập dựa trên axe-core

Tính năng bổ sung
• Quản lý bookmark để truy cập URL nhanh
• Thay đổi kích thước viewport đáp ứng (preset iPhone, iPad, Desktop)
• Chụp ảnh màn hình
• Phát hiện khả năng API
• Hỗ trợ chế độ tối

Hoàn hảo cho các nhà phát triển iOS cần kiểm thử hiển thị nội dung web, gỡ lỗi JavaScript, phân tích yêu cầu mạng và đảm bảo tuân thủ khả năng truy cập.
""",
        "keywords": "webview,lập trình,debug,console,mạng,safari,devtools,kiểm thử,kiểm tra,ios,javascript,html,css",
        "whatsNew": "Sửa lỗi và cải thiện hiệu suất.",
        "promotionalText": "Nhanh chóng xem nội dung web hoạt động thế nào trong WKWebView và SafariVC. Tìm nguyên nhân với Console, Network, Storage, Performance và Sources."
    },
    "id": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Tes WKWebView & SafariVC",
        "description": """Alat pengembang terbaik untuk menguji konfigurasi WKWebView dan SFSafariViewController secara real-time.

FITUR UTAMA

Pengujian WKWebView
• Pengujian konfigurasi real-time dengan lebih dari 20 opsi
• DevTools bawaan: Console, Network, Storage, Performance, Sources, Accessibility
• Injeksi JavaScript dan eksekusi snippet
• Emulasi User-Agent kustom
• Emulasi viewport dan perangkat

Pengujian SFSafariViewController
• Berbagi cookie/sesi Safari
• Dukungan Content Blocker
• Konfigurasi Reader Mode
• Kompatibilitas ekstensi Safari

Alat Pengembang
• Console: Tangkap console.log dengan dukungan styling CSS %c
• Network: Monitor permintaan fetch/XHR dengan data timing
• Storage: Lihat/edit localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) dan Navigation Timing
• Sources: Inspeksi pohon DOM, stylesheet, skrip
• Accessibility: Audit aksesibilitas berbasis axe-core

Fitur Tambahan
• Manajemen bookmark untuk akses URL cepat
• Pengubahan ukuran viewport responsif (preset iPhone, iPad, Desktop)
• Tangkapan layar
• Deteksi kemampuan API
• Dukungan mode gelap

Sempurna untuk pengembang iOS yang perlu menguji rendering konten web, debug JavaScript, menganalisis permintaan jaringan, dan memastikan kepatuhan aksesibilitas.
""",
        "keywords": "webview,developer,debug,console,jaringan,safari,devtools,tes,inspeksi,ios,javascript,html,css",
        "whatsNew": "Perbaikan bug dan peningkatan kinerja.",
        "promotionalText": "Cepat lihat bagaimana konten web berperilaku di WKWebView dan SafariVC. Temukan penyebabnya dengan Console, Network, Storage, Performance, dan Sources."
    },
    "ms": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Uji WKWebView & SafariVC",
        "description": """Alat pembangun terbaik untuk menguji konfigurasi WKWebView dan SFSafariViewController secara masa nyata.

CIRI-CIRI UTAMA

Pengujian WKWebView
• Pengujian konfigurasi masa nyata dengan lebih dari 20 pilihan
• DevTools terbina dalam: Console, Network, Storage, Performance, Sources, Accessibility
• Suntikan JavaScript dan pelaksanaan snippet
• Emulasi User-Agent tersuai
• Emulasi viewport dan peranti

Pengujian SFSafariViewController
• Perkongsian kuki/sesi Safari
• Sokongan Content Blocker
• Konfigurasi Reader Mode
• Keserasian sambungan Safari

Alat Pembangun
• Console: Tangkap console.log dengan sokongan gaya CSS %c
• Network: Pantau permintaan fetch/XHR dengan data masa
• Storage: Lihat/edit localStorage, sessionStorage, kuki
• Performance: Web Vitals (LCP, FID, CLS) dan Navigation Timing
• Sources: Pemeriksaan pokok DOM, helaian gaya, skrip
• Accessibility: Audit kebolehcapaian berasaskan axe-core

Ciri-ciri Tambahan
• Pengurusan penanda buku untuk akses URL pantas
• Pengubahsuaian saiz viewport responsif (pratetap iPhone, iPad, Desktop)
• Tangkapan skrin
• Pengesanan keupayaan API
• Sokongan mod gelap

Sempurna untuk pembangun iOS yang perlu menguji pemaparan kandungan web, nyahpepijat JavaScript, menganalisis permintaan rangkaian, dan memastikan pematuhan kebolehcapaian.
""",
        "keywords": "webview,pembangun,debug,konsol,rangkaian,safari,devtools,uji,periksa,ios,javascript,html,css,pelayar",
        "whatsNew": "Pembetulan pepijat dan penambahbaikan prestasi.",
        "promotionalText": "Lihat dengan cepat bagaimana kandungan web berfungsi dalam WKWebView dan SafariVC. Jejaki punca dengan Console, Network, Storage, Performance dan Sources."
    },
    "nl-NL": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """De ultieme ontwikkelaarstool voor het testen van WKWebView- en SFSafariViewController-configuraties in realtime.

BELANGRIJKSTE FUNCTIES

WKWebView-testen
• Realtime configuratietesten met meer dan 20 opties
• Ingebouwde DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript-injectie en snippet-uitvoering
• Aangepaste User-Agent-emulatie
• Viewport- en apparaatemulatie

SFSafariViewController-testen
• Safari-cookie-/sessiedeling
• Content Blocker-ondersteuning
• Reader Mode-configuratie
• Safari-extensiecompatibiliteit

Ontwikkelaarstools
• Console: console.log-vastlegging met %c CSS-styling-ondersteuning
• Network: Fetch/XHR-verzoeken monitoren met timinggegevens
• Storage: localStorage, sessionStorage, cookies bekijken/bewerken
• Performance: Web Vitals (LCP, FID, CLS) en Navigation Timing
• Sources: DOM-boominspectie, stylesheets, scripts
• Accessibility: axe-core-gebaseerde toegankelijkheidsaudit

Extra functies
• Bladwijzerbeheer voor snelle URL-toegang
• Responsieve viewportgrootte (iPhone, iPad, Desktop-presets)
• Schermafbeelding
• API-mogelijkheidsdetectie
• Ondersteuning voor donkere modus

Perfect voor iOS-ontwikkelaars die webcontent-rendering moeten testen, JavaScript moeten debuggen, netwerkverzoeken moeten analyseren en toegankelijkheidsconformiteit moeten waarborgen.
""",
        "keywords": "webview,ontwikkelaar,debug,console,netwerk,safari,devtools,test,inspecteer,ios,javascript,html,css",
        "whatsNew": "Bugfixes en prestatieverbeteringen.",
        "promotionalText": "Zie snel hoe webcontent zich gedraagt in WKWebView en SafariVC. Vind de oorzaak met Console, Network, Storage, Performance en Sources."
    },
    "pl": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Testuj WKWebView i SafariVC",
        "description": """Najlepsze narzędzie deweloperskie do testowania konfiguracji WKWebView i SFSafariViewController w czasie rzeczywistym.

GŁÓWNE FUNKCJE

Testowanie WKWebView
• Testowanie konfiguracji w czasie rzeczywistym z ponad 20 opcjami
• Wbudowane DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• Wstrzykiwanie JavaScript i wykonywanie snippetów
• Emulacja niestandardowego User-Agent
• Emulacja viewport i urządzenia

Testowanie SFSafariViewController
• Udostępnianie ciasteczek/sesji Safari
• Obsługa Content Blocker
• Konfiguracja Reader Mode
• Kompatybilność z rozszerzeniami Safari

Narzędzia deweloperskie
• Console: Przechwytywanie console.log z obsługą stylowania CSS %c
• Network: Monitorowanie żądań fetch/XHR z danymi czasowymi
• Storage: Przeglądanie/edycja localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) i Navigation Timing
• Sources: Inspekcja drzewa DOM, arkusze stylów, skrypty
• Accessibility: Audyt dostępności oparty na axe-core

Dodatkowe funkcje
• Zarządzanie zakładkami dla szybkiego dostępu do URL
• Responsywna zmiana rozmiaru viewport (presety iPhone, iPad, Desktop)
• Przechwytywanie zrzutów ekranu
• Wykrywanie możliwości API
• Obsługa trybu ciemnego

Idealne dla programistów iOS, którzy muszą testować renderowanie treści webowych, debugować JavaScript, analizować żądania sieciowe i zapewniać zgodność z dostępnością.
""",
        "keywords": "webview,programista,debug,konsola,sieć,safari,devtools,test,inspektor,ios,javascript,html,css",
        "whatsNew": "Poprawki błędów i ulepszenia wydajności.",
        "promotionalText": "Szybko sprawdź, jak działa treść webowa w WKWebView i SafariVC. Ustal przyczynę z Console, Network, Storage, Performance i Sources."
    },
    "tr": {
        "name": "Walnut: Webview Test & Debug",
        "subtitle": "WKWebView & SafariVC Test",
        "description": """WKWebView ve SFSafariViewController yapılandırmalarını gerçek zamanlı test etmek için nihai geliştirici aracı.

ANA ÖZELLİKLER

WKWebView Testi
• 20'den fazla seçenekle gerçek zamanlı yapılandırma testi
• Yerleşik DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript enjeksiyonu ve snippet çalıştırma
• Özel User-Agent emülasyonu
• Viewport ve cihaz emülasyonu

SFSafariViewController Testi
• Safari çerez/oturum paylaşımı
• Content Blocker desteği
• Reader Mode yapılandırması
• Safari uzantı uyumluluğu

Geliştirici Araçları
• Console: %c CSS stilleme desteğiyle console.log yakalama
• Network: Zamanlama verileriyle fetch/XHR isteklerini izleme
• Storage: localStorage, sessionStorage, çerezleri görüntüleme/düzenleme
• Performance: Web Vitals (LCP, FID, CLS) ve Navigation Timing
• Sources: DOM ağacı incelemesi, stil sayfaları, scriptler
• Accessibility: axe-core tabanlı erişilebilirlik denetimi

Ek Özellikler
• Hızlı URL erişimi için yer imi yönetimi
• Duyarlı viewport boyutlandırma (iPhone, iPad, Desktop önayarları)
• Ekran görüntüsü yakalama
• API yetenek algılama
• Karanlık mod desteği

Web içerik görüntülemeyi test etmesi, JavaScript hata ayıklaması, ağ isteklerini analiz etmesi ve erişilebilirlik uyumluluğunu sağlaması gereken iOS geliştiricileri için mükemmel.
""",
        "keywords": "webview,geliştirici,debug,konsol,ağ,safari,devtools,test,denetim,ios,javascript,html,css,tarayıcı",
        "whatsNew": "Hata düzeltmeleri ve performans iyileştirmeleri.",
        "promotionalText": "Web içeriğinin WKWebView ve SafariVC’de nasıl davrandığını hızla görün. Console, Network, Storage, Performance ve Sources ile nedeni bulun."
    },
    "uk": {
        "name": "Walnut: Webview Тест і Дебаг",
        "subtitle": "Тест WKWebView і SafariVC",
        "description": """Найкращий інструмент розробника для тестування конфігурацій WKWebView та SFSafariViewController в реальному часі.

ОСНОВНІ ФУНКЦІЇ

Тестування WKWebView
• Тестування конфігурації в реальному часі з понад 20 опціями
• Вбудовані DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• Інʼєкція JavaScript та виконання сніппетів
• Емуляція користувацького User-Agent
• Емуляція viewport та пристрою

Тестування SFSafariViewController
• Спільний доступ до cookies/сесій Safari
• Підтримка Content Blocker
• Налаштування Reader Mode
• Сумісність з розширеннями Safari

Інструменти розробника
• Console: Захоплення console.log з підтримкою стилів CSS %c
• Network: Моніторинг запитів fetch/XHR з даними тайминга
• Storage: Перегляд/редагування localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) та Navigation Timing
• Sources: Інспекція дерева DOM, таблиці стилів, скрипти
• Accessibility: Аудит доступності на основі axe-core

Додаткові функції
• Керування закладками для швидкого доступу до URL
• Адаптивна зміна розміру viewport (пресети iPhone, iPad, Desktop)
• Захоплення скріншотів
• Виявлення можливостей API
• Підтримка темного режиму

Ідеально підходить для iOS-розробників, яким потрібно тестувати рендеринг веб-контенту, налагоджувати JavaScript, аналізувати мережеві запити та забезпечувати відповідність вимогам доступності.
""",
        "keywords": "webview,розробник,налагодження,консоль,мережа,safari,devtools,тест,інспектор,ios,javascript,html",
        "whatsNew": "Виправлення помилок та покращення продуктивності.",
        "promotionalText": "Швидко перевірте, як вебвміст працює у WKWebView і SafariVC. Знайдіть причину з Console, Network, Storage, Performance і Sources."
    },
    "sv": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Testa WKWebView & SafariVC",
        "description": """Det ultimata utvecklarverktyget för att testa WKWebView- och SFSafariViewController-konfigurationer i realtid.

HUVUDFUNKTIONER

WKWebView-testning
• Realtidskonfigurationstestning med över 20 alternativ
• Inbyggda DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript-injektion och snippet-körning
• Anpassad User-Agent-emulering
• Viewport- och enhetsemulering

SFSafariViewController-testning
• Safari-cookie-/sessionsdelning
• Content Blocker-stöd
• Reader Mode-konfiguration
• Safari-tilläggskompatibilitet

Utvecklarverktyg
• Console: console.log-fångst med %c CSS-stilstöd
• Network: Övervaka fetch/XHR-förfrågningar med tidsdata
• Storage: Visa/redigera localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) och Navigation Timing
• Sources: DOM-trädinspektion, stilmallar, skript
• Accessibility: axe-core-baserad tillgänglighetsrevision

Ytterligare funktioner
• Bokmärkeshantering för snabb URL-åtkomst
• Responsiv viewportstorleksändring (iPhone, iPad, Desktop-förinställningar)
• Skärmdumpsfångst
• API-kapacitetsdetektering
• Stöd för mörkt läge

Perfekt för iOS-utvecklare som behöver testa webbinnehållsrendering, felsöka JavaScript, analysera nätverksförfrågningar och säkerställa tillgänglighetsefterlevnad.
""",
        "keywords": "webview,utvecklare,debug,konsol,nätverk,safari,devtools,test,inspektera,ios,javascript,html,css",
        "whatsNew": "Buggfixar och prestandaförbättringar.",
        "promotionalText": "Se snabbt hur webbinnehåll beter sig i WKWebView och SafariVC. Hitta orsaken med Console, Network, Storage, Performance och Sources."
    },
    "no": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """Det ultimate utviklerverktøyet for testing av WKWebView- og SFSafariViewController-konfigurasjoner i sanntid.

HOVEDFUNKSJONER

WKWebView-testing
• Sanntidskonfigurasjonstesting med over 20 alternativer
• Innebygde DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript-injeksjon og snippet-kjøring
• Tilpasset User-Agent-emulering
• Viewport- og enhetsemulering

SFSafariViewController-testing
• Safari-informasjonskapsler-/sesjonsdeling
• Content Blocker-støtte
• Reader Mode-konfigurasjon
• Safari-utvidelseskompatibilitet

Utviklerverktøy
• Console: console.log-fangst med %c CSS-stilstøtte
• Network: Overvåk fetch/XHR-forespørsler med tidsdata
• Storage: Vis/rediger localStorage, sessionStorage, informasjonskapsler
• Performance: Web Vitals (LCP, FID, CLS) og Navigation Timing
• Sources: DOM-treinspeksjon, stilark, skript
• Accessibility: axe-core-basert tilgjengelighetsrevisjon

Ytterligere funksjoner
• Bokmerkebehandling for rask URL-tilgang
• Responsiv viewportstørrelsesendring (iPhone, iPad, Desktop-forhåndsinnstillinger)
• Skjermbilde-fangst
• API-kapasitetsdeteksjon
• Støtte for mørk modus

Perfekt for iOS-utviklere som trenger å teste webinnholdsrendering, feilsøke JavaScript, analysere nettverksforespørsler og sikre tilgjengelighetsoverholdelse.
""",
        "keywords": "webview,utvikler,debug,konsoll,nettverk,safari,devtools,test,inspiser,ios,javascript,html,css",
        "whatsNew": "Feilrettinger og ytelsesforbedringer.",
        "promotionalText": "Se raskt hvordan webinnhold oppfører seg i WKWebView og SafariVC. Finn årsaken med Console, Network, Storage, Performance og Sources."
    },
    "da": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """Det ultimative udviklerværktøj til test af WKWebView- og SFSafariViewController-konfigurationer i realtid.

HOVEDFUNKTIONER

WKWebView-test
• Realtidskonfigurationstest med over 20 muligheder
• Indbyggede DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript-injektion og snippet-kørsel
• Tilpasset User-Agent-emulering
• Viewport- og enhedsemulering

SFSafariViewController-test
• Safari-cookie-/sessionsdeling
• Content Blocker-understøttelse
• Reader Mode-konfiguration
• Safari-udvidelseskompatibilitet

Udviklerværktøjer
• Console: console.log-optagelse med %c CSS-stilunderstøttelse
• Network: Overvåg fetch/XHR-anmodninger med tidsdata
• Storage: Vis/rediger localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) og Navigation Timing
• Sources: DOM-træinspektion, stilark, scripts
• Accessibility: axe-core-baseret tilgængelighedsrevision

Yderligere funktioner
• Bogmærkestyring til hurtig URL-adgang
• Responsiv viewport-størrelse (iPhone, iPad, Desktop-forudindstillinger)
• Skærmbillede
• API-kapacitetsdetektion
• Understøttelse af mørk tilstand

Perfekt til iOS-udviklere, der skal teste webindholdsgengivelse, debugge JavaScript, analysere netværksanmodninger og sikre tilgængelighedsoverholdelse.
""",
        "keywords": "webview,udvikler,debug,konsol,netværk,safari,devtools,test,inspicér,ios,javascript,html,css,browser",
        "whatsNew": "Fejlrettelser og ydelsesforbedringer.",
        "promotionalText": "Se hurtigt hvordan webindhold opfører sig i WKWebView og SafariVC. Find årsagen med Console, Network, Storage, Performance og Sources."
    },
    "fi": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Testaa WKWebView & SafariVC",
        "description": """Kehittäjätyökalu WKWebView- ja SFSafariViewController-konfiguraatioiden reaaliaikaiseen testaamiseen.

PÄÄOMINAISUUDET

WKWebView-testaus
• Reaaliaikainen konfiguraatiotestaus yli 20 vaihtoehdolla
• Sisäänrakennetut DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript-injektio ja snippet-suoritus
• Mukautettu User-Agent-emulointi
• Viewport- ja laiteemulointi

SFSafariViewController-testaus
• Safari-eväste-/istuntojakaminen
• Content Blocker -tuki
• Reader Mode -konfiguraatio
• Safari-laajennusyhteensopivuus

Kehittäjätyökalut
• Console: console.log-kaappaus %c CSS-tyylituella
• Network: Fetch/XHR-pyyntöjen seuranta ajoitustiedoilla
• Storage: localStorage-, sessionStorage-, evästeiden katselu/muokkaus
• Performance: Web Vitals (LCP, FID, CLS) ja Navigation Timing
• Sources: DOM-puun tarkastus, tyylisivut, skriptit
• Accessibility: axe-core-pohjainen saavutettavuustarkastus

Lisäominaisuudet
• Kirjanmerkkien hallinta nopeaan URL-käyttöön
• Responsiivinen viewport-koon muuttaminen (iPhone, iPad, Desktop-esiasetukset)
• Kuvakaappaus
• API-ominaisuuksien tunnistus
• Tumman tilan tuki

Täydellinen iOS-kehittäjille, jotka tarvitsevat web-sisällön renderöinnin testausta, JavaScript-virheenkorjausta, verkkopyyntöjen analysointia ja saavutettavuusvaatimusten varmistamista.
""",
        "keywords": "webview,kehittäjä,debug,konsoli,verkko,safari,devtools,testi,tarkasta,ios,javascript,html,css,selain",
        "whatsNew": "Virheenkorjauksia ja suorituskyvyn parannuksia.",
        "promotionalText": "Näe nopeasti, miten web-sisältö toimii WKWebViewissä ja SafariVC:ssä. Jäljitä syy Console-, Network-, Storage-, Performance- ja Sources-työkaluilla."
    },
    "cs": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """Ultimátní vývojářský nástroj pro testování konfigurací WKWebView a SFSafariViewController v reálném čase.

HLAVNÍ FUNKCE

Testování WKWebView
• Testování konfigurace v reálném čase s více než 20 možnostmi
• Vestavěné DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• Injekce JavaScriptu a spouštění snippetů
• Emulace vlastního User-Agent
• Emulace viewportu a zařízení

Testování SFSafariViewController
• Sdílení cookies/sessions Safari
• Podpora Content Blocker
• Konfigurace Reader Mode
• Kompatibilita s rozšířeními Safari

Vývojářské nástroje
• Console: Zachycení console.log s podporou %c CSS stylování
• Network: Monitorování fetch/XHR požadavků s časovými daty
• Storage: Zobrazení/úprava localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) a Navigation Timing
• Sources: Inspekce DOM stromu, styly, skripty
• Accessibility: Audit přístupnosti založený na axe-core

Další funkce
• Správa záložek pro rychlý přístup k URL
• Responzivní změna velikosti viewportu (presety iPhone, iPad, Desktop)
• Zachycení snímku obrazovky
• Detekce schopností API
• Podpora tmavého režimu

Ideální pro iOS vývojáře, kteří potřebují testovat vykreslování webového obsahu, debugovat JavaScript, analyzovat síťové požadavky a zajistit soulad s přístupností.
""",
        "keywords": "webview,vývojář,debug,konzole,síť,safari,devtools,test,inspektor,ios,javascript,html,css,prohlížeč",
        "whatsNew": "Opravy chyb a vylepšení výkonu.",
        "promotionalText": "Rychle ověřte, jak se webový obsah chová ve WKWebView a SafariVC. Sledujte příčinu pomocí Console, Network, Storage, Performance a Sources."
    },
    "sk": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """Ultimátny vývojársky nástroj pre testovanie konfigurácií WKWebView a SFSafariViewController v reálnom čase.

HLAVNÉ FUNKCIE

Testovanie WKWebView
• Testovanie konfigurácie v reálnom čase s viac ako 20 možnosťami
• Vstavané DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• Injekcia JavaScriptu a spúšťanie snippetov
• Emulácia vlastného User-Agent
• Emulácia viewportu a zariadenia

Testovanie SFSafariViewController
• Zdieľanie cookies/sessions Safari
• Podpora Content Blocker
• Konfigurácia Reader Mode
• Kompatibilita s rozšíreniami Safari

Vývojárske nástroje
• Console: Zachytenie console.log s podporou %c CSS štýlovania
• Network: Monitorovanie fetch/XHR požiadaviek s časovými údajmi
• Storage: Zobrazenie/úprava localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) a Navigation Timing
• Sources: Inšpekcia DOM stromu, štýly, skripty
• Accessibility: Audit prístupnosti založený na axe-core

Ďalšie funkcie
• Správa záložiek pre rýchly prístup k URL
• Responzívna zmena veľkosti viewportu (presety iPhone, iPad, Desktop)
• Zachytenie snímky obrazovky
• Detekcia schopností API
• Podpora tmavého režimu

Ideálne pre iOS vývojárov, ktorí potrebujú testovať vykresľovanie webového obsahu, debugovať JavaScript, analyzovať sieťové požiadavky a zabezpečiť súlad s prístupnosťou.
""",
        "keywords": "webview,vývojár,debug,konzola,sieť,safari,devtools,test,inšpektor,ios,javascript,html,css,prehliadač",
        "whatsNew": "Opravy chýb a vylepšenia výkonu.",
        "promotionalText": "Rýchlo overte, ako sa webový obsah správa vo WKWebView a SafariVC. Sledujte príčinu pomocou Console, Network, Storage, Performance a Sources."
    },
    "hu": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "WKWebView & SafariVC teszt",
        "description": """A tökéletes fejlesztői eszköz a WKWebView és SFSafariViewController konfigurációk valós idejű teszteléséhez.

FŐ JELLEMZŐK

WKWebView tesztelés
• Valós idejű konfigurációs tesztelés több mint 20 opcióval
• Beépített DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript injektálás és snippet végrehajtás
• Egyéni User-Agent emuláció
• Viewport és eszköz emuláció

SFSafariViewController tesztelés
• Safari cookie/munkamenet megosztás
• Content Blocker támogatás
• Reader Mode konfiguráció
• Safari bővítmény kompatibilitás

Fejlesztői eszközök
• Console: console.log rögzítés %c CSS stílus támogatással
• Network: Fetch/XHR kérések figyelése időadatokkal
• Storage: localStorage, sessionStorage, sütik megtekintése/szerkesztése
• Performance: Web Vitals (LCP, FID, CLS) és Navigation Timing
• Sources: DOM fa vizsgálat, stíluslapok, szkriptek
• Accessibility: axe-core alapú akadálymentességi audit

További funkciók
• Könyvjelzőkezelés a gyors URL-hozzáféréshez
• Reszponzív viewport méretezés (iPhone, iPad, Desktop előbeállítások)
• Képernyőkép rögzítés
• API képesség észlelése
• Sötét mód támogatás

Tökéletes iOS fejlesztőknek, akiknek webtartalom renderelést kell tesztelniük, JavaScript-et debugolniuk, hálózati kéréseket elemezniük és akadálymentességi megfelelőséget biztosítaniuk.
""",
        "keywords": "webview,fejlesztő,debug,konzol,hálózat,safari,devtools,teszt,vizsgálat,ios,javascript,html,css",
        "whatsNew": "Hibajavítások és teljesítménybeli fejlesztések.",
        "promotionalText": "Gyorsan nézze meg, hogyan viselkedik a webes tartalom WKWebViewben és SafariVC-ben. Kövesse az okot a Console, Network, Storage, Performance és Sources segítségével."
    },
    "ro": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView & SafariVC",
        "description": """Instrumentul suprem pentru dezvoltatori pentru testarea configurațiilor WKWebView și SFSafariViewController în timp real.

CARACTERISTICI PRINCIPALE

Testare WKWebView
• Testare configurație în timp real cu peste 20 de opțiuni
• DevTools încorporate: Console, Network, Storage, Performance, Sources, Accessibility
• Injectare JavaScript și execuție de snippeturi
• Emulare User-Agent personalizat
• Emulare viewport și dispozitiv

Testare SFSafariViewController
• Partajare cookies/sesiuni Safari
• Suport Content Blocker
• Configurare Reader Mode
• Compatibilitate extensii Safari

Instrumente pentru dezvoltatori
• Console: Captură console.log cu suport pentru stilizare CSS %c
• Network: Monitorizare cereri fetch/XHR cu date de sincronizare
• Storage: Vizualizare/editare localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) și Navigation Timing
• Sources: Inspecție arbore DOM, foi de stil, scripturi
• Accessibility: Audit de accesibilitate bazat pe axe-core

Caracteristici suplimentare
• Gestionare marcaje pentru acces rapid la URL-uri
• Redimensionare viewport responsiv (presetări iPhone, iPad, Desktop)
• Captură de ecran
• Detectare capabilități API
• Suport mod întunecat

Perfect pentru dezvoltatorii iOS care trebuie să testeze redarea conținutului web, să depaneze JavaScript, să analizeze cererile de rețea și să asigure conformitatea cu accesibilitatea.
""",
        "keywords": "webview,dezvoltator,debug,consolă,rețea,safari,devtools,test,inspector,ios,javascript,html,css",
        "whatsNew": "Remedieri de erori și îmbunătățiri de performanță.",
        "promotionalText": "Verificați rapid cum se comportă conținutul web în WKWebView și SafariVC. Urmăriți cauza cu Console, Network, Storage, Performance și Sources."
    },
    "hr": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Test WKWebView i SafariVC",
        "description": """Ultimativni alat za programere za testiranje WKWebView i SFSafariViewController konfiguracija u stvarnom vremenu.

GLAVNE ZNAČAJKE

WKWebView testiranje
• Testiranje konfiguracije u stvarnom vremenu s više od 20 opcija
• Ugrađeni DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• JavaScript injekcija i izvršavanje isječaka
• Prilagođena User-Agent emulacija
• Emulacija viewporta i uređaja

SFSafariViewController testiranje
• Dijeljenje Safari kolačića/sesija
• Podrška za Content Blocker
• Konfiguracija Reader Mode
• Kompatibilnost sa Safari proširenjima

Alati za programere
• Console: Hvatanje console.log s podrškom za %c CSS stiliziranje
• Network: Praćenje fetch/XHR zahtjeva s vremenskim podacima
• Storage: Pregled/uređivanje localStorage, sessionStorage, kolačića
• Performance: Web Vitals (LCP, FID, CLS) i Navigation Timing
• Sources: Inspekcija DOM stabla, stilske liste, skripte
• Accessibility: Revizija pristupačnosti temeljena na axe-core

Dodatne značajke
• Upravljanje oznakama za brzi pristup URL-ovima
• Responzivna promjena veličine viewporta (iPhone, iPad, Desktop predlošci)
• Hvatanje snimke zaslona
• Otkrivanje mogućnosti API-ja
• Podrška za tamni način

Savršeno za iOS programere koji trebaju testirati prikazivanje web sadržaja, debugirati JavaScript, analizirati mrežne zahtjeve i osigurati usklađenost s pristupačnošću.
""",
        "keywords": "webview,programer,debug,konzola,mreža,safari,devtools,test,inspektor,ios,javascript,html,css",
        "whatsNew": "Ispravci grešaka i poboljšanja performansi.",
        "promotionalText": "Brzo provjerite kako se web sadržaj ponaša u WKWebViewu i SafariVC-u. Pronađite uzrok uz Console, Network, Storage, Performance i Sources."
    },
    "el": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Δοκιμή WKWebView & SafariVC",
        "description": """Το απόλυτο εργαλείο προγραμματιστή για δοκιμή διαμορφώσεων WKWebView και SFSafariViewController σε πραγματικό χρόνο.

ΚΥΡΙΑ ΧΑΡΑΚΤΗΡΙΣΤΙΚΑ

Δοκιμή WKWebView
• Δοκιμή διαμόρφωσης σε πραγματικό χρόνο με πάνω από 20 επιλογές
• Ενσωματωμένα DevTools: Console, Network, Storage, Performance, Sources, Accessibility
• Έγχυση JavaScript και εκτέλεση snippets
• Προσαρμοσμένη εξομοίωση User-Agent
• Εξομοίωση viewport και συσκευής

Δοκιμή SFSafariViewController
• Κοινή χρήση cookies/sessions Safari
• Υποστήριξη Content Blocker
• Διαμόρφωση Reader Mode
• Συμβατότητα επεκτάσεων Safari

Εργαλεία προγραμματιστή
• Console: Σύλληψη console.log με υποστήριξη %c CSS styling
• Network: Παρακολούθηση αιτημάτων fetch/XHR με δεδομένα χρονισμού
• Storage: Προβολή/επεξεργασία localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) και Navigation Timing
• Sources: Επιθεώρηση δέντρου DOM, stylesheets, scripts
• Accessibility: Έλεγχος προσβασιμότητας βασισμένος στο axe-core

Επιπλέον χαρακτηριστικά
• Διαχείριση σελιδοδεικτών για γρήγορη πρόσβαση URL
• Αποκρινόμενη αλλαγή μεγέθους viewport (προεπιλογές iPhone, iPad, Desktop)
• Λήψη στιγμιότυπου οθόνης
• Ανίχνευση δυνατοτήτων API
• Υποστήριξη σκοτεινής λειτουργίας

Ιδανικό για iOS προγραμματιστές που χρειάζεται να δοκιμάσουν απόδοση περιεχομένου web, να κάνουν debug σε JavaScript, να αναλύσουν αιτήματα δικτύου και να εξασφαλίσουν συμμόρφωση προσβασιμότητας.
""",
        "keywords": "webview,προγραμματιστής,debug,κονσόλα,δίκτυο,safari,devtools,δοκιμή,ios,javascript,html,css",
        "whatsNew": "Διορθώσεις σφαλμάτων και βελτιώσεις απόδοσης.",
        "promotionalText": "Δείτε γρήγορα πώς συμπεριφέρεται το web περιεχόμενο σε WKWebView και SafariVC. Εντοπίστε την αιτία με Console, Network, Storage, Performance και Sources."
    },
    "he": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "בדיקת WKWebView ו-SafariVC",
        "description": """הכלי האולטימטיבי למפתחים לבדיקת הגדרות WKWebView ו-SFSafariViewController בזמן אמת.

תכונות עיקריות

בדיקת WKWebView
• בדיקת הגדרות בזמן אמת עם יותר מ-20 אפשרויות
• DevTools מובנים: Console, Network, Storage, Performance, Sources, Accessibility
• הזרקת JavaScript והרצת snippets
• אמולציית User-Agent מותאמת אישית
• אמולציית viewport ומכשיר

בדיקת SFSafariViewController
• שיתוף עוגיות/סשנים של Safari
• תמיכה ב-Content Blocker
• הגדרת Reader Mode
• תאימות לתוספי Safari

כלי מפתחים
• Console: לכידת console.log עם תמיכה בעיצוב CSS %c
• Network: מעקב אחר בקשות fetch/XHR עם נתוני תזמון
• Storage: צפייה/עריכת localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) ו-Navigation Timing
• Sources: בדיקת עץ DOM, גיליונות סגנון, סקריפטים
• Accessibility: ביקורת נגישות מבוססת axe-core

תכונות נוספות
• ניהול סימניות לגישה מהירה לכתובות URL
• שינוי גודל viewport רספונסיבי (הגדרות iPhone, iPad, Desktop)
• צילום מסך
• זיהוי יכולות API
• תמיכה במצב כהה

מושלם למפתחי iOS שצריכים לבדוק רינדור תוכן אינטרנט, לדבג JavaScript, לנתח בקשות רשת ולהבטיח עמידה בדרישות נגישות.
""",
        "keywords": "webview,מפתח,דיבאג,קונסול,רשת,safari,devtools,בדיקה,בדיקת,ios,javascript,html,css,דפדפן,כלי,פיתוח",
        "whatsNew": "תיקוני באגים ושיפורי ביצועים.",
        "promotionalText": "בדקו במהירות כיצד תוכן אינטרנט מתנהג ב‑WKWebView וב‑SafariVC. אתרו את הגורם בעזרת Console, Network, Storage, Performance ו‑Sources."
    },
    "ca": {
        "name": "Walnut: Webview Tester & Debug",
        "subtitle": "Provar WKWebView i SafariVC",
        "description": """L'eina definitiva per a desenvolupadors per provar configuracions de WKWebView i SFSafariViewController en temps real.

CARACTERÍSTIQUES PRINCIPALS

Proves de WKWebView
• Proves de configuració en temps real amb més de 20 opcions
• DevTools integrades: Console, Network, Storage, Performance, Sources, Accessibility
• Injecció de JavaScript i execució de snippets
• Emulació de User-Agent personalitzat
• Emulació de viewport i dispositiu

Proves de SFSafariViewController
• Compartir cookies/sessions de Safari
• Suport de Content Blocker
• Configuració de Reader Mode
• Compatibilitat amb extensions de Safari

Eines de desenvolupador
• Console: Captura de console.log amb suport d'estil CSS %c
• Network: Monitoratge de peticions fetch/XHR amb dades de temps
• Storage: Veure/editar localStorage, sessionStorage, cookies
• Performance: Web Vitals (LCP, FID, CLS) i Navigation Timing
• Sources: Inspecció de l'arbre DOM, fulls d'estil, scripts
• Accessibility: Auditoria d'accessibilitat basada en axe-core

Característiques addicionals
• Gestió de marcadors per a accés ràpid a URLs
• Redimensionament de viewport responsiu (presets iPhone, iPad, Desktop)
• Captura de pantalla
• Detecció de capacitats d'API
• Suport de mode fosc

Perfecte per a desenvolupadors iOS que necessiten provar el renderitzat de contingut web, depurar JavaScript, analitzar peticions de xarxa i assegurar el compliment d'accessibilitat.
""",
        "keywords": "webview,desenvolupador,debug,consola,xarxa,safari,devtools,prova,inspector,ios,javascript,html,css",
        "whatsNew": "Correccions d'errors i millores de rendiment.",
        "promotionalText": "Comproveu ràpidament com es comporta el contingut web a WKWebView i SafariVC. Localitzeu la causa amb Console, Network, Storage, Performance i Sources."
    }
}

# Default fallback for missing languages (use English)
DEFAULT_LOCALE = "en-US"


def generate_jwt_token():
    """Generate JWT token for App Store Connect API authentication"""
    with open(PRIVATE_KEY_PATH, 'r') as key_file:
        private_key = key_file.read()

    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1"
    }

    headers = {
        "alg": "ES256",
        "kid": KEY_ID,
        "typ": "JWT"
    }

    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    return token


def get_headers():
    """Get authorization headers for API requests"""
    token = generate_jwt_token()
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }


def get_app_id(bundle_id="com.kobbokkom.wina"):
    """Get App ID from bundle ID"""
    headers = get_headers()
    response = session.get(
        f"{BASE_URL}/apps",
        headers=headers,
        params={"filter[bundleId]": bundle_id}
    )
    response.raise_for_status()
    data = response.json()
    if data["data"]:
        return data["data"][0]["id"]
    raise ValueError(f"App with bundle ID {bundle_id} not found")


def get_app_info(app_id):
    """Get app info for the app - prefer editable state"""
    headers = get_headers()
    response = session.get(
        f"{BASE_URL}/apps/{app_id}/appInfos",
        headers=headers
    )
    response.raise_for_status()
    data = response.json()
    if data["data"]:
        # Prefer editable app info (not released)
        for info in data["data"]:
            state = info["attributes"].get("appStoreState", "")
            if state in ["PREPARE_FOR_SUBMISSION", "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "DEVELOPER_REJECTED", "REJECTED"]:
                print(f"   Using editable App Info (state: {state})")
                return info["id"]
        # Fall back to first if none are editable
        return data["data"][0]["id"]
    raise ValueError("No app info found")


def get_app_store_version(app_id):
    """Get the latest app store version"""
    headers = get_headers()
    # Get all versions without filter, then pick the editable one
    response = session.get(
        f"{BASE_URL}/apps/{app_id}/appStoreVersions",
        headers=headers
    )
    response.raise_for_status()
    data = response.json()
    if data["data"]:
        # Prefer versions that are editable (not released)
        for version in data["data"]:
            state = version["attributes"].get("appStoreState", "")
            if state in ["PREPARE_FOR_SUBMISSION", "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "DEVELOPER_REJECTED", "REJECTED"]:
                return version["id"]
        # Fall back to first version if none are editable
        return data["data"][0]["id"]
    raise ValueError("No app store version found")


def get_existing_localizations(app_info_id):
    """Get existing app info localizations"""
    headers = get_headers()
    response = session.get(
        f"{BASE_URL}/appInfos/{app_info_id}/appInfoLocalizations",
        headers=headers
    )
    response.raise_for_status()
    data = response.json()
    return {item["attributes"]["locale"]: item["id"] for item in data["data"]}


def get_existing_version_localizations(version_id):
    """Get existing app store version localizations"""
    headers = get_headers()
    response = session.get(
        f"{BASE_URL}/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        headers=headers
    )
    response.raise_for_status()
    data = response.json()
    return {item["attributes"]["locale"]: item["id"] for item in data["data"]}


def get_metadata_for_locale(locale):
    """Get metadata for a specific locale, falling back to English if needed"""
    if locale in METADATA:
        return METADATA[locale]

    # Map locales to their base language
    locale_mapping = {
        "en-AU": "en-US",
        "en-CA": "en-US",
        "en-GB": "en-US",
        "es-MX": "es-ES",
        "fr-CA": "fr-FR",
        "pt-PT": "pt-BR",
    }

    mapped_locale = locale_mapping.get(locale)
    if mapped_locale and mapped_locale in METADATA:
        return METADATA[mapped_locale]

    return METADATA[DEFAULT_LOCALE]


def update_app_info_localization(localization_id, locale, metadata):
    """Update existing app info localization"""
    headers = get_headers()
    payload = {
        "data": {
            "type": "appInfoLocalizations",
            "id": localization_id,
            "attributes": {
                "name": metadata.get("name", "")[:30],
                "subtitle": metadata.get("subtitle", "")[:30],
            }
        }
    }

    response = session.patch(
        f"{BASE_URL}/appInfoLocalizations/{localization_id}",
        headers=headers,
        json=payload
    )

    if response.status_code == 200:
        print(f"  ✅ Updated app info for {locale}")
        return True
    else:
        print(f"  ❌ Failed to update app info for {locale}: {response.status_code}")
        print(f"     {response.text[:200]}")
        return False


def create_app_info_localization(app_info_id, locale, metadata):
    """Create new app info localization"""
    headers = get_headers()
    payload = {
        "data": {
            "type": "appInfoLocalizations",
            "attributes": {
                "locale": locale,
                "name": metadata.get("name", "")[:30],
                "subtitle": metadata.get("subtitle", "")[:30],
            },
            "relationships": {
                "appInfo": {
                    "data": {
                        "type": "appInfos",
                        "id": app_info_id
                    }
                }
            }
        }
    }

    response = session.post(
        f"{BASE_URL}/appInfoLocalizations",
        headers=headers,
        json=payload
    )

    if response.status_code == 201:
        print(f"  ✅ Created app info for {locale}")
        return True
    else:
        print(f"  ❌ Failed to create app info for {locale}: {response.status_code}")
        print(f"     {response.text[:200]}")
        return False


def update_version_localization(localization_id, locale, metadata):
    """Update existing app store version localization"""
    headers = get_headers()
    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": localization_id,
            "attributes": {
                "description": metadata.get("description", "")[:4000],
                "keywords": metadata.get("keywords", "")[:100],
                "whatsNew": metadata.get("whatsNew", ""),
                "promotionalText": "Comproveu ràpidament com es comporta el contingut web a WKWebView i SafariVC. Localitzeu la causa amb Console, Network, Storage, Performance i Sources."
            }
        }
    }

    response = session.patch(
        f"{BASE_URL}/appStoreVersionLocalizations/{localization_id}",
        headers=headers,
        json=payload
    )

    if response.status_code == 200:
        print(f"  ✅ Updated version info for {locale}")
        return True
    else:
        print(f"  ❌ Failed to update version info for {locale}: {response.status_code}")
        print(f"     {response.text[:200]}")
        return False


def create_version_localization(version_id, locale, metadata):
    """Create new app store version localization"""
    headers = get_headers()
    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {
                "locale": locale,
                "description": metadata.get("description", "")[:4000],
                "keywords": metadata.get("keywords", "")[:100],
                "whatsNew": metadata.get("whatsNew", ""),
                "promotionalText": "Comproveu ràpidament com es comporta el contingut web a WKWebView i SafariVC. Localitzeu la causa amb Console, Network, Storage, Performance i Sources."
            },
            "relationships": {
                "appStoreVersion": {
                    "data": {
                        "type": "appStoreVersions",
                        "id": version_id
                    }
                }
            }
        }
    }

    response = session.post(
        f"{BASE_URL}/appStoreVersionLocalizations",
        headers=headers,
        json=payload
    )

    if response.status_code == 201:
        print(f"  ✅ Created version info for {locale}")
        return True
    else:
        print(f"  ❌ Failed to create version info for {locale}: {response.status_code}")
        print(f"     {response.text[:200]}")
        return False


def main():
    print("🚀 Starting App Store metadata upload...")
    print()

    # Get app info
    print("📱 Getting app information...")
    app_id = get_app_id()
    print(f"   App ID: {app_id}")

    app_info_id = get_app_info(app_id)
    print(f"   App Info ID: {app_info_id}")

    version_id = get_app_store_version(app_id)
    print(f"   Version ID: {version_id}")
    print()

    # Get existing localizations
    print("📋 Getting existing localizations...")
    existing_app_info = get_existing_localizations(app_info_id)
    existing_version = get_existing_version_localizations(version_id)
    print(f"   Existing app info locales: {len(existing_app_info)}")
    print(f"   Existing version locales: {len(existing_version)}")
    print()

    # Process each locale
    print("🌍 Processing localizations...")
    success_count = 0
    fail_count = 0

    for locale in LOCALES:
        print(f"\n📝 Processing {locale}...")
        metadata = get_metadata_for_locale(locale)

        # Update or create app info localization
        if locale in existing_app_info:
            if update_app_info_localization(existing_app_info[locale], locale, metadata):
                success_count += 1
            else:
                fail_count += 1
        else:
            if create_app_info_localization(app_info_id, locale, metadata):
                success_count += 1
            else:
                fail_count += 1

        # Update or create version localization
        if locale in existing_version:
            if update_version_localization(existing_version[locale], locale, metadata):
                success_count += 1
            else:
                fail_count += 1
        else:
            if create_version_localization(version_id, locale, metadata):
                success_count += 1
            else:
                fail_count += 1

    print()
    print("=" * 50)
    print(f"✅ Complete! Success: {success_count}, Failed: {fail_count}")
    print(f"🌍 Processed {len(LOCALES)} locales")


if __name__ == "__main__":
    main()
