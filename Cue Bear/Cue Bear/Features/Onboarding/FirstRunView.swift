//
//  FirstRunView.swift — Cue Bear Next (v1.3)
//
//  Replaces the four welcome slides and the "beta" card. The user is already inside a demo show;
//  this sheet is a checklist that ticks itself as the Mac connection comes up, plus a short
//  setup guide for their DAW. Also opened from the menu ("Getting Started").
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct FirstRunView: View {
    @ObservedObject var usbServer: ConnectionManager
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var coordinator: ConnectionCoordinator
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
        VStack(spacing: 0) {
            CBSheetHeader(title: "Getting started", trailingTitle: "Done", trailingAction: onDone)
            ScrollView {
                VStack(alignment: .leading, spacing: CBSpace.xl) {
                    header
                    VStack(alignment: .leading, spacing: CBSpace.m) {
                        stepBridge
                        stepConnect
                        stepMIDI
                    }
                    dawGuide
                }
                .padding(CBSpace.xl)
            }
            Button(action: onTryShowMode) {
                Label("Try Show mode", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(CBButtonStyle(kind: .primary, fullWidth: true, height: CBSize.largeControl))
            .padding(.horizontal, CBSpace.xl)
            .padding(.vertical, CBSpace.m)
        }
        .cbSheetChrome()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: CBSpace.s) {
            Text("Welcome to Cue Bear")
                .font(.cb(.heading, .bold))
            Text("You're in a demo show already. Try it in Show mode, then connect your Mac. Each step below ticks itself when it works.")
                .font(.cb(.body))
                .foregroundStyle(CBColor.textSecondary)
        }
    }

    // MARK: - Steps

    private var stepBridge: some View {
        ChecklistStep(number: 1, title: "Cue Bear Bridge running on your Mac", done: bridgeFound) {
            HStack(alignment: .top, spacing: CBSpace.l) {
                VStack(alignment: .leading, spacing: CBSpace.m) {
                    Text("Get the free Bridge app for your Mac at cuebear.app/bridge, then open it. It lives in the menu bar.")
                        .foregroundStyle(CBColor.textSecondary)
                    Link(destination: URL(string: Self.bridgeURL)!) {
                        Label("Open cuebear.app/bridge", systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(.cbSecondary)
                }
                Spacer(minLength: CBSpace.s)
                QRCodeView(text: Self.bridgeURL)
                    .frame(width: 96, height: 96)
                    .accessibilityLabel("QR code for cuebear.app/bridge")
            }
        }
    }

    private var stepConnect: some View {
        ChecklistStep(number: 2, title: connectTitle, done: isConnected) {
            VStack(alignment: .leading, spacing: CBSpace.m) {
                if isConnected {
                    Text(coordinator.activeConnection == .usb ? "Connected by USB cable." : "Connected over Wi-Fi.")
                        .foregroundStyle(CBColor.textSecondary)
                } else {
                    Text("Plug in the USB cable, or pick your Mac below to use Wi-Fi. The first time, the Mac shows a 6-digit code: check it matches the iPad and click Allow.")
                        .foregroundStyle(CBColor.textSecondary)
                    ForEach(wifiClient.discovered) { item in
                        Button(action: { onConnectWiFi(item) }) {
                            Label("Connect to \(item.name)", systemImage: "wifi")
                        }
                        .buttonStyle(.cbSecondary)
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
        ChecklistStep(number: 3, title: "MIDI reaching your DAW", done: midiConfirmed) {
            VStack(alignment: .leading, spacing: CBSpace.m) {
                Text("In your DAW, turn on the MIDI input called \"Bear Bridge\". Then send a test note (middle C) and watch for it.")
                    .foregroundStyle(CBColor.textSecondary)
                HStack(spacing: CBSpace.m) {
                    Button(action: {
                        onSendTest()
                        testSent = true
                    }) {
                        Label("Send test note", systemImage: "music.note")
                    }
                    .buttonStyle(.cbSecondary)
                    .disabled(!isConnected)

                    if testSent && !midiConfirmed {
                        Button("I saw it") { midiConfirmed = true }
                            .buttonStyle(.cbPrimary)
                    }
                }
                if !isConnected {
                    Text("Connect first (step 2).")
                        .font(.cb(.small))
                        .foregroundStyle(CBColor.textTertiary)
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
        VStack(alignment: .leading, spacing: CBSpace.m) {
            Text("Which DAW do you use?")
                .font(.cb(.title, .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CBSpace.s) {
                    ForEach(Self.guides) { guide in
                        DAWChip(title: guide.id, isChosen: chosenDAW == guide.id) {
                            chosenDAW = guide.id
                        }
                    }
                }
            }
            if let guide = Self.guides.first(where: { $0.id == chosenDAW }) {
                VStack(alignment: .leading, spacing: CBSpace.s) {
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: CBSpace.m) {
                            Text("\(index + 1).")
                                .font(.cb(.body, .bold))
                                .foregroundStyle(CBColor.highlight)
                                .frame(width: 22, alignment: .trailing)
                            Text(step)
                                .font(.cb(.body))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cbCard()
            }
        }
    }
}

// MARK: - Pieces

/// A choice chip: white when chosen, like the primary button.
private struct DAWChip: View {
    let title: String
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.cb(.body, .semibold))
                .foregroundStyle(isChosen ? CBColor.onPrimary : CBColor.textPrimary)
                .padding(.horizontal, CBSpace.l)
                .frame(height: CBSize.control)
                .background(RoundedRectangle(cornerRadius: CBRadius.control)
                    .fill(isChosen ? CBColor.primary : CBColor.surface))
                .overlay(RoundedRectangle(cornerRadius: CBRadius.control)
                    .stroke(isChosen ? Color.clear : CBColor.stroke, lineWidth: CBSize.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

private struct ChecklistStep<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: CBSpace.m) {
            ZStack {
                Circle()
                    .fill(done ? CBColor.success.opacity(0.18) : Color.clear)
                    .overlay(Circle().stroke(done ? CBColor.success : CBColor.strokeStrong,
                                             style: StrokeStyle(lineWidth: CBSize.selection, dash: done ? [] : [4, 3])))
                if done {
                    Image(systemName: "checkmark")
                        .font(.cbIcon(.small, .bold))
                        .foregroundStyle(CBColor.success)
                } else {
                    Text("\(number)")
                        .font(.cb(.small, .bold))
                        .foregroundStyle(CBColor.textSecondary)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: CBSpace.s) {
                Text(title)
                    .font(.cb(.large, .bold))
                content()
                    .font(.cb(.body))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cbCard()
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
                .padding(CBSpace.s)
                .background(RoundedRectangle(cornerRadius: CBRadius.small).fill(Color.white))
        } else {
            RoundedRectangle(cornerRadius: CBRadius.small).stroke(CBColor.stroke)
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
