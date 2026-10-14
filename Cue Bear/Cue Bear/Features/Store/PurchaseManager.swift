//
//  PurchaseManager.swift — Cue Bear
//  Handles in-app purchases and subscription management
//  No backend required - uses StoreKit 2 for validation
//
//  v1.2.1: loads the product so the paywall can show the App Store's localized price,
//  and reports "pending" purchases (Ask to Buy, delayed payment) instead of treating
//  them as cancelled.
//

import Foundation
import StoreKit

@MainActor
class PurchaseManager: ObservableObject {
    // MARK: - Published Properties

    @Published var hasLifetimeAccess = false
    @Published var hasActiveSubscription = false
    @Published var isPurchasing = false
    /// The lifetime product from the App Store, for its localized price. nil until loaded.
    @Published private(set) var lifetimeProduct: Product?
    /// True after a purchase that is waiting for approval (Ask to Buy, SCA, etc.).
    @Published private(set) var purchasePending = false

    // MARK: - Product IDs

    // Original one-time purchase. (The ID mentions $4.99, but the price shown to users
    // always comes from the App Store, so changing the price later is safe.)
    let lifetimePurchaseID = "com.cuebear.onetime_4_99"

    // Future subscription product IDs
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

    /// Loads the lifetime product so the paywall can show its localized price.
    func loadProducts() async {
        guard lifetimeProduct == nil else { return }
        do {
            lifetimeProduct = try await Product.products(for: [lifetimePurchaseID]).first
        } catch {
            debugPrint("💰 PurchaseManager: Could not load products: \(error)")
        }
    }

    /// Check purchase status on app launch
    func checkPurchaseStatus() async {
        // First check cached status for quick UI update
        if UserDefaults.standard.bool(forKey: lifetimeAccessKey) {
            hasLifetimeAccess = true
        }

        // Then verify with Apple's servers
        await verifyPurchases()
    }

    /// Verify all purchases with Apple's servers
    private func verifyPurchases() async {
        var foundLifetimePurchase = false
        var foundActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                debugPrint("💰 PurchaseManager: Unverified transaction found")
                continue
            }

            if transaction.productID == lifetimePurchaseID {
                foundLifetimePurchase = true
                UserDefaults.standard.set(transaction.originalID, forKey: originalTransactionIDKey)
                UserDefaults.standard.set(true, forKey: lifetimeAccessKey)
                await transaction.finish()
            }

            if transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID {
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        foundActiveSubscription = true
                    }
                } else {
                    // No expiration date means it's a non-renewing purchase
                    foundActiveSubscription = true
                }
                await transaction.finish()
            }
        }

        hasLifetimeAccess = foundLifetimePurchase
        hasActiveSubscription = foundActiveSubscription
        if foundLifetimePurchase || foundActiveSubscription {
            purchasePending = false
        }
    }

    /// Observe transaction updates in real-time (also delivers approved Ask to Buy purchases)
    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.productID == lifetimePurchaseID {
                hasLifetimeAccess = true
                purchasePending = false
                UserDefaults.standard.set(transaction.originalID, forKey: originalTransactionIDKey)
                UserDefaults.standard.set(true, forKey: lifetimeAccessKey)
            }

            await transaction.finish()
        }
    }

    /// Check if user should see paywall (for future subscription)
    func shouldShowPaywall() -> Bool {
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

    /// Purchase a product. Returns true when access was granted now.
    /// Returns false when cancelled or pending; check `purchasePending` to tell them apart.
    func purchase(productID: String) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        let product: Product
        if productID == lifetimePurchaseID, let cached = lifetimeProduct {
            product = cached
        } else {
            guard let fetched = try await Product.products(for: [productID]).first else {
                throw PurchaseError.productNotFound
            }
            product = fetched
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                if transaction.productID == lifetimePurchaseID {
                    hasLifetimeAccess = true
                    purchasePending = false
                    UserDefaults.standard.set(transaction.originalID, forKey: originalTransactionIDKey)
                    UserDefaults.standard.set(true, forKey: lifetimeAccessKey)
                }
                await transaction.finish()
                return true

            case .unverified(_, let error):
                debugPrint("💰 PurchaseManager: Purchase verification failed: \(error)")
                throw PurchaseError.verificationFailed
            }

        case .userCancelled:
            return false

        case .pending:
            purchasePending = true
            return false

        @unknown default:
            return false
        }
    }

    /// Restore purchases
    func restorePurchases() async throws {
        try await AppStore.sync()
        await verifyPurchases()
    }
}

// MARK: - Supporting Types

enum LicenseType {
    case lifetimeAccess      // Bought original lifetime purchase
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
