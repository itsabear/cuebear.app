//
//  DemoShows.swift — Cue Bear Next (v1.3)
//
//  Three ready-made shows that install on every device (before, only a Simulator demo existed).
//  A new user opens the app, sees a real show, and can press GO before setting anything up.
//  Each one also shows off shared controls, song notes, song extras and remembered levels.
//

import Foundation

enum DemoShows {
    static let firstShowName = "Demo - Club Night"
    private static let installedKey = "CueBearNext.demoShowsInstalled.v1"

    /// Installs any demo show that's missing. Cheap to call on every launch.
    static func installIfNeeded() {
        let alreadyInstalled = UserDefaults.standard.bool(forKey: installedKey)
        for show in [clubNight(), musicalTheatre(), worshipSunday()] {
            // Once installed, a deleted demo stays deleted (the user chose to remove it).
            if alreadyInstalled { continue }
            if (try? ProjectIO.load(name: show.name)) != nil { continue }
            do {
                try ProjectIO.save(
                    name: show.name,
                    cueLists: [show.cueList],
                    activeCueListID: show.cueList.id,
                    library: show.cueList.songs,
                    controls: show.controls,
                    isGlobalChannel: false,
                    globalChannel: 1,
                    theme: nil,
                    appMode: .cue
                )
                debugPrint("📦 Installed demo show: \(show.name)")
            } catch {
                debugPrint("❌ Could not install demo show \(show.name): \(error)")
            }
        }
        UserDefaults.standard.set(true, forKey: installedKey)
    }

    // MARK: - Building blocks

    private struct Show {
        let name: String
        let cueList: CueList
        let controls: [ControlButton]
    }

    private static func song(_ name: String, _ subtitle: String?, cc: Int, color: String,
                             notes: String? = nil, extras: [SongExtra]? = nil,
                             levels: [String: Int]? = nil) -> Song {
        var s = Song(name: name, subtitle: subtitle, cc: cc, channel: 1)
        s.colorHex = color
        s.notes = notes
        s.extras = extras
        s.rememberedLevels = levels
        return s
    }

    private static func button(_ title: String, _ symbol: String, cc: Int, col: Int, row: Int,
                               toggle: Bool = false, color: String? = nil) -> ControlButton {
        ControlButton(title: title, symbol: symbol, kind: .cc, number: cc, channel: 1,
                      isToggle: toggle ? true : nil, isFader: false, isSmall: false,
                      gridCol: col, gridRow: row, colorHex: color)
    }

    private static func fader(_ title: String, cc: Int, col: Int, value: Double) -> ControlButton {
        ControlButton(title: title, symbol: "", kind: .cc, number: cc, channel: 1,
                      isFader: true, isSmall: false, gridCol: col, gridRow: 0,
                      faderValue: value, faderOrientation: "vertical", faderDirection: "up")
    }

    // MARK: - Club Night (band with backing tracks)

    private static func clubNight() -> Show {
        let play = button("Play", "play.fill", cc: 20, col: 0, row: 0, color: "2A9D8F")
        let stop = button("Stop", "stop.fill", cc: 21, col: 0, row: 1, color: "E63946")
        let harmony = fader("Harmony", cc: 22, col: 2, value: 0.7)
        let beat = fader("Beat", cc: 23, col: 3, value: 0.6)
        let vocalFX = button("Vocal FX", "waveform", cc: 24, col: 4, row: 0, toggle: true, color: "6A4C93")
        let songs = [
            song("Opening", "Intro tape, 118 BPM", cc: 30, color: "264653",
                 notes: "Wait for the lights. Count-in from click."),
            song("Gold", "124 BPM, A minor", cc: 31, color: "E9C46A",
                 notes: "Beat drops at the second chorus.",
                 levels: [beat.id.uuidString: 102]),
            song("Midnight Run", "124 BPM, A minor", cc: 32, color: "2A9D8F",
                 notes: "Drop the second verse. Choir FX on the last chorus.",
                 extras: [SongExtra(title: "Choir FX", style: .toggle, number: 40)]),
            song("Paper Hearts", "96 BPM, D major", cc: 33, color: "F4A261",
                 notes: "Acoustic start, band joins at bar 9."),
            song("Slow Burn", "72 BPM, E minor", cc: 34, color: "E76F51",
                 notes: "Harmonies low until the bridge.",
                 levels: [harmony.id.uuidString: 50]),
            song("Encore", "128 BPM, C major", cc: 35, color: "8AB17D",
                 notes: "Long outro. Watch the drummer for the end.")
        ]
        return Show(name: firstShowName,
                    cueList: CueList(name: "Tonight", songs: songs),
                    controls: [play, stop, harmony, beat, vocalFX])
    }

    // MARK: - Musical theatre (numbered cues in order)

    private static func musicalTheatre() -> Show {
        let goSound = button("Sound GO", "speaker.wave.2.fill", cc: 20, col: 0, row: 0, color: "2A9D8F")
        let stopAll = button("Stop All", "stop.fill", cc: 21, col: 0, row: 1, color: "E63946")
        let music = fader("Music", cc: 22, col: 2, value: 0.75)
        let effects = fader("Effects", cc: 23, col: 3, value: 0.6)
        let reverb = button("Reverb", "dot.radiowaves.left.and.right", cc: 24, col: 4, row: 0, toggle: true, color: "6A4C93")
        let songs = [
            song("Q1 Overture", "Pre-show music fades", cc: 30, color: "264653",
                 notes: "GO on the house lights going down."),
            song("Q2 Market Scene", "Crowd ambience", cc: 31, color: "E9C46A",
                 notes: "Stand by: actors enter from stage left."),
            song("Q3 The Storm", "Thunder and rain", cc: 32, color: "457B9D",
                 notes: "Thunder on the lightning flash.",
                 extras: [SongExtra(title: "Thunder", style: .button, number: 41)],
                 levels: [effects.id.uuidString: 115]),
            song("Q4 Love Song", "Song with track", cc: 33, color: "F4A261",
                 notes: "Reverb on for the last verse."),
            song("Q5 Finale", "Full company", cc: 34, color: "E76F51",
                 notes: "Hold the final chord for the bow.",
                 levels: [music.id.uuidString: 120])
        ]
        return Show(name: "Demo - Musical Theatre",
                    cueList: CueList(name: "Act One", songs: songs),
                    controls: [goSound, stopAll, music, effects, reverb])
    }

    // MARK: - Worship (click, pads, tracks)

    private static func worshipSunday() -> Show {
        let play = button("Play", "play.fill", cc: 20, col: 0, row: 0, color: "2A9D8F")
        let stop = button("Stop", "stop.fill", cc: 21, col: 0, row: 1, color: "E63946")
        let tracks = fader("Tracks", cc: 22, col: 2, value: 0.7)
        let pads = fader("Pads", cc: 23, col: 3, value: 0.5)
        let click = button("Click", "metronome", cc: 24, col: 4, row: 0, toggle: true, color: "6A4C93")
        let songs = [
            song("Welcome", "Pads only", cc: 30, color: "264653",
                 notes: "Pads under the welcome. No click.",
                 levels: [pads.id.uuidString: 90]),
            song("Song One", "72 BPM, G major", cc: 31, color: "E9C46A",
                 notes: "Click on. Count in two bars."),
            song("Song Two", "130 BPM, E major", cc: 32, color: "2A9D8F",
                 notes: "Tracks up for the chorus."),
            song("Prayer", "Pads, free time", cc: 33, color: "F4A261",
                 notes: "Watch the pastor. Pads only.",
                 extras: [SongExtra(title: "Pad Swell", style: .fader, number: 42)]),
            song("Closing Song", "68 BPM, D major", cc: 34, color: "E76F51",
                 notes: "Repeat the last chorus if the leader signals.")
        ]
        return Show(name: "Demo - Worship Sunday",
                    cueList: CueList(name: "Sunday", songs: songs),
                    controls: [play, stop, tracks, pads, click])
    }
}
