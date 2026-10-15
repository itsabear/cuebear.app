//
//  ContentView+Library.swift — Cue Bear
//  ContentView: Library helpers, Setlist Batch
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - Library helpers
    func usedCCNumbers() -> Set<Int> {
        // Always compute fresh to avoid state modification during view updates
        var taken: Set<Int> = [CBTransportCC.play, CBTransportCC.stop, CBTransportCC.prev, CBTransportCC.next]
        taken.formUnion(store.activeSongs.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(songLibrary.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(controlButtons.filter{ $0.kind == .cc }.map { $0.number })

        return taken
    }

    func nextDefaultCueName() -> String {
        let prefix = "Cue "
        var maxN = 0
        // Check all songs in the library (not just active cue list) for unique naming
        for s in songLibrary {
            if s.name.hasPrefix(prefix) {
                let rest = s.name.dropFirst(prefix.count)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "Cue \(maxN + 1)"
    }

    func nextDefaultControlName(_ prefix: String) -> String {
        var maxN = 0
        for b in controlButtons {
            if b.title.hasPrefix(prefix + " ") {
                let rest = b.title.dropFirst(prefix.count + 1)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "\(prefix) \(maxN + 1)"
    }

    func cueNameExists(_ name: String, excluding id: UUID? = nil) -> Bool {
        songLibrary.contains { $0.id != id && $0.name.lowercased() == name.lowercased() }
    }

    func uniqueCueName(baseName: String, excluding id: UUID? = nil) -> String {
        let names = Set(songLibrary.filter { $0.id != id }.map { $0.name.lowercased() })
        if !names.contains(baseName.lowercased()) { return baseName }
        var n = 2
        while names.contains("\(baseName) (\(n))".lowercased()) { n += 1 }
        return "\(baseName) (\(n))"
    }

    /// Handles saving a cue with duplicate name check. Shows alert if name exists, otherwise saves directly.
    func saveCueWithDuplicateCheck(_ song: Song, andAddAnother: Bool, dismissSheet: @escaping () -> Void) {
        // Skip duplicate check for aliased (duplicated) cues — duplicate names are their purpose
        if song.aliasedCueID != nil {
            saveSong(song)
            dismissSheet()
            return
        }

        // If editing an existing cue whose name is unchanged, skip the check entirely.
        // Check both library and setlist since a cue might be in the setlist but not the library.
        let existingCue = songLibrary.first(where: { $0.id == song.id })
                       ?? store.activeSongs.first(where: { $0.id == song.id })
        if let existingCue, existingCue.name.lowercased() == song.name.lowercased() {
            saveSong(song)
            dismissSheet()
            return
        }

        // For existing cues being renamed, exclude their own ID from the check.
        // Also check setlist in case a cue exists there but not yet in the library.
        let isKnownCue = songLibrary.contains(where: { $0.id == song.id })
                      || store.activeSongs.contains(where: { $0.id == song.id })
        let excludeID: UUID? = isKnownCue ? song.id : nil

        if cueNameExists(song.name, excluding: excludeID) {
            pendingDuplicateCue = song
            pendingDuplicateCueAddAnother = andAddAnother
            duplicateCueName = song.name
            duplicateCueSuggestedName = uniqueCueName(baseName: song.name, excluding: excludeID)
            // Dismiss the edit sheet first, then show the alert — prevents alert appearing behind the open sheet
            dismissSheet()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showDuplicateCueNameAlert = true
            }
        } else {
            saveSong(song)
            dismissSheet()
        }
    }

    func sortedLibrary() -> [Song] {
        switch sortMode {
        case .nameAZ:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) > (libAddedAt[$1.id] ?? .distantPast) }
        case .oldest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) < (libAddedAt[$1.id] ?? .distantPast) }
        }
    }

    func libraryDecorated() -> [CBLibraryRow] {
        let setIDs = Set(store.activeSongs.map { $0.id })
        return sortedLibrary().map { s in
            CBLibraryRow(id: s.id, song: s, isInSetlist: setIDs.contains(s.id), isSelected: libSelected.contains(s.id))
        }
    }

    func filteredLibraryRows() -> [CBLibraryRow] {
        let rows = libraryDecorated()
        // FIX #9: Use debounced query and localizedCaseInsensitiveContains for better performance
        let q = libraryQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter { row in
            row.song.name.localizedCaseInsensitiveContains(q) ||
            (row.song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    func filteredSetlistSongs() -> [Song] {
        let songs = store.activeSongs
        let q = setlistQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return songs }
        return songs.filter { song in
            song.name.localizedCaseInsensitiveContains(q) ||
            (song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    func toggleLibSelection(_ id: UUID) {
        let songName = songLibrary.first(where: { $0.id == id })?.name ?? "Unknown"
        let wasSelected = libSelected.contains(id)
        debugPrint("🔵 toggleLibSelection called for: \(songName) (ID: \(id)), wasSelected: \(wasSelected)")
        if libSelected.contains(id) { libSelected.remove(id) } else { libSelected.insert(id) }
        let nowSelected = libSelected.contains(id)
        debugPrint("🔵 toggleLibSelection completed for: \(songName), nowSelected: \(nowSelected)")
    }

    func selectAllLibrary() {
        // Select ALL items in the library, including those already in the cue list
        let candidates = filteredLibraryRows()
        libSelected = Set(candidates.map { $0.id })
    }

    func addSelectedToSetlist() {
        guard !libSelected.isEmpty else { return }
        let toAdd = songLibrary.filter { libSelected.contains($0.id) }
        toAdd.forEach(addToSetlist(_:))
        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    func deleteSelectedFromLibrary() {
        guard !libSelected.isEmpty else { return }
        pushSetlistUndo()
        pushLibraryUndo()

        // Remove from both library and cue list
        songLibrary.removeAll { libSelected.contains($0.id) }
        store.updateActiveSongs { $0.removeAll { libSelected.contains($0.id) } }

        // Clean up metadata for deleted songs
        libSelected.forEach { libAddedAt[$0] = nil }
        invalidateConflictCache()
        isDirty = true

        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    // MARK: - Setlist Batch Operations

    func toggleSetlistSelection(_ id: UUID) {
        let songName = store.activeSongs.first(where: { $0.id == id })?.name ?? "Unknown"
        let wasSelected = setlistSelected.contains(id)
        debugPrint("🔵 toggleSetlistSelection called for: \(songName) (ID: \(id)), wasSelected: \(wasSelected)")
        if setlistSelected.contains(id) { setlistSelected.remove(id) } else { setlistSelected.insert(id) }
        let nowSelected = setlistSelected.contains(id)
        debugPrint("🔵 toggleSetlistSelection completed for: \(songName), nowSelected: \(nowSelected)")
    }

    func selectAllSetlist() {
        let candidates = filteredSetlistSongs()
        setlistSelected = Set(candidates.map { $0.id })
    }

    func removeSelectedFromSetlist() {
        guard !setlistSelected.isEmpty else { return }
        pushSetlistUndo()

        // Remove from cue list only
        store.updateActiveSongs { $0.removeAll { setlistSelected.contains($0.id) } }

        invalidateConflictCache()
        isDirty = true

        setlistSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    func addToSetlist(_ s: Song) {
        debugPrint("➕ addToSetlist called for: \(s.name) (ID: \(s.id))")
        pushSetlistUndo()
        let alreadyInSetlist = store.activeSongs.contains(where: { $0.id == s.id })
        debugPrint("➕ Already in setlist: \(alreadyInSetlist)")
        guard !alreadyInSetlist else {
            debugPrint("➕ Skipping add - song already in setlist")
            return
        }

        // Auto-assign MIDI message if not already assigned
        var songToAdd = s
        if songToAdd.channel == 0 || songToAdd.cc == 0 {
            // Find first available CC message
            let freeCC = firstFreeCC()
            if freeCC >= 0 {
                songToAdd.kind = .cc
                songToAdd.channel = 1
                songToAdd.cc = freeCC
                songToAdd.velocity = 127
            }
        }

        debugPrint("➕ Appending \(s.name) to setlist")
        store.updateActiveSongs { $0.append(songToAdd) }
        invalidateConflictCache()
        isDirty = true
        debugPrint("➕ addToSetlist completed for: \(s.name), setlist now has \(store.activeSongs.count) songs")
    }

    func firstFreeCC() -> Int {
        for cc in 0...127 {
            let key = MIDIKey(kind: .cc, channel: 1, number: cc)
            if conflictLookup()[key] == nil {
                return cc
            }
        }
        return -1 // No free CC found
    }

    func removeFromSetlist(_ s: Song) {
        debugPrint("🔴 removeFromSetlist called for: \(s.name) (ID: \(s.id))")
        let countBefore = store.activeSongs.count
        debugPrint("🔴 Setlist size before removal: \(countBefore)")
        pushSetlistUndo()
        store.updateActiveSongs { $0.removeAll { $0.id == s.id } }
        let countAfter = store.activeSongs.count
        debugPrint("🔴 Setlist size after removal: \(countAfter)")
        isDirty = true
        debugPrint("🔴 removeFromSetlist completed for: \(s.name), removed: \(countBefore - countAfter) song(s)")
    }

    func deleteFromLibrary(_ s: Song) {
        // Dismiss library popover so it doesn't cover the confirmation dialog
        showLibraryPopover = false

        // Check if song is in ANY cue list
        let isInAnyCueList = store.cueLists.contains { cueList in
            cueList.songs.contains(where: { $0.id == s.id })
        }

        if isInAnyCueList {
            // Show confirmation popup
            songToDelete = s
            showDeleteConfirmation = true
        } else {
            // Safe to delete from library only
            performDeleteFromLibrary(s)
        }
    }

    
    func performDeleteFromLibrary(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        // Convert any alias cues pointing to this song into regular cues AND remove song from ALL cue lists
        for i in 0..<store.cueLists.count {
            var updated = false
            for j in 0..<store.cueLists[i].songs.count {
                // Convert aliases to regular cues
                if store.cueLists[i].songs[j].aliasedCueID == s.id {
                    store.cueLists[i].songs[j].aliasedCueID = nil
                    debugPrint("🔄 Converted alias cue '\(store.cueLists[i].songs[j].name)' to regular cue (original deleted)")
                    updated = true
                }
            }
            // Remove the song from this cue list
            let beforeCount = store.cueLists[i].songs.count
            store.cueLists[i].songs.removeAll { $0.id == s.id }
            let afterCount = store.cueLists[i].songs.count
            if beforeCount != afterCount {
                updated = true
                debugPrint("🗑️ Removed song '\(s.name)' from cue list '\(store.cueLists[i].name)'")
            }
            // Update timestamp if modified
            if updated {
                store.cueLists[i].touch()
            }
        }

        // Remove from library
        songLibrary.removeAll { $0.id == s.id }
        libAddedAt[s.id] = nil
        invalidateConflictCache()
        isDirty = true

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    func duplicateSong(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        // If this is an alias cue, duplicate the original cue instead
        let sourceSong: Song
        if let aliasedID = s.aliasedCueID,
           let originalCue = songLibrary.first(where: { $0.id == aliasedID }) {
            sourceSong = originalCue
        } else {
            sourceSong = s
        }

        // Create copy with same name but "copy of [name]" as subtitle
        var copy = Song(name: sourceSong.name, subtitle: "copy of \(sourceSong.name)", cc: sourceSong.cc, channel: sourceSong.channel)
        copy.kind = sourceSong.kind
        copy.note = sourceSong.note
        copy.velocity = sourceSong.velocity
        copy.colorHex = sourceSong.colorHex
        copy.midiEnabled = sourceSong.midiEnabled
        // Don't copy aliasedCueID - this is a real duplicate, not an alias
        songLibrary.append(copy)
        libAddedAt[copy.id] = Date()

        // Add the copy to the cue list right after the original song
        store.updateActiveSongs { songs in
            if let index = songs.firstIndex(where: { $0.id == s.id }) {
                songs.insert(copy, at: index + 1)
            }
        }

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.5)
        isDirty = true
        saveCurrentProject(overwrite: true)
    }

    func saveSong(_ song: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        var song = song

        let isNewSong = !songLibrary.contains(where: { $0.id == song.id })

        // Auto-assign random color for new cues if enabled and no color set
        if isNewSong && autoAssignCueColors && song.colorHex == nil {
            let usedColors = Set(songLibrary.compactMap { $0.colorHex })
            let available = curatedColorPalette.filter { !usedColors.contains($0) }
            if let random = available.randomElement() {
                song.colorHex = random
            } else {
                song.colorHex = curatedColorPalette.randomElement()
            }
        }

        // Update existing song in setlist if it's there
        store.updateActiveSongs { songs in
            if let i = songs.firstIndex(where: { $0.id == song.id }) {
                songs[i] = song
            }
        }

        // Add or update in library
        if let j = songLibrary.firstIndex(where: { $0.id == song.id }) {
            songLibrary[j] = song
        } else {
            songLibrary.append(song)
            libAddedAt[song.id] = Date()

            // For new songs, also add directly to cue list for better UX
            if isNewSong && !store.activeSongs.contains(where: { $0.id == song.id }) {
                store.updateActiveSongs { $0.append(song) }
        }
        }

        // Invalidate conflict cache since MIDI assignments may have changed
        invalidateConflictCache()
        isDirty = true
    }

    func markDirty() {
        isDirty = true
    }

    func loadMidiFiltersFromUserDefaults() {
        if let saved = UserDefaults.standard.array(forKey: "midiFilterCCs") as? [Int] {
            midiFilter = Set(saved)
        }
        let ccs = UserDefaults.standard.array(forKey: "midiCustomFilterCCs") as? [Int] ?? []
        let names = UserDefaults.standard.array(forKey: "midiCustomFilterNames") as? [String] ?? []
        if ccs.count == names.count && !ccs.isEmpty {
            customMidiFilters = zip(ccs, names).map { ($0, $1) }
        }
    }

    func saveMidiCustomFiltersToUserDefaults() {
        UserDefaults.standard.set(customMidiFilters.map { $0.0 }, forKey: "midiCustomFilterCCs")
        UserDefaults.standard.set(customMidiFilters.map { $0.1 }, forKey: "midiCustomFilterNames")
    }

    func snapshotAndSave(as name: String, overwrite: Bool) {
        let cueLists = store.cueLists
        let activeCueListID = store.activeCueListID
        let library = songLibrary
        let controls = controlButtons
        let isGlobalCh = isGlobalChannel
        let globalCh = globalChannel
        let theme = selectedThemeID
        let appMode = store.mode
        let filtersEnabled = midiFiltersEnabled
        let filter = midiFilter
        let customFilters = customMidiFilters
        DispatchQueue.global(qos: .utility).async {
            do {
                try ProjectIO.save(name: name, cueLists: cueLists, activeCueListID: activeCueListID, library: library, controls: controls, isGlobalChannel: isGlobalCh, globalChannel: globalCh, theme: theme, appMode: appMode, midiFiltersEnabled: filtersEnabled, midiFilter: filter, customMidiFilters: customFilters)
                let projects = ProjectIO.list()
                DispatchQueue.main.async {
                    projectName = name
                    isDirty = false
                    projectsList = projects
                }
            } catch { debugPrint("Save failed: \(error)") }
        }
    }

    /// Generate a unique project name by appending (1), (2), etc. if name already exists
    func uniqueProjectName(baseName: String) -> String {
        let existingProjects = projectsList

        // If name doesn't exist, return as-is
        if !existingProjects.contains(baseName) {
            return baseName
        }

        // Find the next available number
        var counter = 1
        while existingProjects.contains("\(baseName) (\(counter))") {
            counter += 1
        }

        return "\(baseName) (\(counter))"
    }
}
