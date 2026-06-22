//
//  URLValidatorEdgeCaseTests.swift
//  winaTests
//
//  Extensive edge-case coverage for URLValidator.
//

import Testing
@testable import wina

@Suite("URLValidator Edge Cases")
struct URLValidatorEdgeCaseTests {

    // MARK: - isValidURL

    private static let validURLs: [String] = [
        "example.com",
        "example.com/",
        "example.com/path",
        "example.com/path/to/resource",
        "example.com?query=1",
        "example.com?query=hello&lang=en",
        "example.com#fragment",
        "example.com:8080",
        "example.com:3000/api/v1",
        "sub.example.com",
        "sub.sub.example.com",
        "www.example.com",
        "my-site.com",
        "example.co.uk",
        "example.com.au",
        "example.co.kr",
        "example.io",
        "example.dev",
        "http://example.com",
        "https://example.com",
        "HTTPS://example.com",
        "http://example.com/",
        "https://example.com/path",
        "https://example.com/path/to/resource",
        "https://example.com/path?query=1",
        "https://example.com/path?query=hello&lang=en",
        "https://example.com/path#anchor",
        "https://example.com:443",
        "http://example.com:8080",
        "example.com/path/to/resource?query=1&lang=en",
        "example.com/path/to/resource#section",
        "example.com/path?query=hello%20world",
        "example.com/~user",
        "example.com/123",
        "example.com/abc-def",
        "example.com/abc_def",
        "http://example.com/<>",
        "http://example.com/|",
        "http://example.com/{}",
        "localhost",
        "localhost:3000",
        "http://localhost",
        "http://localhost:8080",
        "https://localhost",
        "127.0.0.1",
        "127.0.0.1:8080",
        "http://127.0.0.1",
        "https://127.0.0.1",
        "192.168.0.1",
        "10.0.0.1",
        "172.16.0.1",
        "255.255.255.255",
        "0.0.0.0",
        "http://0.0.0.0",
        "https://10.0.0.1/path"
    ]

    private static let invalidURLs: [String] = [
        "",
        " ",
        "\n",
        "\t",
        "http://",
        "https://",
        "http:///path",
        "https:///path",
        "://example.com",
        "://",
        "http://?query=1",
        "http://#fragment",
        "example",
        "www",
        "localhostx",
        "http://example",
        "https://example",
        "http://localhostx",
        "example com",
        "example .com",
        "exam<ple.com",
        "exam>ple.com",
        "exam{ple}.com",
        "exa|mple.com",
        "exa\"mple.com",
        "exa^mple.com",
        "http://exa mple.com",
        "http://example .com",
        "http://example.com/pa th",
        "http://example.com/\""
    ]

    @Test("Valid URLs", arguments: validURLs)
    func testValidURLs(_ input: String) {
        #expect(URLValidator.isValidURL(input))
    }

    @Test("Invalid URLs", arguments: invalidURLs)
    func testInvalidURLs(_ input: String) {
        #expect(!URLValidator.isValidURL(input))
    }

    // MARK: - isValidIPv4Address

    private static let validIPv4: [String] = [
        "0.0.0.0",
        "0.0.0.1",
        "1.1.1.1",
        "1.2.3.4",
        "8.8.8.8",
        "9.9.9.9",
        "10.0.0.1",
        "10.0.0.255",
        "10.255.255.255",
        "100.64.0.1",
        "100.127.255.254",
        "127.0.0.1",
        "128.0.0.1",
        "169.254.0.1",
        "172.16.0.0",
        "172.16.0.1",
        "172.31.255.255",
        "192.0.2.1",
        "192.168.0.0",
        "192.168.1.1",
        "192.168.255.255",
        "198.51.100.10",
        "203.0.113.5",
        "224.0.0.1",
        "239.255.255.255",
        "255.255.255.255"
    ]

    private static let invalidIPv4: [String] = [
        "256.0.0.1",
        "192.168.1.256",
        "999.999.999.999",
        "-1.0.0.1",
        "192.-1.1.1",
        "192.168.1",
        "192.168.1.1.1",
        "192.168",
        "192..1.1",
        ".168.1.1",
        "192.168.1.",
        "192.168.01.1",
        "192.168.001.1",
        "01.02.03.04",
        "192.168.a.1",
        "abc.def.ghi.jkl",
        "192.168.1.1a",
        "192. 168.1.1",
        " 192.168.1.1",
        "192.168.1.1 ",
        "",
        "localhost",
        "google.com",
        "not an ip",
        "0.0.0",
        "0.0.0.0.0",
        "00.0.0.0",
        "1.1.1.01",
        "1.1.1.-1"
    ]

    @Test("Valid IPv4", arguments: validIPv4)
    func testValidIPv4(_ input: String) {
        #expect(URLValidator.isValidIPv4Address(input))
    }

    @Test("Invalid IPv4", arguments: invalidIPv4)
    func testInvalidIPv4(_ input: String) {
        #expect(!URLValidator.isValidIPv4Address(input))
    }

    // MARK: - normalizeURL

    private static let normalizeCases: [(String, String)] = [
        ("example.com", "https://example.com"),
        ("example.com/path", "https://example.com/path"),
        ("http://example.com", "http://example.com"),
        ("https://example.com", "https://example.com"),
        ("HTTP://example.com", "HTTP://example.com"),
        ("HTTPS://example.com", "HTTPS://example.com"),
        ("  example.com  ", "https://example.com"),
        ("\nhttps://example.com\n", "https://example.com"),
        // Local/private hosts default to http:// (dev servers speak plain HTTP)
        ("\tlocalhost\t", "http://localhost"),
        ("localhost:3000", "http://localhost:3000"),
        ("127.0.0.1", "http://127.0.0.1"),
        ("192.168.0.1", "http://192.168.0.1"),
        ("192.168.0.1:8080/path", "http://192.168.0.1:8080/path"),
        ("10.0.0.5", "http://10.0.0.5"),
        ("172.16.0.1", "http://172.16.0.1"),
        ("172.31.255.255", "http://172.31.255.255"),
        ("169.254.1.1", "http://169.254.1.1"),
        ("0.0.0.0:8080", "http://0.0.0.0:8080"),
        // Public IPs and domains keep https://
        ("8.8.8.8", "https://8.8.8.8"),
        ("172.32.0.1", "https://172.32.0.1"),
        ("172.15.0.1", "https://172.15.0.1"),
        ("11.0.0.1", "https://11.0.0.1")
    ]

    @Test("Normalize URL", arguments: normalizeCases)
    func testNormalizeURL(_ input: String, _ expected: String) {
        #expect(URLValidator.normalizeURL(input) == expected)
    }

    // MARK: - isPrivateOrLoopbackIPv4

    private static let privateOrLoopbackIPv4: [String] = [
        "0.0.0.0", "10.0.0.0", "10.255.255.255", "127.0.0.1", "127.255.255.255",
        "169.254.0.1", "169.254.255.255", "172.16.0.0", "172.31.255.255",
        "192.168.0.0", "192.168.255.255"
    ]

    private static let publicIPv4: [String] = [
        "1.1.1.1", "8.8.8.8", "9.9.9.9", "11.0.0.1", "126.255.255.255",
        "128.0.0.1", "169.253.255.255", "169.255.0.1", "172.15.255.255",
        "172.32.0.0", "192.167.255.255", "192.169.0.0", "203.0.113.5", "255.255.255.255"
    ]

    @Test("Private/loopback IPv4", arguments: privateOrLoopbackIPv4)
    func testPrivateOrLoopbackIPv4(_ input: String) {
        #expect(URLValidator.isPrivateOrLoopbackIPv4(input))
    }

    @Test("Public IPv4 is not private/loopback", arguments: publicIPv4)
    func testPublicIPv4(_ input: String) {
        #expect(!URLValidator.isPrivateOrLoopbackIPv4(input))
    }

    @Test("Non-IPv4 is not private/loopback")
    func testNonIPv4NotPrivate() {
        #expect(!URLValidator.isPrivateOrLoopbackIPv4("localhost"))
        #expect(!URLValidator.isPrivateOrLoopbackIPv4("example.com"))
        #expect(!URLValidator.isPrivateOrLoopbackIPv4("192.168.01.1"))  // invalid (leading zero)
        #expect(!URLValidator.isPrivateOrLoopbackIPv4(""))
    }

    // MARK: - isLocalHost

    @Test("isLocalHost true cases")
    func testIsLocalHostTrue() {
        #expect(URLValidator.isLocalHost("localhost"))
        #expect(URLValidator.isLocalHost("LOCALHOST"))
        #expect(URLValidator.isLocalHost("localhost:3000"))
        #expect(URLValidator.isLocalHost("localhost/api"))
        #expect(URLValidator.isLocalHost("192.168.0.1"))
        #expect(URLValidator.isLocalHost("192.168.0.1:8080/path?q=1#x"))
        #expect(URLValidator.isLocalHost("127.0.0.1"))
    }

    @Test("isLocalHost false cases")
    func testIsLocalHostFalse() {
        #expect(!URLValidator.isLocalHost("example.com"))
        #expect(!URLValidator.isLocalHost("8.8.8.8"))
        #expect(!URLValidator.isLocalHost("localhostx"))
        #expect(!URLValidator.isLocalHost("notlocalhost.com"))
    }

    // MARK: - extractHost

    private static let extractHostCases: [(String, String?)] = [
        ("https://www.google.com", "www.google.com"),
        ("https://example.com/path", "example.com"),
        ("google.com", "google.com"),
        ("www.example.com/path", "www.example.com"),
        ("localhost:3000", "localhost"),
        ("https://example.com:8080", "example.com"),
        ("192.168.1.1", "192.168.1.1"),
        ("http://10.0.0.1:8080", "10.0.0.1"),
        ("", nil),
        ("   ", nil)
    ]

    @Test("Extract host", arguments: extractHostCases)
    func testExtractHost(_ input: String, _ expected: String?) {
        #expect(URLValidator.extractHost(input) == expected)
    }

    // MARK: - isSupportedSafariURL

    private static let safariSupportCases: [(String, Bool)] = [
        ("https://example.com", true),
        ("http://example.com", true),
        ("example.com", true),
        ("about:blank", false),
        ("file:///path/to/file.html", false),
        ("ftp://example.com", false),
        ("data:text/plain,hello", false),
        ("mailto:test@example.com", false),
        ("sms:+1234567890", false),
        ("myapp://deep-link", false)
    ]

    @Test("Safari URL support", arguments: safariSupportCases)
    func testSupportedSafariURL(_ input: String, _ expected: Bool) {
        #expect(URLValidator.isSupportedSafariURL(input) == expected)
    }
}
