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
        let document = CueBearProjectDocument(fileURL: url)
        
        document.open { success in
            DispatchQueue.main.async {
                completion(success ? document.projectData : nil)
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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.cueBearProject])
        picker.allowsMultipleSelection = false
        
        // Store completion handler
        DocumentPickerDelegate.shared.completion = completion
        picker.delegate = DocumentPickerDelegate.shared
        
        viewController.present(picker, animated: true)
    }
}

// MARK: - Document Picker Delegate

private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPickerDelegate()
    var completion: ((URL?) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion?(urls.first)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
    }
}
