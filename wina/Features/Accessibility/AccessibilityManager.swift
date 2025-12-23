//
//  AccessibilityManager.swift
//  wina
//
//  Accessibility audit manager that persists results across sheet dismissals.
//

import Foundation
import Observation

// MARK: - Accessibility Manager

/// sheet 닫혀도 audit 결과 유지하는 매니저
@Observable
class AccessibilityManager {
    var issues: [AccessibilityIssue] = []
    var isScanning: Bool = false
    var hasScanned: Bool = false
    var filterSeverity: AccessibilityIssue.Severity?
    var searchText: String = ""

    // 결과 초기화
    func clear() {
        issues = []
        hasScanned = false
        filterSeverity = nil
        searchText = ""
    }

    // axe-core violations 파싱
    func parseAxeViolations(_ violations: [[String: Any]]) -> [AccessibilityIssue] {
        var result: [AccessibilityIssue] = []

        for violation in violations {
            guard let ruleId = violation["id"] as? String,
                  let impact = violation["impact"] as? String,
                  let help = violation["help"] as? String,
                  let nodes = violation["nodes"] as? [[String: Any]] else {
                continue
            }

            let tags = violation["tags"] as? [String] ?? []
            let helpUrl = violation["helpUrl"] as? String
            let severity = AccessibilityIssue.Severity.from(impact: impact)
            let category = AccessibilityIssue.Category.from(tags: tags, ruleId: ruleId)

            for node in nodes {
                let fullHtml = node["html"] as? String ?? ""
                let targets = node["target"] as? [String] ?? []
                let selector = targets.first
                let failureSummary = node["failureSummary"] as? String ?? ""

                // 축약된 element (collapsed 상태용)
                let element = fullHtml.count > 60 ? String(fullHtml.prefix(60)) + "..." : fullHtml

                result.append(AccessibilityIssue(
                    severity: severity,
                    category: category,
                    help: help,
                    failureSummary: failureSummary,
                    element: element,
                    fullHtml: fullHtml,
                    selector: selector,
                    helpUrl: helpUrl,
                    ruleId: ruleId
                ))
            }
        }

        return result
    }
}
