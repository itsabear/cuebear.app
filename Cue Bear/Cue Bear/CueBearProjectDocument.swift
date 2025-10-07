import UIKit
import UniformTypeIdentifiers

/// Document-based project storage for iCloud Drive integration
/// Simple, clean implementation that maintains existing data structure
final class CueBearProjectDocument: UIDocument {
    
    // MARK: - Properties
    
    /// The project data - same structure as existing ProjectPayload
    var projectData: ProjectPayload?
    
    // MARK: - UIDocument Overrides
    
    override func contents(forType typeName: String) throws -> Any {
        guard let data = projectData else {
            throw NSError(domain: "CueBear", code: 1, userInfo: [NSLocalizedDescriptionKey: "No project data to save"])
        }
        
        // Use existing JSON encoding - no changes to data format
        let jsonData = try JSONEncoder().encode(data)
        return jsonData
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        debugPrint("📄 CueBearProjectDocument: load(fromContents:ofType:) called")
        debugPrint("📄 CueBearProjectDocument: Type name: \(typeName ?? "nil")")

        guard let data = contents as? Data else {
            debugPrint("❌ CueBearProjectDocument: Contents is not Data type")
            throw NSError(domain: "CueBear", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid project data"])
        }

        debugPrint("📄 CueBearProjectDocument: Data size: \(data.count) bytes")

        // Use existing JSON decoding - no changes to data format
        do {
            projectData = try JSONDecoder().decode(ProjectPayload.self, from: data)
            debugPrint("✅ CueBearProjectDocument: Successfully decoded project: \(projectData?.name ?? "unknown")")
        } catch {
            debugPrint("❌ CueBearProjectDocument: Decoding error: \(error)")
            throw error
        }
    }
    
    // MARK: - Document Behavior
    // UIDocument handles autosave automatically
    
    // MARK: - Convenience Methods
    
    /// Create a new document with project data
    static func create(with data: ProjectPayload, fileName: String) -> CueBearProjectDocument {
        let document = CueBearProjectDocument(fileURL: Self.defaultURL(for: fileName))
        document.projectData = data
        return document
    }
    
    /// Get default URL for a project name
    private static func defaultURL(for name: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("\(name).cuebearproj")
    }
}

// MARK: - UTType Definition

extension UTType {
    /// Cue Bear project file type
    static var cueBearProject: UTType {
        UTType(exportedAs: "com.studiobear.cuebear.project")
    }
}
