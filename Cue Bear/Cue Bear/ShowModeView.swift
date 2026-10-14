//
//  ShowModeView.swift — Cue Bear Next (v1.3)
//
//  The stage screen: the current song large, the next song under it, one big GO,
//  then the show's shared controls plus this song's extras.
//
//  Safe by design:
//  - Nothing can be edited here. Tapping a song only makes it NEXT; only GO (or a pedal) fires.
//  - Leaving Show mode needs a one-second hold on the exit button.
//  - The connection pill is always visible and buzzes if the link drops.
//

import SwiftUI
import UIKit

struct ShowModeView: View {
    @ObservedObject var store: SetlistStore
    @ObservedObject var coordinator: ConnectionCoordinator
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var usbServer: ConnectionManager
    @ObservedObject var rigs: BackupRigManager
    @Binding var controlButtons: [ControlButton]

    let projectName: String
    let accent: Color
    let isGlobalChannel: Bool
    let globalChannel: Int
    /// Song that was last fired before entering Show mode (becomes NOW)
    let startAfterSongID: UUID?

    /// Fires a song's cue exactly as the main screen does (flash, last-played, MIDI)
    var onFire: (Song) -> Void
    /// Presses one of the show's shared buttons (keeps toggle state in the project)
    var onSharedControl: (ControlButton) -> Void
    var onExit: () -> Void

    @State private var currentID: UUID? = nil
    @State private var nextID: UUID? = nil
    @State private var extraToggles: [UUID: Bool] = [:]
    @State private var extraFaders: [UUID: Double] = [:]
    @State private var goPressed = false
    @State private var showExitHint = false
    @FocusState private var hasKeyFocus: Bool

    private var songs: [Song] { store.activeSongs }

    private var currentSong: Song? {
        guard let id = currentID else { return nil }
        return songs.first(where: { $0.id == id })
    }

    private var nextSong: Song? {
        guard let id = nextID else { return nil }
        return songs.first(where: { $0.id == id })
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                if landscape {
                    HStack(spacing: 0) {
                        setlistColumn
                            .frame(width: min(300, geo.size.width * 0.28))
                        Divider().background(Color.white.opacity(0.15))
                        mainColumn
                    }
                } else {
                    VStack(spacing: 0) {
                        mainColumn
                        Divider().background(Color.white.opacity(0.15))
                        setlistStrip
                            .frame(height: 96)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .focusable()
        .focused($hasKeyFocus)
        // Bluetooth page-turner pedals (AirTurn and similar) and keyboards
        .onKeyPress(.downArrow) { go(); return .handled }
        .onKeyPress(.pageDown) { go(); return .handled }
        .onKeyPress(.rightArrow) { go(); return .handled }
        .onKeyPress(.space) { go(); return .handled }
        .onKeyPress(.upArrow) { stepNext(by: -1); return .handled }
        .onKeyPress(.pageUp) { stepNext(by: -1); return .handled }
        .onKeyPress(.leftArrow) { stepNext(by: -1); return .handled }
        .onAppear {
            setUpPositions()
            hasKeyFocus = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: songs.map(\.id)) { _, _ in
            // The setlist changed under us (another cue list chosen): keep positions valid
            if let id = currentID, !songs.contains(where: { $0.id == id }) { currentID = nil }
            if let id = nextID, !songs.contains(where: { $0.id == id }) { nextID = songs.first?.id }
        }
        .onChange(of: coordinator.activeConnection) { _, newValue in
            if newValue == .none {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // MARK: - Positions

    private func setUpPositions() {
        if let start = startAfterSongID, let i = songs.firstIndex(where: { $0.id == start }) {
            currentID = start
            nextID = i + 1 < songs.count ? songs[i + 1].id : nil
        } else {
            currentID = nil
            nextID = songs.first?.id
        }
    }

    /// GO: fire the next song, it becomes NOW, the one after it becomes NEXT.
    private func go() {
        guard let song = nextSong else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        onFire(song)
        applyRememberedLevels(of: song)
        extraToggles.removeAll()
        extraFaders.removeAll()
        currentID = song.id
        if let i = songs.firstIndex(where: { $0.id == song.id }), i + 1 < songs.count {
            nextID = songs[i + 1].id
        } else {
            nextID = nil
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { goPressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeIn(duration: 0.2)) { goPressed = false }
        }
    }

    /// Pedal "back" or a tap on a song: choose what GO fires next, without sending anything.
    private func stepNext(by offset: Int) {
        guard !songs.isEmpty else { return }
        let base: Int
        if let id = nextID, let i = songs.firstIndex(where: { $0.id == id }) {
            base = i
        } else if let id = currentID, let i = songs.firstIndex(where: { $0.id == id }) {
            base = i + 1
        } else {
            base = 0
        }
        let target = max(0, min(songs.count - 1, base + offset))
        nextID = songs[target].id
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func chooseNext(_ song: Song) {
        nextID = song.id
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Moves shared faders to the levels this song remembers (sends them to the DAW too).
    private func applyRememberedLevels(of song: Song) {
        guard let levels = song.rememberedLevels, !levels.isEmpty else { return }
        for (key, midiValue) in levels {
            guard let b = controlButtons.first(where: { $0.id.uuidString == key && $0.isFader == true }) else { continue }
            let value = max(0, min(127, midiValue))
            sendSharedFader(b, value: value)
        }
    }

    // MARK: - Setlist (landscape column)

    private var setlistColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETLIST")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            setlistRow(index: index, song: song)
                                .id(song.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
                .onChange(of: currentID) { _, id in
                    if let id = id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }
            Text("Tap a song to make it next")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
                .padding(20)
        }
    }

    private func setlistRow(index: Int, song: Song) -> some View {
        let isNow = song.id == currentID
        let isNext = song.id == nextID
        return Button(action: { chooseNext(song) }) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, alignment: .trailing)
                Text(song.name)
                    .font(.system(size: 19, weight: isNow ? .bold : .regular))
                    .foregroundColor(isPlayed(song) ? .white.opacity(0.45) : .white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isNow {
                    Text("NOW").font(.system(size: 11, weight: .bold)).foregroundColor(accent)
                } else if isNext {
                    Text("NEXT").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isNow ? accent.opacity(0.25) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isNow ? accent : (isNext ? Color.white.opacity(0.5) : Color.clear), lineWidth: isNow ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(index + 1), \(song.name)\(isNow ? ", now playing" : "")\(isNext ? ", next" : "")")
        .accessibilityHint("Makes this song next. Press GO to play it.")
    }

    private func isPlayed(_ song: Song) -> Bool {
        guard let id = currentID,
              let now = songs.firstIndex(where: { $0.id == id }),
              let i = songs.firstIndex(where: { $0.id == song.id }) else { return false }
        return i < now
    }

    // MARK: - Setlist (portrait strip)

    private var setlistStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button(action: { chooseNext(song) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(song.name)
                                    .font(.system(size: 15, weight: song.id == currentID ? .bold : .regular))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .frame(width: 150, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(song.id == currentID ? accent.opacity(0.25) : Color.white.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(song.id == nextID ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(song.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: currentID) { _, id in
                if let id = id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    // MARK: - Main column

    private var mainColumn: some View {
        VStack(spacing: 16) {
            topBar
            nowCard
            HStack(spacing: 16) {
                nextCard
                goButton
            }
            .frame(height: 104)
            controlsArea
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(projectName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let list = store.activeCueList {
                    Text(list.name)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer()
            ShowStatusPill(coordinator: coordinator, wifiClient: wifiClient, rigs: rigs)
            exitButton
        }
    }

    private var exitButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 13, weight: .semibold))
            Text(showExitHint ? "Hold to exit" : "Exit")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Capsule().fill(Color.white.opacity(0.1)))
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation { showExitHint = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showExitHint = false } }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onExit()
        }
        .accessibilityLabel("Exit Show mode")
        .accessibilityHint("Touch and hold for one second")
    }

    // MARK: - Now / Next / GO

    private var nowCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOW")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
            if let song = currentSong {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let i = songs.firstIndex(where: { $0.id == song.id }) {
                        Text("\(i + 1)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text(song.name)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                if let notes = song.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(3)
                }
            } else {
                Text("Ready")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                Text("Press GO to start the first song")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(accent.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }

    private var nextCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
            if let song = nextSong {
                Text(song.name)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("End of the set")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var goButton: some View {
        Button(action: go) {
            Text("GO")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundColor(nextSong == nil ? .white.opacity(0.35) : .white)
                .frame(width: 200)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(nextSong == nil ? Color.white.opacity(0.06) : accent.opacity(goPressed ? 0.95 : 0.6)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent, lineWidth: 3))
                .scaleEffect(goPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(nextSong == nil)
        .accessibilityLabel("GO")
        .accessibilityHint(nextSong.map { "Plays \($0.name)" } ?? "End of the set")
    }

    // MARK: - Controls (shared + this song's extras)

    private var sortedShared: [ControlButton] {
        controlButtons.sorted { a, b in
            if a.page != b.page { return a.page < b.page }
            if (a.gridRow ?? 0) != (b.gridRow ?? 0) { return (a.gridRow ?? 0) < (b.gridRow ?? 0) }
            return (a.gridCol ?? 0) < (b.gridCol ?? 0)
        }
    }

    private var sharedButtons: [ControlButton] { sortedShared.filter { $0.isFader != true } }
    private var sharedFaders: [ControlButton] { sortedShared.filter { $0.isFader == true } }
    private var songExtras: [SongExtra] { currentSong?.extras ?? [] }

    private var controlsArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if controlButtons.isEmpty && songExtras.isEmpty {
                    Text("No controls yet. Add them in the main screen's control area.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("CONTROLS")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    HStack(alignment: .top, spacing: 20) {
                        buttonGrid
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        if !sharedFaders.isEmpty || songExtras.contains(where: { $0.style == .fader }) {
                            faderStack
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
        }
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 12)]

    private var buttonGrid: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
            ForEach(sharedButtons) { b in
                ShowControlTile(title: b.title.isEmpty ? "Button" : b.title,
                                symbol: b.symbol,
                                isOn: b.isToggle == true && b.toggleState,
                                isExtra: false,
                                accent: accent) {
                    onSharedControl(b)
                }
            }
            ForEach(songExtras.filter { $0.style != .fader }) { extra in
                ShowControlTile(title: extra.title,
                                symbol: extra.style == .toggle ? "power" : "",
                                isOn: extra.style == .toggle && (extraToggles[extra.id] ?? false),
                                isExtra: true,
                                accent: accent) {
                    pressExtra(extra)
                }
            }
        }
    }

    private var faderStack: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sharedFaders) { b in
                ShowFaderRow(title: b.title.isEmpty ? "Fader" : b.title,
                             isExtra: false,
                             accent: accent,
                             value: Binding(
                                get: { controlButtons.first(where: { $0.id == b.id })?.faderValue ?? 0 },
                                set: { newValue in
                                    let midi = Int((newValue * 127).rounded())
                                    let old = Int(((controlButtons.first(where: { $0.id == b.id })?.faderValue ?? 0) * 127).rounded())
                                    if let i = controlButtons.firstIndex(where: { $0.id == b.id }) {
                                        controlButtons[i].faderValue = newValue
                                    }
                                    if midi != old { sendSharedFader(b, value: midi) }
                                }))
            }
            ForEach(songExtras.filter { $0.style == .fader }) { extra in
                ShowFaderRow(title: extra.title,
                             isExtra: true,
                             accent: accent,
                             value: Binding(
                                get: { extraFaders[extra.id] ?? 0 },
                                set: { newValue in
                                    let midi = Int((newValue * 127).rounded())
                                    let old = Int(((extraFaders[extra.id] ?? 0) * 127).rounded())
                                    extraFaders[extra.id] = newValue
                                    if midi != old { sendExtra(extra, value: midi) }
                                }))
            }
        }
    }

    // MARK: - Sending

    private func channel(_ ch: Int) -> Int { isGlobalChannel ? globalChannel : ch }

    /// Same route as the main screen's faders: ContentView stores the value and sends it.
    private func sendSharedFader(_ b: ControlButton, value: Int) {
        NotificationCenter.default.post(
            name: Notification.Name("cbFaderChanged"),
            object: nil,
            userInfo: ["id": b.id, "channel": b.channel, "cc": b.number, "value": value, "title": b.title])
        // Keep the main screen's fader tile in step
        NotificationCenter.default.post(
            name: Notification.Name("cbUpdateFaderFromDAW"),
            object: nil,
            userInfo: ["buttonID": b.id.uuidString, "value": Double(value) / 127.0])
    }

    private func pressExtra(_ extra: SongExtra) {
        let onValue = extra.kind == .cc ? 127 : max(1, extra.velocity)
        switch extra.style {
        case .toggle:
            let newState = !(extraToggles[extra.id] ?? false)
            extraToggles[extra.id] = newState
            sendExtra(extra, value: newState ? onValue : 0)
        case .button, .fader:
            sendExtra(extra, value: onValue)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func sendExtra(_ extra: SongExtra, value: Int) {
        let kind: MIDIKind = extra.style == .fader ? .cc : extra.kind
        coordinator.sendMIDI(type: kind, channel: channel(extra.channel), number: extra.number,
                             value: value, label: extra.title, buttonID: extra.id.uuidString)
    }
}

// MARK: - Pieces

private struct ShowControlTile: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let isExtra: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if !symbol.isEmpty {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if isExtra {
                    Text("this song")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(isOn ? accent.opacity(0.7) : (isExtra ? accent.opacity(0.16) : Color.white.opacity(0.08))))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isExtra ? accent : Color.white.opacity(0.2), lineWidth: isExtra ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(IOSPressButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "")
    }
}

private struct ShowFaderRow: View {
    let title: String
    let isExtra: Bool
    let accent: Color
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                if isExtra {
                    Text("this song")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accent)
                }
                Spacer()
                Text("\(Int((value * 127).rounded()))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            Slider(value: $value, in: 0...1)
                .tint(accent)
                .accessibilityLabel(title)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(isExtra ? accent.opacity(0.12) : Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isExtra ? accent : Color.clear, lineWidth: 1.5))
    }
}

/// USB / Wi-Fi / backup status. Re-checks every second so it never shows a stale state.
struct ShowStatusPill: View {
    @ObservedObject var coordinator: ConnectionCoordinator
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var rigs: BackupRigManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let status = currentStatus
            HStack(spacing: 8) {
                Circle().fill(status.color).frame(width: 10, height: 10)
                Text(status.text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(status.color.opacity(0.18)))
            .overlay(Capsule().stroke(status.color.opacity(0.6), lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Connection: \(status.text)")
        }
    }

    private var currentStatus: (text: String, color: Color) {
        var parts: [String] = []
        var color: Color = .green
        switch coordinator.activeConnection {
        case .usb:
            parts.append(wifiClient.isStandbyReady ? "USB, Wi-Fi backup ready" : "USB")
        case .wifi:
            parts.append("Wi-Fi")
        case .none:
            parts.append("Not connected")
            color = .red
        }
        switch rigs.health {
        case .none:
            break
        case .ok:
            parts.append("Backup Mac OK")
        case .offline:
            parts.append("Backup Mac offline")
            if color != .red { color = .orange }
        case .sameMac:
            parts.append("Backup is the same Mac")
            if color != .red { color = .orange }
        }
        if coordinator.activeConnection == .none && rigs.health == .ok {
            // The show carries on through the backup
            parts = ["Main offline", "Backup Mac playing"]
            color = .orange
        }
        return (parts.joined(separator: " · "), color)
    }
}
