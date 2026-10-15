//
//  TopBar.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Shipping Ready
// All placeholder data removed - app starts completely blank


// MARK: - Top Bar (v1.1.0 Extreme Simplification)
struct CBTopBar: View {
    @Binding var mode: AppMode
    @Binding var showSideMenu: Bool
    @Binding var isEditing: Bool
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    @Binding var showLibraryPopover: Bool  // Control library popover visibility
    @Binding var songLibrary: [Song]  // Song library for popover
    @Binding var activeCueListSongs: [Song]  // Active cue list songs
    @Binding var editingSong: Song?  // Currently editing song
    @Binding var showAddEdit: Bool  // Show add/edit sheet
    @Binding var cueLists: [CueList]  // All cue lists
    @Binding var activeCueListID: UUID?  // Active cue list ID
    @Binding var showCueListChooser: Bool  // Show cue list chooser popover
    let libAddedAt: [UUID: Date]  // Timestamps for library songs
    let selectedThemeID: String  // Theme ID for popover
    let projectTitle: String
    let connectionTint: Color
    let connectionCoordinator: ConnectionCoordinator
    let titleBarColor: Color  // Theme title bar color
    let buttonColor: Color  // Theme button color for icons/text
    let textColor: Color  // Theme text color for title
    let lightButtonBackgroundColor: Color  // Slightly lighter version of title bar for button backgrounds
    let themeFont: (CGFloat, Font.Weight) -> Font  // Theme font function

    // Core actions
    var onConnections: () -> Void
    var onEditToggle: () -> Void
    var onAdd: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onMenuToggle: () -> Void
    var onAddToSetlist: (Song) -> Void  // Add song to setlist callback
    var onDeleteFromLibrary: (Song) -> Void  // Delete from library callback

    // Menu actions
    var onRenameProject: () -> Void
    var onNewProject: () -> Void
    var onSave: () -> Void
    var onSaveAs: () -> Void
    var onOpenProject: () -> Void
    var onImport: () -> Void
    var onExport: () -> Void
    var onShowMidiSettings: () -> Void
    var onShowAppearance: () -> Void = {}
    var onShowOnboarding: () -> Void = {}
    var onShowAbout: () -> Void = {}

    // Cue list actions
    var onSwitchCueList: (UUID) -> Void = { _ in }
    var onDuplicateCueList: (UUID) -> Void = { _ in }
    var onRenameCueList: (UUID) -> Void = { _ in }
    var onDeleteCueList: (UUID) -> Void = { _ in }
    var onCreateCueList: () -> Void = {}

    // v1.3: open Show mode
    var onShowMode: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        HStack(spacing: 0) {
            // LEFT CAPSULE: Menu button + Project Name
            // iPhone: Hide when in edit mode
            if !(isPhone && isEditing) {
                HStack(spacing: 8) {
                    // Hamburger menu capsule
                    mainMenuButton
                        .cbChip()
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)

                    // Cue list name capsule
                    projectNameButton
                        .cbChip()
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: TutorialButtonFramePreferenceKey.self,
                                    value: ["cueListNameButton": geo.frame(in: .global)]
                                )
                            }
                        )
                }
                .padding(.leading, 16)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: CapsuleBoundsPreferenceKey.self,
                            value: ["topBar.left": geo.frame(in: .global)]
                        )
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()

            // RIGHT CAPSULES: Separate capsules for connections and edit
            HStack(spacing: 8) {
                // v1.3: Show mode capsule (hide when editing)
                if !isEditing {
                    Button(action: onShowMode) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.cbIcon(.body, .semibold))
                            Text("Show")
                                .font(.cb(.body, .semibold))
                        }
                        .foregroundStyle(CBColor.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
                        .cbChip()
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(IOSPressButtonStyle())
                    .accessibilityLabel("Show mode")
                    .accessibilityHint("Opens the stage screen with Now, Next and GO")
                    .transition(.opacity.combined(with: .scale))
                }

                // Connections capsule (hide when editing)
                if !isEditing {
                    Button(action: onConnections) {
                        // All visual styling inside label so ButtonStyle animates the whole capsule
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.cbIcon(.large, .regular))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(connectionTint)

                            // Show connection type chip when connected
                            if connectionCoordinator.activeConnection == .usb {
                                CBTag(text: "USB", color: CBColor.usb)
                            } else if connectionCoordinator.activeConnection == .wifi {
                                CBTag(text: "Wi-Fi", color: CBColor.wifi)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
                        .cbChip()
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(IOSPressButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }

                // Edit controls capsule
                rightCapsuleControls
                .padding(.horizontal, isEditing ? 4 : 0)
                .frame(height: 44)
                .cbChip()
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TutorialButtonFramePreferenceKey.self,
                            value: ["editButton": geo.frame(in: .global)]
                        )
                    }
                )
            }
            .padding(.trailing, 16)
            .padding(.leading, isPhone && isEditing ? 16 : 0)  // iPhone edit mode: expand to left edge
            .offset(x: showSideMenu ? 300 : 0)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CapsuleBoundsPreferenceKey.self,
                        value: ["topBar.right": geo.frame(in: .global)]
                    )
                }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: showSideMenu)
        }
    }

    // MARK: - Subviews

    private var projectNameButton: some View {
        Button(action: { showCueListChooser.toggle() }) {
            HStack(spacing: 6) {
                Text(activeCueList?.name ?? "Untitled")
                    .font(themeFont(17, .semibold))
                    .foregroundStyle(CBColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: showCueListChooser ? "chevron.up" : "chevron.down")
                    .font(.cbIcon(.caption, .semibold))
                    .foregroundStyle(CBColor.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
        }
        .buttonStyle(IOSPressButtonStyle())
        .popover(isPresented: $showCueListChooser, arrowEdge: .top) {
            CueListChooserPopover(
                cueLists: $cueLists,
                activeCueListID: $activeCueListID,
                selectedThemeID: selectedThemeID,
                projectName: projectTitle,
                onSwitchCueList: { id in
                    // If clicking the already-active cue list, just close chooser
                    if id != activeCueListID {
                        onSwitchCueList(id)
                    }
                    showCueListChooser = false
                },
                onDuplicate: onDuplicateCueList,
                onRename: onRenameCueList,
                onDelete: onDeleteCueList,
                onCreateNew: onCreateCueList,
                onRenameProject: onRenameProject
            )
            .presentationCompactAdaptation(.popover)
            .presentationBackground(CBColor.background)
            .tint(.white)
        }
    }

    private var activeCueList: CueList? {
        guard let id = activeCueListID else { return cueLists.first }
        return cueLists.first(where: { $0.id == id })
    }

    private var mainMenuButton: some View {
        Button(action: onMenuToggle) {
            Image(systemName: showSideMenu ? "xmark" : "line.3.horizontal")
                .font(.cbIcon(.large, .medium))
                .foregroundStyle(CBColor.textPrimary)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(showSideMenu ? 90 : 0))
                .contentTransition(.symbolEffect(.replace))
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    // Unified right capsule that morphs between performance and edit modes
    private var rightCapsuleControls: some View {
        HStack(spacing: 4) {
            // Edit mode controls (show when editing)
            if isEditing {
                // Library button - opens song library popover
                Button(action: {
                    showLibraryPopover = true
                }) {
                    Image(systemName: "book")
                        .imageScale(.large)
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .transition(.opacity.combined(with: .scale))
                .id("libraryButton")
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TutorialButtonFramePreferenceKey.self,
                            value: ["libraryButton": geo.frame(in: .global)]
                        )
                    }
                )
                .popover(isPresented: $showLibraryPopover, arrowEdge: .top) {
                    SongLibraryPopover(
                        library: $songLibrary,
                        activeCueListSongs: $activeCueListSongs,
                        libAddedAt: libAddedAt,
                        selectedThemeID: selectedThemeID,
                        onAddToCueList: onAddToSetlist,
                        onRemoveFromCueList: { song in
                            // Remove song from active cue list
                            if let activeCueList = cueLists.first(where: { $0.id == activeCueListID }) {
                                var updatedList = activeCueList
                                updatedList.songs.removeAll(where: { $0.id == song.id })
                                if let index = cueLists.firstIndex(where: { $0.id == activeCueListID }) {
                                    cueLists[index] = updatedList
                                }
                            }
                        },
                        onDelete: onDeleteFromLibrary,
                        onEdit: { song in
                            editingSong = song
                            showAddEdit = true
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(CBColor.background)
                    .tint(.white)
                }

                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .imageScale(.large)
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .disabled(!canUndo)
                .opacity(canUndo ? 1.0 : 0.4)
                .transition(.opacity.combined(with: .scale))

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .imageScale(.large)
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .disabled(!canRedo)
                .opacity(canRedo ? 1.0 : 0.4)
                .transition(.opacity.combined(with: .scale))

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .imageScale(.large)
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .transition(.opacity.combined(with: .scale))
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TutorialButtonFramePreferenceKey.self,
                            value: ["addCueButton": geo.frame(in: .global)]
                        )
                    }
                )
            }

            // Edit/Done button (morphs between states) - pencil/checkmark icon like CueRowDesignPreview
            Button(action: onEditToggle) {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .imageScale(.large)
                    .foregroundColor(buttonColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IOSPressButtonStyle())
            .transition(.opacity.combined(with: .scale))
            .id(isEditing ? "doneButton" : "editButton")
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 32)
    }

}
