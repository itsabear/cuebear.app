//
//  SongDetailsSheet.swift — Cue Bear Next (v1.3)
//
//  "Notes & Extras" for one song: what this song adds on top of the show's shared controls.
//  - Notes: shown large on the Show mode card.
//  - Extras: buttons, toggles or faders that appear only while this song is current.
//  - Remembered levels: shared faders jump to a set level when the song starts.
//  Most songs need nothing here; the shared controls already appear on every song.
//

import SwiftUI
import UIKit

struct SongDetailsSheet: View {
    let originalSong: Song
    /// The show's shared faders (for remembered levels)
    let sharedFaders: [ControlButton]
    /// Other songs in the current cue list (for "Copy extras to other songs")
    let otherSongs: [Song]
    var onSave: (Song) -> Void
    var onCopyExtras: ([UUID], [SongExtra]) -> Void
    var onCancel: () -> Void

    @State private var notes: String = ""
    @State private var extras: [SongExtra] = []
    @State private var levels: [String: Int] = [:]
    @State private var editingExtra: SongExtra? = nil
    @State private var showCopySheet = false

    var body: some View {
        VStack(spacing: 0) {
            CBSheetHeader(title: originalSong.name,
                          leadingTitle: "Cancel", leadingAction: onCancel,
                          trailingTitle: "Done", trailingAction: save)
            Form {
                Section {
                    TextField("Key, tempo, cues to the band…", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                        .cbRow()
                } header: {
                    CBSectionLabel("Notes")
                } footer: {
                    FormFooter("Shown large on the Show mode screen while this song is playing.")
                }

                Section {
                    if extras.isEmpty {
                        Text("No extras. This song uses the shared controls only.")
                            .foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    }
                    ForEach(extras) { extra in
                        Button(action: { editingExtra = extra }) {
                            HStack {
                                VStack(alignment: .leading, spacing: CBSpace.xxs) {
                                    Text(extra.title).foregroundStyle(CBColor.textPrimary)
                                    Text(extraSummary(extra))
                                        .font(.cb(.caption))
                                        .foregroundStyle(CBColor.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.cbIcon(.caption))
                                    .foregroundStyle(CBColor.textTertiary)
                            }
                        }
                        .cbRow()
                    }
                    .onDelete { offsets in extras.remove(atOffsets: offsets) }

                    Button(action: addExtra) {
                        Label("Add extra", systemImage: "plus.circle.fill")
                    }
                    .cbRow()
                    if !extras.isEmpty && !otherSongs.isEmpty {
                        Button(action: { showCopySheet = true }) {
                            Label("Copy extras to other songs…", systemImage: "doc.on.doc")
                        }
                        .cbRow()
                    }
                } header: {
                    CBSectionLabel("Song extras, this song only")
                } footer: {
                    FormFooter("Buttons, toggles or faders that appear in Show mode only while this song is current.")
                }

                Section {
                    if sharedFaders.isEmpty {
                        Text("The show has no shared faders yet.")
                            .foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    }
                    ForEach(sharedFaders) { fader in
                        RememberedLevelRow(
                            title: fader.title.isEmpty ? "Fader" : fader.title,
                            level: Binding(
                                get: { levels[fader.id.uuidString] },
                                set: { newValue in levels[fader.id.uuidString] = newValue }
                            ),
                            currentValue: Int(((fader.faderValue ?? 0) * 127).rounded())
                        )
                        .cbRow()
                    }
                } header: {
                    CBSectionLabel("Remembered levels")
                } footer: {
                    FormFooter("When this song starts, these shared faders jump to the level you set. Faders left off stay where they are.")
                }
            }
            .cbFormChrome()
        }
        .cbSheetChrome()
        .sheet(item: $editingExtra) { extra in
            SongExtraEditor(extra: extra,
                            onSave: { updated in
                                if let i = extras.firstIndex(where: { $0.id == updated.id }) {
                                    extras[i] = updated
                                } else {
                                    extras.append(updated)
                                }
                                editingExtra = nil
                            },
                            onDelete: {
                                extras.removeAll(where: { $0.id == extra.id })
                                editingExtra = nil
                            },
                            onCancel: { editingExtra = nil })
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showCopySheet) {
            CopyExtrasSheet(songs: otherSongs,
                            onCopy: { ids in
                                onCopyExtras(ids, extras)
                                showCopySheet = false
                            },
                            onCancel: { showCopySheet = false })
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .onAppear {
            notes = originalSong.notes ?? ""
            extras = originalSong.extras ?? []
            levels = originalSong.rememberedLevels ?? [:]
        }
    }

    private func addExtra() {
        let used = Set(extras.map(\.number))
        var number = 40
        while used.contains(number) && number < 119 { number += 1 }
        editingExtra = SongExtra(title: "Extra \(extras.count + 1)", style: .button, number: number,
                                 channel: originalSong.channel)
    }

    private func extraSummary(_ extra: SongExtra) -> String {
        let style: String
        switch extra.style {
        case .button: style = "Button"
        case .toggle: style = "Toggle"
        case .fader: style = "Fader"
        }
        let msg = (extra.style == .fader || extra.kind == .cc) ? "CC \(extra.number)" : "Note \(extra.number)"
        return "\(style) · \(msg) · channel \(extra.channel)"
    }

    private func save() {
        var song = originalSong
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        song.notes = trimmed.isEmpty ? nil : trimmed
        song.extras = extras.isEmpty ? nil : extras
        song.rememberedLevels = levels.isEmpty ? nil : levels
        onSave(song)
    }
}

// MARK: - Shared pieces

/// Footer text under a form section.
private struct FormFooter: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.cb(.small))
            .foregroundStyle(CBColor.textTertiary)
    }
}

// MARK: - One remembered level

struct RememberedLevelRow: View {
    let title: String
    @Binding var level: Int?
    let currentValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: CBSpace.s) {
            Toggle(isOn: Binding(
                get: { level != nil },
                set: { on in level = on ? (level ?? currentValue) : nil }
            )) {
                Text(title)
            }
            if let value = level {
                HStack {
                    Slider(value: Binding(
                        get: { Double(value) },
                        set: { level = Int($0.rounded()) }
                    ), in: 0...127)
                    Text("\(Int((Double(value) / 127 * 100).rounded()))%")
                        .font(.cbMono(.body))
                        .foregroundStyle(CBColor.textSecondary)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Edit one extra

struct SongExtraEditor: View {
    @State private var draft: SongExtra
    @State private var isLearning = false
    var onSave: (SongExtra) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    init(extra: SongExtra, onSave: @escaping (SongExtra) -> Void, onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: extra)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            CBSheetHeader(title: draft.title.isEmpty ? "Extra" : draft.title,
                          leadingTitle: "Cancel", leadingAction: onCancel,
                          trailingTitle: "Save", trailingAction: {
                              var d = draft
                              if d.title.trimmingCharacters(in: .whitespaces).isEmpty { d.title = "Extra" }
                              onSave(d)
                          })
            Form {
                Section {
                    TextField("Name", text: $draft.title)
                        .cbRow()
                } header: {
                    CBSectionLabel("Name")
                }
                Section {
                    Picker("Type", selection: $draft.style) {
                        Text("Button").tag(SongExtra.Style.button)
                        Text("Toggle").tag(SongExtra.Style.toggle)
                        Text("Fader").tag(SongExtra.Style.fader)
                    }
                    .pickerStyle(.segmented)
                    .cbRow()
                } header: {
                    CBSectionLabel("Type")
                }
                Section {
                    if draft.style != .fader {
                        Picker("Message", selection: $draft.kind) {
                            Text("CC").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .pickerStyle(.segmented)
                        .cbRow()
                    }
                    Button(action: { isLearning.toggle() }) {
                        Label(isLearning ? "Listening… move a control in your DAW" : "Learn from DAW",
                              systemImage: isLearning ? "dot.radiowaves.left.and.right" : "wand.and.stars")
                    }
                    .cbRow()
                    Stepper(value: $draft.number, in: 0...127) {
                        ValueRow(title: draft.style == .fader || draft.kind == .cc ? "CC number" : "Note",
                                 value: "\(draft.number)")
                    }
                    .cbRow()
                    Stepper(value: $draft.channel, in: 1...16) {
                        ValueRow(title: "Channel", value: "\(draft.channel)")
                    }
                    .cbRow()
                    if draft.style != .fader && draft.kind == .note {
                        Stepper(value: $draft.velocity, in: 1...127) {
                            ValueRow(title: "Velocity", value: "\(draft.velocity)")
                        }
                        .cbRow()
                    }
                } header: {
                    CBSectionLabel("MIDI")
                } footer: {
                    FormFooter("Map this in your DAW like any other control. Faders always send CC.")
                }
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete extra", systemImage: "trash")
                            .foregroundStyle(CBColor.danger)
                    }
                    .cbRow()
                }
            }
            .cbFormChrome()
        }
        .cbSheetChrome()
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("cbMIDIInputFromDAW"))) { notif in
            // MIDI learn: take the next CC or note the DAW sends back through the Bridge
            guard isLearning, let info = notif.userInfo as? [String: Any],
                  let type = info["type"] as? String, let channel = info["channel"] as? Int else { return }
            if type == "cc", let cc = info["cc"] as? Int {
                draft.kind = .cc
                draft.number = cc
                draft.channel = channel
                isLearning = false
            } else if type == "note", let note = info["note"] as? Int, draft.style != .fader {
                draft.kind = .note
                draft.number = note
                draft.channel = channel
                isLearning = false
            }
            if !isLearning { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }
}

/// "Title ........ value" inside a Stepper.
private struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.cbMono(.body))
                .foregroundStyle(CBColor.textSecondary)
        }
    }
}

// MARK: - Copy extras to other songs

private struct CopyExtrasSheet: View {
    let songs: [Song]
    var onCopy: ([UUID]) -> Void
    var onCancel: () -> Void
    @State private var selected: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            CBSheetHeader(title: "Copy extras to…",
                          leadingTitle: "Cancel", leadingAction: onCancel,
                          trailingTitle: "Copy", trailingDisabled: selected.isEmpty,
                          trailingAction: { onCopy(Array(selected)) })
            List(songs) { song in
                Button(action: {
                    if selected.contains(song.id) { selected.remove(song.id) } else { selected.insert(song.id) }
                }) {
                    HStack(spacing: CBSpace.m) {
                        Image(systemName: selected.contains(song.id) ? "checkmark.circle.fill" : "circle")
                            .font(.cbIcon(.large, .regular))
                            .foregroundStyle(selected.contains(song.id) ? CBColor.highlight : CBColor.textTertiary)
                        Text(song.name).foregroundStyle(CBColor.textPrimary)
                    }
                }
                .cbRow()
            }
            .cbFormChrome()
        }
        .cbSheetChrome()
    }
}
