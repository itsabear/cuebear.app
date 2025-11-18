# Migration Notes for Multiple Cue Lists Feature

**Date:** 2025-01-16
**Branch:** feature/multiple-cue-lists
**Target Version:** 1.2.0

## Current Code Locations (Pre-Migration)

### Key Files
- **SetListStore.swift**: Line 1-50 (entire file to be rewritten)
- **ContentView.swift**: Main implementation file
  - ProjectPayload: Search for `struct ProjectPayload`
  - Save function: Search for `func saveCurrentProject`
  - Load function: Search for `func loadProjectFromURL`

### State Variables (ContentView.swift)
```swift
@StateObject private var store = SetlistStore()
```

### Data Access Patterns to Replace

#### Pattern 1: Read-only access
```swift
// OLD:
let songs = store.setlist.songs
let count = store.setlist.songs.count
let isEmpty = store.setlist.songs.isEmpty

// NEW:
let songs = store.activeSongs
let count = store.activeSongs.count
let isEmpty = store.activeSongs.isEmpty
```

#### Pattern 2: Simple mutation
```swift
// OLD:
store.setlist.songs.append(newSong)
store.setlist.songs.remove(at: index)

// NEW:
pushUndo()
store.updateActiveSongs { songs in
    songs.append(newSong)
}
saveCurrentProject()
```

#### Pattern 3: Complex mutation
```swift
// OLD:
store.setlist.songs[index].name = "New Name"
store.setlist.songs[index].number = 5

// NEW:
pushUndo()
store.updateActiveSongs { songs in
    songs[index].name = "New Name"
    songs[index].number = 5
}
saveCurrentProject()
```

#### Pattern 4: Move/reorder
```swift
// OLD:
store.setlist.songs.move(fromOffsets: indices, toOffset: offset)

// NEW:
pushUndo()
store.updateActiveSongs { songs in
    songs.move(fromOffsets: indices, toOffset: offset)
}
saveCurrentProject()
```

## Search Patterns

| Pattern | Purpose | Expected Matches |
|---------|---------|------------------|
| `store\.setlist\.songs` | All data access points | ~70-80 |
| `store\.setlist` | All setlist references | ~90-100 |
| `Setlist\(` | Setlist initializations | ~5-10 |
| `ProjectPayload` | Payload struct | 1 |
| `func save.*Project` | Save functions | 2-3 |
| `func load.*Project` | Load functions | 2-3 |

## Critical Changes Required

### 1. SetListStore.swift - COMPLETE REWRITE
- ❌ Remove: `@Published var setlist: Setlist`
- ❌ Remove: Auto-save Combine pipeline
- ✅ Add: `@Published var cueLists: [CueList]`
- ✅ Add: `@Published var activeCueListID: UUID?`
- ✅ Add: Mutation helper functions

### 2. ContentView.swift - Major Updates
- Add cue list state variables
- Add undo/redo snapshot system
- Update all `store.setlist.songs` references
- Implement new UI components
- Update save/load functions

### 3. Models/CueList.swift - NEW FILE
- Create complete CueList struct
- Add validation
- Add templates

## Backup Files Created

Before starting implementation, these files were backed up:

```bash
SetListStore.swift.backup
ContentView.swift.backup
```

## Test Files Created

```
Test_Projects/
├── legacy_v1.0_empty.json
├── legacy_v1.0_small.json
├── corrupted_missing_setlist.json
└── modern_v1.2_multi.json
```

## Implementation Phases Status

- [x] Phase 0: Preparation (1 hour)
  - [x] Create feature branch
  - [x] Create test files
  - [x] Set up unit tests
  - [x] Create migration notes
  - [x] Backup files
- [x] Phase 1: Data Models (1 hour)
  - [x] Create Models/CueList.swift
  - [x] Update ProjectPayload.swift for dual format support
  - [x] Fix optional unwrapping errors in CueBearApp.swift
  - [x] Fix optional unwrapping errors in ContentView.swift
  - [x] Verify project builds successfully
- [x] Phase 2: State Management (1.5 hours)
  - [x] Completely rewrite SetListStore.swift
  - [x] Remove @Published var setlist: Setlist
  - [x] Remove auto-save Combine pipeline
  - [x] Add @Published var cueLists: [CueList]
  - [x] Add @Published var activeCueListID: UUID?
  - [x] Add mutation helper functions (updateActiveSongs, switchToCueList, etc.)
  - [x] Remove duplicate AppMode enum (already exists in Models.swift)
- [ ] Phase 2.5: Accessibility (30 minutes)
- [x] Phase 3: UI Components (2 hours)
  - [x] Added 7 new state variables for cue list management
  - [x] Updated left capsule: Menu + Cue List Title (tappable)
  - [x] Added center project name (iPad only)
  - [x] Updated right capsule (iPad): Song Library | Cue List | Connections
  - [x] Updated right capsule (iPhone): Connections | More (...)
  - [x] Created song library popover (iPad) with context menu
  - [x] Created cue list picker sheet (add song to cue list)
  - [x] Created cue list switcher sheet (switch between cue lists)
  - [x] Added helper functions: addSongToCueList, createAndAddToCueList, deleteSongFromLibrary
  - [x] Build succeeded with zero errors
- [ ] Phase 3.5: Undo/Redo (1 hour)
- [x] Phase 4: Data Access Migration (3 hours)
  - [x] Migrated all 79 store.setlist.songs references in ContentView.swift
  - [x] Replaced read-only access with store.activeSongs (43 occurrences)
  - [x] Replaced simple mutations with store.updateActiveSongs (15 occurrences)
  - [x] Replaced complex mutations with store.updateActiveSongs (21 occurrences)
  - [x] Build succeeded with zero errors
- [x] Phase 5: Save/Load Implementation (1.5 hours)
  - [x] Updated ProjectIO.save() with modern format (cueLists, activeCueListID, theme)
  - [x] Added ProjectIO.saveLegacy() for backward compatibility
  - [x] Updated all 5 ProjectIO.save() calls in ContentView.swift
  - [x] Added legacy migration logic to loadProject(named:)
  - [x] Added legacy migration logic to autoOpenLastProject()
  - [x] Added legacy migration logic to document import handler
  - [x] Updated exportCurrentProject() to use modern format
  - [x] Fixed CueBearApp.swift demo project installer
  - [x] Fixed currentTheme.identifier → currentTheme.id
  - [x] Build succeeded with zero errors
- [ ] Phase 6: Comprehensive Testing (4 hours)
- [ ] Phase 7: Documentation (30 minutes)

## Known Issues to Watch For

1. **Auto-save conflicts**: The old SetlistStore has auto-save. Must be completely removed.
2. **Computed property mutations**: Can't use simple `{ get set }` pattern for song arrays.
3. **Undo stack on switch**: Must clear when switching cue lists.
4. **Migration edge cases**: Handle missing/corrupted fields gracefully.
5. **Global channel behavior**: Apply to active list only, not all lists.

## Rollback Commands

If needed to revert:

```bash
# Revert all changes
git checkout ipad-iphone-v1.2.0

# Or restore specific files
git checkout ipad-iphone-v1.2.0 -- SetListStore.swift
git checkout ipad-iphone-v1.2.0 -- ContentView.swift

# Or use backups
cp SetListStore.swift.backup SetListStore.swift
cp ContentView.swift.backup ContentView.swift
```

## Notes

- Keep detailed log of actual time spent per phase
- Document any deviations from plan
- Track all edge cases discovered during implementation
- Record any new search patterns found

---

*Last Updated: 2025-01-16 - Phase 0 Complete*
