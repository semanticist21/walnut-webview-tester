//
//  AccessibilityAuditView.swift
//  wina
//
//  Accessibility audit tool using axe-core for WCAG compliance checking.
//

import SwiftUI

// MARK: - Accessibility Issue Model

struct AccessibilityIssue: Identifiable, Equatable {
    let id = UUID()
    let severity: Severity
    let category: Category
    let help: String  // Short help message
    let failureSummary: String  // Detailed failure info
    let element: String  // Truncated element for display
    let fullHtml: String  // Full HTML for copy
    let selector: String?  // CSS selector for the element
    let helpUrl: String?  // Link to axe-core documentation
    let ruleId: String?  // axe-core rule ID

    enum Severity: String, CaseIterable {
        case error  // critical, serious
        case warning  // moderate
        case info  // minor

        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }

        var label: String {
            switch self {
            case .error: return "Errors"
            case .warning: return "Warnings"
            case .info: return "Info"
            }
        }

        static func from(impact: String) -> Severity {
            switch impact.lowercased() {
            case "critical", "serious": return .error
            case "moderate": return .warning
            default: return .info
            }
        }
    }

    enum Category: String, CaseIterable {
        case images
        case links
        case buttons
        case forms
        case headings
        case aria
        case contrast
        case keyboard
        case language
        case structure
        case other

        var icon: String {
            switch self {
            case .images: return "photo"
            case .links: return "link"
            case .buttons: return "hand.tap"
            case .forms: return "list.bullet.rectangle"
            case .headings: return "textformat.size"
            case .aria: return "accessibility"
            case .contrast: return "circle.lefthalf.filled"
            case .keyboard: return "keyboard"
            case .language: return "globe"
            case .structure: return "rectangle.3.group"
            case .other: return "questionmark.circle"
            }
        }

        var label: String {
            switch self {
            case .images: return "Images"
            case .links: return "Links"
            case .buttons: return "Buttons"
            case .forms: return "Forms"
            case .headings: return "Headings"
            case .aria: return "ARIA"
            case .contrast: return "Contrast"
            case .keyboard: return "Keyboard"
            case .language: return "Language"
            case .structure: return "Structure"
            case .other: return "Other"
            }
        }

        // swiftlint:disable:next cyclomatic_complexity
        static func from(tags: [String], ruleId: String) -> Category {
            // Check rule ID first for specific mappings
            if ruleId.contains("image") || ruleId.contains("alt") {
                return .images
            }
            if ruleId.contains("link") {
                return .links
            }
            if ruleId.contains("button") {
                return .buttons
            }
            if ruleId.contains("label") || ruleId.contains("input") || ruleId.contains("form") {
                return .forms
            }
            if ruleId.contains("heading") {
                return .headings
            }
            if ruleId.contains("color") || ruleId.contains("contrast") {
                return .contrast
            }
            if ruleId.contains("focus") || ruleId.contains("keyboard") || ruleId.contains("tabindex") {
                return .keyboard
            }
            if ruleId.contains("lang") || ruleId.contains("language") {
                return .language
            }

            // Check tags for category
            for tag in tags {
                let lowered = tag.lowercased()
                if lowered.contains("image") { return .images }
                if lowered.contains("link") { return .links }
                if lowered.contains("button") { return .buttons }
                if lowered.contains("form") || lowered.contains("label") { return .forms }
                if lowered.contains("heading") || lowered.contains("structure") { return .structure }
                if lowered.contains("aria") { return .aria }
                if lowered.contains("color") { return .contrast }
                if lowered.contains("keyboard") { return .keyboard }
                if lowered.contains("language") { return .language }
            }

            return .other
        }
    }
}

// MARK: - Accessibility Audit View

struct AccessibilityAuditView: View {
    let navigator: WebViewNavigator?

    @Environment(\.dismiss) private var dismiss
    @State private var issues: [AccessibilityIssue] = []
    @State private var isScanning: Bool = false
    @State private var hasScanned: Bool = false
    @State private var filterSeverity: AccessibilityIssue.Severity?
    @State private var searchText: String = ""

    private var filteredIssues: [AccessibilityIssue] {
        var result = issues

        if let severity = filterSeverity {
            result = result.filter { $0.severity == severity }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.help.localizedCaseInsensitiveContains(searchText)
                    || $0.element.localizedCaseInsensitiveContains(searchText)
                    || $0.category.label.localizedCaseInsensitiveContains(searchText)
                    || ($0.ruleId?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var issueCountBySeverity: [AccessibilityIssue.Severity: Int] {
        Dictionary(grouping: issues, by: \.severity).mapValues(\.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            filterTabs

            Divider()

            if isScanning {
                scanningState
            } else if !hasScanned {
                initialState
            } else if filteredIssues.isEmpty {
                emptyState
            } else {
                issuesList
            }
        }
        .task {
            await AdManager.shared.showInterstitialAd(
                options: AdOptions(id: "accessibility_devtools"),
                adUnitId: AdManager.interstitialAdUnitId
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        DevToolsHeader(
            title: "Accessibility",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(
                    icon: "trash",
                    isDisabled: issues.isEmpty || isScanning
                ) {
                    issues = []
                    hasScanned = false
                },
                .init(
                    icon: "square.and.arrow.up",
                    isDisabled: issues.isEmpty || isScanning
                ) {
                    shareAllIssues()
                }
            ],
            rightButtons: [
                .init(
                    icon: "arrow.clockwise",
                    isDisabled: isScanning
                ) {
                    Task { await runAudit() }
                }
            ]
        )
    }

    private func shareAllIssues() {
        let summary = generateShareText()
        let activityVC = UIActivityViewController(
            activityItems: [summary],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: 100, width: 0, height: 0)
            }
            rootVC.present(activityVC, animated: true)
        }
    }

    private func generateShareText() -> String {
        var lines: [String] = []

        // Header
        lines.append("# Accessibility Audit Report")
        lines.append("")
        if let url = navigator?.currentURL?.absoluteString {
            lines.append("URL: \(url)")
        }
        lines.append("Date: \(Date().formatted(date: .abbreviated, time: .shortened))")
        lines.append("")

        // Summary
        let errorCount = issueCountBySeverity[.error] ?? 0
        let warningCount = issueCountBySeverity[.warning] ?? 0
        let infoCount = issueCountBySeverity[.info] ?? 0
        lines.append("## Summary")
        lines.append("- Errors: \(errorCount)")
        lines.append("- Warnings: \(warningCount)")
        lines.append("- Info: \(infoCount)")
        lines.append("- Total: \(issues.count)")
        lines.append("")

        // Issues by severity
        for severity in AccessibilityIssue.Severity.allCases {
            let severityIssues = issues.filter { $0.severity == severity }
            if severityIssues.isEmpty { continue }

            lines.append("## \(severity.label) (\(severityIssues.count))")
            lines.append("")

            for (index, issue) in severityIssues.enumerated() {
                lines.append("### \(index + 1). \(issue.help)")
                if let ruleId = issue.ruleId {
                    lines.append("- Rule: \(ruleId)")
                }
                lines.append("- Category: \(issue.category.label)")
                if !issue.failureSummary.isEmpty {
                    lines.append("- Details: \(issue.failureSummary)")
                }
                if let selector = issue.selector {
                    lines.append("- Selector: \(selector)")
                }
                lines.append("- HTML: \(issue.fullHtml)")
                if let helpUrl = issue.helpUrl {
                    lines.append("- Help: \(helpUrl)")
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter issues", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                FilterTab(
                    label: "All",
                    count: issues.count,
                    isSelected: filterSeverity == nil
                ) {
                    filterSeverity = nil
                }

                ForEach(AccessibilityIssue.Severity.allCases, id: \.self) { severity in
                    FilterTab(
                        label: severity.label,
                        count: issueCountBySeverity[severity] ?? 0,
                        isSelected: filterSeverity == severity,
                        color: severity.color
                    ) {
                        filterSeverity = severity
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - States

    private var initialState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    Image(systemName: "accessibility")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Accessibility Audit")
                        .font(.headline)
                    Text("Scan the current page for accessibility issues")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    GlassActionButton("Run Audit", icon: "play.fill", style: .primary) {
                        Task { await runAudit() }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var scanningState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var emptyState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text(issues.isEmpty ? "No issues found" : "No matching issues")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if issues.isEmpty {
                        Text("Great! This page passes basic accessibility checks.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Issues List

    private var issuesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredIssues) { issue in
                    IssueRow(issue: issue)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Audit Logic

    private func runAudit() async {
        guard let navigator else { return }

        isScanning = true
        issues = []

        // Step 1: Inject axe-core if not already loaded
        let checkAxe = "typeof axe !== 'undefined'"
        let axeLoaded = await navigator.evaluateJavaScript(checkAxe) as? Bool ?? false

        if !axeLoaded {
            guard let axeURL = Bundle.main.url(forResource: "axe.min", withExtension: "js"),
                  let axeScript = try? String(contentsOf: axeURL, encoding: .utf8) else {
                // axe.min.js not found - user needs to add Scripts folder to Xcode project
                isScanning = false
                hasScanned = true
                return
            }
            _ = await navigator.evaluateJavaScript(axeScript)
        }

        // Step 2: Run axe-core audit using callAsyncJavaScript (supports Promises)
        let auditScript = """
            const results = await axe.run();
            return JSON.stringify(results.violations);
        """

        if let result = await navigator.callAsyncJavaScript(auditScript) as? String,
           let data = result.data(using: .utf8),
           let violations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            issues = parseAxeViolations(violations)
        }

        isScanning = false
        hasScanned = true
    }

    private func parseAxeViolations(_ violations: [[String: Any]]) -> [AccessibilityIssue] {
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

                // Create truncated element for collapsed display
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

// MARK: - Filter Tab

private struct FilterTab: View {
    let label: String
    let count: Int
    let isSelected: Bool
    var color: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if count != 0 {  // swiftlint:disable:this empty_count
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(isSelected ? color : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(color)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Issue Row

private struct IssueRow: View {
    let issue: AccessibilityIssue
    @Environment(\.openURL) private var openURL
    @State private var isExpanded: Bool = false

    private var copyText: String {
        var parts: [String] = []
        if let ruleId = issue.ruleId {
            parts.append("Rule: \(ruleId)")
        }
        parts.append("Severity: \(issue.severity.rawValue)")
        parts.append("Category: \(issue.category.label)")
        parts.append("Issue: \(issue.help)")
        if !issue.failureSummary.isEmpty {
            parts.append("Details: \(issue.failureSummary)")
        }
        if let selector = issue.selector {
            parts.append("Selector: \(selector)")
        }
        parts.append("HTML: \(issue.fullHtml)")
        if let helpUrl = issue.helpUrl {
            parts.append("Help: \(helpUrl)")
        }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                // Severity icon
                Image(systemName: issue.severity.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(issue.severity.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    // Category badge + rule ID
                    HStack(spacing: 6) {
                        Label(issue.category.label, systemImage: issue.category.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(issue.severity.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(issue.severity.color.opacity(0.15), in: Capsule())

                        if let ruleId = issue.ruleId {
                            Text(ruleId)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        // Chevron indicator
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }

                    // Help message (title)
                    Text(issue.help)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                        .multilineTextAlignment(.leading)

                    // Element (truncated when collapsed)
                    Text(isExpanded ? issue.fullHtml : issue.element)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? 6 : 1)
                        .multilineTextAlignment(.leading)

                    // Expanded details
                    if isExpanded {
                        expandedDetails
                    }
                }

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(issue.severity == .error ? Color.red.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 42)
        }
    }

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Failure summary
            if !issue.failureSummary.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Details")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(issue.failureSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }

            // Selector
            if let selector = issue.selector {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selector")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(selector)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 4) {
            // Copy button
            CopyIconButton(copyText)

            // Help link button
            if let helpUrl = issue.helpUrl, let url = URL(string: helpUrl) {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    AccessibilityAuditView(navigator: WebViewNavigator())
}
