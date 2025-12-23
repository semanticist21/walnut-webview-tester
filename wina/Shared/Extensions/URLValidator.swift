//
//  URLValidator.swift
//  wina
//
//  URL validation utilities for testing and validating URLs and IP addresses.
//

import Foundation

// MARK: - URL Validator

/// Utilities for validating URLs and IP addresses
enum URLValidator {

    // Cached NSDataDetector for URL validation (expensive to create)
    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    /// Validates if a string is a valid URL
    /// - Parameter string: URL string to validate
    /// - Returns: true if valid URL, false otherwise
    static func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Add https:// if no scheme present
        var urlString = trimmed
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        guard let url = URL(string: urlString), let host = url.host else {
            return false
        }

        // Special handling for localhost
        if host == "localhost" {
            return true
        }

        // Special handling for IP addresses
        if isValidIPv4Address(host) {
            return true
        }

        // Host must contain at least one dot (for TLD)
        // This rejects "www.naver" but allows "www.naver.com"
        guard host.contains(".") else {
            return false
        }

        // URL validation using cached NSDataDetector (Apple's link detection engine)
        guard let detector = linkDetector else {
            return false
        }

        let range = NSRange(urlString.startIndex..., in: urlString)
        let matches = detector.matches(in: urlString, options: [], range: range)

        // Exactly one match must cover the entire string
        guard matches.count == 1,
              let match = matches.first,
              match.range.location == 0,
              match.range.length == urlString.utf16.count else {
            return false
        }

        return true
    }

    /// Validates if a string is a valid IPv4 address
    /// - Parameter string: IP address string to validate
    /// - Returns: true if valid IPv4 address, false otherwise
    static func isValidIPv4Address(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }

        return parts.allSatisfy { part in
            // Must be a valid number
            guard let num = Int(part) else { return false }
            // Must be in range 0-255
            guard num >= 0 && num <= 255 else { return false }
            // Must not have leading zeros (except for "0" itself)
            // "01" is invalid, "0" is valid, "10" is valid
            if part.count > 1 && part.first == "0" { return false }
            return true
        }
    }

    /// Normalizes a URL string by adding https:// scheme if missing
    /// - Parameter string: URL string to normalize
    /// - Returns: Normalized URL string with scheme
    static func normalizeURL(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        return "https://" + trimmed
    }

    /// Checks whether the URL string is supported by SFSafariViewController.
    /// SafariVC only accepts http/https URLs.
    static func isSupportedSafariURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            return scheme == "http" || scheme == "https"
        }

        let normalized = normalizeURL(trimmed)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    /// Extracts the host from a URL string
    /// - Parameter string: URL string
    /// - Returns: Host string or nil if invalid
    static func extractHost(_ string: String) -> String? {
        let normalized = normalizeURL(string)
        return URL(string: normalized)?.host
    }
}
