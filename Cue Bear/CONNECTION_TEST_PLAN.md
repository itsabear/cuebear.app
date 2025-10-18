# Cue Bear Connection Test Plan

**Version:** 1.0
**Date:** 2025-10-11
**Purpose:** Comprehensive testing strategy for USB and WiFi connection management

---

## Executive Summary

This document provides a comprehensive test plan for the Cue Bear iPad app's connection system. The app supports two mutually exclusive connection types:
- **USB Connection**: Via iproxy tunnel from Mac Bridge app (priority connection)
- **WiFi Connection**: Via Bonjour discovery and direct TCP connection (fallback)

**Key Requirements:**
1. USB and WiFi connections are mutually exclusive (only one active at a time)
2. USB has priority over WiFi
3. WiFi remains connected when USB cable is unplugged
4. Connections renew automatically after Mac sleep/wake
5. If iPad app is open + USB connected + Bridge app running = connection MUST succeed

---

## Architecture Overview

### Components
1. **ConnectionCoordinator** (iPad): Orchestrates USB/WiFi mutual exclusion
2. **ConnectionManager** (iPad): Handles USB listener on port 9360
3. **BridgeOutput** (iPad): Handles WiFi Bonjour discovery and connection
4. **IProxyManager** (Mac): Manages iproxy process for USB tunneling
5. **MacConnectionManager** (Mac): Connects to iPad via iproxy tunnel

### Connection Flow
- **USB**: Mac Bridge → iproxy (8077→9360) → iPad ConnectionManager → USB connection established
- **WiFi**: iPad BridgeOutput → Bonjour discovery → Direct TCP to Mac Bridge → WiFi connection established

---

## Test Priority Matrix

| Priority | Category | Risk Level | Must Pass Before Release |
|----------|----------|------------|--------------------------|
| P0 | Critical Path | High | Yes |
| P1 | Core Functionality | Medium | Yes |
| P2 | Edge Cases | Medium | Recommended |
| P3 | Nice to Have | Low | Optional |

---

## P0: Critical Path Tests

These tests MUST pass for the app to be considered functional.

### TC-001: Basic USB Connection
**Priority:** P0
**Category:** Connection Establishment

**Initial State:**
- iPad app freshly launched
- USB cable connected to Mac
- Mac Bridge app running
- No WiFi connection active

**Test Steps:**
1. Launch iPad app
2. Verify USB cable is physically connected
3. Wait for Bridge app to start iproxy
4. Observe connection indicator in UI

**Expected Behavior:**
- `ConnectionManager.isUSBCableConnected` = true within 2 seconds
- `ConnectionManager.usbBridgeAvailable` = true
- USB connection chip appears in UI
- `ConnectionCoordinator.activeConnection` = `.usb`
- `ConnectionManager.isConnected` = true within 5 seconds
- `ConnectionManager.connectedComputerName` displays Mac name
- Handshake completes (CB/2 → OK/2)

**Success Criteria:**
- Connection established within 5 seconds
- MIDI messages can be sent successfully
- No error messages in logs

**Logging to Monitor:**
```
🔗 ConnectionManager: 🔌 Darwin notification received: host_attached
🔗 ConnectionManager: ✅ USB cable connected - chip will appear
🔗 ConnectionManager: Starting listener on port 9360
🔗 USB Listener ready on 9360
🔗 ConnectionManager: *** NEW CONNECTION HANDLER CALLED ***
🤝 USB: Received CB/2+ handshake from Bridge
🔗 USB: sent OK/2 response
🔗 USB: Connection established with [Mac Name]
🔌 ConnectionCoordinator: USB connection change - isConnected: true
```

---

### TC-002: USB Connection Must Succeed (Critical Guarantee)
**Priority:** P0
**Category:** Connection Reliability

**Initial State:**
- iPad app is open and visible
- USB cable is connected
- Bridge app is running on Mac

**Test Steps:**
1. Verify all three conditions are met
2. Wait up to 10 seconds
3. Verify connection status

**Expected Behavior:**
- Connection MUST establish within 10 seconds
- Zero tolerance for failure when all conditions are met
- If connection fails, automatic retry within 2 seconds
- Maximum 3 retry attempts

**Success Criteria:**
- Connection established within 10 seconds with 100% reliability
- If any failure occurs, this is a CRITICAL BUG

**Failure Conditions:**
- Connection not established after 10 seconds = FAIL
- Any error in logs indicating handshake failure = FAIL
- Port 9360 not listening = FAIL

---

### TC-003: Basic WiFi Connection
**Priority:** P0
**Category:** Connection Establishment

**Initial State:**
- iPad app launched
- No USB cable connected
- Mac Bridge app running on same network
- WiFi enabled on both devices

**Test Steps:**
1. Launch iPad app
2. Tap WiFi connection chip
3. Wait for Bonjour discovery
4. Tap discovered Mac Bridge
5. Wait for connection

**Expected Behavior:**
- `BridgeOutput.discovered` contains Bridge within 5 seconds
- Tapping bridge starts connection
- `BridgeOutput.isConnecting` = true during connection
- `BridgeOutput.isConnected` = true within 3 seconds
- `ConnectionCoordinator.activeConnection` = `.wifi`
- Connection quality indicator shows "excellent"

**Success Criteria:**
- WiFi connection established within 8 seconds total
- MIDI messages can be sent successfully
- No timeout errors

**Logging to Monitor:**
```
BridgeOutput: Discovery results changed, found 1 services
BridgeOutput: Discovered bridge: [Mac Name]
🔌 DEBUG: BridgeOutput.connect called for: [Mac Name]
🔌 DEBUG: Connection state changed to: ready
BridgeOutput: Connected successfully to [Mac Name]
✅ WiFi connection established
```

---

### TC-004: Mutual Exclusion - USB Takes Priority
**Priority:** P0
**Category:** Mutual Exclusion

**Initial State:**
- iPad app running
- WiFi connected to Bridge
- MIDI messages flowing successfully

**Test Steps:**
1. Verify WiFi connection is active
2. Send test MIDI message (should succeed)
3. Plug in USB cable
4. Wait for USB detection
5. Send another test MIDI message

**Expected Behavior:**
1. WiFi disconnects immediately when USB is detected
2. `ConnectionCoordinator.activeConnection` changes from `.wifi` to `.usb`
3. `BridgeOutput.isConnected` = false
4. `ConnectionManager.isConnected` = true within 5 seconds
5. Second MIDI message routes through USB
6. No duplicate MIDI messages sent

**Success Criteria:**
- Only one connection active at any time
- Clean transition with no MIDI message loss
- No "both connections active" state logged

**Logging to Monitor:**
```
🔗 ConnectionManager: 🎯 USB host attached - cable connected!
🔌 USB connected - disabling WiFi connection
🔌 ConnectionCoordinator: Updated activeConnection to .usb
BridgeOutput: Connection cancelled to [Mac Name]
```

---

### TC-005: WiFi Persists When USB Unplugged
**Priority:** P0
**Category:** Connection Stability

**Initial State:**
- WiFi was connected
- USB cable plugged in (USB active, WiFi disconnected)
- MIDI messages flowing via USB

**Test Steps:**
1. Verify USB connection is active
2. Unplug USB cable
3. DO NOT manually reconnect WiFi
4. Wait and observe connection state

**Expected Behavior:**
- USB connection drops immediately
- `ConnectionManager.isUSBCableConnected` = false
- WiFi does NOT automatically reconnect
- `ConnectionCoordinator.activeConnection` = `.none`
- User must manually tap WiFi chip to reconnect

**Success Criteria:**
- WiFi stays disconnected after USB unplug
- No automatic WiFi reconnection
- User has explicit control

**Anti-Pattern to Avoid:**
- WiFi auto-reconnecting after USB disconnect

**Logging to Monitor:**
```
🔗 ConnectionManager: 🔌 USB host detached - cable disconnected!
🔗 ConnectionManager: ❌ USB cable disconnected - chip will disappear
🔌 USB disconnected - WiFi available for manual connection
🔌 ConnectionCoordinator: Updated activeConnection to .none
```

---

## P1: Core Functionality Tests

### TC-101: Sleep/Wake - USB Connection Renewal
**Priority:** P1
**Category:** Sleep/Wake Recovery

**Initial State:**
- iPad and Mac both awake
- USB cable connected
- USB connection established and working

**Test Steps:**
1. Verify USB connection is active
2. Put Mac to sleep (close lid or ⌥⌘⏏)
3. Wait 10 seconds
4. Wake Mac (open lid or press key)
5. Observe connection recovery

**Expected Behavior:**
1. **On Mac Sleep:**
   - `IProxyManager` detects sleep: "💤 System going to sleep - stopping iproxy"
   - iproxy process stops
   - USB connection on iPad disconnects
   - `ConnectionManager.isConnected` = false

2. **On Mac Wake:**
   - `IProxyManager` detects wake: "⏰ System woke up - restarting iproxy after 2s delay"
   - iproxy restarts automatically (2-second delay)
   - USB connection re-establishes
   - `ConnectionManager.isConnected` = true within 10 seconds
   - Full handshake completes

**Success Criteria:**
- Connection fully restored within 15 seconds of wake
- No manual intervention required
- MIDI messages work immediately after reconnection

**Failure Recovery:**
- If first reconnection fails, retry after 2 more seconds
- Maximum 3 retry attempts

**Logging to Monitor:**
```
🔧 IProxyManager: 💤 System going to sleep - stopping iproxy
🔧 IProxyManager: ⏰ System woke up - restarting iproxy after 2s delay
🔧 IProxyManager: ✅ iproxy restarted successfully after wake
🔗 MacConnectionManager: Handshake sent — waiting for response…
🔗 MacConnectionManager: Received CB/2 handshake response — connected
```

---

### TC-102: Sleep/Wake - WiFi Connection Renewal
**Priority:** P1
**Category:** Sleep/Wake Recovery

**Initial State:**
- iPad and Mac both awake
- WiFi connection established
- No USB cable connected

**Test Steps:**
1. Verify WiFi connection is active
2. Put Mac to sleep
3. Wait 10 seconds
4. Wake Mac
5. Observe connection recovery

**Expected Behavior:**
1. **On Mac Sleep:**
   - WiFi connection may remain open or close depending on network
   - `BridgeOutput.isConnected` may stay true (WiFi doesn't die like USB)

2. **On Mac Wake:**
   - `BridgeOutput` performs health check
   - Sends test message to verify connection
   - If connection is stale, automatic reconnection starts
   - Connection re-establishes within 5 seconds

**Success Criteria:**
- Connection verified or restored within 10 seconds of wake
- MIDI messages work after recovery

**Logging to Monitor:**
```
📡 BridgeOutput: Checking WiFi connection health after wake
📡 BridgeOutput: WiFi connection was active - verifying it's still healthy
📡 BridgeOutput: WiFi connection verified healthy after wake
```

---

### TC-103: iPad Sleep/Wake (App Backgrounded)
**Priority:** P1
**Category:** App Lifecycle

**Initial State:**
- iPad app running with active connection (USB or WiFi)
- Connection working properly

**Test Steps:**
1. Verify active connection
2. Press iPad home button (background app)
3. Wait 30 seconds
4. Reopen Cue Bear app
5. Observe connection state

**Expected Behavior:**
1. **On Background:**
   - App registers background task
   - Connection maintained for background task duration
   - Logs: "App entered background - starting background task"

2. **On Foreground:**
   - App checks connection health
   - Logs: "Checking connection health after wake"
   - If connection lost, automatic reconnection
   - Connection restored within 5 seconds

**Success Criteria:**
- Connection still works after returning to foreground
- If connection was lost, automatic recovery within 5 seconds
- MIDI messages work immediately

**Logging to Monitor:**
```
🔗 ConnectionManager: App entered background - starting background task
🔗 ConnectionManager: App entering foreground - ending background task
🔗 ConnectionManager: Checking connection health after wake
```

---

### TC-104: Unplug/Replug USB Cable (Quick)
**Priority:** P1
**Category:** Connection Stability

**Initial State:**
- USB connection active
- MIDI messages flowing

**Test Steps:**
1. Verify USB connection is active
2. Unplug USB cable
3. Wait 1 second
4. Re-plug USB cable
5. Observe reconnection time

**Expected Behavior:**
1. **On Unplug:**
   - Darwin notification: "host_detached"
   - Connection drops immediately
   - `ConnectionManager.isUSBCableConnected` = false
   - USB chip disappears from UI

2. **On Re-plug:**
   - Darwin notification: "host_attached" within 2 seconds
   - `ConnectionManager.isUSBCableConnected` = true
   - USB chip appears in UI
   - Automatic reconnection starts
   - Connection re-establishes within 5 seconds

**Success Criteria:**
- Total recovery time < 7 seconds
- No stuck connections
- Clean reconnection

**Logging to Monitor:**
```
🔗 ConnectionManager: 🔌 USB host detached - cable disconnected!
🔗 ConnectionManager: ❌ USB cable disconnected - chip will disappear
🔗 ConnectionManager: 🎯 USB host attached - cable connected!
🔗 ConnectionManager: ✅ USB cable connected - chip will appear
🔗 ConnectionManager: Starting USB server for new connection
```

---

### TC-105: Bridge App Quit and Restart
**Priority:** P1
**Category:** Connection Recovery

**Initial State:**
- USB or WiFi connection active
- Mac Bridge app running

**Test Steps:**
1. Verify active connection
2. Quit Mac Bridge app (⌘Q)
3. Wait 5 seconds
4. Restart Mac Bridge app
5. Observe reconnection

**Expected Behavior:**
1. **On Bridge Quit:**
   - Connection closes gracefully
   - iPad detects disconnection via "isComplete" callback
   - Logs: "Connection completed by remote"
   - `isConnected` = false
   - `isListening` = false (USB server stops)

2. **On Bridge Restart:**
   - Bridge app starts iproxy (USB) or Bonjour (WiFi)
   - iPad detects Bridge availability
   - Automatic reconnection within 5 seconds (USB)
   - Manual reconnection required (WiFi)

**Success Criteria:**
- Clean disconnection detected
- USB: Automatic reconnection within 5 seconds
- WiFi: Bridge appears in discovery list within 5 seconds

**Logging to Monitor:**
```
🔗 ConnectionManager: 🔌 Connection completed - updating state to disconnected
🔗 ConnectionManager: 🛑 Stopped listening - Bridge app has quit
🔧 IProxyManager: ✅ iproxy started successfully
🔗 ConnectionManager: Starting USB server for new connection
```

---

### TC-106: Manual WiFi Disconnect and Reconnect
**Priority:** P1
**Category:** Manual Control

**Initial State:**
- WiFi connection active
- MIDI messages flowing

**Test Steps:**
1. Verify WiFi connection is active
2. Tap WiFi chip to disconnect
3. Wait 2 seconds
4. Tap WiFi chip again
5. Select Bridge from list
6. Observe reconnection

**Expected Behavior:**
1. **On Disconnect:**
   - `BridgeOutput.disconnect()` called
   - Connection cancelled immediately
   - `isConnected` = false
   - Connection health monitoring stops

2. **On Reconnect:**
   - Bonjour discovery shows available bridges
   - Tapping bridge initiates connection
   - Connection established within 3 seconds
   - Health monitoring resumes

**Success Criteria:**
- Clean disconnect with no errors
- Reconnection works reliably
- No stale connection issues

---

### TC-107: Network Change (WiFi Network Switch)
**Priority:** P1
**Category:** Network Stability

**Initial State:**
- WiFi connection active on Network A
- Both iPad and Mac on same network

**Test Steps:**
1. Verify WiFi connection is active
2. Switch iPad to Network B (different WiFi network)
3. Observe connection state
4. Switch iPad back to Network A
5. Observe reconnection

**Expected Behavior:**
1. **On Network Switch:**
   - Connection drops (network unreachable)
   - `BridgeOutput` detects failure
   - Logs: "Connection failed" or "Connection cancelled"
   - Connection health monitoring stops
   - Automatic reconnection timer starts

2. **On Network Restore:**
   - Bonjour discovery resumes
   - Bridge appears in discovery list
   - Manual reconnection required (tap WiFi chip)

**Success Criteria:**
- Connection cleanly fails on network change
- No crash or hanging connections
- Reconnection works after network restore

**Logging to Monitor:**
```
BridgeOutput: Connection failed to [Mac Name]: Error Domain=...
🔄 BridgeOutput: Periodic reconnection check - attempting to reconnect
BridgeOutput: Discovery results changed, found 1 services
```

---

## P2: Edge Case Tests

### TC-201: Multiple Bridge Apps on Network
**Priority:** P2
**Category:** Discovery

**Initial State:**
- iPad on WiFi
- Two or more Mac Bridge apps on same network

**Test Steps:**
1. Launch 2+ Mac Bridge apps on different Macs
2. Open iPad WiFi discovery
3. Verify all bridges appear
4. Connect to Bridge A
5. Disconnect
6. Connect to Bridge B

**Expected Behavior:**
- All bridges appear in `BridgeOutput.discovered` list
- Each bridge shows unique computer name
- Can connect to any bridge
- Only one active connection at a time
- Clean switching between bridges

**Success Criteria:**
- All bridges discovered within 5 seconds
- Connection switching works reliably
- No duplicate connections

---

### TC-202: USB Cable Partially Connected
**Priority:** P2
**Category:** Physical Connection

**Initial State:**
- USB cable loosely connected (poor contact)
- Connection intermittently dropping

**Test Steps:**
1. Partially insert USB cable (loose connection)
2. Observe connection behavior
3. Wiggle cable to simulate intermittent connection
4. Fully insert cable
5. Observe stabilization

**Expected Behavior:**
- Intermittent connection triggers multiple connect/disconnect events
- Darwin notifications fire repeatedly
- Connection manager handles rapid state changes
- Eventually stabilizes when cable fully connected
- No memory leaks or stuck states

**Success Criteria:**
- App doesn't crash during rapid connection changes
- Connection stabilizes when cable properly connected
- No zombie connections remain

---

### TC-203: iPad Locked Screen
**Priority:** P2
**Category:** Device State

**Initial State:**
- Connection active (USB or WiFi)
- iPad screen on

**Test Steps:**
1. Verify active connection
2. Lock iPad (press power button)
3. Wait 30 seconds
4. Unlock iPad
5. Observe connection state

**Expected Behavior:**
- Connection maintained during lock (background task)
- Background task keeps connection alive for limited time
- On unlock, connection health check performed
- If connection lost, automatic reconnection

**Success Criteria:**
- Connection still works after unlock (if < 3 minutes)
- If connection lost, automatic recovery within 5 seconds

---

### TC-204: Low Battery / Low Power Mode
**Priority:** P2
**Category:** Power Management

**Initial State:**
- Connection active
- iPad battery normal

**Test Steps:**
1. Verify active connection
2. Enable Low Power Mode
3. Send MIDI messages
4. Observe connection stability
5. Disable Low Power Mode

**Expected Behavior:**
- Connection remains active in Low Power Mode
- MIDI messages still work
- Performance may be slightly degraded (longer latency)
- Connection maintained

**Success Criteria:**
- Connection doesn't drop when Low Power Mode enabled
- MIDI messages continue to work
- Connection quality may show "good" instead of "excellent"

---

### TC-205: Airplane Mode Toggle
**Priority:** P2
**Category:** Network State

**Initial State:**
- WiFi connection active
- Airplane Mode off

**Test Steps:**
1. Verify WiFi connection is active
2. Enable Airplane Mode
3. Observe connection state
4. Wait 5 seconds
5. Disable Airplane Mode
6. Observe reconnection

**Expected Behavior:**
1. **Airplane Mode On:**
   - WiFi connection drops immediately
   - `BridgeOutput` detects failure
   - All network activity stops

2. **Airplane Mode Off:**
   - WiFi re-enables
   - Bonjour discovery resumes
   - Manual reconnection required

**Success Criteria:**
- Clean disconnection on Airplane Mode
- No crash or errors
- Reconnection works after Airplane Mode disabled

---

### TC-206: VPN Interference (WiFi)
**Priority:** P2
**Category:** Network Configuration

**Initial State:**
- WiFi connection active
- VPN disconnected

**Test Steps:**
1. Verify WiFi connection is active
2. Connect to VPN on iPad
3. Observe connection stability
4. Send MIDI messages
5. Disconnect VPN

**Expected Behavior:**
- VPN may or may not interfere with local network (depends on VPN config)
- If VPN routes local traffic, connection may fail
- If VPN only routes internet traffic, connection remains stable
- Connection quality may degrade if routing is affected

**Success Criteria:**
- Connection doesn't crash or hang
- If VPN breaks connection, clean failure detected
- After VPN disconnect, reconnection works

**Notes:**
- This is environment-dependent
- Split-tunnel VPNs should work fine
- Full-tunnel VPNs may break local connections

---

### TC-207: Bluetooth Interference
**Priority:** P2
**Category:** Hardware Interference

**Initial State:**
- WiFi connection active
- Multiple Bluetooth devices connected

**Test Steps:**
1. Verify WiFi connection is active
2. Connect multiple Bluetooth devices (headphones, keyboard, etc.)
3. Send rapid MIDI messages
4. Observe connection quality
5. Disconnect Bluetooth devices

**Expected Behavior:**
- Bluetooth and WiFi share 2.4GHz spectrum (potential interference)
- Connection should remain stable but latency may increase
- Connection quality indicator may show "good" instead of "excellent"
- No disconnections due to interference

**Success Criteria:**
- Connection remains stable
- MIDI messages continue to work
- Latency may increase but < 200ms

**Notes:**
- Modern devices have good coexistence mechanisms
- 5GHz WiFi avoids this issue entirely

---

### TC-208: iPad Battery Dies During Connection
**Priority:** P2
**Category:** Power Loss

**Initial State:**
- USB or WiFi connection active
- iPad battery critically low

**Test Steps:**
1. Verify active connection
2. Let iPad battery drain completely
3. iPad shuts down
4. Charge iPad
5. Restart iPad
6. Launch app
7. Observe connection behavior

**Expected Behavior:**
- App handles sudden termination gracefully
- On restart, no corrupted state
- USB: Automatic reconnection if cable still connected
- WiFi: Manual reconnection required

**Success Criteria:**
- No data corruption
- App launches cleanly after restart
- Connections can be re-established

---

### TC-209: Rapid Connection Type Switching
**Priority:** P2
**Category:** Stress Test

**Initial State:**
- Both USB cable and WiFi available
- App ready for connections

**Test Steps:**
1. Connect via WiFi
2. Immediately plug in USB cable
3. Wait for USB to take over
4. Immediately unplug USB
5. Immediately plug USB back in
6. Repeat 5 times rapidly
7. Observe final connection state

**Expected Behavior:**
- Each connection transition is clean
- No duplicate connections
- No stuck states
- Final connection matches physical state
- No memory leaks

**Success Criteria:**
- App doesn't crash
- Final connection state is correct
- Logs show clean transitions
- No zombie connections

---

### TC-210: Mac Bridge App Not Responding
**Priority:** P2
**Category:** Connection Health

**Initial State:**
- Connection established (USB or WiFi)
- Mac Bridge app running but hung

**Test Steps:**
1. Verify connection shows "Connected"
2. Simulate Bridge hang (Force Quit and don't restart)
3. Send MIDI messages
4. Wait 10 seconds
5. Observe connection status updates

**Expected Behavior:**
1. **Initial State:**
   - Connection shows "Connected"

2. **After Bridge Quits:**
   - Heartbeat monitoring detects no response
   - Heartbeat timeout after 3 seconds (USB) or 15 seconds (WiFi)
   - Connection marked as disconnected
   - Logs: "Heartbeat timeout - connection appears to be disconnected"

3. **Reconnection Attempts:**
   - USB: Reconnection timer starts (2-second intervals)
   - WiFi: Reconnection timer starts (30-second intervals)

**Success Criteria:**
- Stale connection detected within reasonable time
- Connection status updated to "Disconnected"
- Automatic reconnection attempts after Bridge restarts

**Logging to Monitor:**
```
🔗 ConnectionManager: Heartbeat timeout - USB connection appears to be disconnected
🔄 BridgeOutput: Connection appears stale (no messages in 60s), forcing reconnection
```

---

## P3: Nice to Have Tests

### TC-301: MIDI Message Flood (Performance)
**Priority:** P3
**Category:** Performance

**Initial State:**
- Connection active (USB or WiFi)
- App ready

**Test Steps:**
1. Send 100 rapid MIDI CC messages (fader sweep)
2. Observe UI responsiveness
3. Monitor connection latency
4. Check for message loss
5. Verify main thread not blocked

**Expected Behavior:**
- Messages batched automatically (5 messages per batch or 10ms timeout)
- UI remains responsive
- No main thread freezing
- Connection quality stays "excellent" or "good"
- All messages delivered (or gracefully dropped if too many)

**Success Criteria:**
- UI frame rate stays > 30 FPS during flood
- No visible UI freezing
- Message batching working correctly
- Maximum batch size enforced (100 messages)

**Logging to Monitor:**
```
🔗 ConnectionManager: ✅ Batch sent successfully (5 messages)
🔗 ConnectionManager: ⚠️ Batch at maximum size (100) - forcing immediate send
```

---

### TC-302: Long-Duration Connection (24 Hours)
**Priority:** P3
**Category:** Stability

**Initial State:**
- Connection established
- App running

**Test Steps:**
1. Establish connection
2. Send periodic MIDI messages (1 per minute)
3. Leave running for 24 hours
4. Check connection status
5. Send final test message

**Expected Behavior:**
- Connection remains stable for 24 hours
- No memory leaks
- No connection degradation
- Heartbeats keep connection alive
- Final test message works

**Success Criteria:**
- Connection still active after 24 hours
- Memory usage stable (no leaks)
- CPU usage minimal when idle
- MIDI messages work at end of test

---

### TC-303: Multiple Reconnection Attempts (Max Retry)
**Priority:** P3
**Category:** Edge Case

**Initial State:**
- Connection established
- Mac Bridge app stopped (not running)

**Test Steps:**
1. Verify connection fails
2. Observe automatic reconnection attempts
3. Count retry attempts
4. Verify max retry limit
5. Restart Bridge app
6. Verify connection re-establishes

**Expected Behavior:**
- Automatic reconnection attempts every 2 seconds
- Maximum 5 retry attempts before giving up
- After 5 failures, connection health = "critical"
- When Bridge restarts, reconnection succeeds immediately

**Success Criteria:**
- Reconnection attempts stop after max retries
- No infinite retry loop
- Connection works after Bridge restart

**Logging to Monitor:**
```
🔗 ConnectionManager: Attempting reconnection...
🔗 ConnectionManager: Scheduling reconnection in 2.0s (attempt 1)
🔗 ConnectionManager: Scheduling reconnection in 2.0s (attempt 2)
...
🔗 ConnectionManager: Max reconnection attempts reached
```

---

### TC-304: iPad App Launch With Connection Already Established
**Priority:** P3
**Category:** State Management

**Initial State:**
- USB cable connected
- Mac Bridge app running
- iPad app NOT running

**Test Steps:**
1. Verify Bridge app running
2. Verify USB cable connected
3. Launch iPad app
4. Observe connection time

**Expected Behavior:**
- App detects USB cable on launch
- `isUSBCableConnected` = false initially
- Listener starts immediately
- Connection establishes within 5 seconds
- USB chip appears after cable detection

**Success Criteria:**
- Connection established within 5 seconds of app launch
- Smooth user experience
- No delays or errors

---

### TC-305: WiFi Connected, Then Bridge App Starts Later
**Priority:** P3
**Category:** Discovery Timing

**Initial State:**
- iPad app running with WiFi discovery active
- Mac Bridge app NOT running

**Test Steps:**
1. Open WiFi chip on iPad (no bridges shown)
2. Start Mac Bridge app
3. Wait for Bonjour discovery
4. Verify Bridge appears in list
5. Connect to Bridge

**Expected Behavior:**
- Bridge appears in discovery list within 5 seconds of starting
- Discovery refresh timer catches late-starting bridges (30-second intervals)
- Manual "Restart Discovery" button works immediately
- Connection works normally

**Success Criteria:**
- Bridge discovered within 5 seconds (or 30 seconds for timer)
- Connection establishes successfully
- Discovery system catches late-starting services

**Logging to Monitor:**
```
BridgeOutput: Refreshing discovery to catch late-starting Bridge apps
BridgeOutput: Discovery results changed, found 1 services
BridgeOutput: Discovered bridge: [Mac Name]
```

---

## Failure Recovery Tests

### TC-401: Port Already in Use (USB)
**Priority:** P1
**Category:** Error Handling

**Initial State:**
- Another process using port 9360 on iPad

**Test Steps:**
1. Simulate port conflict
2. Launch app
3. Observe error handling
4. Free port
5. Verify recovery

**Expected Behavior:**
- Listener fails to start with "EADDRINUSE" error
- App logs: "Port 9360 is already in use - waiting longer before retry"
- Retry after 5-second delay
- Eventually succeeds when port is free

**Success Criteria:**
- App doesn't crash on port conflict
- Automatic retry with longer delay
- Connection works after port is freed

---

### TC-402: iproxy Process Crash (Mac)
**Priority:** P1
**Category:** Error Recovery

**Initial State:**
- USB connection active
- iproxy running

**Test Steps:**
1. Verify USB connection active
2. Manually kill iproxy process (pkill iproxy)
3. Wait 5 seconds
4. Observe recovery
5. Put Mac to sleep and wake
6. Verify iproxy restarts

**Expected Behavior:**
1. **On iproxy Crash:**
   - USB connection drops immediately
   - `MacConnectionManager` detects failure
   - Reconnection attempts fail (no iproxy)

2. **On Mac Wake:**
   - `IProxyManager` restarts iproxy automatically
   - USB connection re-establishes
   - Full recovery within 10 seconds

**Success Criteria:**
- Connection recovers after Mac sleep/wake
- iproxy restarts automatically
- No manual intervention needed

---

### TC-403: Handshake Timeout (USB)
**Priority:** P1
**Category:** Protocol Error

**Initial State:**
- USB connection attempting to establish
- Mac Bridge app running but not responding to handshake

**Test Steps:**
1. Simulate Bridge app that accepts connection but doesn't send handshake
2. Observe timeout behavior
3. Verify reconnection attempt

**Expected Behavior:**
- Connection reaches `.ready` state
- Mac sends CB/2 handshake
- iPad waits for OK/2 response
- After 5 seconds, handshake timeout triggered
- Connection cancelled and retry scheduled

**Success Criteria:**
- Handshake timeout after 5 seconds
- Connection cancelled cleanly
- Automatic retry within 2 seconds

**Logging to Monitor:**
```
🔗 MacConnectionManager: Handshake sent — waiting for response…
🔗 MacConnectionManager: Handshake timed out; reconnecting
```

---

### TC-404: JSON Parsing Error
**Priority:** P2
**Category:** Protocol Error

**Initial State:**
- Connection established
- Mac sends malformed JSON

**Test Steps:**
1. Simulate malformed JSON message
2. Observe error handling
3. Send valid message after
4. Verify connection still works

**Expected Behavior:**
- Malformed JSON logged as error
- Connection remains stable
- Next valid message processes normally
- No crash or connection drop

**Success Criteria:**
- Graceful error handling
- Connection not affected by bad messages
- Logs show JSON parsing error

---

## Test Execution Guidelines

### Prerequisites
- iPad with iOS 15+ installed
- Mac with Bridge app installed
- USB cable (Lightning or USB-C depending on iPad)
- WiFi network available
- Test environment with minimal interference

### Test Environment Setup
1. Clean install of Cue Bear app
2. Fresh Mac Bridge app installation
3. iproxy binary bundled or Homebrew installed
4. Console.app open for log monitoring
5. Network analyzer available (optional)

### Logging Configuration
Enable verbose logging for all components:
```swift
// Set debug logging level
Logger.shared.enableVerboseLogging = true
```

### Test Execution Order
1. Run P0 tests first (critical path)
2. Run P1 tests next (core functionality)
3. Run P2 tests (edge cases)
4. Run P3 tests if time permits

### Pass/Fail Criteria
- **P0 Tests:** 100% pass required for release
- **P1 Tests:** 95% pass required for release
- **P2 Tests:** 80% pass recommended
- **P3 Tests:** Nice to have

### Bug Severity Levels
- **Critical:** P0 test failure - blocks release
- **High:** P1 test failure - must fix before release
- **Medium:** P2 test failure - should fix
- **Low:** P3 test failure - can defer

---

## Known Issues and Workarounds

### Issue #1: USB Cable Not Detected Immediately
**Symptom:** USB chip doesn't appear for 5-10 seconds after cable plugged in
**Root Cause:** Darwin notification delay
**Workaround:** Wait for notification, or restart app
**Fix Priority:** P2

### Issue #2: WiFi Discovery Slow on First Launch
**Symptom:** WiFi bridges take > 10 seconds to appear
**Root Cause:** Bonjour startup delay
**Workaround:** Tap "Restart Discovery" button
**Fix Priority:** P3

### Issue #3: Connection Chip Visibility After Quit
**Symptom:** USB chip remains visible after Bridge app quits
**Root Cause:** `connectedComputerName` not cleared to keep chip visible
**Workaround:** This is intentional behavior for better UX
**Fix Priority:** N/A (by design)

---

## Automation Opportunities

### Automatable Tests
- TC-001: Basic USB Connection (UI testing)
- TC-003: Basic WiFi Connection (UI testing)
- TC-104: Unplug/Replug USB Cable (with hardware control)
- TC-301: MIDI Message Flood (performance testing)
- TC-302: Long-Duration Connection (soak testing)

### Manual Testing Required
- TC-101, TC-102: Sleep/Wake tests (requires physical action)
- TC-202: USB Cable Partially Connected (requires physical manipulation)
- TC-203: iPad Locked Screen (requires physical action)
- Most P2 tests (require specific environmental conditions)

### Test Framework Recommendations
- **XCTest:** For unit testing individual components
- **XCUITest:** For UI automation of connection flows
- **Network Link Conditioner:** For simulating poor network conditions
- **Instruments:** For memory leak detection and performance monitoring

---

## Appendix A: Connection State Diagrams

### USB Connection State Machine
```
┌─────────────┐
│ Disconnected│
└──────┬──────┘
       │ Cable Plugged In
       │ (Darwin notification)
       ▼
┌─────────────┐
│  Listening  │
└──────┬──────┘
       │ Bridge Connects
       │ (NWListener.newConnectionHandler)
       ▼
┌─────────────┐
│ Connecting  │
└──────┬──────┘
       │ Handshake Sent (CB/2)
       │ Handshake Received (OK/2)
       ▼
┌─────────────┐
│  Connected  │◄─────┐
└──────┬──────┘      │
       │             │ Heartbeat OK
       │             │
       │ Cable Unplugged OR
       │ Bridge Quit OR
       │ Heartbeat Timeout
       ▼
┌─────────────┐
│ Disconnected│
└─────────────┘
```

### WiFi Connection State Machine
```
┌─────────────┐
│ Discovering │◄────────────────┐
└──────┬──────┘                 │
       │ User Taps Bridge        │ Discovery Refresh
       │                         │ (30s timer)
       ▼                         │
┌─────────────┐                 │
│ Connecting  │                 │
└──────┬──────┘                 │
       │ TCP Connected          │
       │ Pairing Complete       │
       ▼                         │
┌─────────────┐                 │
│  Connected  │◄─────┐          │
└──────┬──────┘      │          │
       │             │ Health OK│
       │             │          │
       │ User Disconnects OR    │
       │ Network Error OR       │
       │ Health Check Fails     │
       ▼                         │
┌─────────────┐                 │
│ Disconnected│─────────────────┘
└─────────────┘
```

---

## Appendix B: Key Log Messages Reference

### Critical Success Messages
| Log Message | Meaning | Action |
|-------------|---------|--------|
| `🔗 USB Listener ready on 9360` | USB server started successfully | Verify chip appears |
| `🔗 USB: Connection established with [Name]` | USB handshake complete | Connection ready |
| `✅ WiFi connection established` | WiFi connected successfully | Connection ready |
| `🔌 ConnectionCoordinator: Updated activeConnection to .usb` | USB is now active connection | USB has priority |

### Critical Error Messages
| Log Message | Meaning | Action |
|-------------|---------|--------|
| `❌ USB Listener failed: Error Domain=...EADDRINUSE` | Port conflict | Wait and retry |
| `🔗 MacConnectionManager: Handshake timed out; reconnecting` | Bridge not responding | Check Bridge app |
| `🔧 IProxyManager: ❌ No iOS device connected` | Cable not connected | Check physical connection |
| `🔄 BridgeOutput: Connection appears stale` | WiFi connection dead | Automatic reconnection |

---

## Appendix C: Performance Benchmarks

### Expected Latency
- **USB Connection:** 5-10ms RTT (round-trip time)
- **WiFi Connection:** 10-50ms RTT (depends on network)
- **Message Batching:** 10ms timeout, 5 messages per batch

### Expected Connection Times
- **USB Connection Establishment:** < 5 seconds
- **WiFi Connection Establishment:** < 8 seconds
- **Reconnection After Sleep (USB):** < 15 seconds
- **Reconnection After Sleep (WiFi):** < 10 seconds

### Resource Usage
- **Memory (Idle):** < 50 MB
- **Memory (Active Connection):** < 100 MB
- **CPU (Idle):** < 1%
- **CPU (MIDI Flood):** < 20%
- **Network Bandwidth (WiFi):** < 100 KB/s typical

---

## Appendix D: Test Report Template

### Test Report Header
```
Test ID: TC-XXX
Test Name: [Test Name]
Date: [YYYY-MM-DD]
Tester: [Name]
App Version: [Version Number]
iOS Version: [iOS Version]
Mac Version: [macOS Version]
```

### Test Results
```
Status: [PASS / FAIL / BLOCKED / SKIPPED]
Duration: [MM:SS]
Iterations: [Number of times run]
```

### Test Details
```
Initial State: [Describe actual initial state]
Steps Executed: [List steps performed]
Observed Behavior: [Describe what happened]
Deviations: [Any differences from expected behavior]
```

### Logs and Evidence
```
Key Log Messages:
[Paste relevant log snippets]

Screenshots:
[Attach if applicable]

Video Recording:
[Link if applicable]
```

### Issues Found
```
Issue #1: [Description]
Severity: [Critical / High / Medium / Low]
Reproducible: [Always / Sometimes / Once]
Workaround: [If available]
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-11 | Claude | Initial comprehensive test plan |

---

## Sign-Off

**Test Plan Approved By:**
- Engineering Lead: _______________
- QA Lead: _______________
- Product Owner: _______________

**Date:** _______________
