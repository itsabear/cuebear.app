import Foundation

/// Shared project data structure for both legacy and document-based projects
struct ProjectPayload: Codable {
    let name: String
    let setlist: [Song]
    let library: [Song]
    let controls: [ControlButton]
    let isGlobalChannel: Bool?
    let globalChannel: Int?

    init(name: String, setlist: [Song], library: [Song], controls: [ControlButton], isGlobalChannel: Bool? = nil, globalChannel: Int? = nil) {
        self.name = name
        self.setlist = setlist
        self.library = library
        self.controls = controls
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
    }
}
