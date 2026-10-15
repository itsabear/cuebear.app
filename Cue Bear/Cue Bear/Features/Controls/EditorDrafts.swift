//
//  EditorDrafts.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Draft State Persistence
// v1.0.8: Preserve draft edits across sheet dismissals (when tapping outside)
// Only clear drafts when Cancel is clicked, not when tapping outside

class CueEditorDraft: ObservableObject {
    @Published var name: String = ""
    @Published var subtitle: String = ""
    @Published var kind: MIDIKind = .cc
    @Published var number: Int = 0
    @Published var channel: Int = 1
    @Published var velocity: Int = 127
    @Published var autoAssign: Bool = true

    func clear() {
        name = ""
        subtitle = ""
        kind = .cc
        number = 0
        channel = 1
        velocity = 127
        autoAssign = true
    }

    func loadFrom(song: Song) {
        name = song.name
        subtitle = song.subtitle ?? ""
        kind = song.kind
        channel = song.channel
        velocity = song.velocity
        if kind == .note {
            number = song.note ?? 0
        } else {
            number = song.cc
        }
        autoAssign = true
    }
}

class ControlEditorDraft: ObservableObject {
    @Published var title: String = ""
    @Published var symbol: String = "square.grid.2x2.fill"
    @Published var kind: MIDIKind = .cc
    @Published var number: Int = 0
    @Published var channel: Int = 1
    @Published var velocity: Int = 127
    @Published var autoAssign: Bool = true
    @Published var isToggle: Bool = false
    @Published var isSmall: Bool = false
    @Published var isFader: Bool = false
    @Published var faderOrientation: String = "vertical"
    @Published var faderDirection: String = "up"
    @Published var colorHex: String? = nil

    func clear() {
        title = ""
        symbol = "square.grid.2x2.fill"
        kind = .cc
        number = 0
        channel = 1
        velocity = 127
        autoAssign = true
        isToggle = false
        isSmall = false
        isFader = false
        faderOrientation = "vertical"
        faderDirection = "up"
        colorHex = nil
    }

    func loadFrom(control: ControlButton) {
        title = control.title
        symbol = control.symbol
        kind = control.kind
        number = control.number
        channel = control.channel
        velocity = control.velocity
        autoAssign = true
        isToggle = control.isToggle ?? false
        isSmall = control.isSmall ?? false
        isFader = control.isFader == true
        faderOrientation = control.faderOrientation ?? "vertical"
        faderDirection = control.faderDirection ?? "up"
        colorHex = control.colorHex
    }
}
