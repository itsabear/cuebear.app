import SwiftUI
@_exported import Foundation

// MARK: - Performance List (instant touch-down flash; long-press Change MIDI…)
struct CBPerformanceList: View {
    let songs: [Song]
    let isCueMode: Bool
    let cuedID: UUID?
    var onTapSong: (Song) -> Void
    var onLongPressChangeMIDI: (Song) -> Void
    var onRename: (Song) -> Void
    var onDelete: (Song) -> Void
    var onDuplicate: (Song) -> Void
    let conflictFor: [MIDIKey: String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    ForEach(songs) { s in
                    let key = (s.kind == .note)
                        ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                        : MIDIKey(kind: .cc,   channel: s.channel, number: s.cc)
                    let takenBy = conflictFor[key]
                    CBPerformanceRow(
                        song: s,
                        isCued: isCueMode && cuedID == s.id,
                        isCueMode: isCueMode,
                        takenBy: (takenBy != nil && takenBy != s.name) ? takenBy : nil,
                        onTap: { onTapSong(s) },
                        onLongPressChangeMIDI: { onLongPressChangeMIDI(s) },
                        onRename: { onRename(s) },
                        onDelete: { onDelete(s) },
                        onDuplicate: { onDuplicate(s) }
                        )
                        .id(s.id)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .onChange(of: cuedID) { _, newID in
                guard isCueMode, let id = newID else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

struct CBPerformanceRow: View {
    let song: Song
    let isCued: Bool
    let isCueMode: Bool
    let takenBy: String?
    var onTap: () -> Void
    var onLongPressChangeMIDI: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void
    var onDuplicate: () -> Void

    @GestureState private var isPressed = false
    @State private var didDrag = false
    @State private var flashOpacity: Double = 0.0
    private let corner: CGFloat = 20

    var body: some View {
        let press = DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in if !state { state = true } }
            .onChanged { value in
                let delta = abs(value.translation.width) + abs(value.translation.height)
                if delta > 8 {
                    didDrag = true
                }
            }
            .onEnded { _ in
                // Only flash and send MIDI on quick tap (not long-press/context menu)
                if !didDrag && takenBy == nil {
                    if !isCued && !isCueMode {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        flash()
                    }
                    onTap()
                }
                didDrag = false
            }

        ZStack(alignment: .center) {
            // Use accent color from theme for non-cued rows
            RoundedRectangle(cornerRadius: corner)
                .fill(isCued ? Color.orange : Color.accentColor)
                .frame(maxWidth: .infinity, minHeight: 86)
                .opacity(takenBy == nil ? 1.0 : 0.55)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(song.name)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let sub = song.subtitle, !sub.isEmpty {
                        Text(sub).font(.footnote).foregroundColor(Color.white.opacity(0.85)).lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                let subtitle: String = {
                    if song.kind == .cc {
                        return "Ch \(song.channel)  •  CC \(song.cc)"
                    } else {
                        let noteName = (song.note ?? 0).midiNoteName
                        return "Ch \(song.channel)  •  \(noteName)"
                    }
                }()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            RoundedRectangle(cornerRadius: corner)
                .fill(Color.white)
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            if let owner = takenBy {
                Text("Taken by: \(owner)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.985 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.85), value: isPressed)
        .simultaneousGesture(press)
        .contextMenu {
            Button("Edit Cue", action: onRename)
            Button(role: .destructive) { onDelete() } label: { Text("Delete") }
        }
        .accessibilityLabel("\(song.name), \(song.kind == .cc ? "CC \(song.cc)" : "Note \(song.note ?? 0)")")
    }

    private func flash() {
        flashOpacity = 1.0
        // v1.0.3: Removed 20ms delay for instant visual feedback
        withAnimation(.easeOut(duration: 0.18)) { flashOpacity = 0.0 }
    }
}

// MARK: - Setlist Row (custom row for handling drag appearance)
struct CBSetlistRow: View {
    let song: Song
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name).font(.body.bold()).foregroundColor(.primary)
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Custom Drag Preview (no white border)
struct CBSetlistDragPreview: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            // Show hamburger menu icon during drag
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name).font(.body.bold()).foregroundColor(.primary)
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(width: 300, alignment: .leading) // Fixed width for preview
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Editor: Setlist column
struct CBSetlistColumn: View {
    let songs: [Song]
    @Binding var searchText: String
    var onRename: (Song) -> Void
    var onRemove: (Song) -> Void
    var onMove: (IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cue List")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Search TextField
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.body)

                TextField("Search cues...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            List {
                ForEach(songs) { s in
                    CBSetlistRow(
                        song: s,
                        onRemove: {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            onRemove(s)
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowSeparator(.hidden)
                    .onDrag {
                        // Provide item for drag
                        NSItemProvider(object: s.id.uuidString as NSString)
                    } preview: {
                        // Custom preview without white border
                        CBSetlistDragPreview(song: s)
                    }
                    .contextMenu {
                        Button("Edit Cue") { onRename(s) }
                        Button("Remove from Cue List") { onRemove(s) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            onRemove(s)
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                }
                // Only allow reordering when not searching
                .onMove { inds, newOffset in
                    if searchText.isEmpty {
                        onMove(inds, newOffset)
                    }
                }
            }
            // Only show edit mode when not searching (to allow reordering)
            .environment(\.editMode, .constant(searchText.isEmpty ? .active : .inactive))
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Editor: Library column
struct CBLibraryColumn: View {
    let rows: [CBLibraryRow]
    @Binding var isEditing: Bool
    @Binding var batchMode: Bool
    @Binding var selected: Set<UUID>
    @Binding var sortMode: LibrarySortMode
    @Binding var searchText: String

    var onToggleSelect: (UUID) -> Void
    var onAddToSetlist: (Song) -> Void
    var onDeleteFromLibrary: (Song) -> Void
    var onRename: (Song) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Song Library")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()

                Menu {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(LibrarySortMode.allCases) { mode in Text(mode.label).tag(mode) }
                    }
                } label: {
                    Label(sortMode.label, systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(WhiteCapsuleButtonStyle())

                Button(batchMode ? "Cancel" : "Select") {
                    withAnimation(.easeInOut) { batchMode.toggle() }
                    if !batchMode { selected.removeAll() }
                }
                .buttonStyle(WhiteCapsuleButtonStyle())
                .padding(.trailing, 16)
            }

            // Search TextField
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.body)

                TextField("Search songs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            List {
                ForEach(rows) { row in
                    CBRowLikeLibrary(
                        title: row.song.name,
                        subtitle: row.song.subtitle,
                        leading: {
                            if batchMode {
                                Button { onToggleSelect(row.song.id) } label: {
                                    Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    if !row.isInSetlist {
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        onAddToSetlist(row.song)
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(row.isInSetlist ? .gray : .accentColor)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .disabled(row.isInSetlist)
                            }
                        },
                        trailing: { EmptyView() }
                    )
                    .opacity(row.isInSetlist ? 0.55 : 1.0)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if isEditing && !row.isInSetlist {
                            Button(role: .destructive) {
                                onDeleteFromLibrary(row.song)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .contextMenu {
                        Button("Edit Cue") { onRename(row.song) }
                        Button(role: .destructive) { onDeleteFromLibrary(row.song) } label: { Text("Delete") }
                    }
                }
            }
            .listStyle(.plain)
            .onReceive(NotificationCenter.default.publisher(for: .init("CBRemoveFromSetlist"))) { _ in }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CBRowLikeLibrary<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    var leading: () -> Leading
    var trailing: () -> Trailing

    init(title: String, subtitle: String?,
         @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.bold()).foregroundColor(.primary)
                if let sub = subtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

// MARK: - Full-width batch toolbar
struct CBBatchToolbar: View {
    let selectedCount: Int
    var onSelectAll: () -> Void
    var onClear: () -> Void
    var onAddToSetlist: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button("Select All", action: onSelectAll)
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                Button("Clear", action: onClear)
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAddToSetlist()
                } label: { Label("Add to Setlist", systemImage: "plus.circle.fill") }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)

                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDelete()
                } label: { Label("Delete", systemImage: "trash") }
                .buttonStyle(WhiteCapsuleButtonStyle())
                .foregroundColor(.blue)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .frame(maxWidth: .infinity)
        }
    }
}

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
            return .blue
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isConnected ? connectionType.connectedColor : connectionType.color)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(connectionType == .usb ? "USB Bridge" : "WiFi Bridge")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
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
            RoundedRectangle(cornerRadius: 12)
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
            RoundedRectangle(cornerRadius: 12)
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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("USB")) {
                    KeyValueRow("Status", connectionCoordinator.activeConnection == .usb ? "Connected" : "Waiting")
                    if connectionCoordinator.activeConnection == .usb {
                        Button("Disconnect USB", role: .destructive) {
                            usbServer.stop()
                        }
                    }


                    // Bridge device card for USB connection - show ONLY when USB cable is physically connected
                    if usbServer.isUSBCableConnected {
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
                        .animation(.easeInOut(duration: 0.2), value: usbServer.isUSBCableConnected)
                    } else {
                        Text("USB cable not connected")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: usbServer.isUSBCableConnected)
                    }
                }

                Section(header: Text("Wi-Fi")) {
                    KeyValueRow("Status", connectionCoordinator.activeConnection == .wifi ? "Connected" : "Not Connected")
                    if connectionCoordinator.activeConnection == .wifi {
                        Button("Disconnect Wi-Fi", role: .destructive) { onDisconnectWifi() }
                    }
                    
                    
                    if wifiClient.discovered.isEmpty {
                        Text("Searching on local network…").foregroundColor(.secondary)
                    } else {
                        ForEach(wifiClient.discovered, id: \.id) { item in
                            BridgeDeviceCard(
                                computerName: item.name,
                                isConnected: wifiClient.isConnected && wifiClient.current?.id == item.id,
                                isConnecting: wifiClient.isConnecting && wifiClient.current?.id == item.id,
                                connectionType: .wifi,
                                isClickable: true,
                                onTap: {
                                    debugPrint("🔌 DEBUG: Bridge tapped - \(item.name)")
                                    connectionCoordinator.connectToWiFi(bridge: item)
                                }
                            )
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Cue Bear for iPad")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2") (\(gitCommitHash()))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

            }
            .navigationTitle("Connections")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    
    
    private func KeyValueRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(.secondary)
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
}


struct CBProjectsSheet: View {
    @Binding var projectName: String
    let projects: [String]
    @Binding var isDirty: Bool

    var onTapTitleWhenUnsaved: () -> Void
    var onSave: () -> Void
    var onSaveAs: (String) -> Void
    var onNew: () -> Void
    var onLoad: (String) -> Void
    var onDelete: (String) -> Void
    var onOpenDocument: () -> Void  // New: Open document picker
    var onExportProject: () -> Void  // New: Export current project

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: String? = nil
    @State private var tempSaveAs: String = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Project")
                        Spacer()
                        if projectName == "Untitled" || isDirty {
                            Button(projectName) { onTapTitleWhenUnsaved() }
                                .foregroundColor(.blue)
                        } else {
                            Text(projectName).foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Actions")) {
                    Button("Save") { onSave() }
                        .disabled(!isDirty && projectName != "Untitled")
                    Button("Save As…") {
                        tempSaveAs = (projectName == "Untitled") ? "" : projectName
                        onSaveAs(tempSaveAs)
                    }
                    Button("New Project") { onNew() }
                    Button("Open from Files") {
                        // Simple document picker - will be handled in ContentView
                        onOpenDocument()
                    }
                    .foregroundColor(.blue)
                    Button("Export Project") {
                        // Export current project to share/save elsewhere
                        onExportProject()
                    }
                    .foregroundColor(.blue)
                }

                Section(header: Text("Saved Projects")) {
                    if projects.isEmpty {
                        Text("No saved projects yet.").foregroundColor(.secondary)
                    } else {
                        ForEach(projects, id: \.self) { name in
                            HStack {
                                Button(name) { onLoad(name); dismiss() }
                                Spacer()
                                Button {
                                    debugPrint("🗑️ Delete button tapped for project: \(name)")
                                    confirmDelete = name
                                    debugPrint("🗑️ Set confirmDelete to: \(name)")
                                } label: {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Delete Project", isPresented: Binding(get: { confirmDelete != nil }, set: { newVal in if !newVal { confirmDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    debugPrint("🗑️ Delete confirmed for project: \(confirmDelete ?? "nil")")
                    if let n = confirmDelete { 
                        debugPrint("🗑️ Calling onDelete with: \(n)")
                        onDelete(n) 
                    }
                    confirmDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    debugPrint("🗑️ Delete cancelled for project: \(confirmDelete ?? "nil")")
                    confirmDelete = nil
                }
            } message: {
                if let name = confirmDelete {
                    Text("Are you sure you want to delete '\(name)'? This action cannot be undone.")
                }
            }
        }
    }
}

struct CBAddEditCueSheet: View {
    @Binding var editingSong: Song?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    let defaultName: String
    var onSave: (Song, Bool) -> Void  // Added Bool parameter for andAddAnother
    var onCancel: () -> Void
    var onDelete: ((Song) -> Void)? = nil

    // Global channel support
    let isGlobalChannel: Bool
    let globalChannel: Int

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 1
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var autoAssign: Bool = true
    @State private var error: String? = nil
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Song")) {
                    TextField("Name", text: $name, prompt: Text(defaultName).foregroundColor(.secondary))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                    TextField("Subtitle (Tempo/Key/Notes)", text: $subtitle)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                }
                Section(header: Text("MIDI")) {
                    Toggle(isOn: $autoAssign) {
                        Text("Assign MIDI automatically")
                    }
                    Picker("Type", selection: $kind) {
                        Text("Control Change").tag(MIDIKind.cc)
                        Text("Note").tag(MIDIKind.note)
                    }
                    Picker("Channel", selection: $channel) {
                        ForEach(1...16, id: \.self) { ch in
                            Text("\(ch)").tag(ch)
                        }
                    }
                    Picker(kind == .cc ? "CC Number" : "Note Number", selection: $number) {
                        ForEach(0...127, id: \.self) { n in
                            let owner = ownerFor(kind: kind, number: n, channel: channel)
                            let displayText = kind == .note
                                ? (owner == nil ? "\(n) - \(n.midiNoteName)" : "\(n) - \(n.midiNoteName) (Used by: \(owner!))")
                                : (owner == nil ? "\(n)" : "\(n) (Used by: \(owner!))")

                            Text(displayText)
                                .foregroundColor(owner == nil ? .primary : .secondary)
                                .tag(n)
                        }
                    }
                    .disabled(autoAssign)
                    if kind == .note {
                        Stepper(value: $velocity, in: 1...127) { Text("Velocity: \(velocity)") }
                    }
                    if let owner = conflictOwner() {
                        Text("⚠️ Taken by: \(owner)").foregroundColor(.orange)
                    }
                }
                if let err = error { Text(err).foregroundColor(.red) }

                // Delete section - only show when editing existing cue
                if editingSong != nil, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Cue")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingSong == nil ? "Add Cue" : "Edit Cue")
            .alert("Delete Cue", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let song = editingSong {
                        onDelete?(song)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(name.isEmpty ? defaultName : name)'? This action cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
                if editingSong == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save & Add Another") { save(andAddAnother: true) }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(andAddAnother: false) } }
            }
            .onAppear { preset() }
            .onChange(of: editingSong) { oldValue, newValue in
                // When editingSong changes (especially when set to nil for "Add Another"),
                // re-run preset to ensure form is properly initialized
                if oldValue != nil && newValue == nil {
                    preset()
                }
            }
            .onChange(of: autoAssign) { _, newValue in
                if newValue {
                    number = firstFreeNumber(for: kind, channel: channel)
                }
            }
            .onChange(of: kind) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: newValue, channel: channel)
                }
            }
            .onChange(of: channel) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: kind, channel: newValue)
                }
            }
        }
    }

    private func preset() {
        debugPrint("📋 [CUE] preset() called, editingSong: \(editingSong != nil ? "exists" : "nil")")
        if let s = editingSong {
            name = s.name
            subtitle = s.subtitle ?? ""
            kind = s.kind
            number = (s.kind == .note) ? (s.note ?? 60) : s.cc
            channel = s.channel
            velocity = s.velocity
            // For existing songs, disable auto-assign to allow manual editing
            autoAssign = false
        } else {
            name = ""
            subtitle = ""
            kind = .cc
            // FIX: Use global channel if enabled, otherwise default to 1
            channel = isGlobalChannel ? globalChannel : 1
            velocity = 127
            // For new songs, enable auto-assign and find free MIDI
            autoAssign = true
            debugPrint("  🆕 [CUE] No editing state, finding free number for \(kind) ch\(channel)")
            number = firstFreeNumber(for: kind, channel: channel)
            debugPrint("  ✅ [CUE] preset() set number to \(number)")
        }
    }

    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        debugPrint("🔍 [CUE] Finding first free \(kind) number on channel \(channel), editingSong: \(editingSong?.name ?? "nil")")
        for n in 0...127 {
            let key = MIDIKey(kind: kind, channel: channel, number: n)
            if let owner = currentOwnerName(key) {
                if owner != editingSong?.name {
                    debugPrint("  ✗ [CUE] \(n) is taken by '\(owner)', skipping")
                    continue
                }
                debugPrint("  ✓ [CUE] \(n) is taken by editing song, available")
            }
            debugPrint("  ✅ [CUE] First free number: \(n)")
            return n
        }
        debugPrint("  ⚠️ [CUE] No free numbers found, returning 0")
        return 0
    }

    private func conflictOwner() -> String? {
        // If we're editing an existing song and the MIDI assignment hasn't changed, no conflict
        if let edit = editingSong {
            let editNumber = (edit.kind == .note) ? (edit.note ?? 60) : edit.cc
            if edit.kind == kind && edit.channel == channel && editNumber == number {
                return nil
            }
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing song and checking its current MIDI assignment, no conflict
        if let edit = editingSong {
            let editNumber = (edit.kind == .note) ? (edit.note ?? 60) : edit.cc
            if edit.kind == kind && edit.channel == channel && editNumber == number {
                return nil
            }
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func save(andAddAnother: Bool) {
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? defaultName : trimmed

        var song = editingSong ?? Song(name: finalName, subtitle: subtitle.isEmpty ? nil : subtitle, cc: 0, channel: channel)
        song.name = finalName
        song.subtitle = subtitle.isEmpty ? nil : subtitle
        song.kind = kind
        song.channel = channel
        song.velocity = velocity

        // Set cc or note based on kind
        if kind == .note {
            song.note = number
            song.cc = 0  // Reset cc when using note
        } else {
            song.cc = number
            song.note = nil  // Reset note when using cc
        }

        onSave(song, andAddAnother)

        if andAddAnother {
            debugPrint("➕ [CUE] Save & Add Another clicked")
            // CRITICAL FIX: Reset state variables BEFORE setting editingSong = nil
            // This prevents race condition where preset() uses old values when .onChange fires

            // Reset all form fields to defaults FIRST
            name = ""
            subtitle = ""
            kind = .cc
            velocity = 127
            autoAssign = true
            error = nil

            // Calculate next channel and number with the reset values
            debugPrint("  🔢 [CUE] Calculating next free number BEFORE setting editingSong=nil")
            let nextChannel = isGlobalChannel ? globalChannel : 1
            channel = nextChannel
            let nextNumber = firstFreeNumber(for: .cc, channel: nextChannel)
            number = nextNumber
            debugPrint("  ✅ [CUE] Set number to \(nextNumber)")

            // NOW set editingSong to nil (triggers .onChange which calls preset())
            // preset() will now see the correct reset values above
            debugPrint("  🔄 [CUE] Setting editingSong=nil (will trigger .onChange)")
            editingSong = nil
        }
    }
}

struct CBMIDIPickerSheet: View {
    let title: String
    @State var kind: MIDIKind
    @State var number: Int
    @State var channel: Int
    @State var velocity: Int
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (MIDIKind, Int, Int, Int) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Control Change").tag(MIDIKind.cc)
                    Text("Note").tag(MIDIKind.note)
                }
                Stepper(value: $number, in: 0...127) {
                    Text(kind == .cc ? "CC Number: \(number)" : "Note Number: \(number)")
                }
                Stepper(value: $channel, in: 1...16) { Text("Channel: \(channel)") }
                if kind == .note {
                    Stepper(value: $velocity, in: 1...127) { Text("Velocity: \(velocity)") }
                }
                if let owner = conflictOwner() {
                    Text("⚠️ Taken by: \(owner)").foregroundColor(.orange)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(kind, number, channel, velocity) }
                        .disabled(conflictOwner() != nil)
                }
            }
        }
    }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return conflictFor[key]
    }
}


