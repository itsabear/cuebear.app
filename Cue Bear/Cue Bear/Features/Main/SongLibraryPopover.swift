//
//  SongLibraryPopover.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation

// MARK: - Song Library Popover

/// Sort options for the song library
enum LibrarySortOption: String, CaseIterable, Identifiable {
    case nameAZ = "A-Z"
    case nameZA = "Z-A"
    case oldest = "Oldest First"
    case newest = "Newest First"

    var id: String { rawValue }
}

/// Popover view for managing the song library
struct SongLibraryPopover: View {
    @Environment(\.colorScheme) var colorScheme

    // Data
    @Binding var library: [Song]
    @Binding var activeCueListSongs: [Song]
    let libAddedAt: [UUID: Date]
    let selectedThemeID: String

    // Callbacks
    let onAddToCueList: (Song) -> Void
    let onRemoveFromCueList: (Song) -> Void
    let onDelete: (Song) -> Void
    let onEdit: (Song) -> Void

    // State
    @State private var searchQuery: String = ""
    @State private var sortOption: LibrarySortOption = .nameAZ
    @State private var selectedSongs: Set<UUID> = []
    @State private var batchSelectMode: Bool = false
    @FocusState private var isSearchFocused: Bool
    @State private var songToDelete: Song? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showBatchDeleteConfirmation: Bool = false
    @State private var songMenuToShow: Song? = nil

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var backgroundColor: Color {
        selectedTheme.backgroundColor(for: colorScheme)
    }

    private var titleBarColor: Color {
        selectedTheme.titleBarColor(for: colorScheme)
    }

    private var textColor: Color {
        selectedTheme.primaryTextColor(for: colorScheme)
    }

    private var defaultCueColor: Color {
        .white  // Popover chrome uses light accent (matches title bar/control area)
    }

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    // Get IDs of songs already in active cue list
    // Includes both direct song IDs and original IDs of aliased cues
    private var activeSongIDs: Set<UUID> {
        var ids = Set<UUID>()
        for song in activeCueListSongs {
            ids.insert(song.id)
            // If this is an alias, also include the original cue's ID
            if let aliasedID = song.aliasedCueID {
                ids.insert(aliasedID)
            }
        }
        return ids
    }

    // Check if a library song is in the active cue list
    // Matches by ID or by MIDI data (to handle duplicated cue lists)
    private func isLibrarySongInCueList(_ librarySong: Song) -> Bool {
        // First check by ID (handles direct matches and aliases)
        if activeSongIDs.contains(librarySong.id) {
            return true
        }

        // Then check by MIDI data (handles duplicated cue lists)
        return activeCueListSongs.contains { cueListSong in
            cueListSong.kind == librarySong.kind &&
            cueListSong.channel == librarySong.channel &&
            (cueListSong.kind == .cc ? cueListSong.cc == librarySong.cc : cueListSong.note == librarySong.note)
        }
    }

    // Filtered and sorted library songs
    private var filteredSongs: [Song] {
        let filtered = library.filter { song in
            if searchQuery.isEmpty {
                return true
            }
            return song.name.localizedCaseInsensitiveContains(searchQuery) ||
                   (song.subtitle ?? "").localizedCaseInsensitiveContains(searchQuery)
        }

        return sortedSongs(filtered)
    }

    private func sortedSongs(_ songs: [Song]) -> [Song] {
        switch sortOption {
        case .nameAZ:
            return songs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return songs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newest:
            return songs.sorted { (libAddedAt[$0.id] ?? .distantPast) > (libAddedAt[$1.id] ?? .distantPast) }
        case .oldest:
            return songs.sorted { (libAddedAt[$0.id] ?? .distantPast) < (libAddedAt[$1.id] ?? .distantPast) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls and search bar
            headerView

            // Song list
            List {
                ForEach(filteredSongs) { song in
                    libraryRowView(for: song)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(backgroundColor)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(width: isPhone ? min(380, UIScreen.main.bounds.width - 16) : 400, height: 500)
        .background(backgroundColor)
        .cbDialog("Delete \(selectedSongs.count) Cues", isPresented: $showBatchDeleteConfirmation, themeFont: selectedTheme.font,
            message: "Are you sure you want to delete \(selectedSongs.count) cues from the library?",
            buttons: [
                .init("Delete", role: .destructive) {
                    let songsToDelete = library.filter { selectedSongs.contains($0.id) }
                    for song in songsToDelete {
                        onDelete(song)
                    }
                    selectedSongs.removeAll()
                    batchSelectMode = false
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            // Single row: search bar (shrinks to icon in batch mode), sort, select/batch actions
            HStack(spacing: 8) {
                // Search bar — always present, animates between full width and circular icon
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.cbIcon(points: batchSelectMode ? 18 : 16, .regular))
                        .foregroundColor(defaultCueColor)

                    if !batchSelectMode {
                        TextField("Search songs...", text: $searchQuery)
                            .font(.cb(.body))
                            .foregroundColor(textColor)
                            .focused($isSearchFocused)

                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.cbIcon(.body, .regular))
                                    .foregroundColor(defaultCueColor.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, batchSelectMode ? 0 : 14)
                .frame(width: batchSelectMode ? 44 : nil, height: 44)
                .frame(maxWidth: batchSelectMode ? nil : .infinity)
                .cbChip()
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                .onTapGesture {
                    if batchSelectMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            batchSelectMode = false
                            selectedSongs.removeAll()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isSearchFocused = true
                        }
                    } else {
                        isSearchFocused = true
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: batchSelectMode)

                if batchSelectMode {
                    Spacer()
                }

                // Sort menu - separate capsule (hidden in batch mode)
                if !batchSelectMode {
                    Menu {
                        ForEach(LibrarySortOption.allCases) { option in
                            Button(action: { sortOption = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.cbIcon(.large, .regular))
                            .foregroundStyle(CBColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: CBRadius.control)
                                    .fill(CBColor.chip)
                                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                            )
                            .overlay(RoundedRectangle(cornerRadius: CBRadius.control).stroke(CBColor.stroke, lineWidth: CBSize.hairline))
                            .clipShape(RoundedRectangle(cornerRadius: CBRadius.control))
                    }
                }

                // Select capsule — grows into batch actions
                HStack(spacing: 0) {
                    if batchSelectMode {
                        Button(action: {
                            selectedSongs = Set(filteredSongs.map { $0.id })
                        }) {
                            Text("All")
                                .font(.cb(.small, .medium))
                                .foregroundColor(defaultCueColor)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        Button(action: {
                            selectedSongs.removeAll()
                        }) {
                            Text("Clear")
                                .font(.cb(.small, .medium))
                                .foregroundColor(defaultCueColor)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        Button(action: {
                            for songID in selectedSongs {
                                if let song = library.first(where: { $0.id == songID }),
                                   !activeSongIDs.contains(songID) {
                                    onAddToCueList(song)
                                }
                            }
                            selectedSongs.removeAll()
                            UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
                        }) {
                            Text("Add")
                                .font(.cb(.small, .medium))
                                .foregroundColor(selectedSongs.isEmpty ? textColor.opacity(0.3) : .green)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())
                        .disabled(selectedSongs.isEmpty)

                        Button(action: {
                            if !selectedSongs.isEmpty {
                                showBatchDeleteConfirmation = true
                            }
                        }) {
                            Text("Delete")
                                .font(.cb(.small, .medium))
                                .foregroundColor(selectedSongs.isEmpty ? textColor.opacity(0.3) : .red)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())
                        .disabled(selectedSongs.isEmpty)

                        Rectangle()
                            .fill(defaultCueColor.opacity(0.2))
                            .frame(width: 1, height: 24)
                            .padding(.horizontal, 2)

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                batchSelectMode = false
                                selectedSongs.removeAll()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.cbIcon(.small, .medium))
                                .foregroundColor(defaultCueColor)
                                .frame(width: 36, height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())
                    } else {
                        // Collapsed: just the checklist icon
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                batchSelectMode = true
                            }
                        }) {
                            Image(systemName: "checklist")
                                .font(.cbIcon(.large, .regular))
                                .foregroundColor(defaultCueColor)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())
                    }
                }
                .cbChip()
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: batchSelectMode)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .background(backgroundColor)
    }

    private func libraryRowView(for song: Song) -> some View {
        let isInCueList = isLibrarySongInCueList(song)
        let isSelected = selectedSongs.contains(song.id)

        return HStack(spacing: 0) {
            // Selection radial (in batch select mode)
            if batchSelectMode {
                Button(action: {
                    if selectedSongs.contains(song.id) {
                        selectedSongs.remove(song.id)
                    } else {
                        selectedSongs.insert(song.id)
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(defaultCueColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(defaultCueColor)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.trailing, 12)
            }

            // Song info
            Button(action: {
                if batchSelectMode {
                    if selectedSongs.contains(song.id) {
                        selectedSongs.remove(song.id)
                    } else {
                        selectedSongs.insert(song.id)
                    }
                } else {
                    onEdit(song)
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.cb(.body, .medium))
                            .foregroundColor(isInCueList ? textColor.opacity(0.4) : textColor)

                        if let subtitle = song.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.cb(.small))
                                .foregroundColor(isInCueList ? textColor.opacity(0.3) : textColor.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // MIDI data display (matching cue list format)
                    if song.midiEnabled {
                        let midiText: String = {
                            if song.kind == .cc {
                                return "Ch \(song.channel)  •  CC \(song.cc)"
                            } else {
                                let noteName = (song.note ?? 60).midiNoteName
                                return "Ch \(song.channel)  •  \(noteName)"
                            }
                        }()

                        Text(midiText)
                            .font(.cb(.micro))
                            .foregroundColor(textColor.opacity(0.6))
                            .padding(.trailing, 8)
                    } else {
                        Text("No MIDI")
                            .font(.cb(.micro))
                            .foregroundColor(textColor.opacity(0.4))
                            .padding(.trailing, 8)
                    }

                    // More button with menu (hide in batch select mode)
                    if !batchSelectMode {
                        Menu {
                            // Show "Add to Cue List" or "Remove from Cue List" based on whether song is in cue list
                            if !isInCueList {
                                Button(action: {
                                    onAddToCueList(song)
                                }) {
                                    Label("Add to Cue List", systemImage: "plus.circle")
                                }
                            } else {
                                Button(action: {
                                    onRemoveFromCueList(song)
                                }) {
                                    Label("Remove from Cue List", systemImage: "minus.circle")
                                }
                            }

                            Button(action: {
                                onEdit(song)
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                onDelete(song)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.cbIcon(.body, .semibold))
                                .foregroundColor(textColor.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 8)
                    }
                }
                .padding(.vertical, 12)
                .padding(.leading, batchSelectMode ? 0 : 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(backgroundColor)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            // Add to cue list action (swipe right, disabled if already in cue list)
            if !isInCueList {
                Button {
                    onAddToCueList(song)
                    UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .tint(CBColor.success)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Delete action (swipe left)
            Button(role: .destructive) {
                onDelete(song)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: false)
        .clipped()
    }
}
