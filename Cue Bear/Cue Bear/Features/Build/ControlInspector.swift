//
//  ControlInspector.swift — Cue Bear Next
//
//  Build › Controls, right side: one shared control (button, toggle or fader).
//  Shared controls are on every song; for one song only, add an extra in that song instead.
//

import SwiftUI
import UIKit

struct ControlInspector: View {
    let control: ControlButton
    let isFirst: Bool
    let isLast: Bool
    var conflictName: (MIDIKind, Int, Int) -> String?
    var onChange: (ControlButton) -> Void
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void
    var onDelete: () -> Void

    @State private var draft: ControlButton
    @State private var isLearning = false

    private enum Style: String, CaseIterable { case button = "Button", toggle = "Toggle", fader = "Fader" }

    private static let symbols = ["", "play.fill", "stop.fill", "pause.fill", "backward.end.fill", "forward.end.fill",
                                  "repeat", "metronome", "waveform", "mic.fill", "speaker.wave.2.fill",
                                  "music.note", "sparkles", "bolt.fill", "star.fill", "power"]

    init(control: ControlButton, isFirst: Bool, isLast: Bool,
         conflictName: @escaping (MIDIKind, Int, Int) -> String?,
         onChange: @escaping (ControlButton) -> Void,
         onMoveEarlier: @escaping () -> Void,
         onMoveLater: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.control = control
        self.isFirst = isFirst
        self.isLast = isLast
        self.conflictName = conflictName
        self.onChange = onChange
        self.onMoveEarlier = onMoveEarlier
        self.onMoveLater = onMoveLater
        self.onDelete = onDelete
        _draft = State(initialValue: control)
    }

    private var style: Binding<Style> {
        Binding(
            get: {
                if draft.isFader == true { return .fader }
                return draft.isToggle == true ? .toggle : .button
            },
            set: { newStyle in
                switch newStyle {
                case .button:
                    draft.isFader = nil
                    draft.isToggle = nil
                    if draft.symbol.isEmpty { draft.symbol = "square.grid.2x2.fill" }
                case .toggle:
                    draft.isFader = nil
                    draft.isToggle = true
                    if draft.symbol.isEmpty { draft.symbol = "power" }
                case .fader:
                    draft.isFader = true
                    draft.isToggle = nil
                    draft.kind = .cc
                    draft.symbol = ""
                    if draft.faderValue == nil { draft.faderValue = 0 }
                }
            })
    }

    private var isFader: Bool { draft.isFader == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CBSpace.xl) {
                HStack(spacing: CBSpace.m) {
                    TextField("Control name", text: $draft.title)
                        .font(.cb(.heading, .bold))
                        .foregroundStyle(CBColor.textPrimary)
                        .submitLabel(.done)
                    Button("Delete", action: onDelete)
                        .buttonStyle(.cbDestructive)
                }

                VStack(alignment: .leading, spacing: CBSpace.m) {
                    CBSectionLabel("Type")
                    Picker("Type", selection: style) {
                        ForEach(Style.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(styleHint)
                        .font(.cb(.small))
                        .foregroundStyle(CBColor.textTertiary)
                }
                .cbCard()

                sendsCard

                if !isFader {
                    iconCard
                }

                VStack(alignment: .leading, spacing: CBSpace.m) {
                    CBSectionLabel("Order in Show")
                    HStack(spacing: CBSpace.s) {
                        Button(action: onMoveEarlier) { Label("Earlier", systemImage: "arrow.up") }
                            .buttonStyle(CBButtonStyle(kind: .secondary, fullWidth: true))
                            .disabled(isFirst)
                        Button(action: onMoveLater) { Label("Later", systemImage: "arrow.down") }
                            .buttonStyle(CBButtonStyle(kind: .secondary, fullWidth: true))
                            .disabled(isLast)
                    }
                }
                .cbCard()

                Text("Shared controls are on every song. For one song only, add an extra in that song.")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.textTertiary)
            }
            .padding(CBSpace.xl)
        }
        .onChange(of: draft) { _, newValue in onChange(newValue) }
        .onChange(of: control) { _, newValue in
            if newValue != draft { draft = newValue }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("cbMIDIInputFromDAW"))) { notif in
            learn(from: notif)
        }
    }

    private var styleHint: String {
        switch style.wrappedValue {
        case .button: return "Sends once each time you press it."
        case .toggle: return "Press for on, press again for off."
        case .fader: return "Sends a CC value from 0 to 127 as you move it."
        }
    }

    // MARK: - Sends

    private var sendsCard: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            CBSectionLabel("Sends")
            if !isFader {
                Picker("Message", selection: $draft.kind) {
                    Text("CC").tag(MIDIKind.cc)
                    Text("Note").tag(MIDIKind.note)
                }
                .pickerStyle(.segmented)
            }
            Stepper(value: $draft.number, in: 0...127) {
                InspectorValue(title: isFader || draft.kind == .cc ? "CC number" : "Note", value: "\(draft.number)")
            }
            Stepper(value: $draft.channel, in: 1...16) {
                InspectorValue(title: "Channel", value: "\(draft.channel)")
            }
            if !isFader && draft.kind == .note {
                Stepper(value: $draft.velocity, in: 1...127) {
                    InspectorValue(title: "Velocity", value: "\(draft.velocity)")
                }
            }
            HStack {
                Button(action: { isLearning.toggle() }) {
                    Label(isLearning ? "Listening… move a control in your DAW" : "Learn from DAW",
                          systemImage: isLearning ? "dot.radiowaves.left.and.right" : "wand.and.stars")
                }
                .buttonStyle(CBButtonStyle(kind: isLearning ? .highlight : .secondary))
                Spacer(minLength: 0)
            }
            let kind: MIDIKind = isFader ? .cc : draft.kind
            if let other = conflictName(kind, draft.channel, draft.number), other != draft.title {
                Label("\(other) sends the same message", systemImage: "exclamationmark.triangle.fill")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.warning)
            }
        }
        .cbCard()
    }

    // MARK: - Icon

    private var iconCard: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            CBSectionLabel("Icon")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: CBSpace.s)], spacing: CBSpace.s) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    let chosen = draft.symbol == symbol
                    Button(action: { draft.symbol = symbol }) {
                        Group {
                            if symbol.isEmpty {
                                Text("None").font(.cb(.micro))
                            } else {
                                Image(systemName: symbol).font(.cbIcon(.body))
                            }
                        }
                        .foregroundStyle(chosen ? CBColor.textPrimary : CBColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surfaceRaised))
                        .overlay(RoundedRectangle(cornerRadius: CBRadius.control)
                            .stroke(chosen ? CBColor.highlight : CBColor.stroke, lineWidth: chosen ? CBSize.selection : CBSize.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol.isEmpty ? "No icon" : symbol)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }
        .cbCard()
    }

    // MARK: - MIDI learn

    private func learn(from notif: Notification) {
        guard isLearning, let info = notif.userInfo as? [String: Any],
              let type = info["type"] as? String, let channel = info["channel"] as? Int else { return }
        if type == "cc", let cc = info["cc"] as? Int {
            draft.kind = .cc
            draft.number = cc
            draft.channel = channel
            isLearning = false
        } else if type == "note", let note = info["note"] as? Int, !isFader {
            draft.kind = .note
            draft.number = note
            draft.channel = channel
            isLearning = false
        }
        if !isLearning { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}
