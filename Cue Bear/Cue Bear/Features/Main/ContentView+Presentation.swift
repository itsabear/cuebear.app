//
//  ContentView+Presentation.swift — Cue Bear
//  ContentView: View Modifiers
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - View Modifiers (extracted to fix compiler type-checking timeout)

    @ViewBuilder
    /// v1.3 (Cue Bear Next): Show mode and Notes & Extras, kept out of the long sheet chain below
    /// so the compiler can type-check each part quickly.
    func applyNextFeatures<V: View>(_ view: V) -> some View {
        view
        // v1.3 (Cue Bear Next): the stage screen
        .fullScreenCover(isPresented: $showShowMode) {
            ShowModeView(
                store: store,
                coordinator: connectionCoordinator,
                wifiClient: wifiClient,
                usbServer: usbServer,
                rigs: BackupRigManager.shared,
                controlButtons: $controlButtons,
                projectName: isUntitledProject(projectName) ? "Untitled show" : projectName,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                startAfterSongID: lastPlayedCueID,
                onFire: { song in trigger(song) },
                onSharedControl: { button in triggerControl(button) },
                onExit: { showShowMode = false }
            )
        }
        // v1.3 (Cue Bear Next): Notes & Extras for one song
        .sheet(item: $songForDetails) { song in
            SongDetailsSheet(
                originalSong: song,
                sharedFaders: controlButtons.filter { $0.isFader == true },
                otherSongs: store.activeSongs.filter { $0.id != song.id },
                onSave: { updated in
                    saveSong(updated)
                    saveIfNamed()
                    songForDetails = nil
                },
                onCopyExtras: { ids, extras in
                    copyExtras(extras, toSongIDs: ids)
                },
                onCancel: { songForDetails = nil }
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
    }

    func applySheets<V: View>(_ view: V) -> some View {
        applyNextFeatures(view)
        // MARK: Sheets
        .sheet(isPresented: $showConnections) {
            CBConnectionsSheet(
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                onDisconnectWifi: { connectionCoordinator.disconnectWiFi() },
                onConnectWifiItem: { item in
                    connectionCoordinator.connectToWiFi(bridge: item)
                }
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showMidiTable) {
            MidiTableSheet(
                setlist: store.activeSongs,
                controlButtons: $controlButtons,
                isGlobalChannel: $isGlobalChannel,
                globalChannel: $globalChannel,
                midiFiltersEnabled: $midiFiltersEnabled,
                midiFilter: $midiFilter,
                customMidiFilters: $customMidiFilters,
                onDismiss: { showMidiTable = false },
                onApply: { items in
                    debugPrint("🎛️ [MIDI] Applying MIDI assignments: \(items.count) items")

                    // Write changes back to setlist and controls by id
                    store.updateActiveSongs { songs in
                        for i in 0..<songs.count {
                            if let edited = items.first(where: { $0.id == songs[i].id }) {
                                debugPrint("🎛️ [MIDI] Updating song '\(songs[i].name)': \(edited.midiType) Ch\(edited.channel) #\(edited.value)")
                                songs[i].kind = edited.midiType
                                songs[i].channel = edited.channel
                                if edited.midiType == .note { songs[i].note = edited.value } else { songs[i].cc = edited.value }
                            }
                        }
                    }

                    var controls = controlButtons
                    var updatedCount = 0
                    for i in 0..<controls.count {
                        if let edited = items.first(where: { $0.id == controls[i].id }) {
                            debugPrint("🎛️ [MIDI] Updating control '\(controls[i].title)' (was \(controls[i].kind) Ch\(controls[i].channel) #\(controls[i].number)) -> (now \(edited.midiType) Ch\(edited.channel) #\(edited.value))")
                            controls[i].kind = edited.midiType
                            controls[i].channel = edited.channel
                            controls[i].number = edited.value
                            updatedCount += 1
                        }
                    }
                    debugPrint("🎛️ [MIDI] Updated \(updatedCount) controls out of \(controls.count) total")
                    controlButtons = controls
                    markDirty()
                }
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showAddEdit, onDismiss: {
            // Tutorial 2b: Show Library tutorial after adding a cue
            if hasSeenTutorial2 && !hasSeenTutorial2b && isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.requestTutorial(21)  // 21 = tutorial 2b
                }
            }
        }) {
            CBAddEditCueSheet(
                editingSong: $editingSong,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                defaultName: nextDefaultCueName(),
                onSave: { song, andAddAnother in
                    saveCueWithDuplicateCheck(song, andAddAnother: andAddAnother) {
                        if andAddAnother {
                            // Close with linear animation (no slowdown) and reopen
                            withAnimation(.linear(duration: 0.15)) {
                                showAddEdit = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showAddEdit = true
                            }
                        } else {
                            // Normal close
                            showAddEdit = false
                        }
                    }
                },
                onCancel: {
                    // v1.0.8: Don't clear draft - it persists across dismissals
                    // Only close sheet
                    showAddEdit = false
                },
                onDelete: { song in
                    // Remove from cue list only (when in cue list context)
                    // Or delete from library (when in library context)
                    if isEditing {
                        removeFromSetlist(song)
                    } else {
                        deleteFromLibrary(song)
                    }
                    showAddEdit = false
                },
                onDeleteFromLibrary: { song in
                    // Delete from library (and all cue lists)
                    deleteFromLibrary(song)
                    showAddEdit = false
                },
                onDuplicate: { song in
                    // Create an alias cue
                    var aliasCue = song
                    aliasCue.id = UUID()  // New ID for the alias
                    aliasCue.aliasedCueID = song.id  // Reference to original cue

                    // Add to setlist
                    store.updateActiveSongs { $0.append(aliasCue) }
                    showAddEdit = false
                },
                editContext: isEditing ? .cueList : .library,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                midiFilter: midiFilter
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showAddEditMIDIOnly) {
            CBMIDIPickerSheet(
                title: "Change MIDI",
                kind: editingSong?.kind ?? .cc,
                number: (editingSong?.kind == .note) ? (editingSong?.note ?? 60) : (editingSong?.cc ?? 0),
                channel: editingSong?.channel ?? 1,
                velocity: editingSong?.velocity ?? 127,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                onSave: { kind, number, channel, velocity in
                    guard var s = editingSong else { return }
                    s.kind = kind
                    if kind == .note { s.note = number } else { s.cc = number }
                    s.channel = channel
                    s.velocity = velocity
                    saveSong(s)
                    showAddEditMIDIOnly = false
                },
                onCancel: { showAddEditMIDIOnly = false },
                editingSongName: editingSong?.name
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showControlEditor) {
            CBControlEditorSheet(
                editing: $editingControl,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                pendingIsFader: $pendingAddIsFader,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                midiFilter: midiFilter,
                onSave: { updated, andAddAnother in
                    if let idx = controlButtons.firstIndex(where: { $0.id == updated.id }) {
                        // Editing existing control
                        pushControlUndo()
                        // Force SwiftUI to detect the change by creating a new array
                        var updatedButtons = controlButtons
                        updatedButtons[idx] = updated
                        controlButtons = updatedButtons
                    } else {
                        // Adding new control
                        pushControlUndo()
                        // Assign grid position immediately when adding new control
                        var newControl = updated
                        if newControl.gridCol == nil || newControl.gridRow == nil {
                            // Find first available position based on control type
                            let buttonWidth = newControl.gridWidth
                            let buttonHeight = newControl.gridHeight

                            // Only check buttons on the same page for overlap
                            let pageButtons = controlButtons.filter { $0.page == newControl.page }

                            // Simple position finder - scan grid for first available spot
                            var foundPosition = false
                            for row in 0..<4 { // Scan up to 4 rows (matching display limit)
                                for col in 0..<(8 - buttonWidth + 1) { // 8 columns max, account for width
                                    var canPlace = true
                                    // Check if this position is free
                                    for existingButton in pageButtons {
                                        if let existingCol = existingButton.gridCol, let existingRow = existingButton.gridRow {
                                            let existingWidth = existingButton.gridWidth
                                            let existingHeight = existingButton.gridHeight

                                            // Check for overlap
                                            if !(col + buttonWidth <= existingCol ||
                                                existingCol + existingWidth <= col ||
                                                row + buttonHeight <= existingRow ||
                                                existingRow + existingHeight <= row) {
                                                canPlace = false
                                                break
                                            }
                                        }
                                    }
                                    if canPlace {
                                        newControl.gridCol = col
                                        newControl.gridRow = row
                                        foundPosition = true
                                        debugPrint("🔧 Assigned new control to position (\(col), \(row)) on page \(newControl.page)")
                                        break
                                    }
                                }
                                if foundPosition { break }
                            }

                            if !foundPosition {
                                // Fallback to 0,0 if no space found
                                newControl.gridCol = 0
                                newControl.gridRow = 0
                                debugPrint("🔧 No space found, placing new control at (0, 0) on page \(newControl.page)")
                            }
                        }
                        // Auto-assign random color for new controls if enabled and no color set
                        if autoAssignControlColors && newControl.colorHex == nil {
                            let usedColors = Set(controlButtons.compactMap { $0.colorHex })
                            let available = curatedColorPalette.filter { !usedColors.contains($0) }
                            if let random = available.randomElement() {
                                newControl.colorHex = random
                            } else {
                                newControl.colorHex = curatedColorPalette.randomElement()
                            }
                        }
                        controlButtons.append(newControl)
                    }
                    invalidateConflictCache()
                    markDirty()

                    if andAddAnother {
                        // Close with linear animation (no slowdown) and reopen
                        withAnimation(.linear(duration: 0.15)) {
                            showControlEditor = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showControlEditor = true
                        }
                    } else {
                        // Normal close
                        showControlEditor = false
                        pendingAddIsFader = nil
                    }
                },
                    onCancel: { showControlEditor = false; pendingAddIsFader = nil },
                onDelete: { control in
                    deleteControl(control)
                    showControlEditor = false
                    pendingAddIsFader = nil
                },
                allButtons: controlButtons,
                columns: 8,
                icons: icons,
                isEditMode: false,
                canAddMore: $canAddMoreControlsToGrid,
                flashNewForm: $flashNewFormControl,
                draft: controlEditorDraft  // v1.0.8: Pass draft manager
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showEditControlSheet) {
            CBControlEditorSheet(
                editing: $editingControlForEdit,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                pendingIsFader: $pendingAddIsFader,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                midiFilter: midiFilter,
                onSave: { updated, andAddAnother in
                    if let idx = controlButtons.firstIndex(where: { $0.id == updated.id }) {
                        // Editing existing control
                        pushControlUndo()
                        // Force SwiftUI to detect the change by creating a new array
                        var updatedButtons = controlButtons
                        updatedButtons[idx] = updated
                        controlButtons = updatedButtons
                    }
                    invalidateConflictCache()
                    markDirty()
                    // Edit sheet always closes (andAddAnother only for add sheet)
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                onCancel: {
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                onDelete: { control in
                    deleteControl(control)
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                allButtons: controlButtons,
                columns: 8,
                icons: icons,
                isEditMode: true,
                canAddMore: $canAddMoreControlsToGrid,
                flashNewForm: .constant(false),  // Edit mode doesn't use "Save & Add Another"
                draft: controlEditorDraft  // v1.0.8: Pass draft manager
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showProjects) {
            CBProjectsSheet(
                projectName: $projectName,
                projects: projectsList,
                isDirty: $isDirty,
                onTapTitleWhenUnsaved: { tempName = projectName; showNamePrompt = true },
                onLoad: { name in checkUnsavedChangesBeforeAction { loadProject(named: name) } },
                onDelete: { name in
                    debugPrint("🗑️ Delete button tapped for project: \(name)")

                    // If deleting the current project, switch to Untitled
                    if name == projectName {
                        debugPrint("🗑️ Deleting current project, switching to Untitled")
                        projectName = "Untitled"
                        isDirty = false
                    }

                    ProjectIO.delete(name: name)
                    projectsList = ProjectIO.list()
                    debugPrint("🗑️ Projects list after deletion: \(projectsList)")
                }
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            // v1.3 (Cue Bear Next): the step-by-step tutorials are retired; the demo show
            // and the connect checklist replace them.
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            hasSeenTutorial1 = true
            hasSeenTutorial2 = true
            hasSeenTutorial2b = true
            hasSeenTutorial2c = true
            hasSeenTutorial3 = true
        }) {
            FirstRunView(
                usbServer: usbServer,
                wifiClient: wifiClient,
                coordinator: connectionCoordinator,
                onSendTest: { sendFirstRunTest() },
                onConnectWiFi: { item in connectionCoordinator.connectToWiFi(bridge: item) },
                onTryShowMode: {
                    showOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showShowMode = true }
                },
                onDone: { showOnboarding = false }
            )
            .presentationBackground(CBColor.background)
            .presentationCornerRadius(CBRadius.panel)
            .interactiveDismissDisabled(false)
        }

        .sheet(isPresented: $showAboutSheet) {
            AboutSheet()
                .presentationBackground(CBColor.background)
                .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showAppearanceSheet) {
            AppearanceSheet()
                .presentationBackground(CBColor.background)
                .presentationCornerRadius(CBRadius.panel)
        }
        .sheet(isPresented: $showAppearanceSettingsSheet) {
            AppearanceSettingsSheet()
                .presentationBackground(CBColor.background)
                .presentationCornerRadius(CBRadius.panel)
        }
        #if DEBUG
        .sheet(isPresented: $showAdminPanel) {
            ThemeAdminPanel()
                .presentationBackground(CBColor.background)
                .presentationCornerRadius(CBRadius.panel)
        }
        #endif
        // Force default theme on every app launch
        .task {
            selectedThemeID = "default"
        }
        // TODO: Integrate tutorial overlay when ready
        // .overlay {
        //     TutorialOverlay(coordinator: tutorialCoordinator)
        // }
    }

    @ViewBuilder
    func applyAlerts<V: View>(_ view: V) -> some View {
        view
        .cbDialog("Project Name", isPresented: $showNamePrompt, themeFont: currentTheme.font,
            message: "Enter a name for your project.",
            textField: $tempName, textFieldPlaceholder: "Name",
            buttons: [
                .init("OK", role: .primary) {
                    let final = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !final.isEmpty else { return }
                    projectName = final
                    if shouldSaveAfterNaming {
                        snapshotAndSave(as: final, overwrite: false)
                        shouldSaveAfterNaming = false
                    }
                    showProjects = false
                },
                .init("Cancel", role: .cancel) {
                    shouldSaveAfterNaming = false
                }
            ]
        )
        .cbDialog("Rename Cue List", isPresented: $showCueListRenamePrompt, themeFont: currentTheme.font,
            message: "Enter a new name for this cue list.",
            textField: $tempCueListName, textFieldPlaceholder: "Name",
            buttons: [
                .init("Save", role: .primary) {
                    let final = tempCueListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !final.isEmpty, let cueListID = cueListToRename else { return }
                    if store.cueListNameExists(final, excluding: cueListID) {
                        duplicateRenameNewName = final
                        showDuplicateRenameAlert = true
                    } else {
                        store.renameCueList(cueListID, to: final)
                        isDirty = true
                        cueListToRename = nil
                    }
                },
                .init("Cancel", role: .cancel) {
                    cueListToRename = nil
                }
            ]
        )
        .cbDialog("Duplicate Name", isPresented: $showDuplicateRenameAlert, themeFont: currentTheme.font,
            message: "A cue list named \"\(duplicateRenameNewName)\" already exists. Do you want to use this name anyway?",
            buttons: [
                .init("Use Anyway", role: .primary) {
                    guard let cueListID = cueListToRename else { return }
                    store.renameCueList(cueListID, to: duplicateRenameNewName)
                    isDirty = true
                    cueListToRename = nil
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
        .cbDialog("New Cue List", isPresented: $showNewCueListPrompt, themeFont: currentTheme.font,
            message: "Enter a name for the new cue list.",
            textField: $newCueListName, textFieldPlaceholder: "Name",
            buttons: [
                .init("Create", role: .primary) {
                    let final = newCueListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !final.isEmpty else { return }
                    if store.cueListNameExists(final) {
                        duplicateCueListName = final
                        showDuplicateCueListAlert = true
                    } else {
                        let newID = store.createCueList(name: final)
                        store.switchToCueList(newID)
                        isDirty = true
                    }
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
        .cbDialog("Duplicate Name", isPresented: $showDuplicateCueListAlert, themeFont: currentTheme.font,
            message: "A cue list named \"\(duplicateCueListName)\" already exists in your song library.",
            buttons: [
                .init("Create A Copy", role: .primary) {
                    let newID = store.createCueList(name: duplicateCueListName, forceNumbered: true)
                    store.switchToCueList(newID)
                    isDirty = true
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
        .cbDialog("Duplicate Name", isPresented: $showDuplicateCueNameAlert, themeFont: currentTheme.font,
            message: "A cue named \"\(duplicateCueName)\" already exists in your library.",
            buttons: [
                .init("Rename to \"\(duplicateCueSuggestedName)\"", role: .primary) {
                    if var cue = pendingDuplicateCue {
                        let addAnother = pendingDuplicateCueAddAnother
                        cue.name = duplicateCueSuggestedName
                        saveSong(cue)
                        pendingDuplicateCue = nil
                        if addAnother {
                            withAnimation(.linear(duration: 0.15)) {
                                showAddEdit = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showAddEdit = true
                            }
                        } else {
                            showAddEdit = false
                        }
                    }
                },
                .init("Cancel", role: .cancel) {
                    pendingDuplicateCue = nil
                }
            ]
        )
        .cbDialog("Save Changes", isPresented: $showSaveChangesAlert, themeFont: currentTheme.font,
            message: "You have unsaved changes. Do you want to save them before continuing?",
            buttons: [
                .init("Save", role: .primary) {
                    saveCurrentProject(overwrite: true)
                    pendingAction?()
                    pendingAction = nil
                },
                .init("Don't Save", role: .destructive) {
                    pendingAction?()
                    pendingAction = nil
                },
                .init("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            ]
        )
        .cbDialog("Error Loading Project", isPresented: $showDocumentLoadError, themeFont: currentTheme.font,
            message: documentLoadErrorMessage,
            buttons: [
                .init("OK", role: .primary) {
                    documentLoadErrorMessage = ""
                }
            ]
        )
        .cbDialog("Delete Song", isPresented: $showDeleteConfirmation, themeFont: currentTheme.font,
            message: "Remove \"\(songToDelete?.name ?? "")\" from song library and cue list?",
            buttons: [
                .init("Delete from Both", role: .destructive) {
                    if let song = songToDelete {
                        performDeleteFromLibrary(song)
                    }
                    songToDelete = nil
                },
                .init("Cancel", role: .cancel) {
                    songToDelete = nil
                }
            ]
        )
    }

    @ViewBuilder
    func applyLifecycle<V: View>(_ view: V) -> some View {
        view
        // MARK: Lifecycle
        // FIX #1: Setup notification subscriptions on appear
        .onAppear {
            setupNotificationSubscriptions()
            cachedConflictLookup = computeConflictLookup()
            loadMidiFiltersFromUserDefaults()
        }
        .task {
            let loadStart = Date()
            debugPrint("🚀 App launch: hasCompletedInitialLaunch=\(hasCompletedInitialLaunch)")

            // Build initial conflict cache
            cachedConflictLookup = computeConflictLookup()

            // On very first ever launch, clear any stale state
            if !hasInitialized && !hasCompletedInitialLaunch {
                debugPrint("🔄 First launch — clearing all data")
                store.updateActiveSongs { $0.removeAll() }
                songLibrary.removeAll()
                controlButtons.removeAll()
                libAddedAt.removeAll()
                hasInitialized = true
            }

            // Load project list from disk
            projectsList = await Task.detached(priority: .userInitiated) { ProjectIO.list() }.value
            debugPrint("📁 Found \(projectsList.count) projects")

            // Load project data into memory if needed
            if songLibrary.isEmpty && !isUntitledProject(projectName) && !projectName.isEmpty {
                debugPrint("🔄 Loading project: \(projectName)")
                await autoOpenLastProject()
            } else if songLibrary.isEmpty && isUntitledProject(projectName) {
                if let saved = await Task.detached(priority: .userInitiated, operation: { ProjectIO.loadLibraryAutosave() }).value {
                    songLibrary = saved
                    debugPrint("📂 Restored \(saved.count) songs from autosave")
                }
            }

            // Rebuild cache after data load
            cachedConflictLookup = computeConflictLookup()
            debugPrint("🔄 Conflict cache: \(cachedConflictLookup.count) entries")

            // Splash shows for minimum 1.5s (first launch: 2.5s) — loading runs concurrently
            let minDuration: Double = hasCompletedInitialLaunch ? 1.5 : 2.5
            let elapsed = Date().timeIntervalSince(loadStart)
            let remaining = max(0.0, minDuration - elapsed)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            withAnimation(.easeInOut(duration: 0.5)) {
                debugPrint("🎬 Hiding splash screen")
                showSplash = false
            }

            hasCompletedInitialLaunch = true

            // v1.3 (Cue Bear Next): a brand-new user starts inside a real demo show
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
                && songLibrary.isEmpty
                && ProjectIO.list().contains(DemoShows.firstShowName) {
                loadProject(named: DemoShows.firstShowName)
            }

            // Show onboarding if not yet seen
            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            debugPrint("📖 Onboarding: hasSeenOnboarding=\(hasSeenOnboarding), crashAlertActive=\(crashAlertActive)")
            if !hasSeenOnboarding && !crashAlertActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showOnboarding = true
                }
            }

            debugPrint("✅ App initialization complete")
        }
        .onDisappear {
            // FIX #1: Clean up notification subscriptions to prevent memory leaks
            notificationCancellables.removeAll()
            // Don't stop connections completely - just pause them for background
            // This allows automatic reconnection when the app is reopened
            debugPrint("📱 App going to background - pausing connections")
            // Connections are managed by ConnectionCoordinator
        }
        // Connection monitoring now handled by ConnectionCoordinator
        .task(id: wifiClient.discovered.count) {
            debugPrint("🔍 Discovery changed: \(wifiClient.discovered.count) bridges found")
            debugPrint("🔌 USB connected: \(usbServer.isConnected), WiFi connected: \(wifiClient.isConnected)")
            
            // Simple status reporting - ConnectionCoordinator handles the logic
            if wifiClient.discovered.count > 0 {
                debugPrint("🔌 Bridge discovered - USB server running, WiFi available for manual connection")
            } else if wifiClient.discovered.count == 0 {
                debugPrint("⏸️ No bridges discovered - waiting for bridge to appear")
            } else if wifiClient.isConnected {
                debugPrint("✅ Already connected to bridge")
            } else {
                debugPrint("⏸️ Waiting for user to choose connection method")
            }
        }
        .task(id: store.mode) {
            if store.mode == .regular || store.mode == .regularPlusRemote { store.cuedSong = nil }
            updateConflictCache()
        }
        .task(id: store.activeSongs.map(\.id)) {
            updateConflictCache()
            if !isLoadingProject {
                markDirty()
            }
        }
        .task(id: songLibrary) {
            updateConflictCache()
            if !isLoadingProject {
                markDirty()
            }
        }
        .onChange(of: isGlobalChannel) { oldValue, newValue in
            handleGlobalChannelToggle(wasEnabled: oldValue, isEnabled: newValue)
        }
        .onChange(of: globalChannel) { oldValue, newValue in
            // When global channel number changes while global mode is enabled, reapply
            if isGlobalChannel && !isLoadingProject {
                debugPrint("🌍 Global channel changed from \(oldValue) to \(newValue) - reapplying to all items")
                applyGlobalChannel()
                invalidateConflictCache()
                markDirty()
            }
        }
        .onChange(of: midiFiltersEnabled) { _, _ in
            if !isLoadingProject { markDirty() }
        }
        .onChange(of: midiFilter) { _, newValue in
            if !isLoadingProject {
                markDirty()
                UserDefaults.standard.set(Array(newValue), forKey: "midiFilterCCs")
            }
        }
        .onChange(of: customMidiFilters.count) { _, _ in
            if !isLoadingProject {
                markDirty()
                saveMidiCustomFiltersToUserDefaults()
            }
        }
        .task(id: controlButtons) {
            updateConflictCache()
            if !isLoadingProject {
                markDirty()
            }
        }
    }

    @ViewBuilder func applyObservers<V: View>(_ view: V) -> some View {
        view
            .onChange(of: isDirty) { _, newValue in
                guard newValue, !isUntitledProject(projectName) else { return }
                autosaveWorkItem?.cancel()
                let currentProjectName = projectName
                let workItem = DispatchWorkItem {
                    snapshotAndSave(as: currentProjectName, overwrite: true)
                }
                autosaveWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
            }
            .onChange(of: songLibrary) { _, newLibrary in
                DispatchQueue.global(qos: .utility).async {
                    ProjectIO.saveLibraryAutosave(newLibrary)
                }
            }
            .onChange(of: isEditing) { _, newValue in
                if !newValue {
                    libBatchMode = false
                    libSelected.removeAll()
                    setlistBatchMode = false
                    setlistSelected.removeAll()
                    reorderMode = false
                    WobbleAnimator.shared.stopAll()
                }
            }
            .onChange(of: libraryQuery) { _, newQuery in
                isTyping = !newQuery.isEmpty
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if libraryQuery == newQuery {
                        libraryQueryDebounced = newQuery
                        isTyping = false
                    }
                }
            }
            .onChange(of: setlistQuery) { _, newQuery in
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if setlistQuery == newQuery {
                        setlistQueryDebounced = newQuery
                    }
                }
            }
    }
}
