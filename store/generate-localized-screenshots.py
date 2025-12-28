#!/usr/bin/env python3
"""Generate localized App Store screenshots for all 39 supported languages."""

import os
import re

# Define translations for each language
# Format: (title1, desc1, title2, desc2, title3, desc3, title_ipad3, desc_ipad3)
TRANSLATIONS = {
    # English variants
    "en-US": (
        "WebView Tester", "Test WKWebView &amp; SafariVC instantly",
        "Built-in DevTools", "Console, Network, Storage and more",
        "Customize Settings", "Fine-tune options for precise testing",
        "WebView Capabilities", "Check API support and device info"
    ),
    "en-GB": (
        "WebView Tester", "Test WKWebView &amp; SafariVC instantly",
        "Built-in DevTools", "Console, Network, Storage and more",
        "Customise Settings", "Fine-tune options for precise testing",
        "WebView Capabilities", "Check API support and device info"
    ),
    "en-AU": (
        "WebView Tester", "Test WKWebView &amp; SafariVC instantly",
        "Built-in DevTools", "Console, Network, Storage and more",
        "Customise Settings", "Fine-tune options for precise testing",
        "WebView Capabilities", "Check API support and device info"
    ),
    "en-CA": (
        "WebView Tester", "Test WKWebView &amp; SafariVC instantly",
        "Built-in DevTools", "Console, Network, Storage and more",
        "Customize Settings", "Fine-tune options for precise testing",
        "WebView Capabilities", "Check API support and device info"
    ),

    # Korean (요체 - polite conversational)
    "ko": (
        "WebView 테스터", "WKWebView와 SafariVC를 바로 테스트해요",
        "내장 개발자 도구", "콘솔, 네트워크, 저장소 등을 확인해요",
        "설정 커스터마이즈", "세밀한 테스트를 위해 옵션을 조정해요",
        "WebView 기능", "API 지원과 기기 정보를 확인해요"
    ),

    # Japanese
    "ja": (
        "WebView テスター", "WKWebViewとSafariVCをすぐにテスト",
        "内蔵デベロッパーツール", "コンソール、ネットワーク、ストレージなど",
        "設定をカスタマイズ", "細かいテストのためのオプション調整",
        "WebView 機能", "APIサポートとデバイス情報を確認"
    ),

    # Chinese Simplified
    "zh-Hans": (
        "WebView 测试工具", "即刻测试 WKWebView 和 SafariVC",
        "内置开发者工具", "控制台、网络、存储等功能",
        "自定义设置", "精细调整测试选项",
        "WebView 功能", "查看 API 支持和设备信息"
    ),

    # Chinese Traditional
    "zh-Hant": (
        "WebView 測試工具", "即刻測試 WKWebView 和 SafariVC",
        "內建開發者工具", "控制台、網路、儲存等功能",
        "自訂設定", "精細調整測試選項",
        "WebView 功能", "查看 API 支援和裝置資訊"
    ),

    # German
    "de-DE": (
        "WebView Tester", "WKWebView &amp; SafariVC sofort testen",
        "Integrierte Entwicklertools", "Konsole, Netzwerk, Speicher und mehr",
        "Einstellungen anpassen", "Optionen für präzises Testen optimieren",
        "WebView Funktionen", "API-Unterstützung und Geräteinfo prüfen"
    ),

    # French (France)
    "fr-FR": (
        "Testeur WebView", "Testez WKWebView &amp; SafariVC instantanément",
        "Outils de développement", "Console, Réseau, Stockage et plus",
        "Personnaliser les réglages", "Affinez les options pour des tests précis",
        "Fonctionnalités WebView", "Vérifiez le support API et les infos appareil"
    ),

    # French (Canada)
    "fr-CA": (
        "Testeur WebView", "Testez WKWebView &amp; SafariVC instantanément",
        "Outils de développement", "Console, Réseau, Stockage et plus",
        "Personnaliser les paramètres", "Ajustez les options pour des tests précis",
        "Fonctionnalités WebView", "Vérifiez le support API et les infos appareil"
    ),

    # Spanish (Spain)
    "es-ES": (
        "Probador WebView", "Prueba WKWebView y SafariVC al instante",
        "Herramientas de desarrollo", "Consola, Red, Almacenamiento y más",
        "Personalizar ajustes", "Afina las opciones para pruebas precisas",
        "Funciones WebView", "Consulta el soporte API e info del dispositivo"
    ),

    # Spanish (Mexico)
    "es-MX": (
        "Probador WebView", "Prueba WKWebView y SafariVC al instante",
        "Herramientas de desarrollo", "Consola, Red, Almacenamiento y más",
        "Personalizar configuración", "Ajusta las opciones para pruebas precisas",
        "Funciones WebView", "Consulta el soporte API e info del dispositivo"
    ),

    # Portuguese (Brazil)
    "pt-BR": (
        "Testador WebView", "Teste WKWebView e SafariVC instantaneamente",
        "Ferramentas do desenvolvedor", "Console, Rede, Armazenamento e mais",
        "Personalizar configurações", "Ajuste fino das opções para testes precisos",
        "Funcionalidades WebView", "Verifique suporte de API e info do dispositivo"
    ),

    # Portuguese (Portugal)
    "pt-PT": (
        "Testador WebView", "Teste WKWebView e SafariVC instantaneamente",
        "Ferramentas de desenvolvimento", "Consola, Rede, Armazenamento e mais",
        "Personalizar definições", "Ajuste as opções para testes precisos",
        "Funcionalidades WebView", "Verifique suporte API e info do dispositivo"
    ),

    # Italian
    "it": (
        "Tester WebView", "Testa WKWebView e SafariVC all'istante",
        "Strumenti sviluppatore", "Console, Rete, Archiviazione e altro",
        "Personalizza impostazioni", "Regola le opzioni per test precisi",
        "Funzionalità WebView", "Verifica supporto API e info dispositivo"
    ),

    # Dutch
    "nl-NL": (
        "WebView Tester", "Test WKWebView &amp; SafariVC direct",
        "Ingebouwde ontwikkelaarstools", "Console, Netwerk, Opslag en meer",
        "Instellingen aanpassen", "Opties fijn afstemmen voor precies testen",
        "WebView Mogelijkheden", "Controleer API-ondersteuning en apparaatinfo"
    ),

    # Russian
    "ru": (
        "Тестер WebView", "Мгновенно тестируйте WKWebView и SafariVC",
        "Встроенные инструменты", "Консоль, Сеть, Хранилище и другое",
        "Настройка параметров", "Точная настройка опций для тестирования",
        "Возможности WebView", "Проверьте поддержку API и информацию"
    ),

    # Ukrainian
    "uk": (
        "Тестер WebView", "Миттєво тестуйте WKWebView та SafariVC",
        "Вбудовані інструменти", "Консоль, Мережа, Сховище та інше",
        "Налаштування параметрів", "Точне налаштування для тестування",
        "Можливості WebView", "Перевірте підтримку API та інформацію"
    ),

    # Polish
    "pl": (
        "Tester WebView", "Testuj WKWebView i SafariVC natychmiast",
        "Wbudowane narzędzia", "Konsola, Sieć, Pamięć i więcej",
        "Dostosuj ustawienia", "Dopasuj opcje do precyzyjnych testów",
        "Funkcje WebView", "Sprawdź obsługę API i info o urządzeniu"
    ),

    # Turkish
    "tr": (
        "WebView Test Aracı", "WKWebView ve SafariVC'yi anında test edin",
        "Yerleşik Geliştirici Araçları", "Konsol, Ağ, Depolama ve daha fazlası",
        "Ayarları Özelleştir", "Hassas test için seçenekleri ayarlayın",
        "WebView Özellikleri", "API desteğini ve cihaz bilgisini kontrol edin"
    ),

    # Arabic
    "ar-SA": (
        "مختبر WebView", "اختبر WKWebView و SafariVC فوراً",
        "أدوات المطور المدمجة", "وحدة التحكم والشبكة والتخزين والمزيد",
        "تخصيص الإعدادات", "ضبط الخيارات للاختبار الدقيق",
        "إمكانيات WebView", "تحقق من دعم API ومعلومات الجهاز"
    ),

    # Hebrew
    "he": (
        "בודק WebView", "בדוק WKWebView ו-SafariVC מיידית",
        "כלי פיתוח מובנים", "קונסול, רשת, אחסון ועוד",
        "התאמת הגדרות", "כוונון אפשרויות לבדיקות מדויקות",
        "יכולות WebView", "בדוק תמיכת API ומידע על המכשיר"
    ),

    # Hindi
    "hi": (
        "WebView टेस्टर", "WKWebView और SafariVC को तुरंत टेस्ट करें",
        "बिल्ट-इन डेवटूल्स", "कंसोल, नेटवर्क, स्टोरेज और बहुत कुछ",
        "सेटिंग्स कस्टमाइज़ करें", "सटीक परीक्षण के लिए विकल्पों को समायोजित करें",
        "WebView क्षमताएं", "API सपोर्ट और डिवाइस जानकारी जांचें"
    ),

    # Thai
    "th": (
        "WebView Tester", "ทดสอบ WKWebView และ SafariVC ได้ทันที",
        "เครื่องมือนักพัฒนาในตัว", "คอนโซล เครือข่าย พื้นที่จัดเก็บ และอื่นๆ",
        "ปรับแต่งการตั้งค่า", "ปรับตัวเลือกสำหรับการทดสอบที่แม่นยำ",
        "ความสามารถ WebView", "ตรวจสอบการรองรับ API และข้อมูลอุปกรณ์"
    ),

    # Vietnamese
    "vi": (
        "Công cụ thử nghiệm WebView", "Thử nghiệm WKWebView &amp; SafariVC ngay",
        "Công cụ phát triển tích hợp", "Console, Mạng, Lưu trữ và nhiều hơn",
        "Tùy chỉnh cài đặt", "Tinh chỉnh các tùy chọn để thử nghiệm chính xác",
        "Khả năng WebView", "Kiểm tra hỗ trợ API và thông tin thiết bị"
    ),

    # Indonesian
    "id": (
        "Penguji WebView", "Uji WKWebView &amp; SafariVC secara instan",
        "Alat Pengembang Bawaan", "Console, Jaringan, Penyimpanan, dan lainnya",
        "Sesuaikan Pengaturan", "Atur opsi untuk pengujian yang presisi",
        "Kemampuan WebView", "Periksa dukungan API dan info perangkat"
    ),

    # Malay
    "ms": (
        "Penguji WebView", "Uji WKWebView &amp; SafariVC dengan segera",
        "Alat Pembangun Terbina Dalam", "Konsol, Rangkaian, Storan dan lagi",
        "Sesuaikan Tetapan", "Laraskan pilihan untuk ujian yang tepat",
        "Keupayaan WebView", "Semak sokongan API dan maklumat peranti"
    ),

    # Danish
    "da": (
        "WebView Tester", "Test WKWebView og SafariVC med det samme",
        "Indbyggede udviklerværktøjer", "Konsol, Netværk, Lagring og mere",
        "Tilpas indstillinger", "Finjuster muligheder til præcis test",
        "WebView-funktioner", "Tjek API-understøttelse og enhedsinfo"
    ),

    # Swedish
    "sv": (
        "WebView Testare", "Testa WKWebView och SafariVC direkt",
        "Inbyggda utvecklarverktyg", "Konsol, Nätverk, Lagring och mer",
        "Anpassa inställningar", "Finjustera alternativ för exakt testning",
        "WebView Funktioner", "Kontrollera API-stöd och enhetsinformation"
    ),

    # Norwegian
    "no": (
        "WebView Tester", "Test WKWebView og SafariVC umiddelbart",
        "Innebygde utviklerverktøy", "Konsoll, Nettverk, Lagring og mer",
        "Tilpass innstillinger", "Finjuster alternativer for presis testing",
        "WebView Funksjoner", "Sjekk API-støtte og enhetsinformasjon"
    ),

    # Finnish
    "fi": (
        "WebView Testaaja", "Testaa WKWebView ja SafariVC heti",
        "Sisäänrakennetut kehitystyökalut", "Konsoli, Verkko, Tallennustila ja muuta",
        "Mukauta asetuksia", "Säädä vaihtoehtoja tarkkaan testaukseen",
        "WebView-ominaisuudet", "Tarkista API-tuki ja laitetiedot"
    ),

    # Czech
    "cs": (
        "WebView Tester", "Okamžitě otestujte WKWebView a SafariVC",
        "Vestavěné vývojářské nástroje", "Konzole, Síť, Úložiště a další",
        "Přizpůsobit nastavení", "Upravte možnosti pro přesné testování",
        "Funkce WebView", "Zkontrolujte podporu API a info o zařízení"
    ),

    # Slovak
    "sk": (
        "WebView Tester", "Okamžite otestujte WKWebView a SafariVC",
        "Vstavané vývojárske nástroje", "Konzola, Sieť, Úložisko a viac",
        "Prispôsobiť nastavenia", "Upravte možnosti pre presné testovanie",
        "Funkcie WebView", "Skontrolujte podporu API a info o zariadení"
    ),

    # Hungarian
    "hu": (
        "WebView Tesztelő", "WKWebView és SafariVC azonnali tesztelése",
        "Beépített fejlesztőeszközök", "Konzol, Hálózat, Tárhely és még sok más",
        "Beállítások testreszabása", "Opciók finomhangolása a pontos teszteléshez",
        "WebView Képességek", "API támogatás és eszközinformáció ellenőrzése"
    ),

    # Romanian
    "ro": (
        "Tester WebView", "Testați WKWebView și SafariVC instant",
        "Instrumente dezvoltator integrate", "Consolă, Rețea, Stocare și mai multe",
        "Personalizare setări", "Ajustați opțiunile pentru testare precisă",
        "Funcționalități WebView", "Verificați suportul API și info dispozitiv"
    ),

    # Greek
    "el": (
        "Δοκιμαστής WebView", "Δοκιμάστε WKWebView &amp; SafariVC αμέσως",
        "Ενσωματωμένα εργαλεία ανάπτυξης", "Κονσόλα, Δίκτυο, Αποθήκευση και άλλα",
        "Προσαρμογή ρυθμίσεων", "Ρυθμίστε επιλογές για ακριβείς δοκιμές",
        "Δυνατότητες WebView", "Ελέγξτε υποστήριξη API και πληροφορίες συσκευής"
    ),

    # Croatian
    "hr": (
        "WebView Tester", "Testirajte WKWebView i SafariVC odmah",
        "Ugrađeni razvojni alati", "Konzola, Mreža, Pohrana i više",
        "Prilagodi postavke", "Fino podesite opcije za precizno testiranje",
        "WebView Mogućnosti", "Provjerite podršku za API i info o uređaju"
    ),

    # Catalan
    "ca": (
        "Provador WebView", "Prova WKWebView i SafariVC a l'instant",
        "Eines de desenvolupador integrades", "Consola, Xarxa, Emmagatzematge i més",
        "Personalitzar configuració", "Ajusteu les opcions per a proves precises",
        "Funcionalitats WebView", "Comproveu el suport d'API i info del dispositiu"
    ),
}

def escape_for_regex(text):
    """Escape special regex characters."""
    return re.escape(text)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    # Original English texts to replace
    originals = {
        "title1": "WebView Tester",
        "desc1": "Test WKWebView &amp; SafariVC instantly",
        "title2": "Built-in DevTools",
        "desc2": "Console, Network, Storage and more",
        "title3": "Customize Settings",
        "desc3": "Fine-tune options for precise testing",
        "title_ipad3": "WebView Capabilities",
        "desc_ipad3": "Check API support and device info",
    }

    print(f"Generating localized screenshots for {len(TRANSLATIONS)} languages...")

    for lang, texts in TRANSLATIONS.items():
        print(f"Processing: {lang}")

        title1, desc1, title2, desc2, title3, desc3, title_ipad3, desc_ipad3 = texts

        # Create language directory
        os.makedirs(lang, exist_ok=True)

        # iPhone screenshots (1.svg, 2.svg, 3.svg)
        for i in [1, 2, 3]:
            src_file = f"en/{i}.svg"
            dst_file = f"{lang}/{i}.svg"

            with open(src_file, "r", encoding="utf-8") as f:
                content = f.read()

            # Replace texts based on which screenshot
            if i == 1:
                content = content.replace(f">{originals['title1']}<", f">{title1}<")
                content = content.replace(f">{originals['desc1']}<", f">{desc1}<")
            elif i == 2:
                content = content.replace(f">{originals['title2']}<", f">{title2}<")
                content = content.replace(f">{originals['desc2']}<", f">{desc2}<")
            elif i == 3:
                content = content.replace(f">{originals['title3']}<", f">{title3}<")
                content = content.replace(f">{originals['desc3']}<", f">{desc3}<")

            with open(dst_file, "w", encoding="utf-8") as f:
                f.write(content)

        # iPad screenshots (ipad-1.svg, ipad-2.svg, ipad-3.svg)
        for i in [1, 2, 3]:
            src_file = f"en/ipad-{i}.svg"
            dst_file = f"{lang}/ipad-{i}.svg"

            with open(src_file, "r", encoding="utf-8") as f:
                content = f.read()

            # Replace texts based on which screenshot
            if i == 1:
                content = content.replace(f">{originals['title1']}<", f">{title1}<")
                content = content.replace(f">{originals['desc1']}<", f">{desc1}<")
            elif i == 2:
                content = content.replace(f">{originals['title2']}<", f">{title2}<")
                content = content.replace(f">{originals['desc2']}<", f">{desc2}<")
            elif i == 3:
                content = content.replace(f">{originals['title_ipad3']}<", f">{title_ipad3}<")
                content = content.replace(f">{originals['desc_ipad3']}<", f">{desc_ipad3}<")

            with open(dst_file, "w", encoding="utf-8") as f:
                f.write(content)

    print(f"\nDone! Generated screenshots for {len(TRANSLATIONS)} languages.")
    print("\nLanguages generated:")
    for lang in sorted(TRANSLATIONS.keys()):
        print(f"  - {lang}")


if __name__ == "__main__":
    main()
