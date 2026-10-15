//
//  ContentView.swift — Cue Bear (v1.16c)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - ContentView
internal struct ContentView: View {
    // Icon library for control buttons
    let icons = [
        // Transport & Control
        "backward.end.fill", "backward.frame.fill",
        "forward.end.fill", "forward.frame.fill",
        "pause.circle.fill", "pause.fill",
        "play.circle.fill", "play.fill", "play.square.fill",
        "record.circle.fill",
        "stop.circle.fill", "stop.fill",

        // Music & Performance - Strings & Keys
        "pianokeys", "pianokeys.inverse",

        // Music & Performance - Vocals & Microphones
        "mic.fill",

        // Music & Performance - Notes & Notation
        "music.note", "music.note.list", "music.quarternote.3",

        // Music & Performance - Audio Equipment
        "radio", "radio.fill",
        "hifispeaker", "hifispeaker.fill",
        "hifispeaker.2", "hifispeaker.2.fill",
        "homepod", "homepod.fill",
        "homepod.2", "homepod.2.fill",
        "headphones", "headphones.circle.fill",

        // Audio & Mixing
        "dial.max",
        "ear.fill",
        "slider.horizontal.3",
        "speaker.slash.fill",
        "speaker.wave.2.fill", "speaker.wave.3.fill",
        "waveform",
        "waveform.circle", "waveform.circle.fill",
        "waveform.path",
        "waveform.path.badge.minus",
        "waveform.path.ecg", "waveform.path.ecg.rectangle",

        // Effects & Processing
        "arrow.down.circle.fill", "arrow.up.circle.fill",
        "arrow.up.right.circle.fill",
        "bolt.circle.fill", "bolt.fill",
        "building.columns.fill",
        "burst.fill",
        "cloud.bolt.fill",
        "dot.radiowaves.left.and.right",
        "repeat.1.circle.fill", "repeat.circle.fill",
        "sparkles",
        "wave.3.right.circle.fill",

        // Song Structure
        "b.circle.fill", "b.square.fill",
        "c.circle.fill", "c.square.fill",
        "flag.checkered",
        "i.circle.fill",
        "o.circle.fill",
        "v.circle.fill", "v.square.fill",

        // Numbers & Markers
        "1.circle", "1.square.fill",
        "2.circle", "2.square.fill",
        "3.circle", "3.square.fill",
        "4.circle", "4.circle.fill",
        "5.circle",
        "6.circle",
        "8.circle.fill",

        // People & Groups
        "person.2.fill", "person.3.fill",

        // Lighting & Theater
        "arrow.down.square.fill", "arrow.up.square.fill",
        "hands.clap.fill",
        "light.beacon.max.fill",
        "light.max", "light.min",

        // Utility
        "circle.hexagongrid.fill",
        "memories",
        "minus.circle.fill",
        "plus.circle.fill",
        "square.grid.2x2.fill"
    ]

    @EnvironmentObject var store: SetlistStore
    @Environment(\.scenePhase) private var scenePhase

    // Simple connection systems - USB server + WiFi client
    @EnvironmentObject var usbServer: ConnectionManager
    @EnvironmentObject var wifiClient: BridgeOutput
    @EnvironmentObject var connectionCoordinator: ConnectionCoordinator

    // UI state
    @State private var showConnections = false
    @State private var showAddEdit = false
    @State private var editingSong: Song? = nil
    @State private var isEditing = false
    @State private var modeBeforeEditing: AppMode? = nil  // Remember mode before entering edit mode
    @State private var editModeTab: Int = 1  // iPhone only: 0 = Library, 1 = Cue List
    @State private var showEditModeViewPicker = false  // iPhone only: Show sheet to choose view
    @State private var reorderMode = false  // v1.0.9: Reorder mode for cue list
    @State private var setlistBatchMode = false  // Batch select mode for cue list
    @State private var setlistSelected: Set<UUID> = []  // Selected cues in batch mode
    @State private var showLibraryPopover = false  // Show song library popover
    @State private var showCueListChooser = false  // Show cue list chooser popover

    // Library state
    @State private var songLibrary: [Song] = []
    @State private var libBatchMode = false
    @State private var libSelected: Set<UUID> = []
    @State private var sortMode: LibrarySortMode = .nameAZ
    @State private var libAddedAt: [UUID: Date] = [:]
    @State private var libraryQuery: String = ""
    @State private var libraryQueryDebounced: String = ""
    @State private var setlistQuery: String = ""
    @State private var setlistQueryDebounced: String = ""
    @FocusState private var isSetlistSearchFocused: Bool

    // Splash Screen - v1.0.8: Use AppStorage to persist across view recreations
    @AppStorage("hasCompletedInitialLaunch") private var hasCompletedInitialLaunch = false
    @State private var showSplash = true
    @State private var hasInitialized = false

    // v1.0.8: Draft managers to preserve edits across sheet dismissals
    @StateObject private var cueEditorDraft = CueEditorDraft()
    @StateObject private var controlEditorDraft = ControlEditorDraft()

    // Onboarding Tutorial State
    // Flow: Onboarding → T1 (Edit btn) → T2 (+ btn) → T2b (Library btn) → exit edit → T2c (cue list name) → T3 (Controls)
    @AppStorage("hasSeenTutorial1") private var hasSeenTutorial1 = false  // Tutorial 1: Edit button
    @AppStorage("hasSeenTutorial2") private var hasSeenTutorial2 = false  // Tutorial 2: + button
    @AppStorage("hasSeenTutorial2b") private var hasSeenTutorial2b = false  // Tutorial 2b: Library button
    @AppStorage("hasSeenTutorial2c") private var hasSeenTutorial2c = false  // Tutorial 2c: Cue list name
    @AppStorage("hasSeenTutorial3") private var hasSeenTutorial3 = false  // Tutorial 3: Controls capsule
    // Tutorial 4 removed (two-finger scroll no longer exists)
    @State private var showTutorial1 = false  // Tutorial 1: Edit button (after onboarding)
    @State private var showTutorial2 = false  // Tutorial 2: + button (after clicking Edit)
    @State private var showTutorial2b = false  // Tutorial 2b: Library button
    @State private var showTutorial2c = false  // Tutorial 2c: Cue list name button (after exiting edit)
    @State private var showTutorial3 = false  // Tutorial 3: Controls capsule
    // showTutorial4 removed (two-finger scroll no longer exists)
    @State private var interruptedTutorial: Int? = nil  // Track which tutorial was interrupted by nav/cue capsule tutorial (1, 2, 2 for 2b, 3 for 2c, 4 for 3)
    @State private var pendingTutorial: Int? = nil  // Tutorial waiting to be shown (queued because another is active)

    /// Check if any tutorial is currently showing
    private var isAnyTutorialShowing: Bool {
        showTutorial1 || showTutorial2 || showTutorial2b || showTutorial2c || showTutorial3
    }

    /// Request to show a tutorial - will queue if another is active
    /// Tutorial IDs: 1=Edit, 2=AddCue, 2b=Library, 2c=CueListName, 3=Controls
    private func requestTutorial(_ tutorialId: Int) {
        if isAnyTutorialShowing {
            // Queue this tutorial to show after current one is dismissed
            pendingTutorial = tutorialId
            debugPrint("📖 [Tutorial] Tutorial \(tutorialId) queued - another tutorial is active")
        } else {
            // Show immediately
            showTutorialById(tutorialId)
        }
    }

    /// Show a tutorial by its ID
    private func showTutorialById(_ tutorialId: Int) {
        switch tutorialId {
        case 1: showTutorial1 = true
        case 2: showTutorial2 = true
        case 21: showTutorial2b = true  // Using 21 for 2b
        case 22: showTutorial2c = true  // Using 22 for 2c
        case 3: showTutorial3 = true
        default: break
        }
        debugPrint("📖 [Tutorial] Showing tutorial \(tutorialId)")
    }

    /// Called when a tutorial is dismissed - shows pending tutorial if any
    private func onTutorialDismissed() {
        if let pending = pendingTutorial {
            pendingTutorial = nil
            // Small delay before showing next tutorial for smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !self.isAnyTutorialShowing {
                    self.showTutorialById(pending)
                }
            }
        }
    }

    // Tutorial frame tracking (for positioning tutorials)
    @State private var editButtonFrame: CGRect = .zero  // Edit button in top right capsule
    @State private var addCueButtonFrame: CGRect = .zero  // + button in edit mode
    @State private var libraryButtonFrame: CGRect = .zero  // Library button (book icon)
    @State private var cueListNameButtonFrame: CGRect = .zero  // Cue list name button (top left)
    @State private var controlsCapsuleFrame: CGRect = .zero  // Controls capsule (bottom right)
    // controlAreaFrame removed (tutorial 4 no longer exists)

    // Projects
    @State private var showProjects = false
    @State private var showOnboarding = false
    @State private var showShowMode = false  // v1.3: the stage screen (Now, Next, GO)
    @State private var songForDetails: Song? = nil  // v1.3: Notes & Extras sheet
    @Binding var crashAlertActive: Bool  // Prevents onboarding from showing while crash alert is active
    @AppStorage("lastProjectName") private var projectName: String = "Untitled"
    @State private var projectsList: [String] = []
    @State private var isDirty: Bool = false
    @State private var showNamePrompt: Bool = false
    @State private var tempName: String = ""
    @State private var showSaveChangesAlert: Bool = false
    @State private var pendingAction: (() -> Void)? = nil
    @State private var shouldSaveAfterNaming: Bool = false  // Track if we should save after user names the project

    // Cue list renaming
    @State private var showCueListRenamePrompt: Bool = false
    @State private var cueListToRename: UUID? = nil
    @State private var tempCueListName: String = ""
    @State private var showDuplicateRenameAlert: Bool = false
    @State private var duplicateRenameNewName: String = ""

    // Cue list creation
    @State private var showNewCueListPrompt: Bool = false
    @State private var newCueListName: String = ""
    @State private var showDuplicateCueListAlert: Bool = false
    @State private var duplicateCueListName: String = ""

    // Duplicate cue name detection
    @State private var showDuplicateCueNameAlert: Bool = false
    @State private var duplicateCueName: String = ""
    @State private var duplicateCueSuggestedName: String = ""
    @State private var pendingDuplicateCue: Song? = nil
    @State private var pendingDuplicateCueAddAnother: Bool = false

    // Navigation capsule (Regular + Remote mode)
    @State private var lastTriggeredSongIndex: Int = 0

    // Last played cue (for play icon indicator)
    @State private var lastPlayedCueID: UUID? = nil

    // Selected/chosen cue (for expanded width in cue list)
    @State private var selectedCue: UUID? = nil

    // Song deletion confirmation
    @State private var showDeleteConfirmation: Bool = false
    @State private var songToDelete: Song? = nil

    // Document loading error alert
    @State private var showDocumentLoadError: Bool = false
    @State private var documentLoadErrorMessage: String = ""

    // Control Area (formerly transport)
    @State private var controlButtons: [ControlButton] = []
    @State private var controlEditMode = false
    @State private var controlAreaCollapsed: Bool = false  // Track if control area is collapsed
    @State private var currentControlPage: Int = 0  // Current page (0-3) for multi-page control area
    @State private var controlsPerRow: Int = 4
    @State private var controlAreaHeight: CGFloat = 0
    @State private var showCollapsedCapsule: Bool = false  // Control visibility for sequential animation
    @State private var showExpandedArea: Bool = false  // Control visibility for sequential animation
    @State private var isAnimatingControlArea: Bool = false  // Track if control area is animating
    @State private var controlSectionReady: Bool = false  // PERFORMANCE: Delay CBControlSection creation until after initial layout
    @State private var titleBarBottom: CGFloat = 88  // Bottom edge of title bar (default: safe area + title height)
    @State private var editCapsuleBottom: CGFloat = 0  // Bottom edge of edit/search capsules when visible
    @State private var capsuleBounds: [String: CGRect] = [:]  // Track all UI capsule bounds for collision detection
    @State private var canAddMoreControlsToGrid: Bool = true  // Track if grid has space for new controls
    @State private var controlEditModeTimer: Timer? = nil  // Auto-exit timer for edit mode
    @State private var showControlEditor: Bool = false
    @State private var editingControl: ControlButton? = nil
    @State private var showEditControlSheet: Bool = false
    @State private var editingControlForEdit: ControlButton? = nil
    @State private var showMidiTable: Bool = false
    @State private var flashNewFormControl: Bool = false  // Visual feedback for "Save & Add Another" in control editor

    // Notification subscriptions (to prevent memory leaks)
    @State private var notificationCancellables: Set<AnyCancellable> = []

    // Global MIDI Channel
    @State private var isGlobalChannel: Bool = false
    @State private var globalChannel: Int = 1
    // Backup of original channels before enabling global mode
    @State private var savedSongChannels: [UUID: Int] = [:]
    @State private var savedControlChannels: [UUID: Int] = [:]
    // Flag to prevent backup/restore during project loading
    @State private var isLoadingProject: Bool = false

    // MIDI Filter - persisted globally via UserDefaults (not per-project)
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    @State private var midiFilter: Set<Int> = [1, 7, 10, 11, 64, 120, 121, 122, 123, 124, 125, 126, 127]
    @State private var customMidiFilters: [(Int, String)] = []

    // Undo/Redo
    @State private var setlistUndoStack: [[Song]] = []
    @State private var setlistRedoStack: [[Song]] = []
    @State private var libraryUndoStack: [[Song]] = []
    @State private var libraryRedoStack: [[Song]] = []
    @State private var controlUndoStack: [[ControlButton]] = []
    @State private var controlRedoStack: [[ControlButton]] = []

    // Misc
    @State private var autosaveTask: Task<Void, Never>? = nil
    // FIX #4: Replace task-based autosave with DispatchWorkItem
    @State private var autosaveWorkItem: DispatchWorkItem? = nil
    @State private var showAddEditMIDIOnly = false
    @State private var pendingAddIsFader: Bool? = nil
    @State private var isTyping: Bool = false
    @State private var flashingCueID: UUID? = nil  // Tracks which cue should flash

    // Side Menu
    @State private var showSideMenu = false
    @State private var modeChangeWorkItem: DispatchWorkItem?
    @State private var showAboutSheet = false
    @State private var showAppearanceSheet = false
    @State private var showAppearanceSettingsSheet = false
    #if DEBUG
    @State private var showAdminPanel = false
    @State private var adminPanelPressTimer: Timer? = nil
    @State private var adminPanelPressCount = 0
    #endif

    // Theme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var currentTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // Effective default cue color (custom overrides theme default)
    private var effectiveDefaultCueColorHex: String {
        customDefaultCueColorStorage.isEmpty ? currentTheme.defaultCueColorHexValue(for: colorScheme) : customDefaultCueColorStorage
    }

    // Appearance Settings
    @AppStorage("showMIDIData") private var showMIDIData: Bool = true
    @AppStorage("cueHeight") private var cueHeight: Double = 110
    @AppStorage("navigationPillSize") private var navigationPillSize: Double = 0.85
    @AppStorage("cueCapsuleSize") private var cueCapsuleSize: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 1.0
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignCueColors") private var autoAssignCueColors: Bool = true
    @AppStorage("autoAssignControlColors") private var autoAssignControlColors: Bool = true

    // Performance caches
    @State private var cachedConflictLookup: [MIDIKey: String] = [:]
    @State private var cacheVersion: Int = 0
    @State private var cachedUsedCCs: Set<Int> = []
    // FIX #5: Conflict cache throttling
    @State private var conflictCacheUpdateScheduled = false

    // Control Area constraints
    private let maxControlRows: Int = 5

    

    // Visuals
    private var connectionTint: Color { connectionCoordinator.activeConnection != .none ? .green : .red }
    // activeIsUSB removed - now handled by ConnectionCoordinator

    // Break up body for compiler
    private var topBarView: some View {
            CBTopBar(
                mode: $store.mode,
                showSideMenu: $showSideMenu,
                isEditing: $isEditing,
                isGlobalChannel: $isGlobalChannel,
                globalChannel: $globalChannel,
                showLibraryPopover: $showLibraryPopover,
                songLibrary: $songLibrary,
                activeCueListSongs: Binding(
                    get: { store.activeSongs },
                    set: { _ in }
                ),
                editingSong: $editingSong,
                showAddEdit: $showAddEdit,
                cueLists: $store.cueLists,
                activeCueListID: $store.activeCueListID,
                showCueListChooser: $showCueListChooser,
                libAddedAt: libAddedAt,
                selectedThemeID: selectedThemeID,
                projectTitle: projectName,
                connectionTint: connectionTint,
                connectionCoordinator: connectionCoordinator,
                titleBarColor: currentTheme.titleBarColor(for: colorScheme),
                buttonColor: .white,
                textColor: .white,
                lightButtonBackgroundColor: currentTheme.lightButtonBackgroundColor(for: colorScheme),
                themeFont: { size, weight in .cb(points: size, weight) },
                // Core actions
                onConnections: {
                    if isEditing { isEditing = false }
                    showConnections = true
                },
                onEditToggle: {
                    withAnimation(.easeInOut) {
                        isEditing.toggle()

                        // Reset selection when entering edit mode
                        if isEditing {
                            store.cuedSong = nil
                            if store.mode == .cue {
                                store.mode = .regular
                            }
                        }
                    }
                },
                onAdd: {
                    // Don't exit edit mode when adding a new cue
                    editingSong = nil
                    showAddEdit = true

                    // Tutorial 2: Dismiss when clicking + button
                    if showTutorial2 {
                        showTutorial2 = false
                        hasSeenTutorial2 = true
                        onTutorialDismissed()
                    }
                    // Will trigger tutorial 2b after the add sheet closes
                },
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                canUndo: !setlistUndoStack.isEmpty || !libraryUndoStack.isEmpty,
                canRedo: !setlistRedoStack.isEmpty || !libraryRedoStack.isEmpty,
                onMenuToggle: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        showSideMenu.toggle()
                        // Exit edit mode when opening side menu
                        if showSideMenu {
                            isEditing = false
                        }
                    }
                },
                onAddToSetlist: { song in
                    addToSetlist(song)
                },
                onDeleteFromLibrary: { song in
                    deleteFromLibrary(song)
                },
                // Menu actions
                onRenameProject: {
                    if isEditing { isEditing = false }
                    tempName = projectName
                    showNamePrompt = true
                },
                onNewProject: {
                    if isEditing { isEditing = false }
                    newProjectFlow()
                },
                onSave: {
                    if isEditing { isEditing = false }
                    saveCurrentProject(overwrite: true)
                },
                onSaveAs: {
                    if isEditing { isEditing = false }
                    saveCurrentProject(overwrite: false)
                },
                onOpenProject: {
                    if isEditing { isEditing = false }
                    openProjectFlow()
                },
                onImport: {
                    if isEditing { isEditing = false }
                    openDocumentPicker()
                },
                onExport: {
                    if isEditing { isEditing = false }
                    exportCurrentProject()
                },
                onShowMidiSettings: {
                    if isEditing { isEditing = false }
                    showMidiTable = true
                },
                onShowAppearance: {
                    if isEditing { isEditing = false }
                    showAppearanceSheet = true
                },
                onShowOnboarding: {
                    if isEditing { isEditing = false }
                    // Only show onboarding if crash alert is not active
                    if !crashAlertActive {
                        showOnboarding = true
                    }
                },
                onShowAbout: {
                    if isEditing { isEditing = false }
                    showAboutSheet = true
                },
                // Cue list actions
                onSwitchCueList: { cueListID in
                    store.switchToCueList(cueListID)
                    isDirty = true
                    saveCurrentProject(overwrite: true)
                },
                onDuplicateCueList: { cueListID in
                    if let newID = store.duplicateCueList(cueListID) {
                        store.switchToCueList(newID)
                        isDirty = true
                        saveCurrentProject(overwrite: true)
                    }
                },
                onRenameCueList: { cueListID in
                    // Pre-fill with current cue list name
                    if let cueList = store.cueLists.first(where: { $0.id == cueListID }) {
                        cueListToRename = cueListID
                        tempCueListName = cueList.name
                        showCueListRenamePrompt = true
                    }
                },
                onDeleteCueList: { cueListID in
                    store.deleteCueList(cueListID)
                    isDirty = true
                },
                onCreateCueList: {
                    newCueListName = "New Cue List"
                    showNewCueListPrompt = true
                },
                onShowMode: {
                    if isEditing { isEditing = false }
                    showShowMode = true
                }
            )
    }

    // Filter active songs based on search query
    private var filteredActiveSongs: [Song] {
        if setlistQuery.isEmpty {
            return store.activeSongs
        }
        return store.activeSongs.filter { song in
            song.name.localizedCaseInsensitiveContains(setlistQuery)
        }
    }

    @ViewBuilder private func buildMiddleSectionView() -> some View {
        ZStack {
                // Background - same in all modes

                VStack(spacing: 0) {
                    CBPerformanceList(
                        songs: filteredActiveSongs,
                    songLibrary: songLibrary,  // Pass full song library for alias resolution
                    isCueMode: store.mode == .cue,
                    cuedID: store.mode == .cue ? store.cuedSong?.id : (store.mode == .regularPlusRemote && !store.activeSongs.isEmpty ? store.activeSongs[currentSongIndex()].id : nil),
                    isEditing: isEditing,
                    reorderMode: reorderMode,  // Pass reorder mode for drag handles
                    batchSelectMode: setlistBatchMode,  // Pass batch select mode
                    selectedSongs: setlistSelected,  // Pass selected song IDs
                    flashingCueID: flashingCueID,  // Pass flash trigger down to rows
                    lastPlayedID: lastPlayedCueID,  // Pass last played cue ID for play icon
                    accentColor: currentTheme.accentColor(for: colorScheme),  // Pass theme accent color
                    defaultCueColor: Color(hex: effectiveDefaultCueColorHex),  // Pass theme default cue color (custom or theme default)
                    themeFont: currentTheme.font,  // Pass theme font function
                    selectionStrokeColor: { cueColorHex in currentTheme.selectionStrokeColor(for: cueColorHex, colorScheme: colorScheme) },  // Compute contrasting selection stroke color
                    backgroundColorHex: currentTheme.backgroundColorHexValue(for: colorScheme),  // Pass background color hex
                    defaultCueColorHex: effectiveDefaultCueColorHex,  // Pass default cue color hex (custom or theme default)
                    showMIDIData: showMIDIData,  // Pass MIDI data visibility setting
                    cueHeight: cueHeight,  // Pass customizable cue height
                    fontSize: fontSize,  // Pass font size multiplier
                    controlAreaCollapsed: controlAreaCollapsed || (controlButtons.isEmpty && !controlEditMode),  // Pass effective collapsed state
                    controlAreaHeight: controlAreaHeight,  // Pass control area height for dynamic bottom padding
                    onTapSong: { song in
                        if store.mode == .regular || store.mode == .regularPlusRemote {
                            // In Navigator mode, update the index to match the tapped song
                            if store.mode == .regularPlusRemote {
                                if let index = store.activeSongs.firstIndex(where: { $0.id == song.id }) {
                                    lastTriggeredSongIndex = index
                                }
                            }
                            trigger(song)
                        } else {
                            store.cuedSong = song
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    },
                    onLongPressChangeMIDI: { song in
                        editingSong = song
                        showAddEditMIDIOnly = true
                    },
                    onRename: { s in editingSong = s; showAddEdit = true },
                    onDelete: { s in removeFromSetlist(s) },
                    onDuplicate: { s in duplicateSong(s) },
                    onMove: { indices, newOffset in
                        pushSetlistUndo()
                        store.updateActiveSongs { songs in
                            songs.move(fromOffsets: indices, toOffset: newOffset)
                        }
                        isDirty = true
                    },
                    onToggleSelection: { song in
                        if setlistSelected.contains(song.id) {
                            setlistSelected.remove(song.id)
                        } else {
                            setlistSelected.insert(song.id)
                        }
                    },
                    conflictFor: conflictLookup()
                )
                .onAppear { /* Start with blank data for shipping */ }
                .overlay(alignment: .center) {
                    // Show draggable transport dock in cue mode
                    if store.mode == .cue || (isEditing && modeBeforeEditing == .cue) {
                        let songs = store.activeSongs
                        let cued = store.cuedSong
                        let cuedIndex = cued.flatMap { s in songs.firstIndex(where: { $0.id == s.id }) }
                        let canPrev = (cuedIndex ?? 0) > 0
                        let canNext = cuedIndex.map { $0 < songs.count - 1 } ?? false

                        SimpleDraggableTransportDock(
                            cuedName: cued?.name,
                            canPrev: canPrev,
                            canNext: canNext,
                            isGoEnabled: cued != nil,
                            onPrev: { selectPreviousCued() },
                            onGo: { cueGo() },
                            onNext: { selectNextCued() },
                            onClear: { store.cuedSong = nil },
                            controlAreaHeight: $controlAreaHeight,
                            isEditing: isEditing,
                            titleBarBottom: titleBarBottom,
                            editCapsuleBottom: editCapsuleBottom,
                            sizeMultiplier: navigationPillSize,  // Use same size as nav pill
                            isControlAreaCollapsed: effectivelyCollapsedForOverlay,
                            capsuleBounds: capsuleBounds,
                            hasControlButtons: !controlButtons.isEmpty,
                            themeColor: currentTheme.titleBarColor(for: colorScheme),
                            onTutorialDismiss: { resumeInterruptedTutorial() }
                        )
                        .offset(x: isEditing ? globalCachedPortraitWidth : 0)
                        .animation(.easeInOut(duration: 0.3), value: isEditing)
                        .zIndex(100)
                    }

                    // Show draggable navigation capsule in regularPlusRemote mode
                    if store.mode == .regularPlusRemote || (isEditing && modeBeforeEditing == .regularPlusRemote) {
                        let songs = store.activeSongs
                        let currentIndex = currentSongIndex()
                        let canPrev = currentIndex > 0
                        let canNext = currentIndex < songs.count - 1

                        DraggableNavigationCapsule(
                            canPrev: canPrev,
                            canNext: canNext,
                            onPrev: { triggerPrevious() },
                            onNext: { triggerNext() },
                            controlAreaHeight: $controlAreaHeight,
                            isEditing: isEditing,
                            titleBarBottom: titleBarBottom,
                            editCapsuleBottom: editCapsuleBottom,
                            sizeMultiplier: navigationPillSize,
                            isControlAreaCollapsed: effectivelyCollapsedForOverlay,
                            capsuleBounds: capsuleBounds,
                            hasControlButtons: !controlButtons.isEmpty,
                            themeColor: currentTheme.titleBarColor(for: colorScheme),
                            onTutorialDismiss: { resumeInterruptedTutorial() }
                        )
                        .offset(x: isEditing ? globalCachedPortraitWidth : 0)
                        .animation(.easeInOut(duration: 0.3), value: isEditing)
                        .zIndex(100)
                    }
                }
                // No background needed - cues and capsules live on same plane
                // Animation removed to prevent interference with draggable capsule position updates
                .overlay(alignment: .top) {
                    // Gradient from top of screen (solid background) to below title/search bar (fades to transparent) - improves scrolled cue visibility
                    let gradientHeight: CGFloat = isEditing ? 118 : 120  // Taller in edit mode (title + search), extends below title bar capsule in normal mode
                    let bgColor = currentTheme.backgroundColor(for: colorScheme)

                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: bgColor, location: 0.0),                  // Solid background at top
                            .init(color: bgColor.opacity(0.7), location: 0.25),   // More visible
                            .init(color: bgColor.opacity(0.3), location: 0.5),    // Slight fade
                            .init(color: bgColor.opacity(0.0), location: 1.0)     // Transparent at bottom
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: gradientHeight)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isEditing)
                }
                .overlay(alignment: .top) {
                    // Search and action capsules overlay (only in edit mode) - cues scroll underneath
                    if isEditing {
                        HStack(spacing: 8) {
                            // Search bar — always present, animates between full width and circular icon
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.cbIcon(points: setlistBatchMode ? 18 : 16, .regular))
                                    .foregroundStyle(CBColor.textPrimary)

                                if !setlistBatchMode {
                                    TextField("Search cues...", text: $setlistQuery)
                                        .font(.cb(.body))
                                        .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                        .focused($isSetlistSearchFocused)

                                    if !setlistQuery.isEmpty {
                                        Button(action: { setlistQuery = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.cbIcon(.body, .regular))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, setlistBatchMode ? 0 : 14)
                            .frame(width: setlistBatchMode ? 44 : nil, height: 44)
                            .frame(maxWidth: setlistBatchMode ? nil : .infinity)
                            .cbChip()
                            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                            .onTapGesture {
                                if setlistBatchMode {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        setlistBatchMode = false
                                        setlistSelected.removeAll()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        isSetlistSearchFocused = true
                                    }
                                } else {
                                    isSetlistSearchFocused = true
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: setlistBatchMode)

                            if setlistBatchMode {
                                Spacer()
                            }

                            // Reorder button - separate capsule (hidden in batch mode)
                            if !setlistBatchMode {
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        reorderMode.toggle()
                                    }
                                }) {
                                    Image(systemName: reorderMode ? "checkmark" : "list.bullet")
                                        .font(.cbIcon(.large, .regular))
                                        .foregroundStyle(CBColor.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: CBRadius.control)
                                                .fill(CBColor.chip)
                                                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                                        )
                                        .overlay(RoundedRectangle(cornerRadius: CBRadius.control).stroke(CBColor.stroke, lineWidth: CBSize.hairline))
                                        .clipShape(RoundedRectangle(cornerRadius: CBRadius.control))
                                }
                                .buttonStyle(IOSPressButtonStyle())
                            }

                            // Select capsule — grows into batch actions
                            HStack(spacing: 0) {
                                if setlistBatchMode {
                                    Button(action: {
                                        setlistSelected = Set(filteredActiveSongs.map { $0.id })
                                    }) {
                                        Text("All")
                                            .font(.cb(.small, .medium))
                                            .foregroundStyle(CBColor.textPrimary)
                                            .padding(.horizontal, 10)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())

                                    Button(action: {
                                        setlistSelected.removeAll()
                                    }) {
                                        Text("Clear")
                                            .font(.cb(.small, .medium))
                                            .foregroundStyle(CBColor.textPrimary)
                                            .padding(.horizontal, 10)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())

                                    Button(action: {
                                        pushSetlistUndo()
                                        store.updateActiveSongs { songs in
                                            songs.removeAll(where: { setlistSelected.contains($0.id) })
                                        }
                                        setlistSelected.removeAll()
                                        isDirty = true
                                    }) {
                                        Text("Remove")
                                            .font(.cb(.small, .medium))
                                            .foregroundColor(setlistSelected.isEmpty ? currentTheme.primaryTextColor(for: colorScheme).opacity(0.3) : .red)
                                            .padding(.horizontal, 10)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())
                                    .disabled(setlistSelected.isEmpty)

                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 1, height: 24)
                                        .padding(.horizontal, 2)

                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            setlistBatchMode = false
                                            setlistSelected.removeAll()
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.cbIcon(.small, .medium))
                                            .foregroundStyle(CBColor.textPrimary)
                                            .frame(width: 36, height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())
                                } else {
                                    // Collapsed: just the checklist icon
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            setlistBatchMode = true
                                            reorderMode = false
                                        }
                                    }) {
                                        Image(systemName: "checklist")
                                            .font(.cbIcon(.large, .regular))
                                            .foregroundStyle(CBColor.textPrimary)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())
                                }
                            }
                            .cbChip()
                            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: setlistBatchMode)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 68)  // Position below the top bar
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: EditCapsuleBottomPreferenceKey.self, value: geo.frame(in: .global).maxY)
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isEditing)
                    }
                }
                    }
                }
    }

    private var effectivelyCollapsedForOverlay: Bool {
        return controlAreaCollapsed || (controlButtons.isEmpty && !controlEditMode)
    }

    // State for controls capsule press animation (can't use ButtonStyle due to GeometryReader conflicts)
    @State private var controlsCapsulePressed: Bool = false

    private var collapsedControlCapsule: some View {
        // Floating action button with rounded rectangle to match app button style
        Image(systemName: "slider.horizontal.3")
            .font(.cbIcon(.title, .medium))
            .foregroundStyle(CBColor.textPrimary)
            .frame(width: 56, height: 56)
            .background(RoundedRectangle(cornerRadius: CBRadius.card).fill(Color.black.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: CBRadius.card).stroke(CBColor.stroke, lineWidth: CBSize.hairline))
            .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            .opacity(controlsCapsulePressed ? 0.5 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: CBRadius.card))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !controlsCapsulePressed {
                            controlsCapsulePressed = true
                        }
                    }
                    .onEnded { _ in
                        controlsCapsulePressed = false
                        // User found the controls on their own — skip tutorial 3
                        hasSeenTutorial3 = true
                        if showTutorial3 {
                            showTutorial3 = false
                            onTutorialDismissed()
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            controlAreaCollapsed = false
                            // If empty, also enter edit mode
                            if controlButtons.isEmpty {
                                controlEditMode = true
                            }
                        }
                    }
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TutorialButtonFramePreferenceKey.self,
                        value: ["controlsCapsule": geo.frame(in: .global)]
                    )
                }
            )
            .padding(.trailing, 16)
            .padding(.bottom, 0)  // No internal bottom padding - applied externally at frame level
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CapsuleBoundsPreferenceKey.self,
                        value: ["controlArea.main": geo.frame(in: .global)]
                    )
                }
            )
    }

    private var controlSectionView: some View {
        CBControlSection(
            buttons: $controlButtons,
            isEditing: $controlEditMode,
            perRow: $controlsPerRow,
            pendingAddIsFader: $pendingAddIsFader,
            reportedHeight: $controlAreaHeight,
            canAddMoreControls: $canAddMoreControlsToGrid,
            isCollapsed: $controlAreaCollapsed,
            selectedCue: $selectedCue,
            currentPage: $currentControlPage,
            conflictFor: conflictLookup(),
            midiFilter: midiFilter,
            showMIDIData: showMIDIData,
            onTap: { btn in triggerControl(btn) },
            onEditButton: { btn in
                editingControlForEdit = btn
                showEditControlSheet = true
                resetControlEditModeTimer()
            },
            onAddButton: { if canAddMoreControlsToGrid { beginAddControlOfType(.button) }; resetControlEditModeTimer() },
            onAddFader: { if canAddMoreControlsToGrid { beginAddControlOfType(.fader) }; resetControlEditModeTimer() },
            onUndo: { undoControls(); resetControlEditModeTimer() },
            onRedo: { redoControls(); resetControlEditModeTimer() },
            canUndo: !controlUndoStack.isEmpty,
            canRedo: !controlRedoStack.isEmpty,
            onDelete: { btn in deleteControl(btn); resetControlEditModeTimer() },
            onMove: { from, to in pushControlUndo(); controlButtons.move(fromOffsets: from, toOffset: to); markDirty(); resetControlEditModeTimer() },
            onCancelTimer: cancelControlEditModeTimer,
            onResetTimer: resetControlEditModeTimer,
            usbServer: usbServer,
            wifiClient: wifiClient,
            connectionCoordinator: connectionCoordinator,
            controlAreaColor: currentTheme.titleBarColor(for: colorScheme),
            buttonBackgroundColor: currentTheme.buttonBackgroundColor(for: colorScheme, customAccentHex: customDefaultCueColorStorage),
            lightButtonBackgroundColor: currentTheme.lightButtonBackgroundColor(for: colorScheme),
            defaultCueColor: Color(hex: effectiveDefaultCueColorHex),
            standardButtonColor: currentTheme.accentColor(for: colorScheme),
            textColor: currentTheme.primaryTextColor(for: colorScheme),
            markDirty: markDirty,
            cueListEditMode: isEditing
        )
            .onChange(of: controlEditMode) { _, newValue in
                if newValue {
                    // Entering edit mode - start timer
                    startControlEditModeTimer()

                    // Tutorial 4 dismiss removed (no longer exists)
                } else {
                    // Exiting edit mode - cancel timer
                    cancelControlEditModeTimer()

                    // Tutorial 4 (two-finger scroll) removed — no longer needed
                }
            }
            .onChange(of: showControlEditor) { _, isShowing in
                if isShowing {
                    // Sheet opened - pause timer
                    cancelControlEditModeTimer()
                } else {
                    // Sheet dismissed - restart timer if still in edit mode
                    if controlEditMode {
                        startControlEditModeTimer()
                    }
                }
            }
            .onChange(of: showEditControlSheet) { _, isShowing in
                if isShowing {
                    // Sheet opened - pause timer
                    cancelControlEditModeTimer()
                } else {
                    // Sheet dismissed - restart timer if still in edit mode
                    if controlEditMode {
                        startControlEditModeTimer()
                    }
                }
            }
    }

    // FIX #1: Setup NotificationCenter subscriptions using Combine to prevent memory leaks
    private func setupNotificationSubscriptions() {
        // Clear any existing subscriptions
        notificationCancellables.removeAll()

        // Subscription 1: cbFaderChanged
        NotificationCenter.default.publisher(for: Notification.Name("cbFaderChanged"))
            .sink { [self] notif in
                guard let info = notif.userInfo as? [String: Any],
                      let channel = info["channel"] as? Int,
                      let cc = info["cc"] as? Int,
                      let value = info["value"] as? Int,
                      let id = info["id"] as? UUID,
                      let title = info["title"] as? String else { return }

                // Store the fader value in the ControlButton model for persistence
                if let index = controlButtons.firstIndex(where: { $0.id == id }) {
                    let faderValue = Double(value) / 127.0
                    controlButtons[index].faderValue = faderValue
                    markDirty() // Mark project as dirty to save the fader value
                    debugPrint("🎚️ cbFaderChanged: Stored fader value \(faderValue) for \"\(title)\"")
                }

                // Use global channel if enabled, otherwise use fader's channel
                let channelToUse = isGlobalChannel ? globalChannel : channel

                let connectionType = connectionCoordinator.activeConnection == .usb ? "USB" : "WiFi"
                debugPrint("🎚️ MIDI OUT [\(connectionType)]: Fader CC #\(cc) = \(value) • Ch \(channelToUse) • \"\(title)\"")

                // Use ConnectionCoordinator to send MIDI through the active connection
                connectionCoordinator.sendMIDI(type: .cc, channel: channelToUse, number: cc, value: value, label: title, buttonID: id.uuidString)
            }
            .store(in: &notificationCancellables)

        // v1.3: open "Notes & Extras" for a song (from the cue row's menu)
        NotificationCenter.default.publisher(for: Notification.Name("cbOpenSongDetails"))
            .sink { [self] notif in
                guard let id = notif.userInfo?["songID"] as? UUID else { return }
                if let song = store.activeSongs.first(where: { $0.id == id })
                    ?? songLibrary.first(where: { $0.id == id }) {
                    songForDetails = song
                }
            }
            .store(in: &notificationCancellables)

        // Subscription 2: cbMIDIInputFromDAW
        NotificationCenter.default.publisher(for: Notification.Name("cbMIDIInputFromDAW"))
            .sink { [self] notif in
                debugPrint("🎚️ Received cbMIDIInputFromDAW notification: \(notif.userInfo ?? [:])")

                guard let info = notif.userInfo as? [String: Any],
                      let type = info["type"] as? String else {
                    debugPrint("🎚️ ❌ Invalid notification data")
                    return
                }

                if type == "cc",
                   let channel = info["channel"] as? Int,
                   let cc = info["cc"] as? Int,
                   let value = info["value"] as? Int {

                    debugPrint("🎚️ MIDI IN [DAW]: CC #\(cc) = \(value) • Ch \(channel)")

                    // Find matching fader and update its value
                    updateFaderFromDAW(channel: channel, cc: cc, value: value)
                } else {
                    debugPrint("🎚️ ❌ Invalid MIDI CC data: type=\(type), channel=\(info["channel"] ?? "nil"), cc=\(info["cc"] ?? "nil"), value=\(info["value"] ?? "nil")")
                }
            }
            .store(in: &notificationCancellables)
    }

    // MARK: - Side Menu
    private var sideMenuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer for floating top bar (transparent)
            Spacer().frame(height: 80)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Section 0: Mode Selection
                    sideMenuSection(title: "Performance") {
                        // Regular Mode (no pill)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .regular
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .regular {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Regular")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        // Regular + Remote (navigation capsule)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .regularPlusRemote
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .regularPlusRemote {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Navigator")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        // Cue Mode (GO capsule)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .cue
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .cue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Cue Mode")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 1: File Operations
                    sideMenuSection(title: "Project") {
                        sideMenuButton("New Project", icon: "doc.badge.plus", action: {
                            if isEditing { isEditing = false }
                            newProjectFlow()
                            closeMenu()
                        })
                        sideMenuButton("Save", icon: "square.and.arrow.down", action: {
                            if isEditing { isEditing = false }
                            saveCurrentProject(overwrite: true)
                            closeMenu()
                        })
                        sideMenuButton("Save As...", icon: "square.and.arrow.down.on.square", action: {
                            if isEditing { isEditing = false }
                            saveCurrentProject(overwrite: false)
                            closeMenu()
                        })
                        sideMenuButton("Open...", icon: "folder", action: {
                            if isEditing { isEditing = false }
                            projectsList = ProjectIO.list()
                            showProjects = true
                            closeMenu()
                        })
                        sideMenuButton("Import...", icon: "arrow.down.doc", action: {
                            if isEditing { isEditing = false }
                            openDocumentPicker()
                            closeMenu()
                        })
                        sideMenuButton("Export...", icon: "square.and.arrow.up", action: {
                            if isEditing { isEditing = false }
                            exportCurrentProject()
                            closeMenu()
                        })
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 2: Settings
                    sideMenuSection(title: "Settings") {
                        sideMenuButton("MIDI Settings...", icon: "slider.horizontal.3", action: {
                            if isEditing { isEditing = false }
                            showMidiTable = true
                            closeMenu()
                        })
                        sideMenuButton("Appearance...", icon: "paintbrush", action: {
                            if isEditing { isEditing = false }
                            showAppearanceSettingsSheet = true
                            closeMenu()
                        })
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 3: Help
                    sideMenuSection(title: "Help") {
                        sideMenuButton("Getting Started", icon: "questionmark.circle", action: {
                            if isEditing { isEditing = false }
                            // Only show onboarding if crash alert is not active
                            if !crashAlertActive {
                                showOnboarding = true
                            }
                            closeMenu()
                        })
                        #if DEBUG
                        // About button with long press for admin panel
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .frame(width: 24)
                                .foregroundColor(currentTheme.accentColor(for: colorScheme))
                            Text("About Cue Bear")
                                .font(currentTheme.font(size: 15, weight: .regular))
                                .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditing { isEditing = false }
                            showAboutSheet = true
                            closeMenu()
                        }
                        .onLongPressGesture(minimumDuration: 3.0) {
                            showAdminPanel = true
                            closeMenu()
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                        #else
                        sideMenuButton("About Cue Bear", icon: "info.circle", action: {
                            if isEditing { isEditing = false }
                            showAboutSheet = true
                            closeMenu()
                        })
                        #endif

                        // Reset Tutorials button (in Help section)
                        sideMenuButton("Reset Tutorials", icon: "arrow.counterclockwise", action: {
                            // Reset all tutorial flags
                            hasSeenTutorial1 = false
                            hasSeenTutorial2 = false
                            hasSeenTutorial2b = false
                            hasSeenTutorial2c = false
                            hasSeenTutorial3 = false
                            // Also reset nav pill and cue capsule tutorials
                            UserDefaults.standard.removeObject(forKey: "hasSeenNavPillTutorial")
                            UserDefaults.standard.removeObject(forKey: "hasSeenCueCapsuleTutorial")
                            // Reset onboarding so it shows again
                            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
                            closeMenu()
                            // Show onboarding immediately after menu closes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showOnboarding = true
                            }
                        })
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(currentTheme.titleBarColor(for: colorScheme))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 2, y: 0)
    }

    private func sideMenuSection<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(currentTheme.font(size: 11, weight: .semibold))
                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                    .textCase(.uppercase)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
            }
            content()
        }
    }

    private func sideMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(currentTheme.accentColor(for: colorScheme))
                Text(title)
                    .font(currentTheme.font(size: 15, weight: .regular))
                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showSideMenu = false
        }
    }

    private func mainStack() -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                // Theme background color - extends to all edges including safe areas
                currentTheme.backgroundColor(for: colorScheme)
                    .ignoresSafeArea(edges: .all)

                // Main content (without top bar - it will overlay)
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        buildMiddleSectionView()
                    }
                    .disabled(showSideMenu)
                    .blur(radius: showSideMenu ? 3 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.85), value: showSideMenu)
                    .ignoresSafeArea(edges: .bottom) // Allow cues to extend into bottom safe area behind home indicator

                    // Floating control area capsules - NOT clipped so they can slide off-screen
                    ZStack {
                        if !isEditing && effectivelyCollapsedForOverlay && showCollapsedCapsule {
                            // Show small collapsed capsule with sequential animation
                            // Match expanded control area positioning
                            let bottomPadding: CGFloat = 21
                            AnyView(collapsedControlCapsule)
                                .padding(.bottom, bottomPadding)  // Match expanded control area bottom padding
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .ignoresSafeArea(edges: .bottom)  // Match expanded control area safe area handling
                                .zIndex(0)
                                .id("collapsed")
                                .transition(.move(edge: .bottom))
                        }

                        // PERFORMANCE: Only create CBControlSection when controlSectionReady is true
                        // This delays heavy view initialization until after initial app layout
                        // NOTE: Removed GeometryReader background - it caused UI freeze due to layout loop
                        if !isEditing && !effectivelyCollapsedForOverlay && showExpandedArea && controlSectionReady {
                            let isLandscape = verticalSizeClass == .compact
                            // Bottom padding: X + 2Y where X = home indicator height (~5pt), Y = its distance from bottom (8pt)
                            let bottomPadding: CGFloat = 21

                            AnyView(controlSectionView)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLandscape ? .bottomTrailing : .bottom)
                                .padding(.trailing, isLandscape ? 16 : 0)
                                .padding(.bottom, bottomPadding)
                                .ignoresSafeArea(edges: .bottom)
                                .transition(.move(edge: .bottom))
                                .zIndex(1)
                                .id("expandedNonEdit")
                        }
                    }
                    // NOTE: No blanket .animation() here — using explicit withAnimation in onChange
                    // to prevent parent spring from infecting child view properties (e.g. chevron opacity)
                    .onChange(of: effectivelyCollapsedForOverlay) { _, isCollapsed in
                        // Mark as animating - prevents GeometryReader from updating height during animation
                        isAnimatingControlArea = true

                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if isCollapsed {
                                // Collapsing: hide expanded area and show collapsed capsule simultaneously
                                showExpandedArea = false
                                showCollapsedCapsule = true
                            } else {
                                // Expanding: hide collapsed capsule and show expanded area simultaneously
                                showCollapsedCapsule = false
                                showExpandedArea = true
                            }
                        }

                        if isCollapsed {
                            // Set collapsed height immediately
                            controlAreaHeight = 56
                        } else {
                            // Set expanded height immediately from bounds or use fixed estimate
                            // IMPORTANT: Do NOT access UIScreen.main.bounds here - causes freeze
                            if let actualHeight = capsuleBounds["controlArea.main"]?.height, actualHeight > 56 {
                                controlAreaHeight = actualHeight
                            } else {
                                // Use fixed estimate - actual height will be set by CBControlSection
                                controlAreaHeight = 200
                            }
                        }

                        // Clear animating flag after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isAnimatingControlArea = false
                        }
                    }
                    .onAppear {
                        // Initialize visibility based on initial state
                        showCollapsedCapsule = effectivelyCollapsedForOverlay
                        showExpandedArea = !effectivelyCollapsedForOverlay

                        // Initialize control area height based on initial state
                        if effectivelyCollapsedForOverlay {
                            controlAreaHeight = 56  // Collapsed capsule height
                        } else {
                            // For expanded state, try to get actual height from bounds or use estimate
                            if let actualHeight = capsuleBounds["controlArea.main"]?.height {
                                controlAreaHeight = actualHeight
                            } else {
                                // Use fixed estimate - UIScreen.main.bounds access during layout causes freeze
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                let maxHeight = isPhone ? globalCachedPortraitWidth * 0.8 : 200
                                controlAreaHeight = maxHeight
                            }
                        }

                        // PERFORMANCE: Delay CBControlSection creation until after initial layout
                        // This prevents the heavy view from blocking app startup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            controlSectionReady = true
                        }
                    }
                }

                // Floating top bar overlay
                VStack {
                    AnyView(topBarView)
                        .padding(.top, UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact ? 8 : 0)
                    Spacer()
                }
                .background(Color.clear)
                .zIndex(10)

                // Side menu with overlay
                // Overlay - fades independently
                if showSideMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                showSideMenu = false
                            }
                        }
                        .zIndex(1)
                }

                // Menu - slides independently
                if showSideMenu {
                    sideMenuView
                        .frame(width: 320)
                        .transition(.move(edge: .leading))
                        .zIndex(2)
                }
            }
        )
    }

    // Control area is now always shown as overlay (see mainStack overlay)
    // No longer need bottomSectionView

    // MARK: - Control functions
    private func controlRowCount() -> Int {
        // Grid triples columns; normal buttons occupy 3, faders 2 (2 grid squares wide).
        let slotsPerRow = max(3, controlsPerRow * 3)
        let totalSlots = controlButtons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(totalSlots) / Double(slotsPerRow)))
    }
    
    // Update fader value from DAW MIDI input
    private func updateFaderFromDAW(channel: Int, cc: Int, value: Int) {
        debugPrint("🎚️ updateFaderFromDAW: Looking for fader with channel=\(channel), cc=\(cc), value=\(value)")
        debugPrint("🎚️ Available faders:")
        for (index, button) in controlButtons.enumerated() {
            if button.isFader == true {
                debugPrint("🎚️   Fader \(index): \"\(button.title)\" - channel=\(button.channel), cc=\(button.number)")
            }
        }
        
        // Find the fader that matches this MIDI channel and CC
        if let index = controlButtons.firstIndex(where: { button in
            button.isFader == true && button.channel == channel && button.number == cc
        }) {
            // Convert MIDI value (0-127) to fader value (0.0-1.0)
            let faderValue = Double(value) / 127.0
            
            debugPrint("🎚️ ✅ Found matching fader \"\(controlButtons[index].title)\" at index \(index)")
            debugPrint("🎚️ Updated fader \"\(controlButtons[index].title)\" to \(faderValue) from DAW MIDI")
            
            // Store the fader value in the ControlButton model for persistence
            controlButtons[index].faderValue = faderValue
            markDirty() // Mark project as dirty to save the fader value
            
            // Post notification for the fader tile to update its visual value
            NotificationCenter.default.post(
                name: Notification.Name("cbUpdateFaderFromDAW"),
                object: nil,
                userInfo: [
                    "buttonID": controlButtons[index].id.uuidString,
                    "value": faderValue
                ]
            )
        } else {
            debugPrint("🎚️ ❌ No matching fader found for channel=\(channel), cc=\(cc)")
        }
    }

    private func canAddMoreControls() -> Bool {
        return controlRowCount() < maxControlRows
    }
    private func addControl() {
        // Legacy helper kept if needed elsewhere: directly append a default control
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        var new = ControlButton(title: "Custom", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127)
        if autoAssignControlColors {
            let usedColors = Set(controlButtons.compactMap { $0.colorHex })
            let available = curatedColorPalette.filter { !usedColors.contains($0) }
            new.colorHex = available.randomElement() ?? curatedColorPalette.randomElement()
        }
        controlButtons.append(new)
        invalidateConflictCache()
        markDirty()
    }

    private func beginAddControl() {
        // Prepare a default control for editing (do not append yet)
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        let draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil)
        editingControl = draft
        pendingAddIsFader = false
        showControlEditor = true
    }

    private enum AddKind { case button, fader }
    private func beginAddControlOfType(_ kind: AddKind) {
        debugPrint("🎹 [ADD CONTROL] beginAddControlOfType called with kind: \(kind)")
        // FIX: Skip filtered CC numbers and MIDI already taken by cues or controls
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        debugPrint("🎹 beginAddControlOfType: Found free CC = \(freeCC)")
        var draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil, page: currentControlPage)
        switch kind {
        case .button:
            draft.isFader = false
            draft.isSmall = false
            draft.title = nextDefaultControlName("Button")
            debugPrint("🎹 [ADD CONTROL] Creating button draft on page \(currentControlPage)")
        case .fader:
            draft.isFader = true
            draft.isSmall = false
            draft.symbol = "" // no icon for fader
            draft.title = nextDefaultControlName("Fader")
            debugPrint("🎹 [ADD CONTROL] Creating fader draft on page \(currentControlPage)")
        }
        editingControl = draft
        // Hint the editor about fader mode
        pendingAddIsFader = (kind == .fader)
        debugPrint("🎹 [ADD CONTROL] Setting showControlEditor = true")
        showControlEditor = true
        debugPrint("🎹 [ADD CONTROL] showControlEditor is now: \(showControlEditor)")
    }

    private func deleteControl(_ btn: ControlButton) {
        pushControlUndo()
        controlButtons.removeAll { $0.id == btn.id }
        invalidateConflictCache()
        markDirty()
    }

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            mainStack()
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .focusable()  // Required to receive keyboard input from Bluetooth pedals
                .focusEffectDisabled()  // Hide the blue focus indicator lines
                // Bluetooth pedal support (Airturn BT500 and similar devices)
                .onKeyPress(.upArrow) {
                    debugPrint("🎹 Up Arrow pressed")
                    handlePedalPrevious()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    debugPrint("🎹 Down Arrow pressed")
                    handlePedalNext()
                    return .handled
                }
                .onKeyPress(.pageUp) {
                    debugPrint("🎹 Page Up pressed")
                    handlePedalPrevious()
                    return .handled
                }
                .onKeyPress(.pageDown) {
                    debugPrint("🎹 Page Down pressed")
                    handlePedalNext()
                    return .handled
                }
                // MARK: - Tutorial Overlays
                .overlay {
                    ZStack {
                        // Tutorial 1: Edit button (after onboarding)
                        if showTutorial1 && editButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Open edit mode to add your first cue",
                                targetFrame: editButtonFrame,
                                onDismiss: {
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2: + button (after clicking Edit)
                        if showTutorial2 && addCueButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Tap + to add your first cue",
                                targetFrame: addCueButtonFrame,
                                onDismiss: {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    if !hasSeenTutorial2b {
                                        pendingTutorial = 21  // 21 = tutorial 2b
                                    }
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2b: Library button (after tutorial 2 or adding cue)
                        if showTutorial2b && libraryButtonFrame != .zero {
                            UpwardTutorial(
                                message: "All your cues live in the cue library.",
                                targetFrame: libraryButtonFrame,
                                onDismiss: {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2c: Cue list name button
                        if showTutorial2c && cueListNameButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Create as many cue lists as you want",
                                targetFrame: cueListNameButtonFrame,
                                onDismiss: {
                                    showTutorial2c = false
                                    hasSeenTutorial2c = true
                                    if !hasSeenTutorial3 {
                                        pendingTutorial = 3
                                    }
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2c = false
                                    hasSeenTutorial2c = true
                                    if !hasSeenTutorial3 {
                                        pendingTutorial = 3
                                    }
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 3: Controls capsule (contextual: 3+ cues in active list)
                        if showTutorial3 && controlsCapsuleFrame != .zero {
                            DownwardTutorial(
                                message: "Add buttons and faders for extra MIDI control",
                                targetFrame: controlsCapsuleFrame,
                                onDismiss: {
                                    showTutorial3 = false
                                    hasSeenTutorial3 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial3 = false
                                    hasSeenTutorial3 = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 4 (two-finger scroll) removed
                    }
                    .animation(.easeInOut(duration: 0.3), value: showTutorial1)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2b)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2c)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial3)
                    .onChange(of: showTutorial1) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial1 changed to \(newValue), editButtonFrame=\(editButtonFrame), frame != .zero: \(editButtonFrame != .zero)")
                    }
                    .onChange(of: showTutorial2) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2 changed to \(newValue), addCueButtonFrame=\(addCueButtonFrame)")
                    }
                    .onChange(of: showTutorial2b) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2b changed to \(newValue), libraryButtonFrame=\(libraryButtonFrame)")
                    }
                    .onChange(of: showTutorial2c) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2c changed to \(newValue), cueListNameButtonFrame=\(cueListNameButtonFrame)")
                    }
                    .onChange(of: showTutorial3) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial3 changed to \(newValue), controlsCapsuleFrame=\(controlsCapsuleFrame)")
                    }
                    // Tutorial 4 onChange removed
                    .onChange(of: showCueListChooser) { _, isShowing in
                        if isShowing && showTutorial2c {
                            // Dismiss tutorial 2c when user opens cue list chooser
                            showTutorial2c = false
                            hasSeenTutorial2c = true
                        }
                        if !isShowing && hasSeenTutorial2c && !hasSeenTutorial3 {
                            // Skip tutorial 3 if control area is already open
                            if !effectivelyCollapsedForOverlay {
                                hasSeenTutorial3 = true
                            } else {
                                // Queue Tutorial 3 after cue list chooser closes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.requestTutorial(3)
                                }
                            }
                        }
                    }
                    .onChange(of: showLibraryPopover) { _, isShowing in
                        // Dismiss tutorial 2b when user opens song library
                        if isShowing && showTutorial2b {
                            showTutorial2b = false
                            hasSeenTutorial2b = true
                            onTutorialDismissed()
                        }
                    }
                }

            if showSplash {
                SplashScreen()
                    .transition(.opacity)
                    .ignoresSafeArea()
                    .zIndex(1)
            }
        }
    }

    var body: some View {
        applyObservers(applyLifecycle(
            applyAlerts(
                applySheets(
                    contentView
                        .onPreferenceChange(EditCapsuleBottomPreferenceKey.self) { value in
                            editCapsuleBottom = isEditing ? value : 0  // Only track when visible
                        }
                        .onPreferenceChange(CapsuleBoundsPreferenceKey.self) { value in
                            // PERFORMANCE: Guard against redundant updates to prevent layout loops
                            // Use a larger threshold (5 points) to filter out animation micro-updates
                            let hasSignificantChange = value.contains { key, newRect in
                                guard let oldRect = capsuleBounds[key] else { return true }
                                return abs(newRect.origin.x - oldRect.origin.x) > 5 ||
                                       abs(newRect.origin.y - oldRect.origin.y) > 5 ||
                                       abs(newRect.width - oldRect.width) > 5 ||
                                       abs(newRect.height - oldRect.height) > 5
                            }

                            guard hasSignificantChange || value.count != capsuleBounds.count else { return }

                            capsuleBounds = value
                            // Tutorial 4 controlAreaFrame tracking removed
                        }
                        .onPreferenceChange(TutorialButtonFramePreferenceKey.self) { value in
                            // PERFORMANCE: Only process tutorial frames when tutorials might be shown
                            // This prevents expensive frame comparisons on every layout pass
                            let anyTutorialVisible = showTutorial1 || showTutorial2 || showTutorial2b || showTutorial2c || showTutorial3
                            let anyTutorialPending = !hasSeenTutorial1 || !hasSeenTutorial2 || !hasSeenTutorial2b || !hasSeenTutorial2c || !hasSeenTutorial3

                            guard anyTutorialVisible || anyTutorialPending else { return }

                            // Helper to check if frames differ significantly (more than 5 points to filter animation frames)
                            func framesDiffer(_ a: CGRect, _ b: CGRect) -> Bool {
                                return abs(a.origin.x - b.origin.x) > 5 ||
                                       abs(a.origin.y - b.origin.y) > 5 ||
                                       abs(a.width - b.width) > 5 ||
                                       abs(a.height - b.height) > 5
                            }

                            // Silently update frames without logging - logging caused major performance issues
                            if let frame = value["editButton"], framesDiffer(frame, editButtonFrame) {
                                editButtonFrame = frame
                            }
                            if let frame = value["addCueButton"], framesDiffer(frame, addCueButtonFrame) {
                                addCueButtonFrame = frame
                            }
                            if let frame = value["libraryButton"], framesDiffer(frame, libraryButtonFrame) {
                                libraryButtonFrame = frame
                            }
                            if let frame = value["cueListNameButton"], framesDiffer(frame, cueListNameButtonFrame) {
                                cueListNameButtonFrame = frame
                            }
                            if let frame = value["controlsCapsule"], framesDiffer(frame, controlsCapsuleFrame) {
                                controlsCapsuleFrame = frame
                            }
                        }
                        .onChange(of: isEditing) { oldValue, newValue in
                            if newValue {
                                // Entering edit mode - save current mode
                                modeBeforeEditing = store.mode

                                // Tutorial 2: Show + button tutorial after clicking Edit
                                if showTutorial1 {
                                    // Dismiss Tutorial 1 first
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                }
                                if !hasSeenTutorial2 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.requestTutorial(2)
                                    }
                                }
                            } else {
                                // Exiting edit mode - restore previous mode if it was cue or regularPlusRemote
                                if let previousMode = modeBeforeEditing,
                                   (previousMode == .cue || previousMode == .regularPlusRemote) {
                                    store.mode = previousMode
                                }
                                modeBeforeEditing = nil

                                // Dismiss tutorial 2 or 2b if still showing when exiting edit mode
                                if showTutorial2 {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    onTutorialDismissed()
                                }
                                if showTutorial2b {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                }

                                // Tutorial 2c: Show cue list name tutorial after exiting edit mode
                                if !hasSeenTutorial2c {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.requestTutorial(22)  // 22 = tutorial 2c
                                    }
                                }
                                // Tutorial 3: Show controls tutorial after exiting edit mode (if 2c already seen)
                                else if !hasSeenTutorial3 {
                                    // Skip if control area is already open
                                    if !effectivelyCollapsedForOverlay {
                                        hasSeenTutorial3 = true
                                    } else {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.requestTutorial(3)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: scenePhase) { _, phase in
                            // Ensure connections are properly managed when app becomes active
                            if phase == .active {
                                debugPrint("📱 App became active, managing connections...")

                                // Restart USB tunnel
                                // usb.stop() // Removed to prevent restart loop

                                // Small delay to ensure clean restart
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // Simple connection management - USB server is already running
                                    debugPrint("📱 App became active, USB server should be running")
                                    if !wifiClient.isConnected {
                                        wifiClient.restartDiscovery()
                                    }
                                }
                            } else if phase == .background {
                                // Save project when app goes to background
                                if isDirty && !isUntitledProject(projectName) {
                                    debugPrint("💾 App going to background, saving project: \(projectName)")
                                    snapshotAndSave(as: projectName, overwrite: true)
                                }
                            }
                        }
                        .onChange(of: store.mode) { _, newMode in
                            if !isUntitledProject(projectName) && !isLoadingProject {
                                debugPrint("🔄 Mode changed to \(newMode), saving project: \(projectName)")
                                snapshotAndSave(as: projectName, overwrite: true)
                            }

                            // Tutorial interruption: When switching to Navigator or Cue mode, pause current tutorial
                            // so the nav pill or cue capsule tutorial can show first
                            if newMode == .regularPlusRemote || newMode == .cue {
                                // Check if any tutorial is currently showing and save it
                                if showTutorial1 {
                                    interruptedTutorial = 1
                                    showTutorial1 = false
                                } else if showTutorial2 {
                                    interruptedTutorial = 2
                                    showTutorial2 = false
                                } else if showTutorial2b {
                                    interruptedTutorial = 3  // Using 3 for 2b
                                    showTutorial2b = false
                                } else if showTutorial2c {
                                    interruptedTutorial = 4  // Using 4 for 2c
                                    showTutorial2c = false
                                } else if showTutorial3 {
                                    interruptedTutorial = 5  // Using 5 for 3
                                    showTutorial3 = false
                                }
                            }
                        }
                )
            )
        ))
        .preferredColorScheme(currentTheme.preferredColorScheme(for: colorScheme))
    }

    // MARK: - View Modifiers (extracted to fix compiler type-checking timeout)

    @ViewBuilder
    /// v1.3 (Cue Bear Next): Show mode and Notes & Extras, kept out of the long sheet chain below
    /// so the compiler can type-check each part quickly.
    private func applyNextFeatures<V: View>(_ view: V) -> some View {
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

    private func applySheets<V: View>(_ view: V) -> some View {
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
    private func applyAlerts<V: View>(_ view: V) -> some View {
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
    private func applyLifecycle<V: View>(_ view: V) -> some View {
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

    @ViewBuilder private func applyObservers<V: View>(_ view: V) -> some View {
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

    // MARK: - Conflict map (always use cached version to prevent main thread blocking)
    private func conflictLookup() -> [MIDIKey: String] {
        // FIX: NEVER compute synchronously during rendering - this was causing app freeze
        // Always return cached value (even if empty). The cache will be populated
        // asynchronously by .task modifiers within ~500ms
        // Empty cache temporarily shows no conflicts, which is acceptable vs freezing the app
        return cachedConflictLookup
    }

    private func computeConflictLookup() -> [MIDIKey: String] {
        var multiMap: [MIDIKey: [String]] = [:]

        // Songs in setlist + library (deduplicate by ID to avoid counting same song twice)
        var seenSongIDs = Set<UUID>()
        for s in (store.activeSongs + songLibrary) {
            // Skip if we've already processed this song ID
            guard !seenSongIDs.contains(s.id) else { continue }
            seenSongIDs.insert(s.id)

            let key = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc,   channel: s.channel, number: s.cc)
            multiMap[key, default: []].append(s.name)
        }

        // Control buttons - add type prefix for clarity
        for b in controlButtons {
            let typePrefix: String
            if b.isFader == true {
                typePrefix = "Fader"
            } else {
                typePrefix = "Button"
            }
            let displayName = b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            multiMap[MIDIKey(kind: b.kind, channel: b.channel, number: b.number), default: []].append(displayName)
        }

        // Convert to single string per key, joining multiple owners (deduplicate names)
        // NOTE: Duplicate cues (same name) intentionally share MIDI - don't count as conflict
        var map: [MIDIKey: String] = [:]
        for (key, owners) in multiMap {
            // Deduplicate owner names - this means cues with the same name
            // (duplicates/copies) won't be counted as separate conflicts
            let uniqueOwners = Array(Set(owners)).sorted()

            // Only store if there are 2+ UNIQUE owners (actual conflicts)
            // Single owner or multiple cues with same name = no conflict
            if uniqueOwners.count >= 2 {
                // Format list with separator
                map[key] = uniqueOwners.joined(separator: "|||")
            }
            // Don't store single owners - no conflict to display
        }

        return map
    }

    // Helper function to format conflict owners, excluding a specific name
    private func formatConflictOwners(_ ownersString: String, excluding excludeName: String? = nil) -> String? {
        // Split by our separator
        let owners = ownersString.split(separator: "|||").map(String.init)

        // Filter out excluded name if provided
        let filteredOwners = excludeName != nil ? owners.filter { $0 != excludeName } : owners

        guard !filteredOwners.isEmpty else { return nil }

        if filteredOwners.count == 1 {
            return filteredOwners[0]
        } else if filteredOwners.count == 2 {
            return "\(filteredOwners[0]) and \(filteredOwners[1])"
        } else if filteredOwners.count <= 4 {
            return filteredOwners.dropLast().joined(separator: ", ") + ", and " + filteredOwners.last!
        } else {
            let shown = filteredOwners.prefix(3).joined(separator: ", ")
            return "\(shown), and \(filteredOwners.count - 3) more"
        }
    }

    private func invalidateConflictCache() {
        // FIX: Immediately rebuild cache instead of clearing it
        // Clearing causes "Save & Add Another" to see empty cache and assign CC#0
        cachedConflictLookup = computeConflictLookup()
        cachedUsedCCs = []
        cacheVersion += 1
        debugPrint("🔄 Conflict cache rebuilt immediately with \(cachedConflictLookup.count) entries")
    }

    // FIX #5: Throttled conflict cache update (500ms throttle)
    private func scheduleConflictCacheUpdate() {
        guard !conflictCacheUpdateScheduled else { return }
        conflictCacheUpdateScheduled = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms throttle
            cachedConflictLookup = computeConflictLookup()
            conflictCacheUpdateScheduled = false
        }
    }

    private func updateConflictCache() {
        // FIX #5: Use throttled version instead of immediate update
        scheduleConflictCacheUpdate()
    }
    
    /// Returns the owner name for a MIDI key (for auto-assign conflict detection)
    /// This checks ALL owners, not just conflicts (unlike conflictLookup which only stores 2+ owners)
    private func ownerName(for key: MIDIKey) -> String? {
        // Check songs in setlist
        for s in store.activeSongs {
            let songKey = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc, channel: s.channel, number: s.cc)
            if songKey == key {
                return s.name
            }
        }

        // Check songs in library (not in setlist)
        for s in songLibrary {
            // Skip if already in setlist (avoid double-counting)
            if store.activeSongs.contains(where: { $0.id == s.id }) { continue }
            let songKey = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc, channel: s.channel, number: s.cc)
            if songKey == key {
                return s.name
            }
        }

        // Check control buttons
        for b in controlButtons {
            let buttonKey = MIDIKey(kind: b.kind, channel: b.channel, number: b.number)
            if buttonKey == key {
                let typePrefix = b.isFader == true ? "Fader" : "Button"
                return b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            }
        }

        return nil
    }

    // MARK: - Global Channel Management
    private func handleGlobalChannelToggle(wasEnabled: Bool, isEnabled: Bool) {
        guard wasEnabled != isEnabled else { return }

        // Don't backup/restore during project loading
        guard !isLoadingProject else {
            debugPrint("🔄 Skipping global channel toggle handling during project load")
            return
        }

        if isEnabled {
            // Enabling global mode: Save current channels and apply global channel
            debugPrint("🌍 Enabling global MIDI channel mode - saving current channels")

            // Save song channels
            savedSongChannels.removeAll()
            for song in store.activeSongs {
                savedSongChannels[song.id] = song.channel
            }
            for song in songLibrary {
                savedSongChannels[song.id] = song.channel
            }

            // Save control channels
            savedControlChannels.removeAll()
            for button in controlButtons {
                savedControlChannels[button.id] = button.channel
            }

            debugPrint("💾 Saved channels for \(savedSongChannels.count) songs and \(savedControlChannels.count) controls")

            // Apply global channel to all items
            applyGlobalChannel()
        } else {
            // Disabling global mode: Restore original channels
            debugPrint("🌍 Disabling global MIDI channel mode - restoring original channels")

            // Restore song channels
            store.updateActiveSongs { songs in
                for i in 0..<songs.count {
                    if let savedChannel = savedSongChannels[songs[i].id] {
                        songs[i].channel = savedChannel
                    }
                }
            }
            for i in 0..<songLibrary.count {
                if let savedChannel = savedSongChannels[songLibrary[i].id] {
                    songLibrary[i].channel = savedChannel
                }
            }

            // Restore control channels
            for i in 0..<controlButtons.count {
                if let savedChannel = savedControlChannels[controlButtons[i].id] {
                    controlButtons[i].channel = savedChannel
                }
            }

            debugPrint("♻️ Restored channels for \(savedSongChannels.count) songs and \(savedControlChannels.count) controls")

            // Clear the saved channels
            savedSongChannels.removeAll()
            savedControlChannels.removeAll()
        }

        // Invalidate cache and mark as dirty
        invalidateConflictCache()
        markDirty()
    }

    private func applyGlobalChannel() {
        debugPrint("🌍 Applying global channel \(globalChannel) to all items")

        // Apply to songs in setlist
        store.updateActiveSongs { songs in
            for i in 0..<songs.count {
                songs[i].channel = globalChannel
            }
        }

        // Apply to songs in library
        for i in 0..<songLibrary.count {
            songLibrary[i].channel = globalChannel
        }

        // Apply to control buttons
        for i in 0..<controlButtons.count {
            controlButtons[i].channel = globalChannel
        }

        debugPrint("✅ Applied global channel to \(store.activeSongs.count + songLibrary.count) songs and \(controlButtons.count) controls")
    }

    // MARK: - Actions
    private func trigger(_ song: Song) {
        let id = song.id.uuidString

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: song.kind, channel: song.channel, number: song.kind == .cc ? song.cc : (song.note ?? 60), value: song.kind == .cc ? 127 : song.velocity, label: song.name, buttonID: id)

        // Trigger flash animation on the cue row
        flashingCueID = song.id
        // Clear the flash trigger after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            flashingCueID = nil
        }

        // Update last played cue for play icon indicator
        lastPlayedCueID = song.id

        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func triggerControl(_ b: ControlButton) {
        var value: Int
        var updatedButton = b

        if b.isToggle == true {
            // Toggle behavior: flip state and send appropriate value
            updatedButton.toggleState.toggle()
            value = updatedButton.toggleState ? (b.kind == .cc ? 127 : b.velocity) : 0
        } else {
            // Momentary behavior: send fixed value
            value = b.kind == .cc ? 127 : b.velocity
        }

        // Use global channel if enabled, otherwise use button's channel
        let channelToUse = isGlobalChannel ? globalChannel : b.channel

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: b.kind, channel: channelToUse, number: b.number, value: value, label: b.title, buttonID: b.id.uuidString)
        
        // Update the button state in the controlButtons array if it's a toggle
        if b.isToggle == true {
            if let index = controlButtons.firstIndex(where: { $0.id == b.id }) {
                controlButtons[index] = updatedButton
            }
        }
        
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func sendFaderMIDI(channel: Int, cc: Int, value: Int, title: String, buttonID: UUID) {
        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
    }

    // MARK: - v1.3 (Cue Bear Next) helpers

    /// First-run checklist: sends a recognisable test message so the user can see it arrive in the DAW.
    private func sendFirstRunTest() {
        let channelToUse = isGlobalChannel ? globalChannel : 1
        connectionCoordinator.sendMIDI(type: .note, channel: channelToUse, number: 60, value: 100,
                                       label: "Cue Bear test", buttonID: "cuebear-first-run-test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            connectionCoordinator.sendMIDI(type: .note, channel: channelToUse, number: 60, value: 0,
                                           label: "Cue Bear test", buttonID: "cuebear-first-run-test")
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// "Copy extras to other songs": each target song gets its own copies (new IDs).
    private func copyExtras(_ extras: [SongExtra], toSongIDs ids: [UUID]) {
        guard !extras.isEmpty, !ids.isEmpty else { return }
        for id in ids {
            guard var target = store.activeSongs.first(where: { $0.id == id })
                    ?? songLibrary.first(where: { $0.id == id }) else { continue }
            var merged = target.extras ?? []
            for e in extras where !merged.contains(where: { $0.title == e.title && $0.number == e.number }) {
                var copy = e
                copy.id = UUID()
                merged.append(copy)
            }
            target.extras = merged
            saveSong(target)
        }
        saveIfNamed()
    }

    /// Saves straight away when the show already has a name; otherwise just marks it changed
    /// (no name prompt popping up over a sheet).
    private func saveIfNamed() {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isUntitledProject(trimmed) {
            isDirty = true
        } else {
            saveCurrentProject(overwrite: true)
        }
    }

    private func cueGo() {
        guard let s = store.cuedSong else { return }
        trigger(s)
        if let i = store.activeSongs.firstIndex(where: { $0.id == s.id }),
           i + 1 < store.activeSongs.count {
            store.cuedSong = store.activeSongs[i + 1]
        }
        // If on last song, stay on it (don't set to nil)
    }

    private func selectPreviousCued() {
        guard let cued = store.cuedSong,
              let i = store.activeSongs.firstIndex(where: { $0.id == cued.id }),
              i > 0 else { return }
        store.cuedSong = store.activeSongs[i - 1]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectNextCued() {
        if let cued = store.cuedSong, let i = store.activeSongs.firstIndex(where: { $0.id == cued.id }) {
            guard i + 1 < store.activeSongs.count else { return }
            store.cuedSong = store.activeSongs[i + 1]
        } else if !store.activeSongs.isEmpty {
            // If nothing cued yet, select first
            store.cuedSong = store.activeSongs.first
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Tutorial Resume
    /// Resumes a tutorial that was interrupted by nav pill or cue capsule tutorial
    private func resumeInterruptedTutorial() {
        guard let interrupted = interruptedTutorial else { return }
        interruptedTutorial = nil

        // Small delay to let the capsule tutorial fully dismiss, then use queue system
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch interrupted {
            case 1: self.requestTutorial(1)
            case 2: self.requestTutorial(2)
            case 3: self.requestTutorial(21)  // 21 = tutorial 2b
            case 4: self.requestTutorial(22)  // 22 = tutorial 2c
            case 5:
                // Skip if control area already open (user found it themselves)
                if !self.effectivelyCollapsedForOverlay {
                    self.hasSeenTutorial3 = true
                } else {
                    self.requestTutorial(3)
                }
            default: break
            }
        }
    }

    // MARK: - Regular Mode Navigation (for Navigation Capsule)
    private func currentSongIndex() -> Int {
        return max(0, min(lastTriggeredSongIndex, store.activeSongs.count - 1))
    }

    private func triggerNext() {
        guard !store.activeSongs.isEmpty else { return }
        // Prevent going past the last song
        guard lastTriggeredSongIndex < store.activeSongs.count - 1 else { return }
        let nextIndex = lastTriggeredSongIndex + 1
        lastTriggeredSongIndex = nextIndex
        let song = store.activeSongs[nextIndex]
        trigger(song)
    }

    private func triggerPrevious() {
        guard !store.activeSongs.isEmpty else { return }
        // Prevent going before the first song
        guard lastTriggeredSongIndex > 0 else { return }
        let prevIndex = lastTriggeredSongIndex - 1
        lastTriggeredSongIndex = prevIndex
        let song = store.activeSongs[prevIndex]
        trigger(song)
    }

    // MARK: - Bluetooth Pedal Handlers
    // These functions handle pedal input intelligently based on the current mode

    private func handlePedalNext() {
        if store.mode == .cue {
            // In Cue mode: move the chosen cue down the list
            selectNextCued()
        } else {
            // In Regular/Navigator mode: trigger next song
            triggerNext()
        }
    }

    private func handlePedalPrevious() {
        if store.mode == .cue {
            // In Cue mode: move the chosen cue up the list
            selectPreviousCued()
        } else {
            // In Regular/Navigator mode: trigger previous song
            triggerPrevious()
        }
    }

    // MARK: - Library helpers
    private func usedCCNumbers() -> Set<Int> {
        // Always compute fresh to avoid state modification during view updates
        var taken: Set<Int> = [CBTransportCC.play, CBTransportCC.stop, CBTransportCC.prev, CBTransportCC.next]
        taken.formUnion(store.activeSongs.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(songLibrary.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(controlButtons.filter{ $0.kind == .cc }.map { $0.number })

        return taken
    }

    private func nextDefaultCueName() -> String {
        let prefix = "Cue "
        var maxN = 0
        // Check all songs in the library (not just active cue list) for unique naming
        for s in songLibrary {
            if s.name.hasPrefix(prefix) {
                let rest = s.name.dropFirst(prefix.count)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "Cue \(maxN + 1)"
    }

    private func nextDefaultControlName(_ prefix: String) -> String {
        var maxN = 0
        for b in controlButtons {
            if b.title.hasPrefix(prefix + " ") {
                let rest = b.title.dropFirst(prefix.count + 1)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "\(prefix) \(maxN + 1)"
    }

    private func cueNameExists(_ name: String, excluding id: UUID? = nil) -> Bool {
        songLibrary.contains { $0.id != id && $0.name.lowercased() == name.lowercased() }
    }

    private func uniqueCueName(baseName: String, excluding id: UUID? = nil) -> String {
        let names = Set(songLibrary.filter { $0.id != id }.map { $0.name.lowercased() })
        if !names.contains(baseName.lowercased()) { return baseName }
        var n = 2
        while names.contains("\(baseName) (\(n))".lowercased()) { n += 1 }
        return "\(baseName) (\(n))"
    }

    /// Handles saving a cue with duplicate name check. Shows alert if name exists, otherwise saves directly.
    private func saveCueWithDuplicateCheck(_ song: Song, andAddAnother: Bool, dismissSheet: @escaping () -> Void) {
        // Skip duplicate check for aliased (duplicated) cues — duplicate names are their purpose
        if song.aliasedCueID != nil {
            saveSong(song)
            dismissSheet()
            return
        }

        // If editing an existing cue whose name is unchanged, skip the check entirely.
        // Check both library and setlist since a cue might be in the setlist but not the library.
        let existingCue = songLibrary.first(where: { $0.id == song.id })
                       ?? store.activeSongs.first(where: { $0.id == song.id })
        if let existingCue, existingCue.name.lowercased() == song.name.lowercased() {
            saveSong(song)
            dismissSheet()
            return
        }

        // For existing cues being renamed, exclude their own ID from the check.
        // Also check setlist in case a cue exists there but not yet in the library.
        let isKnownCue = songLibrary.contains(where: { $0.id == song.id })
                      || store.activeSongs.contains(where: { $0.id == song.id })
        let excludeID: UUID? = isKnownCue ? song.id : nil

        if cueNameExists(song.name, excluding: excludeID) {
            pendingDuplicateCue = song
            pendingDuplicateCueAddAnother = andAddAnother
            duplicateCueName = song.name
            duplicateCueSuggestedName = uniqueCueName(baseName: song.name, excluding: excludeID)
            // Dismiss the edit sheet first, then show the alert — prevents alert appearing behind the open sheet
            dismissSheet()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showDuplicateCueNameAlert = true
            }
        } else {
            saveSong(song)
            dismissSheet()
        }
    }

    private func sortedLibrary() -> [Song] {
        switch sortMode {
        case .nameAZ:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) > (libAddedAt[$1.id] ?? .distantPast) }
        case .oldest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) < (libAddedAt[$1.id] ?? .distantPast) }
        }
    }

    private func libraryDecorated() -> [CBLibraryRow] {
        let setIDs = Set(store.activeSongs.map { $0.id })
        return sortedLibrary().map { s in
            CBLibraryRow(id: s.id, song: s, isInSetlist: setIDs.contains(s.id), isSelected: libSelected.contains(s.id))
        }
    }

    private func filteredLibraryRows() -> [CBLibraryRow] {
        let rows = libraryDecorated()
        // FIX #9: Use debounced query and localizedCaseInsensitiveContains for better performance
        let q = libraryQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter { row in
            row.song.name.localizedCaseInsensitiveContains(q) ||
            (row.song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func filteredSetlistSongs() -> [Song] {
        let songs = store.activeSongs
        let q = setlistQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return songs }
        return songs.filter { song in
            song.name.localizedCaseInsensitiveContains(q) ||
            (song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func toggleLibSelection(_ id: UUID) {
        let songName = songLibrary.first(where: { $0.id == id })?.name ?? "Unknown"
        let wasSelected = libSelected.contains(id)
        debugPrint("🔵 toggleLibSelection called for: \(songName) (ID: \(id)), wasSelected: \(wasSelected)")
        if libSelected.contains(id) { libSelected.remove(id) } else { libSelected.insert(id) }
        let nowSelected = libSelected.contains(id)
        debugPrint("🔵 toggleLibSelection completed for: \(songName), nowSelected: \(nowSelected)")
    }

    private func selectAllLibrary() {
        // Select ALL items in the library, including those already in the cue list
        let candidates = filteredLibraryRows()
        libSelected = Set(candidates.map { $0.id })
    }

    private func addSelectedToSetlist() {
        guard !libSelected.isEmpty else { return }
        let toAdd = songLibrary.filter { libSelected.contains($0.id) }
        toAdd.forEach(addToSetlist(_:))
        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func deleteSelectedFromLibrary() {
        guard !libSelected.isEmpty else { return }
        pushSetlistUndo()
        pushLibraryUndo()

        // Remove from both library and cue list
        songLibrary.removeAll { libSelected.contains($0.id) }
        store.updateActiveSongs { $0.removeAll { libSelected.contains($0.id) } }

        // Clean up metadata for deleted songs
        libSelected.forEach { libAddedAt[$0] = nil }
        invalidateConflictCache()
        isDirty = true

        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    // MARK: - Setlist Batch Operations

    private func toggleSetlistSelection(_ id: UUID) {
        let songName = store.activeSongs.first(where: { $0.id == id })?.name ?? "Unknown"
        let wasSelected = setlistSelected.contains(id)
        debugPrint("🔵 toggleSetlistSelection called for: \(songName) (ID: \(id)), wasSelected: \(wasSelected)")
        if setlistSelected.contains(id) { setlistSelected.remove(id) } else { setlistSelected.insert(id) }
        let nowSelected = setlistSelected.contains(id)
        debugPrint("🔵 toggleSetlistSelection completed for: \(songName), nowSelected: \(nowSelected)")
    }

    private func selectAllSetlist() {
        let candidates = filteredSetlistSongs()
        setlistSelected = Set(candidates.map { $0.id })
    }

    private func removeSelectedFromSetlist() {
        guard !setlistSelected.isEmpty else { return }
        pushSetlistUndo()

        // Remove from cue list only
        store.updateActiveSongs { $0.removeAll { setlistSelected.contains($0.id) } }

        invalidateConflictCache()
        isDirty = true

        setlistSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func addToSetlist(_ s: Song) {
        debugPrint("➕ addToSetlist called for: \(s.name) (ID: \(s.id))")
        pushSetlistUndo()
        let alreadyInSetlist = store.activeSongs.contains(where: { $0.id == s.id })
        debugPrint("➕ Already in setlist: \(alreadyInSetlist)")
        guard !alreadyInSetlist else {
            debugPrint("➕ Skipping add - song already in setlist")
            return
        }

        // Auto-assign MIDI message if not already assigned
        var songToAdd = s
        if songToAdd.channel == 0 || songToAdd.cc == 0 {
            // Find first available CC message
            let freeCC = firstFreeCC()
            if freeCC >= 0 {
                songToAdd.kind = .cc
                songToAdd.channel = 1
                songToAdd.cc = freeCC
                songToAdd.velocity = 127
            }
        }

        debugPrint("➕ Appending \(s.name) to setlist")
        store.updateActiveSongs { $0.append(songToAdd) }
        invalidateConflictCache()
        isDirty = true
        debugPrint("➕ addToSetlist completed for: \(s.name), setlist now has \(store.activeSongs.count) songs")
    }

    private func firstFreeCC() -> Int {
        for cc in 0...127 {
            let key = MIDIKey(kind: .cc, channel: 1, number: cc)
            if conflictLookup()[key] == nil {
                return cc
            }
        }
        return -1 // No free CC found
    }

    private func removeFromSetlist(_ s: Song) {
        debugPrint("🔴 removeFromSetlist called for: \(s.name) (ID: \(s.id))")
        let countBefore = store.activeSongs.count
        debugPrint("🔴 Setlist size before removal: \(countBefore)")
        pushSetlistUndo()
        store.updateActiveSongs { $0.removeAll { $0.id == s.id } }
        let countAfter = store.activeSongs.count
        debugPrint("🔴 Setlist size after removal: \(countAfter)")
        isDirty = true
        debugPrint("🔴 removeFromSetlist completed for: \(s.name), removed: \(countBefore - countAfter) song(s)")
    }

    private func deleteFromLibrary(_ s: Song) {
        // Dismiss library popover so it doesn't cover the confirmation dialog
        showLibraryPopover = false

        // Check if song is in ANY cue list
        let isInAnyCueList = store.cueLists.contains { cueList in
            cueList.songs.contains(where: { $0.id == s.id })
        }

        if isInAnyCueList {
            // Show confirmation popup
            songToDelete = s
            showDeleteConfirmation = true
        } else {
            // Safe to delete from library only
            performDeleteFromLibrary(s)
        }
    }
    
    private func performDeleteFromLibrary(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        // Convert any alias cues pointing to this song into regular cues AND remove song from ALL cue lists
        for i in 0..<store.cueLists.count {
            var updated = false
            for j in 0..<store.cueLists[i].songs.count {
                // Convert aliases to regular cues
                if store.cueLists[i].songs[j].aliasedCueID == s.id {
                    store.cueLists[i].songs[j].aliasedCueID = nil
                    debugPrint("🔄 Converted alias cue '\(store.cueLists[i].songs[j].name)' to regular cue (original deleted)")
                    updated = true
                }
            }
            // Remove the song from this cue list
            let beforeCount = store.cueLists[i].songs.count
            store.cueLists[i].songs.removeAll { $0.id == s.id }
            let afterCount = store.cueLists[i].songs.count
            if beforeCount != afterCount {
                updated = true
                debugPrint("🗑️ Removed song '\(s.name)' from cue list '\(store.cueLists[i].name)'")
            }
            // Update timestamp if modified
            if updated {
                store.cueLists[i].touch()
            }
        }

        // Remove from library
        songLibrary.removeAll { $0.id == s.id }
        libAddedAt[s.id] = nil
        invalidateConflictCache()
        isDirty = true

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func duplicateSong(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        // If this is an alias cue, duplicate the original cue instead
        let sourceSong: Song
        if let aliasedID = s.aliasedCueID,
           let originalCue = songLibrary.first(where: { $0.id == aliasedID }) {
            sourceSong = originalCue
        } else {
            sourceSong = s
        }

        // Create copy with same name but "copy of [name]" as subtitle
        var copy = Song(name: sourceSong.name, subtitle: "copy of \(sourceSong.name)", cc: sourceSong.cc, channel: sourceSong.channel)
        copy.kind = sourceSong.kind
        copy.note = sourceSong.note
        copy.velocity = sourceSong.velocity
        copy.colorHex = sourceSong.colorHex
        copy.midiEnabled = sourceSong.midiEnabled
        // Don't copy aliasedCueID - this is a real duplicate, not an alias
        songLibrary.append(copy)
        libAddedAt[copy.id] = Date()

        // Add the copy to the cue list right after the original song
        store.updateActiveSongs { songs in
            if let index = songs.firstIndex(where: { $0.id == s.id }) {
                songs.insert(copy, at: index + 1)
            }
        }

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.5)
        isDirty = true
        saveCurrentProject(overwrite: true)
    }

    private func saveSong(_ song: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        var song = song

        let isNewSong = !songLibrary.contains(where: { $0.id == song.id })

        // Auto-assign random color for new cues if enabled and no color set
        if isNewSong && autoAssignCueColors && song.colorHex == nil {
            let usedColors = Set(songLibrary.compactMap { $0.colorHex })
            let available = curatedColorPalette.filter { !usedColors.contains($0) }
            if let random = available.randomElement() {
                song.colorHex = random
            } else {
                song.colorHex = curatedColorPalette.randomElement()
            }
        }

        // Update existing song in setlist if it's there
        store.updateActiveSongs { songs in
            if let i = songs.firstIndex(where: { $0.id == song.id }) {
                songs[i] = song
            }
        }

        // Add or update in library
        if let j = songLibrary.firstIndex(where: { $0.id == song.id }) {
            songLibrary[j] = song
        } else {
            songLibrary.append(song)
            libAddedAt[song.id] = Date()

            // For new songs, also add directly to cue list for better UX
            if isNewSong && !store.activeSongs.contains(where: { $0.id == song.id }) {
                store.updateActiveSongs { $0.append(song) }
        }
        }

        // Invalidate conflict cache since MIDI assignments may have changed
        invalidateConflictCache()
        isDirty = true
    }

    private func markDirty() {
        isDirty = true
    }

    private func loadMidiFiltersFromUserDefaults() {
        if let saved = UserDefaults.standard.array(forKey: "midiFilterCCs") as? [Int] {
            midiFilter = Set(saved)
        }
        let ccs = UserDefaults.standard.array(forKey: "midiCustomFilterCCs") as? [Int] ?? []
        let names = UserDefaults.standard.array(forKey: "midiCustomFilterNames") as? [String] ?? []
        if ccs.count == names.count && !ccs.isEmpty {
            customMidiFilters = zip(ccs, names).map { ($0, $1) }
        }
    }

    private func saveMidiCustomFiltersToUserDefaults() {
        UserDefaults.standard.set(customMidiFilters.map { $0.0 }, forKey: "midiCustomFilterCCs")
        UserDefaults.standard.set(customMidiFilters.map { $0.1 }, forKey: "midiCustomFilterNames")
    }

    private func snapshotAndSave(as name: String, overwrite: Bool) {
        let cueLists = store.cueLists
        let activeCueListID = store.activeCueListID
        let library = songLibrary
        let controls = controlButtons
        let isGlobalCh = isGlobalChannel
        let globalCh = globalChannel
        let theme = selectedThemeID
        let appMode = store.mode
        let filtersEnabled = midiFiltersEnabled
        let filter = midiFilter
        let customFilters = customMidiFilters
        DispatchQueue.global(qos: .utility).async {
            do {
                try ProjectIO.save(name: name, cueLists: cueLists, activeCueListID: activeCueListID, library: library, controls: controls, isGlobalChannel: isGlobalCh, globalChannel: globalCh, theme: theme, appMode: appMode, midiFiltersEnabled: filtersEnabled, midiFilter: filter, customMidiFilters: customFilters)
                let projects = ProjectIO.list()
                DispatchQueue.main.async {
                    projectName = name
                    isDirty = false
                    projectsList = projects
                }
            } catch { debugPrint("Save failed: \(error)") }
        }
    }

    /// Generate a unique project name by appending (1), (2), etc. if name already exists
    private func uniqueProjectName(baseName: String) -> String {
        let existingProjects = projectsList

        // If name doesn't exist, return as-is
        if !existingProjects.contains(baseName) {
            return baseName
        }

        // Find the next available number
        var counter = 1
        while existingProjects.contains("\(baseName) (\(counter))") {
            counter += 1
        }

        return "\(baseName) (\(counter))"
    }

    // MARK: - Undo/Redo helpers
    private func pushSetlistUndo() {
        setlistUndoStack.append(store.activeSongs)
        if setlistUndoStack.count > 30 { setlistUndoStack.removeFirst() }
        setlistRedoStack.removeAll()
    }
    private func undoSetlist() {
        guard let last = setlistUndoStack.popLast() else { return }
        setlistRedoStack.append(store.activeSongs)
        store.updateActiveSongs { $0 = last }
        isDirty = true
    }
    private func redoSetlist() {
        guard let next = setlistRedoStack.popLast() else { return }
        setlistUndoStack.append(store.activeSongs)
        store.updateActiveSongs { $0 = next }
        isDirty = true
    }
    
    private func pushLibraryUndo() {
        libraryUndoStack.append(songLibrary)
        if libraryUndoStack.count > 30 { libraryUndoStack.removeFirst() }
        libraryRedoStack.removeAll()
    }
    private func undoLibrary() {
        guard let last = libraryUndoStack.popLast() else { return }
        libraryRedoStack.append(songLibrary)
        songLibrary = last
        isDirty = true
    }
    private func redoLibrary() {
        guard let next = libraryRedoStack.popLast() else { return }
        libraryUndoStack.append(songLibrary)
        songLibrary = next
        isDirty = true
    }
    
    // Combined undo/redo that handles both setlist and library
    private func performUndo() {
        // Prioritize setlist undo if available, otherwise library undo
        if !setlistUndoStack.isEmpty {
            undoSetlist()
        } else if !libraryUndoStack.isEmpty {
            undoLibrary()
        }
    }
    
    private func performRedo() {
        // Prioritize setlist redo if available, otherwise library redo
        if !setlistRedoStack.isEmpty {
            redoSetlist()
        } else if !libraryRedoStack.isEmpty {
            redoLibrary()
        }
    }

    private func pushControlUndo() {
        controlUndoStack.append(controlButtons)
        controlRedoStack.removeAll()
    }
    private func undoControls() {
        guard let last = controlUndoStack.popLast() else { return }
        controlRedoStack.append(controlButtons)
        controlButtons = last
        invalidateConflictCache()
        markDirty()
    }
    private func redoControls() {
        guard let next = controlRedoStack.popLast() else { return }
        controlUndoStack.append(controlButtons)
        controlButtons = next
        invalidateConflictCache()
        markDirty()
    }

    // Control edit mode auto-exit timer
    private func startControlEditModeTimer() {
        // Cancel existing timer
        controlEditModeTimer?.invalidate()

        // Start new 5-second timer
        controlEditModeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut) {
                controlEditMode = false
            }
        }
    }

    private func cancelControlEditModeTimer() {
        controlEditModeTimer?.invalidate()
        controlEditModeTimer = nil
    }

    private func resetControlEditModeTimer() {
        if controlEditMode {
            startControlEditModeTimer()
        }
    }

    private func saveCurrentProject(overwrite: Bool) {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show name prompt for "Save As" OR when saving an untitled project for the first time
        if !overwrite || trimmed.isEmpty || isUntitledProject(trimmed) {
            // Pre-fill with current name for "Save As", or suggest active cue list name for new projects
            tempName = trimmed.isEmpty || isUntitledProject(trimmed) ? (store.activeCueList?.name ?? "My Show") : trimmed
            shouldSaveAfterNaming = true  // Mark that we should save after user enters name
            showNamePrompt = true
            return
        }

        // For projects with a name, save directly
        snapshotAndSave(as: trimmed, overwrite: overwrite)
    }

    private func loadProject(named: String) {
        do {
            debugPrint("🔄 Loading project: \(named)")
            let payload = try ProjectIO.load(name: named)
            debugPrint("📦 Project payload loaded - cueLists: \(payload.cueLists?.count ?? 0), library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Set loading flag to prevent global channel toggle from triggering backup/restore
            isLoadingProject = true

            projectName = payload.name

            // Migrate legacy format: convert setlist to "Main" cue list
            if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                debugPrint("🔄 Migrating legacy project format to v1.2.0")
                let mainList = CueList(name: "Main", songs: legacySetlist)
                store.cueLists = [mainList]
                store.activeCueListID = mainList.id
                debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
            } else {
                // Modern format or empty legacy
                store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                store.activeCueListID = payload.activeCueListID ?? store.cueLists.first?.id
            }
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Restore app mode preference if saved
            if let savedMode = payload.appMode {
                store.mode = savedMode
                debugPrint("✅ Restored app mode: \(savedMode)")
            }

            // MIDI filter settings are global preferences (UserDefaults), not per-project.
            // Do not restore from project file — loadMidiFiltersFromUserDefaults() on onAppear handles this.

            // Reset loading flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoadingProject = false
            }

            // Migrate controls that are beyond the 4-row limit (rows 0-3)
            migrateOutOfBoundsControls()

            debugPrint("✅ Project data assigned - cueLists: \(store.cueLists.count), activeSongs: \(store.activeSongs.count) songs, library: \(songLibrary.count) songs, controls: \(controlButtons.count) buttons")
            
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil { libAddedAt[s.id] = now }
            isDirty = false

            // Clear autosave when loading a named project
            ProjectIO.clearLibraryAutosave()

            debugPrint("✅ Project loaded successfully: \(named)")

            // v1.0.8: Auto-recover empty library from setlist
            recoverEmptyLibrary()
        } catch {
            debugPrint("❌ Load failed for project \(named): \(error)")
        }
    }

    /// v1.0.8: Auto-recovery for corrupted projects where library is empty but setlist has songs
    /// This copies all songs from setlist to library and marks project as dirty for save
    private func recoverEmptyLibrary() {
        // Only recover if library is empty AND setlist has songs
        guard songLibrary.isEmpty && !store.activeSongs.isEmpty else {
            return
        }

        debugPrint("🔧 RECOVERY: Detected empty library with \(store.activeSongs.count) songs in setlist")
        debugPrint("🔧 RECOVERY: Auto-populating library from setlist...")

        // Copy all songs from setlist to library
        songLibrary = store.activeSongs

        // Set timestamps for all recovered songs
        let now = Date()
        for song in songLibrary {
            libAddedAt[song.id] = now
        }

        // Mark project as dirty so it gets saved
        isDirty = true

        debugPrint("✅ RECOVERY: Added \(songLibrary.count) songs to library")
        debugPrint("✅ RECOVERY: Project marked as dirty - save to keep changes")
    }

    /// Migrates controls that are positioned beyond the 4-row limit (rows 0-3) or 8-column limit (cols 0-7)
    /// This fixes projects created when the row limit was higher or controls positioned incorrectly
    private func migrateOutOfBoundsControls() {
        // FIX #10: Early exit check using .contains for performance
        let hasOutOfBounds = controlButtons.contains { button in
            let width = button.gridWidth
            let height = button.gridHeight

            if let row = button.gridRow, row >= 4 { return true }
            if let col = button.gridCol, col >= 8 { return true }
            if let col = button.gridCol, col + width > 8 { return true }
            if let row = button.gridRow, row + height > 4 { return true }
            return false
        }

        guard hasOutOfBounds else {
            debugPrint("✅ No out-of-bounds controls found")
            return
        }

        var migratedCount = 0

        debugPrint("⚠️ Found controls out of bounds (beyond row 3 or col 7), starting migration...")

        // Second pass: reposition out-of-bounds controls
        for i in 0..<controlButtons.count {
            let button = controlButtons[i]
            let width = button.gridWidth
            let height = button.gridHeight
            var needsRepositioning = false

            // Check all out-of-bounds conditions
            if let row = button.gridRow, row >= 4 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col >= 8 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col + width > 8 {
                needsRepositioning = true
            }
            if let row = button.gridRow, row + height > 4 {
                needsRepositioning = true
            }

            if needsRepositioning {
                let currentCol = button.gridCol ?? -1
                let currentRow = button.gridRow ?? -1
                debugPrint("🔧 Control '\(button.title)' at (\(currentCol), \(currentRow)) size \(width)×\(height) needs repositioning")

                // Try to find an available position within the 4-row, 8-column limit

                var foundPosition = false
                for newRow in 0..<4 {
                    for newCol in 0..<(8 - width + 1) {
                        var canPlace = true

                        // Check if this position is free
                        for j in 0..<controlButtons.count where i != j {
                            if let existingCol = controlButtons[j].gridCol,
                               let existingRow = controlButtons[j].gridRow {
                                let existingWidth = controlButtons[j].gridWidth
                                let existingHeight = controlButtons[j].gridHeight

                                // Check for overlap
                                if !(newCol + width <= existingCol ||
                                    existingCol + existingWidth <= newCol ||
                                    newRow + height <= existingRow ||
                                    existingRow + existingHeight <= newRow) {
                                    canPlace = false
                                    break
                                }
                            }
                        }

                        if canPlace {
                            controlButtons[i].gridCol = newCol
                            controlButtons[i].gridRow = newRow
                            foundPosition = true
                            migratedCount += 1
                            debugPrint("✅ Repositioned '\(button.title)' to (\(newCol), \(newRow))")
                            break
                        }
                    }
                    if foundPosition { break }
                }

                if !foundPosition {
                    // No space found - clear position to let auto-assign handle it
                    controlButtons[i].gridCol = nil
                    controlButtons[i].gridRow = nil
                    debugPrint("⚠️ No space found for '\(button.title)', cleared position for auto-assign")
                }
            }
        }

        if migratedCount > 0 {
            debugPrint("✅ Migration complete: repositioned \(migratedCount) control(s)")
            // Mark as dirty so the migration is saved
            markDirty()
        }
    }

    // MARK: - Automatic Save/Open Functions
    
    /// Start automatic saving with debouncing
    private func startAutosave() {
        // Cancel existing autosave task
        autosaveTask?.cancel()

        // Only autosave if project has a name (not "Untitled Project")
        guard !isUntitledProject(projectName) && !projectName.isEmpty else { return }

        autosaveTask = Task {
            // Wait 2 seconds before saving to debounce rapid changes
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if isDirty && !isUntitledProject(projectName) {
                    debugPrint("💾 Auto-saving project: \(projectName)")
                    do {
                        try ProjectIO.save(name: projectName, cueLists: store.cueLists, activeCueListID: store.activeCueListID, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel, theme: selectedThemeID, appMode: store.mode, midiFiltersEnabled: midiFiltersEnabled, midiFilter: midiFilter, customMidiFilters: customMidiFilters)
                        isDirty = false
                        debugPrint("✅ Auto-save completed: \(projectName)")
                    } catch {
                        debugPrint("❌ Auto-save failed: \(error)")
                    }
                }
            }
        }
    }
    
    /// Automatically open the last project on app launch
    @MainActor private func autoOpenLastProject() async {
        debugPrint("🔍 Auto-open check - projectName: '\(projectName)'")
        debugPrint("🔍 UserDefaults lastProjectName: '\(UserDefaults.standard.string(forKey: "lastProjectName") ?? "nil")'")
        debugPrint("🔍 hasCompletedInitialLaunch: \(hasCompletedInitialLaunch)")

        // First launch - new users start with an empty project
        if !hasCompletedInitialLaunch {
            debugPrint("🎵 First launch detected - starting with empty project")
            hasCompletedInitialLaunch = true
            return
        }

        // For subsequent launches, load the last opened project
        guard !isUntitledProject(projectName) && !projectName.isEmpty else {
            debugPrint("⏭️ Skipping auto-open - projectName is 'Untitled Project' or empty")
            // For "Untitled Project" projects, try to restore library from autosave
            if let saved = await Task.detached(priority: .userInitiated, operation: { ProjectIO.loadLibraryAutosave() }).value {
                songLibrary = saved
                debugPrint("📂 Restored library from autosave for Untitled project (\(saved.count) songs)")
            }
            return
        }

        // Check if the project file exists
        do {
            let name = projectName
            let payload = try await Task.detached(priority: .userInitiated) { try ProjectIO.load(name: name) }.value
            debugPrint("🔄 Auto-opening last project: \(projectName)")
            debugPrint("📦 Auto-open payload - cueLists: \(payload.cueLists?.count ?? 0), library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Set loading flag to prevent global channel toggle from triggering backup/restore
            isLoadingProject = true

            // Load the project data - migrate legacy format if needed
            if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                debugPrint("🔄 Migrating legacy auto-open project to v1.2.0")
                let mainList = CueList(name: "Main", songs: legacySetlist)
                store.cueLists = [mainList]
                store.activeCueListID = mainList.id
                debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
            } else {
                store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                store.activeCueListID = payload.activeCueListID ?? store.cueLists.first?.id
            }
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Restore MIDI filter settings if saved
            // MIDI filter settings are global preferences (UserDefaults), not per-project.
            // Do not restore from project file — loadMidiFiltersFromUserDefaults() on onAppear handles this.

            // Reset loading flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoadingProject = false
            }
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil {
                libAddedAt[s.id] = now
            }
            isDirty = false

            // Clear autosave when loading a named project
            ProjectIO.clearLibraryAutosave()

            debugPrint("✅ Successfully auto-opened: \(projectName)")
        } catch {
            debugPrint("❌ Failed to auto-open '\(projectName)': \(error)")
            debugPrint("💡 Project may have been deleted or corrupted")
            // Reset to untitled if project doesn't exist
            projectName = "Untitled"
        }
    }
    
    // MARK: - Document-Based Project Functions
    
    /// Open document picker to load projects from Files/iCloud Drive
    private func openDocumentPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("❌ Could not find root view controller for document picker")
            return
        }
        
        debugPrint("📁 ContentView: Presenting document picker from root view controller")

        DocumentProjectIO.presentDocumentPicker(from: rootViewController) { url in
            debugPrint("📁 ContentView: Document picker completion called with URL: \(url?.absoluteString ?? "nil")")

            guard let url = url else {
                debugPrint("📁 ContentView: No URL received (user cancelled)")
                return
            }

            debugPrint("📁 ContentView: Calling openProject with URL: \(url.path)")

            DocumentProjectIO.openProject(from: url) { payload in
                DispatchQueue.main.async {
                    if let payload = payload {
                        debugPrint("✅ ContentView: Project payload received: \(payload.name)")

                        // Generate unique name if project with same name already exists
                        let uniqueName = self.uniqueProjectName(baseName: payload.name)
                        if uniqueName != payload.name {
                            debugPrint("📝 ContentView: Project renamed from '\(payload.name)' to '\(uniqueName)' to avoid overwrite")
                        }

                        // Set loading flag to prevent global channel toggle from triggering backup/restore
                        self.isLoadingProject = true

                        self.projectName = uniqueName

                        // Migrate legacy format if needed
                        if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                            debugPrint("🔄 Migrating imported legacy project to v1.2.0")
                            let mainList = CueList(name: "Main", songs: legacySetlist)
                            self.store.cueLists = [mainList]
                            self.store.activeCueListID = mainList.id
                            debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
                        } else {
                            self.store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                            self.store.activeCueListID = payload.activeCueListID ?? self.store.cueLists.first?.id
                        }
                        self.songLibrary = payload.library
                        self.controlButtons = payload.controls
                        self.isGlobalChannel = payload.isGlobalChannel ?? false
                        self.globalChannel = payload.globalChannel ?? 1

                        // Reset loading flag after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isLoadingProject = false
                        }
                        let now = Date()
                        for s in self.songLibrary where self.libAddedAt[s.id] == nil {
                            self.libAddedAt[s.id] = now
                        }
                        self.isDirty = true  // Mark as dirty so user needs to save the imported project
                        debugPrint("✅ ContentView: Project loaded successfully as: \(uniqueName)")
                    } else {
                        debugPrint("❌ ContentView: Failed to load project - showing error alert")
                        self.documentLoadErrorMessage = "Could not open the selected project file. The file may be corrupted or in an unsupported format."
                        self.showDocumentLoadError = true
                    }
                }
            }
        }
    }

    /// Export current project to share sheet (save to Files, AirDrop, etc.)
    private func exportCurrentProject() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("❌ Could not find root view controller for export")
            return
        }

        debugPrint("📤 ContentView: Exporting project: \(projectName)")

        // Create payload from current state
        let payload = ProjectPayload(
            name: projectName,
            cueLists: store.cueLists,
            activeCueListID: store.activeCueListID,
            library: songLibrary,
            controls: controlButtons,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel,
            theme: selectedThemeID,
            appMode: store.mode
        )

        // Present share sheet
        DocumentProjectIO.exportProject(
            name: projectName,
            data: payload,
            from: rootViewController
        )
    }

    private func newProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                createNewProject()
            }
        } else {
            createNewProject()
        }
    }

    private func openProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                projectsList = ProjectIO.list()
                showProjects = true
            }
        } else {
            projectsList = ProjectIO.list()
            showProjects = true
        }
    }

    private func createNewProject() {
        projectName = "Untitled Project"
        store.reset()  // Reset to single "Untitled Cue List"
        songLibrary.removeAll()
        controlButtons.removeAll()
        libAddedAt.removeAll()
        isDirty = false
        // No seeding for shipping - start blank

        // v1.0.8: Dismiss project sheet after creating new project
        showProjects = false
    }
    
    private func checkUnsavedChangesBeforeAction(_ action: @escaping () -> Void) {
        // v1.0.8: Only show save prompt for projects that have been saved before (not "Untitled Project")
        // Matches autosave behavior pattern used throughout the app
        if isDirty && !isUntitledProject(projectName) {
            showSaveChangesAlert = true
            pendingAction = action
        } else {
            action()
        }
    }

    // Helper function to check if project name is untitled
    private func isUntitledProject(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Untitled" || trimmed == "Untitled Project"
    }

    // MARK: - Ready for Shipping
    // App starts with completely blank data - no placeholder content
}

// MARK: - Conditional Drawing Group
// Applies drawingGroup only when enabled (skip on iPhone to avoid rendering issues)
struct ConditionalDrawingGroup: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.drawingGroup(opaque: false, colorMode: .nonLinear)
        } else {
            content
        }
    }
}

// MARK: - Press Gesture Modifier
// Applies press feedback gesture for visual touch feedback on both iPhone and iPad
// (Previously disabled on iPhone to allow ScrollView scrolling, but ScrollView was removed)
struct PressGestureModifier: ViewModifier {
    let isPhone: Bool
    @Binding var isTouching: Bool
    @Binding var isPressed: Bool
    var onTouchDown: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isTouching {
                                isTouching = true
                                isPressed = true
                                onTouchDown?()
                            }
                        }
                        .onEnded { _ in
                            isTouching = false
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isPressed = false
                            }
                        }
                )
    }
}

// MARK: - Splash Screen
struct SplashScreen: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Bear paw icon
                Image("BearPawIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.2)
                
                // App name
                Text("Cue Bear")
                    .font(.cb(.display, .bold))
                    .foregroundStyle(CBColor.textPrimary)

                // Subtle loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
        }
    }
}
