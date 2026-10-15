//
//  ContentView+Actions.swift — Cue Bear
//  ContentView: Actions, v1.3, Tutorial Resume, Regular Mode Navigation, Bluetooth Pedal
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - Actions
    func trigger(_ song: Song) {
        let id = song.id.uuidString

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: song.kind, channel: song.channel, number: song.kind == .cc ? song.cc : (song.note ?? 60), value: song.kind == .cc ? 127 : song.velocity, label: song.name, buttonID: id)

        // Trigger flash animation on the cue row
        flashingCueID = song.id
        // Clear the flash trigger after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            flashingCueID = nil
        }

        // Update last played cue for play icon indicator
        lastPlayedCueID = song.id

        UISelectionFeedbackGenerator().selectionChanged()
    }

    func triggerControl(_ b: ControlButton) {
        var value: Int
        var updatedButton = b

        if b.isToggle == true {
            // Toggle behavior: flip state and send appropriate value
            updatedButton.toggleState.toggle()
            value = updatedButton.toggleState ? (b.kind == .cc ? 127 : b.velocity) : 0
        } else {
            // Momentary behavior: send fixed value
            value = b.kind == .cc ? 127 : b.velocity
        }

        // Use global channel if enabled, otherwise use button's channel
        let channelToUse = isGlobalChannel ? globalChannel : b.channel

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: b.kind, channel: channelToUse, number: b.number, value: value, label: b.title, buttonID: b.id.uuidString)
        
        // Update the button state in the controlButtons array if it's a toggle
        if b.isToggle == true {
            if let index = controlButtons.firstIndex(where: { $0.id == b.id }) {
                controlButtons[index] = updatedButton
            }
        }
        
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func sendFaderMIDI(channel: Int, cc: Int, value: Int, title: String, buttonID: UUID) {
        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
    }

    // MARK: - v1.3 (Cue Bear Next) helpers

    /// First-run checklist: sends a recognisable test message so the user can see it arrive in the DAW.
    func sendFirstRunTest() {
        let channelToUse = isGlobalChannel ? globalChannel : 1
        connectionCoordinator.sendMIDI(type: .note, channel: channelToUse, number: 60, value: 100,
                                       label: "Cue Bear test", buttonID: "cuebear-first-run-test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            connectionCoordinator.sendMIDI(type: .note, channel: channelToUse, number: 60, value: 0,
                                           label: "Cue Bear test", buttonID: "cuebear-first-run-test")
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// "Copy extras to other songs": each target song gets its own copies (new IDs).
    func copyExtras(_ extras: [SongExtra], toSongIDs ids: [UUID]) {
        guard !extras.isEmpty, !ids.isEmpty else { return }
        for id in ids {
            guard var target = store.activeSongs.first(where: { $0.id == id })
                    ?? songLibrary.first(where: { $0.id == id }) else { continue }
            var merged = target.extras ?? []
            for e in extras where !merged.contains(where: { $0.title == e.title && $0.number == e.number }) {
                var copy = e
                copy.id = UUID()
                merged.append(copy)
            }
            target.extras = merged
            saveSong(target)
        }
        saveIfNamed()
    }

    /// Saves straight away when the show already has a name; otherwise just marks it changed
    /// (no name prompt popping up over a sheet).
    func saveIfNamed() {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isUntitledProject(trimmed) {
            isDirty = true
        } else {
            saveCurrentProject(overwrite: true)
        }
    }

    func cueGo() {
        guard let s = store.cuedSong else { return }
        trigger(s)
        if let i = store.activeSongs.firstIndex(where: { $0.id == s.id }),
           i + 1 < store.activeSongs.count {
            store.cuedSong = store.activeSongs[i + 1]
        }
        // If on last song, stay on it (don't set to nil)
    }

    func selectPreviousCued() {
        guard let cued = store.cuedSong,
              let i = store.activeSongs.firstIndex(where: { $0.id == cued.id }),
              i > 0 else { return }
        store.cuedSong = store.activeSongs[i - 1]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectNextCued() {
        if let cued = store.cuedSong, let i = store.activeSongs.firstIndex(where: { $0.id == cued.id }) {
            guard i + 1 < store.activeSongs.count else { return }
            store.cuedSong = store.activeSongs[i + 1]
        } else if !store.activeSongs.isEmpty {
            // If nothing cued yet, select first
            store.cuedSong = store.activeSongs.first
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Tutorial Resume
    /// Resumes a tutorial that was interrupted by nav pill or cue capsule tutorial
    func resumeInterruptedTutorial() {
        guard let interrupted = interruptedTutorial else { return }
        interruptedTutorial = nil

        // Small delay to let the capsule tutorial fully dismiss, then use queue system
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch interrupted {
            case 1: self.requestTutorial(1)
            case 2: self.requestTutorial(2)
            case 3: self.requestTutorial(21)  // 21 = tutorial 2b
            case 4: self.requestTutorial(22)  // 22 = tutorial 2c
            case 5:
                // Skip if control area already open (user found it themselves)
                if !self.effectivelyCollapsedForOverlay {
                    self.hasSeenTutorial3 = true
                } else {
                    self.requestTutorial(3)
                }
            default: break
            }
        }
    }

    // MARK: - Regular Mode Navigation (for Navigation Capsule)
    func currentSongIndex() -> Int {
        return max(0, min(lastTriggeredSongIndex, store.activeSongs.count - 1))
    }

    func triggerNext() {
        guard !store.activeSongs.isEmpty else { return }
        // Prevent going past the last song
        guard lastTriggeredSongIndex < store.activeSongs.count - 1 else { return }
        let nextIndex = lastTriggeredSongIndex + 1
        lastTriggeredSongIndex = nextIndex
        let song = store.activeSongs[nextIndex]
        trigger(song)
    }

    func triggerPrevious() {
        guard !store.activeSongs.isEmpty else { return }
        // Prevent going before the first song
        guard lastTriggeredSongIndex > 0 else { return }
        let prevIndex = lastTriggeredSongIndex - 1
        lastTriggeredSongIndex = prevIndex
        let song = store.activeSongs[prevIndex]
        trigger(song)
    }

    // MARK: - Bluetooth Pedal Handlers
    // These functions handle pedal input intelligently based on the current mode

    func handlePedalNext() {
        if store.mode == .cue {
            // In Cue mode: move the chosen cue down the list
            selectNextCued()
        } else {
            // In Regular/Navigator mode: trigger next song
            triggerNext()
        }
    }

    func handlePedalPrevious() {
        if store.mode == .cue {
            // In Cue mode: move the chosen cue up the list
            selectPreviousCued()
        } else {
            // In Regular/Navigator mode: trigger previous song
            triggerPrevious()
        }
    }
}
