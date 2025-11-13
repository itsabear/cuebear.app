// Models.swift — Cue Bear (clean base)

import Foundation

// MARK: - App Mode
public enum AppMode: String, Codable {
    case regular          // No remote pill
    case regularPlusRemote // Regular mode + navigation capsule
    case cue              // Cue mode with GO capsule
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

    // Custom color (hex string, e.g. "#FF5733")
    public var colorHex: String? = nil

    // MIDI enable/disable for dummy cues (default true for backward compatibility)
    public var midiEnabled: Bool = true

    // Alias system - if set, this cue is an alias of another cue
    public var aliasedCueID: UUID? = nil

    public init(id: UUID = UUID(), name: String, subtitle: String? = nil, cc: Int, channel: Int) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.cc = cc
        self.channel = channel
    }

    // Custom decoder for backward compatibility with old projects
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        cc = try container.decode(Int.self, forKey: .cc)
        channel = try container.decode(Int.self, forKey: .channel)

        // Optional fields with defaults for backward compatibility
        kind = try container.decodeIfPresent(MIDIKind.self, forKey: .kind) ?? .cc
        note = try container.decodeIfPresent(Int.self, forKey: .note)
        velocity = try container.decodeIfPresent(Int.self, forKey: .velocity) ?? 127
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        midiEnabled = try container.decodeIfPresent(Bool.self, forKey: .midiEnabled) ?? true
        aliasedCueID = try container.decodeIfPresent(UUID.self, forKey: .aliasedCueID)
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
