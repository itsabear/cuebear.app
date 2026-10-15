# CLAUDE.md: Cue Bear (read this first)

Update this file whenever an architectural decision is made or a major task finishes.

## 1. What Cue Bear is
- **Cue Bear (iPad app)**: a setlist MIDI controller for live shows. Songs ("cues") send a MIDI CC or note when fired (GO). There are also shared controls (buttons, toggles, faders) and a cue list per show.
- **Cue Bear Bridge (Mac menu-bar app)**: receives messages from the iPad and plays them out of a virtual MIDI port called **"Bear Bridge"** (`CueBearBridge/MIDIManager.swift`), which the DAW listens to. MIDI from the DAW goes back to the iPad: fader feedback and MIDI learn.
- **Cue Bear Next**: the relaunch version of the iPad app. It installs as a separate app next to the App Store app.

## 2. Where things are
- GitHub: `itsabear/cuebear.app`. **`main` is the cuebear.app website. Never push app code to it.**
- Branches:
  - `relaunch`: Cue Bear Next, active work.
  - `usb-cleanup`: the USB redesign plus Bridge 1.2.4; already contained in `relaunch`.
  - `release-1.2.1`.
- On Omri's Mac (Dropbox), two folders:
  - `~/Library/CloudStorage/Dropbox/SANDBOX/Cue Bear`: the main repo, branch `usb-cleanup`. The App Store app lives here.
  - `~/Library/CloudStorage/Dropbox/SANDBOX/Cue Bear Next`: a git **worktree** of that repo, branch `relaunch`. This file lives here.

## 3. How iPad and Mac talk
- **USB**: the Bridge relays `127.0.0.1:8077` on the Mac to port `9360` on the iPad through usbmuxd. This is `DirectUSBRelay` in `CueBearBridge/IProxyManager.swift`; iproxy is gone. On the iPad, `Connection/ConnectionManager.swift` listens on 127.0.0.1:9360.
- **Wi-Fi**: the Bridge publishes Bonjour `_cuebear._tcp.` on port 8078 (`CueBearBridgeApp.swift`). The iPad browses for it and connects (`Connection/BridgeOutput.swift`).
- **Messages**: newline-delimited JSON wrapped by `SecureLink` (`Connection/SecureLink.swift`, Bridge `ConnectionSecurity.swift`).
  - Types: `midi_cc`, `midi_note`, `transport`, `heartbeat`, auth/pairing.
  - DAW input reaches the iPad as `midi_input` and is posted as the notification `cbMIDIInputFromDAW`.
- **Pairing**: on first connect the Mac shows a 6-digit code to confirm. The iPad side of the window is `Connection/PairingOverlay.swift`.
- **Coordinator** (`Connection/ConnectionCoordinator.swift`):
  - USB always wins. Wi-Fi stays connected as a suspended standby while on USB (`connectStandby`, `isSuspended`).
  - An `isStaleUSB` guard stops a dead old USB link from overriding the live one.
  - A reconcile timer runs every 1 s.
- **Backup rig** (`Connection/BackupRigManager.swift`): a second `BridgeOutput` to another Mac. `ConnectionCoordinator.sendMIDI` mirrors every send to it. It ignores DAW input (`forwardsDAWInput = false`).

## 4. iPad app layout (`Cue Bear/Cue Bear/`, Swift + SwiftUI, iOS 17, iPad only)
- The Xcode project uses **folder-synchronized groups**: new files and folders are picked up automatically, with no pbxproj edits.
- `App/`: `CueBearApp.swift` (startup, DemoShows install, connections, `CBAppearance.apply()`), CrashReporter, Logger.
- `Design/`: the design foundation. See `DESIGN_FOUNDATION.md`.
  - `CBTokens.swift`: type scale, spacing, radii, colors, UIKit appearance.
  - `CBComponents.swift`: `.cbChip/.cbCard/.cbRow/.cbSheetChrome`, `CBSheetHeader`, `CBButtonStyle`, `CBPill`, `CBTag`...
  - `Components.swift`: older shared pieces (`CBSheetButton`, `CBDialog`, transport dock).
  - `AppTheme.swift` and `Color+CueBear.swift`.
- `Models/`: `Models.swift` (Song, SongExtra, MIDIKind), `ControlButton.swift`, `CueList.swift`, `SetListStore.swift`, `ProjectPayload.swift`.
- `Storage/`: ProjectIO and the document-based project files.
- `Connection/`: everything in section 3.
- `Features/Main/`:
  - `ContentView.swift` (the main screen, ~1,300 lines) plus `ContentView+*.swift` extensions: SideMenu, Controls, Presentation (all sheets), MIDI, Actions, Library, Undo, Projects.
  - `TopBar.swift`, `PerformanceList.swift`, `SetlistEditor.swift`, `SongLibraryPopover.swift`, `CueListChooser.swift`, `ConnectionsSheet.swift`, `BackupComputerSection.swift`, `ProjectsSheet.swift`, `NavigationCapsule.swift`, `Tutorials.swift`.
- `Features/Controls/`: the control area grid (`ControlArea.swift` plus `+Editing`/`+Pages`), control editor sheets, MIDI pickers, wobble.
- `Features/MIDI/MidiAssignments.swift`: the MIDI table and filters.
- `Features/ShowMode/ShowModeView.swift`: the stage screen. Pedals map to arrows, space and PageUp/PageDown.
- `Features/Songs/`:
  - `SongDetailsSheet.swift`: Notes & Extras, including MIDI learn.
  - `CueEditorSheet.swift`: add or edit a cue.
- `Features/Onboarding/`: `FirstRunView.swift` (self-ticking checklist, QR code, DAW guides) and `DemoShows.swift` (Club Night, Musical Theatre, Worship Sunday).
- `Features/Settings/` (About, Appearance, Bug report, ThemeAdminPanel in DEBUG) and `Features/Store/` (Paywall/Purchase; business model on hold).
- Song data:
  - Show-mode data per song: `notes`, `extras: [SongExtra]` and `rememberedLevels: [faderID: 0...127]`, all decoded with `decodeIfPresent`.
  - **Shared controls** are on every song; **extras** belong to one song.

## 5. Mac Bridge (`CueBearBridge/`, macOS 13)
- Main pieces: `CueBearBridgeApp.swift` (Wi-Fi server, Bonjour), `MacConnectionManager.swift` (USB side), `IProxyManager.swift` (DirectUSBRelay), `USBMuxdMonitor.swift`, `MIDIManager.swift`, `ConnectionSecurity.swift`, `MenuBarView.swift`.
- Version: `CueBearBridge/Info.plist`, currently **1.2.4**. It is signed, notarized as a DMG, and installed on Omri's Mac.

## 6. Current state (2026-10-15)
- **Works, tested by Omri:**
  - USB redesign: USB↔Wi-Fi handover, and staying on USB when both are up.
  - Bridge 1.2.4 DMG.
- **Written, not yet built in Xcode (unverified):** everything on `relaunch` after `151b940`:
  - the design foundation pass;
  - the folder restructure;
  - the ContentView and ControlSubviews split;
  - Show mode, Notes & Extras, backup rig, first run and demo shows.
  - Omri is fixing compile errors one round at a time; the last fix was `CBButtonStyle`'s inner view renamed from `Body`.
- **Known gap:** Show mode is a full-screen cover on top of the old perform screen. Two screens do the same job. Next step 1 fixes this.
- **Code-level checks only:** syntax only, with tree-sitter. No type checking or tests have run in the cloud.

## 7. Decisions (do not re-suggest the rejected ones)
- **Cue Bear Next is a separate app**: bundle `Omri-Behr.Cue-Bear.Next`, version 1.3.0, display name "Cue Bear Next", orange NEXT band on the icon. The App Store app is untouched.
- **iPad only** (`TARGETED_DEVICE_FAMILY = 2`). No iPhone yet.
- **Bridge stays.** "No Bridge app" (talking straight to the DAW from the iPad) is postponed to the future, not now.
- **USB through usbmuxd DirectUSBRelay.** iproxy and its flags were removed; don't bring them back.
- **Per-song setup is minimal:** shared controls apply to all songs. A song only adds notes, extras and remembered fader levels. This answers "too much work to set things for every song".
- **Two computers at once** is done with a backup Mac over Wi-Fi that mirrors every send. Only the main Mac moves the iPad's faders.
- **No business model yet.** Pricing and the paywall are left as they are.
- **Design: one foundation first, the real design language later.**
  - Everything uses Sora, `CBColor`, `CBRadius` and the type scale. No literal sizes, system colors or system sheet toolbars in new UI.
  - The look is a deliberately plain dark skeleton.
- **The default theme is forced on launch** (`selectedThemeID = "default"` in `ContentView+Presentation.swift`), so the genre themes are effectively off.
- **New UI structure (agreed 2026-10-15, mock-ups in Artifact "Cue Bear Next: Show & Build")**:
  - Two modes, switched by **Show | Build** in the top bar.
  - **Show** becomes the home screen and replaces the old perform screen and floating GO dock. It shows the setlist, Now/Next/GO and the shared controls plus this song's extras, with a **Lock** button.
  - **Build** has a left panel with tabs (Setlist / Controls / Library) and an inspector on the right. The inspector replaces the Edit Cue sheet and the Notes & Extras sheet.
  - Undecided:
    - whether Lock also hides the mode switch;
    - whether portrait support is needed (the window is currently fixed at 1024×768).

## 8. Conventions
- Swift/SwiftUI. Before writing UI, read `DESIGN_FOUNDATION.md` for the rules (tokens, `CBSheetHeader` plus `.cbSheetChrome()`, one primary button per screen).
- **New code goes in feature folders** as small files. Don't grow `ContentView.swift`; add a `ContentView+X.swift` extension or a new view.
- Members of `ContentView`/`CBControlSection` are internal, not `private`, so extensions in other files can reach them. Keep it that way.
- Commits:
  - author Omri Behr <omribehr@gmail.com>;
  - end messages with the Co-Authored-By and Claude-Session lines;
  - write commit messages in plain English.
- **Build the iPad app**: in Xcode, scheme "Cue Bear", target an iPad, ⌘R.
  - Signing: team 2U78NYVLQN. If you see "No profiles for Omri-Behr.Cue-Bear.Next", go to Xcode › Settings › Accounts, sign in again, then Signing & Capabilities › Try Again.
- **xcodebuild on the Mac** needs the full Xcode: prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Bridge release**: bump `CueBearBridge/Info.plist`, then run `CueBearBridge/CueBearBridgeInstaller/release_dmg.sh`.
  - It needs the "Developer ID Application" certificate and the notarytool profile `cuebear-notarize`.
  - It builds, signs, notarizes and staples `dist/CueBear-Bridge-v<version>.dmg`.

## 9. Moving code between the cloud session and the Mac
- `git fetch`/`pull` on the Dropbox mount crashes (Bus error / FETCH_HEAD deadlock). Don't use them there.
- **Cloud → Mac**:
  1. `git format-patch` in the cloud.
  2. Copy the patches to the Mac.
  3. In `SANDBOX/Cue Bear Next`, run `git am`.
  4. Check that `git rev-parse HEAD^{tree}` matches on both sides.
- **Mac → GitHub**: push from the cloud clone (it has push access to `itsabear/cuebear.app`). For commits made only on the Mac, use a git bundle.
- **Lock files and stray `rebase-apply`**: git on the mount needs delete permission. If a stray `.git/worktrees/Cue-Bear-Next/rebase-apply` blocks `git am`, `mv` it out of the way, because `rm` can fail on Dropbox.
- **Worktree path quirks**:
  - The worktree's `.git` file uses a relative path (`gitdir: ../Cue Bear/.git/worktrees/Cue-Bear-Next`).
  - The back-pointer is the Mac's absolute path.
  - The worktree is locked. Don't `git worktree prune`.

## 10. Next steps (priority order)
1. Get `relaunch` building in Xcode (fix errors as Omri pastes them).
2. Build the Show | Build structure from the mock-ups:
   - Show as home, with Lock.
   - Build's Setlist, Controls and Library tabs plus the inspector.
   - Retire the old perform screen, the GO dock and the Edit Cue / Notes & Extras sheets.
3. Then run the test list in `CUE_BEAR_NEXT.md` on the iPad. That covers Show mode, extras, the backup Mac and first run.
4. Later:
   - the real design language (in `Design/` only);
   - resizable windows for iPadOS 27;
   - Program Change (needs a Bridge change too);
   - "Use on every song" (turn an extra into a shared control);
   - pricing.

## 11. Gotchas
- **Security**: a password was once committed in `QUICKSTART_OMRI.md` and pushed to the public repo. It's a placeholder now, and Omri confirmed no app-specific passwords are active. Never commit credentials.
- **Actor isolation** (Swift 5 mode, but Xcode still flags it): `PairingWindowPresenter` is main-actor isolated. Call it from Combine sinks inside `Task { @MainActor in … }`.
- **Show-mode faders** send through `cbFaderChanged` and keep the main screen in sync with `cbUpdateFaderFromDAW` (notifications), not by calling into ContentView directly.
- **Legacy tutorial code**:
  - Tutorial state (`hasSeenTutorial*`, `Tutorials.swift`) is still wired in, but the tutorials are retired: closing Getting started sets every flag.
  - The purple/blue tutorial gradient was replaced with `CBColor.highlight`.
- **Fixed window size**: `CueBearApp` fixes the window at 1024×768 (`sizeRestrictions`).
- **`@_exported import Foundation`** in `Design/Color+CueBear.swift` is intentional; it was there before. Removing it may break files that rely on it (unverified).
- **Unused bundled project**: `Beethoven Live.cuebearproj` is referenced in the pbxproj but excluded from the target and unused (demo shows replaced it). It was left in place to avoid editing the pbxproj.
- **Older docs**: the many `*.md` files at the repo root (DESIGN_SYSTEM.md, plans, changelogs) are older. `DESIGN_FOUNDATION.md` and this file are current.
