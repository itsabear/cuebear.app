# Cue Bear Bridge - Documentation Index

## Quick Navigation

### Start Here
- **New to the project?** → Read [EXPLORATION_SUMMARY.md](EXPLORATION_SUMMARY.md) (high-level overview, 10 min read)
- **Need specific info?** → Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (lookup guide, searchable)
- **Deep technical dive?** → Study [COMPREHENSIVE_ARCHITECTURE.md](COMPREHENSIVE_ARCHITECTURE.md) (complete reference, 30 min read)

---

## Documentation Files

### 1. EXPLORATION_SUMMARY.md (11KB)
**High-level architectural overview - Best for onboarding and presentations**

| Section | Purpose |
|---------|---------|
| What This App Does | 5 main features overview |
| Architecture Highlights | 4-layer architecture + communication paths |
| Key Design Patterns | Reactive programming, thread safety, event-driven |
| Data Flow Example | iPad MIDI to DAW journey |
| Critical Components | BridgeApp, MacConnectionManager, WifiServer, IProxyManager, ConnectionSecurity |
| Most Impressive Features | Smart reconnection, zombie detection, system integration |
| Code Quality | Strengths, known fixes, future improvements |
| Performance Characteristics | Memory, CPU, latency profiles |

**Best for:** Understanding design, getting team up to speed, presentations  
**Read time:** 10-15 minutes

---

### 2. QUICK_REFERENCE.md (8.2KB)
**Quick lookup guide for specific components and issues**

| Section | Purpose |
|---------|---------|
| Core Concept | Component overview |
| Key Components | Brief description of each major component |
| Message Protocol | CB/2 protocol and MIDI message formats |
| Thread Safety | Matrix of protection mechanisms |
| Connection Lifecycle | State machine diagram |
| Reconnection Strategy | Backoff timing and reset triggers |
| File Locations | Size and purpose of each file |
| Important State Variables | Key @Published and private variables |
| Security Safeguards | Rate limits, validation, fingerprinting |
| Common Issues & Solutions | Troubleshooting guide |
| Debugging Tips | Tools and techniques |

**Best for:** Quick lookups, troubleshooting, code review  
**Read time:** 5 minutes per section

---

### 3. COMPREHENSIVE_ARCHITECTURE.md (33KB)
**Complete technical deep-dive for engineering teams**

| Section | Purpose |
|---------|---------|
| Executive Summary | What the bridge does and how |
| App Architecture | App structure, lifecycle, state management |
| USB Bridge System | IProxyManager, USBMuxdMonitor, USB flow |
| MIDI Output System | MIDIManager, virtual ports, MIDI conversion |
| Connection Management | MacConnectionManager, CB/2 protocol, reconnection |
| IPC and Networking | Protocol details, WiFi server, MIDI routing |
| UI and Menu Bar | Menu bar interface, logs window |
| Login Item Management | SMAppService, auto-launch |
| Key Components | Component diagram, responsibilities, summary |
| Security Architecture | ConnectionSecurity, rate limiting, validation |
| Data Flow Diagrams | Startup, connection, MIDI, sleep/wake flows |
| Implementation Details | Bug fixes, performance optimizations |
| File Organization | Directory structure, dependencies |
| Deployment Considerations | Code signing, bundling, requirements |

**Best for:** Deep technical understanding, system design, protocol design  
**Read time:** 30-45 minutes

---

### 4. README_EXPLORATION.md (11KB)
**Meta-guide for using all exploration documents**

| Section | Purpose |
|---------|---------|
| Overview | Project summary |
| Generated Documentation | What each document covers |
| Key Findings | Architecture, technologies, routing, features, bugs fixed |
| Component Summary | Table of all components with sizes |
| State Machine Diagram | App startup and connection states |
| MIDI Data Flow Example | Complete example with latency |
| Security Implementation | Rate limits, validation, thread safety |
| Performance Profile | Memory, CPU, latency, reconnection speed |
| Deployment Status | Version, OS requirements, entitlements |
| Repository Structure | File organization |
| How to Use These Documents | Guide for different use cases |

**Best for:** Navigation guide, understanding what's documented, finding what you need  
**Read time:** 10 minutes

---

## Use Cases

### "I need to understand the architecture"
1. Read EXPLORATION_SUMMARY.md (15 min)
2. Review COMPREHENSIVE_ARCHITECTURE.md → "Data Flow Diagrams" section (10 min)
3. Reference QUICK_REFERENCE.md as needed for specifics (5 min)

**Total: 30 minutes**

---

### "I need to fix a bug"
1. Check QUICK_REFERENCE.md → "Common Issues & Solutions" (2 min)
2. Review component details in QUICK_REFERENCE.md (5 min)
3. Deep dive into relevant section in COMPREHENSIVE_ARCHITECTURE.md (10 min)
4. Check implementation details in COMPREHENSIVE_ARCHITECTURE.md (5 min)

**Total: 22 minutes**

---

### "I'm onboarding a new engineer"
1. Start with EXPLORATION_SUMMARY.md (15 min)
2. Review QUICK_REFERENCE.md → "Key Components" section (10 min)
3. Walk through COMPREHENSIVE_ARCHITECTURE.md → "Data Flow Diagrams" together (15 min)
4. Provide QUICK_REFERENCE.md as reference material for future lookups

**Total: 40 minutes**

---

### "I need to present this to the team"
1. Use EXPLORATION_SUMMARY.md as presentation outline
2. Include diagrams from COMPREHENSIVE_ARCHITECTURE.md
3. Key talking points:
   - 4-layer architecture
   - Smart reconnection strategy
   - USB/WiFi dual paths
   - Thread-safe state management
   - Security measures

**Prep time: 20 minutes**

---

### "I'm reviewing code changes"
1. Reference QUICK_REFERENCE.md for component overview (5 min)
2. Check COMPREHENSIVE_ARCHITECTURE.md for affected component (10 min)
3. Review "Critical Bugs Fixed" for known issues (5 min)
4. Check thread safety matrix in QUICK_REFERENCE.md (3 min)

**Total: 23 minutes**

---

## Key Concepts At a Glance

### Architecture Layers
```
UI Layer          → MenuBarView + ContentView
State Layer       → BridgeApp (@Published properties)
Service Layer     → Managers (Connection, MIDI, WiFi, etc.)
System Layer      → libusbmuxd, CoreMIDI, Network Framework
```

### Communication Paths
```
iPad USB   → iproxy:8077 → MacConnectionManager
iPad WiFi  → Bonjour:8078 → WifiServer
Both       → Virtual MIDI Ports → DAW
```

### Smart Reconnection
```
Attempts 1-5:   1s delay   (5 sec total)
Attempts 6-15:  3s delay   (30 sec more)
Attempts 16+:   10s delay  (unlimited)
```

### Message Protocol (CB/2)
```
Handshake:  "CB/2 auth=psk1 name=MacName\n"
Response:   "OK/2 hmac=<value>\n"
MIDI:       {"type":"midi_cc","channel":1,"cc":7,"value":100}\n
Heartbeat:  {"type":"heartbeat","source":"mac_bridge","timestamp":123456}\n
```

### Security
```
Rate Limit:     20 attempts/min per device, 100 msgs/sec per device
Validation:     channels 1-16, cc/note 0-127, velocity 0-127
Fingerprint:    SHA256(endpoint.description)
```

---

## Document Statistics

| File | Size | Lines | Focus |
|------|------|-------|-------|
| EXPLORATION_SUMMARY.md | 11KB | 300 | High-level |
| QUICK_REFERENCE.md | 8.2KB | 250 | Lookup |
| COMPREHENSIVE_ARCHITECTURE.md | 33KB | 1114 | Technical |
| README_EXPLORATION.md | 11KB | 300 | Navigation |
| **Total Documentation** | **63.2KB** | **~1964** | **Complete** |

**Source Code Size:** ~176KB (13 Swift files)  
**Documentation Ratio:** ~36% of code size (excellent coverage)

---

## Files Documented

### Source Files (13 total)
- CueBearBridgeApp.swift (42KB, 1200+ lines)
- MacConnectionManager.swift (30KB, 600+ lines)
- IProxyManager.swift (14KB, 350+ lines)
- ConnectionSecurity.swift (12KB, 350+ lines)
- MIDIManager.swift (7.5KB, 220+ lines)
- USBMuxdMonitor.swift (4.6KB, 180+ lines)
- LoginItemManager.swift (3.6KB, 120+ lines)
- MenuBarView.swift (2.6KB, 100+ lines)
- ContentView.swift (2.8KB, 100+ lines)
- Plus 4 smaller files (headers, config, helpers)

### Configuration Files
- Info.plist (app bundle config)
- CueBearBridge.entitlements (security config)
- CueBearBridge-Bridging-Header.h (C interop)

---

## Recommended Reading Order

### For Different Roles

**Product Manager**
1. EXPLORATION_SUMMARY.md (What This App Does + Features)
2. README_EXPLORATION.md (Key Findings)

**Software Engineer**
1. EXPLORATION_SUMMARY.md (Architecture Highlights)
2. QUICK_REFERENCE.md (all sections)
3. COMPREHENSIVE_ARCHITECTURE.md (as needed)

**DevOps / Deployment**
1. README_EXPLORATION.md (Deployment Status)
2. QUICK_REFERENCE.md (Security Safeguards)
3. COMPREHENSIVE_ARCHITECTURE.md (Deployment Considerations)

**QA / Troubleshooting**
1. QUICK_REFERENCE.md (Common Issues & Solutions)
2. COMPREHENSIVE_ARCHITECTURE.md (Implementation Details)

**New Team Member**
1. README_EXPLORATION.md (Overview)
2. EXPLORATION_SUMMARY.md (full read)
3. QUICK_REFERENCE.md (bookmark for reference)
4. COMPREHENSIVE_ARCHITECTURE.md (study over time)

---

## Quick Answers

**Q: How does MIDI get from iPad to DAW?**  
A: See COMPREHENSIVE_ARCHITECTURE.md → "10.3 MIDI Message Flow (iPad → Mac → DAW)"

**Q: Why does the app lose connection?**  
A: See QUICK_REFERENCE.md → "Common Issues & Solutions"

**Q: How are messages validated?**  
A: See COMPREHENSIVE_ARCHITECTURE.md → "9. Security Architecture"

**Q: What happens when Mac wakes from sleep?**  
A: See COMPREHENSIVE_ARCHITECTURE.md → "10.5 System Sleep/Wake Flow"

**Q: What are the rate limits?**  
A: See QUICK_REFERENCE.md → "Security Safeguards"

**Q: How does reconnection work?**  
A: See QUICK_REFERENCE.md → "Reconnection Strategy" + COMPREHENSIVE_ARCHITECTURE.md → "4.4 Smart Reconnection"

**Q: What's the protocol format?**  
A: See QUICK_REFERENCE.md → "Message Protocol" + COMPREHENSIVE_ARCHITECTURE.md → "5.1 USB Connection Protocol"

---

## Feedback

These documents were generated through thorough exploration of the codebase on November 6, 2025.

For accuracy issues or suggestions for improvement, refer to the specific section in the relevant document.

---

**Start reading:** Choose from the four documents above based on your needs and role.

**Navigation:** Use this file as an index to find what you're looking for quickly.

**Questions?** Refer to the appropriate document section listed above.

