//
//  PreloadProfileSettingsView.swift
//  wina
//
//  Home-screen preload profile editor.
//

import SwiftUI

// MARK: - Preload Profile Settings

struct PreloadProfileSettingsState {
    var profile: WebViewPreloadProfile = .empty
    var savedProfiles: [WebViewPreloadProfile] = []
    private(set) var hasLoaded = false

    mutating func loadIfNeeded(
        activeProfile: () -> WebViewPreloadProfile = { PreloadProfileStore.activeProfile() },
        savedProfiles: () -> [WebViewPreloadProfile] = { PreloadProfileStore.savedProfiles() }
    ) {
        guard !hasLoaded else { return }
        hasLoaded = true
        profile = activeProfile()
        self.savedProfiles = savedProfiles()
    }

    mutating func saveCurrentProfile(
        defaults: UserDefaults = .standard
    ) {
        var reusable = profile
        if reusable.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reusable.name = "Untitled Setup"
        }
        reusable.isEnabled = true
        profile = PreloadProfileStore.upsertSavedProfile(reusable, defaults: defaults)
        PreloadProfileStore.saveActiveProfile(profile, defaults: defaults)
        savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)
    }

    mutating func applyCurrentProfile(
        defaults: UserDefaults = .standard
    ) {
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.name = "Untitled Setup"
        }

        profile.isEnabled = true
        PreloadProfileStore.saveActiveProfile(profile, defaults: defaults)
    }

    mutating func deleteSavedProfiles(
        at offsets: IndexSet,
        defaults: UserDefaults = .standard
    ) {
        savedProfiles.remove(atOffsets: offsets)
        PreloadProfileStore.saveProfiles(savedProfiles, defaults: defaults)
        savedProfiles = PreloadProfileStore.savedProfiles(defaults: defaults)
    }

    mutating func startEmptySetup() {
        profile = WebViewPreloadProfile(name: "Untitled Setup")
    }
}

struct PreloadProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var state = PreloadProfileSettingsState()
    @State private var showSavedSetupLoader = false
    @State private var feedbackState = CopiedFeedbackState()

    var body: some View {
        NavigationStack {
            List {
                experimentalWarningSection
                profileSection
                savedProfilesSection
                cookiesSection
                windowItemsSection
                bridgeSection
                customScriptsSection
            }
            .navigationTitle("Page Startup Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        state.applyCurrentProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadIfNeeded)
            .sheet(isPresented: $showSavedSetupLoader) {
                savedSetupLoaderSheet
            }
            .copiedFeedbackOverlay($feedbackState.message)
        }
    }

    @ViewBuilder
    private var experimentalWarningSection: some View {
        Section {
            Text("Experimental feature. This setup may be unstable across pages.")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section {
            TextField("Profile name", text: $state.profile.name)
                .textInputAutocapitalization(.words)

            Button {
                state.saveCurrentProfile()
                feedbackState.show("Setup saved")
            } label: {
                Text("Save Current Setup")
            }

            Button("Start Empty Setup") {
                state.startEmptySetup()
            }
        } header: {
            Text("Current Setup")
        } footer: {
            Text("Applies cookies, window values, and bridge mocks before a new WKWebView page starts loading.")
        }
    }

    @ViewBuilder
    private var savedProfilesSection: some View {
        Section {
            Button("Load Saved Setup") {
                showSavedSetupLoader = true
            }

        } header: {
            Text("Saved Setups")
        } footer: {
            Text("Open saved setups. Swipe left to delete.")
        }
    }

    @ViewBuilder
    private var savedSetupLoaderSheet: some View {
        NavigationStack {
            List {
                ForEach(state.savedProfiles) { saved in
                    Button {
                        state.profile = saved
                        showSavedSetupLoader = false
                        feedbackState.show("Setup loaded")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(saved.name)
                                .foregroundStyle(.primary)
                            if let summary = savedSetupSummary(for: saved) {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteSavedProfiles)
            }
            .navigationTitle("Load Saved Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showSavedSetupLoader = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var cookiesSection: some View {
        Section {
            ForEach(state.profile.cookies) { cookie in
                NavigationLink {
                    PreloadCookieEditorView(cookie: binding(forCookieID: cookie.id))
                } label: {
                    PreloadEditableRow(
                        title: cookie.name.isEmpty ? "Cookie" : cookie.name,
                        subtitle: cookie.domainMode == .currentHost ? "Current host" : cookie.customDomain,
                        isEnabled: cookie.isEnabled
                    )
                }
            }
            .onDelete { state.profile.cookies.remove(atOffsets: $0) }

            Button {
                state.profile.cookies.append(PreloadCookie(name: "session", value: "demo"))
            } label: {
                Label("Add Cookie", systemImage: "plus.circle")
            }
        } header: {
            Text("Cookies")
        }
    }

    @ViewBuilder
    private var windowItemsSection: some View {
        Section {
            ForEach(state.profile.windowItems) { item in
                NavigationLink {
                    WindowInjectionEditorView(item: binding(forWindowItemID: item.id))
                } label: {
                    PreloadEditableRow(
                        title: item.name.isEmpty ? "Window Item" : "window.\(item.name)",
                        subtitle: item.kind.title,
                        isEnabled: item.isEnabled
                    )
                }
            }
            .onDelete { state.profile.windowItems.remove(atOffsets: $0) }

            Button {
                state.profile.windowItems.append(WindowInjectionItem(name: "appVersion", value: "1.0.0"))
            } label: {
                Label("Add Window Item", systemImage: "plus.circle")
            }
        } header: {
            Text("Window")
        }
    }

    @ViewBuilder
    private var bridgeSection: some View {
        Section {
            Toggle("Capture window.postMessage", isOn: $state.profile.capturesWindowPostMessage)

            ForEach(state.profile.bridgeChannels) { channel in
                NavigationLink {
                    BridgeChannelEditorView(channel: binding(forBridgeChannelID: channel.id))
                } label: {
                    PreloadEditableRow(
                        title: channel.name.isEmpty ? "Channel" : channel.name,
                        subtitle: "\(channel.responseRules.filter(\.isEnabled).count) rules",
                        isEnabled: channel.isEnabled
                    )
                }
            }
            .onDelete { state.profile.bridgeChannels.remove(atOffsets: $0) }

            Button {
                state.profile.bridgeChannels.append(
                    BridgeChannel(
                        name: "request",
                        responseRules: [BridgeResponseRule(name: "Log only", matcher: .any)]
                    )
                )
            } label: {
                Label("Add Channel", systemImage: "plus.circle")
            }
        } header: {
            Text("Bridge Mock")
        } footer: {
            Text("Channels become window.webkit.messageHandlers.<name>. Responses can post back to the page.")
        }
    }

    @ViewBuilder
    private var customScriptsSection: some View {
        Section {
            ForEach(state.profile.customScripts) { script in
                NavigationLink {
                    CustomPreloadScriptEditorView(script: binding(forCustomScriptID: script.id))
                } label: {
                    PreloadEditableRow(
                        title: script.name,
                        subtitle: script.forMainFrameOnly ? "Main frame" : "All frames",
                        isEnabled: script.isEnabled
                    )
                }
            }
            .onDelete { state.profile.customScripts.remove(atOffsets: $0) }

            Button {
                state.profile.customScripts.append(PreloadCustomScript())
            } label: {
                Label("Add Custom Script", systemImage: "plus.circle")
            }
        } header: {
            Text("Advanced")
        }
    }

    private func loadIfNeeded() {
        state.loadIfNeeded()
    }

    private func deleteSavedProfiles(at offsets: IndexSet) {
        state.deleteSavedProfiles(at: offsets)
    }

    private func savedSetupSummary(for profile: WebViewPreloadProfile) -> String? {
        let count =
            profile.cookies.count + profile.windowItems.count
            + profile.bridgeChannels.count + profile.customScripts.count
            + (profile.capturesWindowPostMessage ? 1 : 0)
        guard count > 0 else { return nil }
        return count == 1 ? "1 item" : "\(count) items"
    }

    private func binding(forCookieID id: UUID) -> Binding<PreloadCookie> {
        Binding {
            state.profile.cookies.first { $0.id == id } ?? PreloadCookie(id: id, isEnabled: false)
        } set: { updated in
            guard let index = state.profile.cookies.firstIndex(where: { $0.id == id }) else { return }
            state.profile.cookies[index] = updated
        }
    }

    private func binding(forWindowItemID id: UUID) -> Binding<WindowInjectionItem> {
        Binding {
            state.profile.windowItems.first { $0.id == id } ?? WindowInjectionItem(id: id, isEnabled: false)
        } set: { updated in
            guard let index = state.profile.windowItems.firstIndex(where: { $0.id == id }) else { return }
            state.profile.windowItems[index] = updated
        }
    }

    private func binding(forBridgeChannelID id: UUID) -> Binding<BridgeChannel> {
        Binding {
            state.profile.bridgeChannels.first { $0.id == id } ?? BridgeChannel(id: id, isEnabled: false)
        } set: { updated in
            guard let index = state.profile.bridgeChannels.firstIndex(where: { $0.id == id }) else { return }
            state.profile.bridgeChannels[index] = updated
        }
    }

    private func binding(forCustomScriptID id: UUID) -> Binding<PreloadCustomScript> {
        Binding {
            state.profile.customScripts.first { $0.id == id } ?? PreloadCustomScript(id: id, isEnabled: false)
        } set: { updated in
            guard let index = state.profile.customScripts.firstIndex(where: { $0.id == id }) else { return }
            state.profile.customScripts[index] = updated
        }
    }
}

// MARK: - Shared Rows

private struct PreloadEditableRow: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isEnabled ? Color.blue : Color.gray)
        }
    }
}

// MARK: - Cookie Editor

private struct PreloadCookieEditorView: View {
    @Binding var cookie: PreloadCookie

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $cookie.isEnabled)
                TextField("Name", text: $cookie.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Value", text: $cookie.value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Picker("Domain", selection: $cookie.domainMode) {
                    ForEach(PreloadCookieDomainMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if cookie.domainMode == .custom {
                    TextField("Domain", text: $cookie.customDomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                TextField("Path", text: $cookie.path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Picker("Expires", selection: $cookie.expires) {
                    ForEach(PreloadCookieExpiration.allCases, id: \.self) { expiration in
                        Text(expiration.title).tag(expiration)
                    }
                }
                Picker("SameSite", selection: $cookie.sameSite) {
                    ForEach(PreloadCookieSameSite.allCases, id: \.self) { sameSite in
                        Text(sameSite.title).tag(sameSite)
                    }
                }
                Toggle("Secure", isOn: $cookie.isSecure)
                Toggle("HTTP Only", isOn: $cookie.isHTTPOnly)
            }
        }
        .navigationTitle(Text(verbatim: "Cookie"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Window Editor

private struct WindowInjectionEditorView: View {
    @Binding var item: WindowInjectionItem

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $item.isEnabled)
                TextField("Name", text: $item.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Type", selection: $item.kind) {
                    ForEach(WindowInjectionKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                if item.kind != .functionBody {
                    Picker("Value", selection: $item.valueKind) {
                        ForEach(PreloadValueKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
            }

            Section {
                TextEditor(text: $item.value)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
            } header: {
                Text(item.kind == .functionBody ? "Function Body" : "Value")
            } footer: {
                Text("Use dotted names like app.bridge.getToken to create nested window values.")
            }
        }
        .navigationTitle(Text(verbatim: "Window Item"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bridge Editors

private struct BridgeChannelEditorView: View {
    @Binding var channel: BridgeChannel

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $channel.isEnabled)
                TextField("Channel name", text: $channel.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !BridgeChannelNameValidator.isValid(channel.name)
                    || BridgeChannelNameValidator.reservedNames.contains(channel.name)
                {
                    Label(
                        "Use a JavaScript identifier that is not reserved.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(channel.responseRules) { rule in
                    NavigationLink {
                        BridgeRuleEditorView(rule: binding(forRuleID: rule.id))
                    } label: {
                        PreloadEditableRow(
                            title: rule.name,
                            subtitle: rule.response.target.title,
                            isEnabled: rule.isEnabled
                        )
                    }
                }
                .onDelete { channel.responseRules.remove(atOffsets: $0) }

                Button {
                    channel.responseRules.append(
                        BridgeResponseRule(
                            name: "Reply",
                            matcher: .any,
                            response: BridgeResponse(target: .postMessage)
                        )
                    )
                } label: {
                    Label("Add Response Rule", systemImage: "plus.circle")
                }
            } header: {
                Text("Response Rules")
            }
        }
        .navigationTitle(Text(verbatim: "Channel"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(forRuleID id: UUID) -> Binding<BridgeResponseRule> {
        Binding {
            channel.responseRules.first { $0.id == id } ?? BridgeResponseRule(id: id, isEnabled: false)
        } set: { updated in
            guard let index = channel.responseRules.firstIndex(where: { $0.id == id }) else { return }
            channel.responseRules[index] = updated
        }
    }
}

private struct BridgeRuleEditorView: View {
    @Binding var rule: BridgeResponseRule

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $rule.isEnabled)
                TextField("Name", text: $rule.name)
                BridgeMatcherEditor(matcher: $rule.matcher)
                Picker("Respond with", selection: $rule.response.target) {
                    ForEach(BridgeResponseTarget.allCases, id: \.self) { target in
                        Text(target.title).tag(target)
                    }
                }
                Picker("Delay", selection: $rule.delayMilliseconds) {
                    Text("Instant").tag(0)
                    Text("300ms").tag(300)
                    Text("1s").tag(1_000)
                }
            }

            Section {
                TextEditor(text: $rule.response.bodyTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
            } header: {
                Text("Response JSON")
            } footer: {
                Text("Available values: {{message}}, {{message.id}}, {{message.type}}, {{message.payload.token}}")
            }

            responseTargetSection
        }
        .navigationTitle(Text(verbatim: "Response Rule"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var responseTargetSection: some View {
        switch rule.response.target {
        case .postMessage:
            EmptyView()

        case .customEvent:
            Section {
                TextField("Event name", text: $rule.response.eventName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

        case .callback:
            Section {
                TextField("Callback name", text: $rule.response.callbackName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Use a dotted function path like app.onNativeResponse.")
            }

        case .customJavaScript:
            Section {
                TextEditor(text: $rule.response.customJavaScript)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140)
            } header: {
                Text("Custom JavaScript")
            } footer: {
                Text("Use {{message}}, {{response}}, and {{channel}} placeholders.")
            }
        }
    }
}

private struct BridgeMatcherEditor: View {
    @Binding var matcher: BridgeMatcher

    @State private var mode: BridgeMatcherMode = .any
    @State private var value: String = ""
    @State private var path: String = "type"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Match", selection: $mode) {
                ForEach(BridgeMatcherMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if mode == .typeEquals {
                TextField("type", text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else if mode == .jsonPathEquals {
                TextField("JSON path", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Value", text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .onAppear(perform: load)
        .onChange(of: matcher) { _, _ in load() }
        .onChange(of: mode) { _, _ in save() }
        .onChange(of: path) { _, _ in save() }
        .onChange(of: value) { _, _ in save() }
    }

    private func load() {
        switch matcher {
        case .any:
            mode = .any
            path = "type"
            value = ""
        case .typeEquals(let expected):
            mode = .typeEquals
            path = "type"
            value = expected
        case .jsonPathEquals(let currentPath, let expected):
            mode = .jsonPathEquals
            path = currentPath
            value = expected
        }
    }

    private func save() {
        switch mode {
        case .any:
            matcher = .any
        case .typeEquals:
            matcher = .typeEquals(value)
        case .jsonPathEquals:
            matcher = .jsonPathEquals(path: path, value: value)
        }
    }
}

private enum BridgeMatcherMode: CaseIterable {
    case any
    case typeEquals
    case jsonPathEquals

    var title: String {
        switch self {
        case .any: "Any message"
        case .typeEquals: "type equals"
        case .jsonPathEquals: "JSON path equals"
        }
    }
}

// MARK: - Custom Script Editor

private struct CustomPreloadScriptEditorView: View {
    @Binding var script: PreloadCustomScript

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $script.isEnabled)
                TextField("Name", text: $script.name)
                Toggle("Main frame only", isOn: $script.forMainFrameOnly)
            }

            Section {
                TextEditor(text: $script.source)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 240)
            } header: {
                Text("Source")
            }
        }
        .navigationTitle(Text(verbatim: "Custom Script"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
