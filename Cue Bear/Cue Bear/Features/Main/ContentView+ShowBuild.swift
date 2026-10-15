//
//  ContentView+ShowBuild.swift — Cue Bear Next
//
//  Show and Edit: one screen (ShowModeView). Edit adds selection, dragging, the tool palette
//  (EditPalette) and an editor panel for the selected song or control. ContentView keeps the data
//  and the actions (save, undo, MIDI); this file wires them together. See the flow map,
//  "Build becomes Edit".
//

import SwiftUI
import UIKit

/// The editor panel open in Edit
enum EditPanel: Equatable {
    case song(UUID)
    case control(UUID)
}

extension ContentView {

    // MARK: - Mode

    var screenMode: CBScreenMode { CBScreenMode(rawValue: screenModeRaw) ?? .show }
    var isEditingShow: Bool { screenMode == .build }

    var screenModeBinding: Binding<CBScreenMode> {
        Binding(get: { screenMode }, set: { newMode in
            screenModeRaw = newMode.rawValue
            if newMode == .build {
                isShowLocked = false
                if buildSelectedSongID == nil || !store.activeSongs.contains(where: { $0.id == buildSelectedSongID }) {
                    buildSelectedSongID = lastPlayedCueID ?? store.activeSongs.first?.id
                }
            } else {
                editPanel = nil
                showEditLibrary = false
            }
        })
    }

    var showDisplayName: String {
        isUntitledProject(projectName) ? "Untitled show" : projectName
    }

    var modeBarTitle: String {
        if let list = store.activeCueList?.name, !list.isEmpty {
            return "\(showDisplayName) · \(list)"
        }
        return showDisplayName
    }

    // MARK: - Bar

    var modeBarView: some View {
        return ModeBar(
            title: modeBarTitle,
            mode: screenModeBinding,
            isLocked: $isShowLocked,
            showTitlePopover: $showCueListChooser,
            coordinator: connectionCoordinator,
            wifiClient: wifiClient,
            rigs: BackupRigManager.shared,
            onMenu: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { showSideMenu.toggle() }
            },
            onConnections: { showConnections = true }
        ) {
            CueListChooserPopover(
                cueLists: $store.cueLists,
                activeCueListID: $store.activeCueListID,
                selectedThemeID: selectedThemeID,
                projectName: projectName,
                onSwitchCueList: { id in
                    if id != store.activeCueListID {
                        store.switchToCueList(id)
                        isDirty = true
                        saveCurrentProject(overwrite: true)
                    }
                    showCueListChooser = false
                },
                onDuplicate: { id in
                    if let newID = store.duplicateCueList(id) {
                        store.switchToCueList(newID)
                        isDirty = true
                        saveCurrentProject(overwrite: true)
                    }
                },
                onRename: { id in
                    if let list = store.cueLists.first(where: { $0.id == id }) {
                        cueListToRename = id
                        tempCueListName = list.name
                        showCueListRenamePrompt = true
                    }
                },
                onDelete: { id in
                    store.deleteCueList(id)
                    isDirty = true
                },
                onCreateNew: {
                    newCueListName = "New Cue List"
                    showNewCueListPrompt = true
                },
                onRenameProject: {
                    tempName = projectName
                    showNamePrompt = true
                }
            )
            .tint(CBColor.textPrimary)
        }
    }

    // MARK: - The stage: Show, or Show being edited

    /// Everything under the bar: the Show screen, plus the editor panel and the palette while editing.
    var stageView: some View {
        GeometryReader { geo in
            let portrait = geo.size.width < 900
            VStack(spacing: 0) {
                if portrait {
                    VStack(spacing: 0) {
                        showScreenView
                        if isEditingShow, editPanel != nil {
                            Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
                            editorPanel
                                .frame(height: geo.size.height * 0.45)
                                .transition(.move(edge: .bottom))
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        showScreenView
                        if isEditingShow, editPanel != nil {
                            Rectangle().fill(CBColor.separator).frame(width: CBSize.hairline)
                            editorPanel
                                .frame(width: 380)
                                .transition(.move(edge: .trailing))
                        }
                    }
                }
                if isEditingShow {
                    editPaletteView
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: editPanel)
            .animation(.easeInOut(duration: 0.2), value: isEditingShow)
        }
        .sheet(item: $editingExtra) { extra in
            SongExtraEditor(extra: extra,
                            onSave: { updated in saveExtra(updated) },
                            onDelete: { deleteExtra(extra.id) },
                            onCancel: { editingExtra = nil })
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
    }

    var showScreenView: some View {
        ShowModeView(
            store: store,
            coordinator: connectionCoordinator,
            wifiClient: wifiClient,
            usbServer: usbServer,
            rigs: BackupRigManager.shared,
            controlButtons: $controlButtons,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel,
            startAfterSongID: lastPlayedCueID,
            onFire: { song in trigger(song) },
            onSharedControl: { button in triggerControl(button) },
            onBuild: { screenModeBinding.wrappedValue = .build },
            edit: isEditingShow ? showEditContext : nil
        )
    }

    var showEditContext: ShowEdit {
        ShowEdit(
            selectedSongID: buildSelectedSongID,
            selectedControlID: { () -> UUID? in
                if case .control(let id)? = editPanel { return id }
                return nil
            }(),
            onSelectSong: { id in
                buildSelectedSongID = id
                editPanel = .song(id)
            },
            onSelectBoardItem: { id in
                if controlButtons.contains(where: { $0.id == id }) {
                    buildSelectedControlID = id
                    editPanel = .control(id)
                } else if let extra = selectedEditSong?.extras?.first(where: { $0.id == id }) {
                    editingExtra = extra
                }
            },
            onMoveSong: { moving, before in moveSong(moving, before: before) },
            onMoveControl: { moving, before in moveControl(moving, before: before) },
            onDropTool: { kind, before in addFromPalette(kind, before: before) },
            onTry: { song in sendNow(song) }
        )
    }

    var selectedEditSong: Song? {
        guard let id = buildSelectedSongID else { return nil }
        return store.activeSongs.first(where: { $0.id == id }) ?? songLibrary.first(where: { $0.id == id })
    }

    // MARK: - Palette

    var editPaletteView: some View {
        EditPalette(
            target: $editTarget,
            showLibrary: $showEditLibrary,
            selectedSongName: selectedEditSong?.name,
            canUndo: lastEditWasControls ? !controlUndoStack.isEmpty : (!setlistUndoStack.isEmpty || !libraryUndoStack.isEmpty),
            canRedo: lastEditWasControls ? !controlRedoStack.isEmpty : (!setlistRedoStack.isEmpty || !libraryRedoStack.isEmpty),
            onNewSong: { newSongFromBuild() },
            onTool: { kind in addFromPalette(kind, before: nil) },
            onUndo: {
                if lastEditWasControls { undoControls() } else { performUndo() }
                inspectorUndoSongID = nil
                inspectorUndoControlID = nil
            },
            onRedo: {
                if lastEditWasControls { redoControls() } else { performRedo() }
            }
        ) {
            EditLibraryList(
                library: songLibrary,
                inCueList: Set(store.activeSongs.map(\.id)),
                onAdd: { song in
                    addToSetlist(song)
                    lastEditWasControls = false
                    buildSelectedSongID = song.id
                }
            )
        }
    }

    // MARK: - Editor panel

    @ViewBuilder
    var editorPanel: some View {
        let ordered = controlButtons.inShowOrder
        ZStack(alignment: .topTrailing) {
            switch editPanel {
            case .song(let id)?:
                if let song = store.activeSongs.first(where: { $0.id == id }) ?? songLibrary.first(where: { $0.id == id }) {
                    SongInspector(
                        song: song,
                        sharedFaders: ordered.filter { $0.isFader == true },
                        isInSetlist: store.activeSongs.contains(where: { $0.id == song.id }),
                        isConnected: connectionCoordinator.activeConnection != .none,
                        otherSongs: store.activeSongs.filter { $0.id != song.id },
                        conflictName: { kind, channel, number in
                            ownerName(for: MIDIKey(kind: kind, channel: channel, number: number))
                        },
                        onChange: { updated in updateSongFromInspector(updated) },
                        onSendNow: { s in sendNow(s) },
                        onCopyExtras: { ids, extras in copyExtras(extras, toSongIDs: ids) },
                        onDuplicate: { duplicateSong(song) },
                        onRemoveFromSetlist: {
                            editPanel = nil
                            removeFromSetlist(song)
                            buildSelectedSongID = store.activeSongs.first?.id
                        },
                        onAddToSetlist: { addToSetlist(song) },
                        onDeleteFromLibrary: {
                            editPanel = nil
                            buildSelectedSongID = nil
                            deleteFromLibrary(song)
                        }
                    )
                    .id(song.id)
                }
            case .control(let id)?:
                if let control = ordered.first(where: { $0.id == id }) {
                    ControlInspector(
                        control: control,
                        isFirst: ordered.first?.id == control.id,
                        isLast: ordered.last?.id == control.id,
                        isConnected: connectionCoordinator.activeConnection != .none,
                        conflictName: { kind, channel, number in
                            ownerName(for: MIDIKey(kind: kind, channel: channel, number: number))
                        },
                        onChange: { updated in updateControlFromInspector(updated) },
                        onSendNow: { c in sendNow(c) },
                        onMoveEarlier: { moveControl(control.id, by: -1) },
                        onMoveLater: { moveControl(control.id, by: 1) },
                        onDelete: {
                            editPanel = nil
                            buildSelectedControlID = nil
                            deleteControl(control)
                        }
                    )
                    .id(control.id)
                }
            case nil:
                EmptyView()
            }
            CBSheetIconButton(systemName: "xmark", action: { editPanel = nil })
                .accessibilityLabel("Close the editor")
                .padding(CBSpace.s)
        }
        .background(CBColor.background)
    }

    // MARK: - Edit actions

    /// + Song: a new song with a free CC, under the selected one, selected, editor open.
    func newSongFromBuild() {
        var n = songLibrary.count + 1
        var name = "Song \(n)"
        while songLibrary.contains(where: { $0.name == name }) {
            n += 1
            name = "Song \(n)"
        }
        let song = Song(name: name, cc: max(0, firstFreeCC()), channel: 1)
        let after = buildSelectedSongID
        saveSong(song)   // adds to the library and to the end of this cue list (one undo step)
        if let after, let target = store.activeSongs.firstIndex(where: { $0.id == after }) {
            store.updateActiveSongs { songs in
                if let i = songs.firstIndex(where: { $0.id == song.id }) {
                    let moved = songs.remove(at: i)
                    songs.insert(moved, at: min(target + 1, songs.count))
                }
            }
        }
        inspectorUndoSongID = song.id
        lastEditWasControls = false
        buildSelectedSongID = song.id
        editPanel = .song(song.id)
    }

    /// The editors apply every edit as it happens; only the first edit of a song makes an undo step.
    func updateSongFromInspector(_ song: Song) {
        if inspectorUndoSongID != song.id {
            pushSetlistUndo()
            pushLibraryUndo()
            inspectorUndoSongID = song.id
        }
        lastEditWasControls = false
        store.updateActiveSongs { songs in
            if let i = songs.firstIndex(where: { $0.id == song.id }) { songs[i] = song }
        }
        if let j = songLibrary.firstIndex(where: { $0.id == song.id }) {
            songLibrary[j] = song
        }
        invalidateConflictCache()
        markDirty()
    }

    /// Setlist drag in Edit: puts `moving` just before `before`.
    func moveSong(_ moving: UUID, before: UUID) {
        pushSetlistUndo()
        lastEditWasControls = false
        store.updateActiveSongs { songs in
            guard let from = songs.firstIndex(where: { $0.id == moving }) else { return }
            let item = songs.remove(at: from)
            let to = songs.firstIndex(where: { $0.id == before }) ?? songs.count
            songs.insert(item, at: to)
        }
        markDirty()
    }

    /// A palette tool, tapped (before == nil: at the end) or dropped on the board.
    /// "This song" makes an extra for the selected song; "All songs" a shared control.
    func addFromPalette(_ kind: BoardItem.Kind, before: UUID?) {
        if editTarget == .thisSong, var song = selectedEditSong {
            var extras = song.extras ?? []
            let used = Set(extras.map(\.number))
            var number = 40
            while used.contains(number) && number < 119 { number += 1 }
            let style: SongExtra.Style = kind == .fader ? .fader : (kind == .toggle ? .toggle : .button)
            let extra = SongExtra(title: "Extra \(extras.count + 1)", style: style, number: number, channel: song.channel)
            extras.append(extra)
            song.extras = extras
            inspectorUndoSongID = nil
            updateSongFromInspector(song)
            editingExtra = extra
        } else {
            newControlFromBuild(kind, before: before)
        }
    }

    func saveExtra(_ extra: SongExtra) {
        guard var song = selectedEditSong else { editingExtra = nil; return }
        var list = song.extras ?? []
        if let i = list.firstIndex(where: { $0.id == extra.id }) { list[i] = extra } else { list.append(extra) }
        song.extras = list
        updateSongFromInspector(song)
        editingExtra = nil
    }

    func deleteExtra(_ id: UUID) {
        guard var song = selectedEditSong else { editingExtra = nil; return }
        song.extras?.removeAll(where: { $0.id == id })
        if song.extras?.isEmpty == true { song.extras = nil }
        inspectorUndoSongID = nil
        updateSongFromInspector(song)
        editingExtra = nil
    }

    /// Edit's Try and the editors' Send now: plays the message once so the DAW can MIDI-learn it.
    func sendNow(_ song: Song) {
        guard song.midiEnabled else { return }
        let number = song.kind == .cc ? song.cc : (song.note ?? 60)
        let value = song.kind == .cc ? 127 : song.velocity
        let ch = isGlobalChannel ? globalChannel : song.channel
        connectionCoordinator.sendMIDI(type: song.kind, channel: ch, number: number, value: value,
                                       label: song.name, buttonID: song.id.uuidString)
        if song.kind == .note {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                connectionCoordinator.sendMIDI(type: .note, channel: ch, number: number, value: 0,
                                               label: song.name, buttonID: song.id.uuidString)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func sendNow(_ control: ControlButton) {
        let kind: MIDIKind = control.isFader == true ? .cc : control.kind
        let value: Int = control.isFader == true
            ? Int(((control.faderValue ?? 0) * 127).rounded())
            : (kind == .cc ? 127 : control.velocity)
        let ch = isGlobalChannel ? globalChannel : control.channel
        connectionCoordinator.sendMIDI(type: kind, channel: ch, number: control.number, value: value,
                                       label: control.title, buttonID: control.id.uuidString)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Board drag: puts `moving` just before `before` (nil = the end) in Show's order.
    func moveControl(_ moving: UUID, before: UUID?) {
        var list = controlButtons.normalizedShowOrder
        guard let from = list.firstIndex(where: { $0.id == moving }) else { return }
        pushControlUndo()
        lastEditWasControls = true
        let item = list.remove(at: from)
        let to = before.flatMap { b in list.firstIndex(where: { $0.id == b }) } ?? list.count
        list.insert(item, at: to)
        for k in list.indices { list[k].gridRow = k }
        controlButtons = list
        inspectorUndoControlID = nil
        markDirty()
    }

    /// A new shared control with a free CC, placed before `before` (nil = the end), selected, editor open.
    func newControlFromBuild(_ kind: BoardItem.Kind, before: UUID?) {
        let fader = kind == .fader
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        var control = ControlButton(title: nextDefaultControlName(fader ? "Fader" : (kind == .toggle ? "Toggle" : "Button")),
                                    symbol: fader ? "" : (kind == .toggle ? "power" : "square.grid.2x2.fill"),
                                    kind: .cc, number: freeCC, channel: 1,
                                    isToggle: kind == .toggle ? true : nil,
                                    isFader: fader ? true : nil,
                                    isSmall: fader ? nil : true,
                                    faderValue: fader ? 0 : nil)
        pushControlUndo()
        lastEditWasControls = true
        var list = controlButtons.normalizedShowOrder
        let at = before.flatMap { b in list.firstIndex(where: { $0.id == b }) } ?? list.count
        control.page = 0
        control.gridCol = 0
        list.insert(control, at: at)
        for k in list.indices { list[k].gridRow = k }
        controlButtons = list
        inspectorUndoControlID = control.id
        invalidateConflictCache()
        markDirty()
        buildSelectedControlID = control.id
        editPanel = .control(control.id)
    }

    func updateControlFromInspector(_ control: ControlButton) {
        if inspectorUndoControlID != control.id {
            pushControlUndo()
            inspectorUndoControlID = control.id
        }
        lastEditWasControls = true
        if let i = controlButtons.firstIndex(where: { $0.id == control.id }) {
            controlButtons[i] = control
        }
        invalidateConflictCache()
        markDirty()
    }

    /// The editor's Earlier / Later buttons (the accessible alternative to dragging).
    func moveControl(_ id: UUID, by offset: Int) {
        var list = controlButtons.normalizedShowOrder
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard j >= 0, j < list.count else { return }
        pushControlUndo()
        lastEditWasControls = true
        list.swapAt(i, j)
        for k in list.indices { list[k].gridRow = k }
        controlButtons = list
        inspectorUndoControlID = nil
        markDirty()
    }
}

// MARK: - Library list (palette › Library)

/// Every song in the show, A to Z, with search; Add puts a song into this cue list.
struct EditLibraryList: View {
    let library: [Song]
    let inCueList: Set<UUID>
    var onAdd: (Song) -> Void
    @State private var query = ""

    private var filtered: [Song] {
        let sorted = library.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? sorted : sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            CBSectionLabel("Library")
            TextField("Search songs", text: $query)
                .textFieldStyle(CBTextFieldStyle())
            if library.isEmpty {
                Text("Every song you make lands here, so you can reuse it in other cue lists.")
                    .font(.cb(.body))
                    .foregroundStyle(CBColor.textSecondary)
            }
            ScrollView {
                VStack(spacing: CBSpace.s) {
                    ForEach(filtered) { song in
                        HStack(spacing: CBSpace.s) {
                            Circle()
                                .fill(song.colorHex.map { Color(hex: $0) } ?? CBColor.surfaceRaised)
                                .frame(width: 12, height: 12)
                            Text(song.name)
                                .font(.cb(.body))
                                .foregroundStyle(CBColor.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: CBSpace.s)
                            if inCueList.contains(song.id) {
                                CBTag(text: "IN LIST", color: CBColor.surfaceRaised)
                            } else {
                                Button("Add") { onAdd(song) }
                                    .buttonStyle(.cbSecondary)
                                    .accessibilityLabel("Add \(song.name) to this cue list")
                            }
                        }
                        .padding(.horizontal, CBSpace.m)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surface))
                    }
                }
            }
        }
        .padding(CBSpace.l)
        .cbSheetChrome()
    }
}
