//
//  NetworkDetailView+Tabs.swift
//  wina
//
//  Tab content extensions for NetworkDetailView.
//

import SwiftUI

// MARK: - Tab Content

extension NetworkDetailView {
    // MARK: - Overview Tab

    @ViewBuilder
    var overviewContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Timing visualization
            NetworkTimingView(request: request)

            // Stack trace - shows where the request originated
            StackTraceView(stackFrames: request.stackFrames)
        }
        .padding()
    }

    // MARK: - Headers Tab

    @ViewBuilder
    var headersContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // General info section
            DetailSection(title: "General", rawText: generalRawText, onCopy: copyToClipboard) {
                DetailTableRow(key: "Request URL", value: request.url, onCopy: copyToClipboard)
                DetailTableRow(key: "Request Method", value: request.method, onCopy: copyToClipboard)
                if let status = request.status, let statusText = request.statusText {
                    DetailTableRow(key: "Status Code", value: "\(status) \(statusText)", onCopy: copyToClipboard)
                } else if let status = request.status {
                    DetailTableRow(key: "Status Code", value: "\(status)", onCopy: copyToClipboard)
                }
                DetailTableRow(
                    key: "Type",
                    value: request.requestType.rawValue.capitalized,
                    onCopy: copyToClipboard,
                    showBorder: false
                )
            }

            // Response headers
            if let headers = request.responseHeaders, !headers.isEmpty {
                let sortedHeaders = headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
                DetailSection(
                    title: "Response Headers",
                    rawText: formatHeadersForCopy(headers),
                    onCopy: copyToClipboard
                ) {
                    ForEach(Array(sortedHeaders.enumerated()), id: \.element.key) { index, pair in
                        DetailTableRow(
                            key: pair.key,
                            value: pair.value,
                            onCopy: copyToClipboard,
                            showBorder: index < sortedHeaders.count - 1
                        )
                    }
                }
            }

            // Request headers
            if let headers = request.requestHeaders, !headers.isEmpty {
                let sortedHeaders = headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
                DetailSection(
                    title: "Request Headers",
                    rawText: formatHeadersForCopy(headers),
                    onCopy: copyToClipboard
                ) {
                    ForEach(Array(sortedHeaders.enumerated()), id: \.element.key) { index, pair in
                        DetailTableRow(
                            key: pair.key,
                            value: pair.value,
                            onCopy: copyToClipboard,
                            showBorder: index < sortedHeaders.count - 1
                        )
                    }
                }
            }

            if request.requestHeaders == nil && request.responseHeaders == nil {
                emptyState(message: "No headers available")
            }
        }
        .padding()
    }

    var generalRawText: String {
        var lines: [String] = []
        lines.append("Request URL: \(request.url)")
        lines.append("Request Method: \(request.method)")
        if let status = request.status, let statusText = request.statusText {
            lines.append("Status Code: \(status) \(statusText)")
        } else if let status = request.status {
            lines.append("Status Code: \(status)")
        }
        lines.append("Type: \(request.requestType.rawValue.capitalized)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Request Tab

    @ViewBuilder
    var requestContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // URL breakdown
            if let urlComponents = URLComponents(string: request.url) {
                DetailSection(title: "URL", rawText: urlRawText(urlComponents), onCopy: copyToClipboard) {
                    if let scheme = urlComponents.scheme {
                        DetailTableRow(key: "Scheme", value: scheme, onCopy: copyToClipboard)
                    }
                    if let host = urlComponents.host {
                        DetailTableRow(key: "Host", value: host, onCopy: copyToClipboard)
                    }
                    if let port = urlComponents.port {
                        DetailTableRow(key: "Port", value: "\(port)", onCopy: copyToClipboard)
                    }
                    DetailTableRow(
                        key: "Path",
                        value: urlComponents.path.isEmpty ? "/" : urlComponents.path,
                        onCopy: copyToClipboard,
                        showBorder: false
                    )
                }

                // Query parameters
                if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                    DetailSection(
                        title: "Query Parameters",
                        rawText: queryParametersRawText(queryItems),
                        onCopy: copyToClipboard
                    ) {
                        ForEach(Array(queryItems.enumerated()), id: \.element.name) { index, item in
                            DetailTableRow(
                                key: item.name,
                                value: item.value ?? "(empty)",
                                onCopy: copyToClipboard,
                                showBorder: index < queryItems.count - 1
                            )
                        }
                    }
                }
            }

            // Request body
            if let body = request.requestBody, !body.isEmpty {
                let networkContentType = detectContentType(body: body, headers: request.requestHeaders)
                let responseFormatterType = networkContentType.toResponseContentType()
                let bodySize = body.data(using: .utf8)?.count ?? 0
                DetailSection(title: "Request Body", rawText: body, onCopy: copyToClipboard) {
                    BodyHeaderView(contentType: networkContentType, size: bodySize)
                    ResponseFormatterView(
                        responseBody: body,
                        contentType: responseFormatterType
                    )
                    .frame(minHeight: 200)
                }
            } else {
                emptyState(message: "No request body")
            }
        }
        .padding()
    }

    func urlRawText(_ components: URLComponents) -> String {
        var lines: [String] = []
        if let scheme = components.scheme {
            lines.append("Scheme: \(scheme)")
        }
        if let host = components.host {
            lines.append("Host: \(host)")
        }
        if let port = components.port {
            lines.append("Port: \(port)")
        }
        lines.append("Path: \(components.path.isEmpty ? "/" : components.path)")
        return lines.joined(separator: "\n")
    }

    func queryParametersRawText(_ items: [URLQueryItem]) -> String {
        items.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
    }

    // MARK: - Response Tab

    @ViewBuilder
    var responseContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let body = request.responseBody, !body.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    let networkContentType = detectContentType(body: body, headers: request.responseHeaders)
                    let responseFormatterType = networkContentType.toResponseContentType()
                    let bodySize = body.data(using: .utf8)?.count ?? 0

                    DetailSection(
                        title: "Response Body",
                        rawText: body,
                        onCopy: copyToClipboard,
                        onShare: {
                            shareResponseBodyAsFile(body: body, contentType: networkContentType)
                        },
                        content: {
                            BodyHeaderView(contentType: networkContentType, size: bodySize)
                            ResponseFormatterView(
                                responseBody: body,
                                contentType: responseFormatterType
                            )
                            .frame(minHeight: 200)
                        }
                    )
                }
                .padding()
            } else {
                SecurityRestrictionBanner(type: .staticResourceBody)
                    .padding()
            }
        }
    }
}
