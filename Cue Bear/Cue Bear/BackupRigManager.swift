//
//  BackupRigManager.swift — Cue Bear Next (v1.3)
//
//  Two computers at once: every press goes to the main computer (USB or Wi-Fi, as before)
//  AND to a backup Mac over the network, so a playback rig survives a crash.
//
//  - The backup Mac runs the Bridge too; the iPad pairs with it once (same pairing screen).
//  - Only the main computer moves the iPad's faders (the backup link ignores DAW input).
//  - The backup must be a different Mac from the main one; if it's the same, nothing is doubled.
//

import Foundation
import Combine
import SwiftUI

final class BackupRigManager: ObservableObject {
    static let shared = BackupRigManager()

    private static let backupNameKey = "CueBearNext.BackupMacName"
    private static let sendToBothKey = "CueBearNext.SendToBoth"

    /// The network name of the backup Mac (as listed under Wi-Fi in Connections), or nil for none.
    @Published private(set) var backupName: String?
    /// "Both" in the Connections sheet. Off = main computer only.
    @Published var sendToBoth: Bool {
        didSet { UserDefaults.standard.set(sendToBoth, forKey: Self.sendToBothKey) }
    }
    /// The backup link is up and ready for MIDI.
    @Published private(set) var isBackupConnected = false
    /// The chosen backup turned out to be the same Mac as the main connection.
    @Published private(set) var isSameAsMain = false

    /// The link to the backup Mac. A second, independent BridgeOutput.
    let client = BridgeOutput()

    private weak var mainWiFi: BridgeOutput?
    private weak var usbServer: ConnectionManager?
    private var cancellables = Set<AnyCancellable>()
    private var started = false
    private var tint: Color = .accentColor

    private init() {
        backupName = UserDefaults.standard.string(forKey: Self.backupNameKey)
        sendToBoth = UserDefaults.standard.object(forKey: Self.sendToBothKey) as? Bool ?? true
        client.forwardsDAWInput = false
    }

    /// True when a backup Mac has been chosen and "Both" is on.
    var isActive: Bool { backupName != nil && sendToBoth }

    // MARK: - Lifecycle

    /// Called once at launch, after the main connections are configured.
    func configure(mainWiFi: BridgeOutput, usbServer: ConnectionManager, tint: Color) {
        self.mainWiFi = mainWiFi
        self.usbServer = usbServer
        self.tint = tint
        guard !started else { return }
        started = true

        client.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isBackupConnected = connected
                self?.refreshSameAsMain()
            }
            .store(in: &cancellables)

        // Connect as soon as the chosen Mac shows up on the network
        client.$discovered
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.connectIfNeeded() }
            .store(in: &cancellables)

        // The backup Mac's pairing code appears in the same window as the main one
        client.$pairingPrompt
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                guard let self = self else { return }
                PairingWindowPresenter.shared.setVisible(showing, wifiClient: self.client, tint: self.tint)
            }
            .store(in: &cancellables)

        client.start()
        connectIfNeeded()
    }

    // MARK: - Choosing the backup

    /// Choose the backup Mac by its network name (nil = no backup computer).
    func setBackup(_ item: BridgeOutput.Item?) {
        if let item = item {
            backupName = item.name
            UserDefaults.standard.set(item.name, forKey: Self.backupNameKey)
            client.connect(to: item)
        } else {
            backupName = nil
            UserDefaults.standard.removeObject(forKey: Self.backupNameKey)
            client.disconnect()
        }
        refreshSameAsMain()
    }

    private func connectIfNeeded() {
        guard let name = backupName, !client.isConnected, !client.isConnecting, client.current == nil,
              let item = client.discovered.first(where: { $0.name == name }) else { return }
        client.connect(to: item)
    }

    // MARK: - Sending

    /// Mirror one message to the backup Mac. Called by ConnectionCoordinator after the main send.
    func forward(type: MIDIKind, channel: Int, number: Int, value: Int, label: String, buttonID: String) {
        guard isActive, client.isConnected else { return }
        refreshSameAsMain()
        guard !isSameAsMain else { return }   // never send the same message twice to one Mac
        switch type {
        case .cc:
            client.sendCC(channel: channel, cc: number, value: value, label: label, buttonID: buttonID)
        case .note:
            client.sendNote(channel: channel, note: number, velocity: value, label: label, buttonID: buttonID)
        }
    }

    private func refreshSameAsMain() {
        guard let backupID = client.currentBridgeID else { isSameAsMain = false; return }
        let mainIDs = [mainWiFi?.currentBridgeID, usbServer?.usbBridgeID].compactMap { $0 }
        let same = mainIDs.contains(backupID)
        if same != isSameAsMain { isSameAsMain = same }
    }

    // MARK: - Status text (Connections sheet and Show mode pill)

    enum Health { case none, ok, offline, sameMac }

    var health: Health {
        guard backupName != nil, sendToBoth else { return .none }
        if isSameAsMain { return .sameMac }
        return isBackupConnected ? .ok : .offline
    }
}

// MARK: - Connections sheet section

/// "Backup computer" section of the Connections sheet.
struct BackupComputerSection: View {
    @ObservedObject var rigs: BackupRigManager
    @ObservedObject var client: BridgeOutput
    let mainName: String?
    let rowBackground: Color
    let headerColor: Color

    init(rigs: BackupRigManager, wifiClient: BridgeOutput, rowBackground: Color, headerColor: Color) {
        self.rigs = rigs
        self.client = rigs.client
        self.mainName = wifiClient.current?.name
        self.rowBackground = rowBackground
        self.headerColor = headerColor
    }

    private var candidates: [BridgeOutput.Item] {
        client.discovered.filter { $0.name != mainName }
    }

    var body: some View {
        Section(header: Text("Backup computer").foregroundColor(headerColor),
                footer: Text("Every press also goes to a second Mac running the Bridge, so the show survives a crash. Only the main computer moves the iPad's faders.")) {
            if let name = rigs.backupName {
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.system(size: 16, weight: .semibold))
                        Text(statusText).font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(rowBackground)

                Picker("Send every press to", selection: $rigs.sendToBoth) {
                    Text("Main only").tag(false)
                    Text("Both").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(rowBackground)

                Button(role: .destructive) {
                    rigs.setBackup(nil)
                } label: {
                    Label("Remove backup computer", systemImage: "minus.circle")
                }
                .listRowBackground(rowBackground)
            } else if candidates.isEmpty {
                Text("No other Mac with the Bridge found on this network.")
                    .foregroundColor(.secondary)
                    .listRowBackground(rowBackground)
            } else {
                ForEach(candidates) { item in
                    Button {
                        rigs.setBackup(item)
                    } label: {
                        Label("Use \(item.name) as backup", systemImage: "plus.circle")
                    }
                    .listRowBackground(rowBackground)
                }
            }
        }
    }

    private var statusText: String {
        switch rigs.health {
        case .ok: return "Connected. Receives every press."
        case .offline: return client.isConnecting ? "Connecting…" : "Offline. Retrying."
        case .sameMac: return "This is the same Mac as your main connection. Pick a different one."
        case .none: return rigs.sendToBoth ? "Waiting" : "Paused: sending to the main computer only."
        }
    }

    private var statusColor: Color {
        switch rigs.health {
        case .ok: return .green
        case .offline, .sameMac: return .orange
        case .none: return .gray
        }
    }
}
