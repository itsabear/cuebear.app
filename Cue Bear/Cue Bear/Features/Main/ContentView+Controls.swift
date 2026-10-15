//
//  ContentView+Controls.swift — Cue Bear
//  ContentView: Control functions
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // Control area is now always shown as overlay (see mainStack overlay)
    // No longer need bottomSectionView

    // MARK: - Control functions
    func controlRowCount() -> Int {
        // Grid triples columns; normal buttons occupy 3, faders 2 (2 grid squares wide).
        let slotsPerRow = max(3, controlsPerRow * 3)
        let totalSlots = controlButtons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(totalSlots) / Double(slotsPerRow)))
    }

    
    // Update fader value from DAW MIDI input
    func updateFaderFromDAW(channel: Int, cc: Int, value: Int) {
        debugPrint("🎚️ updateFaderFromDAW: Looking for fader with channel=\(channel), cc=\(cc), value=\(value)")
        debugPrint("🎚️ Available faders:")
        for (index, button) in controlButtons.enumerated() {
            if button.isFader == true {
                debugPrint("🎚️   Fader \(index): \"\(button.title)\" - channel=\(button.channel), cc=\(button.number)")
            }
        }
        
        // Find the fader that matches this MIDI channel and CC
        if let index = controlButtons.firstIndex(where: { button in
            button.isFader == true && button.channel == channel && button.number == cc
        }) {
            // Convert MIDI value (0-127) to fader value (0.0-1.0)
            let faderValue = Double(value) / 127.0
            
            debugPrint("🎚️ ✅ Found matching fader \"\(controlButtons[index].title)\" at index \(index)")
            debugPrint("🎚️ Updated fader \"\(controlButtons[index].title)\" to \(faderValue) from DAW MIDI")
            
            // Store the fader value in the ControlButton model for persistence
            controlButtons[index].faderValue = faderValue
            markDirty() // Mark project as dirty to save the fader value
            
            // Post notification for the fader tile to update its visual value
            NotificationCenter.default.post(
                name: Notification.Name("cbUpdateFaderFromDAW"),
                object: nil,
                userInfo: [
                    "buttonID": controlButtons[index].id.uuidString,
                    "value": faderValue
                ]
            )
        } else {
            debugPrint("🎚️ ❌ No matching fader found for channel=\(channel), cc=\(cc)")
        }
    }

    func canAddMoreControls() -> Bool {
        return controlRowCount() < maxControlRows
    }

    func addControl() {
        // Legacy helper kept if needed elsewhere: directly append a default control
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        var new = ControlButton(title: "Custom", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127)
        if autoAssignControlColors {
            let usedColors = Set(controlButtons.compactMap { $0.colorHex })
            let available = curatedColorPalette.filter { !usedColors.contains($0) }
            new.colorHex = available.randomElement() ?? curatedColorPalette.randomElement()
        }
        controlButtons.append(new)
        invalidateConflictCache()
        markDirty()
    }

    func beginAddControl() {
        // Prepare a default control for editing (do not append yet)
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        let draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil)
        editingControl = draft
        pendingAddIsFader = false
        showControlEditor = true
    }

    enum AddKind { case button, fader }

    func beginAddControlOfType(_ kind: AddKind) {
        debugPrint("🎹 [ADD CONTROL] beginAddControlOfType called with kind: \(kind)")
        // FIX: Skip filtered CC numbers and MIDI already taken by cues or controls
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        debugPrint("🎹 beginAddControlOfType: Found free CC = \(freeCC)")
        var draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil, page: currentControlPage)
        switch kind {
        case .button:
            draft.isFader = false
            draft.isSmall = false
            draft.title = nextDefaultControlName("Button")
            debugPrint("🎹 [ADD CONTROL] Creating button draft on page \(currentControlPage)")
        case .fader:
            draft.isFader = true
            draft.isSmall = false
            draft.symbol = "" // no icon for fader
            draft.title = nextDefaultControlName("Fader")
            debugPrint("🎹 [ADD CONTROL] Creating fader draft on page \(currentControlPage)")
        }
        editingControl = draft
        // Hint the editor about fader mode
        pendingAddIsFader = (kind == .fader)
        debugPrint("🎹 [ADD CONTROL] Setting showControlEditor = true")
        showControlEditor = true
        debugPrint("🎹 [ADD CONTROL] showControlEditor is now: \(showControlEditor)")
    }

    func deleteControl(_ btn: ControlButton) {
        pushControlUndo()
        controlButtons.removeAll { $0.id == btn.id }
        invalidateConflictCache()
        markDirty()
    }

    @ViewBuilder
    var contentView: some View {
        ZStack {
            mainStack()
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .focusable()  // Required to receive keyboard input from Bluetooth pedals
                .focusEffectDisabled()  // Hide the blue focus indicator lines
                // Bluetooth pedal support (Airturn BT500 and similar devices)
                .onKeyPress(.upArrow) {
                    debugPrint("🎹 Up Arrow pressed")
                    handlePedalPrevious()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    debugPrint("🎹 Down Arrow pressed")
                    handlePedalNext()
                    return .handled
                }
                .onKeyPress(.pageUp) {
                    debugPrint("🎹 Page Up pressed")
                    handlePedalPrevious()
                    return .handled
                }
                .onKeyPress(.pageDown) {
                    debugPrint("🎹 Page Down pressed")
                    handlePedalNext()
                    return .handled
                }
                // MARK: - Tutorial Overlays
                .overlay {
                    ZStack {
                        // Tutorial 1: Edit button (after onboarding)
                        if showTutorial1 && editButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Open edit mode to add your first cue",
                                targetFrame: editButtonFrame,
                                onDismiss: {
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2: + button (after clicking Edit)
                        if showTutorial2 && addCueButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Tap + to add your first cue",
                                targetFrame: addCueButtonFrame,
                                onDismiss: {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    if !hasSeenTutorial2b {
                                        pendingTutorial = 21  // 21 = tutorial 2b
                                    }
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2b: Library button (after tutorial 2 or adding cue)
                        if showTutorial2b && libraryButtonFrame != .zero {
                            UpwardTutorial(
                                message: "All your cues live in the cue library.",
                                targetFrame: libraryButtonFrame,
                                onDismiss: {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2c: Cue list name button
                        if showTutorial2c && cueListNameButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Create as many cue lists as you want",
                                targetFrame: cueListNameButtonFrame,
                                onDismiss: {
                                    showTutorial2c = false
                                    hasSeenTutorial2c = true
                                    if !hasSeenTutorial3 {
                                        pendingTutorial = 3
                                    }
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2c = false
                                    hasSeenTutorial2c = true
                                    if !hasSeenTutorial3 {
                                        pendingTutorial = 3
                                    }
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 3: Controls capsule (contextual: 3+ cues in active list)
                        if showTutorial3 && controlsCapsuleFrame != .zero {
                            DownwardTutorial(
                                message: "Add buttons and faders for extra MIDI control",
                                targetFrame: controlsCapsuleFrame,
                                onDismiss: {
                                    showTutorial3 = false
                                    hasSeenTutorial3 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial3 = false
                                    hasSeenTutorial3 = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 4 (two-finger scroll) removed
                    }
                    .animation(.easeInOut(duration: 0.3), value: showTutorial1)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2b)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2c)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial3)
                    .onChange(of: showTutorial1) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial1 changed to \(newValue), editButtonFrame=\(editButtonFrame), frame != .zero: \(editButtonFrame != .zero)")
                    }
                    .onChange(of: showTutorial2) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2 changed to \(newValue), addCueButtonFrame=\(addCueButtonFrame)")
                    }
                    .onChange(of: showTutorial2b) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2b changed to \(newValue), libraryButtonFrame=\(libraryButtonFrame)")
                    }
                    .onChange(of: showTutorial2c) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2c changed to \(newValue), cueListNameButtonFrame=\(cueListNameButtonFrame)")
                    }
                    .onChange(of: showTutorial3) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial3 changed to \(newValue), controlsCapsuleFrame=\(controlsCapsuleFrame)")
                    }
                    // Tutorial 4 onChange removed
                    .onChange(of: showCueListChooser) { _, isShowing in
                        if isShowing && showTutorial2c {
                            // Dismiss tutorial 2c when user opens cue list chooser
                            showTutorial2c = false
                            hasSeenTutorial2c = true
                        }
                        if !isShowing && hasSeenTutorial2c && !hasSeenTutorial3 {
                            // Skip tutorial 3 if control area is already open
                            if !effectivelyCollapsedForOverlay {
                                hasSeenTutorial3 = true
                            } else {
                                // Queue Tutorial 3 after cue list chooser closes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.requestTutorial(3)
                                }
                            }
                        }
                    }
                    .onChange(of: showLibraryPopover) { _, isShowing in
                        // Dismiss tutorial 2b when user opens song library
                        if isShowing && showTutorial2b {
                            showTutorial2b = false
                            hasSeenTutorial2b = true
                            onTutorialDismissed()
                        }
                    }
                }

            if showSplash {
                SplashScreen()
                    .transition(.opacity)
                    .ignoresSafeArea()
                    .zIndex(1)
            }
        }
    }
}
