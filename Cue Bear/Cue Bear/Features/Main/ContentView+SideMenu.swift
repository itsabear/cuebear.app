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
            Spacer().frame(height: CBSpace.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Shows (autosave replaces Save)
                    sideMenuSection(title: "Shows") {
                        sideMenuButton("New show", icon: "doc.badge.plus", action: {
                            newProjectFlow()
                            closeMenu()
                        })
                        sideMenuButton("Open a show", icon: "folder", action: {
                            projectsList = ProjectIO.list()
                            showProjects = true
                            closeMenu()
                        })
                        sideMenuButton("Duplicate this show", icon: "plus.square.on.square", action: {
                            saveCurrentProject(overwrite: false)
                            closeMenu()
                        })
                        sideMenuButton("Rename this show", icon: "pencil", action: {
                            tempName = projectName
                            showNamePrompt = true
                            closeMenu()
                        })
                        sideMenuButton("Import", icon: "arrow.down.doc", action: {
                            openDocumentPicker()
                            closeMenu()
                        })
                        sideMenuButton("Export", icon: "square.and.arrow.up", action: {
                            exportCurrentProject()
                            closeMenu()
                        })
                    }

                    Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
                        .padding(.horizontal, CBSpace.xl)

                    sideMenuSection(title: "MIDI") {
                        sideMenuButton("MIDI overview", icon: "list.bullet.rectangle", action: {
                            showMidiTable = true
                            closeMenu()
                        })
                    }

                    Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
                        .padding(.horizontal, CBSpace.xl)

                    // Section 3: Help
                    sideMenuSection(title: "Help") {
                        sideMenuButton("Getting started", icon: "questionmark.circle", action: {
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
                                .font(.cbIcon(.body, .regular))
                                .frame(width: 24)
                                .foregroundStyle(CBColor.textSecondary)
                            Text("About Cue Bear")
                                .font(.cb(.body))
                                .foregroundStyle(CBColor.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, CBSpace.xl)
                        .frame(minHeight: CBSize.touch)
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

                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(CBColor.background.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle().fill(CBColor.separator).frame(width: CBSize.hairline).ignoresSafeArea()
        }
        .shadow(color: .black.opacity(0.3), radius: 16, x: 4, y: 0)
    }

    func sideMenuSection<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                CBSectionLabel(title)
                    .padding(.horizontal, CBSpace.xl)
                    .padding(.top, CBSpace.l)
                    .padding(.bottom, CBSpace.xs)
            }
            content()
        }
    }

    func sideMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.cbIcon(.body, .regular))
                    .frame(width: 24)
                    .foregroundStyle(CBColor.textSecondary)
                Text(title)
                    .font(.cb(.body))
                    .foregroundStyle(CBColor.textPrimary)
                Spacer()
            }
            .padding(.horizontal, CBSpace.xl)
            .frame(minHeight: CBSize.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    func closeMenu() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showSideMenu = false
        }
    }

    /// The whole screen: the mode bar, then Show or Build, with the side menu sliding over.
    func mainStack() -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                CBColor.background
                    .ignoresSafeArea(edges: .all)

                VStack(spacing: 0) {
                    modeBarView
                    stageView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .disabled(showSideMenu)

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
