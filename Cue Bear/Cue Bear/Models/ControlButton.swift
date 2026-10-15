//
//  ControlButton.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Control Button (UI-local model; persisted in ProjectPayload)
internal struct ControlButton: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var symbol: String        // SF Symbol
    var kind: MIDIKind        // .cc or .note
    var number: Int           // CC or Note number (0–127)
    var channel: Int          // 1–16
    var velocity: Int = 127   // for notes
    // Behavior: nil/false = momentary, true = toggle
    var isToggle: Bool? = nil
    // Toggle state: true = on, false = off (only used when isToggle == true)
    var toggleState: Bool = false
    // SNAKE: render as a fader instead of a button (CC only)
    var isFader: Bool? = nil
    // SNAKE: render as a small button (1x1)
    var isSmall: Bool? = nil
    // Optional explicit grid placement (column, row) for widget-like layout
    var gridCol: Int? = nil
    var gridRow: Int? = nil
    // Fader value: 0.0 to 1.0 (only used when isFader == true)
    var faderValue: Double? = nil
    // Fader orientation: "vertical" or "horizontal" (only used when isFader == true)
    // Defaults to "vertical" for backward compatibility with existing faders
    var faderOrientation: String? = nil
    // Fader direction: "up", "down", "left", "right" (only used when isFader == true)
    // Defaults to "up" for vertical, "right" for horizontal
    var faderDirection: String? = nil
    // Custom color (hex string, e.g. "#FF5733")
    var colorHex: String? = nil
    // Page index (0-3) for multi-page control area
    var page: Int = 0

    // Memberwise initializer
    init(title: String, symbol: String, kind: MIDIKind, number: Int, channel: Int, velocity: Int = 127, isToggle: Bool? = nil, toggleState: Bool = false, isFader: Bool? = nil, isSmall: Bool? = nil, gridCol: Int? = nil, gridRow: Int? = nil, faderValue: Double? = nil, faderOrientation: String? = nil, faderDirection: String? = nil, colorHex: String? = nil, page: Int = 0) {
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.number = number
        self.channel = channel
        self.velocity = velocity
        self.isToggle = isToggle
        self.toggleState = toggleState
        self.isFader = isFader
        self.isSmall = isSmall
        self.gridCol = gridCol
        self.gridRow = gridRow
        self.faderValue = faderValue
        self.faderOrientation = faderOrientation
        self.faderDirection = faderDirection
        self.colorHex = colorHex
        self.page = page
    }

    // Custom decoder to handle missing toggleState in older project files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbol = try container.decode(String.self, forKey: .symbol)
        kind = try container.decode(MIDIKind.self, forKey: .kind)
        number = try container.decode(Int.self, forKey: .number)
        channel = try container.decode(Int.self, forKey: .channel)
        velocity = try container.decodeIfPresent(Int.self, forKey: .velocity) ?? 127
        isToggle = try container.decodeIfPresent(Bool.self, forKey: .isToggle)
        toggleState = try container.decodeIfPresent(Bool.self, forKey: .toggleState) ?? false
        isFader = try container.decodeIfPresent(Bool.self, forKey: .isFader)
        isSmall = try container.decodeIfPresent(Bool.self, forKey: .isSmall)
        gridCol = try container.decodeIfPresent(Int.self, forKey: .gridCol)
        gridRow = try container.decodeIfPresent(Int.self, forKey: .gridRow)
        faderValue = try container.decodeIfPresent(Double.self, forKey: .faderValue)
        // New fader properties - defaults for backward compatibility
        faderOrientation = try container.decodeIfPresent(String.self, forKey: .faderOrientation)
        faderDirection = try container.decodeIfPresent(String.self, forKey: .faderDirection)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        // Page property - defaults to 0 for backward compatibility
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 0
    }

    // Computed properties for grid dimensions
    var gridWidth: Int {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        if isFader == true {
            // iPhone: All faders are 1 wide, iPad: orientation-dependent
            if isPhone {
                return 1
            } else {
                let orientation = faderOrientation ?? "vertical"
                return orientation == "horizontal" ? 2 : 1
            }
        } else if isSmall == true {
            return 1  // Small button: 1x1
        } else {
            // iPhone: Regular buttons are 2x1, iPad: 2x1
            return 2
        }
    }

    var gridHeight: Int {
        if isFader == true {
            // iPhone: All faders are 2 high, iPad: orientation-dependent
            if UIDevice.current.userInterfaceIdiom == .phone {
                return 2
            } else {
                let orientation = faderOrientation ?? "vertical"
                return orientation == "horizontal" ? 1 : 2
            }
        } else {
            return 1  // All buttons: height 1
        }
    }
}

// MARK: - Local UI helpers / rows
    internal struct CBLibraryRow: Identifiable {
    let id: UUID
    let song: Song
    let isInSetlist: Bool
    let isSelected: Bool
}

internal enum LibrarySortMode: String, CaseIterable, Identifiable {
    case nameAZ, nameZA, newest, oldest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nameAZ: return "A–Z"
        case .nameZA: return "Z–A"
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        }
    }
}

// MARK: - Project Data Structure (moved to ProjectPayload.swift)
// MARK: - ProjectIO (moved to ProjectIO.swift)

// MARK: - MIDI conflict key
internal struct MIDIKey: Hashable {
    let kind: MIDIKind
    let channel: Int
    let number: Int
}

// MARK: - Order (v1.3, Cue Bear Next)

extension Array where Element == ControlButton {
    /// The order shared controls appear in Show and in Build › Controls.
    var inShowOrder: [ControlButton] {
        sorted { a, b in
            if a.page != b.page { return a.page < b.page }
            if (a.gridRow ?? 0) != (b.gridRow ?? 0) { return (a.gridRow ?? 0) < (b.gridRow ?? 0) }
            return (a.gridCol ?? 0) < (b.gridCol ?? 0)
        }
    }

    /// Same order, written back as plain positions (page 0, row = index) so moves are simple swaps.
    var normalizedShowOrder: [ControlButton] {
        inShowOrder.enumerated().map { index, control in
            var c = control
            c.page = 0
            c.gridRow = index
            c.gridCol = 0
            return c
        }
    }
}
