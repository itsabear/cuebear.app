import UIKit
import UniformTypeIdentifiers

/// Simple document-based project management
/// Works alongside existing ProjectIO for seamless migration
enum DocumentProjectIO {
    
    // MARK: - Document Creation
    
    /// Create a new project document in iCloud Drive
    static func createNewProject(name: String, data: ProjectPayload, completion: @escaping (Bool) -> Void) {
        let document = CueBearProjectDocument.create(with: data, fileName: name)
        
        // Save to iCloud Drive
        document.save(to: document.fileURL, for: .forCreating) { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    /// Open existing project from document picker
    static func openProject(from url: URL, completion: @escaping (ProjectPayload?) -> Void) {
        debugPrint("📂 DocumentProjectIO: Attempting to open project from URL: \(url)")
        debugPrint("📂 DocumentProjectIO: URL path: \(url.path)")
        debugPrint("📂 DocumentProjectIO: URL is file URL: \(url.isFileURL)")

        // Start accessing security-scoped resource
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        debugPrint("📂 DocumentProjectIO: Started accessing security-scoped resource: \(didStartAccessing)")

        let document = CueBearProjectDocument(fileURL: url)

        document.open { success in
            debugPrint("📂 DocumentProjectIO: Document open result: \(success)")
            if success {
                debugPrint("📂 DocumentProjectIO: Project data loaded successfully")
                debugPrint("📂 DocumentProjectIO: Project name: \(document.projectData?.name ?? "nil")")

                // Copy the data before closing the document
                let projectData = document.projectData

                // Close the document to release resources
                document.close { closeSuccess in
                    debugPrint("📂 DocumentProjectIO: Document close result: \(closeSuccess)")

                    DispatchQueue.main.async {
                        if didStartAccessing {
                            url.stopAccessingSecurityScopedResource()
                            debugPrint("📂 DocumentProjectIO: Stopped accessing security-scoped resource")
                        }
                        completion(projectData)
                    }
                }
            } else {
                debugPrint("❌ DocumentProjectIO: Failed to open document")
                debugPrint("❌ DocumentProjectIO: Document state: \(document.documentState)")

                DispatchQueue.main.async {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                        debugPrint("📂 DocumentProjectIO: Stopped accessing security-scoped resource")
                    }
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Migration Helpers
    
    /// Detect legacy projects that can be migrated
    static func detectLegacyProjects() -> [String] {
        do {
            let legacyDir = try ProjectIO.baseFolder()
            let items = try FileManager.default.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil)
            
            // Filter for .cuebear files
            let cuebearFiles = items.filter { $0.pathExtension.lowercased() == "cuebear" }
            
            // Extract project names
            let projectNames = cuebearFiles.map { $0.deletingPathExtension().lastPathComponent }
            
            // Sort alphabetically
            return projectNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch {
            return []
        }
    }
    
    /// Migrate a legacy project to iCloud Drive
    static func migrateLegacyProject(name: String, completion: @escaping (Bool) -> Void) {
        do {
            // Load legacy project
            let legacyData = try ProjectIO.load(name: name)
            
            // Create new document
            createNewProject(name: name, data: legacyData) { success in
                if success {
                    // Remove legacy file after successful migration
                    ProjectIO.delete(name: name)
                }
                completion(success)
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - Document Picker

    /// Present document picker for opening projects
    static func presentDocumentPicker(from viewController: UIViewController, completion: @escaping (URL?) -> Void) {
        debugPrint("📁 DocumentProjectIO: Presenting document picker")
        debugPrint("📁 DocumentProjectIO: Content type: com.studiobear.cuebear.project")

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.cueBearProject])
        picker.allowsMultipleSelection = false

        // Store completion handler
        DocumentPickerDelegate.shared.completion = completion
        picker.delegate = DocumentPickerDelegate.shared

        debugPrint("📁 DocumentProjectIO: About to present picker from view controller: \(viewController)")
        viewController.present(picker, animated: true) {
            debugPrint("📁 DocumentProjectIO: Document picker presented successfully")
        }
    }

    // MARK: - Export/Share

    /// Export current project and present share sheet
    static func exportProject(name: String, data: ProjectPayload, from viewController: UIViewController) {
        debugPrint("📤 DocumentProjectIO: Exporting project: \(name)")

        // Create temporary file with project data
        let fileName = name.isEmpty ? "Untitled" : name
        let sanitizedName = fileName.replacingOccurrences(of: "/", with: "-")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedName).cuebear")

        do {
            // Encode project data to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(data)

            // Write to temporary file
            try jsonData.write(to: tempURL)
            debugPrint("📤 DocumentProjectIO: Created temporary file at: \(tempURL.path)")

            // Present share sheet
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            // For iPad: set source view to avoid crash
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            // Clean up temp file after sharing completes
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: tempURL)
                debugPrint("📤 DocumentProjectIO: Cleaned up temporary file")
            }

            viewController.present(activityVC, animated: true) {
                debugPrint("📤 DocumentProjectIO: Share sheet presented")
            }

        } catch {
            debugPrint("❌ DocumentProjectIO: Export failed: \(error)")

            // Show error alert
            let alert = UIAlertController(
                title: "Export Failed",
                message: "Could not export project: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
        }
    }
}

// MARK: - Document Picker Delegate

private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPickerDelegate()
    var completion: ((URL?) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        debugPrint("📁 DocumentPickerDelegate: User picked documents")
        debugPrint("📁 DocumentPickerDelegate: Number of URLs: \(urls.count)")
        if let firstURL = urls.first {
            debugPrint("📁 DocumentPickerDelegate: First URL: \(firstURL)")
            debugPrint("📁 DocumentPickerDelegate: URL path: \(firstURL.path)")
        }
        completion?(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        debugPrint("📁 DocumentPickerDelegate: User cancelled document picker")
        completion?(nil)
    }
}
