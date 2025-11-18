# Multiple Cue Lists Implementation Plan v2.0

**Version:** 1.2.0
**Platform:** iPad + iPhone
**Date:** 2025-01-16
**Status:** Ready for Implementation

---

## Overview

Transform Cue Bear from single setlist per project to multiple named cue lists, allowing users to organize songs into different scenarios (e.g., "Main Show", "Rehearsal", "Backup").

**Key Design Principle:** One shared song library, multiple independent cue lists.

---

## Table of Contents

1. [Architecture Decisions](#1-architecture-decisions)
2. [Data Model Changes](#2-data-model-changes)
3. [State Management](#3-state-management)
4. [Migration Strategy](#4-migration-strategy)
5. [UI/UX Design](#5-uiux-design)
6. [Undo/Redo System](#6-undoredo-system)
7. [Implementation Phases](#7-implementation-phases)
8. [Testing Strategy](#8-testing-strategy)
9. [Rollback Plan](#9-rollback-plan)
10. [Future Enhancements](#10-future-enhancements)

---

## 1. Architecture Decisions

### 1.1 Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Undo/Redo** | Clear stack on cue list switch | Simpler for v1.2.0, prevents cross-list confusion |
| **Global Channel** | Apply to active list only | More intuitive, allows different lists for different needs |
| **MIDI Conflicts** | Per-list detection + cross-list warnings | Balance flexibility with safety |
| **Library Indicator** | Multi-status (in this list / in other lists / not added) | Clearer user feedback |
| **Feature Flag** | Yes, with AppStorage | Allows quick rollback if needed |
| **Version Number** | 1.2.0 | Minor version - new feature, backward compatible |

### 1.2 Design Principles

1. **No Breaking Changes**: v1.1.0 projects must load seamlessly
2. **Library Independence**: Song library remains shared across all cue lists
3. **Instance Model**: Cue list songs are instances of library songs (changes independent)
4. **Single Source of Truth**: `store.cueLists` is the only data source (no legacy `setlist`)
5. **Fail-Safe**: If migration fails, fall back to single "Main" cue list

---

## 2. Data Model Changes

### 2.1 New CueList Struct

```swift
/// A named collection of songs (cues) within a project.
///
/// Design:
/// - Each project can have multiple cue lists (e.g., "Main Show", "Rehearsal")
/// - Songs in a cue list are instances drawn from the shared library
/// - Each instance can have different MIDI settings than the library template
///
/// Example:
/// ```
/// let mainList = CueList(name: "Main Show", songs: [song1, song2])
/// let rehearsal = CueList(name: "Rehearsal", songs: [song1])
/// ```
public struct CueList: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var songs: [Song]
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        songs: [Song] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.songs = songs
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Update modification timestamp
    public mutating func touch() {
        self.modifiedAt = Date()
    }

    /// Quick validation
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Presets
extension CueList {
    /// Default cue list for new projects
    static var defaultMain: CueList {
        CueList(name: "Main", songs: [])
    }

    /// Common preset templates
    static var templates: [CueList] {
        [
            CueList(name: "Main Show", songs: []),
            CueList(name: "Rehearsal", songs: []),
            CueList(name: "Backup", songs: []),
            CueList(name: "Soundcheck", songs: [])
        ]
    }
}
```

**Location:** Add to `Models/CueList.swift` (new file)

### 2.2 ProjectPayload Changes

```swift
struct ProjectPayload: Codable {
    // New format (v1.2.0+)
    var cueLists: [CueList]?
    var activeCueListID: UUID?

    // Legacy format (v1.0.x - v1.1.x) - for loading only
    var setlist: Setlist?

    var songLibrary: [Song]
    var controlButtons: [ControlButton]
    var globalChannel: Int?
    var isGlobalChannelEnabled: Bool?
    var theme: String?
    var projectVersion: String?  // Track format version

    enum CodingKeys: String, CodingKey {
        case cueLists
        case activeCueListID
        case setlist
        case songLibrary
        case controlButtons
        case globalChannel
        case isGlobalChannelEnabled
        case theme
        case projectVersion
    }
}
```

**Location:** Modify existing `ProjectPayload` in ContentView.swift (search for `struct ProjectPayload`)

---

## 3. State Management

### 3.1 Complete SetlistStore Rewrite

**CRITICAL:** Remove all legacy `setlist` code. No dual-state.

```swift
import SwiftUI
import Combine

final class SetlistStore: ObservableObject {
    // MARK: - Published State

    /// All cue lists in the project
    @Published var cueLists: [CueList] = []

    /// ID of the currently active cue list
    @Published var activeCueListID: UUID?

    /// App mode (regular, cue mode, etc.)
    @Published var mode: AppMode = .regular

    /// Currently cued song (in cue mode)
    @Published var cuedSong: Song? = nil

    /// Scroll lock state
    @Published var scrollLock: Bool = false

    // MARK: - Computed Properties

    /// Active cue list (computed, not stored)
    var activeCueList: CueList? {
        guard let id = activeCueListID else { return cueLists.first }
        return cueLists.first(where: { $0.id == id })
    }

    /// Active cue list songs (read-only)
    var activeSongs: [Song] {
        activeCueList?.songs ?? []
    }

    /// Index of active cue list (cached for performance)
    private(set) var activeIndex: Int? {
        get {
            guard let id = activeCueListID else { return nil }
            return cueLists.firstIndex(where: { $0.id == id })
        }
        set { /* read-only */ }
    }

    // MARK: - Initialization

    init() {
        // Start with default "Main" cue list
        let defaultList = CueList.defaultMain
        self.cueLists = [defaultList]
        self.activeCueListID = defaultList.id
    }

    // MARK: - Mutation Helpers

    /// Update the active cue list safely
    func updateActiveCueList(_ update: (inout CueList) -> Void) {
        guard let id = activeCueListID,
              let index = cueLists.firstIndex(where: { $0.id == id }) else {
            return
        }
        update(&cueLists[index])
        cueLists[index].touch()  // Update timestamp
    }

    /// Update songs in active cue list
    func updateActiveSongs(_ update: (inout [Song]) -> Void) {
        updateActiveCueList { cueList in
            update(&cueList.songs)
        }
    }

    /// Switch to a different cue list
    func switchToCueList(_ cueListID: UUID) {
        guard cueLists.contains(where: { $0.id == cueListID }) else {
            return
        }
        activeCueListID = cueListID
    }

    /// Create a new cue list
    func createCueList(name: String) -> UUID {
        let newList = CueList(name: name, songs: [])
        cueLists.append(newList)
        return newList.id
    }

    /// Delete a cue list (must have at least one remaining)
    func deleteCueList(_ cueListID: UUID) {
        guard cueLists.count > 1 else { return }  // Keep at least one

        // If deleting active list, switch to another first
        if activeCueListID == cueListID {
            let remainingList = cueLists.first(where: { $0.id != cueListID })
            activeCueListID = remainingList?.id
        }

        cueLists.removeAll(where: { $0.id == cueListID })
    }

    /// Rename a cue list
    func renameCueList(_ cueListID: UUID, to newName: String) {
        guard let index = cueLists.firstIndex(where: { $0.id == cueListID }) else {
            return
        }
        cueLists[index].name = newName
        cueLists[index].touch()
    }

    /// Duplicate a cue list
    func duplicateCueList(_ cueListID: UUID) -> UUID? {
        guard let original = cueLists.first(where: { $0.id == cueListID }) else {
            return nil
        }

        let copy = CueList(
            name: "\(original.name) Copy",
            songs: original.songs.map { song in
                var newSong = song
                newSong.id = UUID()  // New ID for the copy
                return newSong
            }
        )

        cueLists.append(copy)
        return copy.id
    }
}

// MARK: - AppMode
enum AppMode: String, Codable {
    case regular
    case cue
}
```

**Location:** Replace entire `SetListStore.swift` file

**IMPORTANT:** This completely removes:
- `@Published var setlist: Setlist`
- Auto-save Combine pipeline (lines 19-22 in old file)
- All legacy setlist references

### 3.2 ContentView State Changes

```swift
// MARK: - State Variables (in ContentView)

// Cue list management
@State private var showCueListSwitcher = false
@State private var showCueListEditor = false
@State private var editingCueList: CueList? = nil
@State private var showDeleteCueListConfirmation = false
@State private var cueListToDelete: CueList? = nil
@State private var cueListNameDraft: String = ""

// Undo/Redo (cleared on cue list switch)
@State private var undoStack: [CueListSnapshot] = []
@State private var redoStack: [CueListSnapshot] = []

// Snapshot for undo/redo
struct CueListSnapshot {
    let cueListID: UUID
    let songs: [Song]
    let timestamp: Date
}
```

**Location:** Add to ContentView state variables section (search for `@State private var showConnections`)

---

## 4. Migration Strategy

### 4.1 Loading Projects

```swift
private func loadProjectFromURL(_ url: URL) {
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ProjectPayload.self, from: data)

        // Detect format version
        let isLegacyFormat = (payload.cueLists == nil && payload.setlist != nil)

        if isLegacyFormat {
            // Migrate from v1.1.0 or earlier
            migrateFromLegacyFormat(payload)
        } else {
            // Load modern format (v1.2.0+)
            loadModernFormat(payload)
        }

        currentProjectURL = url
        projectTitle = url.deletingPathExtension().lastPathComponent

    } catch {
        showError("Failed to load project: \(error.localizedDescription)")
    }
}

private func migrateFromLegacyFormat(_ payload: ProjectPayload) {
    // Convert old setlist to "Main" cue list
    if let legacySetlist = payload.setlist {
        let mainList = CueList(
            name: "Main",
            songs: legacySetlist.songs
        )
        store.cueLists = [mainList]
        store.activeCueListID = mainList.id
    } else {
        // Empty project
        let emptyList = CueList.defaultMain
        store.cueLists = [emptyList]
        store.activeCueListID = emptyList.id
    }

    // Load other data
    songLibrary = payload.songLibrary
    controlButtons = payload.controlButtons
    globalChannel = payload.globalChannel ?? 1
    isGlobalChannelEnabled = payload.isGlobalChannelEnabled ?? false

    // Apply theme if present
    if let themeIdentifier = payload.theme {
        applyTheme(identifier: themeIdentifier)
    }

    // Log migration for analytics
    debugPrint("📦 Migrated legacy project to v1.2.0 format")
}

private func loadModernFormat(_ payload: ProjectPayload) {
    // Load cue lists
    store.cueLists = payload.cueLists ?? [CueList.defaultMain]

    // Validate active ID
    if let activeID = payload.activeCueListID,
       store.cueLists.contains(where: { $0.id == activeID }) {
        store.activeCueListID = activeID
    } else {
        // Fallback to first list
        store.activeCueListID = store.cueLists.first?.id
    }

    // Load other data
    songLibrary = payload.songLibrary
    controlButtons = payload.controlButtons
    globalChannel = payload.globalChannel ?? 1
    isGlobalChannelEnabled = payload.isGlobalChannelEnabled ?? false

    // Apply theme if present
    if let themeIdentifier = payload.theme {
        applyTheme(identifier: themeIdentifier)
    }

    debugPrint("📦 Loaded v1.2.0 project with \(store.cueLists.count) cue lists")
}
```

**Location:** Replace existing `loadProjectFromURL` function in ContentView.swift

### 4.2 Saving Projects

```swift
private func saveCurrentProject() {
    guard let url = currentProjectURL else {
        debugPrint("❌ No project URL to save to")
        return
    }

    let payload = ProjectPayload(
        cueLists: store.cueLists,
        activeCueListID: store.activeCueListID,
        setlist: nil,  // Don't save legacy format
        songLibrary: songLibrary,
        controlButtons: controlButtons,
        globalChannel: globalChannel,
        isGlobalChannelEnabled: isGlobalChannelEnabled,
        theme: currentTheme.identifier,
        projectVersion: "1.2.0"
    )

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
        debugPrint("💾 Saved project with \(store.cueLists.count) cue lists")
    } catch {
        debugPrint("❌ Failed to save project: \(error)")
        showError("Failed to save project: \(error.localizedDescription)")
    }
}
```

**Location:** Replace existing `saveCurrentProject` function in ContentView.swift

### 4.3 Migration Testing

Create these test files before implementation:

```
Test_Projects/
├── legacy_v1.0_empty.json          (v1.0 with no songs)
├── legacy_v1.0_small.json          (v1.0 with 5 songs)
├── legacy_v1.1_large.json          (v1.1 with 100 songs)
├── legacy_v1.1_complex.json        (v1.1 with MIDI, controls, theme)
├── corrupted_missing_setlist.json  (missing setlist field)
└── modern_v1.2_multi.json          (v1.2 with 3 cue lists)
```

---

## 5. UI/UX Design

### 5.1 Title Bar Updates

**Current:** `[Project Name]`
**New:** `[Project Name] - [Active Cue List]`

```swift
private var titleBarView: some View {
    HStack {
        // Project name
        Text(projectTitle)
            .font(.headline)
            .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))

        // Separator (only if multiple cue lists)
        if store.cueLists.count > 1 {
            Text("-")
                .foregroundColor(currentTheme.secondaryTextColor(for: colorScheme))

            // Cue list selector button
            Button(action: {
                showCueListSwitcher = true
            }) {
                HStack(spacing: 4) {
                    Text(store.activeCueList?.name ?? "Main")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(currentTheme.defaultCueColor(for: colorScheme))
            }
        }
    }
}
```

### 5.2 Cue List Switcher (Modal Sheet - iPad)

```swift
.sheet(isPresented: $showCueListSwitcher) {
    NavigationView {
        List {
            ForEach(store.cueLists) { cueList in
                Button(action: {
                    switchToCueList(cueList.id)
                    showCueListSwitcher = false
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cueList.name)
                                .font(.headline)
                                .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))

                            Text("\(cueList.songs.count) songs")
                                .font(.caption)
                                .foregroundColor(currentTheme.secondaryTextColor(for: colorScheme))
                        }

                        Spacer()

                        // Active indicator
                        if cueList.id == store.activeCueListID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(currentTheme.defaultCueColor(for: colorScheme))
                        }

                        // Warning badge for cross-list conflicts
                        if let conflictCount = crossListConflicts[cueList.id], conflictCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("\(conflictCount)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Delete (only if more than 1 list)
                    if store.cueLists.count > 1 {
                        Button(role: .destructive) {
                            cueListToDelete = cueList
                            showDeleteCueListConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    // Rename
                    Button {
                        editingCueList = cueList
                        cueListNameDraft = cueList.name
                        showCueListEditor = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)

                    // Duplicate
                    Button {
                        if let newID = store.duplicateCueList(cueList.id) {
                            store.switchToCueList(newID)
                            showCueListSwitcher = false
                        }
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(.green)
                }
            }
        }
        .navigationTitle("Cue Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    showCueListSwitcher = false
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingCueList = nil
                    cueListNameDraft = "New Cue List"
                    showCueListEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
    .presentationDetents([.medium, .large])
}
```

### 5.3 Cue List Editor (Rename/Create)

```swift
.sheet(isPresented: $showCueListEditor) {
    NavigationView {
        Form {
            Section {
                TextField("Cue List Name", text: $cueListNameDraft)
                    .autocapitalization(.words)
            }

            // Optional: Template selection for new lists
            if editingCueList == nil {
                Section("Start With Template") {
                    ForEach(CueList.templates, id: \.name) { template in
                        Button(template.name) {
                            cueListNameDraft = template.name
                        }
                    }
                }
            }
        }
        .navigationTitle(editingCueList == nil ? "New Cue List" : "Rename Cue List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showCueListEditor = false
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveCueListEdit()
                }
                .disabled(cueListNameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    .presentationDetents([.height(280)])
}

private func saveCueListEdit() {
    let trimmedName = cueListNameDraft.trimmingCharacters(in: .whitespaces)
    guard !trimmedName.isEmpty else { return }

    if let editing = editingCueList {
        // Rename existing
        store.renameCueList(editing.id, to: trimmedName)
    } else {
        // Create new
        let newID = store.createCueList(name: trimmedName)
        store.switchToCueList(newID)
    }

    showCueListEditor = false
    saveCurrentProject()
}
```

### 5.4 Delete Confirmation Alert

```swift
.alert("Delete Cue List?", isPresented: $showDeleteCueListConfirmation) {
    Button("Delete", role: .destructive) {
        if let list = cueListToDelete {
            deleteCueList(list)
        }
    }
    Button("Cancel", role: .cancel) {
        cueListToDelete = nil
    }
} message: {
    if let list = cueListToDelete {
        Text("This will permanently delete \"\(list.name)\" and its \(list.songs.count) song(s).")
    }
}

private func deleteCueList(_ cueList: CueList) {
    // Clear undo stack (since we're changing structure)
    undoStack.removeAll()
    redoStack.removeAll()

    // Delete the list
    store.deleteCueList(cueList.id)

    // Save
    saveCurrentProject()

    cueListToDelete = nil
}
```

### 5.5 iPhone Edit Mode Updates

For iPhone, update the modal view picker to show cue list selector:

```swift
// In the iPhone edit mode sheet (existing from previous work)
.sheet(isPresented: $showEditModeViewPicker) {
    VStack(spacing: 0) {
        // Sheet header
        HStack {
            Spacer()
            Text("Switch View")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(currentTheme.titleBarColor(for: colorScheme))

        // Add cue list selector at top (if multiple lists)
        if store.cueLists.count > 1 {
            Section {
                Picker("Cue List", selection: $store.activeCueListID) {
                    ForEach(store.cueLists) { cueList in
                        Text(cueList.name).tag(cueList.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()
        }

        // View options (Library / Cue List)
        VStack(spacing: 0) {
            // ... existing Library/Cue List buttons ...
        }

        Spacer()
    }
    .presentationDetents([.height(store.cueLists.count > 1 ? 280 : 200)])
    .presentationDragIndicator(.visible)
}
```

### 5.6 Library "In Setlist" Indicator Updates

Update the library view to show multi-status:

```swift
private func inSetlistStatus(for song: Song) -> SetlistStatus {
    var listsContaining: [String] = []

    for cueList in store.cueLists {
        if cueList.songs.contains(where: { $0.id == song.id }) {
            listsContaining.append(cueList.name)
        }
    }

    if listsContaining.isEmpty {
        return .notInAny
    } else if listsContaining.contains(store.activeCueList?.name ?? "") {
        return .inActiveList(otherLists: listsContaining.count - 1)
    } else {
        return .inOtherLists(count: listsContaining.count, names: listsContaining)
    }
}

enum SetlistStatus {
    case notInAny
    case inActiveList(otherLists: Int)  // Also in X other lists
    case inOtherLists(count: Int, names: [String])
}

// In library row view:
HStack {
    // ... song info ...

    Spacer()

    switch inSetlistStatus(for: song) {
    case .notInAny:
        Image(systemName: "plus.circle")
            .foregroundColor(.gray)

    case .inActiveList(let otherCount):
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            if otherCount > 0 {
                Text("+\(otherCount)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }

    case .inOtherLists(let count, _):
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.gray)
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}
```

### 5.7 Empty State Handling

```swift
private var emptyStateView: some View {
    VStack(spacing: 16) {
        Image(systemName: "music.note.list")
            .font(.system(size: 60))
            .foregroundColor(.gray)

        if store.cueLists.count > 1 && store.activeSongs.isEmpty {
            // Active list is empty but other lists have songs
            Text("This cue list is empty")
                .font(.title2)
                .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))

            Text("Switch to another list or add songs from the library")
                .font(.body)
                .foregroundColor(currentTheme.secondaryTextColor(for: colorScheme))
                .multilineTextAlignment(.center)

            Button("Switch Cue List") {
                showCueListSwitcher = true
            }
            .buttonStyle(.borderedProminent)
        } else {
            // First cue list or all lists empty
            Text("Add your first cue")
                .font(.title2)
                .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))

            Text("Tap the edit button, then + to add songs")
                .font(.body)
                .foregroundColor(currentTheme.secondaryTextColor(for: colorScheme))
                .multilineTextAlignment(.center)
        }
    }
    .padding(40)
}
```

---

## 6. Undo/Redo System

### 6.1 Strategy: Clear Stack on Switch

**Decision:** For v1.2.0, clear undo/redo stacks when switching cue lists.

**Rationale:**
- Simpler to implement
- Clear user expectations
- Prevents cross-list confusion
- Can upgrade to per-list stacks in v1.3.0 if needed

### 6.2 Implementation

```swift
// Snapshot structure
struct CueListSnapshot {
    let cueListID: UUID
    let songs: [Song]
    let timestamp: Date
}

// Push undo
private func pushUndo() {
    guard let activeList = store.activeCueList else { return }

    let snapshot = CueListSnapshot(
        cueListID: activeList.id,
        songs: activeList.songs,
        timestamp: Date()
    )

    undoStack.append(snapshot)
    redoStack.removeAll()  // Clear redo on new action

    // Limit stack size
    if undoStack.count > 50 {
        undoStack.removeFirst()
    }
}

// Undo
private func performUndo() {
    guard let snapshot = undoStack.popLast() else { return }

    // Save current state to redo stack
    if let currentList = store.activeCueList {
        let redoSnapshot = CueListSnapshot(
            cueListID: currentList.id,
            songs: currentList.songs,
            timestamp: Date()
        )
        redoStack.append(redoSnapshot)
    }

    // Restore snapshot
    store.updateActiveCueList { cueList in
        cueList.songs = snapshot.songs
    }

    saveCurrentProject()
}

// Redo
private func performRedo() {
    guard let snapshot = redoStack.popLast() else { return }

    // Save current state to undo stack
    pushUndo()

    // Restore snapshot
    store.updateActiveCueList { cueList in
        cueList.songs = snapshot.songs
    }

    saveCurrentProject()
}

// Switch cue list (clears stacks)
private func switchToCueList(_ cueListID: UUID) {
    guard cueListID != store.activeCueListID else { return }

    // Clear undo/redo to prevent confusion
    undoStack.removeAll()
    redoStack.removeAll()

    // Switch
    store.switchToCueList(cueListID)

    // No auto-save on switch (save happens on edit)
}
```

### 6.3 Update All Mutation Points

Find all places that modify `store.setlist.songs` and replace with:

```swift
// Before
store.setlist.songs.append(newSong)

// After
pushUndo()
store.updateActiveSongs { songs in
    songs.append(newSong)
}
saveCurrentProject()
```

**Search pattern:** `store\.setlist\.songs` (regex)
**Expected matches:** ~70-80 occurrences

---

## 7. Implementation Phases

### Phase 0: Preparation (1 hour)

**Goal:** Set up infrastructure and backups

**Tasks:**
1. ✅ Create feature branch: `git checkout -b feature/multiple-cue-lists`
2. ✅ Verify current branch is v1.2.0 base
3. Create test project files (6 files in Test_Projects/)
4. Add unit test infrastructure:
   ```swift
   // Tests/CueListTests.swift
   import XCTest
   @testable import Cue_Bear

   class CueListTests: XCTestCase {
       func testDefaultCueList() {
           let list = CueList.defaultMain
           XCTAssertEqual(list.name, "Main")
           XCTAssertTrue(list.songs.isEmpty)
       }

       func testCueListValidation() {
           let valid = CueList(name: "Test", songs: [])
           XCTAssertTrue(valid.isValid)

           let invalid = CueList(name: "   ", songs: [])
           XCTAssertFalse(invalid.isValid)
       }
   }
   ```
5. Document current code locations (create `MIGRATION_NOTES.md`)
6. Backup current ContentView.swift: `cp ContentView.swift ContentView.swift.backup`

**Validation:**
- Feature branch created
- Test files prepared
- Backup created

---

### Phase 1: Data Models (1 hour)

**Goal:** Add CueList struct and update ProjectPayload

**Tasks:**
1. Create `Models/CueList.swift` with full implementation (Section 2.1)
2. Update `ProjectPayload` struct (Section 2.2)
3. Add to Xcode project
4. Build and fix any compilation errors

**Files Modified:**
- `Models/CueList.swift` (new)
- `ContentView.swift` (ProjectPayload struct)

**Validation:**
- Project builds successfully
- No compiler errors
- CueList is Codable and Identifiable

---

### Phase 2: State Management (1.5 hours)

**Goal:** Rewrite SetlistStore completely

**Tasks:**
1. **CRITICAL:** Back up SetListStore.swift: `cp SetListStore.swift SetListStore.swift.backup`
2. Replace entire SetListStore.swift with new implementation (Section 3.1)
3. Add ContentView state variables (Section 3.2)
4. Add `@StateObject private var store = SetlistStore()` (if not already present)
5. Build and fix errors

**Files Modified:**
- `SetListStore.swift` (complete rewrite)
- `ContentView.swift` (add state variables)

**Validation:**
- Project builds
- No references to old `store.setlist`
- Store initializes with default "Main" cue list

**Expected Errors:**
- Many errors from `store.setlist.songs` references
- This is expected - will fix in Phase 4

---

### Phase 2.5: Accessibility (30 minutes)

**Goal:** Add accessibility support for new UI elements

**Tasks:**
1. Add VoiceOver labels to cue list switcher
2. Add accessibility identifiers for UI testing
3. Test with VoiceOver enabled
4. Test with largest Dynamic Type size

**Code Example:**
```swift
Button(action: { showCueListSwitcher = true }) {
    // ...
}
.accessibilityLabel("Switch cue list")
.accessibilityHint("Opens cue list selector")
.accessibilityIdentifier("cueListSwitcherButton")
```

**Validation:**
- All new buttons have accessibility labels
- VoiceOver reads UI correctly
- UI works with large text sizes

---

### Phase 3: UI Components (2 hours)

**Goal:** Build all new UI elements

**Tasks:**
1. Update title bar to show cue list name (Section 5.1)
2. Create cue list switcher sheet (Section 5.2)
3. Create cue list editor sheet (Section 5.3)
4. Add delete confirmation alert (Section 5.4)
5. Update iPhone edit mode picker (Section 5.5)
6. Add empty state view (Section 5.7)
7. Test all UI interactions

**Files Modified:**
- `ContentView.swift` (add all UI views)

**Validation:**
- All sheets present correctly
- Buttons trigger correct actions
- Alerts show proper messages
- iPhone and iPad UIs work

---

### Phase 3.5: Undo/Redo (1 hour)

**Goal:** Implement clear-on-switch undo/redo

**Tasks:**
1. Add snapshot structure (Section 6.2)
2. Implement `pushUndo()`, `performUndo()`, `performRedo()`
3. Update `switchToCueList()` to clear stacks
4. Add undo/redo buttons to UI (already exist, just wire up)
5. Test undo/redo within single list
6. Test that switching clears stacks

**Files Modified:**
- `ContentView.swift` (undo/redo functions)

**Validation:**
- Undo works within a cue list
- Redo works within a cue list
- Stacks clear on switch
- Undo limit (50) works

---

### Phase 4: Data Access Migration (3 hours)

**Goal:** Replace all `store.setlist.songs` with new accessors

**Tasks:**
1. Find all occurrences: Search `store\.setlist\.songs` (regex)
2. For each occurrence, determine if it's:
   - Read-only: Use `store.activeSongs`
   - Mutation: Use `store.updateActiveSongs { }`
3. Add `pushUndo()` before mutations
4. Add `saveCurrentProject()` after mutations
5. Build and test after every 10 replacements

**Strategy:**
```swift
// Pattern 1: Read-only
let count = store.setlist.songs.count
// Replace with:
let count = store.activeSongs.count

// Pattern 2: Simple mutation
store.setlist.songs.append(newSong)
// Replace with:
pushUndo()
store.updateActiveSongs { songs in
    songs.append(newSong)
}
saveCurrentProject()

// Pattern 3: Complex mutation
store.setlist.songs[index].name = "New Name"
// Replace with:
pushUndo()
store.updateActiveSongs { songs in
    songs[index].name = "New Name"
}
saveCurrentProject()

// Pattern 4: Move
store.setlist.songs.move(fromOffsets: indices, toOffset: offset)
// Replace with:
pushUndo()
store.updateActiveSongs { songs in
    songs.move(fromOffsets: indices, toOffset: offset)
}
saveCurrentProject()
```

**Files Modified:**
- `ContentView.swift` (~70-80 replacements)
- `ControlSubviews.swift` (if any references)

**Validation:**
- Project builds with no errors
- All mutations work
- Undo/redo captures changes

---

### Phase 5: Save/Load Implementation (1.5 hours)

**Goal:** Implement migration and saving

**Tasks:**
1. Implement `loadProjectFromURL()` with migration (Section 4.1)
2. Implement `migrateFromLegacyFormat()` (Section 4.1)
3. Implement `loadModernFormat()` (Section 4.1)
4. Update `saveCurrentProject()` (Section 4.2)
5. Test loading each test project file
6. Test saving and reloading

**Files Modified:**
- `ContentView.swift` (save/load functions)

**Test Scenarios:**
- Load legacy v1.0 project → migrates to "Main"
- Load legacy v1.1 project → migrates to "Main"
- Load v1.2 project → loads all cue lists
- Save v1.2 project → saves correctly
- Load saved project → matches original

**Validation:**
- All test files load successfully
- Migration preserves all data
- Saved files can be reloaded
- No data loss

---

### Phase 6: Comprehensive Testing (4 hours)

**Goal:** Test all features and edge cases

#### 6.1 Migration Testing (1 hour)
- [ ] Load each test project file
- [ ] Verify song count matches
- [ ] Verify MIDI settings preserved
- [ ] Verify control buttons preserved
- [ ] Verify theme applied correctly
- [ ] Test corrupted file handling

#### 6.2 Cue List Management (1 hour)
- [ ] Create new cue list
- [ ] Rename cue list
- [ ] Delete cue list (with confirmation)
- [ ] Duplicate cue list
- [ ] Switch between cue lists
- [ ] Verify undo clears on switch

#### 6.3 Song Operations (1 hour)
- [ ] Add song from library to active list
- [ ] Remove song from active list
- [ ] Reorder songs in active list
- [ ] Edit song in active list
- [ ] Duplicate song in active list
- [ ] Verify library "in setlist" indicator
- [ ] Verify changes don't affect other lists

#### 6.4 Edge Cases (1 hour)
- [ ] Delete last cue list (should prevent)
- [ ] Switch to non-existent list (should fallback)
- [ ] Create list with empty name (should prevent)
- [ ] Create 20 cue lists (performance test)
- [ ] Undo with empty stack (should do nothing)
- [ ] Redo with empty stack (should do nothing)
- [ ] Global channel with multiple lists
- [ ] Cue mode with multiple lists
- [ ] Save while switching lists
- [ ] Load project with invalid active ID

#### 6.5 UI Testing
- [ ] iPad: Cue list switcher sheet
- [ ] iPad: Cue list editor sheet
- [ ] iPad: Delete confirmation alert
- [ ] iPhone: View picker with cue list selector
- [ ] iPhone: All edit mode functions
- [ ] Empty state view (all variants)
- [ ] Title bar cue list name
- [ ] Cross-list conflict warnings

#### 6.6 Integration Testing
- [ ] Create project → Add lists → Save → Close → Reopen
- [ ] Edit multiple lists → Switch between → Verify independence
- [ ] Trigger cues from different lists
- [ ] Use global channel across lists
- [ ] Undo/redo across multiple operations
- [ ] Delete list while in cue mode

**Validation Checklist:**
- ✅ All test cases pass
- ✅ No crashes or errors
- ✅ Data integrity maintained
- ✅ UI responsive and intuitive

---

### Phase 7: Documentation (30 minutes)

**Goal:** Update user-facing documentation

**Tasks:**
1. Update README.md with multiple cue lists feature
2. Add "What's New in v1.2.0" section
3. Create migration guide for v1.1.0 users
4. Update screenshots if needed

**Files Modified:**
- `README.md`
- `CHANGELOG.md`
- `MIGRATION_GUIDE.md` (new)

---

## 8. Testing Strategy

### 8.1 Unit Tests

```swift
// Tests/CueListTests.swift
class CueListTests: XCTestCase {
    func testCreateCueList() { }
    func testRenameCueList() { }
    func testDeleteCueList() { }
    func testDuplicateCueList() { }
    func testSwitchCueList() { }
    func testUpdateActiveSongs() { }
}

// Tests/MigrationTests.swift
class MigrationTests: XCTestCase {
    func testMigrateV1_0() { }
    func testMigrateV1_1() { }
    func testLoadV1_2() { }
    func testCorruptedProject() { }
}

// Tests/UndoRedoTests.swift
class UndoRedoTests: XCTestCase {
    func testUndo() { }
    func testRedo() { }
    func testUndoStackLimit() { }
    func testClearOnSwitch() { }
}
```

### 8.2 Integration Tests

```swift
// Tests/IntegrationTests.swift
class IntegrationTests: XCTestCase {
    func testFullWorkflow() {
        // 1. Create project
        // 2. Add cue lists
        // 3. Add songs
        // 4. Switch lists
        // 5. Save
        // 6. Reload
        // 7. Verify
    }
}
```

### 8.3 Manual Testing Checklist

Copy to `TESTING_CHECKLIST.md`:

```markdown
# Multiple Cue Lists Testing Checklist

## Migration
- [ ] Load v1.0 empty project
- [ ] Load v1.0 small project (5 songs)
- [ ] Load v1.1 large project (100 songs)
- [ ] Load v1.1 complex project (MIDI, controls, theme)
- [ ] Load corrupted project (missing fields)
- [ ] Load v1.2 multi-list project

## Cue List Management
- [ ] Create new cue list
- [ ] Rename cue list (valid name)
- [ ] Rename cue list (empty name - should prevent)
- [ ] Delete cue list (with confirmation)
- [ ] Delete last cue list (should prevent)
- [ ] Duplicate cue list
- [ ] Switch between cue lists
- [ ] Create 20 cue lists (performance)

## Song Operations
- [ ] Add song from library
- [ ] Remove song from cue list
- [ ] Reorder songs
- [ ] Edit song properties
- [ ] Duplicate song
- [ ] Delete song
- [ ] Move song (drag & drop)

## Undo/Redo
- [ ] Undo add song
- [ ] Undo remove song
- [ ] Undo reorder
- [ ] Undo edit
- [ ] Redo all above
- [ ] Verify stack clears on switch
- [ ] Verify stack limit (50)

## UI/UX
- [ ] Title bar shows cue list name
- [ ] Cue list switcher opens
- [ ] Cue list editor opens
- [ ] Delete confirmation shows
- [ ] Empty state shows (no songs)
- [ ] Empty state shows (empty active list)
- [ ] Library indicator: not in any
- [ ] Library indicator: in active list
- [ ] Library indicator: in other lists
- [ ] Cross-list conflict warnings

## Save/Load
- [ ] Save project with multiple lists
- [ ] Close and reopen
- [ ] Verify all lists present
- [ ] Verify active list restored
- [ ] Verify song counts match
- [ ] Verify MIDI settings preserved

## Edge Cases
- [ ] Global channel with multiple lists
- [ ] Cue mode with multiple lists
- [ ] Switch list while in cue mode
- [ ] Switch list during MIDI output
- [ ] Very long cue list name (50+ chars)
- [ ] Special characters in name (emoji, etc.)
- [ ] Network drive save/load
- [ ] Rapid list switching

## iPhone Specific
- [ ] View picker shows cue list selector
- [ ] Cue list selector works
- [ ] Edit mode UI updates
- [ ] All gestures work

## iPad Specific
- [ ] Side-by-side layout works
- [ ] Cue list switcher sheet
- [ ] All swipe actions work
```

---

## 9. Rollback Plan

### 9.1 Feature Flag

Add at top of ContentView:

```swift
/// Feature flag: Enable multiple cue lists
/// Set to false to revert to single setlist behavior
@AppStorage("enableMultipleCueLists") private var enableMultipleCueLists: Bool = true
```

Usage:
```swift
// In title bar
if enableMultipleCueLists && store.cueLists.count > 1 {
    // Show cue list selector
}

// In UI
if enableMultipleCueLists {
    // Use new multi-list logic
} else {
    // Use legacy single-list logic
}
```

### 9.2 Quick Rollback Steps

If critical issues found after release:

1. **Immediate:** Set feature flag to false in code
2. **Build:** Create emergency patch build
3. **Test:** Verify single-list mode works
4. **Release:** Push as v1.2.1 hotfix
5. **Investigate:** Fix issues in separate branch
6. **Re-enable:** Release v1.2.2 with fixes

### 9.3 Git Recovery

If needed to revert completely:

```bash
# Revert to commit before feature
git revert <commit-hash>

# Or reset branch (loses commits)
git reset --hard <commit-before-feature>

# Or checkout specific file versions
git checkout <commit-hash> -- ContentView.swift SetListStore.swift
```

---

## 10. Future Enhancements

### v1.3.0: Per-List Undo Stacks
- Track undo/redo per cue list
- Preserve history when switching
- Better UX for power users

### v1.3.0: Cue List Templates
- Preset templates on project creation
- Import/export cue lists between projects
- Share cue lists with other users

### v1.4.0: Cue List Groups/Folders
- Organize many cue lists into folders
- Collapse/expand groups
- Color-code by type

### v1.4.0: Smart Cue Lists
- Auto-populate based on rules (e.g., all songs in key of C)
- Dynamic filtering
- Tag-based organization

### v2.0.0: Cloud Sync
- Sync cue lists across devices
- Collaborative editing
- Version history

---

## Appendix A: Code Location Guide

### Key Files

| File | Purpose | Lines to Modify |
|------|---------|-----------------|
| `SetListStore.swift` | State management | Entire file rewrite |
| `ContentView.swift` | Main UI + data access | ~80 locations |
| `Models/CueList.swift` | Data model | New file |
| `ControlSubviews.swift` | Library indicator | Minor updates |

### Search Patterns

| Pattern | Purpose | Expected Matches |
|---------|---------|------------------|
| `store\.setlist\.songs` | Find all data access | ~70-80 |
| `store\.setlist` | Find all setlist refs | ~90-100 |
| `func save.*Project` | Find save functions | 2-3 |
| `func load.*Project` | Find load functions | 2-3 |
| `ProjectPayload` | Find payload struct | 1 |

---

## Appendix B: Time Tracking Template

```markdown
# Multiple Cue Lists Implementation Log

## Phase 0: Preparation
- Start: [date/time]
- End: [date/time]
- Duration: [actual]
- Issues: [none]
- Status: ✅ Complete

## Phase 1: Data Models
- Start: [date/time]
- End: [date/time]
- Duration: [actual]
- Issues: [list any]
- Status: ✅ Complete

[... continue for all phases ...]

## Total Time
- Estimated: 15 hours
- Actual: [calculate]
- Variance: [difference]

## Lessons Learned
1. [What went well]
2. [What was challenging]
3. [What to improve next time]
```

---

## Appendix C: Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss during migration | Low | Critical | Extensive testing, backup prompts |
| Undo/redo confusion | Medium | Medium | Clear on switch, user education |
| Performance with 20+ lists | Low | Medium | Lazy loading, optimization |
| UI complexity | Medium | Low | Intuitive design, tooltips |
| Save/load errors | Low | High | Atomic writes, validation |
| Cross-list MIDI conflicts | Medium | Medium | Warning system, documentation |

---

## Appendix D: Success Metrics

### Technical Metrics
- [ ] All unit tests pass (100%)
- [ ] All integration tests pass (100%)
- [ ] No crashes in 1 hour stress test
- [ ] Load time < 2s for 10 cue lists, 100 songs each
- [ ] Migration success rate > 99.9%

### UX Metrics
- [ ] Can create cue list in < 10 seconds
- [ ] Can switch cue list in < 3 seconds
- [ ] All UI actions have < 200ms response time
- [ ] 0 user reports of data loss
- [ ] Positive feedback on multi-list feature

### Code Quality
- [ ] No compiler warnings
- [ ] Code coverage > 70%
- [ ] All public APIs documented
- [ ] No force-unwraps in critical paths
- [ ] SwiftLint passes with 0 errors

---

## Sign-off

**Implementation Plan Approved By:**
- [ ] Lead Developer
- [ ] QA Lead
- [ ] Product Owner

**Date:** _______________

**Estimated Completion:** 5 working days (15 hours)

**Actual Completion:** _______________

---

*End of Implementation Plan v2.0*
