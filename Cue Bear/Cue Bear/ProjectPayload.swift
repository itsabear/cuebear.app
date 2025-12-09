import Foundation

/// Shared project data structure supporting both legacy and modern formats
///
/// **Legacy Format (v1.0.x - v1.1.x):**
/// - Uses `setlist` field with array of songs
/// - Single cue list per project
///
/// **Modern Format (v1.2.0+):**
/// - Uses `cueLists` field with array of CueList objects
/// - Multiple named cue lists per project
/// - `activeCueListID` tracks which list is currently active
///
/// **Migration:** Legacy projects automatically convert `setlist` to a cue list named "Main"
struct ProjectPayload: Codable {
    // MARK: - Modern Format (v1.2.0+)

    /// Multiple cue lists (v1.2.0+)
    var cueLists: [CueList]?

    /// ID of the currently active cue list (v1.2.0+)
    var activeCueListID: UUID?

    /// App mode preference (regular, regularPlusRemote, or cue) - remembered per project
    var appMode: AppMode?

    // MARK: - Legacy Format (v1.0.x - v1.1.x)

    /// Legacy single setlist (for loading old projects only)
    var setlist: [Song]?

    // MARK: - Common Fields

    /// Project name
    let name: String

    /// Song library (shared across all cue lists)
    let library: [Song]

    /// Control buttons
    let controls: [ControlButton]

    /// Global channel enabled state
    let isGlobalChannel: Bool?

    /// Global channel number
    let globalChannel: Int?

    /// Theme identifier
    let theme: String?

    /// Project format version
    let projectVersion: String?

    // MARK: - Initialization

    /// Initialize with modern format (v1.2.0+)
    init(
        name: String,
        cueLists: [CueList],
        activeCueListID: UUID?,
        library: [Song],
        controls: [ControlButton],
        isGlobalChannel: Bool? = nil,
        globalChannel: Int? = nil,
        theme: String? = nil,
        appMode: AppMode? = nil,
        projectVersion: String? = "1.2.0"
    ) {
        self.name = name
        self.cueLists = cueLists
        self.activeCueListID = activeCueListID
        self.appMode = appMode
        self.setlist = nil  // Don't save legacy format
        self.library = library
        self.controls = controls
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
        self.theme = theme
        self.projectVersion = projectVersion
    }

    /// Initialize with legacy format (for compatibility)
    init(
        name: String,
        setlist: [Song],
        library: [Song],
        controls: [ControlButton],
        isGlobalChannel: Bool? = nil,
        globalChannel: Int? = nil,
        theme: String? = nil
    ) {
        self.name = name
        self.setlist = setlist
        self.cueLists = nil
        self.activeCueListID = nil
        self.appMode = nil  // Legacy projects default to nil
        self.library = library
        self.controls = controls
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
        self.theme = theme
        self.projectVersion = nil
    }
}

// MARK: - Format Detection
extension ProjectPayload {
    /// Check if this is a legacy format project
    var isLegacyFormat: Bool {
        cueLists == nil && setlist != nil
    }

    /// Check if this is a modern format project
    var isModernFormat: Bool {
        cueLists != nil
    }
}
