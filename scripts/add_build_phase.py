#!/usr/bin/env python3
"""
Add a "Run Script" build phase to Xcode project to auto-update git commit hash.
"""

import sys
import os

def add_build_phase():
    """Add build phase instructions for manual setup."""

    print("""
╔════════════════════════════════════════════════════════════════════╗
║  How to Add Git Commit Hash Update as Xcode Build Phase           ║
╚════════════════════════════════════════════════════════════════════╝

Follow these steps to automatically update the git commit hash before every build:

1. Open your Xcode project: Cue Bear.xcodeproj

2. Select the "Cue Bear" target in the left sidebar

3. Click on the "Build Phases" tab at the top

4. Click the "+" button in the top left

5. Select "New Run Script Phase"

6. Drag the new "Run Script" phase to be the FIRST phase (above "Compile Sources")

7. Name it: "Update Git Commit Hash & Changelog"

8. In the script box, paste this:

   ┌──────────────────────────────────────────────────────────────┐
   │ # Update git commit hash and generate changelog              │
   │ bash "${SRCROOT}/scripts/update_git_info.sh"                 │
   └──────────────────────────────────────────────────────────────┘

9. Check the box: "Based on dependency analysis" (optional, for faster builds)

10. Click anywhere outside the script box to save

11. Build your project - the script will now run automatically!

═══════════════════════════════════════════════════════════════════

What this does:
✅ Updates GitCommitHash.swift with current commit before every build
✅ Generates CHANGELOG.md with all git commit history
✅ Shows commit hash in About sheet (e.g., "Commit: 1862002")
✅ Keeps changelog up to date automatically

Files affected:
• Cue Bear/Cue Bear/GitCommitHash.swift (auto-updated)
• CHANGELOG.md (auto-generated)

═══════════════════════════════════════════════════════════════════
""")

if __name__ == "__main__":
    add_build_phase()
