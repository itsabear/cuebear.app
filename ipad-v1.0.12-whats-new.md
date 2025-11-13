# What's New in Cue Bear v1.0.12

## 🔧 WiFi Connection Stability Fix

We've fixed a critical bug that was causing WiFi connections to disconnect after 60 seconds of inactivity. Your shows will now run smoothly without unexpected connection drops!

### What Was Fixed

**WiFi Heartbeat Reception Issue**
- The iPad was receiving heartbeat messages from the Bridge but wasn't recognizing them as valid connection activity
- This caused the stale connection detection to kick in after 60 seconds, even though the Bridge was sending heartbeats
- Your connection would drop right in the middle of your show

**The Solution**
- The iPad now properly resets its connection timer when receiving any message from the Bridge
- Heartbeat messages are recognized as valid connection activity
- WiFi connections now stay alive indefinitely during idle periods

### What You'll Notice

✅ **Rock-solid WiFi connections** - No more random disconnections during shows
✅ **Works seamlessly** with idle periods between cues
✅ **Peace of mind** - Focus on your performance, not your connection

### The Complete Fix

For the best WiFi stability, this update works together with **Bridge v1.2.2**:

- **Bridge v1.2.2** sends heartbeat messages every 2 seconds
- **iPad v1.0.12** receives and recognizes these heartbeats

Together, they ensure your WiFi connection stays alive and stable throughout your entire show.

### Technical Details (for the curious)

The bug was in the `parseResponse()` function. The iPad has a 60-second stale connection detector that monitors the `lastSuccessfulMessage` timestamp. Previously, this timestamp was only updated when *sending* messages, not when *receiving* them. Now it updates whenever any valid message is received, including heartbeats from the Bridge.

### Compatibility

- **Requires**: iOS 17.0 or later
- **Works with**: Bridge v1.2.0 and newer
- **Recommended with**: Bridge v1.2.2 for complete WiFi fix

> **Important**: For the best WiFi stability, make sure you're also running **Bridge v1.2.2** on your Mac. You can download it from the [GitHub releases page](https://github.com/itsabear/cuebear.app/releases/tag/bridge-v1.2.2).

### How to Update

1. Open the **App Store** on your iPad
2. Go to your **account** (tap your profile picture)
3. Scroll down to **Available Updates**
4. Find **Cue Bear** and tap **Update**

Or enable automatic updates to always have the latest version!

### What's Next

We're continuing to improve Cue Bear's reliability and performance. If you experience any issues or have suggestions, please let us know:

- **Report issues**: https://github.com/itsabear/cuebear.app/issues
- **Email**: [your support email]

---

**Thank you for using Cue Bear!** Your feedback helps us make it better for everyone in the live performance community.
