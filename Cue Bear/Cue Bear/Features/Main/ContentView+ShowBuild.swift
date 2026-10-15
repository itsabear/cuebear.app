//
//  ContentView+ShowBuild.swift — Cue Bear Next
//
//  The app's two halves: Show (perform) and Build (set up), and the bar above them.
//  ContentView keeps the data and the actions (save, undo, MIDI); this file wires them to
//  ModeBar, ShowModeView, BuildScreen and the two inspectors.
//

import SwiftUI
import UIKit

extension ContentView {

    // MARK: - Mode

    var screenMode: CBScreenMode { CBScreenMode(rawValue: screenModeRaw) ?? .show }

    var screenModeBinding: Binding<CBScreenMode> {
        Binding(get: { screenMode }, set: { newMode in
            screenModeRaw = newMode.rawValue
            if newMode == .build { isShowLocked = false }
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
        let controlsUndo = screenMode == .build && buildTab == .controls
        return ModeBar(
            title: modeBarTitle,
            mode: screenModeBinding,
            isLocked: $isShowLocked,
            showTitlePopover: $showCueListChooser,
            coordinator: connectionCoordinator,
            wifiClient: wifiClient,
            rigs: BackupRigManager.shared,
            canUndo: controlsUndo ? !controlUndoStack.isEmpty : (!setlistUndoStack.isEmpty || !libraryUndoStack.isEmpty),
            canRedo: controlsUndo ? !controlRedoStack.isEmpty : (!setlistRedoStack.isEmpty || !libraryRedoStack.isEmpty),
            onMenu: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { showSideMenu.toggle() }
            },
            onConnections: { showConnections = true },
            onUndo: {
                if controlsUndo { undoControls() } else { performUndo() }
                inspectorUndoSongID = nil
                inspectorUndoControlID = nil
            },
            onRedo: {
                if controlsUndo { redoControls() } else { performRedo() }
            }
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

    // MARK: - Show

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
            onBuild: {
                buildTab = .setlist
                screenModeRaw = CBScreenMode.build.rawValue
            }
        )
    }

    // MARK: - Build

    var buildScreenView: some View {
        let ordered = controlButtons.inShowOrder
        return BuildScreen(
            tab: $buildTab,
            songs: store.activeSongs,
            library: songLibrary,
            controls: ordered,
            selectedSongID: $buildSelectedSongID,
            selectedControlID: $buildSelectedControlID,
            onMoveSongs: { from, to in
                pushSetlistUndo()
                store.updateActiveSongs { $0.move(fromOffsets: from, toOffset: to) }
                markDirty()
            },
            onRemoveSongs: { ids in
                pushSetlistUndo()
                store.updateActiveSongs { $0.removeAll { ids.contains($0.id) } }
                if let sel = buildSelectedSongID, ids.contains(sel), buildTab == .setlist { buildSelectedSongID = nil }
                invalidateConflictCache()
                markDirty()
            },
            onDeleteSongs: { ids in deleteSongsFromLibrary(ids) },
            onNewSong: { newSongFromBuild() },
            onAddToSetlist: { song in addToSetlist(song) },
            onNewControl: { fader in newControlFromBuild(fader: fader) },
            onMoveControl: { moving, before in moveControl(moving, before: before) },
            songInspector: { song in
                AnyView(
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
                            removeFromSetlist(song)
                            if buildTab == .setlist { buildSelectedSongID = nil }
                        },
                        onAddToSetlist: { addToSetlist(song) },
                        onDeleteFromLibrary: {
                            buildSelectedSongID = nil
                            deleteFromLibrary(song)
                        }
                    )
                    .id(song.id)
                )
            },
            controlInspector: { control in
                AnyView(
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
                            buildSelectedControlID = nil
                            deleteControl(control)
                        }
                    )
                    .id(control.id)
                )
            }
        )
    }

    // MARK: - Build actions

    /// A new song with a free CC, added to the library and this cue list, then selected.
    func newSongFromBuild() {
        var n = songLibrary.count + 1
        var name = "Song \(n)"
        while songLibrary.contains(where: { $0.name == name }) {
            n += 1
            name = "Song \(n)"
        }
        let song = Song(name: name, cc: max(0, firstFreeCC()), channel: 1)
        let after = buildTab == .setlist ? buildSelectedSongID : nil
        saveSong(song)   // adds to the library and to the end of this cue list
        // Land it under the selected song, where the user is working
        if let after, let target = store.activeSongs.firstIndex(where: { $0.id == after }) {
            store.updateActiveSongs { songs in
                if let i = songs.firstIndex(where: { $0.id == song.id }) {
                    let moved = songs.remove(at: i)
                    songs.insert(moved, at: min(target + 1, songs.count))
                }
            }
        }
        inspectorUndoSongID = song.id   // saveSong already made the undo step
        buildTab = .setlist
        buildSelectedSongID = song.id
    }

    /// The inspector applies every edit as it happens; only the first edit of a song makes an undo step.
    func updateSongFromInspector(_ song: Song) {
        if inspectorUndoSongID != song.id {
            pushSetlistUndo()
            pushLibraryUndo()
            inspectorUndoSongID = song.id
        }
        store.updateActiveSongs { songs in
            if let i = songs.firstIndex(where: { $0.id == song.id }) { songs[i] = song }
        }
        if let j = songLibrary.firstIndex(where: { $0.id == song.id }) {
            songLibrary[j] = song
        }
        invalidateConflictCache()
        markDirty()
    }

    /// Build's "Send now": plays the message once so the DAW can MIDI-learn it. Changes nothing.
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

    /// Library › Select › Delete: removes the songs everywhere (all cue lists), one undo step.
    func deleteSongsFromLibrary(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        pushSetlistUndo()
        pushLibraryUndo()
        for i in store.cueLists.indices {
            let before = store.cueLists[i].songs.count
            store.cueLists[i].songs.removeAll { ids.contains($0.id) }
            if store.cueLists[i].songs.count != before { store.cueLists[i].touch() }
        }
        songLibrary.removeAll { ids.contains($0.id) }
        for id in ids { libAddedAt[id] = nil }
        if let sel = buildSelectedSongID, ids.contains(sel) { buildSelectedSongID = nil }
        invalidateConflictCache()
        markDirty()
    }

    /// Board drag: puts `moving` just before `before` in Show's order.
    func moveControl(_ moving: UUID, before: UUID) {
        var list = controlButtons.normalizedShowOrder
        guard let from = list.firstIndex(where: { $0.id == moving }) else { return }
        pushControlUndo()
        let item = list.remove(at: from)
        let to = list.firstIndex(where: { $0.id == before }) ?? list.count
        list.insert(item, at: to)
        for k in list.indices { list[k].gridRow = k }
        controlButtons = list
        inspectorUndoControlID = nil
        markDirty()
    }

    func newControlFromBuild(fader: Bool) {
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        var control = ControlButton(title: nextDefaultControlName(fader ? "Fader" : "Button"),
                                    symbol: fader ? "" : "square.grid.2x2.fill",
                                    kind: .cc, number: freeCC, channel: 1,
                                    isFader: fader ? true : nil,
                                    isSmall: fader ? nil : true,
                                    faderValue: fader ? 0 : nil)
        pushControlUndo()
        var list = controlButtons.normalizedShowOrder
        control.gridRow = list.count
        control.gridCol = 0
        control.page = 0
        list.append(control)
        controlButtons = list
        inspectorUndoControlID = control.id
        invalidateConflictCache()
        markDirty()
        buildSelectedControlID = control.id
    }

    func updateControlFromInspector(_ control: ControlButton) {
        if inspectorUndoControlID != control.id {
            pushControlUndo()
            inspectorUndoControlID = control.id
        }
        if let i = controlButtons.firstIndex(where: { $0.id == control.id }) {
            controlButtons[i] = control
        }
        invalidateConflictCache()
        markDirty()
    }

    /// Moves a shared control one place earlier (-1) or later (+1) in Show's order.
    func moveControl(_ id: UUID, by offset: Int) {
        var list = controlButtons.normalizedShowOrder
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard j >= 0, j < list.count else { return }
        pushControlUndo()
        list.swapAt(i, j)
        for k in list.indices { list[k].gridRow = k }
        controlButtons = list
        inspectorUndoControlID = nil
        markDirty()
    }
}
