//
//  PerformanceView.swift
//  wina
//
//  Performance panel with Web Vitals 2025.
//

import SwiftUI

// MARK: - Performance Tab

enum PerformanceTab: String, CaseIterable {
    case metrics = "Metrics"
    case resources = "Resources"
    case timing = "Timing"

    var icon: String {
        switch self {
        case .metrics: return "gauge.with.dots.needle.bottom.50percent"
        case .resources: return "doc.fill"
        case .timing: return "clock"
        }
    }
}

// MARK: - Performance View

struct PerformanceView: View {
    let performanceManager: PerformanceManager
    let onCollect: () -> Void
    let onReload: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: PerformanceTab = .metrics
    @State private var searchText: String = ""
    @State private var expandedTypes: Set<ResourceType> = []

    private var hasData: Bool {
        performanceManager.data.navigation != nil || !performanceManager.data.paints.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            performanceHeader
            searchBar
            filterTabs

            Divider()

            if performanceManager.isLoading {
                loadingState
            } else if let error = performanceManager.lastError, !hasData {
                errorState(error)
            } else if !hasData {
                emptyState
            } else {
                contentView
            }
        }
        .onAppear {
            if !hasData {
                onCollect()
            }
        }
        .task {
            await AdManager.shared.showInterstitialAd(
                options: AdOptions(id: "performance_devtools"),
                adUnitId: AdManager.interstitialAdUnitId
            )
        }
    }

    // MARK: - Header

    private var performanceHeader: some View {
        DevToolsHeader(
            title: "Performance",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(icon: "trash", isDisabled: !hasData) {
                    performanceManager.clear()
                }
            ],
            rightButtons: [
                .init(
                    icon: performanceManager.isLoading ? "hourglass" : "arrow.clockwise",
                    isDisabled: performanceManager.isLoading
                ) {
                    onReload()
                }
            ]
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter metrics", text: $searchText)
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
                ForEach(PerformanceTab.allCases, id: \.self) { tab in
                    PerformanceFilterTab(
                        label: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Core Web Vitals always shown at top
                coreWebVitalsSection

                // Tab content
                switch selectedTab {
                case .metrics:
                    metricsSection
                case .resources:
                    resourcesSection
                case .timing:
                    timingSection
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Core Web Vitals Section

    private var coreWebVitalsSection: some View {
        PerformanceSection {
            VStack(spacing: 16) {
                overallScoreCard
                coreVitalsGrid
                coreVitalsStatus
            }
        }
    }

    private var overallScoreCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(performanceManager.data.totalScore) / 100)
                    .stroke(
                        performanceManager.data.scoreRating.color,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(performanceManager.data.totalScore)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(performanceManager.data.scoreRating.color)
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: performanceManager.data.scoreRating.icon)
                    Text(performanceManager.data.scoreRating.rawValue)
                }
                .font(.headline)
                .foregroundStyle(performanceManager.data.scoreRating.color)

                Text("Web Vitals 2025")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if performanceManager.data.navigation != nil {
                    Text("Measured at \(formatTimestamp(performanceManager.data.timestamp))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
    }

    private var coreVitalsGrid: some View {
        HStack(spacing: 12) {
            CoreVitalCard(
                label: "LCP",
                value: formatLCP(performanceManager.data.largestContentfulPaint),
                rating: performanceManager.data.lcpRating,
                description: "Largest Contentful Paint"
            )
            CoreVitalCard(
                label: "CLS",
                value: formatCLS(performanceManager.data.cls),
                rating: performanceManager.data.clsRating,
                description: "Cumulative Layout Shift"
            )
        }
    }

    private var coreVitalsStatus: some View {
        let passed = performanceManager.data.coreWebVitalsPass

        return HStack(spacing: 8) {
            Image(systemName: passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(passed ? .green : .orange)

            Text(passed ? "Passed Core Web Vitals" : "Needs Improvement")
                .font(.caption.weight(.medium))
                .foregroundStyle(passed ? .green : .orange)

            Spacer()

            Text("LCP + CLS")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Metrics Section

    @ViewBuilder
    private var metricsSection: some View {
        PerformanceSection(title: "Loading Performance") {
            VStack(spacing: 0) {
                if let fcp = performanceManager.data.firstContentfulPaint {
                    if matchesSearch("First Contentful Paint") {
                        MetricRow(
                            label: "First Contentful Paint",
                            value: fcp,
                            rating: MetricThresholds.rate(
                                fcp,
                                good: MetricThresholds.fcpGood,
                                poor: MetricThresholds.fcpPoor
                            )
                        )
                        sectionDivider
                    }
                }

                if let nav = performanceManager.data.navigation {
                    if matchesSearch("Time to First Byte") || matchesSearch("TTFB") {
                        MetricRow(
                            label: "Time to First Byte",
                            value: nav.ttfb,
                            rating: MetricThresholds.rate(
                                nav.ttfb,
                                good: MetricThresholds.ttfbGood,
                                poor: MetricThresholds.ttfbPoor
                            ),
                            threshold: "≤ 200ms"
                        )
                        sectionDivider
                    }

                    if matchesSearch("DOM Content Loaded") {
                        MetricRow(
                            label: "DOM Content Loaded",
                            value: nav.domContentLoadedTime,
                            rating: MetricThresholds.rate(
                                nav.domContentLoadedTime,
                                good: MetricThresholds.dclGood,
                                poor: MetricThresholds.dclPoor
                            )
                        )
                        sectionDivider
                    }

                    if matchesSearch("Page Load") {
                        MetricRow(
                            label: "Page Load",
                            value: nav.loadEventTime,
                            rating: MetricThresholds.rate(
                                nav.loadEventTime,
                                good: MetricThresholds.lcpGood,
                                poor: MetricThresholds.lcpPoor
                            )
                        )
                    }
                }

                if performanceManager.data.tbt >= 0 {
                    if matchesSearch("Total Blocking Time") || matchesSearch("TBT") {
                        sectionDivider
                        MetricRow(
                            label: "Total Blocking Time",
                            value: performanceManager.data.tbt,
                            rating: MetricThresholds.rate(
                                performanceManager.data.tbt,
                                good: MetricThresholds.tbtGood,
                                poor: MetricThresholds.tbtPoor
                            ),
                            threshold: "≤ 200ms"
                        )
                    }
                }
            }
        }

        PerformanceSection(title: "Network") {
            VStack(spacing: 0) {
                if let nav = performanceManager.data.navigation {
                    if matchesSearch("DNS") {
                        MetricRow(
                            label: "DNS Lookup",
                            value: nav.dnsTime,
                            rating: MetricThresholds.rate(
                                nav.dnsTime,
                                good: MetricThresholds.dnsGood,
                                poor: MetricThresholds.dnsPoor
                            )
                        )
                        sectionDivider
                    }

                    if matchesSearch("Connection") || matchesSearch("TCP") || matchesSearch("TLS") {
                        MetricRow(
                            label: "Connection (TCP+TLS)",
                            value: nav.connectionTime,
                            rating: MetricThresholds.rate(
                                nav.connectionTime,
                                good: MetricThresholds.connectGood,
                                poor: MetricThresholds.connectPoor
                            )
                        )
                    }

                    if nav.redirectTime > 0 && matchesSearch("Redirect") {
                        sectionDivider
                        MetricRow(
                            label: "Redirect",
                            value: nav.redirectTime,
                            rating: nav.redirectTime > 100 ? .needsImprovement : .good
                        )
                    }
                }
            }
        }

        PerformanceSection(title: "Summary") {
            VStack(spacing: 0) {
                if matchesSearch("Resources") {
                    HStack {
                        Label("Resources", systemImage: "doc.fill")
                        Spacer()
                        Text("\(performanceManager.data.totalResources)")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    sectionDivider
                }
                if matchesSearch("Transfer") {
                    HStack {
                        Label("Total Transfer", systemImage: "arrow.down.circle.fill")
                        Spacer()
                        Text(formatBytes(performanceManager.data.totalTransferSize))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Resources Section

    @ViewBuilder
    private var resourcesSection: some View {
        let summary = resourceTypeSummary

        PerformanceSection(
            title: "By Type",
            trailing: formatBytes(totalResourceSize)
        ) {
            VStack(spacing: 0) {
                ForEach(Array(summary.enumerated()), id: \.element.type) { index, item in
                    if matchesSearch(item.type.rawValue) {
                        ResourceTypeRow(
                            type: item.type,
                            count: item.count,
                            size: item.size,
                            resources: item.resources,
                            isExpanded: expandedTypes.contains(item.type),
                            onToggle: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if expandedTypes.contains(item.type) {
                                        expandedTypes.remove(item.type)
                                    } else {
                                        expandedTypes.insert(item.type)
                                    }
                                }
                            }
                        )
                        if index < summary.count - 1 {
                            sectionDivider
                        }
                    }
                }
            }
        }
    }

    // MARK: - Timing Section

    @ViewBuilder
    private var timingSection: some View {
        if let nav = performanceManager.data.navigation {
            PerformanceSection(title: "Navigation Breakdown") {
                VStack(spacing: 0) {
                    let breakdowns: [(String, Double)] = [
                        ("Redirect", nav.redirectTime),
                        ("DNS", nav.dnsTime),
                        ("TCP", nav.tcpTime),
                        ("TLS", nav.tlsTime),
                        ("Request", nav.requestTime),
                        ("Response", nav.responseTime),
                        ("DOM Processing", nav.domProcessingTime)
                    ]

                    ForEach(Array(breakdowns.enumerated()), id: \.offset) { index, item in
                        if matchesSearch(item.0) {
                            TimingBreakdownRow(label: item.0, value: item.1, total: nav.loadEventTime)
                                .padding(.vertical, 8)
                            if index < breakdowns.count - 1 {
                                sectionDivider
                            }
                        }
                    }
                }
            }

            PerformanceSection(title: "Timeline") {
                VStack(spacing: 0) {
                    if matchesSearch("TTFB") {
                        TimelineRow(label: "TTFB", time: nav.ttfb)
                            .padding(.vertical, 8)
                        sectionDivider
                    }
                    if let fcp = performanceManager.data.firstContentfulPaint, matchesSearch("FCP") {
                        TimelineRow(label: "FCP", time: fcp)
                            .padding(.vertical, 8)
                        sectionDivider
                    }
                    if matchesSearch("DOM Ready") {
                        TimelineRow(label: "DOM Ready", time: nav.domContentLoadedTime)
                            .padding(.vertical, 8)
                        sectionDivider
                    }
                    if matchesSearch("Load") {
                        TimelineRow(label: "Load", time: nav.loadEventTime)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    ProgressView()
                        .scaleEffect(1.2)
                    VStack(spacing: 4) {
                        Text("Collecting Metrics")
                            .font(.headline)
                        Text("Analyzing page performance...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    VStack(spacing: 4) {
                        Text("No Performance Data")
                            .font(.headline)
                        Text("Navigate to a page to collect metrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func errorState(_ error: String) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Failed to collect metrics")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .padding()
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Divider()
            .padding(.leading, 36)
    }

    private func matchesSearch(_ text: String) -> Bool {
        searchText.isEmpty || text.localizedCaseInsensitiveContains(searchText)
    }

    private var resourceTypeSummary: [(type: ResourceType, count: Int, size: Int, resources: [ResourceTiming])] {
        var summary: [ResourceType: (count: Int, size: Int, resources: [ResourceTiming])] = [:]
        for resource in performanceManager.data.resources {
            let type = resource.resourceType
            var current = summary[type] ?? (0, 0, [])
            current.count += 1
            current.size += resource.displaySize
            current.resources.append(resource)
            summary[type] = current
        }
        return ResourceType.allCases
            .compactMap { type in
                guard let data = summary[type] else { return nil }
                return (type, data.count, data.size, data.resources)
            }
            .sorted { $0.size > $1.size }
    }

    private var totalResourceSize: Int {
        performanceManager.data.resources.reduce(0) { $0 + $1.displaySize }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatLCP(_ value: Double?) -> String {
        guard let value, value > 0 else { return "N/A" }
        return value >= 1000 ? String(format: "%.2fs", value / 1000) : String(format: "%.0fms", value)
    }

    private func formatCLS(_ value: Double) -> String {
        guard value >= 0 else { return "N/A" }
        return String(format: "%.3f", value)
    }
}

// MARK: - Performance Filter Tab

private struct PerformanceFilterTab: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(.primary)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Performance Section

private struct PerformanceSection<Content: View>: View {
    let title: String?
    let trailing: String?
    let content: () -> Content

    init(
        title: String? = nil,
        trailing: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Resource Type Row

private struct ResourceTypeRow: View {
    let type: ResourceType
    let count: Int
    let size: Int
    let resources: [ResourceTiming]
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16)

                    Text(type.rawValue)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(count)")
                        .foregroundStyle(.secondary)

                    Text(size > 0 ? formatBytes(size) : "—")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(size > 0 ? .secondary : .tertiary)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(resources.sorted(by: { $0.displaySize > $1.displaySize }).prefix(15)) { resource in
                        ResourceDetailRow(resource: resource)
                            .padding(.leading, 24)
                            .padding(.vertical, 6)
                    }
                    if resources.count > 15 {
                        Text("+ \(resources.count - 15) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 24)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) B"
    }
}

// MARK: - Preview

#Preview("Good Performance") {
    PerformanceView(
        performanceManager: {
            let manager = PerformanceManager()
            manager.data = PerformanceData(
                navigation: NavigationTiming(
                    startTime: 0,
                    redirectTime: 0,
                    dnsTime: 23,
                    tcpTime: 45,
                    tlsTime: 67,
                    requestTime: 50,
                    responseTime: 89,
                    domProcessingTime: 234,
                    domContentLoadedTime: 567,
                    loadEventTime: 1234
                ),
                resources: [
                    ResourceTiming(
                        id: UUID(), name: "https://example.com/script.js",
                        initiatorType: "script", startTime: 100, duration: 200,
                        transferSize: 45000, encodedBodySize: 45000, decodedBodySize: 120000
                    ),
                    ResourceTiming(
                        id: UUID(), name: "https://example.com/style.css",
                        initiatorType: "link", startTime: 50, duration: 150,
                        transferSize: 12000, encodedBodySize: 12000, decodedBodySize: 35000
                    )
                ],
                paints: [
                    PaintTiming(name: "first-paint", startTime: 345),
                    PaintTiming(name: "first-contentful-paint", startTime: 456)
                ],
                cls: 0.05,
                tbt: 150
            )
            return manager
        }(),
        onCollect: {},
        onReload: {}
    )
}
