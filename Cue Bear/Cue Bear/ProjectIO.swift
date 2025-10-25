import Foundation

/// Legacy project storage system (Documents/CueBearProjects/)
/// Kept for backward compatibility and migration
enum ProjectIO {
    static let folderName = "CueBearProjects"

    static func baseFolder() throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    static func list() -> [String] {
        debugPrint("📁 ProjectIO.list() called")
        do {
            let dir = try baseFolder()
            debugPrint("📁 Looking for projects in: \(dir.path)")
            
            let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            debugPrint("📁 Found \(items.count) items in directory")
            
            let cuebearFiles = items.filter { $0.pathExtension.lowercased() == "cuebear" }
            debugPrint("📁 Found \(cuebearFiles.count) .cuebear files")
            
            let projectNames = cuebearFiles.map { $0.deletingPathExtension().lastPathComponent }
            let sortedNames = projectNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
            debugPrint("📁 Project names: \(sortedNames)")
            debugPrint("📁 Returning \(sortedNames.count) projects")
            return sortedNames
        } catch {
            debugPrint("❌ Failed to list projects: \(error)")
            return []
        }
    }

    static func path(for name: String) throws -> URL {
        try baseFolder().appendingPathComponent("\(name).cuebear", conformingTo: .data) 
    }

    static func save(name: String, setlist: [Song], library: [Song], controls: [ControlButton], isGlobalChannel: Bool? = nil, globalChannel: Int? = nil) throws {
        let payload = ProjectPayload(name: name, setlist: setlist, library: library, controls: controls, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: try path(for: name), options: .atomic)
    }

    static func load(name: String) throws -> ProjectPayload {
        let data = try Data(contentsOf: try path(for: name))
        return try JSONDecoder().decode(ProjectPayload.self, from: data)
    }

    static func delete(name: String) {
        debugPrint("🗑️ ProjectIO.delete called with name: '\(name)'")

        do {
            let filePath = try path(for: name)
            debugPrint("🗑️ Attempting to delete project: \(name) at \(filePath.path)")
            debugPrint("🗑️ File exists check: \(FileManager.default.fileExists(atPath: filePath.path))")

            if FileManager.default.fileExists(atPath: filePath.path) {
                try FileManager.default.removeItem(at: filePath)
                debugPrint("✅ Successfully deleted project: \(name)")

                // Verify deletion
                let stillExists = FileManager.default.fileExists(atPath: filePath.path)
                debugPrint("🗑️ Verification - file still exists after deletion: \(stillExists)")
            } else {
                debugPrint("❌ Project file does not exist: \(filePath.path)")

                // List all files in the directory to see what's there
                let baseFolder = try baseFolder()
                let files = try FileManager.default.contentsOfDirectory(atPath: baseFolder.path)
                debugPrint("🗑️ Files in directory: \(files)")
            }
        } catch {
            debugPrint("❌ Failed to delete project \(name): \(error)")
            debugPrint("❌ Error details: \(error.localizedDescription)")
        }
    }

    // MARK: - Autosave for song library
    // These functions save the library independently so it persists even for "Untitled" projects

    private static var autosaveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("songLibrary.autosave.json")
    }

    static func saveLibraryAutosave(_ library: [Song]) {
        do {
            let data = try JSONEncoder().encode(library)
            try data.write(to: autosaveURL, options: [.atomic])
            debugPrint("💾 Autosaved song library (\(library.count) songs)")
        } catch {
            debugPrint("❌ Failed to autosave library: \(error)")
        }
    }

    static func loadLibraryAutosave() -> [Song]? {
        guard FileManager.default.fileExists(atPath: autosaveURL.path) else {
            debugPrint("ℹ️ No library autosave file found")
            return nil
        }
        do {
            let data = try Data(contentsOf: autosaveURL)
            let library = try JSONDecoder().decode([Song].self, from: data)
            debugPrint("📂 Loaded autosaved library (\(library.count) songs)")
            return library
        } catch {
            debugPrint("❌ Failed to load library autosave: \(error)")
            return nil
        }
    }

    static func clearLibraryAutosave() {
        if FileManager.default.fileExists(atPath: autosaveURL.path) {
            try? FileManager.default.removeItem(at: autosaveURL)
            debugPrint("🗑️ Cleared library autosave")
        }
    }
}
