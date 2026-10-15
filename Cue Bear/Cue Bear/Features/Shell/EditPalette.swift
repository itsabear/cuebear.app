//
//  EditPalette.swift — Cue Bear Next
//
//  The tool palette docked along the bottom while editing (see the flow map, "Build becomes Edit").
//  + Song, Library, Button / Toggle / Fader (drag onto the board, or tap to add at the end),
//  All songs | This song (shared control or extra for the selected song), Undo, Redo.
//

import SwiftUI
import UIKit

/// Where a new control goes: on every song (shared) or only on the selected song (an extra).
enum EditTarget: String {
    case allSongs, thisSong
}

struct EditPalette<Library: View>: View {
    @Binding var target: EditTarget
    @Binding var showLibrary: Bool
    let selectedSongName: String?
    let canUndo: Bool
    let canRedo: Bool
    var onNewSong: () -> Void
    var onTool: (BoardItem.Kind) -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    @ViewBuilder var library: () -> Library

    var body: some View {
        HStack(spacing: CBSpace.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CBSpace.s) {
                    Button(action: onNewSong) { Label("Song", systemImage: "plus") }
                        .buttonStyle(.cbPrimary)
                        .accessibilityLabel("Add a song")
                    Button(action: { showLibrary.toggle() }) { Label("Library", systemImage: "books.vertical") }
                        .buttonStyle(.cbSecondary)
                        .popover(isPresented: $showLibrary, arrowEdge: .bottom) {
                            library()
                                .frame(minWidth: 340, minHeight: 420)
                                .presentationCompactAdaptation(.popover)
                                .presentationBackground(CBColor.background)
                        }
                    divider
                    tool(.button, "Button", "square")
                    tool(.toggle, "Toggle", "power")
                    tool(.fader, "Fader", "slider.horizontal.3")
                    targetSwitch
                }
                .padding(.vertical, 2)
            }
            CBSheetIconButton(systemName: "arrow.uturn.backward", disabled: !canUndo, action: onUndo)
                .accessibilityLabel("Undo")
            CBSheetIconButton(systemName: "arrow.uturn.forward", disabled: !canRedo, action: onRedo)
                .accessibilityLabel("Redo")
        }
        .padding(.horizontal, CBSpace.l)
        .frame(height: 72)
        .background(CBColor.background)
        .overlay(alignment: .top) {
            Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
        }
    }

    private var divider: some View {
        Rectangle().fill(CBColor.stroke).frame(width: CBSize.hairline, height: 32)
    }

    /// Drag onto the board to place it there, or tap to add it at the end.
    private func tool(_ kind: BoardItem.Kind, _ title: String, _ symbol: String) -> some View {
        Button(action: { onTool(kind) }) { Label(title, systemImage: symbol) }
            .buttonStyle(.cbSecondary)
            .draggable(ControlsBoard.tool(kind)) {
                Label(title, systemImage: symbol)
                    .font(.cb(.body, .semibold))
                    .foregroundStyle(CBColor.textPrimary)
                    .padding(.horizontal, CBSpace.l)
                    .frame(height: CBSize.control)
                    .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surfaceRaised))
            }
            .accessibilityLabel("Add a \(title.lowercased())")
            .accessibilityHint(target == .thisSong ? "Adds it to the selected song only" : "Adds it to every song")
    }

    private var targetSwitch: some View {
        HStack(spacing: 0) {
            segment("All songs", .allSongs)
            segment(selectedSongName.map { "Only \($0)" } ?? "This song", .thisSong)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surface))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("New controls go on")
    }

    private func segment(_ label: String, _ value: EditTarget) -> some View {
        let selected = target == value
        return Button(action: { target = value }) {
            Text(label)
                .font(.cb(.small, selected ? .bold : .regular))
                .foregroundStyle(selected ? CBColor.onPrimary : CBColor.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, CBSpace.m)
                .frame(height: 38)
                .frame(maxWidth: 200)
                .background(RoundedRectangle(cornerRadius: CBRadius.small).fill(selected ? CBColor.primary : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(value == .thisSong && selectedSongName == nil)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
