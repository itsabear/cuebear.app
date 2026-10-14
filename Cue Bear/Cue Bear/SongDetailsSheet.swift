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

struct SongDetailsSheet: View {
    let originalSong: Song
    /// The show's shared faders (for remembered levels)
    let sharedFaders: [ControlButton]
    /// Other songs in the current cue list (for "Copy extras to other songs")
    let otherSongs: [Song]
    let accent: Color
    var onSave: (Song) -> Void
    var onCopyExtras: ([UUID], [SongExtra]) -> Void
    var onCancel: () -> Void

    @State private var notes: String = ""
    @State private var extras: [SongExtra] = []
    @State private var levels: [String: Int] = [:]
    @State private var editingExtra: SongExtra? = nil
    @State private var showCopySheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key, tempo, cues to the band…", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Shown large on the Show mode screen while this song is playing.")
                }

                Section {
                    if extras.isEmpty {
                        Text("No extras. This song uses the shared controls only.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(extras) { extra in
                        Button(action: { editingExtra = extra }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(extra.title).foregroundColor(.primary)
                                    Text(extraSummary(extra))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in extras.remove(atOffsets: offsets) }

                    Button(action: addExtra) {
                        Label("Add extra", systemImage: "plus.circle.fill")
                    }
                    if !extras.isEmpty && !otherSongs.isEmpty {
                        Button(action: { showCopySheet = true }) {
                            Label("Copy extras to other songs…", systemImage: "doc.on.doc")
                        }
                    }
                } header: {
                    Text("Song extras, this song only")
                } footer: {
                    Text("Buttons, toggles or faders that appear in Show mode only while this song is current.")
                }

                Section {
                    if sharedFaders.isEmpty {
                        Text("The show has no shared faders yet.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(sharedFaders) { fader in
                        RememberedLevelRow(
                            title: fader.title.isEmpty ? "Fader" : fader.title,
                            accent: accent,
                            level: Binding(
                                get: { levels[fader.id.uuidString] },
                                set: { newValue in levels[fader.id.uuidString] = newValue }
                            ),
                            currentValue: Int(((fader.faderValue ?? 0) * 127).rounded())
                        )
                    }
                } header: {
                    Text("Remembered levels")
                } footer: {
                    Text("When this song starts, these shared faders jump to the level you set. Faders left off stay where they are.")
                }
            }
            .navigationTitle(originalSong.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save).fontWeight(.semibold)
                }
            }
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
            }
            .sheet(isPresented: $showCopySheet) {
                CopyExtrasSheet(songs: otherSongs,
                                onCopy: { ids in
                                    onCopyExtras(ids, extras)
                                    showCopySheet = false
                                },
                                onCancel: { showCopySheet = false })
            }
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

// MARK: - One remembered level

private struct RememberedLevelRow: View {
    let title: String
    let accent: Color
    @Binding var level: Int?
    let currentValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { level != nil },
                set: { on in level = on ? (level ?? currentValue) : nil }
            )) {
                Text(title)
            }
            .tint(accent)
            if let value = level {
                HStack {
                    Slider(value: Binding(
                        get: { Double(value) },
                        set: { level = Int($0.rounded()) }
                    ), in: 0...127)
                    .tint(accent)
                    Text("\(Int((Double(value) / 127 * 100).rounded()))%")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Edit one extra

private struct SongExtraEditor: View {
    @State private var draft: SongExtra
    let isNew: Bool
    var onSave: (SongExtra) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    init(extra: SongExtra, onSave: @escaping (SongExtra) -> Void, onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: extra)
        self.isNew = false
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $draft.title)
                }
                Section("Type") {
                    Picker("Type", selection: $draft.style) {
                        Text("Button").tag(SongExtra.Style.button)
                        Text("Toggle").tag(SongExtra.Style.toggle)
                        Text("Fader").tag(SongExtra.Style.fader)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    if draft.style != .fader {
                        Picker("Message", selection: $draft.kind) {
                            Text("CC").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .pickerStyle(.segmented)
                    }
                    Stepper(value: $draft.number, in: 0...127) {
                        HStack {
                            Text(draft.style == .fader || draft.kind == .cc ? "CC number" : "Note")
                            Spacer()
                            Text("\(draft.number)").foregroundColor(.secondary)
                        }
                    }
                    Stepper(value: $draft.channel, in: 1...16) {
                        HStack {
                            Text("Channel")
                            Spacer()
                            Text("\(draft.channel)").foregroundColor(.secondary)
                        }
                    }
                    if draft.style != .fader && draft.kind == .note {
                        Stepper(value: $draft.velocity, in: 1...127) {
                            HStack {
                                Text("Velocity")
                                Spacer()
                                Text("\(draft.velocity)").foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("MIDI")
                } footer: {
                    Text("Map this in your DAW like any other control. Faders always send CC.")
                }
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete extra", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(draft.title.isEmpty ? "Extra" : draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var d = draft
                        if d.title.trimmingCharacters(in: .whitespaces).isEmpty { d.title = "Extra" }
                        onSave(d)
                    }
                    .fontWeight(.semibold)
                }
            }
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
        NavigationStack {
            List(songs) { song in
                Button(action: {
                    if selected.contains(song.id) { selected.remove(song.id) } else { selected.insert(song.id) }
                }) {
                    HStack {
                        Image(systemName: selected.contains(song.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected.contains(song.id) ? .accentColor : .secondary)
                        Text(song.name).foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Copy extras to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") { onCopy(Array(selected)) }
                        .disabled(selected.isEmpty)
                }
            }
        }
    }
}
