# Bridge Sleep/Wake Connection Fix Summary

## Problem
iPad wouldn't connect to Bridge after Mac woke from sleep. Bridge showed "USB Disconnected" even though iPad was physically connected via USB.

## Root Cause Analysis

### What We Found
1. **Bridge app was getting stuck in a reconnection loop** after sleep/wake
2. After Mac woke from sleep:
   - iproxy restarted correctly (2s delay)
   - iPad USB server might still be initializing
   - MacConnectionManager tried to connect too fast
   - **Handshake timeout (5s) was too short**
   - **Retry delay (2s) was too short**
   - Loop: connect → timeout → retry → connect → timeout...
   - Each failed attempt left zombie CLOSED connections (file descriptors leaked)
   - State flags (`connecting`, `didSendHandshake`) got stuck, preventing clean reconnection

### Why Bonjour Works Better Than USB/iproxy

**Bonjour:**
- Built into macOS/iOS, OS handles everything automatically
- Event-driven with OS-level notifications
- Direct TCP connection (no intermediaries)
- Stateless discovery (continuous broadcasting)
- Automatic sleep/wake recovery

**USB/iproxy:**
- Multiple failure points: iPad USB Server → USB Hardware → usbmuxd → iproxy → MacConnectionManager
- Each layer has independent state that can desync
- No OS-level sleep/wake integration
- Manual error handling for every failure case
- Strict timing dependencies
- Three processes must coordinate: iproxy, MacConnectionManager, iPad ConnectionManager

**Core issue:** We're manually rebuilding what OS does for Bonjour, but without OS-level integration.

## Fixes Applied

### 1. MacConnectionManager.swift - Line 237-258
**Issue:** Handshake timeout didn't clean up state flags properly

**Fix:** Added state cleanup in timeout handler:
```swift
private func startHandshakeTimeout(seconds: TimeInterval) {
    // ... existing code ...
    t.setEventHandler { [weak self] in
        // Fix: Clean up state properly before reconnecting
        self.stateLock.lock()
        self.connecting = false
        self.didSendHandshake = false
        self.stateLock.unlock()
        // ... rest of handler ...
    }
}
```

### 2. MacConnectionManager.swift - Line 233
**Issue:** 5-second handshake timeout too short after sleep/wake

**Fix:** Increased timeout to 10 seconds:
```swift
self.startHandshakeTimeout(seconds: 10.0)  // Was 5.0
```

### 3. MacConnectionManager.swift - Line 378
**Issue:** 2-second reconnect delay too short, causing rapid retry loop

**Fix:** Increased delay to 5 seconds:
```swift
let delay = 5.0  // Increased from 2.0 for better stability after sleep/wake
```

### 4. CueBearBridgeApp.swift - Line 876-901
**Issue:** Incorrect indentation of `do-try-catch` block (syntax issue)

**Fix:** Properly aligned the do-try-catch block for iproxy.start()

## Results

### Before Fix:
- Mac wakes from sleep → iproxy restarts → iPad doesn't connect
- Bridge shows hundreds of CLOSED connections to port 8077
- Required manual Bridge restart to connect
- Test Case TC-101 (Sleep/Wake - USB Connection Renewal): **FAIL**

### After Fix:
- Handshake timeout: 5s → 10s (more time for iPad to be ready)
- Reconnect delay: 2s → 5s (less aggressive retry loop)
- State cleanup: Properly resets flags on timeout
- Should auto-reconnect within 15 seconds after wake

### Outstanding Issue:
**iproxy auto-start still not working** - Bridge app launches but doesn't start iproxy process. Requires investigation of IProxyManager.start() initialization sequence.

## Files Modified

1. **MacConnectionManager.swift**
   - Line 237-258: Added state cleanup in handshake timeout
   - Line 233: Increased handshake timeout 5s → 10s
   - Line 378: Increased reconnect delay 2s → 5s

2. **CueBearBridgeApp.swift**
   - Line 876-901: Fixed do-try-catch block indentation

## Testing Required

1. Test sleep/wake cycle:
   - Mac goes to sleep with iPad connected
   - Mac wakes up
   - **Expected:** Connection re-establishes within 15 seconds automatically
   - **Actual:** Needs verification (iproxy auto-start issue needs fix first)

2. Test iPad connection after Bridge restart:
   - Quit Bridge app
   - Relaunch Bridge app
   - **Expected:** iproxy starts automatically, iPad connects
   - **Actual:** iproxy doesn't start (bug)

## Next Steps

1. **Fix iproxy auto-start issue** - Investigate why IProxyManager.start() isn't being called or is failing silently
2. **Test sleep/wake reconnection** once iproxy auto-start is fixed
3. **Monitor for zombie connections** - Verify CLOSED connections are properly cleaned up
4. **Verify state flags** - Ensure `connecting` and `didSendHandshake` don't get stuck

## Technical Details

**Connection Flow:**
```
iPad (port 9360) <--USB--> iproxy (port 8077) <--TCP--> MacConnectionManager
```

**State Machine Issue:**
- MacConnectionManager has flags: `connecting`, `didSendHandshake`, `reconnectPending`
- Guard clauses at line 114 prevent connection if flags are stale
- Timeout handler wasn't resetting flags → deadlock

**Timing Dependencies:**
```
Mac wakes up
↓ (wait 2s for USB subsystem)
Start iproxy
↓ (wait 0.5s for iproxy to listen)
Try to connect
↓ (wait 10s for handshake - INCREASED FROM 5s)
If timeout → wait 5s and retry (INCREASED FROM 2s)
```

## Commit Message Suggestion

```
Fix USB connection recovery after sleep/wake

- Increase handshake timeout from 5s to 10s to give iPad more time after wake
- Increase reconnect delay from 2s to 5s to prevent aggressive retry loop
- Add proper state cleanup in handshake timeout handler
- Fix indentation of do-try-catch block in BridgeApp.start()

Addresses TC-101 (Sleep/Wake - USB Connection Renewal)
```
