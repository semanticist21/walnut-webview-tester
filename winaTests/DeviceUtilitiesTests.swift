//
//  DeviceUtilitiesTests.swift
//  winaTests
//
//  Tests for DeviceUtilities: SettingsFormatter and ByteFormatter
//

import XCTest
@testable import wina

// MARK: - Settings Formatter Tests

final class SettingsFormatterTests: XCTestCase {

    // MARK: - Content Mode Tests

    func testContentModeTextMobile() {
        XCTAssertEqual(SettingsFormatter.contentModeText(1), "Mobile")
    }

    func testContentModeTextDesktop() {
        XCTAssertEqual(SettingsFormatter.contentModeText(2), "Desktop")
    }

    func testContentModeTextRecommended() {
        XCTAssertEqual(SettingsFormatter.contentModeText(0), "Recommended")
        XCTAssertEqual(SettingsFormatter.contentModeText(99), "Recommended")  // Unknown value
    }

    // MARK: - Data Detectors Tests

    func testActiveDataDetectorsNone() {
        let result = SettingsFormatter.activeDataDetectors(
            phone: false,
            links: false,
            address: false,
            calendar: false
        )
        XCTAssertEqual(result, "None")
    }

    func testActiveDataDetectorsSingle() {
        XCTAssertEqual(
            SettingsFormatter.activeDataDetectors(phone: true, links: false, address: false, calendar: false),
            "Phone"
        )
        XCTAssertEqual(
            SettingsFormatter.activeDataDetectors(phone: false, links: true, address: false, calendar: false),
            "Links"
        )
    }

    func testActiveDataDetectorsMultiple() {
        let result = SettingsFormatter.activeDataDetectors(
            phone: true,
            links: true,
            address: false,
            calendar: false
        )
        XCTAssertEqual(result, "Phone, Links")
    }

    func testActiveDataDetectorsAll() {
        let result = SettingsFormatter.activeDataDetectors(
            phone: true,
            links: true,
            address: true,
            calendar: true
        )
        XCTAssertEqual(result, "Phone, Links, Address, Calendar")
    }

    // MARK: - Enabled Status Tests

    func testEnabledStatusTrue() {
        XCTAssertEqual(SettingsFormatter.enabledStatus(true), "Enabled")
    }

    func testEnabledStatusFalse() {
        XCTAssertEqual(SettingsFormatter.enabledStatus(false), "Disabled")
    }

    // MARK: - Dismiss Button Style Tests

    func testDismissButtonStyleClose() {
        XCTAssertEqual(SettingsFormatter.dismissButtonStyleText(1), "Close")
    }

    func testDismissButtonStyleCancel() {
        XCTAssertEqual(SettingsFormatter.dismissButtonStyleText(2), "Cancel")
    }

    func testDismissButtonStyleDone() {
        XCTAssertEqual(SettingsFormatter.dismissButtonStyleText(0), "Done")
        XCTAssertEqual(SettingsFormatter.dismissButtonStyleText(99), "Done")  // Unknown value
    }
}

// MARK: - Byte Formatter Tests

final class ByteFormatterTests: XCTestCase {

    func testFormatBytes() {
        XCTAssertEqual(ByteFormatter.format(0), "0 B")
        XCTAssertEqual(ByteFormatter.format(500), "500 B")
        XCTAssertEqual(ByteFormatter.format(999), "999 B")
    }

    func testFormatKilobytes() {
        XCTAssertEqual(ByteFormatter.format(1000), "1.0 KB")
        XCTAssertEqual(ByteFormatter.format(1500), "1.5 KB")
        XCTAssertEqual(ByteFormatter.format(10_000), "10.0 KB")
        XCTAssertEqual(ByteFormatter.format(999_999), "1000.0 KB")
    }

    func testFormatMegabytes() {
        XCTAssertEqual(ByteFormatter.format(1_000_000), "1.0 MB")
        XCTAssertEqual(ByteFormatter.format(1_500_000), "1.5 MB")
        XCTAssertEqual(ByteFormatter.format(10_000_000), "10.0 MB")
    }

    func testFormatLargeMegabytes() {
        XCTAssertEqual(ByteFormatter.format(100_000_000), "100.0 MB")
        XCTAssertEqual(ByteFormatter.format(1_000_000_000), "1000.0 MB")
    }

    func testFormatDecimalPrecision() {
        // Check decimal precision (%.1f uses banker's rounding - 1.25 → 1.2)
        XCTAssertEqual(ByteFormatter.format(1_234), "1.2 KB")  // 1.234 → 1.2
        XCTAssertEqual(ByteFormatter.format(1_250_000), "1.2 MB")  // 1.25 → 1.2 (banker's rounding)
    }
}
