//
//  ContentView+SideMenu.swift — Cue Bear
//  ContentView: Side Menu
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - Side Menu
    var sideMenuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer for floating top bar (transparent)
            Spacer().frame(height: 80)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Section 0: Mode Selection
                    sideMenuSection(title: "Performance") {
                        // Regular Mode (no pill)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .regular
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .regular {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Regular")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        // Regular + Remote (navigation capsule)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .regularPlusRemote
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .regularPlusRemote {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Navigator")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        // Cue Mode (GO capsule)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .cue
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .cue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Cue Mode")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 1: File Operations
                    sideMenuSection(title: "Project") {
                        sideMenuButton("New Project", icon: "doc.badge.plus", action: {
                            if isEditing { isEditing = false }
                            newProjectFlow()
                            closeMenu()
                        })
                        sideMenuButton("Save", icon: "square.and.arrow.down", action: {
                            if isEditing { isEditing = false }
                            saveCurrentProject(overwrite: true)
                            closeMenu()
                        })
                        sideMenuButton("Save As...", icon: "square.and.arrow.down.on.square", action: {
                            if isEditing { isEditing = false }
                            saveCurrentProject(overwrite: false)
                            closeMenu()
                        })
                        sideMenuButton("Open...", icon: "folder", action: {
                            if isEditing { isEditing = false }
                            projectsList = ProjectIO.list()
                            showProjects = true
                            closeMenu()
                        })
                        sideMenuButton("Import...", icon: "arrow.down.doc", action: {
                            if isEditing { isEditing = false }
                            openDocumentPicker()
                            closeMenu()
                        })
                        sideMenuButton("Export...", icon: "square.and.arrow.up", action: {
                            if isEditing { isEditing = false }
                            exportCurrentProject()
                            closeMenu()
                        })
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 2: Settings
                    sideMenuSection(title: "Settings") {
                        sideMenuButton("MIDI Settings...", icon: "slider.horizontal.3", action: {
                            if isEditing { isEditing = false }
                            showMidiTable = true
                            closeMenu()
                        })
                        sideMenuButton("Appearance...", icon: "paintbrush", action: {
                            if isEditing { isEditing = false }
                            showAppearanceSettingsSheet = true
                            closeMenu()
                        })
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 3: Help
                    sideMenuSection(title: "Help") {
                        sideMenuButton("Getting Started", icon: "questionmark.circle", action: {
                            if isEditing { isEditing = false }
                            // Only show onboarding if crash alert is not active
                            if !crashAlertActive {
                                showOnboarding = true
                            }
                            closeMenu()
                        })
                        #if DEBUG
                        // About button with long press for admin panel
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .frame(width: 24)
                                .foregroundColor(currentTheme.accentColor(for: colorScheme))
                            Text("About Cue Bear")
                                .font(currentTheme.font(size: 15, weight: .regular))
                                .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditing { isEditing = false }
                            showAboutSheet = true
                            closeMenu()
                        }
                        .onLongPressGesture(minimumDuration: 3.0) {
                            showAdminPanel = true
                            closeMenu()
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                        #else
                        sideMenuButton("About Cue Bear", icon: "info.circle", action: {
                            if isEditing { isEditing = false }
                            showAboutSheet = true
                            closeMenu()
                        })
                        #endif

                        // Reset Tutorials button (in Help section)
                        sideMenuButton("Reset Tutorials", icon: "arrow.counterclockwise", action: {
                            // Reset all tutorial flags
                            hasSeenTutorial1 = false
                            hasSeenTutorial2 = false
                            hasSeenTutorial2b = false
                            hasSeenTutorial2c = false
                            hasSeenTutorial3 = false
                            // Also reset nav pill and cue capsule tutorials
                            UserDefaults.standard.removeObject(forKey: "hasSeenNavPillTutorial")
                            UserDefaults.standard.removeObject(forKey: "hasSeenCueCapsuleTutorial")
                            // Reset onboarding so it shows again
                            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
                            closeMenu()
                            // Show onboarding immediately after menu closes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showOnboarding = true
                            }
                        })
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(currentTheme.titleBarColor(for: colorScheme))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 2, y: 0)
    }

    func sideMenuSection<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(currentTheme.font(size: 11, weight: .semibold))
                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                    .textCase(.uppercase)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
            }
            content()
        }
    }

    func sideMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(currentTheme.accentColor(for: colorScheme))
                Text(title)
                    .font(currentTheme.font(size: 15, weight: .regular))
                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    func closeMenu() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showSideMenu = false
        }
    }

    func mainStack() -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                // Theme background color - extends to all edges including safe areas
                currentTheme.backgroundColor(for: colorScheme)
                    .ignoresSafeArea(edges: .all)

                // Main content (without top bar - it will overlay)
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        buildMiddleSectionView()
                    }
                    .disabled(showSideMenu)
                    .blur(radius: showSideMenu ? 3 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.85), value: showSideMenu)
                    .ignoresSafeArea(edges: .bottom) // Allow cues to extend into bottom safe area behind home indicator

                    // Floating control area capsules - NOT clipped so they can slide off-screen
                    ZStack {
                        if !isEditing && effectivelyCollapsedForOverlay && showCollapsedCapsule {
                            // Show small collapsed capsule with sequential animation
                            // Match expanded control area positioning
                            let bottomPadding: CGFloat = 21
                            AnyView(collapsedControlCapsule)
                                .padding(.bottom, bottomPadding)  // Match expanded control area bottom padding
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .ignoresSafeArea(edges: .bottom)  // Match expanded control area safe area handling
                                .zIndex(0)
                                .id("collapsed")
                                .transition(.move(edge: .bottom))
                        }

                        // PERFORMANCE: Only create CBControlSection when controlSectionReady is true
                        // This delays heavy view initialization until after initial app layout
                        // NOTE: Removed GeometryReader background - it caused UI freeze due to layout loop
                        if !isEditing && !effectivelyCollapsedForOverlay && showExpandedArea && controlSectionReady {
                            let isLandscape = verticalSizeClass == .compact
                            // Bottom padding: X + 2Y where X = home indicator height (~5pt), Y = its distance from bottom (8pt)
                            let bottomPadding: CGFloat = 21

                            AnyView(controlSectionView)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLandscape ? .bottomTrailing : .bottom)
                                .padding(.trailing, isLandscape ? 16 : 0)
                                .padding(.bottom, bottomPadding)
                                .ignoresSafeArea(edges: .bottom)
                                .transition(.move(edge: .bottom))
                                .zIndex(1)
                                .id("expandedNonEdit")
                        }
                    }
                    // NOTE: No blanket .animation() here — using explicit withAnimation in onChange
                    // to prevent parent spring from infecting child view properties (e.g. chevron opacity)
                    .onChange(of: effectivelyCollapsedForOverlay) { _, isCollapsed in
                        // Mark as animating - prevents GeometryReader from updating height during animation
                        isAnimatingControlArea = true

                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if isCollapsed {
                                // Collapsing: hide expanded area and show collapsed capsule simultaneously
                                showExpandedArea = false
                                showCollapsedCapsule = true
                            } else {
                                // Expanding: hide collapsed capsule and show expanded area simultaneously
                                showCollapsedCapsule = false
                                showExpandedArea = true
                            }
                        }

                        if isCollapsed {
                            // Set collapsed height immediately
                            controlAreaHeight = 56
                        } else {
                            // Set expanded height immediately from bounds or use fixed estimate
                            // IMPORTANT: Do NOT access UIScreen.main.bounds here - causes freeze
                            if let actualHeight = capsuleBounds["controlArea.main"]?.height, actualHeight > 56 {
                                controlAreaHeight = actualHeight
                            } else {
                                // Use fixed estimate - actual height will be set by CBControlSection
                                controlAreaHeight = 200
                            }
                        }

                        // Clear animating flag after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isAnimatingControlArea = false
                        }
                    }
                    .onAppear {
                        // Initialize visibility based on initial state
                        showCollapsedCapsule = effectivelyCollapsedForOverlay
                        showExpandedArea = !effectivelyCollapsedForOverlay

                        // Initialize control area height based on initial state
                        if effectivelyCollapsedForOverlay {
                            controlAreaHeight = 56  // Collapsed capsule height
                        } else {
                            // For expanded state, try to get actual height from bounds or use estimate
                            if let actualHeight = capsuleBounds["controlArea.main"]?.height {
                                controlAreaHeight = actualHeight
                            } else {
                                // Use fixed estimate - UIScreen.main.bounds access during layout causes freeze
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                let maxHeight = isPhone ? globalCachedPortraitWidth * 0.8 : 200
                                controlAreaHeight = maxHeight
                            }
                        }

                        // PERFORMANCE: Delay CBControlSection creation until after initial layout
                        // This prevents the heavy view from blocking app startup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            controlSectionReady = true
                        }
                    }
                }

                // Floating top bar overlay
                VStack {
                    AnyView(topBarView)
                        .padding(.top, UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact ? 8 : 0)
                    Spacer()
                }
                .background(Color.clear)
                .zIndex(10)

                // Side menu with overlay
                // Overlay - fades independently
                if showSideMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                showSideMenu = false
                            }
                        }
                        .zIndex(1)
                }

                // Menu - slides independently
                if showSideMenu {
                    sideMenuView
                        .frame(width: 320)
                        .transition(.move(edge: .leading))
                        .zIndex(2)
                }
            }
        )
    }
}
