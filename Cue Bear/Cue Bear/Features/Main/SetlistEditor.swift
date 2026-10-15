//
//  SetlistEditor.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation

// MARK: - Setlist Row (simple row for swipe gestures)
struct CBSetlistRow: View {
    let song: Song
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    let conflictFor: [MIDIKey: String]
    var onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(themeFont?(18, .bold) ?? .body.bold())
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.cb(.caption))
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(" ").font(.cb(.caption)).foregroundColor(.clear)
                }
            }
            Spacer()

            // Show MIDI info and conflict warning
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 16) {
                    // Always show MIDI info
                    let midiInfo: String = {
                        if song.kind == .cc {
                            return "Ch \(song.channel) • CC \(song.cc)"
                        } else {
                            let noteName = (song.note ?? 0).midiNoteName
                            return "Ch \(song.channel) • \(noteName)"
                        }
                    }()
                    Text(midiInfo)
                        .font(.cb(.micro))
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))

                    // Color indicator circle (always reserve space for alignment)
                    Group {
                        if let hex = song.colorHex {
                            Circle()
                                .fill(Color(hex: hex))
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            Circle()
                                .fill(Color.clear)
                        }
                    }
                    .frame(width: 20, height: 20)
                }

                // Show conflict warning below MIDI info
                if let owner = filteredTakenBy() {
                    Text("⚠️ MIDI taken by: \(owner)")
                        .font(.cb(.micro))
                        .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func filteredTakenBy() -> String? {
        let key = (song.kind == .note)
            ? MIDIKey(kind: .note, channel: song.channel, number: song.note ?? 0)
            : MIDIKey(kind: .cc, channel: song.channel, number: song.cc)
        guard let takenBy = conflictFor[key] else { return nil }

        // Filter out current song's name from the conflict list
        if takenBy.contains("|||") {
            // Multiple owners - split and filter
            let owners = takenBy.split(separator: "|||").map(String.init).filter { $0 != song.name }
            guard !owners.isEmpty else { return nil }
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if takenBy == song.name {
            // Single owner and it's us
            return nil
        }
        return takenBy
    }
}

// MARK: - Custom Drag Preview (no white border)
struct CBSetlistDragPreview: View {
    let song: Song
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(themeFont?(18, .bold) ?? .body.bold())
                    .foregroundStyle(CBColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.cb(.caption))
                        .foregroundStyle(CBColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(" ").font(.cb(.caption)).foregroundColor(.clear)
                }
            }
            Spacer()
            // Show drag handle on the right during drag
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(CBColor.textSecondary)
                .font(.cbIcon(.large, .regular))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(width: 300, alignment: .leading) // Fixed width for preview
        .background(
            RoundedRectangle(cornerRadius: CBRadius.control)
                .fill(Color.accentColor.opacity(0.15))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Editor: Setlist column
struct CBSetlistColumn: View {
    let songs: [Song]
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    let conflictFor: [MIDIKey: String]
    @Binding var searchText: String
    @Binding var reorderMode: Bool
    @Binding var batchMode: Bool
    @Binding var selected: Set<UUID>
    var onRename: (Song) -> Void
    var onRemove: (Song) -> Void
    var onMove: (IndexSet, Int) -> Void
    var onAdd: () -> Void
    var onToggleSelect: (UUID) -> Void
    var onSelectAll: (() -> Void)?
    var onClearSelection: (() -> Void)?
    var onBatchRemove: (() -> Void)?
    var onDuplicate: ((Song) -> Void)?  // Optional callback for duplicating a cue

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Cue List")
                    .font(themeFont?(17, .semibold) ?? .headline)
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()

                Button {
                    withAnimation(.easeInOut) {
                        reorderMode.toggle()
                        if reorderMode {
                            batchMode = false
                            selected.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: reorderMode ? "checkmark" : "list.dash")
                        .font(.cbIcon(.body, .regular))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.accentColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.accentColor(for: colorScheme)))

                Button {
                    withAnimation(.easeInOut) {
                        batchMode.toggle()
                        if batchMode {
                            reorderMode = false
                        }
                        if !batchMode {
                            selected.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: batchMode ? "xmark" : "checkmark.circle")
                        .font(.cbIcon(.body, .regular))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.accentColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.accentColor(for: colorScheme)))
                .padding(.trailing, 16)
            }
            .frame(height: 44) // Match library column header height

            // Batch controls replace search bar when in batch mode
            if batchMode {
                HStack(spacing: 20) {
                    Button("Select All") {
                        onSelectAll?()
                    }
                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))

                    Button("Clear") {
                        onClearSelection?()
                    }
                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))

                    Spacer()

                    Button("Remove") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBatchRemove?()
                    }
                    .foregroundColor(selected.isEmpty ? .gray : selectedTheme.errorColor(for: colorScheme))
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // Search TextField
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CBColor.textTertiary)
                        .font(.cbIcon(.body, .regular))

                    TextField("Search cues...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(CBColor.textTertiary)
                                .font(.cbIcon(.body, .regular))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTheme.titleBarColor(for: colorScheme).opacity(0.8))
                .cornerRadius(CBRadius.control)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            List {
                ForEach(songs) { s in
                    HStack(spacing: 12) {
                        // Show selection circle in batch mode
                        if batchMode {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                if selected.contains(s.id) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.cbIcon(.caption, .bold))
                                        .foregroundStyle(CBColor.textPrimary)
                                }
                            }
                            .frame(width: 24, height: 24)
                            .onTapGesture {
                                onToggleSelect(s.id)
                            }
                        }

                        CBSetlistRow(
                            song: s,
                            themeFont: themeFont,
                            conflictFor: conflictFor,
                            onTap: {
                                if batchMode {
                                    onToggleSelect(s.id)
                                } else {
                                    onRename(s)
                                }
                            }
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(.gray)
                    .contextMenu {
                        if reorderMode {
                            Button {
                                onRename(s)
                            } label: {
                                Label("Edit Cue", systemImage: "pencil")
                            }

                            Button {
                                onDuplicate?(s)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Button(role: .destructive) {
                                onRemove(s)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !reorderMode && !batchMode {
                            Button(role: .destructive) {
                                onRemove(s)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                }
                .onMove { inds, newOffset in
                    if searchText.isEmpty && reorderMode {
                        onMove(inds, newOffset)
                    }
                }
            }
            .environment(\.editMode, .constant(reorderMode && searchText.isEmpty ? .active : .inactive))
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .tint(.gray) // Drag handles same color as search icon
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Editor: Library column
struct CBLibraryColumn: View {
    let rows: [CBLibraryRow]
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    let conflictFor: [MIDIKey: String]
    @Binding var isEditing: Bool
    @Binding var batchMode: Bool
    @Binding var selected: Set<UUID>
    @Binding var sortMode: LibrarySortMode
    @Binding var searchText: String

    var onToggleSelect: (UUID) -> Void
    var onAddToSetlist: (Song) -> Void
    var onDeleteFromLibrary: (Song) -> Void
    var onRename: (Song) -> Void
    var onSelectAll: (() -> Void)?
    var onClearSelection: (() -> Void)?
    var onBatchAddToSetlist: (() -> Void)?
    var onBatchDelete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Song Library")
                    .font(themeFont?(17, .semibold) ?? .headline)
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()

                Menu {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(LibrarySortMode.allCases) { mode in Text(mode.label).tag(mode) }
                    }
                    .tint(selectedTheme.accentColor(for: colorScheme))
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.cbIcon(.body, .regular))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.accentColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.accentColor(for: colorScheme)))

                Button {
                    withAnimation(.easeInOut) { batchMode.toggle() }
                    if !batchMode { selected.removeAll() }
                } label: {
                    Image(systemName: batchMode ? "xmark" : "checkmark.circle")
                        .font(.cbIcon(.body, .regular))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.accentColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.accentColor(for: colorScheme)))
                .padding(.trailing, 16)
            }
            .frame(height: 44) // Match cue list column header height

            // v1.0.9: Batch controls replace search bar when in batch mode
            if batchMode {
                HStack(spacing: 20) {
                    Button("Select All") {
                        onSelectAll?()
                    }
                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))

                    Button("Clear") {
                        onClearSelection?()
                    }
                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))

                    Spacer()

                    Button("Add") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBatchAddToSetlist?()
                    }
                    .foregroundColor(selected.isEmpty ? .gray : selectedTheme.accentColor(for: colorScheme))
                    .disabled(selected.isEmpty)

                    Button("Delete") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBatchDelete?()
                    }
                    .foregroundColor(selected.isEmpty ? .gray : .red)
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // Search TextField
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CBColor.textTertiary)
                        .font(.cbIcon(.body, .regular))

                    TextField("Search songs...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(CBColor.textTertiary)
                                .font(.cbIcon(.body, .regular))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTheme.titleBarColor(for: colorScheme).opacity(0.8))
                .cornerRadius(CBRadius.control)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            List {
                ForEach(rows, id: \.id) { row in
                    HStack(spacing: 12) {
                        // Show selection circle in batch mode
                        if batchMode {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                if row.isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.cbIcon(.caption, .bold))
                                        .foregroundStyle(CBColor.textPrimary)
                                }
                            }
                            .frame(width: 24, height: 24)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.song.name)
                                .font(themeFont?(18, .bold) ?? .body.bold())
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if let sub = row.song.subtitle, !sub.isEmpty {
                                Text(sub)
                                    .font(.cb(.caption))
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else {
                                Text(" ").font(.cb(.caption)).foregroundColor(.clear)
                            }
                        }
                        Spacer()

                        // Show MIDI info and conflict warning
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 16) {
                                // Always show MIDI info
                                let midiInfo: String = {
                                    if row.song.kind == .cc {
                                        return "Ch \(row.song.channel) • CC \(row.song.cc)"
                                    } else {
                                        let noteName = (row.song.note ?? 0).midiNoteName
                                        return "Ch \(row.song.channel) • \(noteName)"
                                    }
                                }()
                                Text(midiInfo)
                                    .font(.cb(.micro))
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))

                                // Color indicator circle (always reserve space for alignment)
                                Group {
                                    if let hex = row.song.colorHex {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    } else {
                                        Circle()
                                            .fill(Color.clear)
                                    }
                                }
                                .frame(width: 20, height: 20)
                            }

                            // Show conflict warning below MIDI info
                            if let owner = filteredTakenBy(for: row.song) {
                                Text("⚠️ MIDI taken by: \(owner)")
                                    .font(.cb(.micro))
                                    .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .opacity(row.isInSetlist ? 0.55 : 1.0)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(.gray)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if !row.isInSetlist && !batchMode {
                            Button {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                onAddToSetlist(row.song)
                            } label: {
                                Label("Add to Cue List", systemImage: "plus.circle.fill")
                            }
                            .tint(.accentColor)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !batchMode {
                            Button(role: .destructive) {
                                onDeleteFromLibrary(row.song)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onTapGesture {
                        if batchMode {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onToggleSelect(row.song.id)
                        } else {
                            onRename(row.song)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .onReceive(NotificationCenter.default.publisher(for: .init("CBRemoveFromSetlist"))) { _ in }
        }
        .frame(maxWidth: .infinity)
    }

    private func filteredTakenBy(for song: Song) -> String? {
        let key = (song.kind == .note)
            ? MIDIKey(kind: .note, channel: song.channel, number: song.note ?? 0)
            : MIDIKey(kind: .cc, channel: song.channel, number: song.cc)
        guard let takenBy = conflictFor[key] else { return nil }

        // Filter out current song's name from the conflict list
        if takenBy.contains("|||") {
            // Multiple owners - split and filter
            let owners = takenBy.split(separator: "|||").map(String.init).filter { $0 != song.name }
            guard !owners.isEmpty else { return nil }
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if takenBy == song.name {
            // Single owner and it's us
            return nil
        }
        return takenBy
    }
}

// MARK: - Full-width batch toolbar
struct CBBatchToolbar: View {
    let selectedCount: Int
    var onSelectAll: () -> Void
    var onClear: () -> Void
    var onAddToSetlist: () -> Void
    var onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button("Select All", action: onSelectAll)
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                Button("Clear", action: onClear)
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAddToSetlist()
                } label: { Label("Add to Setlist", systemImage: "plus.circle.fill") }
                .buttonStyle(.cbPrimary)
                .disabled(selectedCount == 0)

                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDelete()
                } label: { Label("Delete", systemImage: "trash") }
                .buttonStyle(WhiteCapsuleButtonStyle())
                .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Drop Delegate for reordering without edit mode
struct ReorderDropDelegate: DropDelegate {
    let song: Song
    let songs: [Song]
    @Binding var draggedSong: Song?
    let onMove: (Int, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        // Provide visual feedback by triggering layout updates
        guard let draggedSong = draggedSong,
              let fromIndex = songs.firstIndex(where: { $0.id == draggedSong.id }),
              let toIndex = songs.firstIndex(where: { $0.id == song.id }),
              fromIndex != toIndex else {
            return
        }

        // Call onMove to provide real-time visual feedback as user drags
        // This makes the list reorder dynamically during the drag
        // Use a snappier spring animation for better responsiveness
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0.1)) {
            onMove(fromIndex, toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        // Clear the dragged song reference
        self.draggedSong = nil
        // Return true to indicate drop was handled
        // Note: The actual reordering already happened in dropEntered()
        return true
    }
}
