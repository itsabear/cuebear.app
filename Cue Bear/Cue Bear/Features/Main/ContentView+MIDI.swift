//
//  ContentView+MIDI.swift — Cue Bear
//  ContentView: Conflict map, Global Channel
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - Conflict map (always use cached version to prevent main thread blocking)
    func conflictLookup() -> [MIDIKey: String] {
        // FIX: NEVER compute synchronously during rendering - this was causing app freeze
        // Always return cached value (even if empty). The cache will be populated
        // asynchronously by .task modifiers within ~500ms
        // Empty cache temporarily shows no conflicts, which is acceptable vs freezing the app
        return cachedConflictLookup
    }

    func computeConflictLookup() -> [MIDIKey: String] {
        var multiMap: [MIDIKey: [String]] = [:]

        // Songs in setlist + library (deduplicate by ID to avoid counting same song twice)
        var seenSongIDs = Set<UUID>()
        for s in (store.activeSongs + songLibrary) {
            // Skip if we've already processed this song ID
            guard !seenSongIDs.contains(s.id) else { continue }
            seenSongIDs.insert(s.id)

            let key = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc,   channel: s.channel, number: s.cc)
            multiMap[key, default: []].append(s.name)
        }

        // Control buttons - add type prefix for clarity
        for b in controlButtons {
            let typePrefix: String
            if b.isFader == true {
                typePrefix = "Fader"
            } else {
                typePrefix = "Button"
            }
            let displayName = b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            multiMap[MIDIKey(kind: b.kind, channel: b.channel, number: b.number), default: []].append(displayName)
        }

        // Convert to single string per key, joining multiple owners (deduplicate names)
        // NOTE: Duplicate cues (same name) intentionally share MIDI - don't count as conflict
        var map: [MIDIKey: String] = [:]
        for (key, owners) in multiMap {
            // Deduplicate owner names - this means cues with the same name
            // (duplicates/copies) won't be counted as separate conflicts
            let uniqueOwners = Array(Set(owners)).sorted()

            // Only store if there are 2+ UNIQUE owners (actual conflicts)
            // Single owner or multiple cues with same name = no conflict
            if uniqueOwners.count >= 2 {
                // Format list with separator
                map[key] = uniqueOwners.joined(separator: "|||")
            }
            // Don't store single owners - no conflict to display
        }

        return map
    }

    // Helper function to format conflict owners, excluding a specific name
    func formatConflictOwners(_ ownersString: String, excluding excludeName: String? = nil) -> String? {
        // Split by our separator
        let owners = ownersString.split(separator: "|||").map(String.init)

        // Filter out excluded name if provided
        let filteredOwners = excludeName != nil ? owners.filter { $0 != excludeName } : owners

        guard !filteredOwners.isEmpty else { return nil }

        if filteredOwners.count == 1 {
            return filteredOwners[0]
        } else if filteredOwners.count == 2 {
            return "\(filteredOwners[0]) and \(filteredOwners[1])"
        } else if filteredOwners.count <= 4 {
            return filteredOwners.dropLast().joined(separator: ", ") + ", and " + filteredOwners.last!
        } else {
            let shown = filteredOwners.prefix(3).joined(separator: ", ")
            return "\(shown), and \(filteredOwners.count - 3) more"
        }
    }

    func invalidateConflictCache() {
        // FIX: Immediately rebuild cache instead of clearing it
        // Clearing causes "Save & Add Another" to see empty cache and assign CC#0
        cachedConflictLookup = computeConflictLookup()
        cachedUsedCCs = []
        cacheVersion += 1
        debugPrint("🔄 Conflict cache rebuilt immediately with \(cachedConflictLookup.count) entries")
    }

    // FIX #5: Throttled conflict cache update (500ms throttle)
    func scheduleConflictCacheUpdate() {
        guard !conflictCacheUpdateScheduled else { return }
        conflictCacheUpdateScheduled = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms throttle
            cachedConflictLookup = computeConflictLookup()
            conflictCacheUpdateScheduled = false
        }
    }

    func updateConflictCache() {
        // FIX #5: Use throttled version instead of immediate update
        scheduleConflictCacheUpdate()
    }

    
    /// Returns the owner name for a MIDI key (for auto-assign conflict detection)
    /// This checks ALL owners, not just conflicts (unlike conflictLookup which only stores 2+ owners)
    func ownerName(for key: MIDIKey) -> String? {
        // Check songs in setlist
        for s in store.activeSongs {
            let songKey = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc, channel: s.channel, number: s.cc)
            if songKey == key {
                return s.name
            }
        }

        // Check songs in library (not in setlist)
        for s in songLibrary {
            // Skip if already in setlist (avoid double-counting)
            if store.activeSongs.contains(where: { $0.id == s.id }) { continue }
            let songKey = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc, channel: s.channel, number: s.cc)
            if songKey == key {
                return s.name
            }
        }

        // Check control buttons
        for b in controlButtons {
            let buttonKey = MIDIKey(kind: b.kind, channel: b.channel, number: b.number)
            if buttonKey == key {
                let typePrefix = b.isFader == true ? "Fader" : "Button"
                return b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            }
        }

        return nil
    }

    // MARK: - Global Channel Management
    func handleGlobalChannelToggle(wasEnabled: Bool, isEnabled: Bool) {
        guard wasEnabled != isEnabled else { return }

        // Don't backup/restore during project loading
        guard !isLoadingProject else {
            debugPrint("🔄 Skipping global channel toggle handling during project load")
            return
        }

        if isEnabled {
            // Enabling global mode: Save current channels and apply global channel
            debugPrint("🌍 Enabling global MIDI channel mode - saving current channels")

            // Save song channels
            savedSongChannels.removeAll()
            for song in store.activeSongs {
                savedSongChannels[song.id] = song.channel
            }
            for song in songLibrary {
                savedSongChannels[song.id] = song.channel
            }

            // Save control channels
            savedControlChannels.removeAll()
            for button in controlButtons {
                savedControlChannels[button.id] = button.channel
            }

            debugPrint("💾 Saved channels for \(savedSongChannels.count) songs and \(savedControlChannels.count) controls")

            // Apply global channel to all items
            applyGlobalChannel()
        } else {
            // Disabling global mode: Restore original channels
            debugPrint("🌍 Disabling global MIDI channel mode - restoring original channels")

            // Restore song channels
            store.updateActiveSongs { songs in
                for i in 0..<songs.count {
                    if let savedChannel = savedSongChannels[songs[i].id] {
                        songs[i].channel = savedChannel
                    }
                }
            }
            for i in 0..<songLibrary.count {
                if let savedChannel = savedSongChannels[songLibrary[i].id] {
                    songLibrary[i].channel = savedChannel
                }
            }

            // Restore control channels
            for i in 0..<controlButtons.count {
                if let savedChannel = savedControlChannels[controlButtons[i].id] {
                    controlButtons[i].channel = savedChannel
                }
            }

            debugPrint("♻️ Restored channels for \(savedSongChannels.count) songs and \(savedControlChannels.count) controls")

            // Clear the saved channels
            savedSongChannels.removeAll()
            savedControlChannels.removeAll()
        }

        // Invalidate cache and mark as dirty
        invalidateConflictCache()
        markDirty()
    }

    func applyGlobalChannel() {
        debugPrint("🌍 Applying global channel \(globalChannel) to all items")

        // Apply to songs in setlist
        store.updateActiveSongs { songs in
            for i in 0..<songs.count {
                songs[i].channel = globalChannel
            }
        }

        // Apply to songs in library
        for i in 0..<songLibrary.count {
            songLibrary[i].channel = globalChannel
        }

        // Apply to control buttons
        for i in 0..<controlButtons.count {
            controlButtons[i].channel = globalChannel
        }

        debugPrint("✅ Applied global channel to \(store.activeSongs.count + songLibrary.count) songs and \(controlButtons.count) controls")
    }
}
