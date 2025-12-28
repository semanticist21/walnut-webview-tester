//
//  AppSettingsView.swift
//  wina
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

// MARK: - App Language Enum (App Store Connect Supported Languages)

enum AppLanguage: String, CaseIterable, Identifiable {
    // System default
    case system = ""

    // English variants
    case englishUS = "en-US"
    case englishUK = "en-GB"
    case englishAU = "en-AU"
    case englishCA = "en-CA"

    // Chinese variants
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    // Spanish variants
    case spanishSpain = "es-ES"
    case spanishMexico = "es-MX"

    // Portuguese variants
    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"

    // French variants
    case french = "fr"
    case frenchCanada = "fr-CA"

    // Other languages (alphabetical)
    case arabic = "ar"
    case catalan = "ca"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case finnish = "fi"
    case german = "de"
    case greek = "el"
    case hebrew = "he"
    case hindi = "hi"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case malay = "ms"
    case norwegian = "no"
    case polish = "pl"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case swedish = "sv"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        // English
        case .englishUS: return "English (US)"
        case .englishUK: return "English (UK)"
        case .englishAU: return "English (Australia)"
        case .englishCA: return "English (Canada)"
        // Chinese
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        // Spanish
        case .spanishSpain: return "Español (España)"
        case .spanishMexico: return "Español (México)"
        // Portuguese
        case .portugueseBrazil: return "Português (Brasil)"
        case .portuguesePortugal: return "Português (Portugal)"
        // French
        case .french: return "Français"
        case .frenchCanada: return "Français (Canada)"
        // Others
        case .arabic: return "العربية"
        case .catalan: return "Català"
        case .croatian: return "Hrvatski"
        case .czech: return "Čeština"
        case .danish: return "Dansk"
        case .dutch: return "Nederlands"
        case .finnish: return "Suomi"
        case .german: return "Deutsch"
        case .greek: return "Ελληνικά"
        case .hebrew: return "עברית"
        case .hindi: return "हिन्दी"
        case .hungarian: return "Magyar"
        case .indonesian: return "Bahasa Indonesia"
        case .italian: return "Italiano"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .malay: return "Bahasa Melayu"
        case .norwegian: return "Norsk"
        case .polish: return "Polski"
        case .romanian: return "Română"
        case .russian: return "Русский"
        case .slovak: return "Slovenčina"
        case .swedish: return "Svenska"
        case .thai: return "ไทย"
        case .turkish: return "Türkçe"
        case .ukrainian: return "Українська"
        case .vietnamese: return "Tiếng Việt"
        }
    }

    var localizedName: String {
        switch self {
        case .system: return "System Default"
        case .englishUS: return "English (United States)"
        case .englishUK: return "English (United Kingdom)"
        case .englishAU: return "English (Australia)"
        case .englishCA: return "English (Canada)"
        case .chineseSimplified: return "Chinese (Simplified)"
        case .chineseTraditional: return "Chinese (Traditional)"
        case .spanishSpain: return "Spanish (Spain)"
        case .spanishMexico: return "Spanish (Mexico)"
        case .portugueseBrazil: return "Portuguese (Brazil)"
        case .portuguesePortugal: return "Portuguese (Portugal)"
        case .french: return "French"
        case .frenchCanada: return "French (Canada)"
        case .arabic: return "Arabic"
        case .catalan: return "Catalan"
        case .croatian: return "Croatian"
        case .czech: return "Czech"
        case .danish: return "Danish"
        case .dutch: return "Dutch"
        case .finnish: return "Finnish"
        case .german: return "German"
        case .greek: return "Greek"
        case .hebrew: return "Hebrew"
        case .hindi: return "Hindi"
        case .hungarian: return "Hungarian"
        case .indonesian: return "Indonesian"
        case .italian: return "Italian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .malay: return "Malay"
        case .norwegian: return "Norwegian"
        case .polish: return "Polish"
        case .romanian: return "Romanian"
        case .russian: return "Russian"
        case .slovak: return "Slovak"
        case .swedish: return "Swedish"
        case .thai: return "Thai"
        case .turkish: return "Turkish"
        case .ukrainian: return "Ukrainian"
        case .vietnamese: return "Vietnamese"
        }
    }
}

// MARK: - App Settings View

struct AppSettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = ""

    var body: some View {
        List {
            Section {
                Picker(selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language.rawValue)
                    }
                } label: {
                    Text("Language")
                }
            } header: {
                Text("Language")
            }
        }
        .navigationTitle(Text(verbatim: "App Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
