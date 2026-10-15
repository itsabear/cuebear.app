//
//  BuildScreen.swift — Cue Bear Next
//
//  The Build half of Show | Build (see the flow map, CLAUDE.md §7).
//  Tabs across the top: Setlist, Controls, Library.
//  - Setlist / Library: the list on the left, the selected song's editor on the right.
//  - Controls: the board exactly as Show draws it, edited in place, with the editor beside it
//    (below it in portrait).
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
    var onRemoveSongs: (Set<UUID>) -> Void
    var onDeleteSongs: (Set<UUID>) -> Void
    var onNewSong: () -> Void
    var onAddToSetlist: (Song) -> Void
    var onNewControl: (_ fader: Bool) -> Void
    var onMoveControl: (_ moving: UUID, _ before: UUID) -> Void
    var songInspector: (Song) -> AnyView
    var controlInspector: (ControlButton) -> AnyView

    @State private var libraryQuery = ""
    @State private var isSelecting = false
    @State private var picked: Set<UUID> = []

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.width < 900
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, CBSpace.l)
                    .padding(.vertical, CBSpace.m)
                Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
                switch tab {
                case .setlist, .library:
                    HStack(spacing: 0) {
                        Group {
                            if tab == .setlist { setlistList } else { libraryList }
                        }
                        .padding(CBSpace.l)
                        .frame(width: portrait ? 300 : 380)
                        Rectangle().fill(CBColor.separator).frame(width: CBSize.hairline)
                        songEditor
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .controls:
                    if portrait {
                        VStack(spacing: 0) {
                            board.frame(maxHeight: geo.size.height * 0.45)
                            Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
                            controlEditor.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        HStack(spacing: 0) {
                            board.frame(maxWidth: .infinity, maxHeight: .infinity)
                            Rectangle().fill(CBColor.separator).frame(width: CBSize.hairline)
                            controlEditor.frame(width: 380)
                        }
                    }
                }
            }
        }
        .background(CBColor.background)
        .onChange(of: tab) { _, _ in
            isSelecting = false
            picked.removeAll()
        }
    }

    // MARK: - Tabs

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
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Select several

    private func selectHeader(title: String, count: Int, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: CBSpace.s) {
            Text(isSelecting ? "\(picked.count) selected" : "\(count) \(title)")
                .font(.cb(.small))
                .foregroundStyle(CBColor.textTertiary)
            Spacer()
            if isSelecting {
                Button(actionTitle) {
                    action()
                    picked.removeAll()
                    isSelecting = false
                }
                .buttonStyle(.cbDestructive)
                .disabled(picked.isEmpty)
            }
            Button(isSelecting ? "Done" : "Select") {
                isSelecting.toggle()
                picked.removeAll()
            }
            .buttonStyle(.cbSecondary)
            .disabled(count == 0)
        }
    }

    private func toggle(_ id: UUID) {
        if picked.contains(id) { picked.remove(id) } else { picked.insert(id) }
    }

    // MARK: - Setlist

    private var moveAction: ((IndexSet, Int) -> Void)? {
        isSelecting ? nil : onMoveSongs
    }

    private var deleteAction: ((IndexSet) -> Void)? {
        if isSelecting { return nil }
        let list = songs
        let remove = onRemoveSongs
        return { offsets in remove(Set(offsets.map { list[$0].id })) }
    }

    private var setlistList: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            selectHeader(title: songs.count == 1 ? "song" : "songs", count: songs.count, actionTitle: "Remove") {
                onRemoveSongs(picked)
            }
            if songs.isEmpty {
                emptyNote("Add your first song. Each one sends a MIDI message when you press GO in Show.")
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button(action: {
                            if isSelecting { toggle(song.id) } else { selectedSongID = song.id }
                        }) {
                            BuildSongRow(index: index + 1, song: song,
                                         isSelected: !isSelecting && selectedSongID == song.id,
                                         isPicked: isSelecting ? picked.contains(song.id) : nil)
                        }
                        .buttonStyle(.plain)
                        .buildRowStyle()
                    }
                    .onMove(perform: moveAction)
                    .onDelete(perform: deleteAction)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                Text("Hold a song and drag to reorder. Swipe left to remove it from this cue list.")
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

    // MARK: - Library

    private var filteredLibrary: [Song] {
        let sorted = library.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let q = libraryQuery.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? sorted : sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var libraryList: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            TextField("Search songs", text: $libraryQuery)
                .textFieldStyle(CBTextFieldStyle())
            selectHeader(title: library.count == 1 ? "song" : "songs", count: library.count, actionTitle: "Delete") {
                onDeleteSongs(picked)
            }
            if library.isEmpty {
                emptyNote("Every song you make lands here, so you can reuse it in other cue lists.")
            } else {
                ScrollView {
                    VStack(spacing: CBSpace.s) {
                        ForEach(filteredLibrary) { song in
                            let inSetlist = songs.contains(where: { $0.id == song.id })
                            HStack(spacing: CBSpace.s) {
                                Button(action: {
                                    if isSelecting { toggle(song.id) } else { selectedSongID = song.id }
                                }) {
                                    BuildSongRow(index: nil, song: song,
                                                 isSelected: !isSelecting && selectedSongID == song.id,
                                                 isPicked: isSelecting ? picked.contains(song.id) : nil)
                                }
                                .buttonStyle(.plain)
                                if !isSelecting {
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

    // MARK: - Controls board

    private var board: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CBSpace.m) {
                Text(controls.isEmpty
                     ? "Add the controls you press on every song, like Play, Stop or a vocal effect."
                     : "This is how they look in Show. Tap one to edit it, hold and drag to move it.")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.textTertiary)
                ControlsBoard(
                    items: controls.map { BoardItem(control: $0) },
                    mode: .build,
                    selectedID: selectedControlID,
                    onSelect: { selectedControlID = $0 },
                    onMove: onMoveControl,
                    onAdd: onNewControl
                )
            }
            .padding(CBSpace.xl)
        }
    }

    // MARK: - Editors

    @ViewBuilder
    private var songEditor: some View {
        if let id = selectedSongID,
           let song = songs.first(where: { $0.id == id }) ?? library.first(where: { $0.id == id }) {
            songInspector(song)
        } else {
            placeholder(tab == .setlist ? "Pick a song on the left to edit it, or add a new one."
                                        : "Pick a song to edit it, or add it to this cue list.")
        }
    }

    @ViewBuilder
    private var controlEditor: some View {
        if let id = selectedControlID, let control = controls.first(where: { $0.id == id }) {
            controlInspector(control)
        } else {
            placeholder("Tap a control to edit it, or + to add one.")
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
    /// nil = not selecting; true / false = picked for "remove several"
    var isPicked: Bool? = nil

    var body: some View {
        HStack(spacing: CBSpace.s) {
            if let isPicked {
                Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                    .font(.cbIcon(.large, .regular))
                    .foregroundStyle(isPicked ? CBColor.highlight : CBColor.textTertiary)
            } else if let index {
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
        .accessibilityAddTraits(isSelected || isPicked == true ? .isSelected : [])
    }
}
