//
//  AboutView.swift
//  wina
//

import StoreKit
import SwiftUI
import SwiftUIBackports

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private var store = StoreManager.shared

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var removeAdsButtonTitle: String {
        if let price = store.product?.displayPrice {
            return "Remove Ads (\(price))"
        }
        return "Remove Ads"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App Icon + Name + Version + Creator
                VStack(spacing: 8) {
                    Image("walnut")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)

                    Text("Wallnut")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Kobbokkom")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Ad Removal Section
                VStack(spacing: 12) {
                    if store.isAdRemoved {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ads Removed")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .backport.glassEffect(in: .capsule)
                    } else {
                        GlassActionButton(removeAdsButtonTitle, icon: "sparkles", style: .primary) {
                            Task {
                                await store.purchaseAdRemoval()
                            }
                        }
                        .disabled(store.isLoading)
                        .overlay {
                            if store.isLoading {
                                ProgressView()
                                    .tint(.accentColor)
                            }
                        }

                        Button {
                            Task {
                                await store.restorePurchases()
                            }
                        } label: {
                            Text("Restore Purchases")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isLoading)
                    }

                    if let error = store.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AboutView()
}
