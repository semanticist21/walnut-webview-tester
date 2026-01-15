//
//  CallbackTestManager.swift
//  wina
//
//  Created by Claude on 1/15/26.
//

import os
import SwiftUI

/// Manages URL scheme callback testing
@Observable
@MainActor
final class CallbackTestManager {
    static let shared = CallbackTestManager()

    // MARK: - State

    /// Last received callback URL
    var lastCallbackURL: URL?

    /// Parsed parameters from callback
    var callbackParameters: [String: String] = [:]

    /// Timestamp of last callback
    var lastCallbackTime: Date?

    /// Trigger to show result alert
    var showResultAlert: Bool = false

    // MARK: - Constants

    /// URL scheme for this app
    static let urlScheme = "walnut"

    /// Test page URL for URL scheme callback testing
    static let testPageURL = URL(
        string: "https://walnut-callback-test.netlify.app"
    )!

    private let logger = Logger(subsystem: "com.walnut.wina", category: "CallbackTest")

    private init() {}

    // MARK: - URL Callback Handling

    /// Handle incoming URL from URL scheme
    func handleIncomingURL(_ url: URL) {
        logger.info("Received callback URL: \(url.absoluteString)")

        lastCallbackURL = url
        lastCallbackTime = Date()

        // Parse query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        {
            callbackParameters = Dictionary(
                uniqueKeysWithValues: queryItems.compactMap { item in
                    guard let value = item.value else { return nil }
                    return (item.name, value)
                }
            )
        } else {
            callbackParameters = [:]
        }

        // Trigger alert
        showResultAlert = true
    }

    // MARK: - Formatted Output

    /// Developer-friendly formatted result for display
    var formattedResult: String {
        guard let url = lastCallbackURL else { return "No callback received" }

        var lines: [String] = []

        // Header
        lines.append("━━━ URL SCHEME CALLBACK ━━━")
        lines.append("")

        // Scheme & Host
        lines.append("▸ Scheme: \(url.scheme ?? "nil")")
        lines.append("▸ Host: \(url.host ?? "nil")")
        if let path = url.path.isEmpty ? nil : url.path {
            lines.append("▸ Path: \(path)")
        }

        // Parameters
        if !callbackParameters.isEmpty {
            lines.append("")
            lines.append("▸ Parameters:")
            for (key, value) in callbackParameters.sorted(by: { $0.key < $1.key }) {
                lines.append("   • \(key): \(value)")
            }
        }

        // Timestamp
        if let time = lastCallbackTime {
            lines.append("")
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            lines.append("▸ Received: \(formatter.string(from: time))")
        }

        // Raw URL
        lines.append("")
        lines.append("━━━ RAW URL ━━━")
        lines.append(url.absoluteString)

        return lines.joined(separator: "\n")
    }

    /// Alert title based on callback path
    var alertTitle: String {
        guard let url = lastCallbackURL else { return "Callback Received" }
        let host = url.host ?? "callback"
        return "📥 \(Self.urlScheme)://\(host)"
    }

    /// Clear callback history
    func clearHistory() {
        lastCallbackURL = nil
        callbackParameters = [:]
        lastCallbackTime = nil
    }
}
