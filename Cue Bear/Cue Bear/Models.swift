// Models.swift — Cue Bear (clean base)

import Foundation

// MARK: - App Mode
public enum AppMode: String, Codable {
    case regular, cue
}

// MARK: - Transport actions (legacy names kept)
public enum TransportAction: String, Codable {
    case prev, play, stop, next
}

// MARK: - Song
public struct Song: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var subtitle: String?
    public var cc: Int
    public var channel: Int

    // New MIDI options (default keeps old behavior)
    public var kind: MIDIKind = .cc
    public var note: Int? = nil
    public var velocity: Int = 127

    public init(id: UUID = UUID(), name: String, subtitle: String? = nil, cc: Int, channel: Int) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.cc = cc
        self.channel = channel
    }
}

// MARK: - Setlist
public struct Setlist: Codable, Equatable {
    public var songs: [Song] = []
    public init(songs: [Song] = []) { self.songs = songs }
}

extension Setlist {
    static let sample: Setlist = {
        let songs: [Song] = [
            Song(name: "Opening Song",  subtitle: "120 BPM • Em", cc: 11, channel: 1),
            Song(name: "Verse Drop",    subtitle: "128 BPM • Gm", cc: 12, channel: 1),
            Song(name: "Chorus Lift",   subtitle: "126 BPM • Bm", cc: 13, channel: 1)
        ]
        return Setlist(songs: songs)
    }()
}
// MARK: - MIDI Kind (new)
public enum MIDIKind: String, Codable {
    case cc, note
}
