# Quick Reference: Adding Build Phase to Xcode

## Script to Add

```bash
bash "${SRCROOT}/scripts/update_git_info.sh"
```

## Steps

1. **Select Target** → Click "Cue Bear" in left sidebar
2. **Build Phases** → Click "Build Phases" tab at top
3. **Add Phase** → Click "+" button → "New Run Script Phase"
4. **Move to Top** → Drag "Run Script" to be FIRST (above all other phases)
5. **Name It** → Double-click "Run Script" → Rename to "Update Git Commit Hash & Changelog"
6. **Add Script** → Paste the script above into the text box
7. **Save** → Click outside the box to save

## Result

✅ Every build will:
- Update `GitCommitHash.swift` with current commit
- Regenerate `CHANGELOG.md` with git history
- Show commit hash in About sheet

## The Script Location

`${SRCROOT}/scripts/update_git_info.sh`

This resolves to your project root automatically.
