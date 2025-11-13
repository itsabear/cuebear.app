# Cue Bear Bridge macOS App - Comprehensive Architecture Analysis

**Version:** v1.2.0  
**Platform:** macOS 13.0+ (SwiftUI)  
**Primary Language:** Swift  
**App Type:** Menu Bar Application

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [App Architecture](#app-architecture)
3. [USB Bridge System](#usb-bridge-system)
4. [MIDI Output System](#midi-output-system)
5. [Connection Management](#connection-management)
6. [IPC and Networking](#ipc-and-networking)
7. [UI and Menu Bar](#ui-and-menu-bar)
8. [Login Item Management](#login-item-management)
9. [Key Components](#key-components)
10. [Security Architecture](#security-architecture)
11. [Data Flow Diagrams](#data-flow-diagrams)

---

## Executive Summary

Cue Bear Bridge is a sophisticated macOS menu bar application that acts as a bidirectional bridge between an iPad and Mac. It enables:

- **USB Connection Management:** Bridges iPad USB connections via iproxy/usbmuxd to enable local TCP communication on port 8077
- **WiFi Streaming:** Provides optional WiFi connectivity for iPad-Mac communication via Bonjour service discovery
- **MIDI Routing:** Creates virtual MIDI ports on Mac to receive MIDI from iPad and route it to DAW applications
- **Intelligent Reconnection:** Implements automatic reconnection with smart backoff strategies
- **Sleep/Wake Handling:** Gracefully manages system sleep/wake cycles
- **Auto-Launch:** Supports "Open at Login" functionality via SMAppService

The app follows an event-driven architecture with reactive subscriptions, thread-safe state management, and comprehensive security validation.

---

## 1. App Architecture

### 1.1 App Structure

**Application Entry Point:** `CueBearBridgeApp` (SwiftUI `@main`)

The app is structured as a menu bar extra app (no main window) with optional debugging window:

```swift
@main
struct CueBearBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var app = BridgeApp()

    var body: some Scene {
        MenuBarExtra("Cue Bear Bridge", image: "BearPawIcon") {
            MenuBarView()
                .environmentObject(app)
        }
        .menuBarExtraStyle(.window)
        
        // Debug/logs window
        WindowGroup("Bridge Logs") {
            ContentView()
                .environmentObject(app)
        }
        .windowStyle(.titleBar)
        .defaultPosition(.topTrailing)
    }
}
```

### 1.2 App Lifecycle

**AppDelegate Responsibilities:**
- Manages application termination lifecycle
- Ensures iproxy is properly stopped when app quits
- Maintains reference to BridgeApp for cleanup coordination

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var bridgeApp: BridgeApp?

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("🔧 App: applicationWillTerminate - stopping iproxy")
        bridgeApp?.iproxy.stop(manual: false)
    }
}
```

### 1.3 Core State Management (BridgeApp Class)

**BridgeApp** is the central Observable state container managing:

```swift
final class BridgeApp: ObservableObject {
    @Published var status: String = "Idle"
    @Published var usbStatus: String = "USB: idle"
    @Published var iproxyStatus: String = "iproxy: idle"
    @Published var wifiStatus: String = "WiFi: idle"
    @Published var localPort: UInt16?
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var midiReady: Bool = false
    @Published var midiActivity: Bool = false

    let iproxy = IProxyManager()
    private var conn: MacConnectionManager!
    let midi = MIDIManager()
    let wifiServer = WifiServer()
    let bonjour = BridgeBonjour()
    let loginItemManager: LoginItemManager
    
    private var cancellables: Set<AnyCancellable> = []
    private var midiActivityTimer: Timer?
}
```

**Key Design Decisions:**
- **Eager Initialization:** `MacConnectionManager` initialized immediately (not lazy) to prevent issues with weak references
- **Combine Subscriptions:** Set up in `setupSubscriptions()` during `init()` BEFORE any services start, ensuring UI updates are never missed
- **Reactive Flow:** All major component status changes flow through Combine publishers

---

## 2. USB Bridge System

### 2.1 Overview

The USB bridge system chains together three components to enable iPad-Mac communication:

```
iPad (USB) → usbmuxd → iproxy (localhost:8077) → MacConnectionManager (TCP)
```

### 2.2 IProxyManager - USB Device Forwarding

**Location:** `/IProxyManager.swift`

**Responsibilities:**
- Start/stop bundled iproxy helper process
- Monitor USB device attachment/detachment
- Auto-restart iproxy on system wake
- Manage port forwarding from iPad USB port 9360 to localhost:8077

**Key Features:**

1. **Bundled iproxy Discovery (Priority-based):**
   ```swift
   private func findBundledIproxy() -> String? {
       // Priority 1: Check bundled iproxy in app bundle (self-contained)
       // Priority 2: Check system paths (/usr/local/bin/iproxy)
       // Priority 3: Check Homebrew path (/opt/homebrew/bin/iproxy)
   }
   ```

2. **USB Device Monitoring via libusbmuxd:**
   - Subscribes to USB device events using `usbmuxd_events_subscribe()`
   - Detects device attach/detach events
   - Automatically starts iproxy when iOS device is attached
   - Stops iproxy when device is detached

3. **Sleep/Wake Monitoring:**
   - Listens for `NSWorkspace.willSleepNotification`
   - Stops iproxy during sleep
   - Restarts iproxy after wake with 2-second delay
   - Posts `iproxyDidRestartAfterWake` notification to trigger connection attempts

4. **Auto-restart on Crash:**
   - Detects unexpected process termination (non-zero exit codes)
   - Implements exponential backoff (2s, 4s, 6s) for up to 3 attempts
   - Prevents restart if exit code is 9 (SIGKILL) or 15 (SIGTERM)

5. **Thread Safety:**
   - Uses `NSLock` to protect process state access
   - Manages process lifecycle safely across thread boundaries

**Process Arguments:**
```swift
let proc = Process()
proc.executableURL = URL(fileURLWithPath: iproxyPath)
proc.arguments = ["8077", "9360"]  // Forward localhost:8077 to device port 9360
```

### 2.3 USBMuxdMonitor - Device Detection

**Location:** `/USBMuxdMonitor.swift`

**Responsibilities:**
- Wraps libusbmuxd C library for Swift
- Provides event-driven device attach/detach notifications
- Checks for already-connected devices on startup

**Event Handling:**
```swift
case Int32(UE_DEVICE_ADD.rawValue):
    // iOS device attached - trigger callback
case Int32(UE_DEVICE_REMOVE.rawValue):
    // iOS device detached - trigger callback
case Int32(UE_DEVICE_PAIRED.rawValue):
    // iOS device paired
```

**Key Implementation Details:**
- Static callback function to keep reference alive across C interop
- Unmanaged memory management for C callback context
- Device list refresh on startup to detect pre-connected devices
- Serial dispatch queue (`com.cuebear.usbmuxd`) to prevent race conditions

---

## 3. MIDI Output System

### 3.1 Overview

Cue Bear Bridge implements bidirectional MIDI routing:

```
iPad (MIDI out) → Bridge (receives) → Mac virtual MIDI source → DAW
DAW (MIDI out) → Bridge (receives) → virtual MIDI destination → iPad (MIDI in)
```

### 3.2 MIDIManager - Virtual MIDI Ports

**Location:** `/MIDIManager.swift`

**Responsibilities:**
- Create and manage virtual MIDI source (for iPad → DAW)
- Create and manage virtual MIDI destination (for DAW → iPad)
- Convert between raw MIDI bytes and JSON format
- Clean up MIDI devices on shutdown

**Virtual MIDI Port Creation:**

1. **MIDI Source** (iPad sends MIDI out → appears in DAW):
   ```swift
   func createVirtualSourceIfNeeded() {
       // Creates MIDIClientRef if needed
       let result = MIDISourceCreate(client, "Bear Bridge" as CFString, &midiSource)
       // Result: DAW can see "Bear Bridge" as MIDI input device
   }
   ```

2. **MIDI Destination** (DAW sends MIDI out → captured by Bridge):
   ```swift
   func createVirtualDestinationIfNeeded() {
       // Creates callback for receiving MIDI
       MIDIDestinationCreate(client, "Bear Bridge" as CFString, 
                            callback, refCon, &destination)
       // Result: DAW can send MIDI to "Bear Bridge"
   }
   ```

**MIDI Message Conversion:**

Raw MIDI bytes → JSON:
```swift
let status = bytes[0]
let data1 = bytes[1]
let data2 = bytes[2]

// Parse message type and channel
let messageType = status & 0xF0  // 0xB0 = CC, 0x90 = Note On
let channel = Int(status & 0x0F)

// Convert to JSON
let jsonDict: [String: Any] = [
    "type": "midi_cc",           // or "midi_note"
    "channel": channel,
    "cc": data1,
    "value": data2
]
```

**Cleanup:**
```swift
func cleanup() {
    // Remove virtual MIDI source
    if midiSource != 0 {
        MIDIEndpointDispose(midiSource)
    }
    // Remove virtual MIDI destination
    if destination != 0 {
        MIDIEndpointDispose(destination)
    }
    // Dispose MIDI client
    if client != 0 {
        MIDIClientDispose(client)
    }
}
```

**Thread Safety:**
- Incoming MIDI callbacks dispatch to main queue for processing
- All state mutations happen on main thread
- Uses `Unmanaged` for safe C callback memory management

---

## 4. Connection Management

### 4.1 MacConnectionManager - USB Connection Handler

**Location:** `/MacConnectionManager.swift`

**Responsibilities:**
- Establish and maintain TCP connection to iPad via iproxy
- Send/receive CB/2 handshake protocol
- Detect and handle connection failures
- Implement intelligent reconnection with smart backoff
- Forward MIDI messages to/from iPad
- Monitor system events (sleep/wake, USB device mount)

### 4.2 Connection Lifecycle

**State Machine:**

```
IDLE
  ↓
waitAndConnect()
  ↓ (iproxy ready on port 8077)
connect(port: 8077)
  ↓ (creates TCP connection)
Connecting
  ↓ (NWConnection state: .ready)
sendHandshake()
  ├→ Waiting for CB/2 handshake response
  │   ├→ Receive "OK/2 hmac=..." → Connected
  │   ├→ Timeout (3s) → Reconnect
  │   └→ Connection error → Reconnect
  └→ Reconnecting (with backoff)
```

### 4.3 Connection Establishment (CB/2 Protocol)

**Handshake Exchange:**

1. **Mac sends:**
   ```swift
   let handshakeMessage = "CB/2 auth=psk1 name=\(displayName)\n"
   // Example: "CB/2 auth=psk1 name=MacBook-Pro\n"
   ```

2. **iPad responds:**
   ```
   OK/2 hmac=<hmac_value>
   ```

3. **On successful response:**
   - Cancel handshake timeout
   - Mark connection as ready
   - Start heartbeat sending (2-second interval)
   - Begin receive loop

### 4.4 Smart Reconnection with Backoff

**Reconnection Strategy:**

```swift
let delay: TimeInterval = {
    if consecutiveReconnectFailures <= 5 {
        return 1.0      // Fast retry: attempts 1-5 (5 seconds total)
    } else if consecutiveReconnectFailures <= 15 {
        return 3.0      // Medium retry: attempts 6-15 (30 seconds more)
    } else {
        return 10.0     // Slow retry: attempts 16+ (unlimited backoff)
    }
}()
```

**Benefits:**
- Fast retries for quick device readiness detection
- Gradual slowdown to avoid overwhelming iPad after sleep/wake
- No hard limit on retry attempts (unlimited persistence)

**Reset Conditions:**
- Successful connection → reset counter to 0
- Device mounted event → reset counter to 0
- System wake event → reset counter to 0
- Device disconnect → reset counter to 0

### 4.5 Event-Driven USB Device Monitoring

**File Mount Detection:**
```swift
usbDeviceObserver = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didMountNotification,
    object: nil,
    queue: .main
) { [weak self] notification in
    self?.handleUSBDeviceMounted(notification)
}
```

When iPad (e.g., "/Volumes/iPad") is mounted:
- Reset failure counter to 0
- Stop any pending reconnect timer
- Wait 0.5s for iproxy to start
- Attempt immediate connection

### 4.6 Heartbeat for Disconnection Detection

**Purpose:** Detect stale connections that appear open but are actually dead

```swift
private func startHeartbeatSending() {
    heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        self?.sendHeartbeat()
    }
}

private func sendHeartbeat() {
    let heartbeat: [String: Any] = [
        "type": "heartbeat",
        "source": "mac_bridge",
        "timestamp": Int(Date().timeIntervalSince1970)
    ]
    // Send as JSON + newline
}
```

**iPad Response:**
- iPad receives heartbeat
- iPad responds with its own heartbeat
- If no response, connection times out and reconnects

### 4.7 Thread Safety

**State Protection with NSLock:**
```swift
private let stateLock = NSLock()

// Protect critical state flags
stateLock.lock()
let isConnecting = connecting
stateLock.unlock()

// Prevent race conditions during rapid reconnects
```

**Protected State:**
- `connecting` - connection attempt in progress
- `didSendHandshake` - handshake already sent
- `reconnectPending` - reconnect scheduled
- `rxBuffer` - receive buffer for parsing lines
- `connID` - connection ID for stale connection detection

---

## 5. IPC and Networking

### 5.1 USB Connection Protocol

**Protocol:** CB/2 (Cue Bear Protocol Version 2)

**Message Format:** 
```
JSON message\n
```

Each message is JSON followed by newline delimiter for line-based parsing.

**Message Types:**

| Type | Direction | Purpose | Payload |
|------|-----------|---------|---------|
| `handshake` | Mac → iPad | Initiate connection | `auth=psk1 name=<mac_name>` |
| `OK/2` | iPad → Mac | Handshake response | `hmac=<value>` |
| `heartbeat` | Bidirectional | Keep-alive signal | `type, source, timestamp` |
| `midi_cc` | Both | Control Change | `channel, cc, value` |
| `midi_note` | Both | Note On/Off | `channel, note, velocity` |
| `midi_input` | Both | Raw MIDI | `midi: [status, data1, data2]` |
| `batch` | Both | Multiple MIDI | `messages: [...]` |
| `switch_to_wifi` | iPad → Mac | Switch protocol | Triggers WiFi connection |

### 5.2 WiFi Connection (Alternative Path)

**Purpose:** Enable WiFi-based connection for environments where USB isn't practical

**Architecture:**
```
iPad (WiFi) → Bridge WiFi Server (localhost:8078) → Bridge WiFi Connection Manager
```

**Bonjour Service Discovery:**
```swift
let netService = NetService(domain: "local.", 
                           type: "_cuebear._tcp.", 
                           name: displayName, 
                           port: Int32(8078))
```

iPad discovers Bridge automatically via Bonjour and can connect to port 8078.

**WiFi Server Features:**

1. **NWListener for Incoming Connections:**
   - Listens on localhost:8078
   - Accepts iPad WiFi connections
   - Validates connection via `ConnectionSecurity`

2. **MIDI Routing:**
   - Receives MIDI from iPad via WiFi
   - Converts to virtual MIDI port output
   - Forwards DAW MIDI to iPad

3. **Heartbeat & Health Monitoring:**
   - Sends heartbeat every 2 seconds
   - Monitors for heartbeat responses
   - Detects zombie connections (no heartbeat > 60s)
   - Cleans up stale connections

4. **Batch Message Processing:**
   - Receives multiple MIDI messages in single batch
   - Processes individually to maintain responsiveness

### 5.3 MIDI Forwarding Flow

**iPad → Mac (USB):**
```
iPad sends JSON → iproxy → localhost:8077 → MacConnectionManager receives
→ Validates with ConnectionSecurity
→ Forwards to WiFi server
→ MIDIManager sends to virtual MIDI source
→ DAW receives MIDI from "Bear Bridge"
```

**DAW → iPad (USB):**
```
DAW sends MIDI to "Bear Bridge" → MIDIManager receives
→ Converts to JSON
→ Sends to WiFi server via notification
→ WiFi server wraps as JSON + newline
→ Sends to iPad via TCP connection
```

**Rate Limiting:**
- WiFi server: 100 messages/second (per device)
- Connection attempts: 20/minute (per device)
- Batch messages: Max 50 messages per batch

---

## 6. UI and Menu Bar

### 6.1 Menu Bar Interface

**File:** `/MenuBarView.swift`

**Layout:**
```
┌─────────────────────────┐
│ Cue Bear Bridge         │
│ v1.2.0                  │
├─────────────────────────┤
│ ● USB      Connected    │
│ ● WiFi     Listening    │
├─────────────────────────┤
│ Open at Login      [ON] │
├─────────────────────────┤
│ Quit                    │
├─────────────────────────┤
│ Created by Omri Behr    │
└─────────────────────────┘
```

**Status Indicators:**

| Color | Meaning |
|-------|---------|
| 🟢 Green | Connected/Ready |
| 🔵 Blue | Listening/Initializing |
| 🟡 Yellow | Disconnected/Idle |
| 🟠 Orange | Error/Failed |

**Menu Items:**
- Version display (cached, non-blocking)
- USB connection status
- WiFi connection status
- "Open at Login" toggle (macOS 13+)
- Quit button
- Creator credit

### 6.2 Debug Logs Window

**File:** `/ContentView.swift`

**Features:**
- Real-time log display
- Auto-scroll to newest entries
- Manual Start/Stop buttons
- Test MIDI button
- Optional UDID targeting
- Server port display

---

## 7. Login Item Management

**File:** `/LoginItemManager.swift`

**Technology:** SMAppService (modern macOS 13+ API)

**Features:**

1. **Status Tracking:**
   ```swift
   @Published var isEnabled: Bool = false
   ```

2. **Enable/Disable Operations:**
   ```swift
   func enable() -> Bool {
       try SMAppService.mainApp.register()
       UserDefaults.standard.set(true, forKey: "openAtLogin")
   }
   
   func disable() -> Bool {
       try SMAppService.mainApp.unregister()
       UserDefaults.standard.set(false, forKey: "openAtLogin")
   }
   ```

3. **First-Launch Behavior:**
   - Defaults to OFF on first launch
   - Persists user preference in UserDefaults
   - Syncs with system SMAppService status

4. **Status Messages:**
   - "App will open at login" (enabled)
   - "Requires approval in System Settings" (needs user action)
   - etc.

---

## 8. Key Components

### 8.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    CueBearBridgeApp (SwiftUI)               │
│                     MenuBarExtra + Logs Window               │
└────────────────┬────────────────────────────────────────────┘
                 │
         ┌───────▼────────────┐
         │   BridgeApp        │
         │  (Central State)   │
         ├────────────────────┤
         │ • USB Status       │
         │ • WiFi Status      │
         │ • iproxy Status    │
         │ • MIDI Ready       │
         │ • MIDI Activity    │
         └─┬──┬──┬──┬──┬─────┘
           │  │  │  │  │
        ┌──▼┐ │  │  │  │
        │ I │◄─┤  │  │  │
        │ P │  │  │  │  │
        │ro│  │  │  │  │
        │xy│  │  │  │  │
        └──┘  │  │  │  │
             ┌▼─┴──┴──┴──┴┐
             │MacConnection│
             │  Manager    │
             ├─────────────┤
             │• Connect    │
             │• Heartbeat  │
             │• Reconnect  │
             │• USB Events │
             └─────────────┘
             
        ┌──────────────────┐
        │ USBMuxdMonitor   │
        ├──────────────────┤
        │• Device events   │
        │• Attach/Detach   │
        └──────────────────┘
        
        ┌──────────────────┐
        │   WiFi Server    │
        ├──────────────────┤
        │• TCP Listener    │
        │• MIDI Routing    │
        │• Heartbeat       │
        │• Health Monitor  │
        └──────────────────┘
        
        ┌──────────────────┐
        │  MIDI Manager    │
        ├──────────────────┤
        │• Virtual Source  │
        │• Virtual Dest    │
        │• JSON Convert    │
        └──────────────────┘
        
        ┌──────────────────┐
        │ ConnectionSecur. │
        ├──────────────────┤
        │• Rate Limiting   │
        │• Validation      │
        │• Sanitization    │
        └──────────────────┘
```

### 8.2 Component Responsibilities

| Component | Purpose | Key Methods |
|-----------|---------|-------------|
| **BridgeApp** | Central state + coordination | `start()`, `stop()`, `triggerMIDIActivity()` |
| **IProxyManager** | USB forwarding | `start()`, `stop()`, device monitoring |
| **MacConnectionManager** | USB connection lifecycle | `waitAndConnect()`, `sendHandshake()`, `handleJSONLine()` |
| **USBMuxdMonitor** | Device detection | `start()`, `stop()`, event callbacks |
| **WifiServer** | WiFi communication | `start()`, `stop()`, `processReceivedData()` |
| **MIDIManager** | Virtual MIDI ports | `createVirtualSourceIfNeeded()`, `handleIncomingMIDI()` |
| **ConnectionSecurity** | Security validation | `validateConnection()`, `validateMessageRate()`, `validateAndSanitizeMIDIMessage()` |
| **LoginItemManager** | Auto-launch | `enable()`, `disable()`, `updateStatus()` |
| **Logger** | Centralized logging | `log()` |
| **BridgeBonjour** | Service discovery | `publish()`, `stop()` |

---

## 9. Security Architecture

### 9.1 ConnectionSecurity Singleton

**File:** `/ConnectionSecurity.swift`

**Threat Model:**
- Malicious local devices sending crafted MIDI messages
- Rate-based DoS attacks
- Invalid MIDI message formats
- Oversized batch messages

### 9.2 Security Measures

**1. Connection Rate Limiting:**
```swift
maxAttemptsPerMinute = 20
rateLimitWindow = 60 seconds

// Per-device tracking using SHA256 hash of endpoint
```

**2. Message Rate Limiting:**
```swift
maxMessagesPerSecond = 100
messageRateWindow = 1.0 second

// Per-device message counting with reset window
```

**3. Message Validation:**

**MIDI CC Message:**
- Channel: 1-16
- CC: 0-127
- Value: 0-127

**MIDI Note Message:**
- Channel: 1-16
- Note: 0-127
- Velocity: 0-127

**MIDI Input (Raw):**
- Status byte: 0xB0-0xBF (CC messages)
- Data1: 0-127
- Data2: 0-127

**Batch Message:**
- Max 50 messages per batch
- Each message individually validated

**4. Input Sanitization:**
```swift
func validateAndSanitizeMIDIMessage(_ json: [String: Any]) -> [String: Any]? {
    // Type-check all fields
    // Range-check all numeric values
    // Return only validated fields (reject unknown keys)
    // Return nil if validation fails
}
```

### 9.3 Device Fingerprinting

```swift
private func generateDeviceId(from endpoint: NWEndpoint) -> String {
    let endpointString = "\(endpoint)"
    let data = endpointString.data(using: .utf8) ?? Data()
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}
```

### 9.4 Thread Safety

All shared state accessed through:
- `NSLock` (synchronous)
- `DispatchQueue` (async/serial)

```swift
private let stateQueue = DispatchQueue(label: "com.cuebear.security.state", 
                                       qos: .userInitiated)

func validateMessageRate(for deviceId: String) -> Bool {
    stateQueue.sync {
        // Access shared state safely
    }
}
```

---

## 10. Data Flow Diagrams

### 10.1 App Startup Flow

```
App Launch
    ↓
CueBearBridgeApp created
    ↓
AppDelegate initialized
    ↓
BridgeApp initialized
    ├→ Create IProxyManager
    ├→ Create MacConnectionManager
    ├→ Create MIDIManager
    ├→ Create WifiServer
    ├→ Create BridgeBonjour
    ├→ Create LoginItemManager
    └→ setupSubscriptions() [CRITICAL: Before starting services]
    ↓
MenuBarView + ContentView rendered
    ↓
BridgeApp.start() [delayed 0.1s]
    ├→ Create virtual MIDI source/destination
    ├→ Setup WiFi server
    ├→ Publish Bonjour service
    └→ Start iproxy via IProxyManager
         ├→ USBMuxdMonitor detects iPad
         ├→ iproxy starts
         └→ iproxy listens on localhost:8077
         
[UI Updates via Combine Publishers]
```

### 10.2 Connection Establishment Flow

```
iproxy bound to port 8077
    ↓
Combine subscription triggers: iproxy.$boundLocalPort
    ↓
BridgeApp calls: conn.waitAndConnect()
    ↓
MacConnectionManager.waitAndConnect()
    ├→ Check: connection == nil AND not connecting
    ├→ Check: iproxy ready AND port available
    └→ Call: connect(to: 8077)
    ↓
create NWConnection to localhost:8077
    ↓
state = .ready (connection accepted)
    ├→ receiveLoop() starts
    └→ sendHandshake()
         └→ "CB/2 auth=psk1 name=Mac...\n"
    ↓
iPad receives handshake
    ├→ Validates Mac connection
    └→ Responds with "OK/2 hmac=..."
    ↓
MacConnectionManager receives "OK/2"
    ├→ Connection confirmed
    ├→ Start heartbeat sending
    ├→ Update UI: "USB: Connected"
    └→ Continue receive loop for MIDI
```

### 10.3 MIDI Message Flow (iPad → Mac → DAW)

```
User sends MIDI on iPad
    ↓
iPad sends via USB → iproxy → localhost:8077
    ↓
MacConnectionManager.receiveLoop()
    ├→ Receives JSON: { "type": "midi_cc", "channel": 1, "cc": 7, "value": 100 }
    ├→ Security validation
    └→ Call: handleMIDIMessage()
    ↓
Forward to WiFi server via NotificationCenter
    ↓
WifiServer.processMIDIMessage()
    ├→ Convert channel 1-based to 0-based
    └→ Call: sendMIDICC(channel: 0, cc: 7, value: 100)
    ↓
Create MIDI packet:
    [0xB0 | 0] = 0xB0  (CC on channel 0)
    [0x07] = CC 7 (Volume)
    [0x64] = Value 100
    ↓
MIDIReceived(midi.source, &packet)
    ↓
DAW receives from "Bear Bridge" virtual MIDI port
    └→ Adjusts volume to 100
```

### 10.4 MIDI Message Flow (DAW → Mac → iPad)

```
User sends MIDI in DAW
    ↓
DAW sends to "Bear Bridge" virtual destination
    ↓
MIDIManager.handleIncomingMIDI() callback
    ├→ Raw MIDI bytes: [0xB0, 0x01, 0x40]
    └→ Convert to JSON: { "type": "midi_cc", "channel": 0, "cc": 1, "value": 64 }
    ↓
WifiServer.onIncomingMIDI callback triggered
    ├→ Convert channel 0-based to 1-based
    ├→ Wrap in message: { "type": "midi_input", "midi": [0xB0, 0x01, 0x40] }
    └→ Send to iPad via TCP
    ↓
Send via both paths:
    ├→ WiFi connection (if connected)
    └→ USB connection (if connected)
    ↓
iPad receives JSON
    ├→ Parse MIDI message
    └→ Apply control to app
```

### 10.5 System Sleep/Wake Flow

```
System going to sleep
    ↓
NSWorkspace.willSleepNotification
    ↓
IProxyManager.handleSystemSleep()
    └→ stop(manual: false)
         ├→ Terminate iproxy process
         └→ Set isRunning = false
    ↓
MacConnectionManager connection cancelled
    ↓
[System sleeping...]
    ↓
System wakes up
    ↓
NSWorkspace.didWakeNotification
    ↓
IProxyManager.handleSystemWake() [after 2s delay]
    ├→ try start()
    └→ Notify MacConnectionManager via iproxyDidRestartAfterWake
    ↓
MacConnectionManager.handleIProxyRestartAfterWake()
    ├→ Reset failure counter to 0
    ├→ Get fresh reconnection attempts
    └→ Attempt connection if not already connecting
```

---

## 11. Important Implementation Details

### 11.1 Critical Bugs Fixed

**Fix Issue #10:** Main queue dispatch for @Published updates
- All @Published value updates must happen on main queue
- Use `DispatchQueue.main.async` for state changes

**Fix Issue #11 & #12:** NSLock for state protection
- Protect shared state access with NSLock
- Prevents race conditions during rapid reconnects
- Particularly important for `rxBuffer` and connection flags

**Fix Issue #13:** Process lifecycle management
- Protect process reference with NSLock
- Prevent dangling pointer dereferences
- Safe termination across thread boundaries

**Fix Issue #14:** Dedicated queue for security operations
- Use serial dispatch queue for ConnectionSecurity state
- Prevents race conditions in rate limiting
- All state mutations are atomic

**Fix Issue #15:** Logger dispatch optimization
- Remove double dispatch (was: serial queue → main queue)
- Dispatch directly to main queue from caller
- Reduces latency in high-volume logging

**Fix Issue #16:** State locking in WiFi server
- Protect state enum access with NSLock
- Prevent inconsistent state during rapid state changes
- Multiple threads accessing WifiServer state

### 11.2 Performance Optimizations

**1. Version String Caching:**
```swift
struct VersionHelper {
    static let cachedVersionString: String = {
        // Computed once at app launch
        // Prevents repeated bundle queries
    }()
}
```

**2. Fast Reconnection Detection:**
- 1-second timeout for handshake response
- If no response after 1s (connection ready but iPad not), fast retry
- Prevents hanging on zombie connections

**3. Port Binding Check (Non-aggressive):**
- Simple async check 2 seconds after iproxy start
- Non-blocking socket connection test
- Doesn't interfere with normal operation

**4. Minimal USB Device Monitoring:**
- Only subscribes to necessary events
- Avoids aggressive polling
- Event-driven rather than timer-based

---

## 12. File Organization

```
CueBearBridge/
├── CueBearBridgeApp.swift           # Main app entry, UI, BridgeApp, WiFi server, Bonjour
├── MacConnectionManager.swift       # USB connection lifecycle, reconnection logic
├── IProxyManager.swift              # iproxy process management, device monitoring
├── USBMuxdMonitor.swift             # libusbmuxd wrapper for device events
├── MIDIManager.swift                # Virtual MIDI ports creation/cleanup
├── WifiServer.swift                 # Embedded in CueBearBridgeApp.swift
├── ConnectionSecurity.swift         # Rate limiting, validation, sanitization
├── LoginItemManager.swift           # SMAppService for auto-launch
├── MenuBarView.swift                # Menu bar UI
├── ContentView.swift                # Debug logs window UI
├── Logger.swift                     # Centralized logging
├── VersionHelper.swift              # Version string caching
├── CueBearBridge-Bridging-Header.h  # C interop for libusbmuxd
├── CueBearBridge.entitlements       # Hardened runtime + security entitlements
├── Info.plist                       # App bundle configuration
└── README.md                        # Quick start guide
```

---

## 13. Dependencies

### 13.1 Swift Frameworks
- **SwiftUI** - UI framework (menu bar, logs window)
- **Combine** - Reactive programming (subscriptions, publishers)
- **Foundation** - Core Swift types
- **Network** - NWListener, NWConnection (TCP)
- **CoreMIDI** - Virtual MIDI port creation
- **AppKit** - Menu bar, app delegate, notifications
- **CryptoKit** - SHA256 hashing for device fingerprints
- **ServiceManagement** - SMAppService for auto-launch

### 13.2 System Frameworks
- **libusbmuxd** - C library for USB device monitoring (bridged via header)

### 13.3 Bundled Helpers
- **iproxy** - Binary for USB port forwarding
  - Must be made executable (chmod 755)
  - Included in app bundle: Contents/MacOS/iproxy
  - Located via fallback search: bundled → system → homebrew

---

## 14. Deployment Considerations

### 14.1 Code Signing & Notarization
- App must be code-signed with developer certificate
- Hardened runtime enabled (Info.plist LSUIElement=true)
- Entitlements required:
  - `com.apple.security.device.usb` (USB access)
  - `com.apple.security.device.audio-input` (MIDI)
  - `com.apple.security.network.server` (WiFi listening)
  - `com.apple.security.network.client` (WiFi connection)

### 14.2 Minimum Requirements
- **macOS:** 13.0+ (SwiftUI + SMAppService)
- **Xcode:** 15+
- **iproxy:** Bundled or system-installed

### 14.3 Installer Considerations
- Bundle iproxy binary with app
- Ensure iproxy is executable (755 permissions)
- Code-sign all bundled dylibs
- Run `codesign -s - --deep` on app bundle before distribution

---

## 15. Summary

Cue Bear Bridge is a sophisticated macOS menu bar utility that demonstrates:

1. **Complex State Management** - Combine publishers, reactive UI updates
2. **System Integration** - USB monitoring, sleep/wake handling, service discovery
3. **Audio Integration** - Virtual MIDI port creation and management
4. **Network Programming** - TCP connections, NWListener, protocol implementation
5. **Thread Safety** - NSLock protection, serial dispatch queues
6. **Security** - Input validation, rate limiting, device fingerprinting
7. **Error Handling** - Graceful degradation, smart reconnection logic
8. **Performance** - Caching, event-driven architecture, minimal polling

The architecture is modular, with clear separation of concerns between connection management, MIDI routing, security, and UI components. All major components communicate through well-defined interfaces (publishers, callbacks, notifications) rather than tight coupling.

