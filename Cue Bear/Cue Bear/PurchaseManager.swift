//
//  PurchaseManager.swift — Cue Bear
//  Handles in-app purchases and subscription management
//  No backend required - uses StoreKit 2 for validation
//

import Foundation
import StoreKit

@MainActor
class PurchaseManager: ObservableObject {
    // MARK: - Published Properties

    @Published var hasLifetimeAccess = false
    @Published var hasActiveSubscription = false
    @Published var isPurchasing = false

    // MARK: - Product IDs

    // Original one-time purchase ($4.99)
    private let lifetimePurchaseID = "com.cuebear.onetime_4_99"

    // Future subscription product IDs (when you add subscriptions)
    private let monthlySubscriptionID = "com.cuebear.subscription_monthly"
    private let yearlySubscriptionID = "com.cuebear.subscription_yearly"

    // MARK: - User Defaults Keys

    private let lifetimeAccessKey = "hasLifetimePurchase"
    private let originalTransactionIDKey = "originalPurchaseTransactionID"

    // MARK: - Singleton

    static let shared = PurchaseManager()

    private init() {
        // Start observing transactions
        Task {
            await observeTransactions()
        }
    }

    // MARK: - Public Methods

    /// Check purchase status on app launch
    func checkPurchaseStatus() async {
        debugPrint("💰 PurchaseManager: Checking purchase status...")

        // First check cached status for quick UI update
        if UserDefaults.standard.bool(forKey: lifetimeAccessKey) {
            hasLifetimeAccess = true
            debugPrint("💰 PurchaseManager: ✅ Cached lifetime access found")
        }

        // Then verify with Apple's servers
        await verifyPurchases()
    }

    /// Verify all purchases with Apple's servers
    private func verifyPurchases() async {
        debugPrint("💰 PurchaseManager: Verifying purchases with Apple...")

        var foundLifetimePurchase = false
        var foundActiveSubscription = false

        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                debugPrint("💰 PurchaseManager: ⚠️ Unverified transaction found")
                continue
            }

            debugPrint("💰 PurchaseManager: Found transaction - Product: \(transaction.productID)")

            // Check for original $4.99 lifetime purchase
            if transaction.productID == lifetimePurchaseID {
                foundLifetimePurchase = true

                // Store the original transaction ID
                let originalID = transaction.originalID
                UserDefaults.standard.set(originalID, forKey: originalTransactionIDKey)
                UserDefaults.standard.set(true, forKey: lifetimeAccessKey)

                debugPrint("💰 PurchaseManager: ✅ Lifetime purchase verified!")
                debugPrint("💰 PurchaseManager: Original Transaction ID: \(originalID)")
                debugPrint("💰 PurchaseManager: Purchase Date: \(transaction.purchaseDate)")

                // Finish the transaction
                await transaction.finish()
            }

            // Check for active subscription (future)
            if transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID {
                // Check if subscription is still active
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        foundActiveSubscription = true
                        debugPrint("💰 PurchaseManager: ✅ Active subscription found (expires: \(expirationDate))")
                    } else {
                        debugPrint("💰 PurchaseManager: ⚠️ Subscription expired on: \(expirationDate)")
                    }
                } else {
                    // No expiration date means it's a non-renewing purchase
                    foundActiveSubscription = true
                    debugPrint("💰 PurchaseManager: ✅ Non-renewing subscription found")
                }

                await transaction.finish()
            }
        }

        // Update published properties
        hasLifetimeAccess = foundLifetimePurchase
        hasActiveSubscription = foundActiveSubscription

        if foundLifetimePurchase {
            debugPrint("💰 PurchaseManager: ✅ User has LIFETIME ACCESS (original $4.99 purchase)")
        } else if foundActiveSubscription {
            debugPrint("💰 PurchaseManager: ✅ User has ACTIVE SUBSCRIPTION")
        } else {
            debugPrint("💰 PurchaseManager: ⚠️ No active purchases found")
        }
    }

    /// Observe transaction updates in real-time
    private func observeTransactions() async {
        debugPrint("💰 PurchaseManager: Starting transaction observer...")

        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else {
                continue
            }

            debugPrint("💰 PurchaseManager: New transaction received: \(transaction.productID)")

            // Handle the new transaction
            if transaction.productID == lifetimePurchaseID {
                hasLifetimeAccess = true
                UserDefaults.standard.set(transaction.originalID, forKey: originalTransactionIDKey)
                UserDefaults.standard.set(true, forKey: lifetimeAccessKey)
                debugPrint("💰 PurchaseManager: ✅ Lifetime access granted!")
            }

            await transaction.finish()
        }
    }

    /// Check if user should see paywall (for future subscription)
    func shouldShowPaywall() -> Bool {
        // If user has lifetime access OR active subscription, don't show paywall
        return !hasLifetimeAccess && !hasActiveSubscription
    }

    /// Get user's license type
    func getLicenseType() -> LicenseType {
        if hasLifetimeAccess {
            return .lifetimeAccess
        } else if hasActiveSubscription {
            return .activeSubscriber
        } else {
            return .needsToPurchase
        }
    }

    /// Purchase product (for future implementation)
    func purchase(productID: String) async throws -> Bool {
        debugPrint("💰 PurchaseManager: Attempting to purchase: \(productID)")

        isPurchasing = true
        defer { isPurchasing = false }

        // Fetch products from App Store
        let products = try await Product.products(for: [productID])

        guard let product = products.first else {
            debugPrint("💰 PurchaseManager: ❌ Product not found: \(productID)")
            throw PurchaseError.productNotFound
        }

        debugPrint("💰 PurchaseManager: Product found: \(product.displayName) - \(product.displayPrice)")

        // Attempt purchase
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                debugPrint("💰 PurchaseManager: ✅ Purchase successful!")

                // Update entitlements
                if transaction.productID == lifetimePurchaseID {
                    hasLifetimeAccess = true
                    UserDefaults.standard.set(transaction.originalID, forKey: originalTransactionIDKey)
                    UserDefaults.standard.set(true, forKey: lifetimeAccessKey)
                }

                await transaction.finish()
                return true

            case .unverified(_, let error):
                debugPrint("💰 PurchaseManager: ❌ Purchase verification failed: \(error)")
                throw PurchaseError.verificationFailed
            }

        case .userCancelled:
            debugPrint("💰 PurchaseManager: User cancelled purchase")
            return false

        case .pending:
            debugPrint("💰 PurchaseManager: Purchase pending approval")
            return false

        @unknown default:
            debugPrint("💰 PurchaseManager: Unknown purchase result")
            return false
        }
    }

    /// Restore purchases
    func restorePurchases() async throws {
        debugPrint("💰 PurchaseManager: Restoring purchases...")

        try await AppStore.sync()
        await verifyPurchases()

        debugPrint("💰 PurchaseManager: ✅ Purchases restored")
    }
}

// MARK: - Supporting Types

enum LicenseType {
    case lifetimeAccess      // Bought original $4.99
    case activeSubscriber    // Has active subscription
    case needsToPurchase     // No purchase/subscription
}

enum PurchaseError: Error, LocalizedError {
    case productNotFound
    case verificationFailed
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found in App Store"
        case .verificationFailed:
            return "Purchase verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
