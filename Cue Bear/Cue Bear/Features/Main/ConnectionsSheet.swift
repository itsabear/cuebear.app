//
//  ConnectionsSheet.swift — Cue Bear
//
//  The Connections sheet: USB, Wi-Fi and the backup computer.
//

import SwiftUI
import UIKit
import CoreImage

// MARK: - Bridge Device Card
private struct BridgeDeviceCard: View {
    let computerName: String
    let isConnected: Bool
    let isConnecting: Bool
    let isClickable: Bool
    let connectionType: ConnectionType
    let onTap: (() -> Void)?
    
    enum ConnectionType {
        case usb, wifi
        
        var color: Color {
            let themeID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "default"
            let theme = AppTheme.allThemes.first { $0.id == themeID } ?? AppTheme.defaultTheme
            return theme.accentColor(for: .dark)
        }
        
        var connectedColor: Color {
            return .green
        }
        
        var icon: String {
            return "bearpaw_32x32"
        }
    }
    
    init(computerName: String, isConnected: Bool, isConnecting: Bool = false, connectionType: ConnectionType, isClickable: Bool = false, onTap: (() -> Void)? = nil) {
        self.computerName = computerName
        self.isConnected = isConnected
        self.isConnecting = isConnecting
        self.connectionType = connectionType
        self.isClickable = isClickable
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Bear paw icon with loading animation
            if isConnecting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: connectionType.color))
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            } else {
                Image(connectionType.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(isConnected ? connectionType.connectedColor : connectionType.color)
                    .frame(width: 20, height: 20)
            }
            
            // Computer name
            VStack(alignment: .leading, spacing: 2) {
                Text(computerName)
                    .font(.cb(.body, .medium))
                    .foregroundColor(isConnected ? connectionType.connectedColor : connectionType.color)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(connectionType == .usb ? "USB Bridge" : "WiFi Bridge")
                    .font(.cb(.caption, .regular))
                    .foregroundStyle(CBColor.textSecondary)
            }
            
            Spacer()
            
            // Connection status indicator
            Circle()
                .fill(isConnected ? connectionType.connectedColor : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .scaleEffect(isConnected ? 1.0 : 0.8)
                .animation(.easeInOut(duration: 0.2), value: isConnected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: CBRadius.card)
                .fill(isConnected ? 
                    LinearGradient(
                        colors: [connectionType.connectedColor.opacity(0.08), connectionType.connectedColor.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) : 
                    LinearGradient(
                        colors: [connectionType.color.opacity(0.08), connectionType.color.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: CBRadius.card)
                .stroke(
                    isConnected ? 
                        LinearGradient(
                            colors: [connectionType.connectedColor.opacity(0.3), connectionType.connectedColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : 
                        LinearGradient(
                            colors: [connectionType.color.opacity(0.3), connectionType.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: isConnected ? connectionType.connectedColor.opacity(0.1) : connectionType.color.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        .scaleEffect(isClickable ? 1.0 : 1.0)
        .onTapGesture {
            if isClickable, let onTap = onTap {
                withAnimation(.easeInOut(duration: 0.1)) {
                    onTap()
                }
            }
        }
    }
}

// The following sheets are moved out for clarity
struct CBConnectionsSheet: View {
    @ObservedObject var usbServer: ConnectionManager
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var connectionCoordinator: ConnectionCoordinator

    var onDisconnectWifi: () -> Void
    var onConnectWifiItem: (BridgeOutput.Item) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    // Loading state - show spinner while checking for bridges
    @State private var isCheckingConnections = true

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var noBridgeDetected: Bool {
        !usbServer.usbBridgeAvailable && wifiClient.discovered.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom header — bypasses iOS 18+/26 toolbar glass capsule chrome
                HStack {
                    Spacer()
                    CBSheetButton(title: "Done", bold: true) { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Group {
                    if isCheckingConnections {
                        // Show loading state while checking for bridges
                        loadingView
                    } else if noBridgeDetected {
                        // Show special "Download Bridge" view when no bridges detected
                        downloadBridgeView
                    } else {
                        // Show normal connections form
                        connectionsForm
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
        .onAppear {
            // If we already have connection info, skip loading
            if usbServer.usbBridgeAvailable || !wifiClient.discovered.isEmpty || connectionCoordinator.activeConnection != .none {
                isCheckingConnections = false
            } else {
                // Give the system time to discover bridges
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isCheckingConnections = false
                    }
                }
            }
        }
        .onChange(of: usbServer.usbBridgeAvailable) { _, available in
            // If bridge becomes available, stop loading immediately
            if available && isCheckingConnections {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCheckingConnections = false
                }
            }
        }
        .onChange(of: wifiClient.discovered.count) { _, count in
            // If WiFi bridges found, stop loading immediately
            if count > 0 && isCheckingConnections {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCheckingConnections = false
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(selectedTheme.accentColor(for: colorScheme))

            Text("Searching for bridges...")
                .font(.cb(.body, .semibold))
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Text("Looking for USB and Wi-Fi connections")
                .font(.cb(.small))
                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connectionsForm: some View {
        Form {
            Section(header: Text("USB").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    KeyValueRow("Status", connectionCoordinator.activeConnection == .usb ? "Connected" : "Waiting")
                        .cbRow()
                    if connectionCoordinator.activeConnection == .usb {
                        Button("Disconnect USB", role: .destructive) {
                            connectionCoordinator.disconnectUSB()
                        }
                        .cbRow()
                    }


                    // Bridge device card for USB connection - show ONLY when Bridge app is running
                    if usbServer.usbBridgeAvailable {
                        BridgeDeviceCard(
                            computerName: usbServer.connectedComputerName ?? "Bear Bridge",
                            isConnected: connectionCoordinator.activeConnection == .usb,
                            isConnecting: usbServer.isConnecting,
                            connectionType: .usb,
                            isClickable: connectionCoordinator.activeConnection != .usb, // Clickable when not connected
                            onTap: {
                                if connectionCoordinator.activeConnection != .usb {
                                    // Force USB connection attempt
                                    connectionCoordinator.forceUSBReconnection()
                                }
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: usbServer.usbBridgeAvailable)
                        .cbRow()
                    } else {
                        Text("Bridge app not running")
                            .foregroundStyle(CBColor.textSecondary)
                            .font(.cb(.caption))
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: usbServer.usbBridgeAvailable)
                            .cbRow()
                    }
                }

                Section(header: Text("Wi-Fi").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    KeyValueRow("Status", connectionCoordinator.activeConnection == .wifi ? "Connected" : "Not Connected")
                        .cbRow()
                    if connectionCoordinator.activeConnection == .wifi {
                        Button("Disconnect Wi-Fi", role: .destructive) { onDisconnectWifi() }
                            .cbRow()
                    }


                    if wifiClient.discovered.isEmpty {
                        Text("Searching on local network…").foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    } else {
                        ForEach(wifiClient.discovered, id: \.id) { item in
                            BridgeDeviceCard(
                                computerName: item.name,
                                // v1.0.4: Fix WiFi chip showing disconnected when USB unplugs
                                // Use connectionCoordinator.activeConnection as source of truth instead of item.id comparison
                                // because discovered array rebuilds with new IDs after USB disconnect
                                isConnected: connectionCoordinator.activeConnection == .wifi && wifiClient.current?.name == item.name,
                                isConnecting: wifiClient.isConnecting && wifiClient.current?.name == item.name,
                                connectionType: .wifi,
                                isClickable: true,
                                onTap: {
                                    debugPrint("🔌 DEBUG: Bridge tapped - \(item.name)")
                                    connectionCoordinator.connectToWiFi(bridge: item)
                                }
                            )
                            .cbRow()
                        }
                    }
                }

                // v1.3 (Cue Bear Next): two computers at once
                BackupComputerSection(rigs: BackupRigManager.shared,
                                      wifiClient: wifiClient,
                                      headerColor: selectedTheme.secondaryTextColor(for: colorScheme))
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .tint(selectedTheme.accentColor(for: colorScheme))
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var downloadBridgeView: some View {
        let accentColor = selectedTheme.accentColor(for: colorScheme)

        return VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon - matching onboarding style (72pt, light weight)
                Image(systemName: "laptopcomputer.and.arrow.down")
                    .font(.cbIcon(.hero, .light))
                    .foregroundColor(accentColor)
                    .frame(height: 72)

                // Title - matching onboarding style (28pt, bold, rounded)
                Text("Ready to Connect?")
                    .font(.cb(.heading, .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .padding(.horizontal, 40)

                // Description - matching onboarding style (17pt, secondary)
                Text("Download Cue Bear Bridge for your Mac to start sending MIDI to your DAW.")
                    .font(.cb(.body, .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(CBColor.textSecondary)
                    .padding(.horizontal, 50)
                    .fixedSize(horizontal: false, vertical: true)

                // QR Code
                VStack(spacing: 12) {
                    if let qrImage = generateQRCode(from: "https://cuebear.app/bridge") {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 160, height: 160)
                            .padding(12)
                            .background(selectedTheme.titleBarColor(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
                    } else {
                        RoundedRectangle(cornerRadius: CBRadius.card)
                            .fill(selectedTheme.titleBarColor(for: colorScheme))
                            .frame(width: 160, height: 160)
                            .overlay(
                                Image(systemName: "qrcode")
                                    .font(.cbIcon(.hero, .regular))
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.5))
                            )
                    }

                    Text("Scan to download")
                        .font(.cb(.small))
                        .foregroundStyle(CBColor.textSecondary)
                }
                .padding(.top, 8)
            }

            Spacer()

            // Bottom section with button and footer
            VStack(spacing: 20) {
                // Download button - matching onboarding "Get Started" style
                Button(action: {
                    if let url = URL(string: "https://cuebear.app/bridge") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("cuebear.app/bridge")
                            .font(.cb(.body, .semibold))
                        Image(systemName: "arrow.up.forward")
                            .font(.cbIcon(.small, .semibold))
                    }
                    .foregroundColor(selectedTheme.accentContrastColor(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
                }
                .padding(.horizontal, 40)

                // Footer text
                Text("Once installed, connections will appear here automatically")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
    }


    private func KeyValueRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundStyle(CBColor.textSecondary)
        }
    }

    private func gitCommitHash() -> String {
        // Try to read git commit hash from build-time generated file
        if let path = Bundle.main.path(forResource: "GitCommit", ofType: "txt"),
           let hash = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            return String(hash.prefix(7))
        }
        // Fallback to build number if git hash not available
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
