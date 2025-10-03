import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: BridgeApp
    @State private var udidText: String = ""
    @ObservedObject var logger = Logger.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CueBear Bridge").font(.title2.bold())
                    HStack { dot(app.status == "Running" ? .green : .orange); Text(app.status) }
                    HStack { dot(app.iproxyStatus.contains("Running") ? .green : .orange); Text(app.iproxyStatus) }
                    HStack { dot(app.usbStatus.contains("Connected") ? .green : .yellow); Text(app.usbStatus + (app.localPort != nil ? " (:\(app.localPort!))" : "")) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("Target UDID (optional):").font(.caption)
                        TextField("auto-detect", text: $udidText).textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                    HStack(spacing: 10) {
                        Button("Start") { if !udidText.isEmpty { app.iproxy.persistedUDID = udidText }; app.start() }
                        Button("Stop") { app.stop() }
                        Button("Test MIDI") { app.midi.sendTestCC() }
                    }.buttonStyle(.borderedProminent)
                }
            }
            Divider().padding(.vertical, 4)
            Text("Logs").font(.headline)
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(logger.lines.enumerated()), id: \.offset) { (idx, line) in
                                Text(line).font(.system(size: 11, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                                    .id(idx)
                            }
                        }.padding(.horizontal, 2).padding(.vertical, 4)
                    }
                    .onChange(of: logger.lines.count) { _ in
                        if let last = logger.lines.indices.last { withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(last, anchor: .bottom) } }
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 440)
        .onAppear {
            udidText = app.iproxy.persistedUDID ?? ""
        }
    }

    @ViewBuilder private func dot(_ c: Color) -> some View { Circle().fill(c).frame(width: 10, height: 10) }
}
