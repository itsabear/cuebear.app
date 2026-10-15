//
//  ShowModeView.swift — Cue Bear Next (v1.3)
//
//  The stage screen: the current song large, the next song under it, one big GO,
//  then the show's shared controls plus this song's extras.
//
//  The app's home screen (the Show half of Show | Build). The top bar, Lock and the connection
//  pill live in ModeBar.swift.
//  Safe by design:
//  - Nothing can be edited here. Tapping a song only makes it NEXT; only GO (or a pedal) fires.
//  - The iPad buzzes if the link drops.
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

    let isGlobalChannel: Bool
    let globalChannel: Int
    /// Song that was last fired before entering Show mode (becomes NOW)
    let startAfterSongID: UUID?

    /// Fires a song's cue exactly as the main screen does (flash, last-played, MIDI)
    var onFire: (Song) -> Void
    /// Presses one of the show's shared buttons (keeps toggle state in the project)
    var onSharedControl: (ControlButton) -> Void
    /// Empty cue list: jump to Build › Setlist
    var onBuild: () -> Void = {}

    @State private var currentID: UUID? = nil
    @State private var nextID: UUID? = nil
    @State private var extraToggles: [UUID: Bool] = [:]
    @State private var extraFaders: [UUID: Double] = [:]
    @State private var goPressed = false
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
                CBColor.stage.ignoresSafeArea()
                if landscape {
                    HStack(spacing: 0) {
                        setlistColumn
                            .frame(width: min(300, geo.size.width * 0.28))
                        Rectangle().fill(CBColor.separator).frame(width: CBSize.hairline)
                        mainColumn
                    }
                } else {
                    VStack(spacing: 0) {
                        mainColumn
                        Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
                        setlistStrip
                            .frame(height: 96)
                    }
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
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
            CBSectionLabel("Setlist")
                .padding(.horizontal, CBSpace.xl)
                .padding(.top, CBSpace.xl)
                .padding(.bottom, CBSpace.s)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: CBSpace.s) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            setlistRow(index: index, song: song)
                                .id(song.id)
                        }
                    }
                    .padding(.horizontal, CBSpace.m)
                    .padding(.bottom, CBSpace.xl)
                }
                .onChange(of: currentID) { _, id in
                    if let id = id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }
            Text("Tap a song to make it next")
                .font(.cb(.small))
                .foregroundStyle(CBColor.textTertiary)
                .padding(CBSpace.xl)
        }
        .background(CBColor.background)
    }

    private func setlistRow(index: Int, song: Song) -> some View {
        let isNow = song.id == currentID
        let isNext = song.id == nextID
        return Button(action: { chooseNext(song) }) {
            HStack(spacing: CBSpace.m) {
                Text("\(index + 1)")
                    .font(.cbMono(.body, .semibold))
                    .foregroundStyle(CBColor.textTertiary)
                    .frame(width: 28, alignment: .trailing)
                Text(song.name)
                    .font(.cb(.large, isNow ? .bold : .regular))
                    .foregroundStyle(isPlayed(song) ? CBColor.textTertiary : CBColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: CBSpace.xs)
                if isNow {
                    CBTag(text: "NOW", color: CBColor.highlight)
                } else if isNext {
                    CBTag(text: "NEXT", color: CBColor.surfaceRaised)
                }
            }
            .padding(.horizontal, CBSpace.m)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: CBRadius.control)
                    .fill(isNow ? CBColor.highlight.opacity(0.25) : CBColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CBRadius.control)
                    .stroke(isNow ? CBColor.highlight : (isNext ? CBColor.strokeStrong : Color.clear),
                            lineWidth: isNow ? CBSize.selection : CBSize.hairline)
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
                HStack(spacing: CBSpace.s) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button(action: { chooseNext(song) }) {
                            VStack(alignment: .leading, spacing: CBSpace.xs) {
                                Text("\(index + 1)")
                                    .font(.cbMono(.caption, .semibold))
                                    .foregroundStyle(CBColor.textTertiary)
                                Text(song.name)
                                    .font(.cb(.body, song.id == currentID ? .bold : .regular))
                                    .foregroundStyle(CBColor.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(CBSpace.m)
                            .frame(width: 150, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: CBRadius.control)
                                .fill(song.id == currentID ? CBColor.highlight.opacity(0.25) : CBColor.surface))
                            .overlay(RoundedRectangle(cornerRadius: CBRadius.control)
                                .stroke(song.id == currentID ? CBColor.highlight : (song.id == nextID ? CBColor.strokeStrong : Color.clear),
                                        lineWidth: song.id == currentID ? CBSize.selection : CBSize.hairline))
                        }
                        .buttonStyle(.plain)
                        .id(song.id)
                    }
                }
                .padding(.horizontal, CBSpace.l)
                .padding(.vertical, CBSpace.m)
            }
            .background(CBColor.background)
            .onChange(of: currentID) { _, id in
                if let id = id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    // MARK: - Main column

    @ViewBuilder
    private var mainColumn: some View {
        if songs.isEmpty {
            VStack(spacing: CBSpace.l) {
                Text("This cue list has no songs yet")
                    .font(.cb(.title, .bold))
                    .foregroundStyle(CBColor.textPrimary)
                Text("Add songs in Build, then come back here to play them.")
                    .font(.cb(.body))
                    .foregroundStyle(CBColor.textSecondary)
                Button("Add songs in Build", action: onBuild)
                    .buttonStyle(.cbPrimary)
            }
            .multilineTextAlignment(.center)
            .padding(CBSpace.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            playColumn
        }
    }

    private var playColumn: some View {
        VStack(spacing: CBSpace.l) {
            nowCard
            HStack(spacing: CBSpace.l) {
                nextCard
                goButton
            }
            .frame(height: 104)
            controlsArea
            Spacer(minLength: 0)
        }
        .padding(CBSpace.xl)
    }

    // MARK: - Now / Next / GO

    private var nowCard: some View {
        VStack(alignment: .leading, spacing: CBSpace.s) {
            CBSectionLabel("Now", color: CBColor.highlight)
            if let song = currentSong {
                HStack(alignment: .firstTextBaseline, spacing: CBSpace.m) {
                    if let i = songs.firstIndex(where: { $0.id == song.id }) {
                        Text("\(i + 1)")
                            .font(.cb(.heading, .bold))
                            .foregroundStyle(CBColor.textTertiary)
                    }
                    Text(song.name)
                        .font(.cb(.display, .bold))
                        .foregroundStyle(CBColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.cb(.title))
                        .foregroundStyle(CBColor.textSecondary)
                        .lineLimit(1)
                }
                if let notes = song.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.cb(.large))
                        .foregroundStyle(CBColor.textSecondary)
                        .lineLimit(3)
                }
            } else {
                Text("Ready")
                    .font(.cb(.display, .bold))
                    .foregroundStyle(CBColor.textPrimary)
                Text("Press GO to start the first song")
                    .font(.cb(.large))
                    .foregroundStyle(CBColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cbCard(fill: CBColor.highlight.opacity(0.14), outline: CBColor.highlight, padding: CBSpace.xl)
        .accessibilityElement(children: .combine)
    }

    private var nextCard: some View {
        VStack(alignment: .leading, spacing: CBSpace.xs) {
            CBSectionLabel("Next")
            if let song = nextSong {
                Text(song.name)
                    .font(.cb(.title, .bold))
                    .foregroundStyle(CBColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("End of the set")
                    .font(.cb(.title, .bold))
                    .foregroundStyle(CBColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .cbCard(outline: CBColor.stroke, outlineWidth: CBSize.hairline, padding: CBSpace.xl)
        .accessibilityElement(children: .combine)
    }

    /// Same look as the GO button on the main screen: white, black type.
    private var goButton: some View {
        Button(action: go) {
            Text("GO")
                .font(.cb(.display, .bold))
                .foregroundStyle(nextSong == nil ? CBColor.textDisabled : CBColor.onPrimary)
                .frame(width: 200)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: CBRadius.card)
                    .fill(nextSong == nil ? CBColor.surface : CBColor.primary.opacity(goPressed ? 0.7 : 1)))
                .scaleEffect(goPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(nextSong == nil)
        .accessibilityLabel("GO")
        .accessibilityHint(nextSong.map { "Plays \($0.name)" } ?? "End of the set")
    }

    // MARK: - Controls (shared + this song's extras)


    private var songExtras: [SongExtra] { currentSong?.extras ?? [] }

    /// Shared controls in board order, then this song's extras.
    private var boardItems: [BoardItem] {
        controlButtons.inShowOrder.map { BoardItem(control: $0) }
            + songExtras.map { BoardItem(extra: $0, isOn: extraToggles[$0.id] ?? false, value: extraFaders[$0.id] ?? 0) }
    }

    private var controlsArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CBSpace.m) {
                if controlButtons.isEmpty && songExtras.isEmpty {
                    Text("No controls yet. Add them in Build › Controls.")
                        .font(.cb(.body))
                        .foregroundStyle(CBColor.textTertiary)
                } else {
                    CBSectionLabel("Controls")
                    ControlsBoard(
                        items: boardItems,
                        mode: .play,
                        onPress: { item in
                            if item.isExtra {
                                if let extra = songExtras.first(where: { $0.id == item.id }) { pressExtra(extra) }
                            } else if let b = controlButtons.first(where: { $0.id == item.id }) {
                                onSharedControl(b)
                            }
                        },
                        onFader: { item, newValue in
                            let midi = Int((newValue * 127).rounded())
                            if item.isExtra {
                                guard let extra = songExtras.first(where: { $0.id == item.id }) else { return }
                                let old = Int(((extraFaders[extra.id] ?? 0) * 127).rounded())
                                extraFaders[extra.id] = newValue
                                if midi != old { sendExtra(extra, value: midi) }
                            } else if let i = controlButtons.firstIndex(where: { $0.id == item.id }) {
                                let b = controlButtons[i]
                                let old = Int(((b.faderValue ?? 0) * 127).rounded())
                                controlButtons[i].faderValue = newValue
                                if midi != old { sendSharedFader(b, value: midi) }
                            }
                        }
                    )
                }
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

/// USB / Wi-Fi / backup status. Re-checks every second so it never shows a stale state.
struct ShowStatusPill: View {
    @ObservedObject var coordinator: ConnectionCoordinator
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var rigs: BackupRigManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let status = currentStatus
            CBPill(text: status.text, color: status.color)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connection: \(status.text)")
        }
    }

    private var currentStatus: (text: String, color: Color) {
        var parts: [String] = []
        var color: Color = CBColor.success
        switch coordinator.activeConnection {
        case .usb:
            parts.append(wifiClient.isStandbyReady ? "USB, Wi-Fi backup ready" : "USB")
        case .wifi:
            parts.append("Wi-Fi")
        case .none:
            parts.append("Not connected")
            color = CBColor.danger
        }
        switch rigs.health {
        case .none:
            break
        case .ok:
            parts.append("Backup Mac OK")
        case .offline:
            parts.append("Backup Mac offline")
            if color != CBColor.danger { color = CBColor.warning }
        case .sameMac:
            parts.append("Backup is the same Mac")
            if color != CBColor.danger { color = CBColor.warning }
        }
        if coordinator.activeConnection == .none && rigs.health == .ok {
            // The show carries on through the backup
            parts = ["Main offline", "Backup Mac playing"]
            color = CBColor.warning
        }
        return (parts.joined(separator: " · "), color)
    }
}
