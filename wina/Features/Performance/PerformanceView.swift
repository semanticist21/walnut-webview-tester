//
//  PerformanceView.swift
//  wina
//
//  Created by Claude on 12/14/25.
//

import SwiftUI

// MARK: - Performance Score Rating

enum PerformanceRating: String {
    case good = "Good"
    case needsImprovement = "Needs Improvement"
    case poor = "Poor"
    case unknown = "N/A"

    var color: Color {
        switch self {
        case .good: .green
        case .needsImprovement: .orange
        case .poor: .red
        case .unknown: .secondary
        }
    }

    var icon: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .needsImprovement: "exclamationmark.circle.fill"
        case .poor: "xmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

// MARK: - Metric Thresholds (Google Web Vitals)

struct MetricThresholds {
    // FCP: First Contentful Paint
    static let fcpGood: Double = 1800  // < 1.8s
    static let fcpPoor: Double = 3000  // >= 3s

    // LCP: Largest Contentful Paint (approximated by load time)
    static let lcpGood: Double = 2500  // < 2.5s
    static let lcpPoor: Double = 4000  // >= 4s

    // TTFB: Time to First Byte
    static let ttfbGood: Double = 800  // < 800ms
    static let ttfbPoor: Double = 1800  // >= 1.8s

    // DOM Content Loaded
    static let dclGood: Double = 1500  // < 1.5s
    static let dclPoor: Double = 3000  // >= 3s

    // DNS Lookup
    static let dnsGood: Double = 50  // < 50ms
    static let dnsPoor: Double = 200  // >= 200ms

    // TCP/TLS Connection
    static let connectGood: Double = 100  // < 100ms
    static let connectPoor: Double = 300  // >= 300ms

    static func rate(_ value: Double, good: Double, poor: Double) -> PerformanceRating {
        if value <= 0 { return .unknown }
        if value < good { return .good }
        if value < poor { return .needsImprovement }
        return .poor
    }

    static func score(_ value: Double, good: Double, poor: Double) -> Int {
        if value <= 0 { return 0 }
        if value <= good { return 100 }
        if value >= poor { return 0 }
        // Linear interpolation between good and poor
        let ratio = (poor - value) / (poor - good)
        return Int(ratio * 100)
    }
}

// MARK: - Navigation Timing

struct NavigationTiming: Codable, Equatable {
    let startTime: Double
    let redirectTime: Double
    let dnsTime: Double
    let tcpTime: Double
    let tlsTime: Double
    let requestTime: Double
    let responseTime: Double
    let domProcessingTime: Double
    let domContentLoadedTime: Double
    let loadEventTime: Double

    // TTFB = time from navigation start to first byte of response
    var ttfb: Double {
        requestTime + responseTime
    }

    // Connection time = TCP + TLS
    var connectionTime: Double {
        tcpTime + tlsTime
    }
}

// MARK: - Resource Timing

struct ResourceTiming: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let initiatorType: String
    let startTime: Double
    let duration: Double
    let transferSize: Int
    let encodedBodySize: Int
    let decodedBodySize: Int

    var resourceType: ResourceType {
        ResourceType.from(initiatorType: initiatorType, name: name)
    }

    var shortName: String {
        if let url = URL(string: name) {
            return url.lastPathComponent.isEmpty ? url.host() ?? name : url.lastPathComponent
        }
        return String(name.suffix(30))
    }
}

// MARK: - Resource Type

enum ResourceType: String, CaseIterable {
    case document = "Document"
    case script = "Script"
    case stylesheet = "Stylesheet"
    case image = "Image"
    case font = "Font"
    case fetch = "Fetch/XHR"
    case other = "Other"

    var icon: String {
        switch self {
        case .document: "doc.fill"
        case .script: "curlybraces"
        case .stylesheet: "paintbrush.fill"
        case .image: "photo.fill"
        case .font: "textformat"
        case .fetch: "arrow.down.circle.fill"
        case .other: "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .document: .blue
        case .script: .yellow
        case .stylesheet: .purple
        case .image: .green
        case .font: .orange
        case .fetch: .cyan
        case .other: .gray
        }
    }

    static func from(initiatorType: String, name: String) -> ResourceType {
        switch initiatorType.lowercased() {
        case "navigation": return .document
        case "script": return .script
        case "link", "css": return .stylesheet
        case "img", "image": return .image
        case "font": return .font
        case "fetch", "xmlhttprequest": return .fetch
        default:
            // Fallback to extension-based detection
            let ext = (name as NSString).pathExtension.lowercased()
            switch ext {
            case "js", "mjs": return .script
            case "css": return .stylesheet
            case "png", "jpg", "jpeg", "gif", "webp", "svg", "ico": return .image
            case "woff", "woff2", "ttf", "otf", "eot": return .font
            default: return .other
            }
        }
    }
}

// MARK: - Paint Timing

struct PaintTiming: Codable, Equatable {
    let name: String
    let startTime: Double
}

// MARK: - Performance Data

struct PerformanceData: Equatable {
    var navigation: NavigationTiming?
    var resources: [ResourceTiming] = []
    var paints: [PaintTiming] = []
    var timestamp = Date()

    var totalResources: Int { resources.count }
    var totalTransferSize: Int {
        resources.reduce(0) { $0 + $1.transferSize }
    }

    var firstContentfulPaint: Double? {
        paints.first { $0.name == "first-contentful-paint" }?.startTime
    }

    var firstPaint: Double? {
        paints.first { $0.name == "first-paint" }?.startTime
    }

    // Calculate overall score (0-100)
    var totalScore: Int {
        var scores: [Int] = []

        if let fcp = firstContentfulPaint {
            scores.append(MetricThresholds.score(fcp, good: MetricThresholds.fcpGood, poor: MetricThresholds.fcpPoor))
        }
        if let nav = navigation {
            scores.append(MetricThresholds.score(nav.ttfb, good: MetricThresholds.ttfbGood, poor: MetricThresholds.ttfbPoor))
            scores.append(MetricThresholds.score(
                nav.domContentLoadedTime,
                good: MetricThresholds.dclGood,
                poor: MetricThresholds.dclPoor
            ))
            scores.append(MetricThresholds.score(
                nav.loadEventTime,
                good: MetricThresholds.lcpGood,
                poor: MetricThresholds.lcpPoor
            ))
        }

        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    var scoreRating: PerformanceRating {
        let score = totalScore
        if score == 0 { return .unknown }
        if score >= 90 { return .good }
        if score >= 50 { return .needsImprovement }
        return .poor
    }
}

// MARK: - Performance Manager

@Observable
class PerformanceManager {
    var data = PerformanceData()
    var isLoading: Bool = false
    var lastError: String?

    // JavaScript to collect Performance API data
    static let collectionScript = """
    (function() {
        const result = {
            navigation: null,
            resources: [],
            paints: []
        };

        // Navigation Timing
        const navEntries = performance.getEntriesByType('navigation');
        if (navEntries.length > 0) {
            const nav = navEntries[0];
            result.navigation = {
                startTime: nav.startTime,
                redirectTime: nav.redirectEnd - nav.redirectStart,
                dnsTime: nav.domainLookupEnd - nav.domainLookupStart,
                tcpTime: nav.connectEnd - nav.connectStart,
                tlsTime: nav.secureConnectionStart > 0 ? nav.connectEnd - nav.secureConnectionStart : 0,
                requestTime: nav.responseStart - nav.requestStart,
                responseTime: nav.responseEnd - nav.responseStart,
                domProcessingTime: nav.domComplete - nav.domInteractive,
                domContentLoadedTime: nav.domContentLoadedEventEnd - nav.startTime,
                loadEventTime: nav.loadEventEnd - nav.startTime
            };
        }

        // Resource Timing
        const resourceEntries = performance.getEntriesByType('resource');
        result.resources = resourceEntries.map(r => ({
            name: r.name,
            initiatorType: r.initiatorType,
            startTime: r.startTime,
            duration: r.duration,
            transferSize: r.transferSize || 0,
            encodedBodySize: r.encodedBodySize || 0,
            decodedBodySize: r.decodedBodySize || 0
        }));

        // Paint Timing
        const paintEntries = performance.getEntriesByType('paint');
        result.paints = paintEntries.map(p => ({
            name: p.name,
            startTime: p.startTime
        }));

        return JSON.stringify(result);
    })()
    """

    func parseData(from jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            lastError = "Failed to convert string to data"
            return
        }

        do {
            let decoded = try JSONDecoder().decode(RawPerformanceData.self, from: jsonData)
            data = PerformanceData(
                navigation: decoded.navigation,
                resources: decoded.resources.map { raw in
                    ResourceTiming(
                        id: UUID(),
                        name: raw.name,
                        initiatorType: raw.initiatorType,
                        startTime: raw.startTime,
                        duration: raw.duration,
                        transferSize: raw.transferSize,
                        encodedBodySize: raw.encodedBodySize,
                        decodedBodySize: raw.decodedBodySize
                    )
                },
                paints: decoded.paints,
                timestamp: Date()
            )
            lastError = nil
        } catch {
            lastError = "Parse error: \(error.localizedDescription)"
        }
    }

    func clear() {
        data = PerformanceData()
        lastError = nil
    }
}

// Raw JSON structures for decoding
private struct RawPerformanceData: Codable {
    let navigation: NavigationTiming?
    let resources: [RawResourceTiming]
    let paints: [PaintTiming]
}

private struct RawResourceTiming: Codable {
    let name: String
    let initiatorType: String
    let startTime: Double
    let duration: Double
    let transferSize: Int
    let encodedBodySize: Int
    let decodedBodySize: Int
}

// MARK: - Performance View

struct PerformanceView: View {
    let performanceManager: PerformanceManager
    let onRefresh: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            List {
                if performanceManager.data.navigation != nil || !performanceManager.data.paints.isEmpty {
                    // Score Section
                    scoreSection

                    // Tab Picker
                    Section {
                        Picker("View", selection: $selectedTab) {
                            Text("Metrics").tag(0)
                            Text("Resources").tag(1)
                            Text("Timing").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }

                    // Tab Content
                    switch selectedTab {
                    case 0:
                        metricsSection
                    case 1:
                        resourcesSection
                    case 2:
                        timingSection
                    default:
                        EmptyView()
                    }
                } else if performanceManager.lastError != nil {
                    errorSection
                } else {
                    emptySection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        performanceManager.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(performanceManager.data.navigation == nil && performanceManager.data.paints.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            onRefresh()
                        } label: {
                            if performanceManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                        }
                        .disabled(performanceManager.isLoading)

                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Score Section

    @ViewBuilder
    private var scoreSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Text("\(performanceManager.data.totalScore)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(performanceManager.data.scoreRating.color)

                    HStack(spacing: 4) {
                        Image(systemName: performanceManager.data.scoreRating.icon)
                        Text(performanceManager.data.scoreRating.rawValue)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(performanceManager.data.scoreRating.color)

                    Text("Based on Google Web Vitals")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Metrics Section

    @ViewBuilder
    private var metricsSection: some View {
        Section("Core Web Vitals") {
            if let fcp = performanceManager.data.firstContentfulPaint {
                MetricRow(
                    label: "First Contentful Paint",
                    value: fcp,
                    rating: MetricThresholds.rate(fcp, good: MetricThresholds.fcpGood, poor: MetricThresholds.fcpPoor)
                )
            }

            if let fp = performanceManager.data.firstPaint {
                MetricRow(
                    label: "First Paint",
                    value: fp,
                    rating: MetricThresholds.rate(fp, good: MetricThresholds.fcpGood, poor: MetricThresholds.fcpPoor)
                )
            }

            if let nav = performanceManager.data.navigation {
                MetricRow(
                    label: "Time to First Byte",
                    value: nav.ttfb,
                    rating: MetricThresholds.rate(nav.ttfb, good: MetricThresholds.ttfbGood, poor: MetricThresholds.ttfbPoor)
                )

                MetricRow(
                    label: "DOM Content Loaded",
                    value: nav.domContentLoadedTime,
                    rating: MetricThresholds.rate(
                        nav.domContentLoadedTime,
                        good: MetricThresholds.dclGood,
                        poor: MetricThresholds.dclPoor
                    )
                )

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

        Section("Network") {
            if let nav = performanceManager.data.navigation {
                MetricRow(
                    label: "DNS Lookup",
                    value: nav.dnsTime,
                    rating: MetricThresholds.rate(nav.dnsTime, good: MetricThresholds.dnsGood, poor: MetricThresholds.dnsPoor)
                )

                MetricRow(
                    label: "Connection (TCP+TLS)",
                    value: nav.connectionTime,
                    rating: MetricThresholds.rate(
                        nav.connectionTime,
                        good: MetricThresholds.connectGood,
                        poor: MetricThresholds.connectPoor
                    )
                )

                if nav.redirectTime > 0 {
                    MetricRow(
                        label: "Redirect",
                        value: nav.redirectTime,
                        rating: nav.redirectTime > 100 ? .needsImprovement : .good
                    )
                }
            }
        }

        Section {
            HStack {
                Text("Resources")
                Spacer()
                Text("\(performanceManager.data.totalResources)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Total Transfer")
                Spacer()
                Text(formatBytes(performanceManager.data.totalTransferSize))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Resources Section

    @ViewBuilder
    private var resourcesSection: some View {
        // Resource type summary
        Section("By Type") {
            ForEach(resourceTypeSummary, id: \.type) { summary in
                HStack {
                    Image(systemName: summary.type.icon)
                        .foregroundStyle(summary.type.color)
                        .frame(width: 24)
                    Text(summary.type.rawValue)
                    Spacer()
                    Text("\(summary.count)")
                        .foregroundStyle(.secondary)
                    Text(formatBytes(summary.size))
                        .foregroundStyle(.tertiary)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }

        // Resource list
        Section("All Resources (\(performanceManager.data.resources.count))") {
            ForEach(performanceManager.data.resources.prefix(50)) { resource in
                ResourceRow(resource: resource)
            }
            if performanceManager.data.resources.count > 50 {
                Text("+ \(performanceManager.data.resources.count - 50) more...")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    // MARK: - Timing Section

    @ViewBuilder
    private var timingSection: some View {
        if let nav = performanceManager.data.navigation {
            Section("Navigation Breakdown") {
                TimingBreakdownRow(label: "Redirect", value: nav.redirectTime, total: nav.loadEventTime)
                TimingBreakdownRow(label: "DNS", value: nav.dnsTime, total: nav.loadEventTime)
                TimingBreakdownRow(label: "TCP", value: nav.tcpTime, total: nav.loadEventTime)
                TimingBreakdownRow(label: "TLS", value: nav.tlsTime, total: nav.loadEventTime)
                TimingBreakdownRow(label: "Request", value: nav.requestTime, total: nav.loadEventTime)
                TimingBreakdownRow(label: "Response", value: nav.responseTime, total: nav.loadEventTime)
                TimingBreakdownRow(label: "DOM Processing", value: nav.domProcessingTime, total: nav.loadEventTime)
            }

            Section("Timeline") {
                TimelineRow(label: "TTFB", time: nav.ttfb)
                if let fcp = performanceManager.data.firstContentfulPaint {
                    TimelineRow(label: "FCP", time: fcp)
                }
                TimelineRow(label: "DOM Ready", time: nav.domContentLoadedTime)
                TimelineRow(label: "Load", time: nav.loadEventTime)
            }
        }
    }

    // MARK: - Empty/Error Sections

    @ViewBuilder
    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No Performance Data")
                    .font(.headline)
                Text("Load a page first, then tap refresh to collect metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text(performanceManager.lastError ?? "Unknown error")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Helpers

    private var resourceTypeSummary: [(type: ResourceType, count: Int, size: Int)] {
        var summary: [ResourceType: (count: Int, size: Int)] = [:]
        for resource in performanceManager.data.resources {
            let type = resource.resourceType
            let current = summary[type] ?? (0, 0)
            summary[type] = (current.count + 1, current.size + resource.transferSize)
        }
        return ResourceType.allCases
            .compactMap { type in
                guard let data = summary[type] else { return nil }
                return (type, data.count, data.size)
            }
            .sorted { $0.count > $1.count }
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

// MARK: - Metric Row

private struct MetricRow: View {
    let label: String
    let value: Double
    let rating: PerformanceRating

    var body: some View {
        HStack {
            Image(systemName: rating.icon)
                .foregroundStyle(rating.color)
                .frame(width: 24)

            Text(label)

            Spacer()

            Text(formatTime(value))
                .foregroundStyle(rating.color)
                .fontWeight(.medium)
        }
    }

    private func formatTime(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2fs", ms / 1000)
        }
        return String(format: "%.0fms", ms)
    }
}

// MARK: - Resource Row

private struct ResourceRow: View {
    let resource: ResourceTiming

    var body: some View {
        HStack {
            Image(systemName: resource.resourceType.icon)
                .foregroundStyle(resource.resourceType.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(resource.shortName)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(formatTime(resource.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if resource.transferSize > 0 {
                Text(formatBytes(resource.transferSize))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func formatTime(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2fs", ms / 1000)
        }
        return String(format: "%.0fms", ms)
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

// MARK: - Timing Breakdown Row

private struct TimingBreakdownRow: View {
    let label: String
    let value: Double
    let total: Double

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                let width = geometry.size.width
                let barWidth = total > 0 ? (value / total) * width : 0

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 8)
                        .clipShape(Capsule())

                    Rectangle()
                        .fill(.blue)
                        .frame(width: barWidth, height: 8)
                        .clipShape(Capsule())
                }
            }
            .frame(width: 80, height: 8)

            Text(formatTime(value))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    private func formatTime(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2fs", ms / 1000)
        }
        return String(format: "%.0fms", ms)
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let label: String
    let time: Double

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(formatTime(time))
                .foregroundStyle(.secondary)
        }
    }

    private func formatTime(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2fs", ms / 1000)
        }
        return String(format: "%.0fms", ms)
    }
}

// MARK: - Preview

#Preview {
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
                    requestTime: 120,
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
                ]
            )
            return manager
        }()
    ) {}
}
