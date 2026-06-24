//
//  PreloadCookieApplicator.swift
//  wina
//
//  Applies preload cookies before the first WKWebView navigation.
//

import Foundation
import WebKit

enum PreloadCookieApplicator {
    static func apply(
        profile: WebViewPreloadProfile,
        url: URL,
        cookieStore: WKHTTPCookieStore,
        completion: @escaping () -> Void
    ) {
        let cookies = profile.cookies
            .filter(\.isEnabled)
            .compactMap { makeHTTPCookie(from: $0, url: url) }

        guard !cookies.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) {
                group.leave()
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    static func makeHTTPCookie(from preloadCookie: PreloadCookie, url: URL) -> HTTPCookie? {
        guard !preloadCookie.name.isEmpty else { return nil }

        let domain: String
        switch preloadCookie.domainMode {
        case .currentHost:
            guard let host = url.host, !host.isEmpty else { return nil }
            domain = host

        case .custom:
            guard !preloadCookie.customDomain.isEmpty else { return nil }
            domain = preloadCookie.customDomain
        }

        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: preloadCookie.name,
            .value: preloadCookie.value,
            .domain: domain,
            .path: preloadCookie.path.isEmpty ? "/" : preloadCookie.path,
            .sameSitePolicy: preloadCookie.sameSite.httpCookieString,
        ]

        if preloadCookie.isSecure {
            properties[.secure] = "TRUE"
        }

        if let expiresDate = preloadCookie.expires.expiresDate {
            properties[.expires] = expiresDate
        }

        if preloadCookie.isHTTPOnly {
            properties[.init("HttpOnly")] = "TRUE"
        }

        return HTTPCookie(properties: properties)
    }
}
