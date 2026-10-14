//
//  FirstRunView.swift — Cue Bear Next (v1.3)
//
//  Replaces the four welcome slides and the "beta" card. The user is already inside a demo show;
//  this sheet is a checklist that ticks itself as the Mac connection comes up, plus a short
//  setup guide for their DAW. Also opened from the menu ("Getting Started").
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct FirstRunView: View {
    @ObservedObject var usbServer: ConnectionManager
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var coordinator: ConnectionCoordinator
    let accent: Color
    var onSendTest: () -> Void
    var onConnectWiFi: (BridgeOutput.Item) -> Void
    var onTryShowMode: () -> Void
    var onDone: () -> Void

    @AppStorage("firstRunDAW") private var chosenDAW: String = ""
    @AppStorage("firstRunMIDIConfirmed") private var midiConfirmed = false
    @State private var testSent = false

    private static let bridgeURL = "https://cuebear.app/bridge"

    private var bridgeFound: Bool {
        usbServer.usbBridgeAvailable || !wifiClient.discovered.isEmpty || isConnected
    }
    private var isConnected: Bool { coordinator.activeConnection != .none }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    VStack(alignment: .leading, spacing: 18) {
                        stepBridge
                        stepConnect
                        stepMIDI
                    }
                    dawGuide
                }
                .padding(24)
            }
            .navigationTitle("Getting started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone).fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(action: onTryShowMode) {
                        Label("Try Show mode", systemImage: "play.rectangle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to Cue Bear")
                .font(.system(size: 30, weight: .bold))
            Text("You're in a demo show already. Try it in Show mode, then connect your Mac. Each step below ticks itself when it works.")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Steps

    private var stepBridge: some View {
        ChecklistStep(number: 1, title: "Cue Bear Bridge running on your Mac", done: bridgeFound, accent: accent) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Get the free Bridge app for your Mac at cuebear.app/bridge, then open it. It lives in the menu bar.")
                        .foregroundColor(.secondary)
                    Link("Open cuebear.app/bridge", destination: URL(string: Self.bridgeURL)!)
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer(minLength: 8)
                QRCodeView(text: Self.bridgeURL)
                    .frame(width: 96, height: 96)
                    .accessibilityLabel("QR code for cuebear.app/bridge")
            }
        }
    }

    private var stepConnect: some View {
        ChecklistStep(number: 2, title: connectTitle, done: isConnected, accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                if isConnected {
                    Text(coordinator.activeConnection == .usb ? "Connected by USB cable." : "Connected over Wi-Fi.")
                        .foregroundColor(.secondary)
                } else {
                    Text("Plug in the USB cable, or pick your Mac below to use Wi-Fi. The first time, the Mac shows a 6-digit code: check it matches the iPad and click Allow.")
                        .foregroundColor(.secondary)
                    ForEach(wifiClient.discovered) { item in
                        Button(action: { onConnectWiFi(item) }) {
                            Label("Connect to \(item.name)", systemImage: "wifi")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                    }
                }
            }
        }
    }

    private var connectTitle: String {
        if coordinator.activeConnection == .usb, let name = usbServer.connectedComputerName, !name.isEmpty {
            return "Connected to \(name)"
        }
        if coordinator.activeConnection == .wifi, let name = wifiClient.current?.name {
            return "Connected to \(name)"
        }
        return "Connect to your Mac"
    }

    private var stepMIDI: some View {
        ChecklistStep(number: 3, title: "MIDI reaching your DAW", done: midiConfirmed, accent: accent) {
            VStack(alignment: .leading, spacing: 10) {
                Text("In your DAW, turn on the MIDI input called \"Bear Bridge\". Then send a test note (middle C) and watch for it.")
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button(action: {
                        onSendTest()
                        testSent = true
                    }) {
                        Label("Send test note", systemImage: "music.note")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .disabled(!isConnected)

                    if testSent && !midiConfirmed {
                        Button("I saw it") { midiConfirmed = true }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                    }
                }
                if !isConnected {
                    Text("Connect first (step 2).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - DAW guide

    private struct DAWGuide: Identifiable {
        let id: String
        let steps: [String]
    }

    private static let guides: [DAWGuide] = [
        DAWGuide(id: "Ableton Live", steps: [
            "Open Settings, then Link, Tempo & MIDI.",
            "Under MIDI Ports, turn on Track and Remote for the input \"Bear Bridge\".",
            "Press ⌘M for MIDI Map Mode, click a control in Live, then press the matching control in Cue Bear.",
            "Press ⌘M again to finish."
        ]),
        DAWGuide(id: "Logic Pro", steps: [
            "Logic picks up \"Bear Bridge\" as a MIDI input automatically.",
            "Choose Logic Pro > Control Surfaces > Learn Assignment (⌘L).",
            "Click the parameter in Logic, then press the matching control in Cue Bear.",
            "Close the Learn window when you're done."
        ]),
        DAWGuide(id: "MainStage", steps: [
            "Switch to Layout or Edit mode and select a screen control.",
            "Click Learn, then press the matching control in Cue Bear.",
            "For song changes, map each Cue Bear song's cue the same way."
        ]),
        DAWGuide(id: "QLab", steps: [
            "In Workspace Settings > MIDI, make sure \"Bear Bridge\" is enabled.",
            "Select a cue, open its Triggers tab and turn on MIDI Trigger.",
            "Click Capture, then press the matching song or control in Cue Bear."
        ]),
        DAWGuide(id: "Other", steps: [
            "Look for a MIDI input called \"Bear Bridge\" and turn it on.",
            "Most apps have a MIDI Learn button: click it, pick a setting, then press the control in Cue Bear."
        ])
    ]

    private var dawGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which DAW do you use?")
                .font(.system(size: 20, weight: .semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.guides) { guide in
                        Button(action: { chosenDAW = guide.id }) {
                            Text(guide.id)
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(Capsule().fill(chosenDAW == guide.id ? accent.opacity(0.22) : Color.secondary.opacity(0.12)))
                                .overlay(Capsule().stroke(chosenDAW == guide.id ? accent : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let guide = Self.guides.first(where: { $0.id == chosenDAW }) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(accent)
                                .frame(width: 22, alignment: .trailing)
                            Text(step)
                                .font(.system(size: 15))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
            }
        }
    }
}

// MARK: - Pieces

private struct ChecklistStep<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Color.green.opacity(0.18) : Color.clear)
                    .overlay(Circle().stroke(done ? Color.green : accent, style: StrokeStyle(lineWidth: 2, dash: done ? [] : [4, 3])))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accent)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                content()
                    .font(.system(size: 15))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.06)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(number): \(title)\(done ? ", done" : "")")
    }
}

/// A QR code drawn with Core Image (no network or bundled image needed).
private struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = Self.makeImage(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
        } else {
            RoundedRectangle(cornerRadius: 8).stroke(Color.secondary)
        }
    }

    private static func makeImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
