//
//  BackupComputerSection.swift — Cue Bear Next (v1.3)
//
//  The "Backup computer" section of the Connections sheet (logic in Connection/BackupRigManager.swift).
//

import SwiftUI

// MARK: - Connections sheet section

/// "Backup computer" section of the Connections sheet.
struct BackupComputerSection: View {
    @ObservedObject var rigs: BackupRigManager
    @ObservedObject var client: BridgeOutput
    let mainName: String?
    let headerColor: Color

    init(rigs: BackupRigManager, wifiClient: BridgeOutput, headerColor: Color) {
        self.rigs = rigs
        self.client = rigs.client
        self.mainName = wifiClient.current?.name
        self.headerColor = headerColor
    }

    private var candidates: [BridgeOutput.Item] {
        client.discovered.filter { $0.name != mainName }
    }

    var body: some View {
        Section(header: Text("Backup computer").foregroundColor(headerColor),
                footer: Text("Every press also goes to a second Mac running the Bridge, so the show survives a crash. Only the main computer moves the iPad's faders.")) {
            if let name = rigs.backupName {
                HStack(spacing: CBSpace.m) {
                    CBStatusDot(color: statusColor)
                    VStack(alignment: .leading, spacing: CBSpace.xxs) {
                        Text(name).font(.cb(.body, .semibold))
                        Text(statusText).font(.cb(.small)).foregroundStyle(CBColor.textSecondary)
                    }
                    Spacer()
                }
                .cbRow()

                Picker("Send every press to", selection: $rigs.sendToBoth) {
                    Text("Main only").tag(false)
                    Text("Both").tag(true)
                }
                .pickerStyle(.segmented)
                .cbRow()

                Button(role: .destructive) {
                    rigs.setBackup(nil)
                } label: {
                    Label("Remove backup computer", systemImage: "minus.circle")
                }
                .cbRow()
            } else if candidates.isEmpty {
                Text("No other Mac with the Bridge found on this network.")
                    .foregroundStyle(CBColor.textSecondary)
                    .cbRow()
            } else {
                ForEach(candidates) { item in
                    Button {
                        rigs.setBackup(item)
                    } label: {
                        Label("Use \(item.name) as backup", systemImage: "plus.circle")
                    }
                    .cbRow()
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
        case .ok: return CBColor.success
        case .offline, .sameMac: return CBColor.warning
        case .none: return CBColor.textTertiary
        }
    }
}
