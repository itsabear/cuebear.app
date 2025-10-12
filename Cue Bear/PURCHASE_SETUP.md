# Cue Bear Purchase System Setup

## Overview

The Cue Bear app now has a **serverless purchase tracking system** that:
- ✅ Tracks original $4.99 purchasers
- ✅ Grants them lifetime access
- ✅ Ready for future subscription transition
- ✅ No backend/database required (uses Apple's StoreKit 2)

## How It Works

### For Current $4.99 Buyers
1. User purchases app for $4.99 (one-time)
2. StoreKit 2 stores `originalTransactionID`
3. App checks purchases on every launch
4. Original buyers get `hasLifetimeAccess = true`
5. They have full access forever

### For Future Subscription
When you add subscriptions:
1. Check `purchaseManager.hasLifetimeAccess` first
2. If `true` → Skip paywall, grant full access
3. If `false` → Show subscription paywall
4. Original $4.99 buyers never see paywall

## App Store Connect Setup

### Current Setup (One-Time Purchase)

**Product ID**: `com.cuebear.onetime_4_99`

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select "Cue Bear" app
3. Go to "Features" → "In-App Purchases"
4. Click "+" to add new purchase
5. Select "Non-Consumable"
6. Fill in:
   - **Product ID**: `com.cuebear.onetime_4_99`
   - **Reference Name**: Cue Bear - One-Time Purchase
   - **Price**: $4.99 (Tier 5)
   - **Description**: Full access to Cue Bear MIDI controller
7. Submit for review

### Future Setup (Subscriptions)

When ready to add subscriptions:

**Monthly Subscription**
- **Product ID**: `com.cuebear.subscription_monthly`
- **Price**: $2.99/month
- **Type**: Auto-Renewable Subscription

**Yearly Subscription** (optional)
- **Product ID**: `com.cuebear.subscription_yearly`
- **Price**: $24.99/year (save 30%)
- **Type**: Auto-Renewable Subscription

## Code Implementation

### Check Purchase Status

```swift
// In any view
@EnvironmentObject var purchaseManager: PurchaseManager

var body: some View {
    if purchaseManager.hasLifetimeAccess {
        // Show full app - original $4.99 buyer
        FullAppView()
    } else if purchaseManager.hasActiveSubscription {
        // Show full app - active subscriber
        FullAppView()
    } else {
        // Show paywall or limited features
        PaywallView()
    }
}
```

### Purchase Flow (Future)

```swift
Button("Subscribe Monthly - $2.99") {
    Task {
        let success = try await purchaseManager.purchase(
            productID: "com.cuebear.subscription_monthly"
        )
        if success {
            // Subscription successful
        }
    }
}
```

### Restore Purchases

```swift
Button("Restore Purchases") {
    Task {
        try await purchaseManager.restorePurchases()
    }
}
```

## Testing

### Test Purchases in Sandbox

1. **Create Sandbox Tester**:
   - App Store Connect → Users and Access → Sandbox Testers
   - Create test Apple ID

2. **Sign Out of Real Apple ID**:
   - Settings → App Store → Sign Out

3. **Run App**:
   - Xcode → Run on device
   - When purchase prompt appears, sign in with sandbox tester
   - Purchase will be free in sandbox

4. **Test Scenarios**:
   - ✅ First-time purchase ($4.99)
   - ✅ Restore purchases
   - ✅ Delete app and reinstall (should restore automatically)
   - ✅ Check `PurchaseStatusView` to see license type

### View Purchase Status

The app includes `PurchaseStatusView` for debugging:
- Shows: Lifetime Access, Active Subscription, or Free
- Displays original transaction ID
- Has "Restore Purchases" button
- Explains lifetime access policy

## Migration Strategy

### Option 1: All Early Buyers Get Lifetime Access (Recommended)
```swift
// Already implemented!
// Anyone who bought $4.99 gets lifetime access automatically
if purchaseManager.hasLifetimeAccess {
    return .lifetimeAccess
}
```

### Option 2: Time-Limited Migration
```swift
func determineLicenseType() async -> LicenseType {
    for await result in Transaction.currentEntitlements {
        guard case .verified(let transaction) = result else { continue }

        if transaction.productID == "com.cuebear.onetime_4_99" {
            let cutoffDate = Date(timeIntervalSince1970: 1704067200) // Jan 1, 2024

            if transaction.purchaseDate < cutoffDate {
                return .lifetimeAccess  // Early buyers
            } else {
                return .oneYearFree     // Later buyers get 1 year free
            }
        }
    }
    return .needsSubscription
}
```

## Security

### Why No Backend Needed
- ✅ **Apple validates all purchases** - no fake purchases possible
- ✅ **StoreKit 2 uses cryptographic signatures** - transactions are verified
- ✅ **originalTransactionID** persists across devices via Apple ID
- ✅ **Automatic receipt validation** on every app launch
- ✅ **Syncs across all user's devices** automatically

### Data Stored Locally
- `hasLifetimePurchase` (UserDefaults) - for quick UI updates
- `originalPurchaseTransactionID` (UserDefaults) - for reference
- Both are re-verified with Apple on every launch

## FAQs

### Q: What if user gets new device?
**A**: StoreKit 2 automatically syncs purchases via Apple ID. No action needed.

### Q: What if user reinstalls app?
**A**: First launch calls `checkPurchaseStatus()` → Apple confirms purchase → Lifetime access restored.

### Q: Can purchases be faked?
**A**: No. StoreKit 2 uses cryptographic signatures. Only Apple-verified transactions are accepted.

### Q: Do I need a server?
**A**: No! Apple's servers handle everything. You can add a server later for:
- Cross-platform sync (iPad + iPhone)
- Customer support lookups
- Analytics

### Q: What about family sharing?
**A**: Enable "Family Sharing" in App Store Connect → Purchases work for whole family.

## Next Steps

1. **Set up product in App Store Connect**
   - Create `com.cuebear.onetime_4_99` product
   - Set price to $4.99
   - Submit for review

2. **Test in sandbox**
   - Use sandbox tester account
   - Verify purchase flow works
   - Test restore purchases

3. **Submit app for review**
   - Include in-app purchase in submission
   - Apple reviews purchase flow

4. **Launch!**
   - Users can now purchase
   - Lifetime access automatically tracked
   - Ready for future subscription transition

## Future: Adding Subscriptions

When ready to add subscriptions (no code changes needed!):

1. Create subscription products in App Store Connect
2. Update product IDs in `PurchaseManager` (already set up)
3. Create paywall UI
4. Original $4.99 buyers automatically skip paywall

That's it! The infrastructure is ready.

## Support

If users have issues:
1. Check `PurchaseStatusView` to see their license type
2. Try "Restore Purchases" button
3. Check they're signed into correct Apple ID
4. Contact Apple if transaction not showing

## Files

- `PurchaseManager.swift` - Core purchase logic
- `PurchaseStatusView.swift` - Debug/status view
- `CueBearApp.swift` - Checks purchases on launch

---

**Ready to track lifetime users and transition to subscriptions smoothly!** 🎉
