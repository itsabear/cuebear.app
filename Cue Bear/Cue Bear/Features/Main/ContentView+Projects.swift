//
//  ContentView+Projects.swift — Cue Bear
//  ContentView: Automatic Save, Document-Based, Ready for Shipping
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension ContentView {
    // MARK: - Automatic Save/Open Functions
    
    /// Start automatic saving with debouncing
    func startAutosave() {
        // Cancel existing autosave task
        autosaveTask?.cancel()

        // Only autosave if project has a name (not "Untitled Project")
        guard !isUntitledProject(projectName) && !projectName.isEmpty else { return }

        autosaveTask = Task {
            // Wait 2 seconds before saving to debounce rapid changes
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if isDirty && !isUntitledProject(projectName) {
                    debugPrint("💾 Auto-saving project: \(projectName)")
                    do {
                        try ProjectIO.save(name: projectName, cueLists: store.cueLists, activeCueListID: store.activeCueListID, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel, theme: selectedThemeID, appMode: store.mode, midiFiltersEnabled: midiFiltersEnabled, midiFilter: midiFilter, customMidiFilters: customMidiFilters)
                        isDirty = false
                        debugPrint("✅ Auto-save completed: \(projectName)")
                    } catch {
                        debugPrint("❌ Auto-save failed: \(error)")
                    }
                }
            }
        }
    }

    
    /// Automatically open the last project on app launch
    @MainActor func autoOpenLastProject() async {
        debugPrint("🔍 Auto-open check - projectName: '\(projectName)'")
        debugPrint("🔍 UserDefaults lastProjectName: '\(UserDefaults.standard.string(forKey: "lastProjectName") ?? "nil")'")
        debugPrint("🔍 hasCompletedInitialLaunch: \(hasCompletedInitialLaunch)")

        // First launch - new users start with an empty project
        if !hasCompletedInitialLaunch {
            debugPrint("🎵 First launch detected - starting with empty project")
            hasCompletedInitialLaunch = true
            return
        }

        // For subsequent launches, load the last opened project
        guard !isUntitledProject(projectName) && !projectName.isEmpty else {
            debugPrint("⏭️ Skipping auto-open - projectName is 'Untitled Project' or empty")
            // For "Untitled Project" projects, try to restore library from autosave
            if let saved = await Task.detached(priority: .userInitiated, operation: { ProjectIO.loadLibraryAutosave() }).value {
                songLibrary = saved
                debugPrint("📂 Restored library from autosave for Untitled project (\(saved.count) songs)")
            }
            return
        }

        // Check if the project file exists
        do {
            let name = projectName
            let payload = try await Task.detached(priority: .userInitiated) { try ProjectIO.load(name: name) }.value
            debugPrint("🔄 Auto-opening last project: \(projectName)")
            debugPrint("📦 Auto-open payload - cueLists: \(payload.cueLists?.count ?? 0), library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Set loading flag to prevent global channel toggle from triggering backup/restore
            isLoadingProject = true

            // Load the project data - migrate legacy format if needed
            if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                debugPrint("🔄 Migrating legacy auto-open project to v1.2.0")
                let mainList = CueList(name: "Main", songs: legacySetlist)
                store.cueLists = [mainList]
                store.activeCueListID = mainList.id
                debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
            } else {
                store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                store.activeCueListID = payload.activeCueListID ?? store.cueLists.first?.id
            }
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Restore MIDI filter settings if saved
            // MIDI filter settings are global preferences (UserDefaults), not per-project.
            // Do not restore from project file — loadMidiFiltersFromUserDefaults() on onAppear handles this.

            // Reset loading flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoadingProject = false
            }
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil {
                libAddedAt[s.id] = now
            }
            isDirty = false

            // Clear autosave when loading a named project
            ProjectIO.clearLibraryAutosave()

            debugPrint("✅ Successfully auto-opened: \(projectName)")
        } catch {
            debugPrint("❌ Failed to auto-open '\(projectName)': \(error)")
            debugPrint("💡 Project may have been deleted or corrupted")
            // Reset to untitled if project doesn't exist
            projectName = "Untitled"
        }
    }

    
    // MARK: - Document-Based Project Functions
    
    /// Open document picker to load projects from Files/iCloud Drive
    func openDocumentPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("❌ Could not find root view controller for document picker")
            return
        }
        
        debugPrint("📁 ContentView: Presenting document picker from root view controller")

        DocumentProjectIO.presentDocumentPicker(from: rootViewController) { url in
            debugPrint("📁 ContentView: Document picker completion called with URL: \(url?.absoluteString ?? "nil")")

            guard let url = url else {
                debugPrint("📁 ContentView: No URL received (user cancelled)")
                return
            }

            debugPrint("📁 ContentView: Calling openProject with URL: \(url.path)")

            DocumentProjectIO.openProject(from: url) { payload in
                DispatchQueue.main.async {
                    if let payload = payload {
                        debugPrint("✅ ContentView: Project payload received: \(payload.name)")

                        // Generate unique name if project with same name already exists
                        let uniqueName = self.uniqueProjectName(baseName: payload.name)
                        if uniqueName != payload.name {
                            debugPrint("📝 ContentView: Project renamed from '\(payload.name)' to '\(uniqueName)' to avoid overwrite")
                        }

                        // Set loading flag to prevent global channel toggle from triggering backup/restore
                        self.isLoadingProject = true

                        self.projectName = uniqueName

                        // Migrate legacy format if needed
                        if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                            debugPrint("🔄 Migrating imported legacy project to v1.2.0")
                            let mainList = CueList(name: "Main", songs: legacySetlist)
                            self.store.cueLists = [mainList]
                            self.store.activeCueListID = mainList.id
                            debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
                        } else {
                            self.store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                            self.store.activeCueListID = payload.activeCueListID ?? self.store.cueLists.first?.id
                        }
                        self.songLibrary = payload.library
                        self.controlButtons = payload.controls
                        self.isGlobalChannel = payload.isGlobalChannel ?? false
                        self.globalChannel = payload.globalChannel ?? 1

                        // Reset loading flag after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isLoadingProject = false
                        }
                        let now = Date()
                        for s in self.songLibrary where self.libAddedAt[s.id] == nil {
                            self.libAddedAt[s.id] = now
                        }
                        self.isDirty = true  // Mark as dirty so user needs to save the imported project
                        debugPrint("✅ ContentView: Project loaded successfully as: \(uniqueName)")
                    } else {
                        debugPrint("❌ ContentView: Failed to load project - showing error alert")
                        self.documentLoadErrorMessage = "Could not open the selected project file. The file may be corrupted or in an unsupported format."
                        self.showDocumentLoadError = true
                    }
                }
            }
        }
    }

    /// Export current project to share sheet (save to Files, AirDrop, etc.)
    func exportCurrentProject() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("❌ Could not find root view controller for export")
            return
        }

        debugPrint("📤 ContentView: Exporting project: \(projectName)")

        // Create payload from current state
        let payload = ProjectPayload(
            name: projectName,
            cueLists: store.cueLists,
            activeCueListID: store.activeCueListID,
            library: songLibrary,
            controls: controlButtons,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel,
            theme: selectedThemeID,
            appMode: store.mode
        )

        // Present share sheet
        DocumentProjectIO.exportProject(
            name: projectName,
            data: payload,
            from: rootViewController
        )
    }

    func newProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                createNewProject()
            }
        } else {
            createNewProject()
        }
    }

    func openProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                projectsList = ProjectIO.list()
                showProjects = true
            }
        } else {
            projectsList = ProjectIO.list()
            showProjects = true
        }
    }

    func createNewProject() {
        projectName = "Untitled Project"
        store.reset()  // Reset to single "Untitled Cue List"
        songLibrary.removeAll()
        controlButtons.removeAll()
        libAddedAt.removeAll()
        isDirty = false
        // No seeding for shipping - start blank

        // v1.0.8: Dismiss project sheet after creating new project
        showProjects = false
    }

    
    func checkUnsavedChangesBeforeAction(_ action: @escaping () -> Void) {
        // v1.0.8: Only show save prompt for projects that have been saved before (not "Untitled Project")
        // Matches autosave behavior pattern used throughout the app
        if isDirty && !isUntitledProject(projectName) {
            showSaveChangesAlert = true
            pendingAction = action
        } else {
            action()
        }
    }

    // Helper function to check if project name is untitled
    func isUntitledProject(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Untitled" || trimmed == "Untitled Project"
    }
}
