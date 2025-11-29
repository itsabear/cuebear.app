# Development Scripts

## Git Commit Hash Tracking

The app displays the current git commit hash in the About sheet (shown below the version number).

### Setup

The git commit hash is stored in `Cue Bear/Cue Bear/GitCommitHash.swift` and displayed in the About sheet.

### Workflow

#### Option 1: Manual Update (Recommended for development)

Before building or committing changes:

```bash
./scripts/update_git_hash.sh
```

This will update `GitCommitHash.swift` with the current HEAD commit hash.

#### Option 2: Add as Xcode Build Phase (Automated)

To automatically update the hash before every build:

1. Open Xcode
2. Select the "Cue Bear" target
3. Go to "Build Phases" tab
4. Click "+" and select "New Run Script Phase"
5. Move it to be the first build phase
6. Add this script:

```bash
bash "${SRCROOT}/scripts/update_git_hash.sh"
```

7. Name it "Update Git Commit Hash"

### After Making Changes

After committing changes, the commit hash display will show the previous commit (the one that was current when you last ran the script). This is the intended behavior - it shows which commit the build is based on.

### Files Modified

- `Cue Bear/Cue Bear/GitCommitHash.swift` - Auto-generated, contains the commit hash
- `Cue Bear/Views/AboutAndAppearanceSheets.swift` - Displays the hash in the About sheet
- `scripts/update_git_hash.sh` - Script to update the hash

### Commit Hashes

- **8e7ec47**: Fix control area transparency to show cues underneath capsule
- **b7acd35**: Add git commit hash display in About sheet
