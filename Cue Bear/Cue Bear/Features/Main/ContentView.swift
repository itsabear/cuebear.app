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
    @Environment(\.scenePhase) var scenePhase

    // Simple connection systems - USB server + WiFi client
    @EnvironmentObject var usbServer: ConnectionManager
    @EnvironmentObject var wifiClient: BridgeOutput
    @EnvironmentObject var connectionCoordinator: ConnectionCoordinator

    // UI state
    @State var showConnections = false
    @State var showAddEdit = false
    @State var editingSong: Song? = nil
    @State var isEditing = false
    @State var modeBeforeEditing: AppMode? = nil  // Remember mode before entering edit mode
    @State var editModeTab: Int = 1  // iPhone only: 0 = Library, 1 = Cue List
    @State var showEditModeViewPicker = false  // iPhone only: Show sheet to choose view
    @State var reorderMode = false  // v1.0.9: Reorder mode for cue list
    @State var setlistBatchMode = false  // Batch select mode for cue list
    @State var setlistSelected: Set<UUID> = []  // Selected cues in batch mode
    @State var showLibraryPopover = false  // Show song library popover
    @State var showCueListChooser = false  // Show cue list chooser popover

    // Library state
    @State var songLibrary: [Song] = []
    @State var libBatchMode = false
    @State var libSelected: Set<UUID> = []
    @State var sortMode: LibrarySortMode = .nameAZ
    @State var libAddedAt: [UUID: Date] = [:]
    @State var libraryQuery: String = ""
    @State var libraryQueryDebounced: String = ""
    @State var setlistQuery: String = ""
    @State var setlistQueryDebounced: String = ""
    @FocusState var isSetlistSearchFocused: Bool

    // Splash Screen - v1.0.8: Use AppStorage to persist across view recreations
    @AppStorage("hasCompletedInitialLaunch") var hasCompletedInitialLaunch = false
    @State var showSplash = true
    @State var hasInitialized = false

    // v1.0.8: Draft managers to preserve edits across sheet dismissals
    @StateObject var cueEditorDraft = CueEditorDraft()
    @StateObject var controlEditorDraft = ControlEditorDraft()

    // Onboarding Tutorial State
    // Flow: Onboarding → T1 (Edit btn) → T2 (+ btn) → T2b (Library btn) → exit edit → T2c (cue list name) → T3 (Controls)
    @AppStorage("hasSeenTutorial1") var hasSeenTutorial1 = false  // Tutorial 1: Edit button
    @AppStorage("hasSeenTutorial2") var hasSeenTutorial2 = false  // Tutorial 2: + button
    @AppStorage("hasSeenTutorial2b") var hasSeenTutorial2b = false  // Tutorial 2b: Library button
    @AppStorage("hasSeenTutorial2c") var hasSeenTutorial2c = false  // Tutorial 2c: Cue list name
    @AppStorage("hasSeenTutorial3") var hasSeenTutorial3 = false  // Tutorial 3: Controls capsule
    // Tutorial 4 removed (two-finger scroll no longer exists)
    @State var showTutorial1 = false  // Tutorial 1: Edit button (after onboarding)
    @State var showTutorial2 = false  // Tutorial 2: + button (after clicking Edit)
    @State var showTutorial2b = false  // Tutorial 2b: Library button
    @State var showTutorial2c = false  // Tutorial 2c: Cue list name button (after exiting edit)
    @State var showTutorial3 = false  // Tutorial 3: Controls capsule
    // showTutorial4 removed (two-finger scroll no longer exists)
    @State var interruptedTutorial: Int? = nil  // Track which tutorial was interrupted by nav/cue capsule tutorial (1, 2, 2 for 2b, 3 for 2c, 4 for 3)
    @State var pendingTutorial: Int? = nil  // Tutorial waiting to be shown (queued because another is active)

    /// Check if any tutorial is currently showing
    var isAnyTutorialShowing: Bool {
        showTutorial1 || showTutorial2 || showTutorial2b || showTutorial2c || showTutorial3
    }

    /// Request to show a tutorial - will queue if another is active
    /// Tutorial IDs: 1=Edit, 2=AddCue, 2b=Library, 2c=CueListName, 3=Controls
    func requestTutorial(_ tutorialId: Int) {
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
    func showTutorialById(_ tutorialId: Int) {
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
    func onTutorialDismissed() {
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
    @State var editButtonFrame: CGRect = .zero  // Edit button in top right capsule
    @State var addCueButtonFrame: CGRect = .zero  // + button in edit mode
    @State var libraryButtonFrame: CGRect = .zero  // Library button (book icon)
    @State var cueListNameButtonFrame: CGRect = .zero  // Cue list name button (top left)
    @State var controlsCapsuleFrame: CGRect = .zero  // Controls capsule (bottom right)
    // controlAreaFrame removed (tutorial 4 no longer exists)

    // Projects
    @State var showProjects = false
    @State var showOnboarding = false
    @State var showShowMode = false  // v1.3: no longer used (Show is now the home screen)
    // v1.3 (Cue Bear Next): Show | Build
    @AppStorage("cb.screenMode") var screenModeRaw: String = CBScreenMode.show.rawValue
    @State var isShowLocked = false
    @State var buildTab: BuildTab = .setlist
    @State var buildSelectedSongID: UUID? = nil
    @State var buildSelectedControlID: UUID? = nil
    /// The song / control whose inspector edits already made an undo step
    @State var inspectorUndoSongID: UUID? = nil
    @State var inspectorUndoControlID: UUID? = nil
    @State var songForDetails: Song? = nil  // v1.3: Notes & Extras sheet
    @Binding var crashAlertActive: Bool  // Prevents onboarding from showing while crash alert is active
    @AppStorage("lastProjectName") var projectName: String = "Untitled"
    @State var projectsList: [String] = []
    @State var isDirty: Bool = false
    @State var showNamePrompt: Bool = false
    @State var tempName: String = ""
    @State var showSaveChangesAlert: Bool = false
    @State var pendingAction: (() -> Void)? = nil
    @State var shouldSaveAfterNaming: Bool = false  // Track if we should save after user names the project

    // Cue list renaming
    @State var showCueListRenamePrompt: Bool = false
    @State var cueListToRename: UUID? = nil
    @State var tempCueListName: String = ""
    @State var showDuplicateRenameAlert: Bool = false
    @State var duplicateRenameNewName: String = ""

    // Cue list creation
    @State var showNewCueListPrompt: Bool = false
    @State var newCueListName: String = ""
    @State var showDuplicateCueListAlert: Bool = false
    @State var duplicateCueListName: String = ""

    // Duplicate cue name detection
    @State var showDuplicateCueNameAlert: Bool = false
    @State var duplicateCueName: String = ""
    @State var duplicateCueSuggestedName: String = ""
    @State var pendingDuplicateCue: Song? = nil
    @State var pendingDuplicateCueAddAnother: Bool = false

    // Navigation capsule (Regular + Remote mode)
    @State var lastTriggeredSongIndex: Int = 0

    // Last played cue (for play icon indicator)
    @State var lastPlayedCueID: UUID? = nil

    // Selected/chosen cue (for expanded width in cue list)
    @State var selectedCue: UUID? = nil

    // Song deletion confirmation
    @State var showDeleteConfirmation: Bool = false
    @State var songToDelete: Song? = nil

    // Document loading error alert
    @State var showDocumentLoadError: Bool = false
    @State var documentLoadErrorMessage: String = ""

    // Control Area (formerly transport)
    @State var controlButtons: [ControlButton] = []
    @State var controlEditMode = false
    @State var controlAreaCollapsed: Bool = false  // Track if control area is collapsed
    @State var currentControlPage: Int = 0  // Current page (0-3) for multi-page control area
    @State var controlsPerRow: Int = 4
    @State var controlAreaHeight: CGFloat = 0
    @State var showCollapsedCapsule: Bool = false  // Control visibility for sequential animation
    @State var showExpandedArea: Bool = false  // Control visibility for sequential animation
    @State var isAnimatingControlArea: Bool = false  // Track if control area is animating
    @State var controlSectionReady: Bool = false  // PERFORMANCE: Delay CBControlSection creation until after initial layout
    @State var titleBarBottom: CGFloat = 88  // Bottom edge of title bar (default: safe area + title height)
    @State var editCapsuleBottom: CGFloat = 0  // Bottom edge of edit/search capsules when visible
    @State var capsuleBounds: [String: CGRect] = [:]  // Track all UI capsule bounds for collision detection
    @State var canAddMoreControlsToGrid: Bool = true  // Track if grid has space for new controls
    @State var controlEditModeTimer: Timer? = nil  // Auto-exit timer for edit mode
    @State var showControlEditor: Bool = false
    @State var editingControl: ControlButton? = nil
    @State var showEditControlSheet: Bool = false
    @State var editingControlForEdit: ControlButton? = nil
    @State var showMidiTable: Bool = false
    @State var flashNewFormControl: Bool = false  // Visual feedback for "Save & Add Another" in control editor

    // Notification subscriptions (to prevent memory leaks)
    @State var notificationCancellables: Set<AnyCancellable> = []

    // Global MIDI Channel
    @State var isGlobalChannel: Bool = false
    @State var globalChannel: Int = 1
    // Backup of original channels before enabling global mode
    @State var savedSongChannels: [UUID: Int] = [:]
    @State var savedControlChannels: [UUID: Int] = [:]
    // Flag to prevent backup/restore during project loading
    @State var isLoadingProject: Bool = false

    // MIDI Filter - persisted globally via UserDefaults (not per-project)
    @AppStorage("midiFiltersEnabled") var midiFiltersEnabled: Bool = true
    @State var midiFilter: Set<Int> = [1, 7, 10, 11, 64, 120, 121, 122, 123, 124, 125, 126, 127]
    @State var customMidiFilters: [(Int, String)] = []

    // Undo/Redo
    @State var setlistUndoStack: [[Song]] = []
    @State var setlistRedoStack: [[Song]] = []
    @State var libraryUndoStack: [[Song]] = []
    @State var libraryRedoStack: [[Song]] = []
    @State var controlUndoStack: [[ControlButton]] = []
    @State var controlRedoStack: [[ControlButton]] = []

    // Misc
    @State var autosaveTask: Task<Void, Never>? = nil
    // FIX #4: Replace task-based autosave with DispatchWorkItem
    @State var autosaveWorkItem: DispatchWorkItem? = nil
    @State var showAddEditMIDIOnly = false
    @State var pendingAddIsFader: Bool? = nil
    @State var isTyping: Bool = false
    @State var flashingCueID: UUID? = nil  // Tracks which cue should flash

    // Side Menu
    @State var showSideMenu = false
    @State var modeChangeWorkItem: DispatchWorkItem?
    @State var showAboutSheet = false
    @State var showAppearanceSheet = false
    @State var showAppearanceSettingsSheet = false
    #if DEBUG
    @State var showAdminPanel = false
    @State var adminPanelPressTimer: Timer? = nil
    @State var adminPanelPressCount = 0
    #endif

    // Theme
    @AppStorage("selectedThemeID") var selectedThemeID: String = "default"
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass
    var currentTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // Effective default cue color (custom overrides theme default)
    var effectiveDefaultCueColorHex: String {
        customDefaultCueColorStorage.isEmpty ? currentTheme.defaultCueColorHexValue(for: colorScheme) : customDefaultCueColorStorage
    }

    // Appearance Settings
    @AppStorage("showMIDIData") var showMIDIData: Bool = true
    @AppStorage("cueHeight") var cueHeight: Double = 110
    @AppStorage("navigationPillSize") var navigationPillSize: Double = 0.85
    @AppStorage("cueCapsuleSize") var cueCapsuleSize: Double = 0.85
    @AppStorage("fontSize") var fontSize: Double = 1.0
    @AppStorage("customDefaultCueColor") var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignCueColors") var autoAssignCueColors: Bool = true
    @AppStorage("autoAssignControlColors") var autoAssignControlColors: Bool = true

    // Performance caches
    @State var cachedConflictLookup: [MIDIKey: String] = [:]
    @State var cacheVersion: Int = 0
    @State var cachedUsedCCs: Set<Int> = []
    // FIX #5: Conflict cache throttling
    @State var conflictCacheUpdateScheduled = false

    // Control Area constraints
    let maxControlRows: Int = 5

    

    // Visuals
    var connectionTint: Color { connectionCoordinator.activeConnection != .none ? .green : .red }
    // activeIsUSB removed - now handled by ConnectionCoordinator

    // Break up body for compiler
    var topBarView: some View {
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
    var filteredActiveSongs: [Song] {
        if setlistQuery.isEmpty {
            return store.activeSongs
        }
        return store.activeSongs.filter { song in
            song.name.localizedCaseInsensitiveContains(setlistQuery)
        }
    }

    @ViewBuilder func buildMiddleSectionView() -> some View {
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

    var effectivelyCollapsedForOverlay: Bool {
        return controlAreaCollapsed || (controlButtons.isEmpty && !controlEditMode)
    }

    // State for controls capsule press animation (can't use ButtonStyle due to GeometryReader conflicts)
    @State var controlsCapsulePressed: Bool = false

    var collapsedControlCapsule: some View {
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

    var controlSectionView: some View {
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
    func setupNotificationSubscriptions() {
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
