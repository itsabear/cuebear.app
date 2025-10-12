# Complete Step-by-Step Guide: Setting Up Cue Bear Purchases

## Overview
This guide will walk you through setting up in-app purchases for Cue Bear, from start to finish. I'll assume you know nothing and explain every single step.

---

## Part 1: Create a Paid App Agreement with Apple

Before you can sell anything, you need to sign Apple's agreement.

### Step 1.1: Go to App Store Connect
1. Open your web browser
2. Go to: https://appstoreconnect.apple.com
3. Sign in with your Apple ID (the one you use for your developer account)

### Step 1.2: Set Up Paid Apps Agreement
1. Click **"Agreements, Tax, and Banking"** in the top menu
2. Look for **"Paid Applications"** section
3. If it says **"Set Up"** or **"Request"**:
   - Click **"Request"** or **"Set Up"**
   - Read the agreement (it's long, but you have to)
   - Click **"Agree"** at the bottom
4. If it says **"Active"** - you're good! Skip to Part 2

### Step 1.3: Add Banking Information (REQUIRED)
Apple needs to know where to send your money!

1. Still in "Agreements, Tax, and Banking"
2. Under **"Paid Applications"**, click **"Set Up"** next to **"Banking"**
3. Click **"Add Bank Account"**
4. Fill in:
   - **Account Holder Name**: Your name or company name
   - **Bank Name**: Your bank's name
   - **Account Number**: Your bank account number
   - **Routing Number**: Your bank's routing number (call your bank if you don't know)
   - **Account Type**: Usually "Checking"
5. Click **"Save"**

### Step 1.4: Add Tax Information (REQUIRED)
1. Still in "Agreements, Tax, and Banking"
2. Under **"Paid Applications"**, click **"Set Up"** next to **"Tax Forms"**
3. Select your country
4. Fill in the tax form (usually W-9 if you're in the US)
5. Click **"Submit"**

**⏳ WAIT**: Apple takes 1-3 business days to review your banking/tax info. You can't sell anything until this is approved.

---

## Part 2: Create Your App in App Store Connect

If you haven't created your app listing yet:

### Step 2.1: Create New App
1. Go to https://appstoreconnect.apple.com
2. Click **"My Apps"**
3. Click the **"+"** button (top left)
4. Select **"New App"**

### Step 2.2: Fill in App Information
1. **Platforms**: Select **"iOS"** (and **"iPadOS"** if shown)
2. **Name**: `Cue Bear`
3. **Primary Language**: English (or your language)
4. **Bundle ID**: Select your app's bundle ID from dropdown
   - Should be something like: `com.yourname.cuebear`
5. **SKU**: Can be anything unique, like: `cuebear-001`
6. **User Access**: Select **"Full Access"**
7. Click **"Create"**

---

## Part 3: Create the $4.99 In-App Purchase

Now we create the thing people will buy!

### Step 3.1: Go to In-App Purchases
1. In App Store Connect, open your **"Cue Bear"** app
2. On the left sidebar, click **"Features"**
3. Click **"In-App Purchases"**
4. Click the **"+"** button to add a new purchase

### Step 3.2: Choose Purchase Type
1. Select **"Non-Consumable"**
   - This means: one-time purchase, never expires, restores on all devices
2. Click **"Next"**

### Step 3.3: Fill in Purchase Details

**Reference Name** (only you see this):
```
Cue Bear - One-Time Purchase
```

**Product ID** (MUST match your code exactly):
```
com.cuebear.onetime_4_99
```
⚠️ **CRITICAL**: This MUST be exactly: `com.cuebear.onetime_4_99` (no spaces, no typos!)

**Review Notes** (optional, leave blank for now)

Click **"Save"**

### Step 3.4: Add Localization (What users see)
1. Under **"App Store Localization"**, click **"+"**
2. Select **"English (U.S.)"**
3. Fill in:

   **Display Name**:
   ```
   Cue Bear Full Access
   ```

   **Description**:
   ```
   Unlock full access to Cue Bear, the MIDI controller built around your set list. One-time purchase gives you lifetime access to all features, including USB and WiFi Bridge connection.
   ```

4. Click **"Save"**

### Step 3.5: Set the Price
1. Scroll down to **"Price Schedule"**
2. Click **"Add Pricing"**
3. In the popup:
   - **Start Date**: Select today's date
   - **End Date**: Leave blank (means: forever)
   - **Price**: Scroll down and select **"$4.99 (USD)"**
     - This is usually "Tier 5" or just find "$4.99" in the list
4. Click **"Next"**
5. Review all countries - it'll show equivalent prices for each country
6. Click **"Confirm"**

### Step 3.6: Submit for Review
1. At the top of the page, you should see a yellow banner saying **"Missing Screenshot"**
2. Upload a **screenshot**:
   - Take a screenshot of your app (any screen is fine)
   - Click **"Add Screenshot"**
   - Upload the image
   - This shows Apple reviewers what the purchase is for
3. Click **"Submit for Review"** at the top right

**⏳ WAIT**: Apple takes 1-3 days to review your in-app purchase.

---

## Part 4: Create a Sandbox Tester (For Testing)

You need a fake Apple ID to test purchases without paying real money.

### Step 4.1: Create Sandbox Tester
1. Go to https://appstoreconnect.apple.com
2. Click **"Users and Access"** at the top
3. Click **"Sandbox Testers"** (left sidebar, under "Sandbox")
4. Click the **"+"** button
5. Fill in:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: Make up a FAKE email (doesn't need to exist!)
     - Example: `cuebear.test@example.com`
     - ⚠️ DON'T use your real email!
   - **Password**: Make a strong password (write it down!)
   - **Confirm Password**: Same password
   - **Country/Region**: Your country
   - **App Store Territory**: Your country
6. Click **"Save"**

### Step 4.2: Remember These!
Write down:
- Email: `________________`
- Password: `________________`

You'll need these to test purchases!

---

## Part 5: Test Purchases (Before Release)

Now let's test if everything works!

### Step 5.1: Sign Out of Real Apple ID on iPad
1. On your **iPad**, go to **Settings**
2. Tap **"App Store"** (near the top)
3. Tap your name/email at the top
4. Tap **"Sign Out"**
5. ⚠️ **IMPORTANT**: Only sign out of **App Store**, NOT iCloud!

### Step 5.2: Build and Run App in Xcode
1. Open **Cue Bear** project in **Xcode**
2. Connect your **iPad** via USB
3. Select your iPad in the device dropdown (top of Xcode)
4. Click **▶️ Run** (or press ⌘R)
5. Wait for app to launch on iPad

### Step 5.3: Test Purchase Flow
1. In the app, trigger the paywall somehow
   - Right now, you might need to add code to show `PaywallView`
   - Or use `PurchaseStatusView` to test
2. When you try to purchase, you'll see an Apple popup asking for Apple ID
3. **Sign in with your SANDBOX tester account**:
   - Email: `cuebear.test@example.com` (or whatever you created)
   - Password: (the one you wrote down)
4. Confirm the purchase
5. **IT'S FREE!** Sandbox purchases don't charge real money

### Step 5.4: Verify It Worked
1. The purchase should complete
2. App should show "Lifetime Access"
3. Check `PurchaseStatusView` to see license status
4. Try deleting and reinstalling app - should restore automatically

---

## Part 6: Submit App to App Store

Once testing works, submit your app!

### Step 6.1: Prepare App for Submission
1. In **Xcode**, select your project
2. Select your target (Cue Bear)
3. Go to **"Signing & Capabilities"**
4. Make sure **"Automatically manage signing"** is checked
5. Select your **Team** from dropdown

### Step 6.2: Create Archive
1. In Xcode, select **"Any iOS Device"** as the build target (not your iPad!)
2. Go to **Product → Archive** in the menu
3. Wait for build to complete (may take a few minutes)
4. Xcode Organizer window will open

### Step 6.3: Upload to App Store Connect
1. In Xcode Organizer, select your archive
2. Click **"Distribute App"**
3. Select **"App Store Connect"**
4. Click **"Upload"**
5. Accept defaults and click **"Upload"**
6. Wait for upload to complete (may take 10-30 minutes)

### Step 6.4: Fill in App Store Listing
1. Go to https://appstoreconnect.apple.com
2. Open **"Cue Bear"** app
3. Click **"App Store"** in left sidebar
4. Fill in **EVERYTHING**:
   - **App Previews and Screenshots**: Upload at least 2 screenshots
   - **Description**: Write about your app
   - **Keywords**: MIDI, DAW, controller, music
   - **Support URL**: Your website or email
   - **Privacy Policy URL**: (if you have one)
   - **App Category**: Choose "Music"
   - **Age Rating**: Answer the questionnaire

### Step 6.5: Submit for Review
1. After filling everything, click **"Save"**
2. Click **"Add for Review"** (top right)
3. Click **"Submit to App Review"**
4. Answer Apple's questions
5. Click **"Submit"**

**⏳ WAIT**: Apple takes 1-7 days to review your app.

---

## Part 7: After Approval

### Step 7.1: Release Your App
1. When Apple approves, you'll get an email
2. Go to App Store Connect
3. Your app will say **"Pending Developer Release"**
4. Click **"Release This Version"**
5. Your app is now LIVE! 🎉

### Step 7.2: Test Real Purchase
1. On your iPad, go to **Settings → App Store**
2. Sign OUT of sandbox tester
3. Sign IN with your REAL Apple ID
4. Download your app from the App Store
5. Try purchasing - this will charge real money! ($4.99)
6. Verify purchase works

---

## Part 8: Monitor Sales

### Step 8.1: Check Sales Reports
1. Go to App Store Connect
2. Click **"Sales and Trends"**
3. See how many people bought your app!

### Step 8.2: Check Payments
1. Click **"Agreements, Tax, and Banking"**
2. Click **"Payments and Financial Reports"**
3. Apple pays you monthly (if you made at least $150)

---

## Troubleshooting

### "The product is not available"
- Make sure Product ID is exactly: `com.cuebear.onetime_4_99`
- Make sure in-app purchase was approved by Apple
- Try signing out and back into App Store

### "Cannot connect to App Store"
- Check your internet connection
- Try signing out of App Store and back in
- Restart iPad

### Purchase doesn't restore after reinstall
- Make sure you signed in with the same Apple ID
- Try "Restore Purchases" button
- Check if purchase shows in App Store Connect

### Still not working?
- Check your code has the correct Product ID
- Make sure banking/tax info is approved
- Try creating a new sandbox tester
- Contact Apple Developer Support

---

## Quick Reference

### Important URLs
- App Store Connect: https://appstoreconnect.apple.com
- Developer Portal: https://developer.apple.com
- Support: https://developer.apple.com/support

### Key Information
- **Product ID**: `com.cuebear.onetime_4_99`
- **Price**: $4.99 (Tier 5)
- **Type**: Non-Consumable
- **Sandbox Email**: (the one you created)
- **Sandbox Password**: (the one you wrote down)

### Code Files
- `PurchaseManager.swift` - Handles purchases
- `PaywallView.swift` - Shows purchase screen
- `PurchaseStatusView.swift` - Shows purchase status (testing)

---

## Summary Checklist

✅ Part 1: Sign Paid Apps Agreement
✅ Part 1: Add banking information
✅ Part 1: Add tax information
✅ Part 2: Create app in App Store Connect
✅ Part 3: Create $4.99 in-app purchase
✅ Part 3: Submit purchase for review
✅ Part 4: Create sandbox tester
✅ Part 5: Test purchase in sandbox
✅ Part 6: Submit app for review
✅ Part 7: Release app when approved
✅ Part 8: Monitor sales and get paid!

**You did it!** 🎉

---

## Need Help?

If you get stuck:
1. Check Apple's documentation: https://developer.apple.com/app-store/in-app-purchase/
2. Search for your error message on Google
3. Ask on Apple Developer Forums: https://developer.apple.com/forums/
4. Contact Apple Developer Support (if you have a paid developer account)

Good luck! You got this! 💪
