//
//  PairingOverlay.swift — Cue Bear
//  v1.2.1: shown while the iPad pairs with a Mac running Cue Bear Bridge.
//

import SwiftUI
import UIKit

struct PairingOverlay: View {
    let prompt: BridgeOutput.PairingPrompt
    let onCancel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                content
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 440)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CBRadius.panel, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
            .padding(24)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var content: some View {
        switch prompt.stage {
        case .contacting:
            Image(systemName: "lock.shield")
                .font(.cbIcon(.display, .regular))
                .foregroundStyle(.tint)
            Text("Pairing with \(prompt.bridgeName)")
                .font(.cb(.large, .semibold))
                .multilineTextAlignment(.center)
            ProgressView()
            Button("Cancel", role: .cancel, action: onCancel)

        case .confirmOnMac(let code):
            Image(systemName: "lock.shield")
                .font(.cbIcon(.display, .regular))
                .foregroundStyle(.tint)
            Text("Pair with \(prompt.bridgeName)")
                .font(.cb(.large, .semibold))
                .multilineTextAlignment(.center)
            Text("Your Mac is asking whether to allow this iPad. Click Allow on the Mac only if it shows this code:")
                .font(.cb(.body))
                .foregroundStyle(CBColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(SecureLink.formattedCode(code))
                .font(.cbMono(.display, .semibold))
                .monospacedDigit()
                .padding(.vertical, 4)
                .accessibilityLabel("Pairing code \(code.map { String($0) }.joined(separator: " "))")
            Text("You only need to do this once for each Mac.")
                .font(.cb(.caption))
                .foregroundStyle(CBColor.textSecondary)
            Button("Cancel", role: .cancel, action: onCancel)

        case .declined:
            resultView(symbol: "xmark.circle",
                       title: "Pairing Declined",
                       message: "The Mac didn't allow this iPad. Connect again to retry.")

        case .busy(let otherDevice):
            resultView(symbol: "ipad.and.iphone",
                       title: "Bridge In Use",
                       message: "\(prompt.bridgeName) is connected to \(otherDevice). Disconnect it first, then try again.")

        case .failed(let message):
            resultView(symbol: "exclamationmark.triangle",
                       title: "Couldn't Pair",
                       message: message)
        }
    }

    @ViewBuilder
    private func resultView(symbol: String, title: String, message: String) -> some View {
        Image(systemName: symbol)
            .font(.cbIcon(.display, .regular))
            .foregroundStyle(CBColor.textSecondary)
        Text(title)
            .font(.cb(.large, .semibold))
        Text(message)
            .font(.cb(.body))
            .foregroundStyle(CBColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        Button("OK", action: onDismiss)
            .buttonStyle(.borderedProminent)
    }
}

#Preview {
    PairingOverlay(
        prompt: BridgeOutput.PairingPrompt(bridgeName: "Studio Mac", stage: .confirmOnMac(code: "482913")),
        onCancel: {},
        onDismiss: {}
    )
}

// MARK: - Top-level presentation
//
// The pairing panel must appear above everything, including sheets and popovers
// (Welcome screen, connections menu). A SwiftUI overlay on the root view sits
// underneath those, so the panel lives in its own window at alert level.

/// Root of the pairing window: follows the Wi-Fi client's prompt live.
private struct PairingWindowRoot: View {
    @ObservedObject var wifiClient: BridgeOutput
    let tint: Color

    var body: some View {
        ZStack {
            if let prompt = wifiClient.pairingPrompt {
                PairingOverlay(
                    prompt: prompt,
                    onCancel: { wifiClient.cancelPairing() },
                    onDismiss: { wifiClient.dismissPairingPrompt() }
                )
                .tint(tint)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: wifiClient.pairingPrompt)
    }
}

@MainActor
final class PairingWindowPresenter {
    static let shared = PairingWindowPresenter()
    private var window: UIWindow?

    func setVisible(_ visible: Bool, wifiClient: BridgeOutput, tint: Color) {
        if visible {
            guard window == nil else { return }
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                    ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                return
            }
            let host = UIHostingController(rootView: PairingWindowRoot(wifiClient: wifiClient, tint: tint))
            host.view.backgroundColor = .clear

            let newWindow = UIWindow(windowScene: scene)
            newWindow.windowLevel = .alert + 1
            newWindow.backgroundColor = .clear
            newWindow.rootViewController = host
            newWindow.isHidden = false
            window = newWindow
        } else {
            window?.isHidden = true
            window = nil
        }
    }
}
