//
//  CueList.swift
//  Cue Bear
//
//  A named collection of songs (cues) within a project
//  Version 1.2.0 - Multiple Cue Lists Feature
//

import Foundation

/// A named collection of songs (cues) within a project.
///
/// Design:
/// - Each project can have multiple cue lists (e.g., "Main Show", "Rehearsal")
/// - Songs in a cue list are instances drawn from the shared library
/// - Each instance can have different MIDI settings than the library template
///
/// Example:
/// ```swift
/// let mainList = CueList(name: "Main Show", songs: [song1, song2])
/// let rehearsal = CueList(name: "Rehearsal", songs: [song1])
/// ```
public struct CueList: Identifiable, Codable, Equatable {
    /// Unique identifier for this cue list
    public var id: UUID

    /// Display name of the cue list
    public var name: String

    /// Songs in this cue list (instances from library)
    public var songs: [Song]

    /// When this cue list was created
    public var createdAt: Date

    /// When this cue list was last modified
    public var modifiedAt: Date

    /// Initialize a new cue list
    public init(
        id: UUID = UUID(),
        name: String,
        songs: [Song] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.songs = songs
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Update modification timestamp
    public mutating func touch() {
        self.modifiedAt = Date()
    }

    /// Validate cue list name
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Presets
extension CueList {
    /// Default cue list for new projects
    public static var defaultMain: CueList {
        CueList(name: "Untitled Cue List", songs: [])
    }

    /// Common preset templates for new cue lists
    public static var templates: [CueList] {
        [
            CueList(name: "Main Show", songs: []),
            CueList(name: "Rehearsal", songs: []),
            CueList(name: "Backup", songs: []),
            CueList(name: "Soundcheck", songs: [])
        ]
    }
}

// MARK: - Convenience Methods
extension CueList {
    /// Get song at index safely
    public func song(at index: Int) -> Song? {
        guard songs.indices.contains(index) else { return nil }
        return songs[index]
    }

    /// Check if cue list contains a song with given ID
    public func contains(songID: UUID) -> Bool {
        songs.contains(where: { $0.id == songID })
    }

    /// Get index of song with given ID
    public func index(of songID: UUID) -> Int? {
        songs.firstIndex(where: { $0.id == songID })
    }
}
