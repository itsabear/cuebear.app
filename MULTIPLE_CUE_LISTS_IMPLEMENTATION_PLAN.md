# Multiple Cue Lists per Project - Implementation Plan

## 1. Overview

This feature adds support for multiple named cue lists per project in Cue Bear iPad app. Currently, each project has a single setlist (`store.setlist.songs`). After implementation, each project will support multiple cue lists (e.g., "Main", "Rehearsal", "Backup"), allowing users to:

- View title as `[Project Name] - [Cue List Name]`
- Edit cue list names in edit mode
- Create new cue lists with a + button
- Switch between cue lists within a project
- Each cue list maintains its own songs (setlist)
- Library remains shared across all cue lists in a project

**Key Design Principle**: The library is shared across all cue lists, but each cue list has its own independent songs array.

---

## 2. Current Architecture

### Data Models (`Models.swift`)

```swift
// Line 18-40
public struct Song: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var subtitle: String?
    public var cc: Int
    public var channel: Int
    public var kind: MIDIKind = .cc
    public var note: Int? = nil
    public var velocity: Int = 127
    public var colorHex: String? = nil
}

// Line 43-46
public struct Setlist: Codable, Equatable {
    public var songs: [Song] = []
    public init(songs: [Song] = []) { self.songs = songs }
}
```

### Project Storage (`ProjectPayload.swift`)

```swift
// Line 4-20
struct ProjectPayload: Codable {
    let name: String
    let setlist: [Song]          // Single setlist array
    let library: [Song]
    let controls: [ControlButton]
    let isGlobalChannel: Bool?
    let globalChannel: Int?
}
```

### State Management (`SetListStore.swift`)

```swift
// Line 4-8
final class SetlistStore: ObservableObject {
    @Published var setlist: Setlist     // Single setlist
    @Published var mode: AppMode = .regular
    @Published var cuedSong: Song? = nil
    @Published var scrollLock: Bool = false
}
```

### UI State (`ContentView.swift`)

```swift
// Line 1786
@EnvironmentObject var store: SetlistStore

// Line 1827
@AppStorage("lastProjectName") private var projectName: String = "Untitled"

// All setlist operations work on store.setlist.songs
// Example at line 1952, 2027, 2038, etc.
```

---

## 3. Proposed Architecture

### New Data Structure

Add a `CueList` struct to encapsulate a named cue list with its songs:

```swift
public struct CueList: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var songs: [Song]

    public init(id: UUID = UUID(), name: String, songs: [Song] = []) {
        self.id = id
        self.name = name
        self.songs = songs
    }
}
```

### Migration from Setlist to CueList Array

- **Before**: `store.setlist.songs` (single array)
- **After**: `store.cueLists[activeCueListIndex].songs` (array of cue lists)

### Backward Compatibility

When loading old projects, convert the single `setlist` to a cue list named "Main":

```swift
// If old format (setlist field present)
if let setlist = payload.setlist {
    let mainCueList = CueList(name: "Main", songs: setlist)
    store.cueLists = [mainCueList]
    store.activeCueListID = mainCueList.id
}
```

---

## 4. Data Model Changes

### File: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Models.swift`

**After line 46** (after `Setlist` struct), add the new `CueList` struct:

```swift
// MARK: - Cue List (v1.1.0)
public struct CueList: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var songs: [Song]

    public init(id: UUID = UUID(), name: String, songs: [Song] = []) {
        self.id = id
        self.name = name
        self.songs = songs
    }
}

extension CueList {
    static let sample: CueList = {
        let songs: [Song] = [
            Song(name: "Opening Song",  subtitle: "120 BPM • Em", cc: 11, channel: 1),
            Song(name: "Verse Drop",    subtitle: "128 BPM • Gm", cc: 12, channel: 1),
            Song(name: "Chorus Lift",   subtitle: "126 BPM • Bm", cc: 13, channel: 1)
        ]
        return CueList(name: "Main", songs: songs)
    }()
}
```

**Keep the existing `Setlist` struct** for backward compatibility during loading.

---

### File: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/ProjectPayload.swift`

**Replace the entire struct** (lines 4-20) with the new version:

```swift
/// Shared project data structure for both legacy and document-based projects
struct ProjectPayload: Codable {
    let name: String

    // New format: multiple cue lists (v1.1.0+)
    let cueLists: [CueList]?
    let activeCueListID: UUID?

    // Legacy format: single setlist (for backward compatibility)
    let setlist: [Song]?

    // Shared across all cue lists
    let library: [Song]
    let controls: [ControlButton]
    let isGlobalChannel: Bool?
    let globalChannel: Int?

    init(name: String, cueLists: [CueList], activeCueListID: UUID, library: [Song], controls: [ControlButton], isGlobalChannel: Bool? = nil, globalChannel: Int? = nil) {
        self.name = name
        self.cueLists = cueLists
        self.activeCueListID = activeCueListID
        self.setlist = nil  // Not used in new format
        self.library = library
        self.controls = controls
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
    }

    // Legacy initializer (for old save calls during migration)
    init(name: String, setlist: [Song], library: [Song], controls: [ControlButton], isGlobalChannel: Bool? = nil, globalChannel: Int? = nil) {
        self.name = name
        self.setlist = setlist
        self.cueLists = nil
        self.activeCueListID = nil
        self.library = library
        self.controls = controls
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
    }
}
```

**Key Design**:
- Both `cueLists` and `setlist` are optional
- When saving new projects, use `cueLists` + `activeCueListID`
- When loading, check which format is present and migrate if needed

---

### File: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/SetListStore.swift`

**Replace lines 4-23** with:

```swift
final class SetlistStore: ObservableObject {
    @Published var cueLists: [CueList] = []
    @Published var activeCueListID: UUID?
    @Published var mode: AppMode = .regular
    @Published var cuedSong: Song? = nil
    @Published var scrollLock: Bool = false

    // DEPRECATED: Legacy single setlist support (kept for backward compat)
    @Published var setlist: Setlist

    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Initialize with legacy empty setlist for compatibility
        self.setlist = Setlist()

        // Initialize with a default "Main" cue list if none exist
        let defaultCueList = CueList(name: "Main", songs: [])
        self.cueLists = [defaultCueList]
        self.activeCueListID = defaultCueList.id

        // Note: Removed auto-save from SetlistStore since ContentView handles all project saving
        // The setlist debounced save at line 19-22 can be removed or kept for legacy compatibility
    }

    // Computed property for easier access to active cue list
    var activeCueList: CueList? {
        get {
            guard let id = activeCueListID else { return cueLists.first }
            return cueLists.first(where: { $0.id == id })
        }
        set {
            guard let newValue = newValue,
                  let index = cueLists.firstIndex(where: { $0.id == newValue.id }) else { return }
            cueLists[index] = newValue
        }
    }

    // Helper to get active cue list index
    var activeCueListIndex: Int {
        guard let id = activeCueListID,
              let index = cueLists.firstIndex(where: { $0.id == id }) else {
            return 0
        }
        return index
    }
}
```

**Note**: Remove or comment out the auto-save logic (lines 19-22 in original) since ContentView handles project saving.

---

## 5. State Management Changes

### File: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Views/ContentView.swift`

Add new state variables after line 1836 (after `lastTriggeredSongIndex`):

```swift
// Cue List Management (v1.1.0)
@State private var showCueListSwitcher: Bool = false
@State private var showCueListNameEditor: Bool = false
@State private var editingCueListName: String = ""
```

### Helper Functions to Add

Add these computed properties and helpers after line 3408 (after `nextAvailableCC` function):

```swift
// MARK: - Cue List Helpers (v1.1.0)

/// Current active cue list (convenience accessor)
private var activeCueList: CueList? {
    store.activeCueList
}

/// Get songs from the active cue list
private var activeCueListSongs: [Song] {
    get { store.activeCueList?.songs ?? [] }
    set {
        guard let index = store.cueLists.firstIndex(where: { $0.id == store.activeCueListID }) else { return }
        store.cueLists[index].songs = newValue
    }
}

/// Add a new cue list
private func addCueList() {
    let newCueList = CueList(name: "Cue List \(store.cueLists.count + 1)", songs: [])
    pushSetlistUndo()  // Save undo state before changing
    store.cueLists.append(newCueList)
    store.activeCueListID = newCueList.id
    isDirty = true

    // Show name editor immediately
    editingCueListName = newCueList.name
    showCueListNameEditor = true
}

/// Switch to a different cue list
private func switchToCueList(_ cueList: CueList) {
    guard cueList.id != store.activeCueListID else { return }

    store.activeCueListID = cueList.id
    store.cuedSong = nil  // Clear cued song when switching lists
    lastTriggeredSongIndex = 0  // Reset navigation index
    isDirty = true

    UISelectionFeedbackGenerator().selectionChanged()
}

/// Rename the active cue list
private func renameActiveCueList(to newName: String) {
    guard let index = store.cueLists.firstIndex(where: { $0.id == store.activeCueListID }) else { return }
    store.cueLists[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    isDirty = true
}

/// Delete a cue list (cannot delete if it's the only one)
private func deleteCueList(_ cueList: CueList) {
    guard store.cueLists.count > 1 else {
        debugPrint("⚠️ Cannot delete the last cue list")
        return
    }

    guard let index = store.cueLists.firstIndex(where: { $0.id == cueList.id }) else { return }

    pushSetlistUndo()
    store.cueLists.remove(at: index)

    // If we deleted the active list, switch to the first available
    if cueList.id == store.activeCueListID {
        store.activeCueListID = store.cueLists.first?.id
        store.cuedSong = nil
        lastTriggeredSongIndex = 0
    }

    isDirty = true
}

/// Duplicate a cue list
private func duplicateCueList(_ cueList: CueList) {
    let duplicatedCueList = CueList(
        name: "\(cueList.name) Copy",
        songs: cueList.songs  // Deep copy of songs array
    )

    pushSetlistUndo()
    store.cueLists.append(duplicatedCueList)
    store.activeCueListID = duplicatedCueList.id
    isDirty = true
}
```

---

## 6. UI Changes

### A. Title Bar - Display "[Project Name] - [Cue List Name]"

**File**: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Views/ContentView.swift`

**Modify line 1916** (where `projectTitle` is passed to `CBTopBar`):

```swift
// OLD:
projectTitle: projectName,

// NEW:
projectTitle: {
    if let cueListName = store.activeCueList?.name, !cueListName.isEmpty {
        return "\(projectName) - \(cueListName)"
    }
    return projectName
}(),
```

### B. Edit Mode - Add Cue List Name Editor

**File**: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Views/ContentView.swift`

**After the topBarView** (around line 2015), add a cue list editor bar that appears when in edit mode:

```swift
// Cue List Editor Bar (v1.1.0 - appears in edit mode)
if isEditing {
    cueListEditorBar
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

**Add the `cueListEditorBar` computed property** after `topBarView` (around line 2010):

```swift
private var cueListEditorBar: some View {
    HStack(spacing: 16) {
        // Cue List Name (tappable to edit)
        Button(action: {
            editingCueListName = store.activeCueList?.name ?? ""
            showCueListNameEditor = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .imageScale(.medium)
                Text(store.activeCueList?.name ?? "Unnamed")
                    .font(.subheadline.weight(.medium))
                Image(systemName: "pencil")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)

        Spacer()

        // Switch Cue List Button
        Button(action: {
            showCueListSwitcher = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .imageScale(.medium)
                Text("Switch")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }

        // Add New Cue List Button
        Button(action: addCueList) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.medium)
                Text("New List")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.green)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .background(Color(UIColor.systemGroupedBackground))
}
```

### C. Cue List Name Editor Sheet

**Add after the other `.sheet` modifiers** (around line 2670):

```swift
.sheet(isPresented: $showCueListNameEditor) {
    NavigationView {
        Form {
            Section(header: Text("Cue List Name")) {
                TextField("Enter name", text: $editingCueListName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Button("Delete This Cue List") {
                    if let activeCueList = store.activeCueList {
                        deleteCueList(activeCueList)
                        showCueListNameEditor = false
                    }
                }
                .foregroundColor(.red)
                .disabled(store.cueLists.count <= 1)

                if store.cueLists.count <= 1 {
                    Text("Cannot delete the last cue list")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Cue List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showCueListNameEditor = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    renameActiveCueList(to: editingCueListName)
                    showCueListNameEditor = false
                }
                .disabled(editingCueListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
```

### D. Cue List Switcher Sheet

**Add after the cue list name editor sheet**:

```swift
.sheet(isPresented: $showCueListSwitcher) {
    NavigationView {
        List {
            ForEach(store.cueLists) { cueList in
                Button(action: {
                    switchToCueList(cueList)
                    showCueListSwitcher = false
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cueList.name)
                                .font(.headline)
                            Text("\(cueList.songs.count) song\(cueList.songs.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if cueList.id == store.activeCueListID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    deleteCueList(store.cueLists[index])
                }
            }
        }
        .navigationTitle("Switch Cue List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    showCueListSwitcher = false
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    addCueList()
                    showCueListSwitcher = false
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
```

---

## 7. Migration Strategy

### When Loading Projects

**File**: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Views/ContentView.swift`

**Modify the `loadProjectData` function** (around line 3754):

**Replace line 3756** (`store.setlist.songs = payload.setlist`) with:

```swift
// MIGRATION: Handle both old (setlist) and new (cueLists) formats
if let cueLists = payload.cueLists, !cueLists.isEmpty {
    // New format: load cue lists
    store.cueLists = cueLists
    store.activeCueListID = payload.activeCueListID ?? cueLists.first?.id
    debugPrint("✅ Loaded new format: \(cueLists.count) cue lists")

    // Sync legacy setlist for backward compat
    if let activeCueList = store.activeCueList {
        store.setlist.songs = activeCueList.songs
    }
} else if let legacySetlist = payload.setlist {
    // Old format: migrate single setlist to "Main" cue list
    let mainCueList = CueList(name: "Main", songs: legacySetlist)
    store.cueLists = [mainCueList]
    store.activeCueListID = mainCueList.id
    store.setlist.songs = legacySetlist  // Keep legacy sync
    debugPrint("🔄 Migrated legacy format: \(legacySetlist.count) songs -> Main cue list")
    isDirty = true  // Mark dirty to auto-save in new format
} else {
    // Empty project
    let emptyCueList = CueList(name: "Main", songs: [])
    store.cueLists = [emptyCueList]
    store.activeCueListID = emptyCueList.id
    store.setlist.songs = []
    debugPrint("✅ Created empty project with Main cue list")
}
```

### Auto-Migration on First Edit

Once a legacy project is loaded, it will automatically save in the new format on the next save operation (since `isDirty` is set to `true`).

---

## 8. Save/Load Changes

### Update All Save Calls

**File**: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/ProjectIO.swift`

**Add a new save method** after line 50:

```swift
static func save(name: String, cueLists: [CueList], activeCueListID: UUID, library: [Song], controls: [ControlButton], isGlobalChannel: Bool? = nil, globalChannel: Int? = nil) throws {
    let payload = ProjectPayload(
        name: name,
        cueLists: cueLists,
        activeCueListID: activeCueListID,
        library: library,
        controls: controls,
        isGlobalChannel: isGlobalChannel,
        globalChannel: globalChannel
    )
    let data = try JSONEncoder().encode(payload)
    try data.write(to: try path(for: name), options: .atomic)
}
```

**Keep the old save method** for temporary backward compatibility during migration.

### Update All Save Call Sites in ContentView.swift

**Search for all occurrences** of `ProjectIO.save(name: projectName, setlist: store.setlist.songs, ...)`

There are approximately 6 call sites:

1. **Line 1952** (in topBarView onSave)
2. **Line 2318** (in topBarView onSave)
3. **Line 2622** (background save)
4. **Line 3642** (snapshotAndSave)
5. **Line 3939** (auto-save)

**Replace each with**:

```swift
// OLD:
try ProjectIO.save(name: projectName, setlist: store.setlist.songs, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)

// NEW:
try ProjectIO.save(
    name: projectName,
    cueLists: store.cueLists,
    activeCueListID: store.activeCueListID ?? store.cueLists.first?.id ?? UUID(),
    library: songLibrary,
    controls: controlButtons,
    isGlobalChannel: isGlobalChannel,
    globalChannel: globalChannel
)
```

### Update Export Call

**File**: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Views/ContentView.swift`

**Around line 4097** (in `exportProject` function):

```swift
// OLD:
let payload = ProjectPayload(
    name: projectName,
    setlist: store.setlist.songs,
    library: songLibrary,
    controls: controlButtons,
    isGlobalChannel: isGlobalChannel,
    globalChannel: globalChannel
)

// NEW:
let payload = ProjectPayload(
    name: projectName,
    cueLists: store.cueLists,
    activeCueListID: store.activeCueListID ?? store.cueLists.first?.id ?? UUID(),
    library: songLibrary,
    controls: controlButtons,
    isGlobalChannel: isGlobalChannel,
    globalChannel: globalChannel
)
```

---

## 9. Update All References to `store.setlist.songs`

**File**: `/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/Cue Bear/Cue Bear/Views/ContentView.swift`

Use **Find & Replace** to update all references. There are approximately 70+ occurrences.

### Strategy

**Replace**: `store.setlist.songs`
**With**: `activeCueListSongs`

**But be careful** - some replacements need special handling:

### Special Cases

1. **Line 2027** (onMove in editListView):
```swift
// OLD:
store.setlist.songs.move(fromOffsets: inds, toOffset: newOffset)

// NEW:
if let index = store.cueLists.firstIndex(where: { $0.id == store.activeCueListID }) {
    store.cueLists[index].songs.move(fromOffsets: inds, toOffset: newOffset)
}
```

2. **Line 2038** (songs parameter in performanceListView):
```swift
// OLD:
songs: store.setlist.songs,

// NEW:
songs: activeCueListSongs,
```

3. **Line 2040** (cuedID ternary check):
```swift
// OLD:
cuedID: store.mode == .cue ? store.cuedSong?.id : (store.mode == .regularPlusRemote && !store.setlist.songs.isEmpty ? store.setlist.songs[currentSongIndex()].id : nil),

// NEW:
cuedID: store.mode == .cue ? store.cuedSong?.id : (store.mode == .regularPlusRemote && !activeCueListSongs.isEmpty ? activeCueListSongs[currentSongIndex()].id : nil),
```

4. **Lines with array assignments** (like 3257, 3290, etc.):
```swift
// OLD:
store.setlist.songs[i].channel = savedChannel

// NEW:
if let idx = store.cueLists.firstIndex(where: { $0.id == store.activeCueListID }) {
    store.cueLists[idx].songs[i].channel = savedChannel
}
```

### Recommended Approach

Instead of direct replacement, create a **computed property** (already added in Section 5):

```swift
private var activeCueListSongs: [Song] {
    get { store.activeCueList?.songs ?? [] }
    set {
        guard let index = store.cueLists.firstIndex(where: { $0.id == store.activeCueListID }) else { return }
        store.cueLists[index].songs = newValue
    }
}
```

Then replace **read-only** occurrences with `activeCueListSongs` and **write** occurrences with:

```swift
activeCueListSongs = newValue
// or
if let idx = store.cueLists.firstIndex(where: { $0.id == store.activeCueListID }) {
    store.cueLists[idx].songs[operation]
}
```

### Key Lines to Update

- **Line 2027**: Move operation (edit mode drag-drop)
- **Line 2038**: Performance list songs parameter
- **Line 2040**: Cued ID check for navigator
- **Line 2046**: Finding song index for tap
- **Line 2070-2071**: Transport dock songs reference
- **Line 2091**: Navigator capsule songs reference
- **Line 2655**: MIDI table setlist parameter
- **Line 2664-2672**: MIDI table apply changes
- **Line 3018**: First launch clear
- **Line 3087**: Task observer
- **Line 3169**: Conflict check map
- **Line 3233-3259**: Global channel save/restore
- **Line 3288-3291**: Apply global channel to songs
- **Line 3355-3378**: Cue mode navigation (prev/next)
- **Line 3384-3405**: Regular mode navigation
- **Line 3411**: nextAvailableCC taken set
- **Line 3421**: nextDefaultName prefix check
- **Line 3444**: libraryDecorated setlist IDs
- **Line 3462**: filteredSetlistSongs
- **Line 3501**: Delete from setlist
- **Line 3515-3540**: addToSetlist
- **Line 3554-3560**: removeFromSetlist
- **Line 3566-3585**: deleteFromLibrary setlist check
- **Line 3613-3627**: saveSong update setlist
- **Line 3669-3683**: Undo/redo setlist
- **Line 3792-3800**: recoverEmptyLibrary
- **Line 3993**: Load project setlist assignment
- **Line 4059**: Import project setlist assignment
- **Line 4127**: createNewProject clear setlist

### Systematic Replacement Plan

1. Add the `activeCueListSongs` computed property (already in Section 5)
2. Run a regex find to identify all lines with `store.setlist.songs`
3. Replace each occurrence based on context:
   - **Simple reads**: Replace with `activeCueListSongs`
   - **Assignments**: Replace with `activeCueListSongs = newValue`
   - **In-place modifications**: Use the full indexing approach
   - **Count checks**: Replace with `activeCueListSongs.count`
   - **isEmpty checks**: Replace with `activeCueListSongs.isEmpty`

---

## 10. Implementation Steps

### Phase 1: Data Model Updates (Estimated: 30 minutes)

1. ✅ **Update `Models.swift`**
   - Add `CueList` struct after line 46
   - Add sample `CueList` extension

2. ✅ **Update `ProjectPayload.swift`**
   - Replace struct with new version supporting both formats
   - Add new initializer with `cueLists` + `activeCueListID`
   - Keep legacy initializer for backward compat

3. ✅ **Update `SetListStore.swift`**
   - Add `cueLists: [CueList]` property
   - Add `activeCueListID: UUID?` property
   - Add `activeCueList` computed property
   - Add `activeCueListIndex` computed property
   - Update initializer to create default "Main" cue list

### Phase 2: State Management (Estimated: 45 minutes)

4. ✅ **Update `ContentView.swift` - State Variables**
   - Add `@State private var showCueListSwitcher`
   - Add `@State private var showCueListNameEditor`
   - Add `@State private var editingCueListName`

5. ✅ **Update `ContentView.swift` - Helper Functions**
   - Add `activeCueListSongs` computed property
   - Add `addCueList()` function
   - Add `switchToCueList(_:)` function
   - Add `renameActiveCueList(to:)` function
   - Add `deleteCueList(_:)` function
   - Add `duplicateCueList(_:)` function

### Phase 3: UI Updates (Estimated: 1.5 hours)

6. ✅ **Update Title Bar Display**
   - Modify line 1916: Change `projectTitle` to show "[Project Name] - [Cue List Name]"

7. ✅ **Add Cue List Editor Bar**
   - Add `cueListEditorBar` computed property
   - Insert call to `cueListEditorBar` after `topBarView` with edit mode condition

8. ✅ **Add Cue List Name Editor Sheet**
   - Add `.sheet(isPresented: $showCueListNameEditor)` modifier
   - Include TextField for name editing
   - Add Delete button (disabled if only one list)

9. ✅ **Add Cue List Switcher Sheet**
   - Add `.sheet(isPresented: $showCueListSwitcher)` modifier
   - List all cue lists with checkmark for active
   - Support swipe-to-delete
   - Add + button in toolbar

### Phase 4: Data Access Updates (Estimated: 2 hours)

10. ✅ **Update All `store.setlist.songs` References**
    - Run regex search for `store\.setlist\.songs`
    - Replace ~70 occurrences based on context (see Section 9)
    - Test each section after replacement

11. ✅ **Update Migration Logic**
    - Modify `loadProjectData` function (line 3754)
    - Add logic to detect old vs new format
    - Convert old format to "Main" cue list

### Phase 5: Save/Load Updates (Estimated: 1 hour)

12. ✅ **Update `ProjectIO.swift`**
    - Add new `save(cueLists:activeCueListID:...)` method
    - Keep old method for temporary backward compat

13. ✅ **Update All Save Call Sites in `ContentView.swift`**
    - Line 1952 (topBarView onSave)
    - Line 2318 (topBarView onSave duplicate?)
    - Line 2622 (background save)
    - Line 3642 (snapshotAndSave)
    - Line 3939 (auto-save)

14. ✅ **Update Export Logic**
    - Line 4097: Update `ProjectPayload` creation in `exportProject`

### Phase 6: Testing & Refinement (Estimated: 2 hours)

15. ✅ **Test Basic Functionality**
    - Create new project → Should have "Main" cue list
    - Add songs to cue list
    - Save and reload project
    - Verify title shows "[Project] - Main"

16. ✅ **Test Multiple Cue Lists**
    - Create second cue list
    - Add different songs to each
    - Switch between lists
    - Verify songs are isolated per list
    - Verify library is shared

17. ✅ **Test Migration**
    - Load an old project (single setlist)
    - Verify it converts to "Main" cue list
    - Save and reload
    - Verify new format is used

18. ✅ **Test Edge Cases**
    - Try to delete last cue list (should be disabled)
    - Create cue list with empty name
    - Switch cue lists in cue mode (should reset cuedSong)
    - Switch cue lists in navigator mode (should reset index)
    - Undo/redo with multiple cue lists

19. ✅ **Test Global Channel**
    - Enable global channel
    - Verify it applies to active cue list only OR all songs across all lists
    - Document expected behavior

20. ✅ **Test MIDI Conflicts**
    - Add same CC in different cue lists
    - Verify conflict detection works per-list or globally
    - Document expected behavior

---

## 11. Testing Checklist

### Basic Functionality
- [ ] Create new project → Has "Main" cue list by default
- [ ] Add songs to cue list → Songs appear in list
- [ ] Edit mode → Cue list editor bar appears
- [ ] Tap cue list name → Name editor sheet opens
- [ ] Change cue list name → Title updates to "[Project] - [New Name]"
- [ ] Save project → No errors
- [ ] Reload project → Cue list name and songs persist

### Multiple Cue Lists
- [ ] Tap "New List" → Creates new cue list with default name
- [ ] Switch between cue lists → Active list changes, songs update
- [ ] Add songs to List A → Songs only in List A, not in List B
- [ ] Add songs to List B → Songs only in List B, not in List A
- [ ] Library songs → Shared across all cue lists
- [ ] Add library song to List A → Appears in List A setlist
- [ ] Add same library song to List B → Appears in both setlists independently
- [ ] Delete song from library → Removes from all cue lists
- [ ] Delete song from List A → Remains in library and List B

### Cue List Management
- [ ] Tap "Switch" button → Cue list switcher sheet opens
- [ ] Switcher shows all lists → Checkmark on active list
- [ ] Tap list in switcher → Switches to that list
- [ ] Swipe-to-delete in switcher → Deletes cue list
- [ ] Try to delete last cue list → Delete button disabled
- [ ] Delete active cue list → Switches to first remaining list
- [ ] Duplicate cue list → Creates copy with " Copy" suffix

### Migration
- [ ] Load old project (v1.0.x) → Converts to "Main" cue list
- [ ] Old project songs → All present in "Main" cue list
- [ ] Save migrated project → Saves in new format
- [ ] Reload migrated project → Loads without errors
- [ ] Export old project → Uses new format

### Cue Mode & Navigator Mode
- [ ] Switch to cue mode → Shows GO capsule
- [ ] Cue a song in List A → Appears cued
- [ ] Switch to List B in cue mode → Cued song clears
- [ ] GO button → Triggers cued song, moves to next
- [ ] Navigator mode in List A → Shows navigation capsule
- [ ] Switch to List B in navigator → Index resets to 0
- [ ] Next/Prev in navigator → Navigates within active list

### Global Channel
- [ ] Enable global channel → Applies to songs in active list
- [ ] Switch to another list → Global channel applies there too
- [ ] Disable global channel → Restores original channels per-song

### Undo/Redo
- [ ] Add song to List A → Can undo
- [ ] Switch to List B → Undo stack preserved per-list or global?
- [ ] Delete cue list → Can undo? (TBD - may not support)
- [ ] Rename cue list → Can undo? (TBD - may not support)

### Edge Cases
- [ ] Create cue list with empty name → Should not allow (disable Done button)
- [ ] Create 10+ cue lists → UI handles long list
- [ ] Very long cue list name → Title truncates properly
- [ ] Switch lists rapidly → No crashes or state corruption
- [ ] Background app → Saves active cue list ID correctly
- [ ] Kill app → Active cue list persists on restart

### MIDI & Conflicts
- [ ] Add same CC in List A and List B → Conflict warning? (TBD)
- [ ] Conflict detection → Works per-list or globally? (TBD)
- [ ] MIDI table view → Shows active cue list only or all? (TBD)

---

## 12. Edge Cases to Handle

### 1. Empty Cue List Names
**Problem**: User tries to save a cue list with an empty name.

**Solution**: Disable "Done" button in name editor when name is empty (already implemented in UI code above).

```swift
.disabled(editingCueListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
```

### 2. Deleting the Last Cue List
**Problem**: User tries to delete the only remaining cue list.

**Solution**:
- Disable delete button in name editor when `store.cueLists.count <= 1`
- Show explanatory text: "Cannot delete the last cue list"
- Guard in `deleteCueList` function already prevents this

### 3. Deleting the Active Cue List
**Problem**: User deletes the cue list they're currently viewing.

**Solution**:
- After deletion, switch to the first remaining cue list
- Clear `cuedSong` and reset `lastTriggeredSongIndex`
- Already implemented in `deleteCueList` function

### 4. Switching Cue Lists While Cued Song is Active
**Problem**: User has a song cued in Cue Mode, then switches to another list.

**Solution**:
- Clear `store.cuedSong` when switching lists (already implemented in `switchToCueList`)
- Reset `lastTriggeredSongIndex = 0` for Navigator Mode

### 5. Undo/Redo Across Cue Lists
**Problem**: Undo stack might contain state from a different cue list.

**Solution**:
- Current implementation uses a single undo stack for setlist
- **Option A**: Continue using single stack (simpler, may cause confusion)
- **Option B**: Implement per-cue-list undo stacks (complex)
- **Recommendation**: Keep single stack for v1.1.0, document behavior

**Decision Point**: Does undo/redo operate per-cue-list or globally?

### 6. Global Channel Behavior Across Cue Lists
**Problem**: Does global channel apply to all cue lists or just the active one?

**Solution**:
- **Option A**: Apply to active cue list only (simpler)
- **Option B**: Apply to all songs across all cue lists (more comprehensive)
- **Recommendation**: Apply to all cue lists (Option B) for consistency

**Implementation**: Update `applyGlobalChannelToAll` function (line 3287) to iterate through all cue lists:

```swift
// Apply to songs in all cue lists
for listIndex in 0..<store.cueLists.count {
    for songIndex in 0..<store.cueLists[listIndex].songs.count {
        store.cueLists[listIndex].songs[songIndex].channel = globalChannel
    }
}
```

### 7. MIDI Conflict Detection Across Cue Lists
**Problem**: Should MIDI conflicts be detected globally or per-cue-list?

**Solution**:
- **Option A**: Conflicts only within active cue list (allows reuse of CCs across lists)
- **Option B**: Conflicts detected globally (prevents MIDI ambiguity)
- **Recommendation**: **Option A** (per-list) - allows intentional CC reuse across different lists

**Implementation**: No changes needed - current conflict detection uses `store.setlist.songs` which becomes `activeCueListSongs`, so it's already per-list.

### 8. MIDI Table View Scope
**Problem**: Should MIDI Table show all songs from all cue lists or just the active one?

**Solution**:
- **Option A**: Show active cue list only (simpler, less overwhelming)
- **Option B**: Show all cue lists with section headers (comprehensive)
- **Recommendation**: **Option A** for v1.1.0, consider Option B for future

**Implementation**: Current MIDI Table uses `store.setlist.songs` at line 2655, which becomes `activeCueListSongs` - already per-list.

### 9. Library Song "Already in Setlist" Indicator
**Problem**: When viewing library, should "in setlist" indicator show if song is in ANY cue list or just the active one?

**Solution**:
- **Option A**: Show if in active cue list only (clearer context)
- **Option B**: Show if in any cue list (prevents duplicates)
- **Recommendation**: **Option A** (active list only)

**Implementation**: Update `libraryDecorated()` function (line 3444) - already uses `store.setlist.songs` which becomes `activeCueListSongs`.

### 10. Empty Project Initialization
**Problem**: What happens when creating a completely new project?

**Solution**:
- Create a default "Main" cue list with no songs (already implemented in `SetlistStore.init()`)
- User can rename "Main" to anything they want

### 11. Very Long Cue List Names
**Problem**: User enters a very long cue list name that breaks the title bar layout.

**Solution**:
- Truncate title in title bar with `.lineLimit(1)` (already present in `CBTopBar`)
- Allow full name in editor sheets
- Consider max character limit (e.g., 50 characters) in name editor

### 12. Rapid Cue List Switching
**Problem**: User rapidly taps between cue lists, causing state corruption.

**Solution**:
- Add haptic feedback on switch (already implemented)
- Consider debouncing or animation delay
- Test thoroughly during Phase 6

### 13. Background App Save
**Problem**: App goes to background while user is in the middle of editing a cue list.

**Solution**:
- Background save already saves `store.setlist.songs` - will be updated to save all cue lists
- Ensure `activeCueListID` is saved correctly
- Test by backgrounding during edit mode

### 14. Export/Import with Multiple Cue Lists
**Problem**: Exported projects should include all cue lists.

**Solution**:
- Export uses `ProjectPayload` which already includes `cueLists` array
- Import will load all cue lists and set `activeCueListID`
- Test export → share → import flow

---

## 13. Rollback Plan

If critical issues are discovered after implementation, here's how to safely roll back:

### Immediate Rollback (Before Any Saves)

If you catch issues before saving any projects:

1. **Revert Code Changes**
   - Use git to revert to the commit before implementation
   - `git log` to find the last good commit
   - `git reset --hard <commit-hash>`

2. **No Data Loss Risk**
   - No projects have been saved in new format yet
   - All existing projects remain in old format

### Partial Rollback (After Some Saves)

If some projects have been saved in new format but issues are found:

1. **Add Legacy Mode Switch**
   - Add a temporary "Use Legacy Format" toggle in settings
   - When enabled, save projects in old format (single setlist)
   - Convert active cue list back to single setlist on save

2. **Preserve Both Formats**
   - Keep old `ProjectPayload` initializer
   - Add backward converter:

```swift
func convertToLegacyFormat() -> [Song] {
    // Flatten all cue lists into a single array
    // Option A: Just use active cue list
    return store.activeCueList?.songs ?? []

    // Option B: Merge all cue lists (with separators?)
    // return store.cueLists.flatMap { $0.songs }
}
```

3. **Update Save Calls to Use Legacy Format**

```swift
if useLegacyFormat {
    try ProjectIO.save(name: projectName, setlist: convertToLegacyFormat(), library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)
} else {
    try ProjectIO.save(name: projectName, cueLists: store.cueLists, activeCueListID: store.activeCueListID ?? UUID(), library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)
}
```

### Data Recovery

If projects are corrupted:

1. **Check for Backups**
   - Projects are saved to `Documents/CueBearProjects/`
   - May have iCloud backups or device backups

2. **Manual Recovery Script**
   - Write a script to parse `.cuebear` files
   - Extract `setlist` field from old format
   - Convert to new format or back to old format

3. **User Communication**
   - If rollback is necessary, provide clear instructions
   - Offer to manually recover projects if needed

### Prevent Future Issues

1. **Incremental Rollout**
   - Test thoroughly in Phase 6 before shipping
   - Consider beta testing with trusted users
   - Monitor crash reports and user feedback

2. **Version Flag in ProjectPayload**
   - Add a `version: Int` field to `ProjectPayload`
   - Current version = 1 (legacy)
   - New version = 2 (cue lists)
   - Makes it easier to detect and migrate formats

```swift
struct ProjectPayload: Codable {
    let version: Int  // Add this field
    let name: String
    // ... rest of fields

    // In initializer:
    init(...) {
        self.version = 2  // New format
        // ...
    }
}
```

3. **Backup Before First Save**
   - When migrating a legacy project, create a backup with `.backup` extension
   - Only create backup once per project

```swift
func migrateWithBackup(name: String) {
    let backupName = "\(name).backup"
    if !FileManager.default.fileExists(atPath: try! ProjectIO.path(for: backupName).path) {
        // Copy current project to backup
        try? FileManager.default.copyItem(at: try! ProjectIO.path(for: name), to: try! ProjectIO.path(for: backupName))
    }
}
```

---

## 14. Additional Considerations

### A. Performance Optimization

With multiple cue lists, the app will be managing more data:

- **Lazy Loading**: Consider lazy-loading cue lists if projects grow very large (probably not needed for v1.1.0)
- **Caching**: Conflict detection cache already exists - ensure it updates when switching cue lists
- **Memory**: Monitor memory usage with 10+ cue lists with 50+ songs each

### B. Future Enhancements

Features to consider for future versions:

1. **Cue List Reordering**: Drag-to-reorder cue lists in switcher
2. **Cue List Colors**: Color-code cue lists for visual distinction
3. **Cue List Duplication**: Already implemented in helper functions
4. **Cue List Templates**: Save a cue list as a template for reuse
5. **Cross-List Song Copy**: Copy/move songs between cue lists
6. **Merge Cue Lists**: Combine two cue lists into one
7. **Per-Cue-List Undo Stacks**: Separate undo history per list
8. **Global MIDI Table**: View all songs from all lists in MIDI Table
9. **Cue List Search**: Search across all cue lists
10. **Cue List Export**: Export individual cue lists

### C. Documentation Updates

After implementation, update:

1. **User-facing documentation**: Explain multiple cue lists feature
2. **Developer comments**: Document the new architecture
3. **README**: Update any architecture diagrams
4. **Release notes**: Document the new feature and migration behavior

### D. Accessibility

Ensure the new UI is accessible:

- [ ] All buttons have proper labels for VoiceOver
- [ ] Cue list switcher is navigable with VoiceOver
- [ ] Dynamic Type support for cue list names
- [ ] Color contrast for cue list editor bar

---

## 15. Implementation Checklist Summary

Copy this checklist to track progress:

### Phase 1: Data Models
- [ ] Add `CueList` struct to `Models.swift`
- [ ] Update `ProjectPayload.swift` with new format
- [ ] Update `SetListStore.swift` with cue lists support

### Phase 2: State Management
- [ ] Add state variables to `ContentView.swift`
- [ ] Add helper functions for cue list management

### Phase 3: UI
- [ ] Update title bar to show "[Project] - [Cue List]"
- [ ] Add cue list editor bar in edit mode
- [ ] Add cue list name editor sheet
- [ ] Add cue list switcher sheet

### Phase 4: Data Access
- [ ] Replace all `store.setlist.songs` references
- [ ] Update migration logic in `loadProjectData`

### Phase 5: Save/Load
- [ ] Add new save method to `ProjectIO.swift`
- [ ] Update all save call sites in `ContentView.swift`
- [ ] Update export logic

### Phase 6: Testing
- [ ] Test basic functionality
- [ ] Test multiple cue lists
- [ ] Test migration
- [ ] Test edge cases
- [ ] Test cue/navigator modes
- [ ] Test global channel
- [ ] Test undo/redo
- [ ] Test MIDI conflicts

### Final
- [ ] Code review
- [ ] Documentation updates
- [ ] Commit changes
- [ ] Create release notes

---

## 16. Estimated Timeline

- **Phase 1 (Data Models)**: 30 minutes
- **Phase 2 (State Management)**: 45 minutes
- **Phase 3 (UI)**: 1.5 hours
- **Phase 4 (Data Access)**: 2 hours
- **Phase 5 (Save/Load)**: 1 hour
- **Phase 6 (Testing)**: 2 hours

**Total Estimated Time**: ~7-8 hours

**Recommended Approach**:
- Day 1: Phases 1-3 (setup and UI)
- Day 2: Phases 4-5 (data migration and save/load)
- Day 3: Phase 6 (thorough testing and bug fixes)

---

## 17. Key Files to Modify

| File | Lines to Modify | Type of Change |
|------|----------------|----------------|
| `Models.swift` | After line 46 | Add `CueList` struct |
| `ProjectPayload.swift` | Lines 4-20 | Replace entire struct |
| `SetListStore.swift` | Lines 4-23 | Add cue lists support |
| `ProjectIO.swift` | After line 50 | Add new save method |
| `ContentView.swift` | ~70+ locations | Replace `store.setlist.songs` |
| `ContentView.swift` | Line 1916 | Update title display |
| `ContentView.swift` | After line 1836 | Add state variables |
| `ContentView.swift` | After line 3408 | Add helper functions |
| `ContentView.swift` | After line 2010 | Add cue list editor bar |
| `ContentView.swift` | After line 2670 | Add sheets |
| `ContentView.swift` | Line 3754 | Update migration logic |
| `ContentView.swift` | Lines 1952, 2318, 2622, 3642, 3939 | Update save calls |
| `ContentView.swift` | Line 4097 | Update export |

---

## 18. Final Notes

This implementation plan provides a comprehensive roadmap for adding multiple cue lists to Cue Bear. The design prioritizes:

1. **Backward Compatibility**: Old projects automatically migrate to new format
2. **User Experience**: Intuitive UI for managing multiple lists
3. **Data Integrity**: Clear ownership of songs per list, shared library
4. **Safety**: Cannot delete last cue list, clear undo behavior
5. **Flexibility**: Easy to add/remove/rename/switch lists

The most complex part is updating all references to `store.setlist.songs` throughout `ContentView.swift`. Take your time with Phase 4 and test each section thoroughly.

If you encounter any blockers or have questions during implementation, refer back to this plan and consider the edge cases and rollback strategies outlined above.

Good luck with the implementation!
