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

    // Major languages (alphabetical by language name)
    case arabic = "ar"
    case catalan = "ca"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case finnish = "fi"
    case french = "fr"
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
    case norwegian = "nb"
    case polish = "pl"
    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case spanish = "es"
    case swedish = "sv"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .arabic: return "العربية"
        case .catalan: return "Català"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .croatian: return "Hrvatski"
        case .czech: return "Čeština"
        case .danish: return "Dansk"
        case .dutch: return "Nederlands"
        case .english: return "English"
        case .finnish: return "Suomi"
        case .french: return "Français"
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
        case .portugueseBrazil: return "Português (Brasil)"
        case .portuguesePortugal: return "Português (Portugal)"
        case .romanian: return "Română"
        case .russian: return "Русский"
        case .slovak: return "Slovenčina"
        case .spanish: return "Español"
        case .swedish: return "Svenska"
        case .thai: return "ไทย"
        case .turkish: return "Türkçe"
        case .ukrainian: return "Українська"
        case .vietnamese: return "Tiếng Việt"
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
