//
//  PaywallView.swift — Cue Bear
//  One-time purchase paywall
//
//  v1.2.1: shows the App Store's localized price (it was hardcoded to "$4.99"),
//  handles pending purchases, and no longer shows an error when the user cancels.
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    /// Localized price from the App Store; falls back to the US price while loading.
    private var priceText: String {
        purchaseManager.lifetimeProduct?.displayPrice ?? "$4.99"
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)

                        // App Icon/Logo
                        Image(systemName: "music.note.list")
                            .font(.cbIcon(.hero, .regular))
                            .foregroundStyle(CBColor.highlight)

                        // Title
                        VStack(spacing: 12) {
                            Text("Unlock Cue Bear")
                                .font(.cb(.heading, .bold))

                            Text("Full-featured MIDI controller for your set list")
                                .font(.cb(.body))
                                .foregroundStyle(CBColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        // Features
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(icon: "music.note.list", text: "Organize your set list")
                            FeatureRow(icon: "slider.horizontal.3", text: "Control your DAW with MIDI")
                            FeatureRow(icon: "laptopcomputer", text: "Connect via USB or WiFi")
                            FeatureRow(icon: "infinity", text: "One-time purchase, lifetime access")
                        }
                        .padding(.horizontal, 40)

                        // Price
                        VStack(spacing: 8) {
                            Text(priceText)
                                .font(.cb(.display, .bold))
                                .foregroundStyle(CBColor.textPrimary)

                            Text("One-time purchase")
                                .font(.cb(.body))
                                .foregroundStyle(CBColor.textSecondary)
                        }
                        .padding(.top, 20)

                        // Purchase Button
                        Button(action: {
                            purchase()
                        }) {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Text("Buy Cue Bear")
                                        .font(.cb(.large, .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
                        }
                        .disabled(isPurchasing || isRestoring)
                        .padding(.horizontal, 40)

                        // Restore Button
                        Button(action: {
                            restore()
                        }) {
                            HStack {
                                if isRestoring {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.8)
                                }
                                Text("Restore Purchases")
                                    .font(.cb(.body))
                                    .foregroundStyle(CBColor.highlight)
                            }
                        }
                        .disabled(isPurchasing || isRestoring)

                        // Status messages
                        if let info = infoMessage {
                            Text(info)
                                .font(.cb(.small))
                                .foregroundStyle(CBColor.textSecondary)
                                .padding(.horizontal, 40)
                                .multilineTextAlignment(.center)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.cb(.caption))
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                .padding(.horizontal, 40)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await purchaseManager.loadProducts()
        }
        .onChange(of: purchaseManager.hasLifetimeAccess) { _, hasAccess in
            if hasAccess {
                // Purchase successful (or approved later) - dismiss paywall
                dismiss()
            }
        }
    }

    private func purchase() {
        Task {
            isPurchasing = true
            errorMessage = nil
            infoMessage = nil

            do {
                let success = try await purchaseManager.purchase(
                    productID: purchaseManager.lifetimePurchaseID
                )

                if !success && purchaseManager.purchasePending {
                    infoMessage = "Waiting for approval. Cue Bear unlocks automatically once the purchase is approved."
                }
                // Cancelled by the user: no message, as in Apple's own apps.
            } catch {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }

            isPurchasing = false
        }
    }

    private func restore() {
        Task {
            isRestoring = true
            errorMessage = nil
            infoMessage = nil

            do {
                try await purchaseManager.restorePurchases()
                if !purchaseManager.hasLifetimeAccess && !purchaseManager.hasActiveSubscription {
                    infoMessage = "No previous purchase was found for this Apple ID."
                }
            } catch {
                errorMessage = "Restore failed: \(error.localizedDescription)"
            }

            isRestoring = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.cbIcon(.title, .regular))
                .foregroundStyle(CBColor.highlight)
                .frame(width: 32)

            Text(text)
                .font(.cb(.body))
                .foregroundStyle(CBColor.textPrimary)

            Spacer()
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(PurchaseManager.shared)
}
