//
//  ContentView+URLInput.swift
//  wina
//
//  URL input view components for ContentView.
//

import GoogleMobileAds
import SwiftUI
import SwiftUIBackports

// MARK: - URL Input Views

extension ContentView {
    var urlInputView: some View {
        GeometryReader { geometry in
            // Background tap to dismiss keyboard and dropdown
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    textFieldFocused = false
                    showDropdown = false
                }

            // Banner ad at bottom (only for non-premium users)
            if !StoreManager.shared.isAdRemoved {
                let adSize = currentOrientationAnchoredAdaptiveBanner(width: geometry.size.width)
                VStack {
                    Spacer()
                    BannerAdView(adUnitId: AdManager.bannerAdUnitId)
                        .frame(width: adSize.size.width, height: adSize.size.height)
                }
            }

            VStack(spacing: 16) {
                // Walnut logo
                Image("walnut")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.bottom, -12)

                // URL parts chips - FlowLayout for wrapping
                FlowLayout(spacing: 8, alignment: .center) {
                    ForEach(urlParts, id: \.self) { part in
                        ChipButton(label: part) {
                            urlText += part
                        }
                    }
                }
                .frame(width: inputWidth)

                // WebView Type Toggle
                Picker("WebView Type", selection: $useSafariWebView) {
                    Text("WKWebView")
                        .tag(false)
                    Text("SafariVC")
                        .tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: inputWidth)

                // URL Input
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: urlValidationState.iconName)
                            .foregroundStyle(urlValidationState.iconColor)
                            .font(.system(size: 16))
                            .contentTransition(.symbolEffect(.replace))

                        TextField("Enter URL", text: $urlText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .font(.system(size: 16))
                            .focused($textFieldFocused)
                            .onSubmit {
                                if urlValidationState == .valid {
                                    textFieldFocused = false
                                    showDropdown = false
                                    submitURL()
                                }
                            }
                            .onChange(of: urlText) { _, _ in
                                // Debounced URL validation
                                validationTask?.cancel()
                                validationTask = Task {
                                    try? await Task.sleep(for: .milliseconds(150))
                                    guard !Task.isCancelled else { return }
                                    validateURL()
                                }
                            }

                        Button {
                            urlText = ""
                            textFieldFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(urlText.isEmpty ? 0 : 1)
                        .disabled(urlText.isEmpty)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(width: urlValidationState == .valid ? inputWidth - 60 : inputWidth)
                    .contentShape(Capsule())
                    .onTapGesture {
                        textFieldFocused = true
                    }
                    .backport.glassEffect(in: .capsule)

                    if urlValidationState == .valid {
                        Button {
                            textFieldFocused = false
                            showDropdown = false
                            submitURL()
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 48, height: 48)
                                .contentShape(Circle())
                                .backport.glassEffect(in: .circle)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.animation(.easeOut(duration: 0.15)))
                    }
                }
                .animation(.easeOut(duration: 0.25), value: urlValidationState)
                .overlay(alignment: .bottom) {
                    // Quick options (lower layer)
                    quickOptionsOverlay
                        .alignmentGuide(.bottom) { $0[.top] }
                        .animation(.easeOut(duration: 0.15), value: useSafariWebView)
                }
                .overlay(alignment: .bottom) {
                    // Dropdown (higher layer, overlays quick options)
                    dropdownOverlay
                        .alignmentGuide(.bottom) { $0[.top] }
                }
                .zIndex(1)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.32)
            .onChange(of: textFieldFocused) { _, newValue in
                withAnimation(.easeOut(duration: 0.15)) {
                    showDropdown = newValue && !filteredURLs.isEmpty
                }
            }
            .onChange(of: filteredURLs) { _, newValue in
                if textFieldFocused {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showDropdown = !newValue.isEmpty
                    }
                }
            }
        }
    }

    @ViewBuilder
    var dropdownOverlay: some View {
        if showDropdown && !filteredURLs.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(filteredURLs.enumerated()), id: \.element) { index, url in
                        dropdownRow(url: url, isLast: index == filteredURLs.count - 1)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: inputWidth, height: min(CGFloat(filteredURLs.count) * 40, 160))
            .backport.glassEffect(in: .rect(cornerRadius: 16))
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    func dropdownRow(url: String, isLast: Bool) -> some View {
        Button {
            urlText = url
            textFieldFocused = false
            showDropdown = false
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text(url)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            UIPasteboard.general.string = url
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .overlay(alignment: .trailing) {
            Button {
                removeURL(url)
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    var quickOptionsOverlay: some View {
        if !useSafariWebView {
            VStack(spacing: 8) {
                ToggleChipButton(isOn: $cleanStart, label: "Start with fresh data")
                ToggleChipButton(isOn: $privateBrowsing, label: "Browse in private session")
            }
            .frame(width: inputWidth)
            .padding(.top, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    var topBar: some View {
        HStack {
            HStack(spacing: 12) {
                if showWebView {
                    BackButton {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showWebView = false
                        }
                    }
                } else {
                    ThemeToggleButton()
                    BookmarkButton(showBookmarks: $showBookmarks, hasBookmarks: !urlStorage.bookmarks.isEmpty)
                    AboutButton(showAbout: $showAbout)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                InfoSheetButton(showInfo: $showInfo)
                SettingsButton(showSettings: $showSettings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
