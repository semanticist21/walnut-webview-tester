//
//  ResourceView.swift
//  wina
//
//  Resource timing view showing all page resources (images, scripts, styles, etc).
//  Uses Resource Timing API via PerformanceObserver.
//

import SwiftUI

// MARK: - Resource View

struct ResourceView: View {
    let resourceManager: ResourceManager
    @Environment(\.dismiss) private var dismiss
    @State private var filterType: ResourceFilter = .all
    @State private var searchText: String = ""
    @State private var shareItem: ResourceShareContent?
    @State private var showSettings: Bool = false
    @State private var selectedResource: ResourceEntry?
    @AppStorage("resourcePreserveLog") private var preserveLog: Bool = false

    private var filteredResources: [ResourceEntry] {
        var result = resourceManager.resources

        if filterType != .all {
            result = result.filter { filterType.matches($0.initiatorType) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var settingsActive: Bool {
        preserveLog
    }

    var body: some View {
        VStack(spacing: 0) {
            resourceHeader
            searchBar
            filterTabs

            Divider()

            if filteredResources.isEmpty {
                emptyState
            } else {
                resourceList
            }
        }
        .sheet(item: $shareItem) { item in
            ResourceShareSheet(content: item.content)
        }
        .sheet(isPresented: $showSettings) {
            ResourceSettingsSheet()
        }
        .sheet(item: $selectedResource) { resource in
            ResourceDetailView(resource: resource)
        }
        .task {
            await AdManager.shared.showInterstitialAd(
                options: AdOptions(id: "resources_devtools"),
                adUnitId: AdManager.interstitialAdUnitId
            )
        }
    }

    // MARK: - Resource Header

    private var resourceHeader: some View {
        DevToolsHeader(
            title: "Resources",
            leftButtons: [
                .init(icon: "xmark.circle.fill", color: .secondary) {
                    dismiss()
                },
                .init(
                    icon: "trash",
                    isDisabled: resourceManager.resources.isEmpty
                ) {
                    resourceManager.clear()
                },
                .init(
                    icon: "square.and.arrow.up",
                    isDisabled: resourceManager.resources.isEmpty
                ) {
                    shareItem = ResourceShareContent(content: exportAsText())
                }
            ],
            rightButtons: [
                .init(
                    icon: "play.fill",
                    activeIcon: "pause.fill",
                    color: .green,
                    activeColor: .red,
                    isActive: resourceManager.isCapturing
                ) {
                    resourceManager.isCapturing.toggle()
                },
                .init(
                    icon: "gearshape",
                    activeIcon: "gearshape.fill",
                    color: .secondary,
                    activeColor: .blue,
                    isActive: settingsActive
                ) {
                    showSettings = true
                }
            ]
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter", text: $searchText)
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
                ForEach(ResourceFilter.allCases) { filter in
                    ResourceFilterTab(
                        filter: filter,
                        count: resourceManager.count(for: filter),
                        isSelected: filterType == filter
                    ) {
                        filterType = filter
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "photo.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(resourceManager.resources.isEmpty ? "No resources" : "No matches")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !resourceManager.isCapturing {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Resource List

    private var resourceList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Stats summary
                    statsRow

                    ForEach(filteredResources) { resource in
                        ResourceRow(resource: resource)
                            .id(resource.id)
                            .onTapGesture {
                                selectedResource = resource
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .scrollContentBackground(.hidden)
            .onChange(of: resourceManager.resources.count) { _, _ in
                if let lastResource = filteredResources.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastResource.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let stats = resourceManager.stats
        return HStack(spacing: 16) {
            Label("\(stats.totalCount) resources", systemImage: "doc.fill")
            Label(stats.displayTotalSize, systemImage: "arrow.down.circle.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Export

    private func exportAsText() -> String {
        var header = "Resource Timing Export"
        if filterType != .all {
            header += " (Filter: \(filterType.displayName))"
        }
        if !searchText.isEmpty {
            header += " (Search: \(searchText))"
        }
        header += "\nExported: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))"
        header += "\nTotal: \(filteredResources.count) resources"
        header += "\n" + String(repeating: "-", count: 50) + "\n\n"

        let body = filteredResources
            .map { res in
                var line = "[\(res.initiatorType.displayName)] \(res.name)"
                line += "\n  Duration: \(res.displayDuration)"
                line += ", Size: \(res.displaySize)"
                if res.isCrossOriginRestricted {
                    line += " (cross-origin)"
                }
                return line
            }
            .joined(separator: "\n\n")

        return header + body
    }
}

// MARK: - Resource Filter Tab

private struct ResourceFilterTab: View {
    let filter: ResourceFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if count != 0 {  // swiftlint:disable:this empty_count
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.primary.opacity(0.2) : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Resource Row

private struct ResourceRow: View {
    let resource: ResourceEntry

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Type icon
            Image(systemName: resource.initiatorType.icon)
                .font(.system(size: 12))
                .foregroundStyle(resource.initiatorType.color)
                .frame(width: 24, height: 24)

            // Resource info
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.displayName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let host = resource.host {
                    Text(host)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right side info
            VStack(alignment: .trailing, spacing: 2) {
                Text(resource.displayDuration)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)

                Text(resource.displaySize)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Type badge
            Text(resource.initiatorType.displayName)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(resource.initiatorType.color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(resource.isCrossOriginRestricted ? Color.orange.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 12)
        }
    }
}

// MARK: - Resource Settings Sheet

private struct ResourceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("resourcePreserveLog") private var preserveLog: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Logging") {
                    Toggle("Preserve Log on Reload", isOn: $preserveLog)
                }

                Section {
                    Text("Resources are collected using the Resource Timing API. Cross-origin resources may have limited timing data due to browser security restrictions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Resources Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Resource Share Content

struct ResourceShareContent: Identifiable {
    let id = UUID()
    let content: String
}

// MARK: - Resource Share Sheet

private struct ResourceShareSheet: View {
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: content) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    let manager = ResourceManager()
    manager.addResource(
        name: "https://example.com/logo.png",
        initiatorType: "img",
        startTime: 100,
        duration: 250,
        transferSize: 15_000,
        encodedBodySize: 15_000,
        decodedBodySize: 18_000,
        dnsTime: 10,
        tcpTime: 20,
        tlsTime: 15,
        requestTime: 50,
        responseTime: 155
    )

    return ResourceView(resourceManager: manager)
        .presentationDetents([.fraction(0.35), .medium, .large])
}
