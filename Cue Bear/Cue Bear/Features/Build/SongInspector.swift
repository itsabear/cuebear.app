//
//  SongInspector.swift — Cue Bear Next
//
//  Build › Setlist / Library, right side: everything about one song in one place.
//  Replaces the old Edit Cue sheet and the Notes & Extras sheet. Every change is applied as you
//  make it (one undo step per song you edit).
//

import SwiftUI
import UIKit

struct SongInspector: View {
    let song: Song
    /// The show's shared faders (for "faders jump to, on GO")
    let sharedFaders: [ControlButton]
    let isInSetlist: Bool
    /// Who else sends this MIDI message (nil = nobody)
    var conflictName: (MIDIKind, Int, Int) -> String?
    var onChange: (Song) -> Void
    var onDuplicate: () -> Void
    var onRemoveFromSetlist: () -> Void
    var onAddToSetlist: () -> Void
    var onDeleteFromLibrary: () -> Void

    @State private var draft: Song
    @State private var editingExtra: SongExtra? = nil
    @State private var isLearning = false

    init(song: Song, sharedFaders: [ControlButton], isInSetlist: Bool,
         conflictName: @escaping (MIDIKind, Int, Int) -> String?,
         onChange: @escaping (Song) -> Void,
         onDuplicate: @escaping () -> Void,
         onRemoveFromSetlist: @escaping () -> Void,
         onAddToSetlist: @escaping () -> Void,
         onDeleteFromLibrary: @escaping () -> Void) {
        self.song = song
        self.sharedFaders = sharedFaders
        self.isInSetlist = isInSetlist
        self.conflictName = conflictName
        self.onChange = onChange
        self.onDuplicate = onDuplicate
        self.onRemoveFromSetlist = onRemoveFromSetlist
        self.onAddToSetlist = onAddToSetlist
        self.onDeleteFromLibrary = onDeleteFromLibrary
        _draft = State(initialValue: song)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CBSpace.xl) {
                header
                sendsCard
                lookCard
                notesSection
                extrasSection
                levelsSection
            }
            .padding(CBSpace.xl)
        }
        .onChange(of: draft) { _, newValue in onChange(newValue) }
        .onChange(of: song) { _, newValue in
            if newValue != draft { draft = newValue }   // undo, or a change made elsewhere
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("cbMIDIInputFromDAW"))) { notif in
            learn(from: notif)
        }
        .sheet(item: $editingExtra) { extra in
            SongExtraEditor(extra: extra,
                            onSave: { updated in
                                var list = draft.extras ?? []
                                if let i = list.firstIndex(where: { $0.id == updated.id }) {
                                    list[i] = updated
                                } else {
                                    list.append(updated)
                                }
                                draft.extras = list
                                editingExtra = nil
                            },
                            onDelete: {
                                draft.extras?.removeAll(where: { $0.id == extra.id })
                                if draft.extras?.isEmpty == true { draft.extras = nil }
                                editingExtra = nil
                            },
                            onCancel: { editingExtra = nil })
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: CBSpace.m) {
            TextField("Song name", text: $draft.name)
                .font(.cb(.heading, .bold))
                .foregroundStyle(CBColor.textPrimary)
                .submitLabel(.done)
            CBSheetIconMenu(systemName: "ellipsis") {
                Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
                if isInSetlist {
                    Button(action: onRemoveFromSetlist) { Label("Remove from this cue list", systemImage: "minus.circle") }
                } else {
                    Button(action: onAddToSetlist) { Label("Add to this cue list", systemImage: "plus.circle") }
                }
                Button(role: .destructive, action: onDeleteFromLibrary) { Label("Delete song", systemImage: "trash") }
            }
            .accessibilityLabel("More actions")
        }
    }

    // MARK: - What it sends

    private var numberBinding: Binding<Int> {
        Binding(
            get: { draft.kind == .cc ? draft.cc : (draft.note ?? 60) },
            set: { value in
                if draft.kind == .cc { draft.cc = value } else { draft.note = value }
            })
    }

    private var sendsCard: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            CBSectionLabel("Sends when played")
            Toggle(isOn: $draft.midiEnabled) {
                Text("Send MIDI").font(.cb(.body))
            }
            if draft.midiEnabled {
                Picker("Message", selection: $draft.kind) {
                    Text("CC").tag(MIDIKind.cc)
                    Text("Note").tag(MIDIKind.note)
                }
                .pickerStyle(.segmented)
                Stepper(value: numberBinding, in: 0...127) {
                    InspectorValue(title: draft.kind == .cc ? "CC number" : "Note", value: "\(numberBinding.wrappedValue)")
                }
                Stepper(value: $draft.channel, in: 1...16) {
                    InspectorValue(title: "Channel", value: "\(draft.channel)")
                }
                if draft.kind == .note {
                    Stepper(value: $draft.velocity, in: 1...127) {
                        InspectorValue(title: "Velocity", value: "\(draft.velocity)")
                    }
                }
                HStack(spacing: CBSpace.m) {
                    Button(action: { isLearning.toggle() }) {
                        Label(isLearning ? "Listening… move a control in your DAW" : "Learn from DAW",
                              systemImage: isLearning ? "dot.radiowaves.left.and.right" : "wand.and.stars")
                    }
                    .buttonStyle(CBButtonStyle(kind: isLearning ? .highlight : .secondary))
                    Spacer(minLength: 0)
                }
                if let other = conflictName(draft.kind, draft.channel, numberBinding.wrappedValue), other != draft.name {
                    Label("\(other) sends the same message", systemImage: "exclamationmark.triangle.fill")
                        .font(.cb(.small))
                        .foregroundStyle(CBColor.warning)
                }
            }
        }
        .cbCard()
    }

    // MARK: - Look

    private var lookCard: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            CBSectionLabel("Subtitle and color")
            TextField("Tempo, key…", text: Binding(
                get: { draft.subtitle ?? "" },
                set: { draft.subtitle = $0.isEmpty ? nil : $0 }))
                .textFieldStyle(CBTextFieldStyle())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CBSpace.s) {
                    ForEach(curatedColorPalette, id: \.self) { hex in
                        let chosen = sameColor(draft.colorHex, hex)
                        Button(action: { draft.colorHex = hex }) {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(CBColor.textPrimary, lineWidth: chosen ? CBSize.selection : 0).padding(-4))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(hex)")
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                .padding(.horizontal, CBSpace.xs)
            }
        }
        .cbCard()
    }

    private func sameColor(_ a: String?, _ b: String) -> Bool {
        guard let a else { return false }
        func norm(_ s: String) -> String { s.replacingOccurrences(of: "#", with: "").uppercased() }
        return norm(a) == norm(b)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: CBSpace.s) {
            CBSectionLabel("Notes · shown large in Show")
            TextField("Key, tempo, cues to the band…", text: Binding(
                get: { draft.notes ?? "" },
                set: { draft.notes = $0.isEmpty ? nil : $0 }), axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(CBTextFieldStyle())
        }
    }

    // MARK: - Extras

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: CBSpace.s) {
            CBSectionLabel("Extras · this song only")
            ForEach(draft.extras ?? []) { extra in
                Button(action: { editingExtra = extra }) {
                    HStack(spacing: CBSpace.m) {
                        Text(extra.title)
                            .font(.cb(.body, .bold))
                            .foregroundStyle(CBColor.textPrimary)
                        Spacer(minLength: CBSpace.s)
                        Text("\(extraStyleName(extra)) · " + cbMIDISummary(kind: extra.style == .fader ? .cc : extra.kind, number: extra.number, channel: extra.channel))
                            .font(.cbMono(.caption))
                            .foregroundStyle(CBColor.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.cbIcon(.caption))
                            .foregroundStyle(CBColor.textTertiary)
                    }
                    .padding(.horizontal, CBSpace.m)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surface))
                    .overlay(RoundedRectangle(cornerRadius: CBRadius.control).stroke(CBColor.highlight, lineWidth: CBSize.selection))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button(action: addExtra) {
                Label("Add extra", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CBButtonStyle(kind: .secondary, fullWidth: true))
            Text("Buttons, toggles or faders that show in Show only while this song is playing.")
                .font(.cb(.small))
                .foregroundStyle(CBColor.textTertiary)
        }
    }

    private func extraStyleName(_ e: SongExtra) -> String {
        switch e.style {
        case .button: return "Button"
        case .toggle: return "Toggle"
        case .fader: return "Fader"
        }
    }

    private func addExtra() {
        let used = Set((draft.extras ?? []).map(\.number))
        var number = 40
        while used.contains(number) && number < 119 { number += 1 }
        editingExtra = SongExtra(title: "Extra \((draft.extras?.count ?? 0) + 1)", style: .button,
                                 number: number, channel: draft.channel)
    }

    // MARK: - Remembered levels

    private var levelsSection: some View {
        VStack(alignment: .leading, spacing: CBSpace.s) {
            CBSectionLabel("Faders jump to, on GO")
            if sharedFaders.isEmpty {
                Text("The show has no shared faders yet. Add them under Controls.")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.textTertiary)
            } else {
                VStack(spacing: CBSpace.m) {
                    ForEach(sharedFaders) { fader in
                        RememberedLevelRow(
                            title: fader.title.isEmpty ? "Fader" : fader.title,
                            level: Binding(
                                get: { draft.rememberedLevels?[fader.id.uuidString] },
                                set: { newValue in
                                    var levels = draft.rememberedLevels ?? [:]
                                    levels[fader.id.uuidString] = newValue
                                    draft.rememberedLevels = levels.isEmpty ? nil : levels
                                }),
                            currentValue: Int(((fader.faderValue ?? 0) * 127).rounded())
                        )
                    }
                }
                .cbCard()
                Text("Faders left off stay where they are.")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.textTertiary)
            }
        }
    }

    // MARK: - MIDI learn

    private func learn(from notif: Notification) {
        guard isLearning, let info = notif.userInfo as? [String: Any],
              let type = info["type"] as? String, let channel = info["channel"] as? Int else { return }
        if type == "cc", let cc = info["cc"] as? Int {
            draft.kind = .cc
            draft.cc = cc
            draft.channel = channel
            isLearning = false
        } else if type == "note", let note = info["note"] as? Int {
            draft.kind = .note
            draft.note = note
            draft.channel = channel
            isLearning = false
        }
        if !isLearning { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}

/// "Title ........ value" inside a Stepper.
struct InspectorValue: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).font(.cb(.body))
            Spacer()
            Text(value)
                .font(.cbMono(.body))
                .foregroundStyle(CBColor.textSecondary)
        }
    }
}
