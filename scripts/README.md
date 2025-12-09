# Development Scripts

## Git Commit Hash Tracking & Changelog Generation

The app automatically tracks the current git commit hash and generates a changelog from your git history.

### Features

✅ **Commit Hash Display** - Shows current commit hash in About sheet (e.g., "Commit: 1862002")
✅ **Auto-Generated Changelog** - Creates `CHANGELOG.md` with all commit history
✅ **Automatic Updates** - Runs before every build (when set up as build phase)

### Setup

#### Quick Setup: Run the Helper Script

```bash
python3 scripts/add_build_phase.py
```

This will show you step-by-step instructions to add the build phase to Xcode.

#### Manual Xcode Setup

1. Open **Cue Bear.xcodeproj** in Xcode
2. Select the **"Cue Bear"** target
3. Go to **"Build Phases"** tab
4. Click **"+"** → **"New Run Script Phase"**
5. Drag it to be the **FIRST** phase (above "Compile Sources")
6. Name it: **"Update Git Commit Hash & Changelog"**
7. Paste this script:

```bash
# Update git commit hash and generate changelog
bash "${SRCROOT}/scripts/update_git_info.sh"
```

8. ✅ Done! The script will run automatically before every build

### Manual Usage

You can also run the script manually:

```bash
./scripts/update_git_info.sh
```

This will:
- Update `GitCommitHash.swift` with current commit
- Regenerate `CHANGELOG.md` with full git history

### Files Generated

- **`Cue Bear/Cue Bear/GitCommitHash.swift`** - Auto-generated, contains current commit hash
- **`CHANGELOG.md`** - Auto-generated, full commit history in Markdown format

### Files Modified

- `Cue Bear/Views/AboutAndAppearanceSheets.swift` - Displays commit hash in About sheet
- `scripts/update_git_info.sh` - Main script (runs on every build)
- `scripts/add_build_phase.py` - Helper to show Xcode setup instructions

### Recent Commits

- **1862002**: Update commit hash to b7acd35 and add documentation
- **b7acd35**: Add git commit hash display in About sheet
- **8e7ec47**: Fix control area transparency to show cues underneath capsule
