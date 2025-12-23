//
//  AccessibilityManagerTests.swift
//  winaTests
//
//  Tests for AccessibilityManager axe-core parsing and severity/category mapping.
//

import XCTest
@testable import wina

// MARK: - AccessibilityIssue.Severity Tests

final class AccessibilityIssueSeverityTests: XCTestCase {

    func testSeverityFromCriticalReturnsError() {
        let severity = AccessibilityIssue.Severity.from(impact: "critical")
        XCTAssertEqual(severity, .error)
    }

    func testSeverityFromSeriousReturnsError() {
        let severity = AccessibilityIssue.Severity.from(impact: "serious")
        XCTAssertEqual(severity, .error)
    }

    func testSeverityFromModerateReturnsWarning() {
        let severity = AccessibilityIssue.Severity.from(impact: "moderate")
        XCTAssertEqual(severity, .warning)
    }

    func testSeverityFromMinorReturnsInfo() {
        let severity = AccessibilityIssue.Severity.from(impact: "minor")
        XCTAssertEqual(severity, .info)
    }

    func testSeverityFromUnknownReturnsInfo() {
        let severity = AccessibilityIssue.Severity.from(impact: "unknown_impact")
        XCTAssertEqual(severity, .info)
    }

    func testSeverityCaseInsensitive() {
        let severity = AccessibilityIssue.Severity.from(impact: "CRITICAL")
        XCTAssertEqual(severity, .error)
    }

    func testSeverityAllCases() {
        XCTAssertEqual(AccessibilityIssue.Severity.allCases.count, 3)
    }

    func testSeverityLabels() {
        XCTAssertEqual(AccessibilityIssue.Severity.error.label, "Errors")
        XCTAssertEqual(AccessibilityIssue.Severity.warning.label, "Warnings")
        XCTAssertEqual(AccessibilityIssue.Severity.info.label, "Info")
    }

    func testSeverityIcons() {
        XCTAssertFalse(AccessibilityIssue.Severity.error.icon.isEmpty)
        XCTAssertFalse(AccessibilityIssue.Severity.warning.icon.isEmpty)
        XCTAssertFalse(AccessibilityIssue.Severity.info.icon.isEmpty)
    }
}

// MARK: - AccessibilityIssue.Category Tests

final class AccessibilityIssueCategoryTests: XCTestCase {

    func testCategoryFromImageRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "image-alt")
        XCTAssertEqual(category, .images)
    }

    func testCategoryFromAltRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "alt-text")
        XCTAssertEqual(category, .images)
    }

    func testCategoryFromLinkRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "link-name")
        XCTAssertEqual(category, .links)
    }

    func testCategoryFromButtonRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "button-name")
        XCTAssertEqual(category, .buttons)
    }

    func testCategoryFromFormRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "form-field-multiple-labels")
        XCTAssertEqual(category, .forms)
    }

    func testCategoryFromLabelRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "label")
        XCTAssertEqual(category, .forms)
    }

    func testCategoryFromHeadingRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "heading-order")
        XCTAssertEqual(category, .headings)
    }

    func testCategoryFromContrastRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "color-contrast")
        XCTAssertEqual(category, .contrast)
    }

    func testCategoryFromKeyboardRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "keyboard")
        XCTAssertEqual(category, .keyboard)
    }

    func testCategoryFromFocusRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "focus-visible")
        XCTAssertEqual(category, .keyboard)
    }

    func testCategoryFromLanguageRuleId() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "html-lang")
        XCTAssertEqual(category, .language)
    }

    func testCategoryFromTagsAria() {
        let category = AccessibilityIssue.Category.from(tags: ["aria", "wcag2a"], ruleId: "unknown")
        XCTAssertEqual(category, .aria)
    }

    func testCategoryFromTagsStructure() {
        let category = AccessibilityIssue.Category.from(tags: ["structure", "wcag2a"], ruleId: "unknown")
        XCTAssertEqual(category, .structure)
    }

    func testCategoryUnknownReturnsOther() {
        let category = AccessibilityIssue.Category.from(tags: [], ruleId: "unknown-rule")
        XCTAssertEqual(category, .other)
    }

    func testCategoryAllCases() {
        XCTAssertEqual(AccessibilityIssue.Category.allCases.count, 11)
    }

    func testCategoryLabels() {
        XCTAssertEqual(AccessibilityIssue.Category.images.label, "Images")
        XCTAssertEqual(AccessibilityIssue.Category.aria.label, "ARIA")
        XCTAssertEqual(AccessibilityIssue.Category.other.label, "Other")
    }

    func testCategoryIcons() {
        for category in AccessibilityIssue.Category.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) should have an icon")
        }
    }
}

// MARK: - AccessibilityManager Tests

final class AccessibilityManagerTests: XCTestCase {

    var manager: AccessibilityManager!

    override func setUp() {
        super.setUp()
        manager = AccessibilityManager()
    }

    override func tearDown() {
        manager?.clear()
        manager = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialIssuesIsEmpty() {
        XCTAssertTrue(manager.issues.isEmpty)
    }

    func testInitialIsScanningIsFalse() {
        XCTAssertFalse(manager.isScanning)
    }

    func testInitialHasScannedIsFalse() {
        XCTAssertFalse(manager.hasScanned)
    }

    func testInitialFilterSeverityIsNil() {
        XCTAssertNil(manager.filterSeverity)
    }

    func testInitialSearchTextIsEmpty() {
        XCTAssertTrue(manager.searchText.isEmpty)
    }

    // MARK: - Clear Tests

    func testClearResetsAllState() {
        manager.hasScanned = true
        manager.filterSeverity = .error
        manager.searchText = "test"

        manager.clear()

        XCTAssertTrue(manager.issues.isEmpty)
        XCTAssertFalse(manager.hasScanned)
        XCTAssertNil(manager.filterSeverity)
        XCTAssertTrue(manager.searchText.isEmpty)
    }

    // MARK: - Parse Tests

    func testParseAxeViolationsWithValidData() {
        let violations: [[String: Any]] = [
            [
                "id": "image-alt",
                "impact": "critical",
                "help": "Images must have alternate text",
                "helpUrl": "https://dequeuniversity.com/rules/axe/4.0/image-alt",
                "tags": ["wcag2a", "wcag111"],
                "nodes": [
                    [
                        "html": "<img src=\"test.png\">",
                        "target": ["img"],
                        "failureSummary": "Fix any of the following: Element has no alt attribute"
                    ]
                ]
            ]
        ]

        let issues = manager.parseAxeViolations(violations)

        XCTAssertEqual(issues.count, 1)

        let issue = issues.first!
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.category, .images)
        XCTAssertEqual(issue.help, "Images must have alternate text")
        XCTAssertEqual(issue.selector, "img")
        XCTAssertEqual(issue.ruleId, "image-alt")
        XCTAssertNotNil(issue.helpUrl)
    }

    func testParseAxeViolationsWithMultipleNodes() {
        let violations: [[String: Any]] = [
            [
                "id": "link-name",
                "impact": "serious",
                "help": "Links must have discernible text",
                "tags": ["wcag2a"],
                "nodes": [
                    [
                        "html": "<a href=\"/\"></a>",
                        "target": ["a:nth-child(1)"],
                        "failureSummary": "Fix the issue"
                    ],
                    [
                        "html": "<a href=\"/about\"></a>",
                        "target": ["a:nth-child(2)"],
                        "failureSummary": "Fix the issue"
                    ]
                ]
            ]
        ]

        let issues = manager.parseAxeViolations(violations)

        // Each node creates a separate issue
        XCTAssertEqual(issues.count, 2)
    }

    func testParseAxeViolationsWithEmptyNodes() {
        let violations: [[String: Any]] = [
            [
                "id": "color-contrast",
                "impact": "moderate",
                "help": "Elements must have sufficient color contrast",
                "tags": ["wcag2aa"],
                "nodes": []
            ]
        ]

        let issues = manager.parseAxeViolations(violations)

        XCTAssertTrue(issues.isEmpty)
    }

    func testParseAxeViolationsWithMissingFields() {
        let violations: [[String: Any]] = [
            [
                "id": "test-rule"
                // Missing required fields
            ]
        ]

        let issues = manager.parseAxeViolations(violations)

        XCTAssertTrue(issues.isEmpty)
    }

    func testParseAxeViolationsTruncatesLongHtml() {
        let longHtml = String(repeating: "a", count: 100)
        let violations: [[String: Any]] = [
            [
                "id": "test-rule",
                "impact": "minor",
                "help": "Test help",
                "tags": [],
                "nodes": [
                    [
                        "html": longHtml,
                        "target": [".test"],
                        "failureSummary": "Test"
                    ]
                ]
            ]
        ]

        let issues = manager.parseAxeViolations(violations)

        XCTAssertEqual(issues.count, 1)
        // Element should be truncated (60 chars + "...")
        XCTAssertTrue(issues.first!.element.count < longHtml.count)
        XCTAssertTrue(issues.first!.element.hasSuffix("..."))
        // fullHtml should preserve original
        XCTAssertEqual(issues.first!.fullHtml, longHtml)
    }

    func testParseAxeViolationsWithEmptyArray() {
        let violations: [[String: Any]] = []

        let issues = manager.parseAxeViolations(violations)

        XCTAssertTrue(issues.isEmpty)
    }
}
