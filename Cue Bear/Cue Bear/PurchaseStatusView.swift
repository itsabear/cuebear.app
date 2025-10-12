//
//  PurchaseStatusView.swift — Cue Bear
//  Shows current purchase/subscription status (for testing/debugging)
//

import SwiftUI

struct PurchaseStatusView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var isRestoring = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("License Type")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(licenseTypeText)
                            .fontWeight(.semibold)
                            .foregroundColor(licenseTypeColor)
                    }

                    if purchaseManager.hasLifetimeAccess {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lifetime Access")
                                    .fontWeight(.semibold)
                                Text("Thank you for being an early supporter!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if purchaseManager.hasActiveSubscription {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Subscription")
                                    .fontWeight(.semibold)
                                Text("Subscription active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Purchase Status")
                }

                Section {
                    Button(action: {
                        Task {
                            isRestoring = true
                            try? await purchaseManager.restorePurchases()
                            isRestoring = false
                        }
                    }) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Restore Purchases")
                            Spacer()
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Restore previous purchases from your Apple ID")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Lifetime Access")
                            .font(.headline)

                        Text("If you purchased Cue Bear for $4.99, you have lifetime access to all features. When we introduce subscriptions in the future, you'll continue to have full access forever as a thank you for being an early supporter.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Information")
                }

                if let transactionID = UserDefaults.standard.object(forKey: "originalPurchaseTransactionID") {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transaction ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(transactionID)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Debug Info")
                    }
                }
            }
            .navigationTitle("Purchase Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var licenseTypeText: String {
        switch purchaseManager.getLicenseType() {
        case .lifetimeAccess:
            return "Lifetime"
        case .activeSubscriber:
            return "Subscriber"
        case .needsToPurchase:
            return "Free"
        }
    }

    private var licenseTypeColor: Color {
        switch purchaseManager.getLicenseType() {
        case .lifetimeAccess:
            return .green
        case .activeSubscriber:
            return .blue
        case .needsToPurchase:
            return .orange
        }
    }
}

#Preview {
    PurchaseStatusView()
        .environmentObject(PurchaseManager.shared)
}
