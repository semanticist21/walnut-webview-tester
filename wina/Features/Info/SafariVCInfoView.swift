//
//  SafariVCInfoView.swift
//  wina
//

import SafariServices
import SwiftUI

struct SafariVCInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var searchText = ""

    // Current configuration values
    @AppStorage("safariEntersReaderIfAvailable") private var entersReaderIfAvailable: Bool = false
    @AppStorage("safariBarCollapsingEnabled") private var barCollapsingEnabled: Bool = true
    @AppStorage("safariDismissButtonStyle") private var dismissButtonStyle: Int = 0
    @AppStorage("safariControlTintColorHex") private var controlTintColorHex: String = ""
    @AppStorage("safariBarTintColorHex") private var barTintColorHex: String = ""

    private var dismissButtonStyleText: String {
        switch dismissButtonStyle {
        case 1: return "Close"
        case 2: return "Cancel"
        default: return "Done"
        }
    }

    private var allItems: [SafariInfoSearchItem] {
        var items: [SafariInfoSearchItem] = []

        // Active Settings
        items.append(contentsOf: [
            SafariInfoSearchItem(category: "Active Settings", label: "Reader Mode", value: entersReaderIfAvailable ? "Enabled" : "Disabled"),
            SafariInfoSearchItem(category: "Active Settings", label: "Bar Collapsing", value: barCollapsingEnabled ? "Enabled" : "Disabled"),
            SafariInfoSearchItem(category: "Active Settings", label: "Dismiss Button", value: dismissButtonStyleText),
            SafariInfoSearchItem(category: "Active Settings", label: "Control Tint", value: controlTintColorHex.isEmpty ? "System" : controlTintColorHex),
            SafariInfoSearchItem(category: "Active Settings", label: "Bar Tint", value: barTintColorHex.isEmpty ? "System" : barTintColorHex)
        ])

        // Safari Features
        items.append(contentsOf: [
            SafariInfoSearchItem(category: "Safari Features", label: "Reader Mode", value: "iOS 9.0+"),
            SafariInfoSearchItem(category: "Safari Features", label: "AutoFill", value: "iOS 9.0+"),
            SafariInfoSearchItem(category: "Safari Features", label: "Fraudulent Website Detection", value: "iOS 9.0+"),
            SafariInfoSearchItem(category: "Safari Features", label: "Content Blockers", value: "iOS 9.0+"),
            SafariInfoSearchItem(category: "Safari Features", label: "Safari Extensions", value: "iOS 15.0+")
        ])

        // API Availability
        items.append(contentsOf: [
            SafariInfoSearchItem(category: "API Availability", label: "SFSafariViewController", value: "iOS 9.0"),
            SafariInfoSearchItem(category: "API Availability", label: "Configuration", value: "iOS 11.0"),
            SafariInfoSearchItem(category: "API Availability", label: "preferredBarTintColor", value: "iOS 10.0"),
            SafariInfoSearchItem(category: "API Availability", label: "preferredControlTintColor", value: "iOS 10.0"),
            SafariInfoSearchItem(category: "API Availability", label: "dismissButtonStyle", value: "iOS 11.0"),
            SafariInfoSearchItem(category: "API Availability", label: "prewarmConnections", value: "iOS 15.0"),
            SafariInfoSearchItem(category: "API Availability", label: "Activity Button", value: "iOS 15.0")
        ])

        // Privacy & Data
        items.append(contentsOf: [
            SafariInfoSearchItem(category: "Privacy & Data", label: "Cookie Isolation", value: "iOS 11.0"),
            SafariInfoSearchItem(category: "Privacy & Data", label: "LocalStorage Isolation", value: "iOS 11.0"),
            SafariInfoSearchItem(category: "Privacy & Data", label: "Session Isolation", value: "iOS 11.0")
        ])

        // Delegate Events
        items.append(contentsOf: [
            SafariInfoSearchItem(category: "Delegate Events", label: "safariViewControllerDidFinish", value: "Method"),
            SafariInfoSearchItem(category: "Delegate Events", label: "didCompleteInitialLoad", value: "Method"),
            SafariInfoSearchItem(category: "Delegate Events", label: "activityItemsFor", value: "Method"),
            SafariInfoSearchItem(category: "Delegate Events", label: "initialLoadDidRedirectTo", value: "Method"),
            SafariInfoSearchItem(category: "Delegate Events", label: "willOpenInBrowser", value: "Method"),
            SafariInfoSearchItem(category: "Delegate Events", label: "excludedActivityTypes", value: "Method")
        ])

        // Limitations
        items.append(contentsOf: [
            SafariInfoSearchItem(category: "Limitations", label: "No JavaScript Injection", value: "Limitation"),
            SafariInfoSearchItem(category: "Limitations", label: "No DOM Access", value: "Limitation"),
            SafariInfoSearchItem(category: "Limitations", label: "No Navigation Control", value: "Limitation"),
            SafariInfoSearchItem(category: "Limitations", label: "No URL Changes", value: "Limitation"),
            SafariInfoSearchItem(category: "Limitations", label: "Limited UI Customization", value: "Limitation")
        ])

        return items
    }

    private var filteredItems: [String: [SafariInfoSearchItem]] {
        let filtered = searchText.isEmpty ? allItems : allItems.filter {
            $0.label.localizedCaseInsensitiveContains(searchText) ||
                $0.value.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: filtered, by: { $0.category })
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchResultsView
                } else {
                    menuView
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all info")
            .navigationTitle("SafariVC Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SafariVCSettingsView()
            }
        }
    }

    // MARK: - Search Results View

    @ViewBuilder
    private var searchResultsView: some View {
        List {
            ForEach(filteredItems.keys.sorted(), id: \.self) { category in
                Section(category) {
                    ForEach(filteredItems[category] ?? []) { item in
                        HStack {
                            Text(item.label)
                            Spacer()
                            Text(item.value)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .overlay {
            if filteredItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    // MARK: - Menu View

    @ViewBuilder
    private var menuView: some View {
        List {
            Section {
                NavigationLink {
                    SafariActiveSettingsDetailView(showSettings: $showingSettings)
                } label: {
                    SafariInfoCategoryRow(
                        icon: "slider.horizontal.3",
                        title: "Active Settings",
                        description: "Current SafariVC configuration"
                    )
                }
            } header: {
                Text("Current Configuration")
            }

            Section {
                NavigationLink {
                    SafariFeaturesDetailView()
                } label: {
                    SafariInfoCategoryRow(
                        icon: "safari",
                        title: "Safari Features",
                        description: "Reader, AutoFill, Content Blockers"
                    )
                }

                NavigationLink {
                    SafariAPIDetailView()
                } label: {
                    SafariInfoCategoryRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        title: "API Availability",
                        description: "SFSafariViewController APIs"
                    )
                }

                NavigationLink {
                    SafariPrivacyDetailView()
                } label: {
                    SafariInfoCategoryRow(
                        icon: "lock.shield",
                        title: "Privacy & Data",
                        description: "Cookie, Storage isolation"
                    )
                }

                NavigationLink {
                    SafariDelegateDetailView()
                } label: {
                    SafariInfoCategoryRow(
                        icon: "arrow.triangle.branch",
                        title: "Delegate Events",
                        description: "Available callback methods"
                    )
                }

                NavigationLink {
                    SafariLimitationsDetailView()
                } label: {
                    SafariInfoCategoryRow(
                        icon: "exclamationmark.triangle",
                        title: "Limitations",
                        description: "What SafariVC cannot do"
                    )
                }
            } header: {
                Text("SafariVC Capabilities")
            }
        }
    }
}

// MARK: - Safari Info Category Row

private struct SafariInfoCategoryRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Active Settings Detail View

private struct SafariActiveSettingsDetailView: View {
    @Binding var showSettings: Bool

    @AppStorage("safariEntersReaderIfAvailable") private var entersReaderIfAvailable: Bool = false
    @AppStorage("safariBarCollapsingEnabled") private var barCollapsingEnabled: Bool = true
    @AppStorage("safariDismissButtonStyle") private var dismissButtonStyle: Int = 0
    @AppStorage("safariControlTintColorHex") private var controlTintColorHex: String = ""
    @AppStorage("safariBarTintColorHex") private var barTintColorHex: String = ""

    private var dismissButtonStyleText: String {
        switch dismissButtonStyle {
        case 1: return "Close"
        case 2: return "Cancel"
        default: return "Done"
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Behavior") {
                SafariInfoRow(
                    label: "Reader Mode",
                    value: entersReaderIfAvailable ? "Enabled" : "Disabled",
                    valueColor: entersReaderIfAvailable ? .green : .secondary,
                    info: "Automatically enters Reader mode when available for the page."
                )
                SafariInfoRow(
                    label: "Bar Collapsing",
                    value: barCollapsingEnabled ? "Enabled" : "Disabled",
                    valueColor: barCollapsingEnabled ? .green : .secondary,
                    info: "Navigation bar collapses when scrolling down."
                )
            }

            Section("UI Style") {
                SafariInfoRow(
                    label: "Dismiss Button",
                    value: dismissButtonStyleText,
                    info: "Button style shown in top-left corner."
                )
            }

            Section("Colors") {
                SafariInfoRow(
                    label: "Control Tint",
                    value: controlTintColorHex.isEmpty ? "System" : controlTintColorHex,
                    info: "Tint color for buttons and controls."
                )
                SafariInfoRow(
                    label: "Bar Tint",
                    value: barTintColorHex.isEmpty ? "System" : barTintColorHex,
                    info: "Background color of navigation bar."
                )
            }
        }
        .navigationTitle("Active Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safari Features Detail View

private struct SafariFeaturesDetailView: View {
    var body: some View {
        List {
            Section("Included Safari Features") {
                SafariCapabilityRow(
                    label: "Reader Mode",
                    supported: true,
                    info: "Distraction-free article view with customizable appearance."
                )
                SafariCapabilityRow(
                    label: "AutoFill",
                    supported: true,
                    info: "Access to saved passwords via iCloud Keychain."
                )
                SafariCapabilityRow(
                    label: "Fraudulent Website Detection",
                    supported: true,
                    info: "Warns users about suspected phishing sites."
                )
                SafariCapabilityRow(
                    label: "Content Blockers",
                    supported: true,
                    info: "User's installed Safari content blockers are applied."
                )
                SafariCapabilityRow(
                    label: "Safari Extensions",
                    supported: true,
                    availability: "iOS 15.0+",
                    info: "User's Safari web extensions are available."
                )
            }
        }
        .navigationTitle("Safari Features")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safari API Detail View

private struct SafariAPIDetailView: View {
    var body: some View {
        List {
            Section("Core API") {
                SafariAPIRow(
                    api: "SFSafariViewController",
                    description: "Core Safari view controller",
                    minVersion: "iOS 9.0"
                )
                SafariAPIRow(
                    api: "Configuration",
                    description: "Reader mode, bar collapsing options",
                    minVersion: "iOS 11.0"
                )
            }

            Section("Appearance") {
                SafariAPIRow(
                    api: "preferredBarTintColor",
                    description: "Navigation bar background color",
                    minVersion: "iOS 10.0"
                )
                SafariAPIRow(
                    api: "preferredControlTintColor",
                    description: "Button and control tint color",
                    minVersion: "iOS 10.0"
                )
                SafariAPIRow(
                    api: "dismissButtonStyle",
                    description: "Done/Close/Cancel button style",
                    minVersion: "iOS 11.0"
                )
            }

            Section("Advanced") {
                SafariAPIRow(
                    api: "prewarmConnections",
                    description: "Pre-load URLs before presenting",
                    minVersion: "iOS 15.0"
                )
                SafariAPIRow(
                    api: "Activity Button",
                    description: "Custom Share Extension in toolbar",
                    minVersion: "iOS 15.0"
                )
            }
        }
        .navigationTitle("API Availability")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safari Privacy Detail View

private struct SafariPrivacyDetailView: View {
    var body: some View {
        List {
            Section("Data Isolation") {
                SafariPrivacyRow(
                    title: "Cookie Isolation",
                    description: "Cookies are NOT shared with Safari app. Each app has separate cookie storage.",
                    since: "iOS 11.0"
                )
                SafariPrivacyRow(
                    title: "LocalStorage Isolation",
                    description: "Website data is sandboxed per app. Data stored in one app is not accessible from another.",
                    since: "iOS 11.0"
                )
                SafariPrivacyRow(
                    title: "Session Isolation",
                    description: "Each SFSafariViewController instance has separate storage. Closing and reopening clears session.",
                    since: "iOS 11.0"
                )
            }

            Section {
                Text("Prior to iOS 11, SFSafariViewController shared cookies and website data with Safari. This was changed for user privacy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safari Delegate Detail View

private struct SafariDelegateDetailView: View {
    var body: some View {
        List {
            Section("SFSafariViewControllerDelegate") {
                SafariDelegateRow(
                    method: "safariViewControllerDidFinish(_:)",
                    description: "Called when user taps Done button. Use this to dismiss the view controller."
                )
                SafariDelegateRow(
                    method: "didCompleteInitialLoad",
                    description: "Called when initial page load completes (success or failure). Good for analytics."
                )
                SafariDelegateRow(
                    method: "initialLoadDidRedirectTo(_:)",
                    description: "Called when initial load redirects to new URL. Track final landing URL."
                )
                SafariDelegateRow(
                    method: "willOpenInBrowser()",
                    description: "Called before opening URL in Safari app. Clean up or save state."
                )
            }

            Section("Activity Customization") {
                SafariDelegateRow(
                    method: "activityItemsFor(_:title:)",
                    description: "Provide custom activities for Share sheet. Return array of UIActivity objects."
                )
                SafariDelegateRow(
                    method: "excludedActivityTypes",
                    description: "Exclude specific activities from Share sheet. Return array of activity type identifiers."
                )
            }
        }
        .navigationTitle("Delegate Events")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safari Limitations Detail View

private struct SafariLimitationsDetailView: View {
    var body: some View {
        List {
            Section("Content Access") {
                SafariLimitationRow(
                    title: "No JavaScript Injection",
                    description: "Cannot execute custom JavaScript code. No evaluateJavaScript() method available."
                )
                SafariLimitationRow(
                    title: "No DOM Access",
                    description: "Cannot read or modify page content. Cannot extract text, images, or any page data."
                )
            }

            Section("Navigation") {
                SafariLimitationRow(
                    title: "No Navigation Control",
                    description: "Cannot intercept or redirect navigation. Cannot block or modify requests."
                )
                SafariLimitationRow(
                    title: "No URL Changes",
                    description: "Cannot change URL after presentation. Must dismiss and create new instance."
                )
            }

            Section("Customization") {
                SafariLimitationRow(
                    title: "Limited UI Customization",
                    description: "Only colors and dismiss button style can be changed. Cannot add custom toolbar items."
                )
            }

            Section {
                Text("These limitations exist because SFSafariViewController prioritizes user privacy and security. For full control, use WKWebView instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Limitations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Views

private struct SafariInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .secondary
    var info: String?

    @State private var showInfo = false

    var body: some View {
        HStack {
            Text(label)
            if let info {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
    }
}

private struct SafariCapabilityRow: View {
    let label: String
    let supported: Bool
    var availability: String?
    var info: String?

    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .secondary)

            Text(label)

            if let info {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }

            Spacer()

            if let availability {
                Text(availability)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SafariAPIRow: View {
    let api: String
    let description: String
    let minVersion: String

    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(api)
                .font(.subheadline.monospaced())

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo) {
                Text(description)
                    .font(.footnote)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Text(minVersion)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SafariPrivacyRow: View {
    let title: String
    let description: String
    let since: String

    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.blue)

            Text(title)

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo) {
                Text(description)
                    .font(.footnote)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Text(since)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SafariDelegateRow: View {
    let method: String
    let description: String

    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "function")
                .foregroundStyle(.purple)

            Text(method)
                .font(.caption.monospaced())
                .lineLimit(1)

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo) {
                Text(description)
                    .font(.footnote)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()
        }
    }
}

private struct SafariLimitationRow: View {
    let title: String
    let description: String

    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)

            Text(title)

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo) {
                Text(description)
                    .font(.footnote)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()
        }
    }
}

// MARK: - Search Item Model

private struct SafariInfoSearchItem: Identifiable {
    let id = UUID()
    let category: String
    let label: String
    let value: String
}

#Preview {
    SafariVCInfoView()
}
