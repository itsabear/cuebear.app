# What's New in Cue Bear Bridge v1.2.2

## 🔧 Critical WiFi Connection Fix

We've fixed a critical bug that was causing WiFi connections to drop after just 60 seconds of inactivity. If you've been experiencing unexpected disconnections during your shows, this update is for you!

### What Was Fixed

**WiFi Heartbeat Timer Issue**
- The Bridge was creating a heartbeat timer to keep WiFi connections alive, but the timer wasn't firing properly
- This caused the iPad to think the connection was "stale" and disconnect after 60 seconds
- Your show would get interrupted right when you needed it most

**The Solution**
- Ensured the heartbeat timer runs reliably on the main RunLoop
- Added comprehensive logging so we can track heartbeat activity
- WiFi connections now stay alive indefinitely during idle periods

### Technical Details (for the curious)

The bug was in how Swift's `Timer.scheduledTimer()` behaves on background threads. We now:
1. Wrap timer creation in `DispatchQueue.main.async` for reliability
2. Explicitly add the timer to RunLoop with `.common` mode
3. Send heartbeat messages every 2 seconds to keep the connection fresh

### What You'll Notice

✅ **WiFi connections stay solid** - No more random disconnections during shows
✅ **Better diagnostics** - More detailed logging helps us troubleshoot issues faster
✅ **Peace of mind** - Your connection won't drop just because you paused between cues

### Universal Binary

This release continues to support both Intel and Apple Silicon Macs with a single universal binary. Whether you're running an M1/M2/M3 Mac or an older Intel Mac, you're covered.

### Installation

Download from the [releases page](https://github.com/itsabear/cuebear.app/releases/tag/bridge-v1.2.2):

- **DMG Installer** - Drag and drop to Applications folder
- **PKG Installer** - Traditional macOS installer

Both are notarized by Apple and fully signed, so they'll open without security warnings.

### Compatibility

- **Requires**: macOS 10.15 (Catalina) or later
- **Works with**: iPad app v1.0.10 and newer
- **Recommended with**: iPad app v1.0.12 for complete WiFi fix

> **Note**: For the best WiFi stability, we recommend updating your iPad app to v1.0.12, which includes the companion fix for receiving heartbeat messages. Together, these updates ensure rock-solid WiFi connections during your shows.

### Based On

This release is based on Bridge v1.2.1, which includes the new onboarding flow and all previous stability improvements.

---

**Questions or issues?** Report them at https://github.com/itsabear/cuebear.app/issues

**Download now:** https://github.com/itsabear/cuebear.app/releases/tag/bridge-v1.2.2
