//
//  ResourceModelsTests.swift
//  winaTests
//
//  Tests for ResourceModels: Resource timing and initiator type detection
//

import XCTest
@testable import wina

// MARK: - Initiator Type Tests

final class InitiatorTypeTests: XCTestCase {

    // MARK: - Direct Mapping Tests

    func testDirectMappingImg() {
        let type = ResourceEntry.InitiatorType(rawString: "img")
        XCTAssertEqual(type, .img)
    }

    func testDirectMappingScript() {
        let type = ResourceEntry.InitiatorType(rawString: "script")
        XCTAssertEqual(type, .script)
    }

    func testDirectMappingLink() {
        let type = ResourceEntry.InitiatorType(rawString: "link")
        XCTAssertEqual(type, .link)
    }

    func testDirectMappingFetch() {
        let type = ResourceEntry.InitiatorType(rawString: "fetch")
        XCTAssertEqual(type, .fetch)
    }

    func testDirectMappingXHR() {
        let type = ResourceEntry.InitiatorType(rawString: "xmlhttprequest")
        XCTAssertEqual(type, .xmlhttprequest)
    }

    func testDirectMappingBeacon() {
        let type = ResourceEntry.InitiatorType(rawString: "beacon")
        XCTAssertEqual(type, .beacon)
    }

    // MARK: - URL Extension Fallback Tests

    func testFontURLDetection() {
        let woff2 = ResourceEntry.InitiatorType(rawString: "other", url: "https://fonts.com/font.woff2")
        XCTAssertEqual(woff2, .font)

        let woff = ResourceEntry.InitiatorType(rawString: "other", url: "https://fonts.com/font.woff")
        XCTAssertEqual(woff, .font)

        let ttf = ResourceEntry.InitiatorType(rawString: "other", url: "https://fonts.com/font.ttf")
        XCTAssertEqual(ttf, .font)

        let otf = ResourceEntry.InitiatorType(rawString: "other", url: "https://fonts.com/font.otf")
        XCTAssertEqual(otf, .font)
    }

    func testImageURLDetection() {
        // Note: Implementation does NOT detect image URLs from extension
        // Images are typically detected by "img" rawString, not URL extension
        // When rawString is "other", it stays .other regardless of image URL
        let png = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/image.png")
        XCTAssertEqual(png, .other)

        let jpg = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/photo.jpg")
        XCTAssertEqual(jpg, .other)

        let webp = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/image.webp")
        XCTAssertEqual(webp, .other)

        let svg = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/icon.svg")
        XCTAssertEqual(svg, .other)
    }

    func testVideoURLDetection() {
        let mp4 = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/video.mp4")
        XCTAssertEqual(mp4, .video)

        let webm = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/video.webm")
        XCTAssertEqual(webm, .video)
    }

    func testAudioURLDetection() {
        let mp3 = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/audio.mp3")
        XCTAssertEqual(mp3, .audio)

        let wav = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/sound.wav")
        XCTAssertEqual(wav, .audio)

        let ogg = ResourceEntry.InitiatorType(rawString: "other", url: "https://cdn.com/music.ogg")
        XCTAssertEqual(ogg, .audio)
    }

    // MARK: - Override Generic Type with URL Tests

    func testOverrideCSSWithFont() {
        // CSS-loaded font should be detected as font
        let type = ResourceEntry.InitiatorType(rawString: "css", url: "https://fonts.com/font.woff2")
        XCTAssertEqual(type, .font)
    }

    func testOverrideFetchWithVideo() {
        let type = ResourceEntry.InitiatorType(rawString: "fetch", url: "https://cdn.com/video.mp4")
        XCTAssertEqual(type, .video)
    }

    func testOverrideLinkWithFont() {
        let type = ResourceEntry.InitiatorType(rawString: "link", url: "https://fonts.com/font.ttf")
        XCTAssertEqual(type, .font)
    }

    // MARK: - Unknown Type Tests

    func testUnknownType() {
        let type = ResourceEntry.InitiatorType(rawString: "unknown")
        XCTAssertEqual(type, .other)
    }

    func testUnknownWithUnknownExtension() {
        let type = ResourceEntry.InitiatorType(rawString: "unknown", url: "https://cdn.com/file.xyz")
        XCTAssertEqual(type, .other)
    }

    // MARK: - Display Properties Tests

    func testDisplayNames() {
        XCTAssertEqual(ResourceEntry.InitiatorType.img.displayName, "Image")
        XCTAssertEqual(ResourceEntry.InitiatorType.script.displayName, "Script")
        XCTAssertEqual(ResourceEntry.InitiatorType.link.displayName, "Stylesheet")
        XCTAssertEqual(ResourceEntry.InitiatorType.fetch.displayName, "Fetch")
        XCTAssertEqual(ResourceEntry.InitiatorType.xmlhttprequest.displayName, "XHR")
    }

    func testIcons() {
        XCTAssertEqual(ResourceEntry.InitiatorType.img.icon, "photo")
        XCTAssertEqual(ResourceEntry.InitiatorType.script.icon, "scroll")
        XCTAssertEqual(ResourceEntry.InitiatorType.font.icon, "textformat")
    }
}

// MARK: - Resource Filter Tests

final class ResourceFilterTests: XCTestCase {

    func testAllMatchesEverything() {
        XCTAssertTrue(ResourceFilter.all.matches(.img))
        XCTAssertTrue(ResourceFilter.all.matches(.script))
        XCTAssertTrue(ResourceFilter.all.matches(.link))
        XCTAssertTrue(ResourceFilter.all.matches(.fetch))
        XCTAssertTrue(ResourceFilter.all.matches(.other))
    }

    func testImgFilter() {
        XCTAssertTrue(ResourceFilter.img.matches(.img))
        XCTAssertFalse(ResourceFilter.img.matches(.script))
    }

    func testScriptFilter() {
        XCTAssertTrue(ResourceFilter.script.matches(.script))
        XCTAssertFalse(ResourceFilter.script.matches(.img))
    }

    func testCSSFilter() {
        XCTAssertTrue(ResourceFilter.css.matches(.link))
        XCTAssertTrue(ResourceFilter.css.matches(.css))
        XCTAssertFalse(ResourceFilter.css.matches(.script))
    }

    func testXHRFilter() {
        XCTAssertTrue(ResourceFilter.xhr.matches(.fetch))
        XCTAssertTrue(ResourceFilter.xhr.matches(.xmlhttprequest))
        XCTAssertFalse(ResourceFilter.xhr.matches(.script))
    }

    func testMediaFilter() {
        XCTAssertTrue(ResourceFilter.media.matches(.video))
        XCTAssertTrue(ResourceFilter.media.matches(.audio))
        XCTAssertFalse(ResourceFilter.media.matches(.img))
    }

    func testOtherFilter() {
        XCTAssertTrue(ResourceFilter.other.matches(.other))
        XCTAssertTrue(ResourceFilter.other.matches(.beacon))
        XCTAssertFalse(ResourceFilter.other.matches(.script))
    }

    func testDisplayNames() {
        XCTAssertEqual(ResourceFilter.all.displayName, "All")
        XCTAssertEqual(ResourceFilter.img.displayName, "Img")
        XCTAssertEqual(ResourceFilter.script.displayName, "JS")
        XCTAssertEqual(ResourceFilter.css.displayName, "CSS")
    }
}

// MARK: - Resource Entry Tests

final class ResourceEntryTests: XCTestCase {

    func testDisplayName() {
        let entry = ResourceEntry(
            id: UUID(),
            name: "https://example.com/assets/script.js",
            initiatorType: .script,
            startTime: 0,
            duration: 100,
            transferSize: 1000,
            encodedBodySize: 900,
            decodedBodySize: 800,
            dnsTime: 10,
            tcpTime: 20,
            tlsTime: 15,
            requestTime: 50,
            responseTime: 30,
            timestamp: Date()
        )

        XCTAssertEqual(entry.displayName, "script.js")
    }

    func testDisplaySize() {
        let entry = ResourceEntry(
            id: UUID(),
            name: "test.js",
            initiatorType: .script,
            startTime: 0,
            duration: 100,
            transferSize: 1536,  // ByteCountFormatter rounds to 2 KB
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )

        // ByteCountFormatter.string(fromByteCount:countStyle:.file) rounds values
        XCTAssertEqual(entry.displaySize, "2 KB")
    }

    func testDisplaySizeZero() {
        let entry = ResourceEntry(
            id: UUID(),
            name: "test.js",
            initiatorType: .script,
            startTime: 0,
            duration: 100,
            transferSize: 0,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )

        XCTAssertEqual(entry.displaySize, "—")
    }

    func testDisplayDuration() {
        // Sub-millisecond
        let entry1 = ResourceEntry(
            id: UUID(),
            name: "test.js",
            initiatorType: .script,
            startTime: 0,
            duration: 0.5,
            transferSize: 0,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )
        XCTAssertEqual(entry1.displayDuration, "<1ms")

        // Milliseconds
        let entry2 = ResourceEntry(
            id: UUID(),
            name: "test.js",
            initiatorType: .script,
            startTime: 0,
            duration: 500,
            transferSize: 0,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )
        XCTAssertEqual(entry2.displayDuration, "500ms")

        // Seconds
        let entry3 = ResourceEntry(
            id: UUID(),
            name: "test.js",
            initiatorType: .script,
            startTime: 0,
            duration: 2500,
            transferSize: 0,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )
        XCTAssertEqual(entry3.displayDuration, "2.50s")
    }

    func testCrossOriginRestricted() {
        // All timings 0 but duration > 0 = cross-origin restricted
        let restricted = ResourceEntry(
            id: UUID(),
            name: "https://other-origin.com/script.js",
            initiatorType: .script,
            startTime: 0,
            duration: 100,
            transferSize: 0,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )
        XCTAssertTrue(restricted.isCrossOriginRestricted)

        // Has timing data = not restricted
        let notRestricted = ResourceEntry(
            id: UUID(),
            name: "https://same-origin.com/script.js",
            initiatorType: .script,
            startTime: 0,
            duration: 100,
            transferSize: 1000,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 10,
            tcpTime: 20,
            tlsTime: 0,
            requestTime: 50,
            responseTime: 20,
            timestamp: Date()
        )
        XCTAssertFalse(notRestricted.isCrossOriginRestricted)
    }

    func testHost() {
        let entry = ResourceEntry(
            id: UUID(),
            name: "https://cdn.example.com/assets/script.js",
            initiatorType: .script,
            startTime: 0,
            duration: 0,
            transferSize: 0,
            encodedBodySize: 0,
            decodedBodySize: 0,
            dnsTime: 0,
            tcpTime: 0,
            tlsTime: 0,
            requestTime: 0,
            responseTime: 0,
            timestamp: Date()
        )

        XCTAssertEqual(entry.host, "cdn.example.com")
    }
}

// MARK: - Resource Stats Tests

final class ResourceStatsTests: XCTestCase {

    func testDisplayTotalSize() {
        let stats = ResourceStats(
            totalCount: 10,
            totalSize: 1_048_576,  // 1 MB
            totalDuration: 1000,
            byType: [:]
        )

        XCTAssertEqual(stats.displayTotalSize, "1 MB")
    }

    func testDisplayTotalSizeZero() {
        let stats = ResourceStats(
            totalCount: 0,
            totalSize: 0,
            totalDuration: 0,
            byType: [:]
        )

        XCTAssertEqual(stats.displayTotalSize, "—")
    }
}
