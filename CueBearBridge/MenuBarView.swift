import SwiftUI

// Helper to provide version string without blocking
struct VersionHelper {
    static let cachedVersionString: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version).\(build)"
    }()
}

struct MenuBarView: View {
    @EnvironmentObject var app: BridgeApp

    var body: some View {
        VStack(spacing: 8) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("Cue Bear Bridge")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(VersionHelper.cachedVersionString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
            
            // Status Indicators
            VStack(spacing: 6) {
                // USB Connection Status
                HStack {
                    Circle()
                        .fill(app.isConnected ? .green : .yellow)
                        .frame(width: 8, height: 8)
                    Text("USB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(app.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            // Creator Credit
            HStack {
                Spacer()
                Text("Created by Omri Behr")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// Menu Bar Extra wrapper
struct MenuBarExtraView: View {
    @StateObject private var app = BridgeApp()
    
    var body: some View {
        MenuBarView()
            .environmentObject(app)
            .onAppear {
                app.start()
            }
            .onDisappear {
                app.stop()
            }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(BridgeApp())
}
