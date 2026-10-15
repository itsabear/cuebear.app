//
//  BuildScreen.swift — Cue Bear Next
//
//  The Build half of Show | Build. Left: what you are building (Setlist, Controls, Library tabs).
//  Right: an inspector for whatever is picked on the left. Nothing pops up over anything else,
//  except the small editor for one song extra.
//

import SwiftUI
import UIKit

enum BuildTab: String, CaseIterable, Identifiable {
    case setlist, controls, library
    var id: String { rawValue }
    var title: String {
        switch self {
        case .setlist: return "Setlist"
        case .controls: return "Controls"
        case .library: return "Library"
        }
    }
}

/// "CC 32 · ch 1" / "Note 60 · ch 2"
func cbMIDISummary(kind: MIDIKind, number: Int, channel: Int) -> String {
    (kind == .cc ? "CC \(number)" : "Note \(number)") + " · ch \(channel)"
}

struct BuildScreen: View {
    @Binding var tab: BuildTab
    let songs: [Song]
    let library: [Song]
    let controls: [ControlButton]
    @Binding var selectedSongID: UUID?
    @Binding var selectedControlID: UUID?

    var onMoveSongs: (IndexSet, Int) -> Void
    var onRemoveSongs: (IndexSet) -> Void
    var onNewSong: () -> Void
    var onAddToSetlist: (Song) -> Void
    var onNewControl: (_ fader: Bool) -> Void
    var songInspector: (Song) -> AnyView
    var controlInspector: (ControlButton) -> AnyView

    @State private var libraryQuery = ""

    var body: some View {
        GeometryReader { geo in
            let leftWidth: CGFloat = geo.size.width < 900 ? 300 : 380
            HStack(spacing: 0) {
                leftPanel
                    .frame(width: leftWidth)
                Rectangle().fill(CBColor.separator).frame(width: CBSize.hairline)
                rightPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(CBColor.background)
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            tabPicker
            switch tab {
            case .setlist: setlistTab
            case .controls: controlsTab
            case .library: libraryTab
            }
        }
        .padding(CBSpace.l)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BuildTab.allCases) { t in
                let selected = tab == t
                Button(action: { tab = t }) {
                    Text(t.title)
                        .font(.cb(.small, selected ? .bold : .regular))
                        .foregroundStyle(selected ? CBColor.textPrimary : CBColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: CBRadius.small).fill(selected ? CBColor.surfaceRaised : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surface))
    }

    // MARK: Setlist

    private var setlistTab: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            if songs.isEmpty {
                emptyNote("No songs in this cue list yet. Add a new song, or bring one in from the library.")
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button(action: { selectedSongID = song.id }) {
                            BuildSongRow(index: index + 1, song: song, isSelected: selectedSongID == song.id)
                        }
                        .buttonStyle(.plain)
                        .buildRowStyle()
                    }
                    .onMove(perform: onMoveSongs)
                    .onDelete(perform: onRemoveSongs)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                Text("Hold a song and drag to reorder. Swipe left to remove it from this list.")
                    .font(.cb(.caption))
                    .foregroundStyle(CBColor.textTertiary)
            }
            Spacer(minLength: 0)
            HStack(spacing: CBSpace.s) {
                Button("+ New song", action: onNewSong)
                    .buttonStyle(CBButtonStyle(kind: .primary, fullWidth: true))
                Button("From library") { tab = .library }
                    .buttonStyle(CBButtonStyle(kind: .secondary, fullWidth: true))
            }
        }
    }

    // MARK: Controls

    private var controlsTab: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            Text("On every song, in this order in Show.")
                .font(.cb(.small))
                .foregroundStyle(CBColor.textTertiary)
            if controls.isEmpty {
                emptyNote("No controls yet. Add a button or a fader for things you press on every song, like Play, Stop or a vocal effect.")
            } else {
                ScrollView {
                    VStack(spacing: CBSpace.s) {
                        ForEach(controls) { control in
                            Button(action: { selectedControlID = control.id }) {
                                BuildControlRow(control: control, isSelected: selectedControlID == control.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: CBSpace.s) {
                Button("+ Button") { onNewControl(false) }
                    .buttonStyle(CBButtonStyle(kind: .primary, fullWidth: true))
                Button("+ Fader") { onNewControl(true) }
                    .buttonStyle(CBButtonStyle(kind: .secondary, fullWidth: true))
            }
        }
    }

    // MARK: Library

    private var filteredLibrary: [Song] {
        let sorted = library.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let q = libraryQuery.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? sorted : sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var libraryTab: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            TextField("Search songs", text: $libraryQuery)
                .textFieldStyle(CBTextFieldStyle())
            if library.isEmpty {
                emptyNote("Every song you make lands here, so you can reuse it in other cue lists.")
            } else {
                ScrollView {
                    VStack(spacing: CBSpace.s) {
                        ForEach(filteredLibrary) { song in
                            let inSetlist = songs.contains(where: { $0.id == song.id })
                            HStack(spacing: CBSpace.s) {
                                Button(action: { selectedSongID = song.id }) {
                                    BuildSongRow(index: nil, song: song, isSelected: selectedSongID == song.id)
                                }
                                .buttonStyle(.plain)
                                if inSetlist {
                                    CBTag(text: "IN LIST", color: CBColor.surfaceRaised)
                                } else {
                                    Button("Add") { onAddToSetlist(song) }
                                        .buttonStyle(CBButtonStyle(kind: .secondary))
                                        .accessibilityLabel("Add \(song.name) to this cue list")
                                }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.cb(.body))
            .foregroundStyle(CBColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cbCard()
    }

    // MARK: - Right panel

    @ViewBuilder
    private var rightPanel: some View {
        switch tab {
        case .setlist, .library:
            if let id = selectedSongID,
               let song = songs.first(where: { $0.id == id }) ?? library.first(where: { $0.id == id }) {
                songInspector(song)
            } else {
                placeholder(tab == .setlist ? "Pick a song on the left to edit it, or add a new one."
                                            : "Pick a song to edit it, or add it to this cue list.")
            }
        case .controls:
            if let id = selectedControlID, let control = controls.first(where: { $0.id == id }) {
                controlInspector(control)
            } else {
                placeholder("Pick a control on the left to edit it, or add a new one.")
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.cb(.body))
            .foregroundStyle(CBColor.textTertiary)
            .multilineTextAlignment(.center)
            .padding(CBSpace.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rows

private extension View {
    /// List row without the system's insets, separators or background.
    func buildRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

struct BuildSongRow: View {
    let index: Int?
    let song: Song
    let isSelected: Bool

    var body: some View {
        HStack(spacing: CBSpace.s) {
            if let index {
                Text("\(index)")
                    .font(.cbMono(.small))
                    .foregroundStyle(CBColor.textTertiary)
                    .frame(width: 22, alignment: .trailing)
            }
            Circle()
                .fill(song.colorHex.map { Color(hex: $0) } ?? CBColor.surfaceRaised)
                .frame(width: 12, height: 12)
            Text(song.name)
                .font(.cb(.body, isSelected ? .bold : .regular))
                .foregroundStyle(CBColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: CBSpace.xs)
            if let n = song.extras?.count, n > 0 {
                CBTag(text: n == 1 ? "1 EXTRA" : "\(n) EXTRAS", color: CBColor.surfaceRaised)
            }
            Text(song.midiEnabled ? cbMIDISummary(kind: song.kind, number: song.kind == .cc ? song.cc : (song.note ?? 60), channel: song.channel) : "No MIDI")
                .font(.cbMono(.caption))
                .foregroundStyle(isSelected ? CBColor.textSecondary : CBColor.textTertiary)
        }
        .padding(.horizontal, CBSpace.m)
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: CBRadius.control)
            .fill(isSelected ? CBColor.highlight.opacity(0.25) : CBColor.surface))
        .overlay(RoundedRectangle(cornerRadius: CBRadius.control)
            .stroke(isSelected ? CBColor.highlight : Color.clear, lineWidth: CBSize.selection))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BuildControlRow: View {
    let control: ControlButton
    let isSelected: Bool

    private var typeName: String {
        if control.isFader == true { return "Fader" }
        return control.isToggle == true ? "Toggle" : "Button"
    }

    private var icon: String {
        if control.isFader == true { return "slider.horizontal.3" }
        return control.symbol.isEmpty ? "square" : control.symbol
    }

    var body: some View {
        HStack(spacing: CBSpace.m) {
            Image(systemName: icon)
                .font(.cbIcon(.body))
                .foregroundStyle(CBColor.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: CBSpace.xxs) {
                Text(control.title.isEmpty ? typeName : control.title)
                    .font(.cb(.body, isSelected ? .bold : .regular))
                    .foregroundStyle(CBColor.textPrimary)
                    .lineLimit(1)
                Text(typeName)
                    .font(.cb(.caption))
                    .foregroundStyle(CBColor.textTertiary)
            }
            Spacer(minLength: CBSpace.xs)
            Text(cbMIDISummary(kind: control.isFader == true ? .cc : control.kind, number: control.number, channel: control.channel))
                .font(.cbMono(.caption))
                .foregroundStyle(CBColor.textTertiary)
        }
        .padding(.horizontal, CBSpace.m)
        .frame(height: 56)
        .background(RoundedRectangle(cornerRadius: CBRadius.control)
            .fill(isSelected ? CBColor.highlight.opacity(0.25) : CBColor.surface))
        .overlay(RoundedRectangle(cornerRadius: CBRadius.control)
            .stroke(isSelected ? CBColor.highlight : Color.clear, lineWidth: CBSize.selection))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
