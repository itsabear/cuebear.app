//
//  CueListChooser.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation

// MARK: - Cue List Chooser Popover

enum CueListSortOption: String, CaseIterable, Identifiable {
    case nameAZ = "A-Z"
    case nameZA = "Z-A"
    case oldest = "Oldest First"
    case newest = "Newest First"

    var id: String { rawValue }
}

struct CueListChooserPopover: View {
    @Environment(\.colorScheme) var colorScheme

    @Binding var cueLists: [CueList]
    @Binding var activeCueListID: UUID?
    let selectedThemeID: String
    let projectName: String
    let onSwitchCueList: (UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onRename: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onCreateNew: () -> Void
    let onRenameProject: () -> Void

    @State private var searchQuery = ""
    @State private var sortOption: CueListSortOption = .nameAZ
    @State private var batchSelectMode = false
    @State private var selectedCueLists = Set<UUID>()
    @FocusState private var isSearchFocused: Bool
    @State private var showDeleteConfirmation = false
    @State private var showBatchDeleteConfirmation = false
    @State private var cueListToDelete: CueList?

    private var theme: AppTheme {
        AppTheme.allThemes.first(where: { $0.id == selectedThemeID }) ?? AppTheme.defaultTheme
    }

    private var textColor: Color {
        theme.primaryTextColor(for: colorScheme)
    }

    private var backgroundColor: Color {
        theme.backgroundColor(for: colorScheme)
    }

    private var titleBarColor: Color {
        theme.titleBarColor(for: colorScheme)
    }

    private var defaultCueColor: Color {
        .white  // Popover chrome uses light accent (matches title bar/control area)
    }

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var popoverWidth: CGFloat {
        isPhone ? min(380, UIScreen.main.bounds.width - 16) : 400
    }

    private var filteredCueLists: [CueList] {
        let filtered = searchQuery.isEmpty ? cueLists : cueLists.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

        // Sort the filtered lists
        switch sortOption {
        case .nameAZ:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .oldest:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var contentView: some View {
        let lists = filteredCueLists  // Compute once and reuse
        return VStack(spacing: 0) {
            headerView

            Divider()
                .background(textColor.opacity(0.2))

            if lists.isEmpty {
                emptyStateView
            } else {
                cueListsScrollView(lists)
            }
        }
        .frame(width: popoverWidth)
        .background(backgroundColor)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.cbIcon(.display, .regular))
                .foregroundColor(textColor.opacity(0.3))
            Text("No Cue Lists")
                .font(.cb(.large, .medium))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, maxHeight: 400)
        .background(backgroundColor)
    }

    private func cueListsScrollView(_ lists: [CueList]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(lists) { cueList in
                    SwipeableCueListRow(
                        cueList: cueList,
                        isActive: cueList.id == activeCueListID,
                        textColor: textColor,
                        backgroundColor: backgroundColor,
                        onTap: { onSwitchCueList(cueList.id) },
                        onDelete: {
                            cueListToDelete = cueList
                            showDeleteConfirmation = true
                        },
                        onDuplicate: { onDuplicate(cueList.id) },
                        onRename: { onRename(cueList.id) }
                    )
                }
            }
            .frame(width: popoverWidth)
            .clipped()
        }
        .frame(width: popoverWidth)
        .frame(maxHeight: 400)
        .clipped()
    }

    var body: some View {
        contentView
            .cbDialog("Delete Cue List", isPresented: $showDeleteConfirmation, themeFont: theme.font,
                message: "Are you sure you want to delete \"\(cueListToDelete?.name ?? "")\"?",
                buttons: [
                    .init("Delete", role: .destructive) {
                        if let cueList = cueListToDelete {
                            onDelete(cueList.id)
                        }
                    },
                    .init("Cancel", role: .cancel) { }
                ]
            )
            .cbDialog("Delete \(selectedCueLists.count) Cue Lists", isPresented: $showBatchDeleteConfirmation, themeFont: theme.font,
                message: "Are you sure you want to delete \(selectedCueLists.count) cue list\(selectedCueLists.count == 1 ? "" : "s")?",
                buttons: [
                    .init("Delete", role: .destructive) {
                        for cueListID in selectedCueLists {
                            onDelete(cueListID)
                        }
                        selectedCueLists.removeAll()
                        batchSelectMode = false
                    },
                    .init("Cancel", role: .cancel) { }
                ]
            )
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            // Top row: + button, project name
            HStack(spacing: 8) {
                Button(action: onCreateNew) {
                    Image(systemName: "plus")
                        .font(.cbIcon(.large, .medium))
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

                Button(action: onRenameProject) {
                    Text(projectName)
                        .font(.cb(.body, .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            // "CUE LISTS" label
            Text("CUE LISTS")
                .font(.cb(.caption, .semibold))
                .foregroundColor(textColor.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            // Search bar + sort + select row (same line, like song library)
            HStack(spacing: 8) {
                // Search bar — animates between full width and circular icon
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.cbIcon(points: batchSelectMode ? 18 : 16, .regular))
                        .foregroundColor(defaultCueColor)

                    if !batchSelectMode {
                        TextField("Search cue lists...", text: $searchQuery)
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
                            selectedCueLists.removeAll()
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
                        ForEach(CueListSortOption.allCases) { option in
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
                            selectedCueLists = Set(filteredCueLists.map { $0.id })
                        }) {
                            Text("All")
                                .font(.cb(.small, .medium))
                                .foregroundColor(defaultCueColor)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        Button(action: {
                            selectedCueLists.removeAll()
                        }) {
                            Text("Clear")
                                .font(.cb(.small, .medium))
                                .foregroundColor(defaultCueColor)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        Button(action: {
                            if !selectedCueLists.isEmpty {
                                showBatchDeleteConfirmation = true
                            }
                        }) {
                            Text("Delete")
                                .font(.cb(.small, .medium))
                                .foregroundColor(selectedCueLists.isEmpty ? textColor.opacity(0.3) : .red)
                                .padding(.horizontal, 10)
                                .frame(height: 44)
                        }
                        .buttonStyle(IOSPressButtonStyle())
                        .disabled(selectedCueLists.isEmpty)

                        Rectangle()
                            .fill(defaultCueColor.opacity(0.2))
                            .frame(width: 1, height: 24)
                            .padding(.horizontal, 2)

                        // X button to exit select mode
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                batchSelectMode = false
                                selectedCueLists.removeAll()
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

    @ViewBuilder
    private func cueListRow(_ cueList: CueList) -> some View {
        HStack(spacing: 12) {
            // Selection checkbox (in select mode)
            if batchSelectMode {
                Button(action: {
                    if selectedCueLists.contains(cueList.id) {
                        selectedCueLists.remove(cueList.id)
                    } else {
                        selectedCueLists.insert(cueList.id)
                    }
                }) {
                    Image(systemName: selectedCueLists.contains(cueList.id) ? "checkmark.circle.fill" : "circle")
                        .font(.cbIcon(.title, .regular))
                        .foregroundColor(selectedCueLists.contains(cueList.id) ? .white : textColor.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.trailing, 12)
            }

            // Cue list info
            Button(action: {
                if batchSelectMode {
                    if selectedCueLists.contains(cueList.id) {
                        selectedCueLists.remove(cueList.id)
                    } else {
                        selectedCueLists.insert(cueList.id)
                    }
                } else {
                    // Click to open cue list
                    onSwitchCueList(cueList.id)
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(cueList.name)
                                .font(.cb(.body, .medium))
                                .foregroundColor(textColor)

                            // Active indicator
                            if cueList.id == activeCueListID {
                                Image(systemName: "checkmark")
                                    .font(.cbIcon(.small, .semibold))
                                    .foregroundStyle(CBColor.success)
                            }
                        }

                        Text("\(cueList.songs.count) cue\(cueList.songs.count == 1 ? "" : "s")")
                            .font(.cb(.small))
                            .foregroundColor(textColor.opacity(0.6))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.leading, batchSelectMode ? 0 : 16)
                .padding(.trailing, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                if !batchSelectMode {
                    Button(action: { onDuplicate(cueList.id) }) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button(action: { onRename(cueList.id) }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: {
                        cueListToDelete = cueList
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .background(backgroundColor)
    }
}

// MARK: - Swipeable Cue List Row
struct SwipeableCueListRow: View {
    let cueList: CueList
    let isActive: Bool
    let textColor: Color
    let backgroundColor: Color
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onRename: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var showMenu = false

    private let deleteThreshold: CGFloat = -80
    private let deleteButtonWidth: CGFloat = 80

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .overlay(
                ZStack(alignment: .trailing) {
                    // Delete button background
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            onDelete()
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(CBColor.textPrimary)
                                .frame(width: deleteButtonWidth)
                                .frame(maxHeight: .infinity)
                        }
                        .background(Color.red)
                    }

                    // Main row content
                    Button(action: {
                        if offset == 0 {
                            onTap()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(cueList.name)
                                        .font(.cb(.body, isActive ? .semibold : .regular))
                                        .foregroundColor(textColor)

                                    if isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.cbIcon(.small, .regular))
                                            .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                                    }
                                }

                                Text("\(cueList.songs.count) cue\(cueList.songs.count == 1 ? "" : "s")")
                                    .font(.cb(.small))
                                    .foregroundColor(textColor.opacity(0.6))
                            }

                            Spacer()

                            // More button with menu
                            Menu {
                                Button(action: onTap) {
                                    Label("Open", systemImage: "arrow.right.circle")
                                }
                                Button(action: onDuplicate) {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                Button(action: onRename) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive, action: onDelete) {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.cbIcon(.body, .semibold))
                                    .foregroundColor(textColor.opacity(0.6))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(backgroundColor)
                    .offset(x: offset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { gesture in
                                isDragging = true
                                let translation = gesture.translation.width
                                // Only allow left swipe
                                if translation < 0 {
                                    offset = translation
                                } else if offset < 0 {
                                    // Allow dragging back to close
                                    offset = min(0, offset + translation)
                                }
                            }
                            .onEnded { gesture in
                                isDragging = false
                                let translation = gesture.translation.width
                                let velocity = gesture.predictedEndTranslation.width - translation

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if offset < deleteThreshold || velocity < -50 {
                                        // Show delete button
                                        offset = -deleteButtonWidth
                                    } else {
                                        // Close
                                        offset = 0
                                    }
                                }
                            }
                    )
                }
            )
            .clipped()
    }
}
