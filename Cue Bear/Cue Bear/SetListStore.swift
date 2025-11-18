import SwiftUI
import Combine

/// Store managing multiple cue lists with shared library (v1.2.0+)
///
/// This replaces the old single-setlist architecture with support for:
/// - Multiple named cue lists per project
/// - One shared song library
/// - Active cue list tracking
///
/// **Migration:** Auto-save has been removed. ContentView now handles save/load.
final class SetlistStore: ObservableObject {
    // MARK: - Published State

    /// All cue lists in the project
    @Published var cueLists: [CueList] = []

    /// ID of the currently active cue list
    @Published var activeCueListID: UUID?

    /// App mode (regular, cue mode, etc.)
    @Published var mode: AppMode = .regular

    /// Currently cued song (in cue mode)
    @Published var cuedSong: Song? = nil

    /// Scroll lock state
    @Published var scrollLock: Bool = false

    // MARK: - Computed Properties

    /// Active cue list (computed, not stored)
    var activeCueList: CueList? {
        guard let id = activeCueListID else { return cueLists.first }
        return cueLists.first(where: { $0.id == id })
    }

    /// Active cue list songs (read-only)
    var activeSongs: [Song] {
        activeCueList?.songs ?? []
    }

    /// Index of active cue list
    var activeIndex: Int? {
        guard let id = activeCueListID else { return nil }
        return cueLists.firstIndex(where: { $0.id == id })
    }

    // MARK: - Initialization

    init() {
        // Start with default "Main" cue list
        let defaultList = CueList.defaultMain
        self.cueLists = [defaultList]
        self.activeCueListID = defaultList.id
    }

    // MARK: - Mutation Helpers

    /// Update the active cue list safely
    func updateActiveCueList(_ update: (inout CueList) -> Void) {
        guard let id = activeCueListID,
              let index = cueLists.firstIndex(where: { $0.id == id }) else {
            return
        }
        update(&cueLists[index])
        cueLists[index].touch()  // Update timestamp
    }

    /// Update songs in active cue list
    func updateActiveSongs(_ update: (inout [Song]) -> Void) {
        updateActiveCueList { cueList in
            update(&cueList.songs)
        }
    }

    /// Switch to a different cue list
    func switchToCueList(_ cueListID: UUID) {
        guard cueLists.contains(where: { $0.id == cueListID }) else {
            return
        }
        activeCueListID = cueListID
    }

    /// Create a new cue list
    func createCueList(name: String) -> UUID {
        let newList = CueList(name: name, songs: [])
        cueLists.append(newList)
        return newList.id
    }

    /// Delete a cue list (must have at least one remaining)
    func deleteCueList(_ cueListID: UUID) {
        guard cueLists.count > 1 else { return }  // Keep at least one

        // If deleting active list, switch to another first
        if activeCueListID == cueListID {
            let remainingList = cueLists.first(where: { $0.id != cueListID })
            activeCueListID = remainingList?.id
        }

        cueLists.removeAll(where: { $0.id == cueListID })
    }

    /// Rename a cue list
    func renameCueList(_ cueListID: UUID, to newName: String) {
        guard let index = cueLists.firstIndex(where: { $0.id == cueListID }) else {
            return
        }
        cueLists[index].name = newName
        cueLists[index].touch()
    }

    /// Duplicate a cue list
    func duplicateCueList(_ cueListID: UUID) -> UUID? {
        guard let original = cueLists.first(where: { $0.id == cueListID }) else {
            return nil
        }

        let copy = CueList(
            name: "\(original.name) Copy",
            songs: original.songs.map { song in
                var newSong = song
                newSong.id = UUID()  // New ID for the copy
                return newSong
            }
        )

        cueLists.append(copy)
        return copy.id
    }

    /// Reset to a fresh project state with single default cue list
    func reset() {
        let defaultList = CueList.defaultMain
        self.cueLists = [defaultList]
        self.activeCueListID = defaultList.id
        self.mode = .regular
        self.cuedSong = nil
        self.scrollLock = false
    }
}
