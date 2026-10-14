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
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        // Title
                        VStack(spacing: 12) {
                            Text("Unlock Cue Bear")
                                .font(.custom("Sora-Bold", size: 32))

                            Text("Full-featured MIDI controller for your set list")
                                .font(.custom("Sora-Regular", size: 17))
                                .foregroundColor(.secondary)
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
                                .font(.custom("Sora-Bold", size: 48))
                                .foregroundColor(.primary)

                            Text("One-time purchase")
                                .font(.custom("Sora-Regular", size: 15))
                                .foregroundColor(.secondary)
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
                                        .font(.custom("Sora-Bold", size: 18))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                                    .font(.custom("Sora-Regular", size: 15))
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isPurchasing || isRestoring)

                        // Status messages
                        if let info = infoMessage {
                            Text(info)
                                .font(.custom("Sora-Regular", size: 13))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                                .multilineTextAlignment(.center)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.custom("Sora-Regular", size: 12))
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
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(PurchaseManager.shared)
}
