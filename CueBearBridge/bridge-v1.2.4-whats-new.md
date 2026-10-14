# CueBear Bridge v1.2.4

## What's New

### Secure Wi-Fi pairing
- **Approve your iPad once**: the first time an iPad connects over Wi-Fi, the Mac shows a 6-digit code. Click Allow if it matches the code on the iPad. After that it connects automatically.
- **Nobody else can send MIDI**: other devices on the network can no longer send MIDI to your DAW, or take over the connection from a paired iPad.
- **New Security section** in the menu: see the lock status, turn **Require pairing** on or off, and **Forget Paired iPads**.

### Faster, more reliable USB
- **Direct USB**: the Bridge now talks to the iPad over USB itself, without the separate iproxy helper. It's on by default and can be switched off in the menu.
- **Seamless USB and Wi-Fi handover** (with Cue Bear 1.2.1 on the iPad): pull the cable mid-show and MIDI carries on over Wi-Fi with no gap. Plug it back in and it returns to USB.
- **Dead connections are noticed**: heartbeats now actually run, so a lost iPad is detected within seconds.

### Fixes
- No more lost MIDI during fast fader moves (messages that arrived together were sometimes dropped).
- Notes from the DAW now reach the iPad as notes (they arrived as CC 0 before).
- MIDI from the DAW is read correctly when several messages arrive at once.

## Compatibility
- Works with Cue Bear 1.2.1 for pairing and seamless handover.
- Older Cue Bear iPad apps keep working until the first iPad is paired with this Mac. After that, update the iPad app.

## Technical Details
- Universal binary (Intel & Apple Silicon)
- Notarized and signed
- Compatible with macOS 13.0+

## Installation
1. Download CueBear-Bridge-v1.2.4.dmg
2. Open the DMG
3. Drag CueBear Bridge to Applications folder
4. Launch from Applications

---
*Version 1.2.4*
