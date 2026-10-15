//
//  ContentView+Undo.swift — Cue Bear
//  ContentView: Undo/Redo
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - Undo/Redo helpers
    func pushSetlistUndo() {
        setlistUndoStack.append(store.activeSongs)
        if setlistUndoStack.count > 30 { setlistUndoStack.removeFirst() }
        setlistRedoStack.removeAll()
    }

    func undoSetlist() {
        guard let last = setlistUndoStack.popLast() else { return }
        setlistRedoStack.append(store.activeSongs)
        store.updateActiveSongs { $0 = last }
        isDirty = true
    }

    func redoSetlist() {
        guard let next = setlistRedoStack.popLast() else { return }
        setlistUndoStack.append(store.activeSongs)
        store.updateActiveSongs { $0 = next }
        isDirty = true
    }

    
    func pushLibraryUndo() {
        libraryUndoStack.append(songLibrary)
        if libraryUndoStack.count > 30 { libraryUndoStack.removeFirst() }
        libraryRedoStack.removeAll()
    }

    func undoLibrary() {
        guard let last = libraryUndoStack.popLast() else { return }
        libraryRedoStack.append(songLibrary)
        songLibrary = last
        isDirty = true
    }

    func redoLibrary() {
        guard let next = libraryRedoStack.popLast() else { return }
        libraryUndoStack.append(songLibrary)
        songLibrary = next
        isDirty = true
    }

    
    // Combined undo/redo that handles both setlist and library
    func performUndo() {
        // Prioritize setlist undo if available, otherwise library undo
        if !setlistUndoStack.isEmpty {
            undoSetlist()
        } else if !libraryUndoStack.isEmpty {
            undoLibrary()
        }
    }

    
    func performRedo() {
        // Prioritize setlist redo if available, otherwise library redo
        if !setlistRedoStack.isEmpty {
            redoSetlist()
        } else if !libraryRedoStack.isEmpty {
            redoLibrary()
        }
    }

    func pushControlUndo() {
        controlUndoStack.append(controlButtons)
        controlRedoStack.removeAll()
    }

    func undoControls() {
        guard let last = controlUndoStack.popLast() else { return }
        controlRedoStack.append(controlButtons)
        controlButtons = last
        invalidateConflictCache()
        markDirty()
    }

    func redoControls() {
        guard let next = controlRedoStack.popLast() else { return }
        controlUndoStack.append(controlButtons)
        controlButtons = next
        invalidateConflictCache()
        markDirty()
    }

    // Control edit mode auto-exit timer
    func startControlEditModeTimer() {
        // Cancel existing timer
        controlEditModeTimer?.invalidate()

        // Start new 5-second timer
        controlEditModeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut) {
                controlEditMode = false
            }
        }
    }

    func cancelControlEditModeTimer() {
        controlEditModeTimer?.invalidate()
        controlEditModeTimer = nil
    }

    func resetControlEditModeTimer() {
        if controlEditMode {
            startControlEditModeTimer()
        }
    }

    func saveCurrentProject(overwrite: Bool) {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show name prompt for "Save As" OR when saving an untitled project for the first time
        if !overwrite || trimmed.isEmpty || isUntitledProject(trimmed) {
            // Pre-fill with current name for "Save As", or suggest active cue list name for new projects
            tempName = trimmed.isEmpty || isUntitledProject(trimmed) ? (store.activeCueList?.name ?? "My Show") : trimmed
            shouldSaveAfterNaming = true  // Mark that we should save after user enters name
            showNamePrompt = true
            return
        }

        // For projects with a name, save directly
        snapshotAndSave(as: trimmed, overwrite: overwrite)
    }

    func loadProject(named: String) {
        do {
            debugPrint("🔄 Loading project: \(named)")
            let payload = try ProjectIO.load(name: named)
            debugPrint("📦 Project payload loaded - cueLists: \(payload.cueLists?.count ?? 0), library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Set loading flag to prevent global channel toggle from triggering backup/restore
            isLoadingProject = true

            projectName = payload.name

            // Migrate legacy format: convert setlist to "Main" cue list
            if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                debugPrint("🔄 Migrating legacy project format to v1.2.0")
                let mainList = CueList(name: "Main", songs: legacySetlist)
                store.cueLists = [mainList]
                store.activeCueListID = mainList.id
                debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
            } else {
                // Modern format or empty legacy
                store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                store.activeCueListID = payload.activeCueListID ?? store.cueLists.first?.id
            }
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Restore app mode preference if saved
            if let savedMode = payload.appMode {
                store.mode = savedMode
                debugPrint("✅ Restored app mode: \(savedMode)")
            }

            // MIDI filter settings are global preferences (UserDefaults), not per-project.
            // Do not restore from project file — loadMidiFiltersFromUserDefaults() on onAppear handles this.

            // Reset loading flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoadingProject = false
            }

            // Migrate controls that are beyond the 4-row limit (rows 0-3)
            migrateOutOfBoundsControls()

            debugPrint("✅ Project data assigned - cueLists: \(store.cueLists.count), activeSongs: \(store.activeSongs.count) songs, library: \(songLibrary.count) songs, controls: \(controlButtons.count) buttons")
            
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil { libAddedAt[s.id] = now }
            isDirty = false

            // Clear autosave when loading a named project
            ProjectIO.clearLibraryAutosave()

            debugPrint("✅ Project loaded successfully: \(named)")

            // v1.0.8: Auto-recover empty library from setlist
            recoverEmptyLibrary()
        } catch {
            debugPrint("❌ Load failed for project \(named): \(error)")
        }
    }

    /// v1.0.8: Auto-recovery for corrupted projects where library is empty but setlist has songs
    /// This copies all songs from setlist to library and marks project as dirty for save
    func recoverEmptyLibrary() {
        // Only recover if library is empty AND setlist has songs
        guard songLibrary.isEmpty && !store.activeSongs.isEmpty else {
            return
        }

        debugPrint("🔧 RECOVERY: Detected empty library with \(store.activeSongs.count) songs in setlist")
        debugPrint("🔧 RECOVERY: Auto-populating library from setlist...")

        // Copy all songs from setlist to library
        songLibrary = store.activeSongs

        // Set timestamps for all recovered songs
        let now = Date()
        for song in songLibrary {
            libAddedAt[song.id] = now
        }

        // Mark project as dirty so it gets saved
        isDirty = true

        debugPrint("✅ RECOVERY: Added \(songLibrary.count) songs to library")
        debugPrint("✅ RECOVERY: Project marked as dirty - save to keep changes")
    }

    /// Migrates controls that are positioned beyond the 4-row limit (rows 0-3) or 8-column limit (cols 0-7)
    /// This fixes projects created when the row limit was higher or controls positioned incorrectly
    func migrateOutOfBoundsControls() {
        // FIX #10: Early exit check using .contains for performance
        let hasOutOfBounds = controlButtons.contains { button in
            let width = button.gridWidth
            let height = button.gridHeight

            if let row = button.gridRow, row >= 4 { return true }
            if let col = button.gridCol, col >= 8 { return true }
            if let col = button.gridCol, col + width > 8 { return true }
            if let row = button.gridRow, row + height > 4 { return true }
            return false
        }

        guard hasOutOfBounds else {
            debugPrint("✅ No out-of-bounds controls found")
            return
        }

        var migratedCount = 0

        debugPrint("⚠️ Found controls out of bounds (beyond row 3 or col 7), starting migration...")

        // Second pass: reposition out-of-bounds controls
        for i in 0..<controlButtons.count {
            let button = controlButtons[i]
            let width = button.gridWidth
            let height = button.gridHeight
            var needsRepositioning = false

            // Check all out-of-bounds conditions
            if let row = button.gridRow, row >= 4 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col >= 8 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col + width > 8 {
                needsRepositioning = true
            }
            if let row = button.gridRow, row + height > 4 {
                needsRepositioning = true
            }

            if needsRepositioning {
                let currentCol = button.gridCol ?? -1
                let currentRow = button.gridRow ?? -1
                debugPrint("🔧 Control '\(button.title)' at (\(currentCol), \(currentRow)) size \(width)×\(height) needs repositioning")

                // Try to find an available position within the 4-row, 8-column limit

                var foundPosition = false
                for newRow in 0..<4 {
                    for newCol in 0..<(8 - width + 1) {
                        var canPlace = true

                        // Check if this position is free
                        for j in 0..<controlButtons.count where i != j {
                            if let existingCol = controlButtons[j].gridCol,
                               let existingRow = controlButtons[j].gridRow {
                                let existingWidth = controlButtons[j].gridWidth
                                let existingHeight = controlButtons[j].gridHeight

                                // Check for overlap
                                if !(newCol + width <= existingCol ||
                                    existingCol + existingWidth <= newCol ||
                                    newRow + height <= existingRow ||
                                    existingRow + existingHeight <= newRow) {
                                    canPlace = false
                                    break
                                }
                            }
                        }

                        if canPlace {
                            controlButtons[i].gridCol = newCol
                            controlButtons[i].gridRow = newRow
                            foundPosition = true
                            migratedCount += 1
                            debugPrint("✅ Repositioned '\(button.title)' to (\(newCol), \(newRow))")
                            break
                        }
                    }
                    if foundPosition { break }
                }

                if !foundPosition {
                    // No space found - clear position to let auto-assign handle it
                    controlButtons[i].gridCol = nil
                    controlButtons[i].gridRow = nil
                    debugPrint("⚠️ No space found for '\(button.title)', cleared position for auto-assign")
                }
            }
        }

        if migratedCount > 0 {
            debugPrint("✅ Migration complete: repositioned \(migratedCount) control(s)")
            // Mark as dirty so the migration is saved
            markDirty()
        }
    }
}
