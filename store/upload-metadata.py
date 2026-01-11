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
• Native Safari experience with content blockers
• Reader mode and responsive size control
• Customizable bar colors and dismiss button styles

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
        "whatsNew": "- Added screenshot and screen recording support for SafariVC mode.\\n- Improved recording state management.",
        "promotionalText": "Test WebView easily with Walnut. Quick URL management with bookmarks and history, plus debugging with Console, Network, and SourceView."
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
• Native Safari experience with content blockers
• Reader mode and responsive size control
• Customizable bar colors and dismiss button styles

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
        "whatsNew": "- Added screenshot and screen recording support for SafariVC mode.\\n- Improved recording state management.",
        "promotionalText": "Test WebView easily with Walnut. Quick URL management with bookmarks and history, plus debugging with Console, Network, and SourceView."
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
• Native Safari experience with content blockers
• Reader mode and responsive size control
• Customizable bar colors and dismiss button styles

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
        "whatsNew": "- Added screenshot and screen recording support for SafariVC mode.\\n- Improved recording state management.",
        "promotionalText": "Test WebView easily with Walnut. Quick URL management with bookmarks and history, plus debugging with Console, Network, and SourceView."
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
• Native Safari experience with content blockers
• Reader mode and responsive size control
• Customizable bar colors and dismiss button styles

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
        "whatsNew": "- Added screenshot and screen recording support for SafariVC mode.\\n- Improved recording state management.",
        "promotionalText": "Test WebView easily with Walnut. Quick URL management with bookmarks and history, plus debugging with Console, Network, and SourceView."
    },
    "ko": {
        "name": "Walnut: Webview 테스터 & 디버그",
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
• 콘텐츠 차단기를 포함한 네이티브 Safari 경험
• Reader Mode 및 반응형 크기 조절
• 바 색상 및 닫기 버튼 스타일 커스터마이징

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
        "whatsNew": "- SafariVC 모드에서 스크린샷 및 화면 녹화를 지원합니다.\n- 녹화 상태 관리가 개선되었습니다.",
        "promotionalText": "Walnut으로 WebView 테스트를 쉽게 해보세요. 북마크·히스토리 기반 URL 관리와 Console, Network, SourceView 내장 도구로 디버깅이 쉽습니다."
    },
    "ja": {
        "name": "Walnut: Webview テスター＆デバッグ",
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
• コンテンツブロッカーを含むネイティブSafari体験
• Reader Modeとレスポンシブサイズ調整
• バーの色と閉じるボタンスタイルのカスタマイズ

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
        "whatsNew": "- SafariVCモードでスクリーンショットと画面録画をサポートしました。\n- 録画状態の管理を改善しました。",
        "promotionalText": "WalnutでWebViewテストを簡単に。ブックマーク/履歴でURL管理が速く、Console・Network・SourceViewなど内蔵ツールでデバッグも簡単です。"
    },
    "zh-Hans": {
        "name": "Walnut: Webview 测试与调试",
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
• 支持内容拦截器的原生Safari体验
• Reader Mode和响应式尺寸控制
• 可自定义栏颜色和关闭按钮样式

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
        "whatsNew": "- 增加了SafariVC模式下的截屏和屏幕录制功能。\n- 改进了录制状态管理。",
        "promotionalText": "用Walnut轻松测试WebView。通过书签/历史管理URL快速访问，并用Console、Network、SourceView等内置工具轻松调试。"
    },
    "zh-Hant": {
        "name": "Walnut: Webview 測試與除錯",
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
• 支援內容阻擋器的原生Safari體驗
• Reader Mode和響應式尺寸控制
• 可自訂列顏色和關閉按鈕樣式

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
        "whatsNew": "- 增加了SafariVC模式下的截圖和螢幕錄製功能。\n- 改進了錄製狀態管理。",
        "promotionalText": "用Walnut輕鬆測試WebView。透過書籤/歷史管理URL快速存取，並用Console、Network、SourceView等內建工具輕鬆除錯。"
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
• Native Safari-Erfahrung mit Content Blockern
• Reader Mode und responsive Größenanpassung
• Anpassbare Leistenfarben und Schließen-Schaltflächen

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
        "whatsNew": "- Screenshot- und Bildschirmaufnahme-Unterstützung für den SafariVC-Modus hinzugefügt.\n- Aufnahmestatusverwaltung verbessert.",
        "promotionalText": "WebView-Tests ganz einfach mit Walnut. Schneller URL-Zugriff über Lesezeichen und Verlauf, Debugging mit Console, Network und SourceView."
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
• Expérience Safari native avec bloqueurs de contenu
• Reader Mode et contrôle de taille réactif
• Couleurs de barre et styles de bouton personnalisables

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
        "whatsNew": "- Ajout de la prise en charge des captures d'écran et de l'enregistrement vidéo pour le mode SafariVC.\n- Amélioration de la gestion de l'état d'enregistrement.",
        "promotionalText": "Testez WebView facilement avec Walnut. Gestion rapide des URL via favoris et historique, et débogage avec Console, Network et SourceView."
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
• Expérience Safari native avec bloqueurs de contenu
• Reader Mode et contrôle de taille réactif
• Couleurs de barre et styles de bouton personnalisables

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
        "whatsNew": "- Ajout de la prise en charge des captures d'écran et de l'enregistrement vidéo pour le mode SafariVC.\n- Amélioration de la gestion de l'état d'enregistrement.",
        "promotionalText": "Testez WebView facilement avec Walnut. Gestion rapide des URL via favoris et historique, et débogage avec Console, Network et SourceView."
    },
    "es-ES": {
        "name": "Walnut: Webview Test & Depuración",
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
• Experiencia Safari nativa con bloqueadores de contenido
• Reader Mode y control de tamaño responsivo
• Colores de barra y estilos de botón personalizables

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
        "whatsNew": "- Añadida la captura de pantalla y grabación de video en modo SafariVC.\n- Mejora en la gestión del estado de grabación.",
        "promotionalText": "Pruebe WebView fácilmente con Walnut. Gestión rápida de URL con marcadores e historial, y depuración con Console, Network y SourceView."
    },
    "es-MX": {
        "name": "Walnut: Webview Test & Depuración",
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
• Experiencia Safari nativa con bloqueadores de contenido
• Reader Mode y control de tamaño responsivo
• Colores de barra y estilos de botón personalizables

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
        "whatsNew": "- Añadida la captura de pantalla y grabación de video en modo SafariVC.\n- Mejora en la gestión del estado de grabación.",
        "promotionalText": "Pruebe WebView fácilmente con Walnut. Gestión rápida de URL con marcadores e historial, y depuración con Console, Network y SourceView."
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
• Esperienza Safari nativa con blocco contenuti
• Reader Mode e controllo dimensioni reattivo
• Colori della barra e stili dei pulsanti personalizzabili
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
        "whatsNew": "- Aggiunto supporto per screenshot e registrazione dello schermo in modalità SafariVC.\n- Migliorata la gestione dello stato di registrazione.",
        "promotionalText": "Testa WebView facilmente con Walnut. Gestione rapida degli URL con segnalibri e cronologia, debug con Console, Network e SourceView."
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
• Experiência Safari nativa com bloqueadores de conteúdo
• Reader Mode e controle de tamanho responsivo
• Cores da barra e estilos de botão personalizáveis
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
        "whatsNew": "- Adicionado suporte a captura de tela e gravação de vídeo no modo SafariVC.\n- Melhoria no gerenciamento do estado de gravação.",
        "promotionalText": "Teste WebView facilmente com o Walnut. Gestão rápida de URLs com favoritos e histórico, e debug com Console, Network e SourceView."
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
• Experiência Safari nativa com bloqueadores de conteúdo
• Reader Mode e controle de tamanho responsivo
• Cores da barra e estilos de botão personalizáveis
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
        "whatsNew": "- Adicionado suporte a captura de tela e gravação de vídeo no modo SafariVC.\n- Melhoria no gerenciamento do estado de gravação.",
        "promotionalText": "Teste WebView facilmente com o Walnut. Gestão rápida de URLs com marcadores e histórico, e debug com Console, Network e SourceView."
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
• Нативный опыт Safari с блокировщиками контента
• Reader Mode и адаптивное управление размером
• Настраиваемые цвета панели и стили кнопок

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
        "whatsNew": "- Добавлена поддержка снимков экрана и записи экрана в режиме SafariVC.\n- Улучшено управление состоянием записи.",
        "promotionalText": "Тестируйте WebView легко с Walnut. Быстрое управление URL через закладки и историю, отладка с Console, Network и SourceView."
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
• تجربة Safari الأصلية مع حاجب المحتوى
• وضع القارئ والتحكم في الحجم المتجاوب
• ألوان الشريط وأنماط الأزرار القابلة للتخصيص

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
        "whatsNew": "- تمت إضافة دعم لقطة الشاشة وتسجيل الشاشة لوضع SafariVC.\n- تحسين إدارة حالة التسجيل.",
        "promotionalText": "اختبر WebView بسهولة مع Walnut. إدارة سريعة للروابط عبر الإشارات المرجعية والسجل، وتصحيح مع Console وNetwork وSourceView."
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
• कंटेंट ब्लॉकर्स के साथ नेटिव Safari अनुभव
• Reader Mode और रिस्पॉन्सिव साइज़ कंट्रोल
• कस्टमाइज़ेबल बार कलर और बटन स्टाइल

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
        "whatsNew": "- SafariVC मोड के लिए स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग सपोर्ट जोड़ा गया।\n- रिकॉर्डिंग स्टेट मैनेजमेंट में सुधार।",
        "promotionalText": "Walnut के साथ WebView को आसानी से टेस्ट करें। बुकमार्क/हिस्ट्री से URL प्रबंधन तेज़, और Console, Network, SourceView से डिबगिंग आसान।"
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
• ประสบการณ์ Safari ดั้งเดิมพร้อม Content Blockers
• Reader Mode และการควบคุมขนาดแบบ Responsive
• สีแถบและสไตล์ปุ่มที่ปรับแต่งได้

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
        "whatsNew": "- เพิ่มการสนับสนุนการจับภาพหน้าจอและการบันทึกหน้าจอสำหรับโหมด SafariVC\n- ปรับปรุงการจัดการสถานะการบันทึก",
        "promotionalText": "ทดสอบ WebView ได้ง่ายด้วย Walnut. จัดการ URL ได้เร็วด้วยบุ๊กมาร์กและประวัติ และดีบักด้วย Console, Network, SourceView."
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
• Trải nghiệm Safari gốc với trình chặn nội dung
• Reader Mode và điều khiển kích thước responsive
• Màu thanh và kiểu nút có thể tùy chỉnh

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
        "whatsNew": "- Thêm hỗ trợ chụp màn hình và quay màn hình cho chế độ SafariVC.\n- Cải thiện quản lý trạng thái ghi.",
        "promotionalText": "Kiểm thử WebView dễ dàng với Walnut. Quản lý URL nhanh bằng dấu trang và lịch sử, và debug với Console, Network, SourceView."
    },
    "id": {
        "name": "Walnut: Webview Tes & Debug",
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
• Pengalaman Safari native dengan pemblokir konten
• Reader Mode dan kontrol ukuran responsif
• Warna bar dan gaya tombol yang dapat disesuaikan

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
        "whatsNew": "- Menambahkan dukungan tangkapan layar dan perekaman layar untuk mode SafariVC.\n- Peningkatan manajemen status perekaman.",
        "promotionalText": "Uji WebView dengan mudah lewat Walnut. Kelola URL cepat lewat bookmark dan riwayat, dan debug dengan Console, Network, SourceView."
    },
    "ms": {
        "name": "Walnut: Webview Uji & Nyahpepijat",
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
• Pengalaman Safari asli dengan penyekat kandungan
• Reader Mode dan kawalan saiz responsif
• Warna bar dan gaya butang yang boleh disesuaikan

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
        "whatsNew": "- Menambah sokongan tangkapan skrin dan rakaman skrin untuk mod SafariVC.\n- Pengurusan status rakaman yang dipertingkatkan.",
        "promotionalText": "Uji WebView dengan mudah bersama Walnut. Urus URL dengan pantas melalui penanda buku dan sejarah, dan nyahpepijat dengan Console, Network, SourceView."
    },
    "nl-NL": {
        "name": "Walnut: Webview Test & Debug",
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
• Native Safari-ervaring met contentblockers
• Reader Mode en responsieve groottecontrole
• Aanpasbare balkkleuren en knopstijlen

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
        "whatsNew": "- Ondersteuning voor schermafbeeldingen en schermopname toegevoegd voor SafariVC-modus.\n- Verbeterd beheer van opnamestatus.",
        "promotionalText": "Test WebView eenvoudig met Walnut. Snel URL-beheer via bladwijzers en geschiedenis, en debug met Console, Network en SourceView."
    },
    "pl": {
        "name": "Walnut: Webview Test i Debug",
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
• Natywne doświadczenie Safari z blokerami treści
• Reader Mode i responsywna kontrola rozmiaru
• Konfigurowalne kolory paska i style przycisków

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
        "whatsNew": "- Dodano obsługę zrzutów ekranu i nagrywania ekranu w trybie SafariVC.\n- Poprawiono zarządzanie stanem nagrywania.",
        "promotionalText": "Testuj WebView łatwo z Walnut. Szybkie zarządzanie URL dzięki zakładkom i historii, debug z Console, Network i SourceView."
    },
    "tr": {
        "name": "Walnut: Webview Test & Hata Ayıklama",
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
• İçerik engelleyicilerle yerel Safari deneyimi
• Reader Mode ve duyarlı boyut kontrolü
• Özelleştirilebilir çubuk renkleri ve düğme stilleri

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
        "whatsNew": "- SafariVC modunda ekran görüntüsü ve ekran kaydı desteği eklendi.\n- Kayıt durumu yönetimi iyileştirildi.",
        "promotionalText": "Walnut ile WebView testini kolayca yapın. Yer imi ve geçmişle URL yönetimi hızlı, Console, Network, SourceView ile hata ayıklama kolay."
    },
    "uk": {
        "name": "Walnut: Webview Тест і Налагодження",
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
• Нативний досвід Safari з блокувальниками контенту
• Reader Mode та адаптивне керування розміром
• Налаштовувані кольори панелі та стилі кнопок

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
        "whatsNew": "- Додано підтримку знімків екрану та запису екрану для режиму SafariVC.\n- Покращено керування станом запису.",
        "promotionalText": "Легко тестуйте WebView з Walnut. Швидке керування URL через закладки й історію та дебаг із Console, Network і SourceView."
    },
    "sv": {
        "name": "Walnut: Webview Test & Debug",
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
• Native Safari-upplevelse med innehållsblockerare
• Reader Mode och responsiv storlekskontroll
• Anpassningsbara fältfärger och knappformat

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
        "whatsNew": "- Lagt till stöd för skärmdumpar och skärminspelning för SafariVC-läge.\n- Förbättrad hantering av inspelningsstatus.",
        "promotionalText": "Testa WebView enkelt med Walnut. Snabb URL-hantering via bokmärken och historik, och debug med Console, Network och SourceView."
    },
    "no": {
        "name": "Walnut: Webview Test & Debug",
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
• Native Safari-opplevelse med innholdsblokkere
• Reader Mode og responsiv størrelseskontroll
• Tilpassbare feltfarger og knappstiler

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
        "whatsNew": "- Lagt til støtte for skjermbilder og skjermopptak for SafariVC-modus.\n- Forbedret håndtering av innspillingsstatus.",
        "promotionalText": "Test WebView enkelt med Walnut. Rask URL-håndtering med bokmerker og historikk, og debugging med Console, Network og SourceView."
    },
    "da": {
        "name": "Walnut: Webview Test & Debug",
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
• Native Safari-oplevelse med indholdsblokkere
• Reader Mode og responsiv størrelseskontrol
• Tilpasselige bjælkefarver og knapstile

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
        "whatsNew": "- Tilføjet understøttelse af skærmbilleder og skærmoptagelse for SafariVC-tilstand.\n- Forbedret styring af optagelsesstatus.",
        "promotionalText": "Test WebView nemt med Walnut. Hurtig URL-styring via bogmærker og historik, og debug med Console, Network og SourceView."
    },
    "fi": {
        "name": "Walnut: Webview Testi & Debug",
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
• Natiivi Safari-kokemus sisällönestäjillä
• Reader Mode ja responsiivinen kokohallinta
• Mukautettavat palkkivärit ja painiketyylit

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
        "whatsNew": "- Lisätty kuvakaappaus- ja näytön tallennustuki SafariVC-tilaan.\n- Parannettu tallennustilan hallintaa.",
        "promotionalText": "Testaa WebView helposti Walnutilla. Nopea URL-hallinta kirjanmerkeillä ja historialla, debuggaus Console-, Network- ja SourceView-työkaluilla."
    },
    "cs": {
        "name": "Walnut: Webview Test & Debug",
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
• Nativní Safari zážitek s blokátory obsahu
• Reader Mode a responzivní ovládání velikosti
• Přizpůsobitelné barvy lišty a styly tlačítek

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
        "whatsNew": "- Přidána podpora snímků obrazovky a nahrávání obrazovky pro režim SafariVC.\n- Vylepšená správa stavu nahrávání.",
        "promotionalText": "Testujte WebView snadno s Walnut. Rychlá správa URL přes záložky a historii, ladění s Console, Network a SourceView."
    },
    "sk": {
        "name": "Walnut: Webview Test & Debug",
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
• Natívny Safari zážitok s blokátormi obsahu
• Reader Mode a responzívne ovládanie veľkosti
• Prispôsobiteľné farby lišty a štýly tlačidiel

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
        "whatsNew": "- Pridaná podpora snímok obrazovky a nahrávania obrazovky pre režim SafariVC.\n- Vylepšená správa stavu nahrávania.",
        "promotionalText": "Testujte WebView jednoducho s Walnut. Rýchla správa URL cez záložky a históriu, ladenie s Console, Network a SourceView."
    },
    "hu": {
        "name": "Walnut: Webview Teszt & Debug",
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
• Natív Safari élmény tartalomblokkolókkal
• Reader Mode és reszponzív méretvezérlés
• Testreszabható sávszínek és gombstílusok

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
        "whatsNew": "- Képernyőkép és képernyőfelvétel támogatás hozzáadva a SafariVC módhoz.\n- Javított felvételi állapotkezelés.",
        "promotionalText": "WebView‑tesztek könnyen a Walnuttal. Gyors URL‑kezelés könyvjelzőkkel és előzményekkel, hibakeresés Console, Network és SourceView eszközökkel."
    },
    "ro": {
        "name": "Walnut: Webview Test & Depanare",
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
• Experiență Safari nativă cu blocatoare de conținut
• Reader Mode și control dimensiune responsiv
• Culori bară și stiluri butoane personalizabile

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
        "whatsNew": "- Adăugat suport pentru capturi de ecran și înregistrare ecran în modul SafariVC.\n- Îmbunătățită gestionarea stării de înregistrare.",
        "promotionalText": "Testează WebView ușor cu Walnut. Gestionare rapidă a URL‑urilor prin marcaje și istoric, și debug cu Console, Network și SourceView."
    },
    "hr": {
        "name": "Walnut: Webview Test & Debug",
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
• Izvorno Safari iskustvo s blokatorima sadržaja
• Reader Mode i responzivna kontrola veličine
• Prilagodljive boje trake i stilovi gumba

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
        "whatsNew": "- Dodana podrška za snimanje zaslona i snimanje zaslona za SafariVC način rada.\n- Poboljšano upravljanje stanjem snimanja.",
        "promotionalText": "Testirajte WebView lako uz Walnut. Brzo upravljanje URL‑ovima putem oznaka i povijesti, te debug s Console, Network i SourceView."
    },
    "el": {
        "name": "Walnut: Webview Δοκιμή & Debug",
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
• Εγγενής εμπειρία Safari με αποκλεισμό περιεχομένου
• Reader Mode και αποκριτικός έλεγχος μεγέθους
• Προσαρμόσιμα χρώματα γραμμής και στυλ κουμπιών

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
        "whatsNew": "- Προστέθηκε υποστήριξη λήψης στιγμιότυπων και εγγραφής οθόνης για τη λειτουργία SafariVC.\n- Βελτιωμένη διαχείριση κατάστασης εγγραφής.",
        "promotionalText": "Δοκιμάστε εύκολα WebView με το Walnut. Γρήγορη διαχείριση URL με σελιδοδείκτες/ιστορικό και debug με Console, Network, SourceView."
    },
    "he": {
        "name": "Walnut: Webview בדיקה ודיבוג",
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
• חוויית Safari מקורית עם חוסמי תוכן
• Reader Mode ובקרת גודל רספונסיבית
• צבעי סרגל וסגנונות כפתורים הניתנים להתאמה

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
        "whatsNew": "- נוספה תמיכה בצילום מסך והקלטת מסך למצב SafariVC.\n- שיפור ניהול מצב ההקלטה.",
        "promotionalText": "בדקו WebView בקלות עם Walnut. ניהול URL מהיר בעזרת סימניות והיסטוריה, ודיבוג עם Console, Network ו‑SourceView."
    },
    "ca": {
        "name": "Walnut: Webview Test & Depuració",
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
• Experiència Safari nativa amb blocadors de contingut
• Reader Mode i control de mida responsiu
• Colors de barra i estils de botó personalitzables

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
        "whatsNew": "- Afegit suport per a captures de pantalla i gravació de pantalla per al mode SafariVC.\n- Millora en la gestió de l'estat de gravació.",
        "promotionalText": "Prova WebView fàcilment amb Walnut. Gestió d'URL ràpida amb marcadors i historial, i depuració amb Console, Network i SourceView."
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
    """No-op: app info updates are intentionally disabled."""
    return True


def create_app_info_localization(app_info_id, locale, metadata):
    """No-op: app info updates are intentionally disabled."""
    return True


def update_version_localization(localization_id, locale, metadata):
    """Update existing app store version localization"""
    headers = get_headers()
    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": localization_id,
            "attributes": {
                "description": metadata.get("description", ""),
                "keywords": metadata.get("keywords", "")[:100],
                "whatsNew": metadata.get("whatsNew", ""),
                "promotionalText": metadata.get("promotionalText", "")
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
                "description": metadata.get("description", ""),
                "keywords": metadata.get("keywords", "")[:100],
                "whatsNew": metadata.get("whatsNew", ""),
                "promotionalText": metadata.get("promotionalText", "")
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
