//
//  NetworkRequestTests.swift
//  winaTests
//
//  Tests for NetworkRequest model: status colors, duration formatting,
//  content type detection, security indicators, and Equatable.
//

import SwiftUI
import Testing
@testable import wina

// MARK: - NetworkRequest Status Tests

@Suite("NetworkRequest Status")
struct NetworkRequestStatusTests {

    private func makeRequest(status: Int? = nil, error: String? = nil, endTime: Date? = nil) -> NetworkRequest {
        NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: status,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: endTime,
            error: error,
            requestType: .fetch
        )
    }

    @Test("Status 2xx is success (green)")
    func testStatus2xxIsGreen() {
        let request200 = makeRequest(status: 200)
        let request201 = makeRequest(status: 201)
        let request204 = makeRequest(status: 204)

        #expect(request200.statusColor == .green)
        #expect(request201.statusColor == .green)
        #expect(request204.statusColor == .green)
    }

    @Test("Status 3xx is redirect (blue)")
    func testStatus3xxIsBlue() {
        let request301 = makeRequest(status: 301)
        let request302 = makeRequest(status: 302)
        let request304 = makeRequest(status: 304)

        #expect(request301.statusColor == .blue)
        #expect(request302.statusColor == .blue)
        #expect(request304.statusColor == .blue)
    }

    @Test("Status 4xx is client error (orange)")
    func testStatus4xxIsOrange() {
        let request400 = makeRequest(status: 400)
        let request404 = makeRequest(status: 404)
        let request403 = makeRequest(status: 403)

        #expect(request400.statusColor == .orange)
        #expect(request404.statusColor == .orange)
        #expect(request403.statusColor == .orange)
    }

    @Test("Status 5xx is server error (red)")
    func testStatus5xxIsRed() {
        let request500 = makeRequest(status: 500)
        let request502 = makeRequest(status: 502)
        let request503 = makeRequest(status: 503)

        #expect(request500.statusColor == .red)
        #expect(request502.statusColor == .red)
        #expect(request503.statusColor == .red)
    }

    @Test("Nil status is secondary")
    func testNilStatusIsSecondary() {
        let request = makeRequest(status: nil)
        #expect(request.statusColor == .secondary)
    }
}

// MARK: - NetworkRequest Duration Tests

@Suite("NetworkRequest Duration")
struct NetworkRequestDurationTests {

    @Test("Duration under 1 second shows milliseconds")
    func testDurationUnder1Second() {
        let start = Date()
        let end = start.addingTimeInterval(0.5)

        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: start,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: end,
            error: nil,
            requestType: .fetch
        )

        #expect(request.durationText == "500ms")
    }

    @Test("Duration over 1 second shows seconds")
    func testDurationOver1Second() {
        let start = Date()
        let end = start.addingTimeInterval(2.5)

        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: start,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: end,
            error: nil,
            requestType: .fetch
        )

        #expect(request.durationText == "2.50s")
    }

    @Test("Pending request shows ellipsis")
    func testPendingDuration() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: nil,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: nil,
            error: nil,
            requestType: .fetch
        )

        #expect(request.durationText == "...")
    }
}

// MARK: - NetworkRequest Completion Tests

@Suite("NetworkRequest Completion State")
struct NetworkRequestCompletionTests {

    @Test("Request with endTime is complete")
    func testRequestWithEndTimeIsComplete() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.isComplete == true)
        #expect(request.isPending == false)
    }

    @Test("Request with error is complete")
    func testRequestWithErrorIsComplete() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: nil,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: nil,
            error: "Network error",
            requestType: .fetch
        )

        #expect(request.isComplete == true)
        #expect(request.isPending == false)
    }

    @Test("Request without endTime or error is pending")
    func testRequestWithoutEndTimeIsPending() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: nil,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: nil,
            error: nil,
            requestType: .fetch
        )

        #expect(request.isComplete == false)
        #expect(request.isPending == true)
    }
}

// MARK: - NetworkRequest Security Tests

@Suite("NetworkRequest Security")
struct NetworkRequestSecurityTests {

    @Test("HTTPS URL is secure")
    func testHttpsIsSecure() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.isSecure == true)
    }

    @Test("HTTP URL is not secure")
    func testHttpIsNotSecure() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "http://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: false,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.isSecure == false)
    }

    @Test("Mixed content detected: HTTPS page loading HTTP resource")
    func testMixedContentDetection() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "http://cdn.example.com/image.png",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,  // Page is HTTPS
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.isMixedContent == true)
        #expect(request.securityIcon == "exclamationmark.shield.fill")
        #expect(request.securityIconColor == .orange)
    }

    @Test("No mixed content when page is HTTP")
    func testNoMixedContentOnHttpPage() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "http://example.com/resource",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: false,  // Page is HTTP
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.isMixedContent == false)
    }

    @Test("No mixed content when resource is HTTPS")
    func testNoMixedContentForHttpsResource() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://cdn.example.com/script.js",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.isMixedContent == false)
        #expect(request.securityIcon == "lock.fill")
        #expect(request.securityIconColor == .green)
    }
}

// MARK: - NetworkRequest Content Type Tests

@Suite("NetworkRequest Content Type Detection")
struct NetworkRequestContentTypeTests {

    private func makeRequest(contentTypeHeader: String?, bodyPreview: String?) -> NetworkRequest {
        var headers: [String: String]? = nil
        if let contentType = contentTypeHeader {
            headers = ["Content-Type": contentType]
        }

        return NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: headers,
            responseBodyPreview: bodyPreview,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )
    }

    @Test("Detects JSON from Content-Type header")
    func testJsonFromHeader() {
        let request = makeRequest(contentTypeHeader: "application/json", bodyPreview: nil)
        #expect(request.responseContentType == "JSON")
    }

    @Test("Detects HTML from Content-Type header")
    func testHtmlFromHeader() {
        let request = makeRequest(contentTypeHeader: "text/html; charset=utf-8", bodyPreview: nil)
        #expect(request.responseContentType == "HTML")
    }

    @Test("Detects XML from Content-Type header")
    func testXmlFromHeader() {
        let request1 = makeRequest(contentTypeHeader: "text/xml", bodyPreview: nil)
        let request2 = makeRequest(contentTypeHeader: "application/xml", bodyPreview: nil)

        #expect(request1.responseContentType == "XML")
        #expect(request2.responseContentType == "XML")
    }

    @Test("Detects JavaScript from Content-Type header")
    func testJsFromHeader() {
        let request = makeRequest(contentTypeHeader: "application/javascript", bodyPreview: nil)
        #expect(request.responseContentType == "JS")
    }

    @Test("Detects JSON from body content")
    func testJsonFromBody() {
        let request1 = makeRequest(contentTypeHeader: nil, bodyPreview: "{\"key\": \"value\"}")
        let request2 = makeRequest(contentTypeHeader: nil, bodyPreview: "[1, 2, 3]")

        #expect(request1.responseContentType == "JSON")
        #expect(request2.responseContentType == "JSON")
    }

    @Test("Detects HTML from body content")
    func testHtmlFromBody() {
        let request1 = makeRequest(contentTypeHeader: nil, bodyPreview: "<!DOCTYPE html><html>")
        let request2 = makeRequest(contentTypeHeader: nil, bodyPreview: "<html lang=\"en\">")

        #expect(request1.responseContentType == "HTML")
        #expect(request2.responseContentType == "HTML")
    }

    @Test("Detects XML from body content")
    func testXmlFromBody() {
        let request = makeRequest(contentTypeHeader: nil, bodyPreview: "<?xml version=\"1.0\"?>")
        #expect(request.responseContentType == "XML")
    }

    @Test("Returns Text for plain text")
    func testPlainText() {
        let request = makeRequest(contentTypeHeader: nil, bodyPreview: "Hello, World!")
        #expect(request.responseContentType == "Text")
    }

    @Test("Returns dash for empty body")
    func testEmptyBody() {
        let request = makeRequest(contentTypeHeader: nil, bodyPreview: nil)
        #expect(request.responseContentType == "—")
    }
}

// MARK: - NetworkRequest URL Parsing Tests

@Suite("NetworkRequest URL Parsing")
struct NetworkRequestURLParsingTests {

    @Test("Extracts host from URL")
    func testHostExtraction() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://api.example.com/v1/users",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.host == "api.example.com")
    }

    @Test("Extracts path from URL")
    func testPathExtraction() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com/api/v1/users",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.path == "/api/v1/users")
    }

    @Test("Returns root path for URL without path")
    func testRootPath() {
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )

        #expect(request.path == "/")
    }
}

// MARK: - NetworkRequest Equatable Tests

@Suite("NetworkRequest Equatable")
struct NetworkRequestEquatableTests {

    @Test("Same request is equal")
    func testSameRequestEqual() {
        let id = UUID()
        let date = Date()

        let request1 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: date,
            error: nil,
            requestType: .fetch
        )

        let request2 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: date,
            error: nil,
            requestType: .fetch
        )

        #expect(request1 == request2)
    }

    @Test("Different status means not equal")
    func testDifferentStatusNotEqual() {
        let id = UUID()
        let date = Date()

        let request1 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: date,
            error: nil,
            requestType: .fetch
        )

        let request2 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: 404,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: date,
            error: nil,
            requestType: .fetch
        )

        #expect(request1 != request2)
    }

    @Test("Different endTime means not equal")
    func testDifferentEndTimeNotEqual() {
        let id = UUID()
        let date = Date()

        let request1 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: date,
            error: nil,
            requestType: .fetch
        )

        let request2 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: 200,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: date.addingTimeInterval(1),
            error: nil,
            requestType: .fetch
        )

        #expect(request1 != request2)
    }

    @Test("Different error means not equal")
    func testDifferentErrorNotEqual() {
        let id = UUID()
        let date = Date()

        let request1 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: nil,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: nil,
            error: nil,
            requestType: .fetch
        )

        let request2 = NetworkRequest(
            id: id,
            method: "GET",
            url: "https://example.com",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: date,
            pageIsSecure: true,
            status: nil,
            statusText: nil,
            responseHeaders: nil,
            responseBodyPreview: nil,
            endTime: nil,
            error: "Network error",
            requestType: .fetch
        )

        #expect(request1 != request2)
    }
}

// MARK: - NetworkRequest RequestType Tests

@Suite("NetworkRequest RequestType")
struct NetworkRequestTypeTests {

    @Test("Fetch type has correct properties")
    func testFetchType() {
        let type = NetworkRequest.RequestType.fetch
        #expect(type.label == "Fetch")
        #expect(type.icon == "arrow.down.doc")
    }

    @Test("XHR type has correct properties")
    func testXhrType() {
        let type = NetworkRequest.RequestType.xhr
        #expect(type.label == "XHR")
        #expect(type.icon == "arrow.triangle.2.circlepath")
    }

    @Test("Document type has correct properties")
    func testDocumentType() {
        let type = NetworkRequest.RequestType.document
        #expect(type.label == "Doc")
        #expect(type.icon == "doc.text")
    }

    @Test("Other type has correct properties")
    func testOtherType() {
        let type = NetworkRequest.RequestType.other
        #expect(type.label == "Other")
        #expect(type.icon == "questionmark.circle")
    }
}
