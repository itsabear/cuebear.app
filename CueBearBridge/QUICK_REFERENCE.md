# Cue Bear Bridge - Quick Reference Guide

## Core Concept
Bidirectional bridge between iPad and Mac enabling USB/WiFi connectivity and MIDI routing.

```
iPad (USB) ↔ iproxy:8077 ↔ MacConnectionManager ↔ Virtual MIDI Ports ↔ DAW
iPad (WiFi) ↔ Bonjour discovery ↔ WifiServer:8078 ↔ Virtual MIDI Ports ↔ DAW
```

---

## Key Components

### BridgeApp (CueBearBridgeApp.swift)
- Central state container with @Published properties
- Coordinates all subsystems
- Subscribes to all component publishers for UI updates
- Entry point for start/stop operations

### IProxyManager (IProxyManager.swift)
- Manages iproxy process (USB port forwarding)
- Detects device attach/detach via libusbmuxd
- Handles sleep/wake cycles
- Auto-restarts on crash with exponential backoff

### MacConnectionManager (MacConnectionManager.swift)
- Establishes/maintains TCP connection to iPad via iproxy
- Implements CB/2 handshake protocol
- Smart reconnection with backoff (1s → 3s → 10s)
- Sends 2-second heartbeat to detect stale connections
- Receives MIDI from iPad, forwards to WifiServer

### WifiServer (CueBearBridgeApp.swift)
- Listens for iPad WiFi connections on :8078
- Processes MIDI messages (CC, Note, batch)
- Validates via ConnectionSecurity
- Sends 2-second heartbeat, monitors for zombie connections
- Converts between JSON and MIDI formats

### MIDIManager (MIDIManager.swift)
- Creates virtual MIDI source: "Bear Bridge" (iPad → DAW)
- Creates virtual MIDI destination: "Bear Bridge" (DAW → iPad)
- Converts raw MIDI bytes ↔ JSON format
- Cleanup on shutdown via MIDIEndpointDispose

### ConnectionSecurity (ConnectionSecurity.swift)
- Rate limits connections: 20/minute per device
- Rate limits messages: 100/second per device
- Validates MIDI messages (channel 1-16, cc/note 0-127, velocity 0-127)
- Sanitizes input, rejects invalid/oversized batches
- Device fingerprinting via SHA256

### LoginItemManager (LoginItemManager.swift)
- Uses SMAppService (macOS 13+ modern API)
- Enables/disables "Open at Login"
- Persists preference in UserDefaults
- Defaults to OFF on first launch

---

## Message Protocol

### CB/2 Protocol (TCP over iproxy:8077)
```
Mac → iPad: "CB/2 auth=psk1 name=MacBook-Pro\n"
iPad → Mac: "OK/2 hmac=<value>\n"
```

### MIDI Message Format
```json
{
  "type": "midi_cc",
  "channel": 1,
  "cc": 7,
  "value": 100
}
```

```json
{
  "type": "midi_note",
  "channel": 1,
  "note": 60,
  "velocity": 100
}
```

### Heartbeat
```json
{
  "type": "heartbeat",
  "source": "mac_bridge|wifi_bridge",
  "timestamp": 1699234567
}
```

---

## Thread Safety

| Component | Protection | Mechanism |
|-----------|-----------|-----------|
| MacConnectionManager | State flags | NSLock on connecting, didSendHandshake, rxBuffer, connID |
| IProxyManager | Process reference | NSLock on process object |
| WifiServer | State enum | NSLock on state in acceptConnection() |
| ConnectionSecurity | Shared counters | DispatchQueue(serial) for atomic state access |
| Logger | Line array | Dispatch to main queue |

---

## Connection Lifecycle

```
START
  ↓
IProxyManager.start() → starts iproxy process
  ↓
USBMuxdMonitor detects iPad (device attached event)
  ↓
iproxy opens port 8077 to iPad
  ↓
Combine: iproxy.$boundLocalPort publisher fires
  ↓
BridgeApp triggers: conn.waitAndConnect()
  ↓
MacConnectionManager.connect(port: 8077)
  ├→ Create NWConnection to localhost:8077
  ├→ State: .ready
  ├→ sendHandshake() + receiveLoop()
  └→ iPad responds with OK/2
  ↓
Connection confirmed
  ├→ Start heartbeat sending (2s interval)
  ├→ Update UI: "USB: Connected"
  └→ Listen for MIDI messages
```

---

## Reconnection Strategy

| Attempt | Delay | Duration | Purpose |
|---------|-------|----------|---------|
| 1-5 | 1s | 5s total | Fast device readiness |
| 6-15 | 3s | 30s more | Gradual slowdown |
| 16+ | 10s | Unlimited | Persistent retry |

**Reset triggers:**
- Successful connection
- Device mount event
- System wake event
- Device disconnect

---

## File Locations

| File | Size | Purpose |
|------|------|---------|
| CueBearBridgeApp.swift | 42KB | Main app + BridgeApp + WifiServer + Bonjour |
| MacConnectionManager.swift | 30KB | USB connection + reconnection logic |
| ConnectionSecurity.swift | 12KB | Security validation + rate limiting |
| MIDIManager.swift | 7.5KB | Virtual MIDI ports |
| IProxyManager.swift | 14KB | iproxy process + USB monitoring |
| USBMuxdMonitor.swift | 4.6KB | libusbmuxd wrapper |
| LoginItemManager.swift | 3.6KB | SMAppService wrapper |
| MenuBarView.swift | 2.6KB | Menu bar UI |
| ContentView.swift | 2.8KB | Debug logs UI |
| Logger.swift | 0.7KB | Centralized logging |
| ConnectionSecurity.swift | 12KB | Rate limiting + validation |

---

## Important State Variables

### BridgeApp
- `status`: "Idle" → "Running" → "Error"
- `usbStatus`: "USB: idle" → "USB: Looking for iPad" → "USB: Connected"
- `iproxyStatus`: "iproxy: idle" → "iproxy: Running"
- `wifiStatus`: "WiFi: idle" → "WiFi: Listening" → "WiFi: Connected"
- `isRunning`: iproxy process running
- `isConnected`: iPad connected via USB
- `midiReady`: Virtual MIDI ports created
- `midiActivity`: MIDI message received (visual flash)

### MacConnectionManager
- `connecting`: TCP connection in progress
- `didSendHandshake`: Handshake sent, waiting for response
- `reconnectPending`: Reconnect timer scheduled
- `consecutiveReconnectFailures`: Retry counter (increments, resets on success)
- `rxBuffer`: Accumulates received bytes until newline
- `connID`: UUID to detect stale connections

### WifiServer
- `state`: stopped → starting → listening → connected
- `isConnected`: iPad connected via WiFi
- `connection`: NWConnection to iPad (nil if disconnected)
- `lastHeartbeatReceived`: Used for zombie detection (> 60s disconnects)

---

## Security Safeguards

1. **Rate Limiting:**
   - 20 connection attempts per minute per device
   - 100 MIDI messages per second per device

2. **Message Validation:**
   - Type-check all JSON fields
   - Range-check: channels 1-16, cc/note 0-127, velocity 0-127
   - Reject unknown keys (return only validated fields)

3. **Device Fingerprinting:**
   - SHA256 hash of endpoint string
   - Per-device rate limiting tracking

4. **Batch Protection:**
   - Max 50 messages per batch
   - Each individually validated

5. **Zombie Detection:**
   - WiFi: No heartbeat > 60s → disconnect
   - USB: Heartbeat timeout (iPad side)

---

## Deployment

### Requirements
- macOS 13.0+ (SwiftUI + SMAppService)
- Xcode 15+
- iproxy binary (bundled or system-installed)

### Code Signing Entitlements
- `com.apple.security.device.usb` - iPad USB access
- `com.apple.security.device.audio-input` - MIDI
- `com.apple.security.network.server` - WiFi listener
- `com.apple.security.network.client` - WiFi connection
- `com.apple.security.cs.allow-dyld-environment-variables` - Bundled dylibs
- `com.apple.security.cs.disable-library-validation` - Bundled libraries

### Hardened Runtime
- `LSUIElement=true` (menu bar app, no dock icon)
- No App Sandbox (would block USB access)

---

## Known Limitations & Future Improvements

1. **USB Only at Startup:** First connection requires USB (WiFi for fallback after)
2. **Single iPad:** App designed for one iPad at a time
3. **Local Network Only:** Bonjour discovery limited to local network
4. **No Encryption:** CB/2 protocol sends plaintext (local network assumed secure)
5. **Manual Port Override:** No UI to change listening port

---

## Debugging Tips

1. **Enable Logs Window:** Always visible in menu bar extra
2. **Manual Start/Stop:** Test buttons in logs window
3. **MIDI Test:** "Test MIDI" button sends CC to virtual port
4. **UDID Targeting:** Optional field to force specific iPad (auto-detect default)

---

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "USB: Looking for iPad" persists | iproxy not running | Check system for iproxy binary |
| iPad not responding | Handshake timeout (3s) | Fast retry kicks in, check iPad app |
| No MIDI in DAW | Virtual source not created | Check MIDIManager.createVirtualSourceIfNeeded() |
| WiFi won't connect | Bonjour not discovered | Check firewall + local network |
| App crashes on quit | iproxy not stopped | Fixed: AppDelegate.applicationWillTerminate() |

