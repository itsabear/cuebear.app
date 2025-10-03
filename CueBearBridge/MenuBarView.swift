import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var app: BridgeApp
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Cue Bear Bridge")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
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
                
                // MIDI Activity Indicator (like a preamp input LED)
                HStack {
                    Circle()
                        .fill(app.midiActivity ? .green : .gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(app.midiActivity ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: app.midiActivity)
                    Text("MIDI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(app.midiActivity ? "Active" : "Ready")
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
