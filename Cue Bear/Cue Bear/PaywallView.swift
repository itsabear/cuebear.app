//
//  PaywallView.swift — Cue Bear
//  Simple paywall for $4.99 purchase
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

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
                                .font(.system(size: 32, weight: .bold))

                            Text("Full-featured MIDI controller for your set list")
                                .font(.system(size: 17))
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
                            Text("$4.99")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.primary)

                            Text("One-time purchase")
                                .font(.system(size: 15))
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
                                        .font(.system(size: 18, weight: .semibold))
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
                                    .font(.system(size: 15))
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isPurchasing || isRestoring)

                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
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
        .onChange(of: purchaseManager.hasLifetimeAccess) { _, hasAccess in
            if hasAccess {
                // Purchase successful - dismiss paywall
                dismiss()
            }
        }
    }

    private func purchase() {
        Task {
            isPurchasing = true
            errorMessage = nil

            do {
                let success = try await purchaseManager.purchase(
                    productID: "com.cuebear.onetime_4_99"
                )

                if success {
                    // Purchase successful
                    debugPrint("💰 Purchase successful!")
                } else {
                    errorMessage = "Purchase was cancelled"
                }
            } catch {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                debugPrint("💰 Purchase error: \(error)")
            }

            isPurchasing = false
        }
    }

    private func restore() {
        Task {
            isRestoring = true
            errorMessage = nil

            do {
                try await purchaseManager.restorePurchases()
                debugPrint("💰 Purchases restored!")
            } catch {
                errorMessage = "Restore failed: \(error.localizedDescription)"
                debugPrint("💰 Restore error: \(error)")
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
