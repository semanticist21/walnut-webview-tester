import Foundation

// MARK: - User Agent Builder

/// Helps build custom User Agent strings with modifiable components
struct UserAgentBuilder {

    // MARK: - Component Types

    enum BrowserEngine: String, CaseIterable {
        case webkit = "AppleWebKit/537.36"
        case gecko = "Gecko/20100101"
        case presto = "Presto/2.12.388"

        var compatString: String {
            switch self {
            case .webkit: return "(KHTML, like Gecko)"
            case .gecko: return ""
            case .presto: return ""
            }
        }
    }

    struct PlatformToken {
        let token: String
        let description: String

        static let windowsDesktop = PlatformToken(
            token: "Windows NT 10.0; Win64; x64",
            description: "Windows 10/11 64-bit"
        )
        static let macDesktop = PlatformToken(
            token: "Macintosh; Intel Mac OS X 10_15_7",
            description: "macOS (Intel)"
        )
        static let macAppleSilicon = PlatformToken(
            token: "Macintosh; ARM Mac OS X 10_15_7",
            description: "macOS (Apple Silicon)"
        )
        static let linux = PlatformToken(
            token: "X11; Linux x86_64",
            description: "Linux 64-bit"
        )
        static let android = PlatformToken(
            token: "Linux; Android 10; K",
            description: "Android (Reduced)"
        )
        static let iphone = PlatformToken(
            token: "iPhone; CPU iPhone OS 18_0 like Mac OS X",
            description: "iPhone iOS 18"
        )
        static let ipad = PlatformToken(
            token: "iPad; CPU OS 18_0 like Mac OS X",
            description: "iPad iPadOS 18"
        )

        static let all: [PlatformToken] = [
            windowsDesktop, macDesktop, macAppleSilicon, linux,
            android, iphone, ipad,
        ]
    }

    // MARK: - Builder State

    var platform: PlatformToken
    var engine: BrowserEngine
    var browserName: String
    var browserVersion: String
    var additionalTokens: [String]

    // MARK: - Initialization

    init(
        platform: PlatformToken = .windowsDesktop,
        engine: BrowserEngine = .webkit,
        browserName: String = "Chrome",
        browserVersion: String = "131.0.0.0",
        additionalTokens: [String] = []
    ) {
        self.platform = platform
        self.engine = engine
        self.browserName = browserName
        self.browserVersion = browserVersion
        self.additionalTokens = additionalTokens
    }

    // MARK: - Build

    func build() -> String {
        var parts: [String] = ["Mozilla/5.0"]

        // Platform
        parts.append("(\(platform.token))")

        // Engine
        parts.append(engine.rawValue)
        if !engine.compatString.isEmpty {
            parts.append(engine.compatString)
        }

        // Browser
        parts.append("\(browserName)/\(browserVersion)")

        // Additional tokens (Safari compat, etc.)
        if engine == .webkit {
            parts.append("Safari/537.36")
        }

        // Custom tokens
        additionalTokens.forEach { parts.append($0) }

        return parts.joined(separator: " ")
    }

    // MARK: - Prebuilt Configurations

    static func chrome(version: String = "131.0.0.0", platform: PlatformToken = .windowsDesktop) -> UserAgentBuilder {
        UserAgentBuilder(
            platform: platform,
            engine: .webkit,
            browserName: "Chrome",
            browserVersion: version
        )
    }

    static func safari(version: String = "18.2", platform: PlatformToken = .macDesktop) -> UserAgentBuilder {
        var builder = UserAgentBuilder(
            platform: platform,
            engine: .webkit,
            browserName: "Version",
            browserVersion: version
        )
        builder.additionalTokens = ["Safari/605.1.15"]
        return builder
    }

    static func firefox(version: String = "133.0", platform: PlatformToken = .windowsDesktop) -> UserAgentBuilder {
        UserAgentBuilder(
            platform: platform,
            engine: .gecko,
            browserName: "Firefox",
            browserVersion: version
        )
    }

    static func edge(version: String = "131.0.0.0", platform: PlatformToken = .windowsDesktop) -> UserAgentBuilder {
        var builder = chrome(version: version, platform: platform)
        builder.additionalTokens = ["Edg/\(version)"]
        return builder
    }
}

// MARK: - User Agent Parser

struct UserAgentParser {

    struct ParsedUserAgent {
        var mozilla: String = "5.0"
        var platform: String = ""
        var engine: String = ""
        var engineVersion: String = ""
        var browser: String = ""
        var browserVersion: String = ""
        var extras: [String] = []

        var isMobile: Bool {
            platform.contains("iPhone") ||
            platform.contains("Android") ||
            platform.contains("Mobile")
        }

        var isTablet: Bool {
            platform.contains("iPad") ||
            (platform.contains("Android") && !platform.contains("Mobile"))
        }

        var osName: String {
            if platform.contains("Windows") { return "Windows" }
            if platform.contains("Mac OS X") { return "macOS" }
            if platform.contains("Linux") && platform.contains("Android") { return "Android" }
            if platform.contains("Linux") { return "Linux" }
            if platform.contains("iPhone") { return "iOS" }
            if platform.contains("iPad") { return "iPadOS" }
            return "Unknown"
        }
    }

    static func parse(_ userAgent: String) -> ParsedUserAgent {
        var result = ParsedUserAgent()

        // Mozilla version
        if let mozRange = userAgent.range(of: "Mozilla/") {
            let start = mozRange.upperBound
            if let end = userAgent[start...].firstIndex(of: " ") {
                result.mozilla = String(userAgent[start..<end])
            }
        }

        // Platform (in parentheses)
        if let openParen = userAgent.firstIndex(of: "("),
           let closeParen = userAgent.firstIndex(of: ")") {
            let start = userAgent.index(after: openParen)
            result.platform = String(userAgent[start..<closeParen])
        }

        // Engine
        if userAgent.contains("AppleWebKit/") {
            result.engine = "WebKit"
            if let range = userAgent.range(of: "AppleWebKit/") {
                let start = range.upperBound
                if let end = userAgent[start...].firstIndex(of: " ") {
                    result.engineVersion = String(userAgent[start..<end])
                }
            }
        } else if userAgent.contains("Gecko/") {
            result.engine = "Gecko"
            if let range = userAgent.range(of: "rv:") {
                let start = range.upperBound
                if let end = userAgent[start...].firstIndex(where: { $0 == ")" || $0 == " " }) {
                    result.engineVersion = String(userAgent[start..<end])
                }
            }
        }

        // Browser detection (order matters - most specific first)
        let browserPatterns: [(pattern: String, name: String)] = [
            ("Edg/", "Edge"),
            ("EdgA/", "Edge Android"),
            ("EdgiOS/", "Edge iOS"),
            ("OPR/", "Opera"),
            ("Brave", "Brave"),
            ("CriOS/", "Chrome iOS"),
            ("FxiOS/", "Firefox iOS"),
            ("Firefox/", "Firefox"),
            ("Chrome/", "Chrome"),
            ("Safari/", "Safari"),
        ]

        for (pattern, name) in browserPatterns {
            if let range = userAgent.range(of: pattern) {
                result.browser = name
                let start = range.upperBound
                if let end = userAgent[start...].firstIndex(where: { $0 == " " || $0 == ")" }) {
                    result.browserVersion = String(userAgent[start..<end])
                } else {
                    result.browserVersion = String(userAgent[start...])
                }
                break
            }
        }

        // If Safari but also has Version/, use Version number
        if result.browser == "Safari",
           let versionRange = userAgent.range(of: "Version/") {
            let start = versionRange.upperBound
            if let end = userAgent[start...].firstIndex(of: " ") {
                result.browserVersion = String(userAgent[start..<end])
            }
        }

        return result
    }
}

// MARK: - Version Modifier

struct UserAgentVersionModifier {

    static func updateChromeVersion(_ userAgent: String, to newVersion: String) -> String {
        let pattern = "Chrome/[0-9.]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return userAgent }

        let range = NSRange(userAgent.startIndex..., in: userAgent)
        return regex.stringByReplacingMatches(
            in: userAgent,
            range: range,
            withTemplate: "Chrome/\(newVersion)"
        )
    }

    static func updateFirefoxVersion(_ userAgent: String, to newVersion: String) -> String {
        let pattern = "Firefox/[0-9.]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return userAgent }

        let range = NSRange(userAgent.startIndex..., in: userAgent)
        return regex.stringByReplacingMatches(
            in: userAgent,
            range: range,
            withTemplate: "Firefox/\(newVersion)"
        )
    }

    static func updateSafariVersion(_ userAgent: String, to newVersion: String) -> String {
        let pattern = "Version/[0-9.]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return userAgent }

        let range = NSRange(userAgent.startIndex..., in: userAgent)
        return regex.stringByReplacingMatches(
            in: userAgent,
            range: range,
            withTemplate: "Version/\(newVersion)"
        )
    }

    static func updateiOSVersion(_ userAgent: String, to newVersion: String) -> String {
        // Convert 18.2 to 18_2
        let versionToken = newVersion.replacingOccurrences(of: ".", with: "_")
        let pattern = "(iPhone OS |CPU OS )[0-9_]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return userAgent }

        let range = NSRange(userAgent.startIndex..., in: userAgent)
        return regex.stringByReplacingMatches(
            in: userAgent,
            range: range,
            withTemplate: "$1\(versionToken)"
        )
    }

    static func updateAndroidVersion(_ userAgent: String, to newVersion: String) -> String {
        let pattern = "Android [0-9.]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return userAgent }

        let range = NSRange(userAgent.startIndex..., in: userAgent)
        return regex.stringByReplacingMatches(
            in: userAgent,
            range: range,
            withTemplate: "Android \(newVersion)"
        )
    }
}
