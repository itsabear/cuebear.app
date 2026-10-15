# Cue Bear Next

The relaunch version of the iPad app, built from the relaunch plan. It installs as a separate
app called **Cue Bear Next** (orange NEXT icon), so the App Store Cue Bear stays untouched.

- Folder: `SANDBOX/Cue Bear Next` (a git worktree of the main Cue Bear repo, branch `relaunch`)
- App ID: `Omri-Behr.Cue-Bear.Next`, version 1.3.0
- Works with Bridge 1.2.4 (the one you just signed). Run only one of the two iPad apps at a time
  when connecting to the same Mac.

## What's new

| Feature | Where to find it |
| --- | --- |
| **Show mode**: Now, Next, one big GO, the setlist at the side, shared controls plus this song's extras | **Show** button at the top right |
| Tap a song in Show mode to make it next; GO (or a pedal) plays it | Show mode |
| Locked by default: hold Exit for one second to leave | Show mode, top right |
| Status pill: USB, Wi-Fi backup, backup Mac; buzzes if the link drops | Show mode, top right |
| **Notes & Extras** per song: notes on the stage card, song-only buttons/toggles/faders, remembered fader levels | Edit mode: long-press a cue, or Edit Cue > ⋯ menu |
| Copy a song's extras to other songs | Notes & Extras |
| MIDI learn for extras ("Learn from DAW") | Notes & Extras > an extra |
| **Two computers at once**: every press also goes to a backup Mac | Connections > Backup computer |
| **Demo shows** on every device (Club Night, Musical Theatre, Worship Sunday) | Menu > Open |
| **First run**: starts inside a demo show; checklist that ticks itself, QR code to the Bridge, test note, setup guide per DAW | First launch, or Menu > Getting Started |
| Old step-by-step tutorials and the "beta" card retired | |

## Design pass: one look everywhere

Every screen now takes its look from one design foundation (see `DESIGN_FOUNDATION.md`):

- One typeface (Sora) and one type scale of 9 sizes, instead of about 28 sizes and three typefaces.
- Four corner sizes, one spacing scale, one set of colors by role.
- Standard pieces: chip, card, row, sheet header, buttons (primary / secondary / destructive), tags, status pill.
- Every sheet has the same background, header and row style, including Show mode, Getting started,
  Notes & Extras and the pairing window, which used to look different from the rest of the app.
- Show mode's GO now looks like the main screen's GO (white, black type). "Now" and selection are blue.

The look is a plain skeleton on purpose. The real design language goes into the foundation files later,
and the whole app follows.

## Code clean-up

- `ContentView.swift` went from 13,800 lines to about 1,300. The rest is split by feature:
  `Features/Main` (top bar, side menu, setlist, library, cue lists, projects...), `Features/Controls`
  (control area, editor, MIDI pickers), `Features/MIDI`, `Features/ShowMode`, `Features/Songs`,
  `Features/Onboarding`, `Features/Settings`, `Features/Store`.
- Other folders: `App`, `Design`, `Models`, `Storage`, `Connection`, `Debug`.
- Removed about 8,000 lines of code nothing used (old tutorials, old onboarding, an old USB tunnel,
  design experiments, placeholders).

## Not done yet (next passes)

- The real design language (the foundation is ready for it).
- The editing screens still have the old layouts, now in the common style. Redesigning them is its own pass.
- Resizable windows for iPadOS 27 (the app still asks for a fixed full-screen window).
- Program Change messages (needs a matching Bridge change).
- Pricing (left off on purpose).
- "Use on every song" (turning an extra into a shared control).

## Built without Xcode

This code was written without a compiler, so a build may show some errors.
Paste them to Claude.

## Test checklist

1. Build and run on the iPad. You should see a second app, **Cue Bear Next**.
2. First launch opens the **Club Night** demo and the Getting started checklist.
3. Tap **Try Show mode**. Press GO a few times. Tap a song in the list, then GO.
4. Song 3 (Midnight Run) shows a **Choir FX** extra. Song 2 (Gold) moves the Beat fader to 80%.
5. Hold **Exit** for a second to leave.
6. In edit mode, long-press a cue > **Notes & Extras**. Add a note and an extra, then check them in Show mode.
7. Connections > **Backup computer**: pick a second Mac running Bridge 1.2.4, and watch both receive MIDI.
