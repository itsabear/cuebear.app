//
//  ContentView.swift — Cue Bear (v1.16c)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Shared Wobble Animator (Time-Based Continuous Animation)
// Uses continuous sine-wave calculations instead of discrete state updates for smooth 60fps performance
@MainActor
class WobbleAnimator: ObservableObject {
    static let shared = WobbleAnimator()

    // Track which controls are wobbling and their parameters
    @Published private(set) var wobbles: [UUID: WobbleConfig] = [:]

    struct WobbleConfig {
        let amplitude: Double
        let scaleDelta: Double
        let phaseOffset: Double  // Randomized phase for organic look
    }

    private init() {}

    func startWobbling(for id: UUID, amplitude: Double, scaleDelta: Double, interval: Double, initialPhase: Bool? = nil) {
        // Randomize phase offset (0 to 2π) for organic out-of-sync wobbling
        let phaseOffset = Double.random(in: 0...(2 * .pi))
        wobbles[id] = WobbleConfig(
            amplitude: amplitude,
            scaleDelta: scaleDelta,
            phaseOffset: phaseOffset
        )
        debugPrint("🔄 WobbleAnimator: Started wobbling for ID \(id.uuidString.prefix(8))... (total wobbles: \(wobbles.count))")
    }

    func stopWobbling(for id: UUID) {
        wobbles.removeValue(forKey: id)
        debugPrint("🔄 WobbleAnimator: Stopped wobbling for ID \(id.uuidString.prefix(8))... (remaining wobbles: \(wobbles.count))")
    }

    func resetWobble(for id: UUID) {
        wobbles.removeValue(forKey: id)
    }

    // Calculate wobble transforms for a given time and config
    func calculateWobble(time: TimeInterval, config: WobbleConfig) -> (rotation: Double, scale: Double) {
        // Frequency: 2.5 Hz (iPhone home screen speed - about 2-3 wobbles per second)
        let frequency = 15.7  // 2.5 * 2π ≈ 15.7 radians per second
        let angle = time * frequency + config.phaseOffset

        let rotation = sin(angle) * config.amplitude
        let scale = 1.0 + sin(angle + .pi / 2) * config.scaleDelta  // 90° phase shift for scale

        return (rotation, scale)
    }
}

// MARK: - Time-Based Wobble View Modifier
// Applies continuous wobble animation using TimelineView for 60fps performance
struct TimeBasedWobbleModifier: ViewModifier {
    let wobbleID: UUID
    @ObservedObject var wobbleAnimator: WobbleAnimator

    func body(content: Content) -> some View {
        if let config = wobbleAnimator.wobbles[wobbleID] {
            // Debug print removed - was causing 60fps console spam during wobble animation
            return AnyView(
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let wobble = wobbleAnimator.calculateWobble(time: time, config: config)

                    content
                        .rotationEffect(.degrees(wobble.rotation))
                        .scaleEffect(wobble.scale)
                }
            )
        } else {
            return AnyView(content)
        }
    }
}

// MARK: - Reserved CCs for legacy transport mapping (kept for compatibility)
private enum CBTransportCC { static let play = 100, stop = 101, prev = 102, next = 103 }

// MARK: - Grid Position Helper
private struct GridPosition: Equatable {
    let col: Int
    let row: Int
}

// MARK: - Control Button (UI-local model; persisted in ProjectPayload)
internal struct ControlButton: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var symbol: String        // SF Symbol
    var kind: MIDIKind        // .cc or .note
    var number: Int           // CC or Note number (0–127)
    var channel: Int          // 1–16
    var velocity: Int = 127   // for notes
    // Behavior: nil/false = momentary, true = toggle
    var isToggle: Bool? = nil
    // Toggle state: true = on, false = off (only used when isToggle == true)
    var toggleState: Bool = false
    // SNAKE: render as a fader instead of a button (CC only)
    var isFader: Bool? = nil
    // SNAKE: render as a small button (1x1)
    var isSmall: Bool? = nil
    // Optional explicit grid placement (column, row) for widget-like layout
    var gridCol: Int? = nil
    var gridRow: Int? = nil
    // Fader value: 0.0 to 1.0 (only used when isFader == true)
    var faderValue: Double? = nil
    // Fader orientation: "vertical" or "horizontal" (only used when isFader == true)
    // Defaults to "vertical" for backward compatibility with existing faders
    var faderOrientation: String? = nil
    // Fader direction: "up", "down", "left", "right" (only used when isFader == true)
    // Defaults to "up" for vertical, "right" for horizontal
    var faderDirection: String? = nil

    // Memberwise initializer
    init(title: String, symbol: String, kind: MIDIKind, number: Int, channel: Int, velocity: Int = 127, isToggle: Bool? = nil, toggleState: Bool = false, isFader: Bool? = nil, isSmall: Bool? = nil, gridCol: Int? = nil, gridRow: Int? = nil, faderValue: Double? = nil, faderOrientation: String? = nil, faderDirection: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.number = number
        self.channel = channel
        self.velocity = velocity
        self.isToggle = isToggle
        self.toggleState = toggleState
        self.isFader = isFader
        self.isSmall = isSmall
        self.gridCol = gridCol
        self.gridRow = gridRow
        self.faderValue = faderValue
        self.faderOrientation = faderOrientation
        self.faderDirection = faderDirection
    }
    
    // Custom decoder to handle missing toggleState in older project files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbol = try container.decode(String.self, forKey: .symbol)
        kind = try container.decode(MIDIKind.self, forKey: .kind)
        number = try container.decode(Int.self, forKey: .number)
        channel = try container.decode(Int.self, forKey: .channel)
        velocity = try container.decodeIfPresent(Int.self, forKey: .velocity) ?? 127
        isToggle = try container.decodeIfPresent(Bool.self, forKey: .isToggle)
        toggleState = try container.decodeIfPresent(Bool.self, forKey: .toggleState) ?? false
        isFader = try container.decodeIfPresent(Bool.self, forKey: .isFader)
        isSmall = try container.decodeIfPresent(Bool.self, forKey: .isSmall)
        gridCol = try container.decodeIfPresent(Int.self, forKey: .gridCol)
        gridRow = try container.decodeIfPresent(Int.self, forKey: .gridRow)
        faderValue = try container.decodeIfPresent(Double.self, forKey: .faderValue)
        // New fader properties - defaults for backward compatibility
        faderOrientation = try container.decodeIfPresent(String.self, forKey: .faderOrientation)
        faderDirection = try container.decodeIfPresent(String.self, forKey: .faderDirection)
    }

    // Computed properties for grid dimensions
    var gridWidth: Int {
        if isFader == true {
            // Fader dimensions depend on orientation
            let orientation = faderOrientation ?? "vertical"
            return orientation == "horizontal" ? 2 : 1
        } else if isSmall == true {
            return 1  // Small button: 1x1
        } else {
            return 2  // Regular button: 2x1
        }
    }

    var gridHeight: Int {
        if isFader == true {
            // Fader dimensions depend on orientation
            let orientation = faderOrientation ?? "vertical"
            return orientation == "horizontal" ? 1 : 2
        } else {
            return 1  // All buttons: height 1
        }
    }
}

// MARK: - Local UI helpers / rows
    internal struct CBLibraryRow: Identifiable {
    let id: UUID
    let song: Song
    let isInSetlist: Bool
    let isSelected: Bool
}

internal enum LibrarySortMode: String, CaseIterable, Identifiable {
    case nameAZ, nameZA, newest, oldest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nameAZ: return "A–Z"
        case .nameZA: return "Z–A"
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        }
    }
}

// MARK: - Isolated Number Picker Component
// This component is isolated to prevent scroll position reset when other state changes
struct MIDINumberPicker: View {
    let kind: MIDIKind
    @Binding var number: Int
    let disabled: Bool
    let channel: Int
    var currentOwnerName: ((MIDIKey) -> String?)?
    var editingControl: ControlButton?  // Full control being edited (to exclude from ownership check)

    var body: some View {
        Picker(kind == .cc ? "CC Number" : "Note Number", selection: $number) {
            ForEach(0...127, id: \.self) { n in
                let owner = ownerFor(kind: kind, number: n, channel: channel)
                let displayText = displayTextFor(kind: kind, number: n, owner: owner)

                Text(displayText)
                    .foregroundColor(owner == nil ? .primary : .secondary)
                    .tag(n)
            }
        }
        .disabled(disabled)
    }

    private func displayTextFor(kind: MIDIKind, number: Int, owner: String?) -> String {
        if kind == .note {
            return owner == nil
                ? "\(number) - \(number.midiNoteName)"
                : "\(number) - \(number.midiNoteName) (Used by: \(owner!))"
        } else {
            return owner == nil
                ? "\(number)"
                : "\(number) (Used by: \(owner!))"
        }
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        guard let currentOwnerName = currentOwnerName else { return nil }

        // If we're editing a control and checking its current MIDI assignment, don't show as taken
        if let edit = editingControl {
            if edit.kind == kind && edit.channel == channel && edit.number == number {
                return nil
            }
        }

        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }
}

// MARK: - Isolated Icon Picker Component
// This component is isolated to prevent scroll position reset when other state changes
struct IconPicker: View {
    @Binding var symbol: String
    let icons: [String]

    var body: some View {
        Picker("Icon", selection: $symbol) {
            Text("Text only").tag("")
            ForEach(icons, id: \.self) { Image(systemName: $0).tag($0) }
        }
    }
}

// MARK: - Isolated Velocity Picker Component
// This component is isolated to prevent scroll position reset when other state changes
struct VelocityPicker: View {
    @Binding var velocity: Int
    let disabled: Bool

    var body: some View {
        Picker("Velocity", selection: $velocity) {
            ForEach(0...127, id: \.self) { v in
                Text("\(v)").tag(v)
            }
        }
        .disabled(disabled)
    }
}

// MARK: - Control Button Editor (moved outside ContentView for scope)
struct CBControlEditorSheet: View {
    @Binding var editing: ControlButton?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    @Binding var pendingIsFader: Bool?
    let isGlobalChannel: Bool
    let globalChannel: Int
    var onSave: (ControlButton, Bool) -> Void  // Added Bool parameter for andAddAnother
    var onCancel: () -> Void
    var onDelete: ((ControlButton) -> Void)? = nil
    var allButtons: [ControlButton] = []  // All control buttons for space validation
    var columns: Int = 8  // Grid column count
    let icons: [String]
    var isEditMode: Bool = false  // Explicit flag: true for editing existing control, false for adding new

    @State private var title: String = ""
    @State private var symbol: String = "square.grid.2x2.fill"
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 0
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var autoAssign: Bool = true
    @State private var isToggle: Bool = false
    @State private var showDeleteAlert: Bool = false
    private enum ControlType: String, CaseIterable, Identifiable { case button, fader; var id: String { rawValue } }
    @State private var controlType: ControlType = .button
    // Button type selection (for toggling between regular and small buttons)
    private enum ButtonType: String, CaseIterable, Identifiable { case regular, small; var id: String { rawValue } }
    @State private var buttonType: ButtonType = .regular
    // Fader orientation and direction
    @State private var faderOrientation: String = "vertical"
    @State private var faderDirection: String = "up"
    // Space validation warning
    @State private var showSpaceWarning: Bool = false
    // Out-of-room warning for add mode
    @State private var isOutOfRoom: Bool = false

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Space Validation Helpers

    // Local GridRect helper for space validation
    private struct GridRectHelper {
        let col: Int
        let row: Int
        let width: Int
        let height: Int
    }

    /// Validates if the control with new dimensions can fit in the grid
    /// Returns true if it fits, false if no space is available
    private func validateSpaceForOrientation() -> Bool {
        guard let editingButton = editing else { return true }

        // Calculate what the new dimensions would be based on control type
        let newWidth: Int
        let newHeight: Int

        if editingButton.isFader == true {
            // Fader dimensions depend on orientation
            newWidth = (faderOrientation == "horizontal") ? 2 : 1
            newHeight = (faderOrientation == "horizontal") ? 1 : 2
        } else {
            // Button dimensions depend on button type
            newWidth = (buttonType == .small) ? 1 : 2
            newHeight = 1
        }

        // If dimensions haven't changed, no validation needed
        if newWidth == editingButton.gridWidth && newHeight == editingButton.gridHeight {
            return true
        }

        // Check if the current position still works with new dimensions
        if let col = editingButton.gridCol, let row = editingButton.gridRow {
            if col + newWidth <= columns && canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: editingButton.id) {
                return true  // Current position still works
            }
        }

        // Try to find any available position with new dimensions
        return findAvailablePosition(width: newWidth, height: newHeight, excluding: editingButton.id) != nil
    }

    /// Checks if a control can fit at a specific position
    private func canFitAtPosition(col: Int, row: Int, width: Int, height: Int, excluding excludeId: UUID) -> Bool {
        // Check bounds
        if col < 0 || row < 0 || col + width > columns {
            return false
        }

        // Check for overlaps with other buttons
        let testRect = GridRectHelper(col: col, row: row, width: width, height: height)

        for button in allButtons where button.id != excludeId {
            guard let bCol = button.gridCol, let bRow = button.gridRow else { continue }
            let buttonRect = GridRectHelper(col: bCol, row: bRow, width: button.gridWidth, height: button.gridHeight)
            if rectsOverlap(testRect, buttonRect) {
                return false
            }
        }

        return true
    }

    /// Finds an available position for the given dimensions
    private func findAvailablePosition(width: Int, height: Int, excluding excludeId: UUID) -> (col: Int, row: Int)? {
        let maxSearchRows = 4  // Match the display limit of 4 rows

        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                if canFitAtPosition(col: col, row: row, width: width, height: height, excluding: excludeId) {
                    return (col, row)
                }
            }
        }

        return nil
    }

    /// Checks if two grid rectangles overlap
    private func rectsOverlap(_ r1: GridRectHelper, _ r2: GridRectHelper) -> Bool {
        let r1Right = r1.col + r1.width
        let r1Bottom = r1.row + r1.height
        let r2Right = r2.col + r2.width
        let r2Bottom = r2.row + r2.height

        return !(r1Right <= r2.col || r2Right <= r1.col || r1Bottom <= r2.row || r2Bottom <= r1.row)
    }

    /// Validates if there's space available for adding a new control
    /// Returns true if space is available, false if grid is full
    private func validateSpaceForAddMode() -> Bool {
        // Only validate when adding new controls (title is empty)
        guard let editingButton = editing else { return true }
        guard editingButton.title.isEmpty else { return true }  // Edit mode - already has space

        // Calculate dimensions based on control type and orientation
        let width: Int
        let height: Int

        if controlType == .fader {
            width = (faderOrientation == "horizontal") ? 2 : 1
            height = (faderOrientation == "horizontal") ? 1 : 2
        } else {
            // Button - check button type
            if buttonType == .small {
                width = 1
                height = 1
            } else {
                // Regular button
                width = 2
                height = 1
            }
        }

        // Try to find any available position with these dimensions
        // Use UUID.zero as the excludeId since this is a new control
        return findAvailablePosition(width: width, height: height, excluding: UUID()) != nil
    }

    // FIX #8: Combined validation function to reduce overhead
    private func validateSpaceForOrientationAndAddMode() -> (orientationValid: Bool, addModeValid: Bool) {
        return (validateSpaceForOrientation(), validateSpaceForAddMode())
    }

    /// Returns the appropriate out-of-room message based on control type
    private func outOfRoomMessage() -> String {
        let controlName: String
        if controlType == .fader {
            controlName = "Fader"
        } else {
            controlName = buttonType == .small ? "Small Button" : "Button"
        }
        return "Out of room! Remove a controller first to add this \(controlName) to your control area."
    }

    var body: some View {
        NavigationView {
            Form {
                // Out of room warning - shown at top for maximum visibility
                if isOutOfRoom {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(outOfRoomMessage())
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Appearance")) {
                    // Control type is preselected by the add buttons; hide the picker
                    HStack {
                        TextField("Control Name", text: $title, prompt: Text("Control Name").foregroundColor(.secondary))
                        if !title.isEmpty {
                            Button(action: { title = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Button Type picker - only show for buttons (not faders)
                    if controlType != .fader {
                        Picker("Button Type", selection: $buttonType) {
                            Text("Button").tag(ButtonType.regular)
                            Text("Small Button").tag(ButtonType.small)
                        }

                        // Show space warning if button type change won't fit
                        if showSpaceWarning {
                            Text("You're out of room! Try removing other controllers to change button size")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    }

                    if controlType != .fader {
                        IconPicker(symbol: $symbol, icons: icons)
                            .id("icon-picker")
                        Picker("Behavior", selection: $isToggle) {
                            Text("Momentary").tag(false)
                            Text("Toggle").tag(true)
                        }
                    }

                    // Fader orientation and direction (only for faders)
                    if controlType == .fader {
                        Picker("Fader Orientation", selection: $faderOrientation) {
                            Text("Vertical").tag("vertical")
                            Text("Horizontal").tag("horizontal")
                        }

                        Picker("Fader Direction", selection: $faderDirection) {
                            Text("Up").tag("up")
                            Text("Down").tag("down")
                            Text("Left").tag("left")
                            Text("Right").tag("right")
                        }
                        .id("fader-direction-picker")

                        // Show space warning if orientation change won't fit
                        if showSpaceWarning {
                            Text("You're out of room! Try removing other controllers to add this one")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    }
                }
                // Live Preview
                Section(header: Text("Preview")) {
                    HStack {
                        Spacer(minLength: 0)
                        if controlType == .fader {
                            ControlFaderPreview(title: title, cc: number, channel: channel, orientation: faderOrientation, direction: faderDirection)
                        } else {
                            ControlButtonPreview(title: title, symbol: symbol, kind: kind, number: number, channel: channel, velocity: velocity, isSmall: buttonType == .small)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
                Section(header: Text("MIDI")) {
                    Toggle(isOn: $autoAssign) {
                        Text("Assign MIDI automatically")
                    }
                    if controlType != .fader {
                        Picker("Type", selection: $kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                    }
                    if isGlobalChannel {
                        HStack {
                            Text("Channel")
                            Spacer()
                            Text("\(globalChannel) (Global Channel)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Channel", selection: $channel) {
                            ForEach(1...16, id: \.self) { ch in
                                Text("\(ch)").tag(ch)
                            }
                        }
                    }
                    MIDINumberPicker(
                        kind: kind,
                        number: $number,
                        disabled: autoAssign,
                        channel: isGlobalChannel ? globalChannel : channel,
                        currentOwnerName: currentOwnerName,
                        editingControl: editing
                    )
                    .id(kind == .note ? "note-picker" : "cc-picker")
                    // Show conflict warning below picker (not inside picker items)
                    if let owner = conflictOwner() {
                        Text("⚠️ Taken by: \(owner)").foregroundColor(.orange)
                    }
                    if controlType != .fader && kind == .note {
                        VelocityPicker(velocity: $velocity, disabled: false)
                    }
                }

                // Delete section - only show when editing existing control
                if isEditMode, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(controlType == .fader ? "Delete Fader" : (buttonType == .small ? "Delete Small Button" : "Delete Button"))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(titleForSheet())
            .navigationBarBackButtonHidden(true)
            .alert("Delete Control", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let control = editing {
                        onDelete?(control)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let controlTypeName = controlType == .fader ? "fader" : (buttonType == .small ? "small button" : "button")
                Text("Are you sure you want to delete this \(controlTypeName)? This action cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                // Show "Save & Add Another" when adding new controls (not when editing existing)
                if !isEditMode {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save & Add Another") {
                            saveControl(andAddAnother: true)
                        }
                        .disabled(conflictOwner() != nil || showSpaceWarning || isOutOfRoom)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Save" : "Add") {
                        saveControl(andAddAnother: false)
                    }
                    .disabled(conflictOwner() != nil || showSpaceWarning || isOutOfRoom)
                }
            }
            .onAppear {
                preset()
                // Validate space for add mode on sheet open
                isOutOfRoom = !validateSpaceForAddMode()
            }
            .onChange(of: editing) { oldValue, newValue in
                // When editing changes (especially when set to nil for "Add Another"),
                // re-run preset to ensure form is properly initialized
                if oldValue != nil && newValue == nil {
                    preset()
                    isOutOfRoom = !validateSpaceForAddMode()
                }
            }
            .onChange(of: autoAssign) { _, newValue in
                if newValue {
                    number = firstFreeNumber(for: kind, channel: channel)
                }
            }
            .onChange(of: kind) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: newValue, channel: channel)
                }
            }
            .onChange(of: channel) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: kind, channel: newValue)
                }
            }
            .onChange(of: controlType) { _, newType in
                if newType == .fader { kind = .cc }
                pendingIsFader = (newType == .fader)
                // Re-validate space when control type changes
                isOutOfRoom = !validateSpaceForAddMode()
            }
            .onChange(of: faderOrientation) { _, newOrientation in
                // Auto-set appropriate direction when orientation changes
                if newOrientation == "vertical" && (faderDirection == "left" || faderDirection == "right") {
                    faderDirection = "up"
                } else if newOrientation == "horizontal" && (faderDirection == "up" || faderDirection == "down") {
                    faderDirection = "right"
                }

                // FIX #8: Combine validation calls to reduce overhead
                let validationResults = validateSpaceForOrientationAndAddMode()
                showSpaceWarning = !validationResults.orientationValid
                isOutOfRoom = !validationResults.addModeValid
            }
            .onChange(of: buttonType) { _, newType in
                // Validate space when button type changes (regular <-> small)
                let validationResults = validateSpaceForOrientationAndAddMode()
                showSpaceWarning = !validationResults.orientationValid
                isOutOfRoom = !validationResults.addModeValid
            }
        }
    }

    private func preset() {
        debugPrint("📋 [CONTROL] preset() called, editing: \(editing != nil ? "exists" : "nil")")
        guard let b = editing else {
            // For new controls without editing state
            // Check if this is "Add Another" by seeing if number is already set to a valid value
            if number > 0 {
                // "Add Another" already set the correct number - DON'T recalculate!
                debugPrint("  🎯 [CONTROL] Number already set by 'Add Another': \(number), skipping recalculation")
                // autoAssign is already set to true above
                // All other values are already reset correctly
                return
            }

            // This is a fresh "Add Control" (not "Add Another")
            autoAssign = true
            // FIX: Use global channel if enabled, otherwise default to 1
            let nextChannel = isGlobalChannel ? globalChannel : 1
            channel = nextChannel
            debugPrint("  🆕 [CONTROL] No editing state, finding free number for \(kind) ch\(channel)")
            number = firstFreeNumber(for: kind, channel: channel)
            debugPrint("  ✅ [CONTROL] preset() set number to \(number)")
            return
        }

        // Set fields from the editing button (whether it's a draft for adding or existing for editing)
        title = b.title
        symbol = b.symbol
        kind = b.kind
        number = b.number
        channel = b.channel
        velocity = b.velocity
        isToggle = b.isToggle ?? false

        // Determine control type from button properties
        if b.isFader == true {
            controlType = .fader
            // Load fader orientation and direction with defaults
            faderOrientation = b.faderOrientation ?? "vertical"
            faderDirection = b.faderDirection ?? (faderOrientation == "vertical" ? "up" : "right")
        } else {
            controlType = .button
            buttonType = (b.isSmall == true) ? .small : .regular
        }

        // For new buttons (add mode), enable auto-assign
        // For existing buttons (edit mode), disable auto-assign to allow manual editing
        autoAssign = !isEditMode
    }

    private func titleForSheet() -> String {
        // Check if we're adding a new control or editing existing (use explicit mode flag)
        let isAddingNew = !isEditMode

        if isAddingNew {
            // Adding new control - show specific type
            if controlType == .fader {
                return "Add Fader"
            } else {
                return buttonType == .small ? "Add Small Button" : "Add Button"
            }
        } else {
            // Editing existing control - show specific type
            if controlType == .fader {
                return "Edit Fader"
            } else {
                return buttonType == .small ? "Edit Small Button" : "Edit Button"
            }
        }
    }

    private func conflictOwner() -> String? {
        // If we're editing an existing control and the MIDI assignment hasn't changed, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing control and checking its current MIDI assignment, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func assignFreeNumber() {
        number = firstFreeNumber(for: kind, channel: channel)
    }

    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        debugPrint("🔍 [CONTROL] Finding first free \(kind) number on channel \(channel), editing: \(editing?.title ?? "nil")")
        for n in 0...127 {
            let key = MIDIKey(kind: kind, channel: channel, number: n)
            let owner = currentOwnerName(key)
            if owner != nil {
                // Skip if occupied by a different control
                if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == n {
                    // This is the control we're editing, so this number is available for it
                    debugPrint("  ✓ [CONTROL] \(n) is taken by editing control, available")
                } else {
                    // Occupied by a different control, skip this number
                    debugPrint("  ✗ [CONTROL] \(n) is taken by '\(owner!)', skipping")
                    continue
                }
            }
            debugPrint("  ✅ [CONTROL] First free number: \(n)")
            return n
        }
        debugPrint("  ⚠️ [CONTROL] No free numbers found, returning 0")
        return 0
    }

    private func firstFreeNumberStartingFrom(_ start: Int, for kind: MIDIKind, channel: Int) -> Int {
        debugPrint("🔍 [CONTROL] Finding first free \(kind) number on channel \(channel) starting from \(start)")
        for n in start...127 {
            let key = MIDIKey(kind: kind, channel: channel, number: n)
            let owner = currentOwnerName(key)
            if owner == nil {
                debugPrint("  ✅ [CONTROL] First free number: \(n)")
                return n
            } else {
                debugPrint("  ✗ [CONTROL] \(n) is taken by '\(owner!)', skipping")
            }
        }
        // Wrap around and search from 0 if nothing found above start
        for n in 0..<start {
            let key = MIDIKey(kind: kind, channel: channel, number: n)
            let owner = currentOwnerName(key)
            if owner == nil {
                debugPrint("  ✅ [CONTROL] First free number (wrapped): \(n)")
                return n
            }
        }
        debugPrint("  ⚠️ [CONTROL] No free numbers found, returning 0")
        return 0
    }

    private func saveControl(andAddAnother: Bool) {
        var b = editing ?? ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: 0, channel: 1, velocity: 127, isToggle: nil)
        b.title = title
        b.symbol = symbol
        b.kind = (controlType == .fader) ? .cc : kind
        b.number = number
        // Use global channel if enabled, otherwise use the selected channel
        b.channel = isGlobalChannel ? globalChannel : channel
        b.velocity = velocity
        b.isToggle = isToggle
        b.isFader = (controlType == .fader)
        // Set isSmall based on buttonType picker (not controlType)
        if controlType != .fader {
            b.isSmall = (buttonType == .small)
        }

        // Save fader orientation and direction (only for faders)
        if controlType == .fader {
            b.faderOrientation = faderOrientation
            b.faderDirection = faderDirection

            // Check if we need to reposition due to orientation change
            if let originalButton = editing, originalButton.isFader == true {
                let oldWidth = originalButton.gridWidth
                let oldHeight = originalButton.gridHeight
                let newWidth = b.gridWidth
                let newHeight = b.gridHeight

                // If dimensions changed, check if we need to reposition
                if oldWidth != newWidth || oldHeight != newHeight {
                    if let col = b.gridCol, let row = b.gridRow {
                        // Check if current position still works
                        if !canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Need to find a new position
                            if let newPos = findAvailablePosition(width: newWidth, height: newHeight, excluding: b.id) {
                                b.gridCol = newPos.col
                                b.gridRow = newPos.row
                                debugPrint("🔄 Repositioned fader from (\(col), \(row)) to (\(newPos.col), \(newPos.row)) due to orientation change")
                            } else {
                                // This shouldn't happen if validation is working correctly
                                debugPrint("⚠️ No position found for fader - this shouldn't happen!")
                            }
                        }
                    }
                }
            }
        } else {
            // Check if we need to reposition due to button type change (regular <-> small)
            if let originalButton = editing, originalButton.isFader != true {
                let oldWidth = originalButton.gridWidth
                let oldHeight = originalButton.gridHeight
                let newWidth = b.gridWidth
                let newHeight = b.gridHeight

                // If dimensions changed, check if we need to reposition
                if oldWidth != newWidth || oldHeight != newHeight {
                    if let col = b.gridCol, let row = b.gridRow {
                        // Check if current position still works
                        if !canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Need to find a new position
                            if let newPos = findAvailablePosition(width: newWidth, height: newHeight, excluding: b.id) {
                                b.gridCol = newPos.col
                                b.gridRow = newPos.row
                                debugPrint("🔄 Repositioned button from (\(col), \(row)) to (\(newPos.col), \(newPos.row)) due to size change")
                            } else {
                                // This shouldn't happen if validation is working correctly
                                debugPrint("⚠️ No position found for button - this shouldn't happen!")
                            }
                        }
                    }
                }
            }
        }

        onSave(b, andAddAnother)

        if andAddAnother {
            debugPrint("➕ [CONTROL] Save & Add Another clicked")
            // CRITICAL FIX: Reset state variables BEFORE setting editing = nil
            // This prevents race condition where preset() uses old values when .onChange fires

            // Reset all form fields to defaults FIRST
            title = ""
            symbol = "square.grid.2x2.fill"
            kind = .cc
            velocity = 127
            isToggle = false
            autoAssign = true
            // FIX: Preserve controlType to keep fader/button mode for "Add Another"
            // Don't reset controlType - if adding fader, stay in fader mode
            // controlType = .button  // ← REMOVED
            // Only reset button-specific properties if it was a button
            if controlType == .button {
                buttonType = .regular
            }
            // Fader orientation and direction are preserved for next fader

            // Calculate next channel and number with the reset values
            debugPrint("  🔢 [CONTROL] Calculating next free number BEFORE setting editing=nil")
            let nextChannel = isGlobalChannel ? globalChannel : 1
            channel = nextChannel
            // FIX: After saving, find next free number starting from the one we just saved + 1
            // The just-saved control is now in the array, so we need to search past it
            let savedNumber = b.number
            let nextNumber = firstFreeNumberStartingFrom(savedNumber + 1, for: kind, channel: nextChannel)
            number = nextNumber
            debugPrint("  ✅ [CONTROL] Set channel to \(nextChannel), number to \(nextNumber)")

            // NOW set editing to nil (triggers .onChange which calls preset())
            // preset() will now see the correct reset values above
            debugPrint("  🔄 [CONTROL] Setting editing=nil (will trigger .onChange)")
            editing = nil

            // Recalculate space validation after reset
            isOutOfRoom = !validateSpaceForAddMode()
        }
    }

    // Recompute when auto-assign is enabled or MIDI type/channel changes
}

// MARK: - MIDI Note Helper
extension Int {
    var midiNoteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (self / 12) - 2
        let noteIndex = self % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Edit Control Sheet (separate from Add Control)
struct CBEditControlSheet: View {
    @Binding var editing: ControlButton?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (ControlButton) -> Void
    var onCancel: () -> Void
    var onDelete: ((ControlButton) -> Void)? = nil
    let icons: [String]

    @State private var title: String = ""
    @State private var symbol: String = "square.grid.2x2.fill"
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 0
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var autoAssign: Bool = true
    @State private var isToggle: Bool = false
    @State private var isFaderUI: Bool = false
    @State private var showDeleteAlert: Bool = false
    // Fader orientation and direction
    @State private var faderOrientation: String = "vertical"
    @State private var faderDirection: String = "up"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    // Control type is not editable - just show what it is
                    HStack {
                        Text("Control Type")
                        Spacer()
                        Text(isFaderUI ? "Fader" : "Button")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    if !isFaderUI {
                        Toggle("Small Button", isOn: Binding(
                            get: { editing?.isSmall ?? false },
                            set: { newVal in editing?.isSmall = newVal }
                        ))
                    }
                    HStack {
                        TextField("Control Name", text: $title, prompt: Text("Control Name").foregroundColor(.secondary))
                        if !title.isEmpty {
                            Button(action: { title = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !isFaderUI {
                        IconPicker(symbol: $symbol, icons: icons)
                            .id("icon-picker-cue")
                        Picker("Behavior", selection: $isToggle) {
                            Text("Momentary").tag(false)
                            Text("Toggle").tag(true)
                        }
                    }

                    // Fader orientation and direction (only for faders)
                    if isFaderUI {
                        Picker("Fader Orientation", selection: $faderOrientation) {
                            Text("Vertical").tag("vertical")
                            Text("Horizontal").tag("horizontal")
                        }

                        Picker("Fader Direction", selection: $faderDirection) {
                            Text("Up").tag("up")
                            Text("Down").tag("down")
                            Text("Left").tag("left")
                            Text("Right").tag("right")
                        }
                        .id("fader-direction-picker-edit")
                    }
                }
                // Live Preview
                Section(header: Text("Preview")) {
                    HStack {
                        Spacer(minLength: 0)
                        if isFaderUI {
                            ControlFaderPreview(title: title, cc: number, channel: channel, orientation: faderOrientation, direction: faderDirection)
                        } else {
                            ControlButtonPreview(title: title, symbol: symbol, kind: kind, number: number, channel: channel, velocity: velocity)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
                Section(header: Text("MIDI")) {
                    Toggle(isOn: $autoAssign) {
                        Text("Assign MIDI automatically")
                    }
                    if !isFaderUI {
                        Picker("Type", selection: $kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                    }
                    Picker("Channel", selection: $channel) {
                        ForEach(1...16, id: \.self) { ch in
                            Text("\(ch)").tag(ch)
                        }
                    }
                    MIDINumberPicker(
                        kind: kind,
                        number: $number,
                        disabled: autoAssign,
                        channel: channel,
                        currentOwnerName: currentOwnerName,
                        editingControl: editing
                    )
                    .id(kind == .note ? "note-picker-edit" : "cc-picker-edit")
                    if !isFaderUI && kind == .note {
                        VelocityPicker(velocity: $velocity, disabled: false)
                    }
                    if let owner = conflictOwner() {
                        Text("⚠️ Taken by: \(owner)").foregroundColor(.orange)
                    }
                }

                // Delete section - always show when editing existing control
                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(isFaderUI ? "Delete Fader" : "Delete Button")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isFaderUI ? "Edit Fader" : "Edit Button")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .alert("Delete Control", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let control = editing {
                        onDelete?(control)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let controlTypeName = isFaderUI ? "fader" : "button"
                Text("Are you sure you want to delete this \(controlTypeName)? This action cannot be undone.")
            }
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save") {
                        if var b = editing {
                            b.title = title
                            b.symbol = symbol
                            b.kind = isFaderUI ? .cc : kind
                            b.number = number
                            b.channel = channel
                            b.velocity = velocity
                            b.isToggle = isToggle
                            b.isFader = isFaderUI
                            if !isFaderUI { b.isSmall = editing?.isSmall ?? false } else { b.isSmall = false }

                            // Save fader orientation and direction (only for faders)
                            if isFaderUI {
                                b.faderOrientation = faderOrientation
                                b.faderDirection = faderDirection
                            }

                            onSave(b)
                        }
                    }
                    .disabled(title.isEmpty || conflictOwner() != nil)
            )
            .onAppear { preset() }
            .onChange(of: autoAssign) { _, newValue in
                if newValue {
                    number = firstFreeNumber(for: kind, channel: channel)
                }
            }
            .onChange(of: kind) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: newValue, channel: channel)
                }
            }
            .onChange(of: channel) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: kind, channel: newValue)
                }
            }
            .onChange(of: faderOrientation) { _, newOrientation in
                // Auto-set appropriate direction when orientation changes
                if newOrientation == "vertical" && (faderDirection == "left" || faderDirection == "right") {
                    faderDirection = "up"
                } else if newOrientation == "horizontal" && (faderDirection == "up" || faderDirection == "down") {
                    faderDirection = "right"
                }
            }
        }
    }
    
    private func preset() {
        guard let b = editing else { 
            // For new buttons, enable auto-assign by default
            autoAssign = true
            return 
        }
        title = b.title
        symbol = b.symbol
        kind = b.kind
        number = b.number
        channel = b.channel
        velocity = b.velocity
        autoAssign = false  // For editing existing buttons, allow manual assignment
        isToggle = b.isToggle ?? false
        isFaderUI = b.isFader ?? false
        if !(b.isFader ?? false) { editing?.isSmall = b.isSmall ?? false }

        // Load fader orientation and direction with defaults
        if b.isFader == true {
            faderOrientation = b.faderOrientation ?? "vertical"
            faderDirection = b.faderDirection ?? (faderOrientation == "vertical" ? "up" : "right")
        }
    }

    private func conflictOwner() -> String? {
        // If we're editing an existing control and the MIDI assignment hasn't changed, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing control and checking its current MIDI assignment, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        for n in 0...127 {
            let key = MIDIKey(kind: kind, channel: channel, number: n)
            if currentOwnerName(key) != nil {
                // Skip if occupied by a different control
                if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == n {
                    // This is the control we're editing, so this number is available
                } else {
                    continue
                }
            }
            return n
        }
        return 0
    }
}

// MARK: - Control Button Preview (used in editor)
struct ControlButtonPreview: View {
    let title: String
    let symbol: String
    let kind: MIDIKind
    let number: Int
    let channel: Int
    let velocity: Int
    var isSmall: Bool = false
    
    var body: some View {
        let frameWidth: CGFloat = isSmall ? 92 : 120
        let frameHeight: CGFloat = isSmall ? 72 : 86
        let corner: CGFloat = isSmall ? 12 : 14
        let iconSize: CGFloat = isSmall ? 24 : 24
        let titleFont: Font = isSmall ? .footnote.weight(.semibold) : .footnote.weight(.semibold)
        let textOnlyFont: Font = isSmall ? .headline.weight(.semibold) : .title3.weight(.semibold)
        
        return VStack(spacing: 6) {
            if symbol.isEmpty {
                Text(title.isEmpty ? "Custom" : title)
                    .font(textOnlyFont)
                Text(kind == .cc ? "\(channel)•\(number)" : "\(channel)•\(number)•\(velocity)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: symbol).font(.system(size: iconSize, weight: .semibold))
                Text(title.isEmpty ? "Custom" : title).font(titleFont)
                if !isSmall {
            Text(kind == .cc ? "\(channel)•\(number)" : "\(channel)•\(number)•\(velocity)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .background(
            RoundedRectangle(cornerRadius: corner)
                .stroke(Color.accentColor, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: corner).fill(Color.clear))
        )
    }
}

// Preview for fader in the editor — matches in-grid FaderTileContent visuals
struct ControlFaderPreview: View {
    let title: String
    let cc: Int
    let channel: Int
    var orientation: String = "vertical"
    var direction: String = "up"

    var body: some View {
        let isHorizontal = (orientation == "horizontal")
        let previewValue: Double = 0.66  // Preview at 66% position

        if isHorizontal {
            // HORIZONTAL FADER PREVIEW
            // Fill alignment: "right" fills from left, "left" fills from right
            // The alignment handles the directional flip, so we use the same value for both
            let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing
            let headWidth: CGFloat = 18
            let trackWidth: CGFloat = 140 - headWidth

            VStack(spacing: 6) {
                Text(title.isEmpty ? "Fader" : title)
                    .font(.footnote.weight(.semibold))
                ZStack(alignment: fillAlignment) {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 2)
                    // Fill based on preview value - alignment handles the direction
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: trackWidth * previewValue)
                        .padding(3)
                    // Head positioned based on value - conditional offset for direction
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(width: headWidth)
                        .offset(x: (direction == "right") ? (trackWidth * previewValue) : -(trackWidth * previewValue))
                        .padding(.vertical, 6)
                }
                .frame(width: 140, height: 60)
                Text("\(channel)•\(cc)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 160, height: 120)
        } else {
            // VERTICAL FADER PREVIEW
            // Fill alignment: "up" fills from bottom, "down" fills from top
            // The alignment handles the directional flip, so we use the same value for both
            let fillAlignment: Alignment = (direction == "up") ? .bottom : .top
            let headHeight: CGFloat = 18
            let trackHeight: CGFloat = 120 - headHeight

            VStack(spacing: 6) {
                Text(title.isEmpty ? "Fader" : title)
                    .font(.footnote.weight(.semibold))
                ZStack(alignment: fillAlignment) {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 2)
                    // Fill based on preview value - alignment handles the direction
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(height: trackHeight * previewValue)
                        .padding(4)
                    // Head positioned based on value - conditional offset for direction
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(height: headHeight)
                        .padding(.horizontal, 6)
                        .offset(y: (direction == "up") ? -(trackHeight * previewValue) : (trackHeight * previewValue))
                }
                .frame(width: 60, height: 120)
                Text("\(channel)•\(cc)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, height: 140)
        }
    }
}

// MARK: - Project Data Structure (moved to ProjectPayload.swift)
// MARK: - ProjectIO (moved to ProjectIO.swift)

// MARK: - MIDI conflict key
internal struct MIDIKey: Hashable {
    let kind: MIDIKind
    let channel: Int
    let number: Int
}

// MARK: - ContentView
internal struct ContentView: View {
    // Icon library for control buttons
    let icons = [
        // Transport & Control
        "backward.end.fill", "backward.frame.fill",
        "forward.end.fill", "forward.frame.fill",
        "pause.circle.fill", "pause.fill",
        "play.circle.fill", "play.fill", "play.square.fill",
        "record.circle.fill",
        "stop.circle.fill", "stop.fill",

        // Music & Performance
        "figure.disc.sports",
        "guitars.fill",
        "metronome", "metronome.fill",
        "music.note", "music.note.list", "music.quarternote.3",
        "pianokeys.inverse",

        // Audio & Mixing
        "dial.max",
        "ear.fill",
        "headphones.circle.fill",
        "mic.fill",
        "slider.horizontal.3",
        "speaker.slash.fill",
        "speaker.wave.2.fill", "speaker.wave.3.fill",
        "waveform",
        "waveform.circle", "waveform.circle.fill",
        "waveform.path",
        "waveform.path.badge.minus",
        "waveform.path.ecg", "waveform.path.ecg.rectangle",

        // Effects & Processing
        "arrow.down.circle.fill", "arrow.up.circle.fill",
        "arrow.up.right.circle.fill",
        "bolt.circle.fill", "bolt.fill",
        "building.columns.fill",
        "burst.fill",
        "cloud.bolt.fill",
        "dot.radiowaves.left.and.right",
        "repeat.1.circle.fill", "repeat.circle.fill",
        "sparkles",
        "wave.3.right.circle.fill",

        // Song Structure
        "b.circle.fill", "b.square.fill",
        "c.circle.fill", "c.square.fill",
        "flag.checkered",
        "i.circle.fill",
        "o.circle.fill",
        "v.circle.fill", "v.square.fill",

        // Numbers & Markers
        "1.circle", "1.square.fill",
        "2.circle", "2.square.fill",
        "3.circle", "3.square.fill",
        "4.circle", "4.circle.fill",
        "5.circle",
        "6.circle",
        "8.circle.fill",

        // People & Groups
        "person.2.fill", "person.3.fill",

        // Lighting & Theater
        "arrow.down.square.fill", "arrow.up.square.fill",
        "hands.clap.fill",
        "light.beacon.max.fill",
        "light.max", "light.min",

        // Utility
        "circle.hexagongrid.fill",
        "memories",
        "minus.circle.fill",
        "plus.circle.fill",
        "square.grid.2x2.fill"
    ]

    @EnvironmentObject var store: SetlistStore
    @Environment(\.scenePhase) private var scenePhase

    // Simple connection systems - USB server + WiFi client
    @EnvironmentObject var usbServer: ConnectionManager
    @EnvironmentObject var wifiClient: BridgeOutput
    @EnvironmentObject var connectionCoordinator: ConnectionCoordinator

    // UI state
    @State private var showConnections = false
    @State private var showAddEdit = false
    @State private var editingSong: Song? = nil
    @State private var isEditing = false

    // Library state
    @State private var songLibrary: [Song] = []
    @State private var libBatchMode = false
    @State private var libSelected: Set<UUID> = []
    @State private var sortMode: LibrarySortMode = .nameAZ
    @State private var libAddedAt: [UUID: Date] = [:]
    @State private var libraryQuery: String = ""
    @State private var libraryQueryDebounced: String = ""
    @State private var setlistQuery: String = ""
    @State private var setlistQueryDebounced: String = ""

    // Splash Screen
    @State private var showSplash = true
    @State private var hasInitialized = false
    // Projects
    @State private var showProjects = false
    @State private var showOnboarding = false
    @AppStorage("lastProjectName") private var projectName: String = "Untitled"
    @State private var projectsList: [String] = []
    @State private var isDirty: Bool = false
    @State private var showNamePrompt: Bool = false
    @State private var tempName: String = ""
    @State private var showSaveChangesAlert: Bool = false
    @State private var pendingAction: (() -> Void)? = nil

    // Song deletion confirmation
    @State private var showDeleteConfirmation: Bool = false
    @State private var songToDelete: Song? = nil

    // Document loading error alert
    @State private var showDocumentLoadError: Bool = false
    @State private var documentLoadErrorMessage: String = ""

    // Control Area (formerly transport)
    @State private var controlButtons: [ControlButton] = []
    @State private var controlEditMode = false
    @State private var controlsPerRow: Int = 4
    @State private var controlAreaHeight: CGFloat = 0
    @State private var showControlEditor: Bool = false
    @State private var editingControl: ControlButton? = nil
    @State private var showEditControlSheet: Bool = false
    @State private var editingControlForEdit: ControlButton? = nil
    @State private var showMidiTable: Bool = false

    // Notification subscriptions (to prevent memory leaks)
    @State private var notificationCancellables: Set<AnyCancellable> = []

    // Global MIDI Channel
    @State private var isGlobalChannel: Bool = false
    @State private var globalChannel: Int = 1

    // Undo/Redo
    @State private var setlistUndoStack: [[Song]] = []
    @State private var setlistRedoStack: [[Song]] = []
    @State private var libraryUndoStack: [[Song]] = []
    @State private var libraryRedoStack: [[Song]] = []
    @State private var controlUndoStack: [[ControlButton]] = []
    @State private var controlRedoStack: [[ControlButton]] = []

    // Misc
    @State private var autosaveTask: Task<Void, Never>? = nil
    // FIX #4: Replace task-based autosave with DispatchWorkItem
    @State private var autosaveWorkItem: DispatchWorkItem? = nil
    @State private var showAddEditMIDIOnly = false
    @State private var pendingAddIsFader: Bool? = nil
    @State private var isTyping: Bool = false
    
    // Performance caches
    @State private var cachedConflictLookup: [MIDIKey: String] = [:]
    @State private var cacheVersion: Int = 0
    @State private var cachedUsedCCs: Set<Int> = []
    // FIX #5: Conflict cache throttling
    @State private var conflictCacheUpdateScheduled = false

    // Control Area constraints
    private let maxControlRows: Int = 5

    

    // Visuals
    private var connectionTint: Color { connectionCoordinator.activeConnection != .none ? .green : .red }
    // activeIsUSB removed - now handled by ConnectionCoordinator

    // Break up body for compiler
    private var topBarView: some View {
            CBTopBar(
                mode: $store.mode,
                isEditing: $isEditing,
                projectTitle: projectName,
                connectionTint: connectionTint,
                connectionCoordinator: connectionCoordinator,
                onConnections: { showConnections = true },
                onProjects: { projectsList = ProjectIO.list(); showProjects = true },
                onEditToggle: { withAnimation(.easeInOut) { isEditing.toggle() } },
                onAdd: { editingSong = nil; showAddEdit = true },
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                onMidiTable: { showMidiTable = true },
                canUndo: !setlistUndoStack.isEmpty || !libraryUndoStack.isEmpty,
                canRedo: !setlistRedoStack.isEmpty || !libraryRedoStack.isEmpty,
                onTapProjectTitle: { tempName = projectName; showNamePrompt = true }
            )
    }

    private func buildMiddleSectionView() -> some View {
            if isEditing {
            return AnyView(
                HStack(spacing: 0) {
                    CBSetlistColumn(
                        songs: filteredSetlistSongs(),
                        searchText: $setlistQuery,
                        onRename: { s in editingSong = s; showAddEdit = true },
                        onRemove: { s in removeFromSetlist(s) },
                        onMove: { inds, newOffset in
                            pushSetlistUndo()
                            store.setlist.songs.move(fromOffsets: inds, toOffset: newOffset)
                        }
                    )
                    .padding(.top, 8)

                    Divider()

                    CBLibraryColumn(
                        rows: filteredLibraryRows(),
                        isEditing: $isEditing,
                        batchMode: $libBatchMode,
                        selected: $libSelected,
                        sortMode: $sortMode,
                        searchText: $libraryQuery,
                        onToggleSelect: { id in toggleLibSelection(id) },
                        onAddToSetlist: { s in addToSetlist(s) },
                        onDeleteFromLibrary: { s in deleteFromLibrary(s) },
                        onRename: { s in editingSong = s; showAddEdit = true }
                    )
                    .padding(.top, 8)
                }
                .overlay(alignment: .bottom) {
                    if libBatchMode {
                        CBBatchToolbar(
                            selectedCount: libSelected.count,
                            onSelectAll: selectAllLibrary,
                            onClear: { libSelected.removeAll() },
                            onAddToSetlist: addSelectedToSetlist,
                            onDelete: deleteSelectedFromLibrary
                        )
                    }
                }
            )
            } else {
            // Debug print removed - was causing console spam on every render
            return AnyView(
                CBPerformanceList(
                    songs: store.setlist.songs,
                    isCueMode: store.mode == .cue,
                    cuedID: store.cuedSong?.id,
                    onTapSong: { song in
                        if store.mode == .regular {
                            trigger(song)
                        } else {
                            store.cuedSong = song
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    },
                    onLongPressChangeMIDI: { song in
                        editingSong = song
                        showAddEditMIDIOnly = true
                    },
                    onRename: { s in editingSong = s; showAddEdit = true },
                    onDelete: { s in removeFromSetlist(s) },
                    onDuplicate: { s in duplicateSong(s) },
                    conflictFor: conflictLookup()
                )
                .onAppear { /* Start with blank data for shipping */ }
            .contentShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    if store.mode == .cue {
                        GeometryReader { geo in
                            let songs = store.setlist.songs
                            let cued = store.cuedSong
                            let cuedIndex = cued.flatMap { s in songs.firstIndex(where: { $0.id == s.id }) }
                            let canPrev = (cuedIndex ?? 0) > 0
                            let canNext = cuedIndex.map { $0 < songs.count - 1 } ?? false

                            DraggableTransportDock(
                                width: geo.size.width,
                                height: geo.size.height,
                                controlAreaHeight: $controlAreaHeight,
                                cuedName: cued?.name,
                                canPrev: canPrev,
                                canNext: canNext,
                                isGoEnabled: cued != nil,
                                onPrev: { selectPreviousCued() },
                                onGo: { cueGo() },
                                onNext: { selectNextCued() },
                                onClear: { store.cuedSong = nil },
                                isControlEditing: isEditing
                            )
                        }
                    }
                }
            )
        }
    }

    private var controlSectionView: some View {
            CBControlSection(
                buttons: $controlButtons,
                isEditing: $controlEditMode,
                perRow: $controlsPerRow,
            pendingAddIsFader: $pendingAddIsFader,
                reportedHeight: $controlAreaHeight,
                conflictFor: conflictLookup(),
                onTap: { btn in triggerControl(btn) },
                onEditButton: { btn in
                    editingControlForEdit = btn
                    showEditControlSheet = true
                },
            onAddButton: { if canAddMoreControls() { beginAddControlOfType(.button) } },
            onAddFader: { if canAddMoreControls() { beginAddControlOfType(.fader) } },
                onUndo: { undoControls() },
                onRedo: { redoControls() },
                canUndo: !controlUndoStack.isEmpty,
                canRedo: !controlRedoStack.isEmpty,
                onDelete: { btn in deleteControl(btn) },
                onMove: { from, to in pushControlUndo(); controlButtons.move(fromOffsets: from, toOffset: to); markDirty() },
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                markDirty: markDirty
            )
    }

    // FIX #1: Setup NotificationCenter subscriptions using Combine to prevent memory leaks
    private func setupNotificationSubscriptions() {
        // Clear any existing subscriptions
        notificationCancellables.removeAll()

        // Subscription 1: cbFaderChanged
        NotificationCenter.default.publisher(for: Notification.Name("cbFaderChanged"))
            .sink { [self] notif in
                guard let info = notif.userInfo as? [String: Any],
                      let channel = info["channel"] as? Int,
                      let cc = info["cc"] as? Int,
                      let value = info["value"] as? Int,
                      let id = info["id"] as? UUID,
                      let title = info["title"] as? String else { return }

                // Store the fader value in the ControlButton model for persistence
                if let index = controlButtons.firstIndex(where: { $0.id == id }) {
                    let faderValue = Double(value) / 127.0
                    controlButtons[index].faderValue = faderValue
                    markDirty() // Mark project as dirty to save the fader value
                    debugPrint("🎚️ cbFaderChanged: Stored fader value \(faderValue) for \"\(title)\"")
                }

                // Use global channel if enabled, otherwise use fader's channel
                let channelToUse = isGlobalChannel ? globalChannel : channel

                let connectionType = connectionCoordinator.activeConnection == .usb ? "USB" : "WiFi"
                debugPrint("🎚️ MIDI OUT [\(connectionType)]: Fader CC #\(cc) = \(value) • Ch \(channelToUse) • \"\(title)\"")

                // Use ConnectionCoordinator to send MIDI through the active connection
                connectionCoordinator.sendMIDI(type: .cc, channel: channelToUse, number: cc, value: value, label: title, buttonID: id.uuidString)
            }
            .store(in: &notificationCancellables)

        // Subscription 2: cbMIDIInputFromDAW
        NotificationCenter.default.publisher(for: Notification.Name("cbMIDIInputFromDAW"))
            .sink { [self] notif in
                debugPrint("🎚️ Received cbMIDIInputFromDAW notification: \(notif.userInfo ?? [:])")

                guard let info = notif.userInfo as? [String: Any],
                      let type = info["type"] as? String else {
                    debugPrint("🎚️ ❌ Invalid notification data")
                    return
                }

                if type == "cc",
                   let channel = info["channel"] as? Int,
                   let cc = info["cc"] as? Int,
                   let value = info["value"] as? Int {

                    debugPrint("🎚️ MIDI IN [DAW]: CC #\(cc) = \(value) • Ch \(channel)")

                    // Find matching fader and update its value
                    updateFaderFromDAW(channel: channel, cc: cc, value: value)
                } else {
                    debugPrint("🎚️ ❌ Invalid MIDI CC data: type=\(type), channel=\(info["channel"] ?? "nil"), cc=\(info["cc"] ?? "nil"), value=\(info["value"] ?? "nil")")
                }
            }
            .store(in: &notificationCancellables)
    }

    private func mainStack() -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                AnyView(topBarView)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if controlEditMode {
                            withAnimation(.easeInOut) {
                                controlEditMode = false
                            }
                        }
                    }
                AnyView(buildMiddleSectionView())
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if controlEditMode {
                            withAnimation(.easeInOut) {
                                controlEditMode = false
                            }
                        }
                    }
                AnyView(bottomSectionView)
            }
        )
    }

    private var bottomSectionView: some View {
        VStack(spacing: 0) {
            // Always show control area - it handles its own edit mode internally
            AnyView(controlSectionView)
        }
    }

    // MARK: - Control functions
    private func controlRowCount() -> Int {
        // Grid triples columns; normal buttons occupy 3, faders 2 (2 grid squares wide).
        let slotsPerRow = max(3, controlsPerRow * 3)
        let totalSlots = controlButtons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(totalSlots) / Double(slotsPerRow)))
    }
    
    // Update fader value from DAW MIDI input
    private func updateFaderFromDAW(channel: Int, cc: Int, value: Int) {
        debugPrint("🎚️ updateFaderFromDAW: Looking for fader with channel=\(channel), cc=\(cc), value=\(value)")
        debugPrint("🎚️ Available faders:")
        for (index, button) in controlButtons.enumerated() {
            if button.isFader == true {
                debugPrint("🎚️   Fader \(index): \"\(button.title)\" - channel=\(button.channel), cc=\(button.number)")
            }
        }
        
        // Find the fader that matches this MIDI channel and CC
        if let index = controlButtons.firstIndex(where: { button in
            button.isFader == true && button.channel == channel && button.number == cc
        }) {
            // Convert MIDI value (0-127) to fader value (0.0-1.0)
            let faderValue = Double(value) / 127.0
            
            debugPrint("🎚️ ✅ Found matching fader \"\(controlButtons[index].title)\" at index \(index)")
            debugPrint("🎚️ Updated fader \"\(controlButtons[index].title)\" to \(faderValue) from DAW MIDI")
            
            // Store the fader value in the ControlButton model for persistence
            controlButtons[index].faderValue = faderValue
            markDirty() // Mark project as dirty to save the fader value
            
            // Post notification for the fader tile to update its visual value
            NotificationCenter.default.post(
                name: Notification.Name("cbUpdateFaderFromDAW"),
                object: nil,
                userInfo: [
                    "buttonID": controlButtons[index].id.uuidString,
                    "value": faderValue
                ]
            )
        } else {
            debugPrint("🎚️ ❌ No matching fader found for channel=\(channel), cc=\(cc)")
        }
    }

    private func canAddMoreControls() -> Bool {
        return controlRowCount() < maxControlRows
    }
    private func addControl() {
        // Legacy helper kept if needed elsewhere: directly append a default control
        let conflicts = conflictLookup()
        let freeCC = (0...127).first { conflicts[MIDIKey(kind: .cc, channel: 1, number: $0)] == nil } ?? 0
        let new = ControlButton(title: "Custom", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127)
        controlButtons.append(new)
        invalidateConflictCache()
        markDirty()
    }

    private func beginAddControl() {
        // Prepare a default control for editing (do not append yet)
        let conflicts = conflictLookup()
        let freeCC = (0...127).first { conflicts[MIDIKey(kind: .cc, channel: 1, number: $0)] == nil } ?? 0
        let draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil)
        editingControl = draft
        pendingAddIsFader = false
        showControlEditor = true
    }

    private enum AddKind { case button, fader }
    private func beginAddControlOfType(_ kind: AddKind) {
        // Always compute fresh conflicts to ensure we have the latest control buttons
        let conflicts = computeConflictLookup()
        // FIX: Start from 1 instead of 0 to avoid assigning CC# 0 by default
        let freeCC = (1...127).first { conflicts[MIDIKey(kind: .cc, channel: 1, number: $0)] == nil } ?? 1
        debugPrint("🎹 beginAddControlOfType: Found free CC = \(freeCC), total conflicts = \(conflicts.count)")
        var draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil)
        switch kind {
        case .button:
            draft.isFader = false
            draft.isSmall = false
        case .fader:
            draft.isFader = true
            draft.isSmall = false
            draft.symbol = "" // no icon for fader
        }
        editingControl = draft
        // Hint the editor about fader mode
        pendingAddIsFader = (kind == .fader)
        showControlEditor = true
    }

    private func deleteControl(_ btn: ControlButton) {
        pushControlUndo()
        controlButtons.removeAll { $0.id == btn.id }
        invalidateConflictCache()
        markDirty()
    }

    @ViewBuilder
    private var contentView: some View {
        if showSplash {
            SplashScreen().transition(.opacity)
        } else {
            mainStack().ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    var body: some View {
        applyLifecycle(
            applyAlerts(
                applySheets(
                    contentView
                        .onChange(of: scenePhase) { _, phase in
                            // Ensure connections are properly managed when app becomes active
                            if phase == .active {
                                debugPrint("📱 App became active, managing connections...")

                                // Restart USB tunnel
                                // usb.stop() // Removed to prevent restart loop

                                // Small delay to ensure clean restart
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // Simple connection management - USB server is already running
                                    debugPrint("📱 App became active, USB server should be running")
                                    if !wifiClient.isConnected {
                                        wifiClient.restartDiscovery()
                                    }
                                }
                            } else if phase == .background {
                                // Save project when app goes to background
                                if isDirty && projectName != "Untitled" {
                                    debugPrint("💾 App going to background, saving project: \(projectName)")
                                    do {
                                        try ProjectIO.save(name: projectName, setlist: store.setlist.songs, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)
                                        isDirty = false
                                        debugPrint("✅ Background save completed: \(projectName)")
                                    } catch {
                                        debugPrint("❌ Background save failed: \(error)")
                                    }
                                }
                            }
                        }
                )
            )
        )
    }

    // MARK: - View Modifiers (extracted to fix compiler type-checking timeout)

    @ViewBuilder
    private func applySheets<V: View>(_ view: V) -> some View {
        view
        // MARK: Sheets
        .sheet(isPresented: $showConnections) {
            CBConnectionsSheet(
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                onDisconnectWifi: { connectionCoordinator.disconnectWiFi() },
                onConnectWifiItem: { item in
                    connectionCoordinator.connectToWiFi(bridge: item)
                }
            )
        }
        .sheet(isPresented: $showMidiTable) {
            CBControlSection.MidiTableSheet(
                setlist: store.setlist.songs,
                controlButtons: controlButtons,
                isGlobalChannel: $isGlobalChannel,
                globalChannel: $globalChannel,
                onDismiss: { showMidiTable = false },
                onApply: { items in
                    // Write changes back to setlist and controls by id
                    var set = store.setlist.songs
                    for i in 0..<set.count {
                        if let edited = items.first(where: { $0.id == set[i].id }) {
                            set[i].kind = edited.midiType
                            set[i].channel = edited.channel
                            if edited.midiType == .note { set[i].note = edited.value } else { set[i].cc = edited.value }
                        }
                    }
                    store.setlist.songs = set

                    var controls = controlButtons
                    for i in 0..<controls.count {
                        if let edited = items.first(where: { $0.id == controls[i].id }) {
                            controls[i].kind = edited.midiType
                            controls[i].channel = edited.channel
                            controls[i].number = edited.value
                        }
                    }
                    controlButtons = controls
                    markDirty()
                }
            )
        }
        .sheet(isPresented: $showAddEdit) {
            CBAddEditCueSheet(
                editingSong: $editingSong,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                defaultName: nextDefaultCueName(),
                onSave: { song, andAddAnother in
                    saveSong(song)
                    // Only close the sheet if not adding another
                    if !andAddAnother {
                        showAddEdit = false
                    }
                },
                onCancel: { showAddEdit = false },
                onDelete: { song in
                    deleteFromLibrary(song)
                    showAddEdit = false
                },
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel
            )
        }
        .sheet(isPresented: $showAddEditMIDIOnly) {
            CBMIDIPickerSheet(
                title: "Change MIDI",
                kind: editingSong?.kind ?? .cc,
                number: (editingSong?.kind == .note) ? (editingSong?.note ?? 60) : (editingSong?.cc ?? 0),
                channel: editingSong?.channel ?? 1,
                velocity: editingSong?.velocity ?? 127,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                onSave: { kind, number, channel, velocity in
                    guard var s = editingSong else { return }
                    s.kind = kind
                    if kind == .note { s.note = number } else { s.cc = number }
                    s.channel = channel
                    s.velocity = velocity
                    saveSong(s)
                    showAddEditMIDIOnly = false
                },
                onCancel: { showAddEditMIDIOnly = false }
            )
        }
        .sheet(isPresented: $showControlEditor) {
            CBControlEditorSheet(
                editing: $editingControl,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                    pendingIsFader: $pendingAddIsFader,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                onSave: { updated, andAddAnother in
                    if let idx = controlButtons.firstIndex(where: { $0.id == updated.id }) {
                        controlButtons[idx] = updated
                    } else {
                        // Assign grid position immediately when adding new control
                        var newControl = updated
                        if newControl.gridCol == nil || newControl.gridRow == nil {
                            // Find first available position based on control type
                            let buttonWidth = newControl.gridWidth
                            let buttonHeight = newControl.gridHeight

                            // Simple position finder - scan grid for first available spot
                            var foundPosition = false
                            for row in 0..<4 { // Scan up to 4 rows (matching display limit)
                                for col in 0..<(8 - buttonWidth + 1) { // 8 columns max, account for width
                                    var canPlace = true
                                    // Check if this position is free
                                    for existingButton in controlButtons {
                                        if let existingCol = existingButton.gridCol, let existingRow = existingButton.gridRow {
                                            let existingWidth = existingButton.gridWidth
                                            let existingHeight = existingButton.gridHeight

                                            // Check for overlap
                                            if !(col + buttonWidth <= existingCol ||
                                                existingCol + existingWidth <= col ||
                                                row + buttonHeight <= existingRow ||
                                                existingRow + existingHeight <= row) {
                                                canPlace = false
                                                break
                                            }
                                        }
                                    }
                                    if canPlace {
                                        newControl.gridCol = col
                                        newControl.gridRow = row
                                        foundPosition = true
                                        debugPrint("🔧 Assigned new control to position (\(col), \(row))")
                                        break
                                    }
                                }
                                if foundPosition { break }
                            }

                            if !foundPosition {
                                // Fallback to 0,0 if no space found
                                newControl.gridCol = 0
                                newControl.gridRow = 0
                                debugPrint("🔧 No space found, placing new control at (0, 0)")
                            }
                        }
                        controlButtons.append(newControl)
                    }
                    invalidateConflictCache()
                    markDirty()
                    // Only close the sheet if not adding another
                    if !andAddAnother {
                        showControlEditor = false
                        pendingAddIsFader = nil
                    }
                },
                    onCancel: { showControlEditor = false; pendingAddIsFader = nil },
                onDelete: { control in
                    deleteControl(control)
                    showControlEditor = false
                    pendingAddIsFader = nil
                },
                allButtons: controlButtons,
                columns: 8,
                icons: icons,
                isEditMode: false
            )
        }
        .sheet(isPresented: $showEditControlSheet) {
            CBControlEditorSheet(
                editing: $editingControlForEdit,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                pendingIsFader: $pendingAddIsFader,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                onSave: { updated, andAddAnother in
                    if let idx = controlButtons.firstIndex(where: { $0.id == updated.id }) {
                        controlButtons[idx] = updated
                    }
                    invalidateConflictCache()
                    markDirty()
                    // Edit sheet always closes (andAddAnother only for add sheet)
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                onCancel: {
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                onDelete: { control in
                    deleteControl(control)
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                allButtons: controlButtons,
                columns: 8,
                icons: icons,
                isEditMode: true
            )
        }
        .sheet(isPresented: $showProjects) {
            CBProjectsSheet(
                projectName: $projectName,
                projects: projectsList,
                isDirty: $isDirty,
                onTapTitleWhenUnsaved: { tempName = projectName; showNamePrompt = true },
                onSave: { saveCurrentProject(overwrite: true) },
                onSaveAs: { proposed in tempName = proposed; showNamePrompt = true },
                onNew: { newProjectFlow() },
                onLoad: { name in checkUnsavedChangesBeforeAction { loadProject(named: name) } },
                onDelete: { name in 
                    debugPrint("🗑️ Delete button tapped for project: \(name)")
                    
                    // If deleting the current project, switch to Untitled
                    if name == projectName {
                        debugPrint("🗑️ Deleting current project, switching to Untitled")
                        projectName = "Untitled"
                        isDirty = false
                    }
                    
                    ProjectIO.delete(name: name)
                    projectsList = ProjectIO.list()
                    debugPrint("🗑️ Projects list after deletion: \(projectsList)")
                },
                onOpenDocument: {
                    checkUnsavedChangesBeforeAction {
                        // Dismiss the projects sheet first before opening document picker
                        showProjects = false
                        // Delay to allow sheet dismissal animation to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            openDocumentPicker()
                        }
                    }
                },
                onExportProject: {
                    // Dismiss the projects sheet first before opening share sheet
                    showProjects = false
                    // Delay to allow sheet dismissal animation to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exportCurrentProject()
                    }
                }
            )
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .presentationBackground(Color(.systemBackground))
                .presentationCornerRadius(20)
                .interactiveDismissDisabled(false)
        }
    }

    @ViewBuilder
    private func applyAlerts<V: View>(_ view: V) -> some View {
        view
        .alert("Project Name", isPresented: $showNamePrompt, actions: {
            TextField("Name", text: $tempName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let final = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !final.isEmpty else { return }
                projectName = final
                saveCurrentProject(overwrite: false)
                showProjects = false
            }
        }, message: { Text("Enter a name for your project.") })
        .alert("Save Changes", isPresented: $showSaveChangesAlert, actions: {
            Button("Save", role: .none) {
                saveCurrentProject(overwrite: true)
                pendingAction?()
                pendingAction = nil
            }
            Button("Don't Save", role: .destructive) {
                pendingAction?()
                pendingAction = nil
            }
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        }, message: {
            Text("You have unsaved changes. Do you want to save them before continuing?")
        })
        .alert("Error Loading Project", isPresented: $showDocumentLoadError, actions: {
            Button("OK", role: .cancel) {
                documentLoadErrorMessage = ""
            }
        }, message: {
            Text(documentLoadErrorMessage)
        })
        .alert("Delete Song", isPresented: $showDeleteConfirmation, actions: {
            Button("Cancel", role: .cancel) { 
                songToDelete = nil
            }
            Button("Delete from Both", role: .destructive) {
                if let song = songToDelete {
                    performDeleteFromLibrary(song)
                }
                songToDelete = nil
            }
        }, message: { 
            if let song = songToDelete {
                Text("Remove \"\(song.name)\" from song library and cue list?")
            } else {
                Text("")
            }
        })
    }

    @ViewBuilder
    private func applyLifecycle<V: View>(_ view: V) -> some View {
        view
        // MARK: Lifecycle
        // FIX #1: Setup notification subscriptions on appear
        .onAppear {
            setupNotificationSubscriptions()
            // FIX: Initialize conflict cache immediately to prevent freeze during first render
            // This prevents conflictLookup() from returning empty cache during mode switch
            cachedConflictLookup = computeConflictLookup()
        }
        .task {
            debugPrint("🚀 App initialization starting...")

            // FIX: Build initial conflict cache BEFORE any data loads to prevent false "Taken by:" flashes
            cachedConflictLookup = computeConflictLookup()
            debugPrint("🔄 Initial conflict cache built with \(cachedConflictLookup.count) entries")

            // Clear any existing data for shipping - start completely blank (only on first launch)
            if !hasInitialized {
                debugPrint("🔄 First launch - clearing all data")
                store.setlist.songs.removeAll()
                songLibrary.removeAll()
                controlButtons.removeAll()
                libAddedAt.removeAll()
                hasInitialized = true
            }

            debugPrint("📁 Loading projects list...")
            projectsList = ProjectIO.list()
            debugPrint("📁 Found \(projectsList.count) projects: \(projectsList)")

            // Auto-open last project if available
            debugPrint("🔄 Attempting to auto-open last project...")
            autoOpenLastProject()

            // FIX: Rebuild conflict cache SYNCHRONOUSLY after loading project (no 500ms delay)
            cachedConflictLookup = computeConflictLookup()
            debugPrint("🔄 Conflict cache rebuilt after project load with \(cachedConflictLookup.count) entries")

            // Connections are now managed by ConnectionCoordinator
            debugPrint("🔌 Connections managed by ConnectionCoordinator")

            // Show splash screen for 2.5 seconds
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeInOut(duration: 0.6)) {
                debugPrint("🎬 Hiding splash screen")
                showSplash = false
            }

            // Show onboarding after splash screen if user hasn't seen it
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s after splash
                showOnboarding = true
            }

            debugPrint("✅ App initialization complete")
        }
        .onDisappear {
            // FIX #1: Clean up notification subscriptions to prevent memory leaks
            notificationCancellables.removeAll()
            // Don't stop connections completely - just pause them for background
            // This allows automatic reconnection when the app is reopened
            debugPrint("📱 App going to background - pausing connections")
            // Connections are managed by ConnectionCoordinator
        }
        // Connection monitoring now handled by ConnectionCoordinator
        .task(id: wifiClient.discovered.count) {
            debugPrint("🔍 Discovery changed: \(wifiClient.discovered.count) bridges found")
            debugPrint("🔌 USB connected: \(usbServer.isConnected), WiFi connected: \(wifiClient.isConnected)")
            
            // Simple status reporting - ConnectionCoordinator handles the logic
            if wifiClient.discovered.count > 0 {
                debugPrint("🔌 Bridge discovered - USB server running, WiFi available for manual connection")
            } else if wifiClient.discovered.count == 0 {
                debugPrint("⏸️ No bridges discovered - waiting for bridge to appear")
            } else if wifiClient.isConnected {
                debugPrint("✅ Already connected to bridge")
            } else {
                debugPrint("⏸️ Waiting for user to choose connection method")
            }
        }
        .task(id: store.mode) {
            if store.mode == .regular { store.cuedSong = nil }
            updateConflictCache()
        }
        .task(id: store.setlist.songs) {
            updateConflictCache()
            markDirty()
        }
        .task(id: songLibrary) {
            updateConflictCache()
            markDirty()
        }
        .task(id: controlButtons) {
            updateConflictCache()
            markDirty()
        }
            .onChange(of: isDirty) { _, newValue in
                // FIX #4: Use DispatchWorkItem instead of .task to prevent task churn
                guard newValue, projectName != "Untitled" else { return }
                autosaveWorkItem?.cancel()
                let currentProjectName = projectName
                let workItem = DispatchWorkItem {
                    snapshotAndSave(as: currentProjectName, overwrite: true)
                }
                autosaveWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
            }
            .onChange(of: isEditing) { _, newValue in
                if !newValue {
                libBatchMode = false
                libSelected.removeAll()
            }
        }
            .onChange(of: libraryQuery) { _, newQuery in
                // Set typing state for performance optimization
                isTyping = !newQuery.isEmpty

                // Debounce search to improve text field performance
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                    if libraryQuery == newQuery {
                        libraryQueryDebounced = newQuery
                        isTyping = false
                    }
                }
            }
            .onChange(of: setlistQuery) { _, newQuery in
                // Debounce setlist search with the same 300ms delay
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                    if setlistQuery == newQuery {
                        setlistQueryDebounced = newQuery
                    }
                }
            }
    }

    // MARK: - Conflict map (always use cached version to prevent main thread blocking)
    private func conflictLookup() -> [MIDIKey: String] {
        // FIX: NEVER compute synchronously during rendering - this was causing app freeze
        // Always return cached value (even if empty). The cache will be populated
        // asynchronously by .task modifiers within ~500ms
        // Empty cache temporarily shows no conflicts, which is acceptable vs freezing the app
        return cachedConflictLookup
    }

    private func computeConflictLookup() -> [MIDIKey: String] {
        var map: [MIDIKey: String] = [:]
        // Songs in setlist + library
        for s in (store.setlist.songs + songLibrary) {
            let key = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc,   channel: s.channel, number: s.cc)
            map[key] = s.name
        }
        // Control buttons - add type prefix for clarity
        for b in controlButtons {
            let typePrefix: String
            if b.isFader == true {
                typePrefix = "Fader"
            } else {
                typePrefix = "Button"
            }
            let displayName = b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            map[MIDIKey(kind: b.kind, channel: b.channel, number: b.number)] = displayName
        }
        return map
    }

    private func invalidateConflictCache() {
        // FIX: Immediately rebuild cache instead of clearing it
        // Clearing causes "Save & Add Another" to see empty cache and assign CC#0
        cachedConflictLookup = computeConflictLookup()
        cachedUsedCCs = []
        cacheVersion += 1
        debugPrint("🔄 Conflict cache rebuilt immediately with \(cachedConflictLookup.count) entries")
    }

    // FIX #5: Throttled conflict cache update (500ms throttle)
    private func scheduleConflictCacheUpdate() {
        guard !conflictCacheUpdateScheduled else { return }
        conflictCacheUpdateScheduled = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms throttle
            cachedConflictLookup = computeConflictLookup()
            conflictCacheUpdateScheduled = false
        }
    }

    private func updateConflictCache() {
        // FIX #5: Use throttled version instead of immediate update
        scheduleConflictCacheUpdate()
    }
    
    private func ownerName(for key: MIDIKey) -> String? { conflictLookup()[key] }

    // MARK: - Actions
    private func trigger(_ song: Song) {
        let id = song.id.uuidString
        
        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: song.kind, channel: song.channel, number: song.kind == .cc ? song.cc : (song.note ?? 60), value: song.kind == .cc ? 127 : song.velocity, label: song.name, buttonID: id)
        
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func triggerControl(_ b: ControlButton) {
        var value: Int
        var updatedButton = b

        if b.isToggle == true {
            // Toggle behavior: flip state and send appropriate value
            updatedButton.toggleState.toggle()
            value = updatedButton.toggleState ? (b.kind == .cc ? 127 : b.velocity) : 0
            debugPrint("🔄 Toggle button '\(b.title)': \(updatedButton.toggleState ? "ON" : "OFF")")
        } else {
            // Momentary behavior: send fixed value
            value = b.kind == .cc ? 127 : b.velocity
            debugPrint("⚡ Momentary button '\(b.title)': \(value)")
        }

        // Use global channel if enabled, otherwise use button's channel
        let channelToUse = isGlobalChannel ? globalChannel : b.channel

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: b.kind, channel: channelToUse, number: b.number, value: value, label: b.title, buttonID: b.id.uuidString)
        
        // Update the button state in the controlButtons array if it's a toggle
        if b.isToggle == true {
            if let index = controlButtons.firstIndex(where: { $0.id == b.id }) {
                controlButtons[index] = updatedButton
            }
        }
        
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func sendFaderMIDI(channel: Int, cc: Int, value: Int, title: String, buttonID: UUID) {
        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
    }

    private func cueGo() {
        guard let s = store.cuedSong else { return }
        trigger(s)
        if let i = store.setlist.songs.firstIndex(where: { $0.id == s.id }),
           i + 1 < store.setlist.songs.count {
            store.cuedSong = store.setlist.songs[i + 1]
        } else {
            store.cuedSong = nil
        }
    }

    private func selectPreviousCued() {
        guard let cued = store.cuedSong,
              let i = store.setlist.songs.firstIndex(where: { $0.id == cued.id }),
              i > 0 else { return }
        store.cuedSong = store.setlist.songs[i - 1]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectNextCued() {
        if let cued = store.cuedSong, let i = store.setlist.songs.firstIndex(where: { $0.id == cued.id }) {
            guard i + 1 < store.setlist.songs.count else { return }
            store.cuedSong = store.setlist.songs[i + 1]
        } else if !store.setlist.songs.isEmpty {
            // If nothing cued yet, select first
            store.cuedSong = store.setlist.songs.first
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Library helpers
    private func usedCCNumbers() -> Set<Int> {
        // Always compute fresh to avoid state modification during view updates
        var taken: Set<Int> = [CBTransportCC.play, CBTransportCC.stop, CBTransportCC.prev, CBTransportCC.next]
        taken.formUnion(store.setlist.songs.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(songLibrary.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(controlButtons.filter{ $0.kind == .cc }.map { $0.number })
        
        return taken
    }

    private func nextDefaultCueName() -> String {
        let prefix = "Cue "
        var maxN = 0
        for s in store.setlist.songs {
            if s.name.hasPrefix(prefix) {
                let rest = s.name.dropFirst(prefix.count)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "Cue \(maxN + 1)"
    }

    private func sortedLibrary() -> [Song] {
        switch sortMode {
        case .nameAZ:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) > (libAddedAt[$1.id] ?? .distantPast) }
        case .oldest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) < (libAddedAt[$1.id] ?? .distantPast) }
        }
    }

    private func libraryDecorated() -> [CBLibraryRow] {
        let setIDs = Set(store.setlist.songs.map { $0.id })
        return sortedLibrary().map { s in
            CBLibraryRow(id: s.id, song: s, isInSetlist: setIDs.contains(s.id), isSelected: libSelected.contains(s.id))
        }
    }

    private func filteredLibraryRows() -> [CBLibraryRow] {
        let rows = libraryDecorated()
        // FIX #9: Use debounced query and localizedCaseInsensitiveContains for better performance
        let q = libraryQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter { row in
            row.song.name.localizedCaseInsensitiveContains(q) ||
            (row.song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func filteredSetlistSongs() -> [Song] {
        let songs = store.setlist.songs
        let q = setlistQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return songs }
        return songs.filter { song in
            song.name.localizedCaseInsensitiveContains(q) ||
            (song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func toggleLibSelection(_ id: UUID) {
        if libSelected.contains(id) { libSelected.remove(id) } else { libSelected.insert(id) }
    }

    private func selectAllLibrary() {
        let candidates = filteredLibraryRows().filter { row in !store.setlist.songs.contains(where: { $0.id == row.id }) }
        libSelected = Set(candidates.map { $0.id })
    }

    private func addSelectedToSetlist() {
        guard !libSelected.isEmpty else { return }
        let toAdd = songLibrary.filter { libSelected.contains($0.id) }
        toAdd.forEach(addToSetlist(_:))
        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func deleteSelectedFromLibrary() {
        guard !libSelected.isEmpty else { return }
        songLibrary.removeAll { libSelected.contains($0.id) }
        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func addToSetlist(_ s: Song) {
        pushSetlistUndo()
        guard !store.setlist.songs.contains(where: { $0.id == s.id }) else { return }

        // Auto-assign MIDI message if not already assigned
        var songToAdd = s
        if songToAdd.channel == 0 || songToAdd.cc == 0 {
            // Find first available CC message
            let freeCC = firstFreeCC()
            if freeCC >= 0 {
                songToAdd.kind = .cc
                songToAdd.channel = 1
                songToAdd.cc = freeCC
                songToAdd.velocity = 127
            }
        }

        store.setlist.songs.append(songToAdd)
        invalidateConflictCache()
        isDirty = true
    }

    private func firstFreeCC() -> Int {
        for cc in 0...127 {
            let key = MIDIKey(kind: .cc, channel: 1, number: cc)
            if conflictLookup()[key] == nil {
                return cc
            }
        }
        return -1 // No free CC found
    }

    private func removeFromSetlist(_ s: Song) {
        pushSetlistUndo()
        store.setlist.songs.removeAll { $0.id == s.id }
        isDirty = true
    }

    private func deleteFromLibrary(_ s: Song) {
        // Check if song is also in cue list
        let isInCueList = store.setlist.songs.contains(where: { $0.id == s.id })
        
        if isInCueList {
            // Show confirmation popup
            songToDelete = s
            showDeleteConfirmation = true
        } else {
            // Safe to delete from library only
            performDeleteFromLibrary(s)
        }
    }
    
    private func performDeleteFromLibrary(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()
        
        // Remove from both library and cue list
        songLibrary.removeAll { $0.id == s.id }
        store.setlist.songs.removeAll { $0.id == s.id }
        libAddedAt[s.id] = nil
        invalidateConflictCache()
        isDirty = true
        
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func duplicateSong(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()
        
        var copy = Song(name: s.name + " (Copy)", subtitle: s.subtitle, cc: s.cc, channel: s.channel)
        copy.kind = s.kind
        copy.note = s.note
        copy.velocity = s.velocity
        songLibrary.append(copy)
        libAddedAt[copy.id] = Date()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.5)
        isDirty = true
    }

    private func saveSong(_ song: Song) {
        pushSetlistUndo()
        pushLibraryUndo()
        
        let isNewSong = !songLibrary.contains(where: { $0.id == song.id })
        
        // Update existing song in setlist if it's there
        if let i = store.setlist.songs.firstIndex(where: { $0.id == song.id }) { 
            store.setlist.songs[i] = song 
        }
        
        // Add or update in library
        if let j = songLibrary.firstIndex(where: { $0.id == song.id }) {
            songLibrary[j] = song
        } else {
            songLibrary.append(song)
            libAddedAt[song.id] = Date()
            
            // For new songs, also add directly to cue list for better UX
            if isNewSong && !store.setlist.songs.contains(where: { $0.id == song.id }) {
                store.setlist.songs.append(song)
        }
        }
        
        // Invalidate conflict cache since MIDI assignments may have changed
        invalidateConflictCache()
        isDirty = true
    }

    private func markDirty() { 
        isDirty = true
        startAutosave()
    }

    private func snapshotAndSave(as name: String, overwrite: Bool) {
        do {
            try ProjectIO.save(name: name, setlist: store.setlist.songs, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)
            projectName = name
            isDirty = false
            projectsList = ProjectIO.list()
        } catch { debugPrint("Save failed: \(error)") }
    }

    /// Generate a unique project name by appending (1), (2), etc. if name already exists
    private func uniqueProjectName(baseName: String) -> String {
        let existingProjects = projectsList

        // If name doesn't exist, return as-is
        if !existingProjects.contains(baseName) {
            return baseName
        }

        // Find the next available number
        var counter = 1
        while existingProjects.contains("\(baseName) (\(counter))") {
            counter += 1
        }

        return "\(baseName) (\(counter))"
    }

    // MARK: - Undo/Redo helpers
    private func pushSetlistUndo() {
        setlistUndoStack.append(store.setlist.songs)
        setlistRedoStack.removeAll()
    }
    private func undoSetlist() {
        guard let last = setlistUndoStack.popLast() else { return }
        setlistRedoStack.append(store.setlist.songs)
        store.setlist.songs = last
        isDirty = true
    }
    private func redoSetlist() {
        guard let next = setlistRedoStack.popLast() else { return }
        setlistUndoStack.append(store.setlist.songs)
        store.setlist.songs = next
        isDirty = true
    }
    
    private func pushLibraryUndo() {
        libraryUndoStack.append(songLibrary)
        libraryRedoStack.removeAll()
    }
    private func undoLibrary() {
        guard let last = libraryUndoStack.popLast() else { return }
        libraryRedoStack.append(songLibrary)
        songLibrary = last
        isDirty = true
    }
    private func redoLibrary() {
        guard let next = libraryRedoStack.popLast() else { return }
        libraryUndoStack.append(songLibrary)
        songLibrary = next
        isDirty = true
    }
    
    // Combined undo/redo that handles both setlist and library
    private func performUndo() {
        // Prioritize setlist undo if available, otherwise library undo
        if !setlistUndoStack.isEmpty {
            undoSetlist()
        } else if !libraryUndoStack.isEmpty {
            undoLibrary()
        }
    }
    
    private func performRedo() {
        // Prioritize setlist redo if available, otherwise library redo
        if !setlistRedoStack.isEmpty {
            redoSetlist()
        } else if !libraryRedoStack.isEmpty {
            redoLibrary()
        }
    }

    private func pushControlUndo() {
        controlUndoStack.append(controlButtons)
        controlRedoStack.removeAll()
    }
    private func undoControls() {
        guard let last = controlUndoStack.popLast() else { return }
        controlRedoStack.append(controlButtons)
        controlButtons = last
    }
    private func redoControls() {
        guard let next = controlRedoStack.popLast() else { return }
        controlUndoStack.append(controlButtons)
        controlButtons = next
    }

    private func saveCurrentProject(overwrite: Bool) {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "Untitled" {
            tempName = trimmed.isEmpty ? "My Show" : trimmed
            showNamePrompt = true
            return
        }
        snapshotAndSave(as: trimmed, overwrite: overwrite)
    }

    private func loadProject(named: String) {
        do {
            debugPrint("🔄 Loading project: \(named)")
            let payload = try ProjectIO.load(name: named)
            debugPrint("📦 Project payload loaded - setlist: \(payload.setlist.count) songs, library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            projectName = payload.name
            store.setlist.songs = payload.setlist
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Migrate controls that are beyond the 4-row limit (rows 0-3)
            migrateOutOfBoundsControls()

            debugPrint("✅ Project data assigned - setlist: \(store.setlist.songs.count) songs, library: \(songLibrary.count) songs, controls: \(controlButtons.count) buttons")
            
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil { libAddedAt[s.id] = now }
            isDirty = false
            debugPrint("✅ Project loaded successfully: \(named)")
        } catch {
            debugPrint("❌ Load failed for project \(named): \(error)")
        }
    }

    /// Migrates controls that are positioned beyond the 4-row limit (rows 0-3) or 8-column limit (cols 0-7)
    /// This fixes projects created when the row limit was higher or controls positioned incorrectly
    private func migrateOutOfBoundsControls() {
        // FIX #10: Early exit check using .contains for performance
        let hasOutOfBounds = controlButtons.contains { button in
            let width = button.gridWidth
            let height = button.gridHeight

            if let row = button.gridRow, row >= 4 { return true }
            if let col = button.gridCol, col >= 8 { return true }
            if let col = button.gridCol, col + width > 8 { return true }
            if let row = button.gridRow, row + height > 4 { return true }
            return false
        }

        guard hasOutOfBounds else {
            debugPrint("✅ No out-of-bounds controls found")
            return
        }

        var migratedCount = 0

        debugPrint("⚠️ Found controls out of bounds (beyond row 3 or col 7), starting migration...")

        // Second pass: reposition out-of-bounds controls
        for i in 0..<controlButtons.count {
            let button = controlButtons[i]
            let width = button.gridWidth
            let height = button.gridHeight
            var needsRepositioning = false

            // Check all out-of-bounds conditions
            if let row = button.gridRow, row >= 4 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col >= 8 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col + width > 8 {
                needsRepositioning = true
            }
            if let row = button.gridRow, row + height > 4 {
                needsRepositioning = true
            }

            if needsRepositioning {
                let currentCol = button.gridCol ?? -1
                let currentRow = button.gridRow ?? -1
                debugPrint("🔧 Control '\(button.title)' at (\(currentCol), \(currentRow)) size \(width)×\(height) needs repositioning")

                // Try to find an available position within the 4-row, 8-column limit

                var foundPosition = false
                for newRow in 0..<4 {
                    for newCol in 0..<(8 - width + 1) {
                        var canPlace = true

                        // Check if this position is free
                        for j in 0..<controlButtons.count where i != j {
                            if let existingCol = controlButtons[j].gridCol,
                               let existingRow = controlButtons[j].gridRow {
                                let existingWidth = controlButtons[j].gridWidth
                                let existingHeight = controlButtons[j].gridHeight

                                // Check for overlap
                                if !(newCol + width <= existingCol ||
                                    existingCol + existingWidth <= newCol ||
                                    newRow + height <= existingRow ||
                                    existingRow + existingHeight <= newRow) {
                                    canPlace = false
                                    break
                                }
                            }
                        }

                        if canPlace {
                            controlButtons[i].gridCol = newCol
                            controlButtons[i].gridRow = newRow
                            foundPosition = true
                            migratedCount += 1
                            debugPrint("✅ Repositioned '\(button.title)' to (\(newCol), \(newRow))")
                            break
                        }
                    }
                    if foundPosition { break }
                }

                if !foundPosition {
                    // No space found - clear position to let auto-assign handle it
                    controlButtons[i].gridCol = nil
                    controlButtons[i].gridRow = nil
                    debugPrint("⚠️ No space found for '\(button.title)', cleared position for auto-assign")
                }
            }
        }

        if migratedCount > 0 {
            debugPrint("✅ Migration complete: repositioned \(migratedCount) control(s)")
            // Mark as dirty so the migration is saved
            markDirty()
        }
    }

    // MARK: - Automatic Save/Open Functions
    
    /// Start automatic saving with debouncing
    private func startAutosave() {
        // Cancel existing autosave task
        autosaveTask?.cancel()
        
        // Only autosave if project has a name (not "Untitled")
        guard projectName != "Untitled" && !projectName.isEmpty else { return }
        
        autosaveTask = Task {
            // Wait 2 seconds before saving to debounce rapid changes
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                if isDirty && projectName != "Untitled" {
                    debugPrint("💾 Auto-saving project: \(projectName)")
                    do {
                        try ProjectIO.save(name: projectName, setlist: store.setlist.songs, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel)
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
    private func autoOpenLastProject() {
        debugPrint("🔍 Auto-open check - projectName: '\(projectName)'")
        debugPrint("🔍 UserDefaults lastProjectName: '\(UserDefaults.standard.string(forKey: "lastProjectName") ?? "nil")'")
        guard projectName != "Untitled" && !projectName.isEmpty else { 
            debugPrint("⏭️ Skipping auto-open - projectName is 'Untitled' or empty")
            debugPrint("💡 To enable auto-open, save a project with a name (not 'Untitled')")
            return 
        }
        
        // Check if the project file exists
        do {
            let payload = try ProjectIO.load(name: projectName)
            debugPrint("🔄 Auto-opening last project: \(projectName)")
            debugPrint("📦 Auto-open payload - setlist: \(payload.setlist.count) songs, library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Load the project data
            store.setlist.songs = payload.setlist
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil { 
                libAddedAt[s.id] = now 
            }
            isDirty = false
            
            debugPrint("✅ Auto-opened project: \(projectName) - setlist: \(store.setlist.songs.count) songs, library: \(songLibrary.count) songs, controls: \(controlButtons.count) buttons")
        } catch {
            debugPrint("❌ Failed to auto-open project \(projectName): \(error)")
            // Reset to untitled if project doesn't exist
            projectName = "Untitled"
        }
    }
    
    // MARK: - Document-Based Project Functions
    
    /// Open document picker to load projects from Files/iCloud Drive
    private func openDocumentPicker() {
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

                        self.projectName = uniqueName
                        self.store.setlist.songs = payload.setlist
                        self.songLibrary = payload.library
                        self.controlButtons = payload.controls
                        self.isGlobalChannel = payload.isGlobalChannel ?? false
                        self.globalChannel = payload.globalChannel ?? 1
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
    private func exportCurrentProject() {
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
            setlist: store.setlist.songs,
            library: songLibrary,
            controls: controlButtons,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel
        )

        // Present share sheet
        DocumentProjectIO.exportProject(
            name: projectName,
            data: payload,
            from: rootViewController
        )
    }

    private func newProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                createNewProject()
            }
        } else {
            createNewProject()
        }
    }
    
    private func createNewProject() {
        projectName = "Untitled"
        store.setlist.songs.removeAll()
        songLibrary.removeAll()
        controlButtons.removeAll()
        libAddedAt.removeAll()
        isDirty = false
        // No seeding for shipping - start blank
    }
    
    private func checkUnsavedChangesBeforeAction(_ action: @escaping () -> Void) {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = action
        } else {
            action()
        }
    }

    // MARK: - Ready for Shipping
    // App starts with completely blank data - no placeholder content
}

// MARK: - Splash Screen
private struct SplashScreen: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Bear paw icon
                Image("BearPawIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.2)
                
                // App name
                Text("Cue Bear")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Subtle loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Shipping Ready
// All placeholder data removed - app starts completely blank


// MARK: - Top Bar
private struct CBTopBar: View {
    @Binding var mode: AppMode
    @Binding var isEditing: Bool
    let projectTitle: String
    let connectionTint: Color
    let connectionCoordinator: ConnectionCoordinator
    var onConnections: () -> Void
    var onProjects: () -> Void
    var onEditToggle: () -> Void
    var onAdd: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onMidiTable: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onTapProjectTitle: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            // Left section - project title
            Button(action: onTapProjectTitle) {
                Text(projectTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Center section - mode picker (hidden in edit mode)
            if !isEditing {
                Picker("", selection: $mode) {
                    Text("Regular").tag(AppMode.regular)
                    Text("Cue").tag(AppMode.cue)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { oldMode, newMode in
                    debugPrint("🎛️ Mode picker changed from \(oldMode) to \(newMode)")
                }
                .frame(maxWidth: 280)
            }

            Spacer()


            Button(action: onConnections) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(connectionTint)
                    .scaleEffect(connectionCoordinator.activeConnection == .none ? 1.0 : 1.0)
                    .animation(connectionCoordinator.activeConnection == .none ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: connectionCoordinator.activeConnection)
            }
            .buttonStyle(WhiteCapsuleButtonStyle())

            Button(action: onProjects) {
                Image(systemName: "folder.badge.gearshape")
                    .imageScale(.large)
            }
            .buttonStyle(WhiteCapsuleButtonStyle())
            .foregroundColor(.blue)

            Button(action: onMidiTable) {
                Image(systemName: "tablecells")
                    .imageScale(.large)
            }
            .buttonStyle(WhiteCapsuleButtonStyle())
            .foregroundColor(.blue)

            if isEditing {
                Button(action: onUndo) { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                    .disabled(!canUndo)
                Button(action: onRedo) { Image(systemName: "arrow.uturn.forward") }
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                    .disabled(!canRedo)
            }

            Button(isEditing ? "Done" : "Edit", action: onEditToggle)
                .buttonStyle(WhiteCapsuleButtonStyle())
                .foregroundColor(.blue)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .imageScale(.large)
            }
            .buttonStyle(WhiteCapsuleButtonStyle())
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Control Area

    // Widget-like packed grid layout types (visible to CBControlSection)
    struct GridSpan { let columns: Int; let rows: Int }
    struct GridSpanKey: LayoutValueKey { static let defaultValue = GridSpan(columns: 1, rows: 1) }
    struct GridOrigin { let col: Int; let row: Int; let isSet: Bool }
    struct GridOriginKey: LayoutValueKey { static let defaultValue = GridOrigin(col: -1, row: -1, isSet: false) }
    struct PackedGridLayout: Layout {
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat

        // FIX #6: Make Placement accessible for cache
        struct Placement { let originRow: Int; let originCol: Int; let span: GridSpan }

        // FIX #6: Implement cache structure to avoid recomputation
        struct LayoutCache {
            var width: CGFloat = 0
            var placements: [Placement] = []
            var rows: Int = 0
            var cellSize: CGSize = .zero
        }
        typealias Cache = LayoutCache

        // FIX #6: Implement makeCache to initialize cache
        func makeCache(subviews: Subviews) -> LayoutCache {
            return LayoutCache()
        }

        private func computePlacements(_ subviews: Subviews, width: CGFloat) -> (placements: [Placement], rows: Int, cellSize: CGSize) {
            let totalColSpacing = columnSpacing * CGFloat(max(0, columns - 1))
            let cellWidth = (width - totalColSpacing) / CGFloat(columns)
            let cellHeight = cellWidth
            var occupancy: [[Bool]] = Array(repeating: Array(repeating: false, count: columns), count: 1)

            func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
                if c + w > columns { return false }
                let rowsNeeded = r + h
                if rowsNeeded > occupancy.count {
                    occupancy.append(contentsOf: Array(repeating: Array(repeating: false, count: columns), count: rowsNeeded - occupancy.count))
                }
                for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
                return true
            }
            func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) {
                for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } }
            }

            var placements: [Placement] = []
            var placedIndex = Set<Int>()
            // First: honor explicit origins when possible
            for idx in subviews.indices {
                let span = subviews[idx][GridSpanKey.self]
                let origin = subviews[idx][GridOriginKey.self]
                if origin.isSet {
                    if origin.col >= 0, origin.row >= 0, fits(origin.row, origin.col, span.columns, span.rows) {
                        placements.append(Placement(originRow: origin.row, originCol: origin.col, span: span))
                        mark(origin.row, origin.col, span.columns, span.rows)
                        placedIndex.insert(idx)
                    }
                }
            }
            // Then: place remaining by first-fit
            for idx in subviews.indices where !placedIndex.contains(idx) {
                let span = subviews[idx][GridSpanKey.self]
                var placed = false
                var r = 0
                while !placed {
                    var c = 0
                    while c < columns {
                        if fits(r, c, span.columns, span.rows) { placements.append(Placement(originRow: r, originCol: c, span: span)); mark(r, c, span.columns, span.rows); placed = true; break }
                        c += 1
                    }
                    if !placed { r += 1 }
                }
            }

            var lastUsed = 0
            for (i, row) in occupancy.enumerated() { if row.contains(true) { lastUsed = i + 1 } }
            return (placements, max(1, lastUsed), CGSize(width: cellWidth, height: cellHeight))
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
            guard let width = proposal.width else { return .zero }
            // FIX #6: Use cached result if width hasn't changed
            if cache.width != width {
                let result = computePlacements(subviews, width: width)
                cache.width = width
                cache.placements = result.placements
                cache.rows = result.rows
                cache.cellSize = result.cellSize
            }
            let totalHeight = CGFloat(cache.rows) * cache.cellSize.height + rowSpacing * CGFloat(max(0, cache.rows - 1))
            return CGSize(width: width, height: totalHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
            let width = bounds.width
            // FIX #6: Use cached result if width hasn't changed
            if cache.width != width {
                let result = computePlacements(subviews, width: width)
                cache.width = width
                cache.placements = result.placements
                cache.rows = result.rows
                cache.cellSize = result.cellSize
            }
            for (idx, placement) in cache.placements.enumerated() {
                let x = CGFloat(placement.originCol) * (cache.cellSize.width + columnSpacing)
                let y = CGFloat(placement.originRow) * (cache.cellSize.height + rowSpacing)
                let w = CGFloat(placement.span.columns) * cache.cellSize.width + CGFloat(max(0, placement.span.columns - 1)) * columnSpacing
                let h = CGFloat(placement.span.rows) * cache.cellSize.height + CGFloat(max(0, placement.span.rows - 1)) * rowSpacing
                let rect = CGRect(x: bounds.minX + x, y: bounds.minY + y, width: w, height: h)
                subviews[idx].place(at: rect.origin, anchor: .topLeading, proposal: ProposedViewSize(rect.size))
            }
        }
    }
private struct CBControlSection: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var buttons: [ControlButton]
    @Binding var isEditing: Bool
    @Binding var perRow: Int
    @Binding var pendingAddIsFader: Bool?
    @Binding var reportedHeight: CGFloat
    let conflictFor: [MIDIKey: String]
    var onTap: (ControlButton) -> Void
    var onEditButton: (ControlButton) -> Void
    var onAddButton: () -> Void
    var onAddFader: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onDelete: (ControlButton) -> Void
    var onMove: (IndexSet, Int) -> Void
    var usbServer: ConnectionManager
    var wifiClient: BridgeOutput
    var connectionCoordinator: ConnectionCoordinator
    var markDirty: () -> Void

    // Mac editor architecture adapted for iPad
    @State private var dragging: ControlButton? = nil
    @State private var previewLocation: GridPosition? = nil
    @State private var dropSurfaceElevated: Bool = false
    @State private var isCollapsed: Bool = false
    @State private var editSessionNonce: Int = 0
    @State private var isDragOperation: Bool = false
    @State private var lastDropTime: Date = Date.distantPast
    @State private var isAutoAssigning: Bool = false

    // Smooth drag system inspired by cue capsule success
    @State private var dragTranslation: CGSize = .zero
    @State private var dragStartLocation: CGPoint = .zero
    @State private var shadowOffset: CGSize = .zero // For smooth shadow tracking

    // Track actual width for proper orientation handling
    @State private var actualWidth: CGFloat = UIScreen.main.bounds.width

    // Track calculated height to avoid infinite render loops
    @State private var cachedHeight: CGFloat = 0

    // PERFORMANCE FIX: Cache displacement calculations to prevent O(n²) recomputation during drag
    @State private var displacementCache: [UUID: (col: Int, row: Int)] = [:]
    @State private var displacementCacheKey: String = ""
    @State private var hasInvalidDisplacement: Bool = false

    // Pixel snapping to prevent jitter (from cue capsule success)
    private func snap(_ value: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        let scale = UIScreen.main.scale
        #else
        let scale: CGFloat = 2.0
        #endif
        return (value * scale).rounded() / scale
    }
    
    // Centralized drag state management
    private func clearDragState(reason: String) {
        debugPrint("🧹 Clearing drag state - \(reason)")
        if let draggingButton = dragging {
            debugPrint("🔍 Button \(draggingButton.title) final position: (\(draggingButton.gridCol ?? -1), \(draggingButton.gridRow ?? -1))")
        }
        dragging = nil
        previewLocation = nil
        displacementCache.removeAll()
        displacementCacheKey = ""
        hasInvalidDisplacement = false
        dropSurfaceElevated = false
        isDragOperation = false
        dragTranslation = .zero
        dragStartLocation = .zero
        shadowOffset = .zero
    }

    // Update displacement cache (called from onChange to avoid state modification during view update)
    private func updateDisplacementCache() {
        guard let dragging = dragging, let preview = previewLocation else {
            // No active drag - clear cache
            displacementCache.removeAll()
            displacementCacheKey = ""
            hasInvalidDisplacement = false
            return
        }

        // Generate cache key for current drag state
        let cacheKey = "\(dragging.id)_\(preview.col)_\(preview.row)"

        // Only rebuild if cache key changed
        if displacementCacheKey != cacheKey {
            displacementCacheKey = cacheKey
            let result = computeAllDisplacements(draggedButton: dragging, targetPosition: preview, columns: columns)
            displacementCache = result.displacements
            hasInvalidDisplacement = result.hasInvalidDisplacement
        }
    }

    // Grid configuration (same as Mac editor)
    private let columns = 8
    private let columnSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 10
    private let gridPadding: CGFloat = 20
    
    private var canAddMoreControlsGlobal: Bool {
        // Check if there's space for either a button (2x1) or fader (1x2)
        let testButton = ControlButton(title: "Test", symbol: "square", kind: .cc, number: 0, channel: 1, isFader: false)
        let testFader = ControlButton(title: "Test", symbol: "square", kind: .cc, number: 0, channel: 1, isFader: true)
        
        // Return true if we can fit either a button OR a fader
        return findFirstAvailablePosition(for: testButton) != nil || 
               findFirstAvailablePosition(for: testFader) != nil
    }
    
    private func controlRowCount() -> Int {
        let slotsPerRow = max(3, perRow * 3)
        let totalSlots = buttons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(max(1, totalSlots)) / Double(slotsPerRow)))
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            collapseHandle
            if !effectivelyCollapsed {
            mainHeader
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Show title when collapsed - use same styling as main header for consistency
                HStack {
                    Text("Control Area")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                Spacer()
                    // Allow entering edit mode even when collapsed/empty
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation(.easeInOut) {
                            isEditing.toggle()
                            if !isEditing {
                                clearDragState(reason: "exiting edit mode")
                            } else {
                                // Entering edit mode - always unfold control area
                                isCollapsed = false
                                editSessionNonce &+= 1
                                clearDragState(reason: "entering edit mode")
                            }
                        }
                    }
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private var collapseHandle: some View {
        Button(action: {
            // Only allow toggle if there are buttons in the control area
            if !buttons.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isCollapsed.toggle()
                }
            }
        }) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(buttons.isEmpty ? 0.15 : 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(buttons.isEmpty)
    }
    
    private var mainHeader: some View {
        HStack(spacing: 10) {
            Text("Control Area").font(.subheadline).fontWeight(.medium)
                Spacer()
            if !isCollapsed {
                // Show edit buttons only when expanded
                if isEditing {
                    HStack(spacing: 6) {
                    Button(action: onUndo) { Image(systemName: "arrow.uturn.backward") }
                        .buttonStyle(WhiteCapsuleButtonStyle())
                        .foregroundColor(.blue)
                            .controlSize(.small)
                        .disabled(!canUndo)
                    Button(action: onRedo) { Image(systemName: "arrow.uturn.forward") }
                        .buttonStyle(WhiteCapsuleButtonStyle())
                        .foregroundColor(.blue)
                            .controlSize(.small)
                        .disabled(!canRedo)
                        // Two explicit add buttons
                        Button("+ Button") { onAddButton() }
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                        .controlSize(.small)
                        .disabled(!canAddMoreControlsGlobal)
                        Button("+ Fader") { onAddFader() }
                        .buttonStyle(WhiteCapsuleButtonStyle())
                        .foregroundColor(.blue)
                        .controlSize(.small)
                    .disabled(!canAddMoreControlsGlobal)
                }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)).animation(.easeOut(duration: 0.2).delay(0.1)),
                        removal: .opacity.combined(with: .scale(scale: 0.8)).animation(.easeIn(duration: 0.15))
                    ))
                }
            }
                // Always show Edit/Done button
                Button(isEditing ? "Done" : "Edit") { 
                    debugPrint("🎛️ Edit button tapped, current isEditing: \(isEditing)")
                    withAnimation(.easeInOut) { 
                        isEditing.toggle()
                        debugPrint("🎛️ Edit mode changed to: \(isEditing)")
                        if !isEditing {
                            clearDragState(reason: "main edit button - exiting edit mode")
                        } else {
                            editSessionNonce &+= 1
                            clearDragState(reason: "main edit button - entering edit mode")
                        }
                    } 
                }
                .buttonStyle(WhiteCapsuleButtonStyle())
                .foregroundColor(.blue)
            .controlSize(.small)
            }
            .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    

    var body: some View {
        let gridArea = Group {
            if effectivelyCollapsed {
                // Collapsed or empty state: header-only, no grid height
                let collapsedHeight: CGFloat = 0
                Color.clear.frame(height: collapsedHeight)
            } else {
                // Create a view that responds to height changes
                GeometryReader { outerProxy in
                    buildControlGrid(proxy: outerProxy, isCtrlEditing: isEditing, sessionNonce: editSessionNonce, usbServer: usbServer, wifiClient: wifiClient, connectionCoordinator: connectionCoordinator)
                        .onAppear {
                            // Update actual width when view appears
                            actualWidth = outerProxy.size.width
                        }
                        .onChange(of: outerProxy.size.width) { _, newWidth in
                            // Update actual width when orientation changes
                            actualWidth = newWidth
                            debugPrint("🔄 CBControlSection: Width changed to \(newWidth)")
                        }
                }
                .id("ctrl-geo-\(isEditing)-sess-\(editSessionNonce)")
                .frame(height: calculateDynamicHeight())
                .onChange(of: actualWidth) { _, _ in
                    // Recalculate height when width changes (orientation change)
                    let height = calculateDynamicHeight()
                    cachedHeight = height
                    reportedHeight = height
                }
            }
        }
        
        let styledGridArea = gridArea
            .animation(Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.1), value: buttons.count)
            .animation(Animation.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.05), value: isEditing)
            .animation(Animation.spring(response: 0.4, dampingFraction: 0.8), value: isCollapsed)
            .animation(Animation.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.05), value: cachedHeight)
            .onChange(of: isEditing) { _, newValue in
                if !newValue {
                    // fully reset drag/drop when leaving edit
                    clearDragState(reason: "onChange - leaving edit mode")
                }
            }
            .onAppear {
                let height = calculateDynamicHeight()
                cachedHeight = height
                reportedHeight = height
            }
            .onChange(of: buttons.count) { _, _ in
                let height = calculateDynamicHeight()
                cachedHeight = height
                reportedHeight = height
            }
            .onChange(of: isCollapsed) { _, _ in
                let height = calculateDynamicHeight()
                cachedHeight = height
                reportedHeight = height
            }
        
        let gridWithLifecycle = styledGridArea
                .onAppear {
                // Auto-assign positions on first load - call immediately since onAppear is safe
                    autoAssignGridPositions()
                }
            .onChange(of: buttons.count) { _, newCount in
                debugPrint("🔄 buttons.count changed to \(newCount) - dragging: \(dragging?.title ?? "none"), isDragOperation: \(isDragOperation)")

                // Auto-unfold when control area becomes empty
                if newCount == 0 && isCollapsed {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isCollapsed = false
                    }
                }

                // Only auto-assign when buttons are actually added/removed, not during drag operations
                // Also avoid auto-assign shortly after a drop to prevent position interference
                let timeSinceLastDrop = Date().timeIntervalSince(lastDropTime)
                if dragging == nil && !isDragOperation && timeSinceLastDrop > 0.5 && !isAutoAssigning {
                    // Auto-assign positions when buttons are added/removed (deferred to avoid state modification warnings)
                    DispatchQueue.main.async {
                        debugPrint("🔧 Auto-assigning positions due to button count change (new count: \(newCount))")
                        self.isAutoAssigning = true
                        autoAssignGridPositions()
                        self.isAutoAssigning = false
                    }
                } else {
                    let reason = dragging != nil ? "dragging in progress" :
                                isDragOperation ? "drag operation flag set" :
                                isAutoAssigning ? "auto-assign already in progress" :
                                "recent drop (time since: \(String(format: "%.2f", timeSinceLastDrop))s)"
                    debugPrint("⏭️ Skipping auto-assign: \(reason)")
                }
                }
                .onChange(of: dragging) { _, newValue in
                    debugPrint("🔄 dragging state changed → \(newValue?.title ?? "nil")")
                    // If dragging ended without going through performDrop, clean up state
                    if newValue == nil {
                        isDragOperation = false
                        // Use a small delay to allow performDrop to complete first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if dragging == nil && previewLocation != nil {
                                debugPrint("🧹 Fallback cleanup - clearing lingering preview")
                                previewLocation = nil
                                dropSurfaceElevated = false
                            }
                        }
                    }
                }
                .onChange(of: previewLocation) { _, newValue in
                    debugPrint("🔄 Preview location changed: \(newValue?.col ?? -1),\(newValue?.row ?? -1)")
                }
                .onChange(of: dragging?.id) { _, _ in
                    // Update displacement cache when drag state changes
                    updateDisplacementCache()
                }
                .onChange(of: previewLocation) { _, _ in
                    // Update displacement cache when preview location changes
                    updateDisplacementCache()
                }

        return VStack(spacing: 0) {
            headerView
            gridWithLifecycle
        }
        .background(Color(UIColor.systemGray6))
        .onChange(of: isEditing) { _, editing in
            // Reset drag/drop state when toggling edit mode to avoid stale state
            clearDragState(reason: "edit mode toggle")
        }
    }
    
    // Treat empty as collapsed (when not editing)
    private var effectivelyCollapsed: Bool {
        return isCollapsed || (buttons.isEmpty && !isEditing)
    }

    // Calculate dynamic height without needing GeometryProxy
    private func calculateDynamicHeight() -> CGFloat {
        // Use tracked actual width instead of screen bounds for proper orientation handling
        let height = calculateControlAreaHeight(proxy: nil, screenWidth: actualWidth)
        // Removed verbose height calculation logs for cleaner testing
        return height
    }
    
    // Calculate the height needed for the control area
    private func calculateControlAreaHeight(proxy: GeometryProxy?, screenWidth: CGFloat? = nil) -> CGFloat {
        // Calculate grid dimensions following the specification
        // Use appropriate default width based on orientation
        let isLandscape = verticalSizeClass == .compact
        let defaultWidth: CGFloat = isLandscape ? 1200 : 800
        let width: CGFloat = proxy?.size.width ?? screenWidth ?? defaultWidth
        let totalSpacing = CGFloat(columns - 1) * columnSpacing
        let availableWidth = width - (2 * gridPadding) - totalSpacing
        let cellSize = floor(availableWidth / CGFloat(columns))
        
        // Ensure minimum cell size in landscape to prevent cutoff
        let minCellSize: CGFloat = isLandscape ? 80 : 60
        let adjustedCellSize = max(cellSize, minCellSize)
        
        // Determine rows based on mode and orientation
        let rows: Int
        
        // Unified approach: Both orientations use dynamic height with 4-row maximum
        if isEditing {
            // Edit mode: Always show full 4-row editing canvas
            rows = 4
            // Removed verbose height calculation logs for cleaner testing
        } else {
            // Non-edit mode: Dynamic based on occupied buttons, capped at 4 rows
            let visualRows = calculateVisualRows()
            if visualRows == 0 && buttons.isEmpty {
                // Special case: no buttons = header-only height (same as collapsed)
                let headerOnlyHeight: CGFloat = 44  // Same as collapsed state
                // Removed verbose height calculation logs for cleaner testing
                return headerOnlyHeight
            }
            rows = min(4, max(0, visualRows))
            // Removed verbose height calculation logs for cleaner testing
        }
        
        // Convert rows to pixels
        let verticalGaps = max(0, rows - 1)
        let gridHeight = CGFloat(rows) * adjustedCellSize + CGFloat(verticalGaps) * rowSpacing
        
        // Add extra padding in landscape to prevent cutoff and provide breathing room
        let extraPadding: CGFloat = isLandscape ? 30 : 0
        let finalHeight = gridHeight + (2 * gridPadding) + extraPadding
        
        // Removed verbose height calculation logs for cleaner testing
        return finalHeight
    }
    
    // Calculate visual rows based on actual control positions and sizes
    private func calculateVisualRows() -> Int {
        guard !buttons.isEmpty else { 
            // Removed verbose height calculation logs for cleaner testing
            return 0  // Will be handled specially in height calculation
        }
        
        // Don't call autoAssignGridPositions during view updates to avoid state modification warnings
        // Instead, just calculate based on current positions, defaulting to row 0 if not set
        
        var maxEndRow = 0
        // Removed verbose height calculation logs for cleaner testing
        for button in buttons {
            let row = button.gridRow ?? 0  // Default to row 0 if not assigned yet
            // Use button.gridHeight to get the correct height based on orientation
            let height = button.gridHeight
            let endRow = row + height
            maxEndRow = max(maxEndRow, endRow)
            // Removed verbose height calculation logs for cleaner testing
        }
        
        let result = maxEndRow  // Allow 0 rows for minimal height when no buttons
        // Removed verbose height calculation logs for cleaner testing
        return result
    }
    
    // Legacy function kept for compatibility
    private func calculateOccupiedRows() -> Int {
        return calculateVisualRows()
    }
    
    // Auto-assign grid positions for controls that don't have them
    private func autoAssignGridPositions() {
        debugPrint("🔧 autoAssignGridPositions called - checking \(buttons.count) buttons")
        var needsUpdate = false
        var updates: [(Int, Int, Int)] = [] // (index, col, row)
        var occupiedPositions: Set<String> = [] // Track occupied positions as "col,row"
        
        // First, record all existing positions to avoid conflicts
        for button in buttons {
            if let col = button.gridCol, let row = button.gridRow {
                let width = button.gridWidth
                let height = button.gridHeight
                
                // Mark all cells occupied by this button
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }
        
        for i in 0..<buttons.count {
            // Only assign if not already set - don't override user-placed positions
            let needsPosition = buttons[i].gridCol == nil || buttons[i].gridRow == nil
            
            debugPrint("🔍 Button \(buttons[i].title): needsPosition=\(needsPosition), current=(\(buttons[i].gridCol ?? -1), \(buttons[i].gridRow ?? -1))")
            
            if needsPosition {
                if let position = findFirstAvailablePositionAvoidingOccupied(for: buttons[i], occupied: occupiedPositions) {
                    updates.append((i, position.col, position.row))
                    needsUpdate = true

                    // Update occupied positions for next iteration
                    let width = buttons[i].gridWidth
                    let height = buttons[i].gridHeight
                    for c in position.col..<(position.col + width) {
                        for r in position.row..<(position.row + height) {
                            occupiedPositions.insert("\(c),\(r)")
                        }
                    }
                    
                    debugPrint("📍 Will auto-assign \(buttons[i].title) to (\(position.col), \(position.row))")
                } else {
                    // Fallback: place at bottom in first available column
                    let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
                    let fallbackRow = maxRow + 2 // Give some space
                    updates.append((i, 0, fallbackRow))
                    needsUpdate = true
                    debugPrint("📍 Will fallback assign \(buttons[i].title) to (0, \(fallbackRow))")
                }
            }
        }
        
        // Apply updates on next run loop to avoid "modifying state during view update"
        if needsUpdate {
            DispatchQueue.main.async {
                for (index, col, row) in updates {
                    if index < self.buttons.count {
                        self.buttons[index].gridCol = col
                        self.buttons[index].gridRow = row
                        debugPrint("✅ Applied position for \(self.buttons[index].title): (\(col), \(row))")
                    }
                }
            }
        }
    }
    
    // Check if a button overlaps with any other buttons
    private func checkForOverlap(button: ControlButton, excluding excludeIds: [UUID]) -> Bool {
        guard let col = button.gridCol, let row = button.gridRow else { return false }

        let width = button.gridWidth
        let height = button.gridHeight
        let buttonRect = GridRect(col: col, row: row, width: width, height: height)
        
        let hasOverlap = hasOverlapExcluding(buttonRect, excluding: excludeIds)
        if hasOverlap {
            debugPrint("🔍 Overlap detected for \(button.title) at (\(col), \(row)) size \(width)x\(height)")
        }
        return hasOverlap
    }
    
    // Find first available position avoiding already occupied positions
    private func findFirstAvailablePositionAvoidingOccupied(for control: ControlButton, occupied: Set<String>) -> (col: Int, row: Int)? {
        let width = control.gridWidth
        let height = control.gridHeight
        let maxSearchRows = 4 // Reasonable limit
        
        debugPrint("🔍 Finding position for \(control.title) (fader: \(control.isFader == true), size: \(width)x\(height))")
        
        // Search from top-left to bottom-right
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                var canPlace = true
                
                // Check if all required cells are free
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        if occupied.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }
                
                if canPlace {
                    return (col, row)
                }
            }
        }
        return nil
    }
    
    // Find the first available position for a control (top-left to bottom-right priority)
    private func findFirstAvailablePosition(for control: ControlButton) -> (col: Int, row: Int)? {
        let width = control.gridWidth
        let height = control.gridHeight
        let maxSearchRows = 4
        
        debugPrint("🔍 Finding position for \(control.isFader == true ? "fader" : "button"): \(control.title) (size: \(width)x\(height))")
        
        // Search from top-left to bottom-right
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                let hasOverlap = hasOverlapExcluding(testRect, excluding: [control.id])
                debugPrint("🔍 Testing position (\(col), \(row)): overlap=\(hasOverlap)")
                if !hasOverlap {
                    debugPrint("✅ Found position for \(control.title): (\(col), \(row))")
                    return (col, row)
                }
            }
        }
        debugPrint("❌ No position found for \(control.title)")
        return nil
    }

    // Compute effective position for live displacement preview during drag
    private func effectivePosition(
        for button: ControlButton,
        dragging: ControlButton?,
        preview: GridPosition?,
        columns: Int
    ) -> (col: Int, row: Int) {
        let baseCol = button.gridCol ?? 0
        let baseRow = button.gridRow ?? 0
        guard let dragging = dragging, let preview = preview else {
            return (baseCol, baseRow)
        }

        // If this IS the dragged button, keep it at its original position
        // The dragTranslation offset will handle the visual movement
        if dragging.id == button.id {
            return (baseCol, baseRow)
        }

        // PERFORMANCE FIX: Generate cache key for current drag state
        let cacheKey = "\(dragging.id)_\(preview.col)_\(preview.row)"

        // PERFORMANCE FIX: Check if we need to rebuild cache (but don't modify state here!)
        // If cache is stale, compute on-the-fly. Cache will be updated via onChange modifier.
        if displacementCacheKey != cacheKey {
            // Cache is stale - compute directly without modifying state
            let result = computeAllDisplacements(draggedButton: dragging, targetPosition: preview, columns: columns)
            return result.displacements[button.id] ?? (baseCol, baseRow)
        }

        // PERFORMANCE FIX: Use cached result (O(1) lookup instead of O(n) computation)
        if let cachedPos = displacementCache[button.id] {
            return cachedPos
        }

        return (baseCol, baseRow)
    }

    // PERFORMANCE FIX: Compute all displacement positions at once (called once per preview location change)
    private func computeAllDisplacements(draggedButton: ControlButton, targetPosition: GridPosition, columns: Int) -> (displacements: [UUID: (col: Int, row: Int)], hasInvalidDisplacement: Bool) {
        var result: [UUID: (col: Int, row: Int)] = [:]
        var hasInvalidDisplacement = false

        let draggedW = draggedButton.gridWidth
        let draggedH = draggedButton.gridHeight
        let draggedButtonShadow = GridRect(col: targetPosition.col, row: targetPosition.row, width: draggedW, height: draggedH)

        // Build occupancy map once for all buttons
        var occupiedPositions: Set<String> = []

        // Mark the dragged button's new position as occupied
        for c in targetPosition.col..<(targetPosition.col + draggedW) {
            for r in targetPosition.row..<(targetPosition.row + draggedH) {
                occupiedPositions.insert("\(c),\(r)")
            }
        }

        // Mark all existing button positions as occupied (excluding dragged button)
        for otherButton in buttons {
            if otherButton.id == draggedButton.id { continue }

            if let col = otherButton.gridCol, let row = otherButton.gridRow {
                let width = otherButton.gridWidth
                let height = otherButton.gridHeight
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }

        // Now compute displacement for each button that overlaps
        for button in buttons {
            if button.id == draggedButton.id { continue }

            let baseCol = button.gridCol ?? 0
            let baseRow = button.gridRow ?? 0
            let buttonRect = GridRect(col: baseCol, row: baseRow, width: button.gridWidth, height: button.gridHeight)

            if rectsOverlap(buttonRect, draggedButtonShadow) {
                // This button needs to move - calculate its new position
                let newPos = calculateDisplacementPosition(
                    for: button,
                    draggedButton: draggedButton,
                    targetPosition: targetPosition,
                    columns: columns,
                    occupiedPositions: occupiedPositions
                )

                if let validPos = newPos {
                    result[button.id] = validPos
                } else {
                    // No valid position found - keep button in original position and mark as invalid
                    hasInvalidDisplacement = true
                    result[button.id] = (baseCol, baseRow)
                }
            }
        }

        return (displacements: result, hasInvalidDisplacement: hasInvalidDisplacement)
    }
    
    // PERFORMANCE FIX: Calculate displacement position using pre-computed occupancy map
    private func calculateDisplacementPosition(
        for button: ControlButton,
        draggedButton: ControlButton,
        targetPosition: GridPosition,
        columns: Int,
        occupiedPositions: Set<String>
    ) -> (col: Int, row: Int)? {
        let buttonW = button.gridWidth
        let buttonH = button.gridHeight
        let draggedOriginalCol = draggedButton.gridCol ?? 0
        let draggedOriginalRow = draggedButton.gridRow ?? 0

        // Create a mutable copy to track positions occupied by other displaced buttons
        var mutableOccupied = occupiedPositions

        // Remove this button's current position from occupancy check
        if let col = button.gridCol, let row = button.gridRow {
            for c in col..<(col + buttonW) {
                for r in row..<(row + buttonH) {
                    mutableOccupied.remove("\(c),\(r)")
                }
            }
        }

        // iPhone-like smart positioning: try positions in order of preference
        // 1. Try swapping with dragged button's original position first (simple swap)

        if draggedOriginalCol + buttonW <= columns {
            var canSwap = true
            for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                    if occupiedPositions.contains("\(c),\(r)") {
                        canSwap = false
                        break
                    }
                }
                if !canSwap { break }
            }

            if canSwap {
                return (draggedOriginalCol, draggedOriginalRow)
            }
        }

        // 2. Try moving right first (same row, next column) - iPhone behavior
        let originalCol = button.gridCol ?? 0
        let originalRow = button.gridRow ?? 0
        let rightCol = originalCol + 1

        if rightCol + buttonW <= columns {
            var canMoveRight = true
            for c in rightCol..<(rightCol + buttonW) {
                for r in originalRow..<(originalRow + buttonH) {
                    if occupiedPositions.contains("\(c),\(r)") {
                        canMoveRight = false
                        break
                    }
                }
                if !canMoveRight { break }
            }

            if canMoveRight {
                return (rightCol, originalRow)
            }
        }

        // 3. Try moving down and left (cascade to next row) - iPhone behavior
        let nextRow = originalRow + 1
        if nextRow + buttonH <= 4 { // max rows check
            for col in 0...(columns - buttonW) {
                var canPlace = true
                for c in col..<(col + buttonW) {
                    for r in nextRow..<(nextRow + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, nextRow)
                }
            }
        }

        // 4. Fallback: find the next available position (top-left to bottom-right)
        let maxRows = 4
        for row in 0..<maxRows {
            for col in 0...(columns - buttonW) {
                var canPlace = true
                for c in col..<(col + buttonW) {
                    for r in row..<(row + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, row)
                }
            }
        }

        // No valid position found - return nil to signal "no space available"
        return nil
    }
    
    // Commit positions for all buttons that were displaced during the drag
    private func commitDisplacedButtonPositions(draggedButton: ControlButton, targetPosition: GridPosition) {
        let draggedW = draggedButton.gridWidth
        let draggedH = draggedButton.gridHeight
        let draggedButtonShadow = GridRect(col: targetPosition.col, row: targetPosition.row, width: draggedW, height: draggedH)
        
        // Find all buttons that were displaced
        var displacedButtons: [(Int, ControlButton)] = []
        for i in 0..<buttons.count {
            let button = buttons[i]
            if button.id == draggedButton.id { continue } // Skip the dragged button
            
            let buttonRect = GridRect(
                col: button.gridCol ?? 0,
                row: button.gridRow ?? 0,
                width: button.gridWidth,
                height: button.gridHeight
            )
            
            // If this button was displaced (overlapped with the dragged button's shadow)
            if rectsOverlap(buttonRect, draggedButtonShadow) {
                displacedButtons.append((i, button))
            }
        }
        
        // Assign unique positions to displaced buttons
        var occupiedPositions: Set<String> = []
        
        // First, mark the dragged button's new position as occupied
        for c in targetPosition.col..<(targetPosition.col + draggedW) {
            for r in targetPosition.row..<(targetPosition.row + draggedH) {
                occupiedPositions.insert("\(c),\(r)")
            }
        }
        
        // Mark all existing button positions as occupied (excluding displaced buttons)
        for i in 0..<buttons.count {
            let button = buttons[i]
            if button.id == draggedButton.id { continue }
            if displacedButtons.contains(where: { $0.1.id == button.id }) { continue }
            
            if let col = button.gridCol, let row = button.gridRow {
                let width = button.gridWidth
                let height = button.gridHeight
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }
        
        // Assign unique positions to displaced buttons
        for (index, button) in displacedButtons {
            let buttonW = button.gridWidth
            let buttonH = button.gridHeight
            
            // Try swapping with dragged button's original position first
            let draggedOriginalCol = draggedButton.gridCol ?? 0
            let draggedOriginalRow = draggedButton.gridRow ?? 0
            
            var foundPosition = false
            if draggedOriginalCol + buttonW <= columns {
                var canSwap = true
                for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                    for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canSwap = false
                            break
                        }
                    }
                    if !canSwap { break }
                }
                
                if canSwap {
                    buttons[index].gridCol = draggedOriginalCol
                    buttons[index].gridRow = draggedOriginalRow
                    foundPosition = true
                    debugPrint("🔄 Committed displaced button \(button.title) to swapped position (\(draggedOriginalCol), \(draggedOriginalRow))")
                    
                    // Mark this position as occupied
                    for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                        for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                            occupiedPositions.insert("\(c),\(r)")
                        }
                    }
                }
            }
            
            // If swap didn't work, find the next available position
            if !foundPosition {
                let maxRows = 4
                for row in 0..<maxRows {
                    for col in 0...(columns - buttonW) {
                        var canPlace = true
                        for c in col..<(col + buttonW) {
                            for r in row..<(row + buttonH) {
                                if occupiedPositions.contains("\(c),\(r)") {
                                    canPlace = false
                                    break
                                }
                            }
                            if !canPlace { break }
                        }
                        
                        if canPlace {
                            buttons[index].gridCol = col
                            buttons[index].gridRow = row
                            foundPosition = true
                            debugPrint("🔄 Committed displaced button \(button.title) to (\(col), \(row))")
                            
                            // Mark this position as occupied
                            for c in col..<(col + buttonW) {
                                for r in row..<(row + buttonH) {
                                    occupiedPositions.insert("\(c),\(r)")
                                }
                            }
                            break
                        }
                    }
                    if foundPosition { break }
                }
            }
            
            // Fallback if no position found
            if !foundPosition {
                let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
                buttons[index].gridCol = 0
                buttons[index].gridRow = maxRow + 2
                debugPrint("🔄 Committed displaced button \(button.title) to fallback position (0, \(maxRow + 2))")
            }
        }
    }
    
    // Find displacement position for a button, ensuring no conflicts with other displaced buttons
    private func findDisplacementPosition(for button: ControlButton, draggedButton: ControlButton, columns: Int) -> (col: Int, row: Int) {
        let buttonW = button.gridWidth
        let buttonH = button.gridHeight
        
        // First try swapping with the dragged button's original position
        let draggedOriginalCol = draggedButton.gridCol ?? 0
        let draggedOriginalRow = draggedButton.gridRow ?? 0
        let draggedOriginalRect = GridRect(col: draggedOriginalCol, row: draggedOriginalRow, width: buttonW, height: buttonH)
        
        if draggedOriginalCol + buttonW <= columns && !hasOverlapExcluding(draggedOriginalRect, excluding: [draggedButton.id, button.id]) {
            return (draggedOriginalCol, draggedOriginalRow)
        }
        
        // Find a unique position by using the button's index as a seed
        let buttonIndex = buttons.firstIndex(where: { $0.id == button.id }) ?? 0
        let maxRows = 4
        
        // Try positions in a deterministic order based on button index
        // Start the search from a different position based on button index to ensure uniqueness
        let startOffset = buttonIndex * 3 // Use button index to offset the search
        for offset in startOffset..<(maxRows * columns + startOffset) {
            let actualOffset = offset % (maxRows * columns)
            let row = actualOffset / columns
            let col = actualOffset % columns
            
            // Skip if this position would go out of bounds
            if col + buttonW > columns || row + buttonH > maxRows {
                continue
            }
            
            let testRect = GridRect(col: col, row: row, width: buttonW, height: buttonH)
            
            // Check if this position is available (excluding dragged button and this button)
            if !hasOverlapExcluding(testRect, excluding: [draggedButton.id, button.id]) {
                return (col, row)
            }
        }
        
        // Fallback: place at bottom
        let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
        return (0, maxRow + 2)
    }

    // Visual-only overlap helpers for live displacement preview
    private func rectsOverlap(_ rect1: GridRect, _ rect2: GridRect) -> Bool {
        return !(rect1.col + rect1.width <= rect2.col ||
                 rect2.col + rect2.width <= rect1.col ||
                 rect1.row + rect1.height <= rect2.row ||
                 rect2.row + rect2.height <= rect1.row)
    }

    private func hasOverlap(_ rect: GridRect) -> Bool {
        for item in buttons {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }

    private func hasOverlapExcluding(_ rect: GridRect, excluding excludeIds: [UUID]) -> Bool {
        for item in buttons {
            guard let col = item.gridCol, let row = item.gridRow, !excludeIds.contains(item.id) else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }

    private func findFreePositionVisual(for item: ControlButton, columns: Int, excluding excludeIds: [UUID] = []) -> (col: Int, row: Int)? {
        let width = item.gridWidth
        let height = item.gridHeight
        let maxSearchRows = 4 // Increased search area
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let test = GridRect(col: col, row: row, width: width, height: height)
                if !hasOverlapExcluding(test, excluding: excludeIds) {
                    return (col, row)
                }
            }
        }
        return nil
    }

    // Find the nearest available position for a button to move to, avoiding the dragged button's shadow
    private func findNearestAvailablePosition(
        for button: ControlButton,
        avoiding draggedButtonShadow: GridRect,
        maxRows: Int,
        columns: Int
    ) -> GridPosition? {
        let buttonWidth = button.gridWidth
        let buttonHeight = button.gridHeight
        
        // Start with the current position
        let currentPos = GridPosition(col: button.gridCol ?? 0, row: button.gridRow ?? 0)
        
        // If current position doesn't overlap with shadow, keep it
        let currentRect = GridRect(col: currentPos.col, row: currentPos.row, width: buttonWidth, height: buttonHeight)
        if !rectsOverlap(currentRect, draggedButtonShadow) {
            return currentPos
        }
        
        // Search in expanding rings around the current position
        let maxSearchRadius = max(maxRows, columns)
        
        for radius in 1...maxSearchRadius {
            // Check positions at this radius
            for dx in -radius...radius {
                for dy in -radius...radius {
                    // Only check positions at the current radius (on the perimeter)
                    if abs(dx) != radius && abs(dy) != radius { continue }
                    
                    let newCol = currentPos.col + dx
                    let newRow = currentPos.row + dy
                    
                    // Check bounds
                    if newCol < 0 || newRow < 0 || 
                       newCol + buttonWidth > columns || 
                       newRow + buttonHeight > maxRows {
                        continue
                    }
                    
                    let candidateRect = GridRect(col: newCol, row: newRow, width: buttonWidth, height: buttonHeight)
                    
                    // Check if this position avoids the shadow and doesn't overlap with other buttons
                    if !rectsOverlap(candidateRect, draggedButtonShadow) && 
                       !hasOverlapExcluding(candidateRect, excluding: [button.id]) {
                        return GridPosition(col: newCol, row: newRow)
                    }
                }
            }
        }
        
        return nil // No available position found
    }

    // Check if a specific grid cell is occupied by any button (excluding currently dragged button)
    private func isCellOccupied(col: Int, row: Int) -> Bool {
        for button in buttons {
            // Skip the button that's currently being dragged
            if let draggedButton = dragging, draggedButton.id == button.id {
                continue
            }
            
            guard let buttonCol = button.gridCol, let buttonRow = button.gridRow else { continue }

            // Get button dimensions
            let buttonWidth = button.gridWidth
            let buttonHeight = button.gridHeight
            
            // Check if the cell (col, row) is within the button's area
            if col >= buttonCol && col < buttonCol + buttonWidth &&
               row >= buttonRow && row < buttonRow + buttonHeight {
                return true
            }
        }
        return false
    }

    // Count rows using a dynamic packing heuristic matching layout
    private func occupiedRows(columns: Int) -> Int {
        guard !buttons.isEmpty else { return 1 }
        
        var occupancy: [[Bool]] = []
        func ensureRows(_ r: Int) {
            while occupancy.count <= r { occupancy.append(Array(repeating: false, count: columns)) }
        }
        
        func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            ensureRows(r + h)
            if c + w > columns { return false }
            for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
            return true
        }
        
        func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) {
            ensureRows(r + h)
            for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } }
        }
        
        // First: place controls with explicit positions
        var explicitlyPlaced = Set<UUID>()
        for b in buttons {
            let w = b.gridWidth
            let h = b.gridHeight
            if let gridCol = b.gridCol, let gridRow = b.gridRow,
               gridCol >= 0, gridRow >= 0, fits(gridRow, gridCol, w, h) {
                mark(gridRow, gridCol, w, h)
                explicitlyPlaced.insert(b.id)
            }
        }
        
        // Then: place remaining controls with auto-packing
        for b in buttons where !explicitlyPlaced.contains(b.id) {
            let w = b.gridWidth
            let h = b.gridHeight
            var placed = false
            var r = 0
            while !placed {
                for c in 0..<columns {
                    if fits(r, c, w, h) {
                        mark(r, c, w, h)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }
        
        var lastUsed = 0
        for (i, row) in occupancy.enumerated() { 
            if row.contains(true) { lastUsed = i + 1 } 
        }
        return max(1, lastUsed)
    }
    
    // Compute packed rows consistent with non-edit portrait packed layout
    private func packedVisualRows() -> Int {
        let positions = computePackedPositions(for: buttons)
        var maxRow = 0
        for b in buttons {
            let pos = positions[b.id]
            let row = pos?.row ?? (b.gridRow ?? 0)
            let height = b.gridHeight
            maxRow = max(maxRow, row + height)
        }
        return max(1, maxRow)
    }
    
    // Helper function to build individual control tile (extracted from ForEach for type-checking performance)
    @ViewBuilder
    private func buildControlTileView(button: ControlButton, cellSize: CGFloat, columnSpacing: CGFloat, rowSpacing: CGFloat, conflictFor: [MIDIKey: String], isEditing: Bool, maxRows: Int, usbServer: ConnectionManager, wifiClient: BridgeOutput, connectionCoordinator: ConnectionCoordinator, controlButtons: Binding<[ControlButton]>, markDirty: @escaping () -> Void) -> some View {
        let width = CGFloat(button.gridWidth) * cellSize + CGFloat(max(0, button.gridWidth - 1)) * columnSpacing
        let height = CGFloat(button.gridHeight) * cellSize + CGFloat(max(0, button.gridHeight - 1)) * rowSpacing

        let pos: (col: Int, row: Int) = effectivePosition(for: button, dragging: dragging, preview: previewLocation, columns: columns)
                let x = CGFloat(pos.col) * (cellSize + columnSpacing)
                let y = CGFloat(pos.row) * (cellSize + rowSpacing)
                let key = MIDIKey(kind: button.kind, channel: button.channel, number: button.number)
                let owner = conflictFor[key]

                iPadControlTile(
                    button: button,
                    takenBy: (owner != nil && owner != button.title) ? owner : nil,
                    isEditing: isEditing,
                    isDragging: dragging?.id == button.id,
                    onTap: { onTap(button) },
                    onEdit: { onEditButton(button) },
                    onDelete: { onDelete(button) },
                    onDrag: {
                        // Keep the old system for compatibility, but we'll add smooth gesture on top
                        guard isEditing else { return NSItemProvider() }
                        return NSItemProvider(object: button.id.uuidString as NSString)
                    },
                    onFaderMIDI: { channel, cc, value, title, buttonID in
                        // Store the fader value in the ControlButton model for persistence
                        if let index = controlButtons.wrappedValue.firstIndex(where: { $0.id == buttonID }) {
                            let faderValue = Double(value) / 127.0
                            controlButtons.wrappedValue[index].faderValue = faderValue
                            markDirty() // Mark project as dirty to save the fader value
                            debugPrint("🎚️ onFaderMIDI: Stored fader value \(faderValue) for \"\(title)\"")
                        }
                        
                        // Use ConnectionCoordinator to send MIDI through the active connection
                        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
                    }
                )
                .id("\(button.id.uuidString)-\(isEditing)")
                .frame(width: width, height: height)
                .offset(
                    x: x + (dragging?.id == button.id ? dragTranslation.width : 0), 
                    y: y + (dragging?.id == button.id ? dragTranslation.height : 0)
                )
                .scaleEffect(dragging?.id == button.id ? 1.1 : 1.0) // iOS-style scale during drag
                // Enable smooth spring animations for buttons moving out of the way (iPhone-like)
                .animation(
                    dragging?.id == button.id ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                    value: x
                )
                .animation(
                    dragging?.id == button.id ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                    value: y
                )
                .animation(.easeInOut(duration: 0.15), value: dragging?.id == button.id) // Smooth scale animation
                .allowsHitTesting(true)
                .simultaneousGesture(
                    isEditing ?
                    DragGesture(minimumDistance: 10, coordinateSpace: .global)
                        .onChanged { value in
                            if dragging?.id != button.id {
                                // Start iOS-style drag
                                isDragOperation = true
                        dragging = button
                        dropSurfaceElevated = true
                                dragStartLocation = value.startLocation
                                previewLocation = nil
                            }
                            
                            if dragging?.id == button.id {
                                // Follow finger exactly - no constraints or modifications
                                let dx = value.translation.width
                                let dy = value.translation.height
                                
                                // Update dragged device position - this should follow finger exactly
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    dragTranslation = CGSize(width: dx, height: dy)
                                }
                                
                                // Calculate shadow position independently - this snaps to grid
                                let currentCol = button.gridCol ?? 0
                                let currentRow = button.gridRow ?? 0

                                let targetWidth = button.gridWidth
                                let targetHeight = button.gridHeight
                                
                                // Calculate target grid position based on drag distance
                                let cellsMovedX = Int((dx / (cellSize + columnSpacing)).rounded())
                                let cellsMovedY = Int((dy / (cellSize + rowSpacing)).rounded())
                                
                                // Calculate target position
                                let targetCol = currentCol + cellsMovedX
                                let targetRow = currentRow + cellsMovedY
                                
                                // Clamp to valid grid boundaries
                                let shadowCol = max(0, min(targetCol, columns - targetWidth))
                                let shadowRow = max(0, min(targetRow, maxRows - targetHeight))
                                
                                // Always update preview location for live displacement preview
                                // This allows other buttons to move out of the way in real-time
                                let newShadowPos = GridPosition(col: shadowCol, row: shadowRow)
                                if previewLocation?.col != shadowCol || previewLocation?.row != shadowRow {
                                    previewLocation = newShadowPos
                                }
                                
                                // Store shadow offset separately - this is for visual shadow positioning only
                                shadowOffset = CGSize(width: dx, height: dy)
                            }
                        }
                        .onEnded { value in
                            guard dragging?.id == button.id else { return }
                            
                            // Snap to grid position like iOS home screen
                            if let preview = previewLocation {
                                // Commit the dragged button's position
                                if let buttonIndex = buttons.firstIndex(where: { $0.id == button.id }) {
                                    buttons[buttonIndex].gridCol = preview.col
                                    buttons[buttonIndex].gridRow = preview.row
                                    lastDropTime = Date()
                                    debugPrint("✅ Drop successful at (\(preview.col), \(preview.row))")
                                }
                                
                                // Commit positions for all displaced buttons
                                self.commitDisplacedButtonPositions(draggedButton: button, targetPosition: preview)
                            }
                            
                            // Clear drag state after drop is processed
                            clearDragState(reason: "iOS-style drag completed")
                        }
                    : nil
                )
                .zIndex(1)
            }

    // Helper function to compute packed positions (moved outside ViewBuilder)
    private func computePackedPositions(for buttons: [ControlButton]) -> [UUID: (col: Int, row: Int)] {
        let isPortraitLike = verticalSizeClass != .compact
        guard !isEditing && isPortraitLike else { return [:] }
        
        var occupancy: [[Bool]] = []
        var packedPositions: [UUID: (col: Int, row: Int)] = [:]
        
        func ensureRows(_ r: Int) {
            while occupancy.count <= r { occupancy.append(Array(repeating: false, count: columns)) }
        }
        func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            ensureRows(r + h)
            if c + w > columns { return false }
            for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
            return true
        }
        func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) { for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } } }
        
        for b in buttons {
            let w = b.gridWidth
            let h = b.gridHeight
            var placed = false
            var r = 0
            while !placed {
                ensureRows(r + h)
                for c in 0...(columns - w) {
                    if fits(r, c, w, h) {
                        mark(r, c, w, h)
                        packedPositions[b.id] = (c, r)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }
        
        return packedPositions
    }
    
    // Helper to calculate grid parameters
    private func calculateGridParameters(proxy: GeometryProxy) -> (cellSize: CGFloat, displayRows: Int, gridHeight: CGFloat, gridWidth: CGFloat) {
        // Calculate grid dimensions using same logic as height calculation
        let totalSpacing = CGFloat(columns - 1) * columnSpacing
        let availableWidth = proxy.size.width - (2 * gridPadding) - totalSpacing
        let cellSize = floor(availableWidth / CGFloat(columns))
        
        // Determine rows based on mode and orientation (same as height calculation)
        let displayRows: Int
        
        // Unified approach: Both orientations use dynamic height with 4-row maximum
            if isEditing {
            // Edit mode: Always show full 4-row editing canvas
            displayRows = 4
        } else {
            // Non-edit mode: Dynamic based on occupied buttons, capped at 4 rows
            let visualRows = calculateVisualRows()
            displayRows = min(4, max(0, visualRows))
        }
        
        let verticalGaps = max(0, displayRows - 1)
        let gridHeight = CGFloat(displayRows) * cellSize + CGFloat(verticalGaps) * rowSpacing
        let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing
        
        return (cellSize: cellSize, displayRows: displayRows, gridHeight: gridHeight, gridWidth: gridWidth)
    }
    
    private func buildControlGrid(proxy: GeometryProxy, isCtrlEditing: Bool, sessionNonce: Int, usbServer: ConnectionManager, wifiClient: BridgeOutput, connectionCoordinator: ConnectionCoordinator) -> AnyView {
        let params = calculateGridParameters(proxy: proxy)
        let cellSize = params.cellSize
        let displayRows = params.displayRows
        // let dropTypes: [UTType] = isCtrlEditing ? [UTType.text] : [] // Unused in new iOS-style drag system

        let buttonsSnapshot = buttons // break reference to avoid closure capturing stale binding
        let maxRows = displayRows // Capture for use in gesture closures
        let tilesCore = ForEach(buttonsSnapshot) { button in
            buildControlTileView(
                button: button,
                cellSize: cellSize,
                columnSpacing: columnSpacing,
                rowSpacing: rowSpacing,
                conflictFor: conflictFor,
                isEditing: isCtrlEditing,
                maxRows: maxRows,
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                controlButtons: $buttons,
                markDirty: markDirty
            )
        }
        let tiles: AnyView = AnyView(
            Group { tilesCore }
                .id("tiles-\(isCtrlEditing)")
        )

        let editOverlay: AnyView = {
            guard isCtrlEditing else { return AnyView(EmptyView()) }
            let overlayCells: [(Int, Int)] = (0..<displayRows).flatMap { row in
                (0..<columns).compactMap { col in
                    isCellOccupied(col: col, row: row) ? nil : (row, col)
                }
            }
            let overlay = ForEach(overlayCells.indices, id: \.self) { idx in
                let (row, col) = overlayCells[idx]
                        let x = CGFloat(col) * (cellSize + columnSpacing)
                        let y = CGFloat(row) * (cellSize + rowSpacing)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: cellSize, height: cellSize)
                            .offset(x: x, y: y)
                }
                .zIndex(0.5)
                .allowsHitTesting(false)
            return AnyView(overlay)
        }()

        let dragPreview: AnyView = {
            // iOS-style shadow: shows at TARGET grid position, not following finger
            guard let dragging = dragging, let preview = previewLocation else { return AnyView(EmptyView()) }
            let width = CGFloat(dragging.gridWidth) * cellSize + CGFloat(max(0, dragging.gridWidth - 1)) * columnSpacing
            let height = CGFloat(dragging.gridHeight) * cellSize + CGFloat(max(0, dragging.gridHeight - 1)) * rowSpacing
            
            // Simple shadow positioning - align exactly with grid cells
            let shadowX = CGFloat(preview.col) * (cellSize + columnSpacing)
            let shadowY = CGFloat(preview.row) * (cellSize + rowSpacing)
            
            // Choose shadow color based on whether displacement is valid
            let shadowColor = hasInvalidDisplacement ? Color.red : Color.blue

            let previewView = ZStack {
                // Shadow effect (blue if valid, red if no space available)
                RoundedRectangle(cornerRadius: 12)
                    .fill(shadowColor.opacity(0.2))
                    .blur(radius: 8)
                    .scaleEffect(1.1)

                // Main preview shape
                RoundedRectangle(cornerRadius: 12)
                    .fill(shadowColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(shadowColor, lineWidth: 3)
                    )
            }
                    .frame(width: width, height: height)
            .offset(x: shadowX, y: shadowY)
            .zIndex(2000)
                    .allowsHitTesting(false)
            .animation(nil, value: preview.col) // No animations to prevent grid movement
            .animation(nil, value: preview.row) // No animations to prevent grid movement
            return AnyView(previewView)
        }()
        
        let _ = iPadDropDelegate( // Unused in new iOS-style drag system
            columns: columns,
            columnSpacing: columnSpacing,
            rowSpacing: rowSpacing,
            cellSize: cellSize,
            displayRows: displayRows,
            buttons: $buttons,
            dragging: $dragging,
            previewLocation: $previewLocation,
            dropSurfaceElevated: $dropSurfaceElevated,
            isDragOperation: $isDragOperation,
            lastDropTime: $lastDropTime,
            isActive: isCtrlEditing,
            clearDragState: clearDragState
        )

        let content = ZStack(alignment: .topLeading) {
            // Controls positioned with simple offset (Mac editor approach)
            tiles
                .allowsHitTesting(true)

            // Dotted grid overlay in edit mode (Mac editor approach)
            editOverlay

            // Blue drag shadow preview
            dragPreview
        }
        .id("ctrl-container-\(isCtrlEditing)-sess-\(sessionNonce)-\(buttons.map { "\($0.gridCol ?? -1)-\($0.gridRow ?? -1)" }.joined(separator: ","))")
        .padding(EdgeInsets(top: gridPadding + 8, leading: gridPadding, bottom: gridPadding + (verticalSizeClass == .compact ? 10 : 0), trailing: gridPadding))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.3), value: displayRows)
        // .onDrop(of: [], delegate: dropDelegate) // Disabled old drop system in favor of smooth drag
        .allowsHitTesting(true)
        .onChange(of: sessionNonce) { _, _ in
            // Force complete state reset when session changes
            clearDragState(reason: "gesture cancelled")
    }
        
        return AnyView(content)
}

private struct ControlButtonTile: View {
    let button: ControlButton
    let takenBy: String?
    let isEditing: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var down = false
    @State private var wiggle = false

    // Wobble state - now uses shared animator
    @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
    @State private var wobbleID = UUID()

    var body: some View {
        ZStack {
            Button {
                    if isEditing { onEdit() } else { onTap() }
            } label: {
                VStack(spacing: 6) {
                        if button.symbol.isEmpty {
                            Text(button.title)
                                .font(.title3.weight(.semibold))
                        } else {
                    Image(systemName: button.symbol).font(.system(size: 24, weight: .semibold))
                    Text(button.title).font(.footnote.weight(.semibold))
                    Text(midiLabel())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        }
                }
                .foregroundColor(down ? .white : .primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(down ? Color.accentColor : Color.clear)
                        )
                )
                    .overlay(alignment: .topLeading) {
                    if isEditing {
                        Button(action: onDelete) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.85))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .offset(x: -1.5, y: -1.5)
                                }
                        }
                        .buttonStyle(.plain)
                            .padding(1)
                            .offset(x: -6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(takenBy != nil && !isEditing)
            .opacity(1.0)
            .modifier(PressEffectWhenNotEditing(isEditing: isEditing, onChange: { down = true }, onEnd: { down = false }))
            .scaleEffect((down && !isEditing) ? 0.97 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: down)
            .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
                .onChange(of: isEditing) { _, editing in
                    if editing { startWobble() } else { stopWobble(); down = false }
            }
            .onDisappear { stopWobble() }
            if let owner = takenBy, !isEditing {
                Text("Taken by: \(owner)")
                    .font(.caption2).padding(6)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    private func midiLabel() -> String {
        switch button.kind {
        case .cc:   return "\(button.channel)•\(button.number)"
        case .note: return "\(button.channel)•\(button.number)•\(button.velocity)"
        }
    }

    // MARK: - iPhone-style wobble implementation (using shared animator)
    private func startWobble() {
        guard isEditing else { return }

        // Generate unique wobble parameters for this tile (iPhone-like wobble)
        var rng = SeededRandom(seed: button.id.uuidString.hashValue)
        let amplitude = 1.2 + Double(rng.nextNormalized()) * 0.6 // ~1.2 ... 1.8 deg
        let scaleDelta = 0.003 + Double(rng.nextNormalized()) * 0.002 // ~0.3% ... 0.5%
        let interval = 0.16 + Double(rng.nextNormalized()) * 0.04 // ~0.16 ... 0.20s
        let initialDelay = Double(rng.nextNormalized()) * 0.2

        debugPrint("🔄 ControlButtonTile '\(button.title)': Starting wobble with wobbleID \(wobbleID.uuidString.prefix(8))...")
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            guard self.isEditing else { return }
            self.wobbleAnimator.startWobbling(
                for: self.wobbleID,
                amplitude: amplitude,
                scaleDelta: scaleDelta,
                interval: interval
            )
        }
    }

    private func stopWobble() {
        wobbleAnimator.stopWobbling(for: wobbleID)
    }
}
    
    // Edit grid overlay made of dotted squares the size of half a button
    private struct CBGridOverlay: View {
        let columns: Int
        let rows: Int
        let columnSpacing: CGFloat = 12
        let rowSpacing: CGFloat = 10
        
        var body: some View {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let colCount = max(1, columns)
                let rowCount = max(1, rows)
                let totalColSpacing = columnSpacing * CGFloat(max(0, colCount - 1))
                // Base cells: each base cell is one column. Button spans 2 base cells (rectangular).
                let cellWidth = (totalWidth - totalColSpacing) / CGFloat(colCount)
                let cellHeight = cellWidth // squares
                let dashed = StrokeStyle(lineWidth: 1, dash: [4, 4])
                let color = Color.secondary.opacity(0.5)
                ZStack {
                    ForEach(0..<rowCount, id: \.self) { r in
                        ForEach(0..<colCount, id: \.self) { c in
                            let x = CGFloat(c) * (cellWidth + columnSpacing)
                            let y = CGFloat(r) * (cellHeight + rowSpacing)
                            let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                            RoundedRectangle(cornerRadius: 10)
                                .inset(by: 4)
                                .stroke(style: dashed)
                                .foregroundColor(color)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            }
        }
    }
    
    // (moved earlier above CBControlSection)

    // SNAKE: Fader control tile (two rows tall, half width)
    private struct ControlFaderTile: View {
        let button: ControlButton
        let takenBy: String?
        let isEditing: Bool
        var onTap: () -> Void
        var onEdit: () -> Void
        var onDelete: () -> Void
        
        // 0.0..1.0 mapped to CC 0..127, rest at 84
        @State private var value: Double = Double(84) / 127.0
        @State private var wiggle = false

        // Wobble state - now uses shared animator
        @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
        @State private var wobbleID = UUID()
        
        var body: some View {
            let isHorizontal = (button.faderOrientation == "horizontal")
            let direction = button.faderDirection ?? (isHorizontal ? "right" : "up")

            ZStack(alignment: .topTrailing) {
                // Fill entire available space - 1x2 for vertical, 2x1 for horizontal
                GeometryReader { geo in
                    if isHorizontal {
                        // HORIZONTAL FADER
                        let headWidth: CGFloat = 20
                        let w = max(0, geo.size.width - headWidth)
                        // shouldReverse is only used for input mapping in gesture, not for visual rendering
                        let shouldReverse = (direction == "left")
                        // Fill alignment: "right" fills from left, "left" fills from right
                        // The alignment handles the directional flip, so we use the same value for both
                        let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

                        ZStack(alignment: fillAlignment) {
                            // Main fader track background
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 2)

                            // Fader fill (dynamic based on value) - alignment handles the direction
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: w * value)
                                .padding(3)

                            // Fader head (dynamic position) - conditional offset for direction
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(width: headWidth)
                                .offset(x: (direction == "right") ? (w * value) : -(w * value))
                                .padding(.vertical, 6)

                            // Text overlay inside fader at left
                            HStack(spacing: 2) {
                                Text(button.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                    .minimumScaleFactor(0.7)
                                Text("CC\(button.number)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Ch\(button.channel)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)

                            // Full-track gesture: tap/drag anywhere
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { g in
                                            guard !isEditing else { return }
                                            let localX = g.location.x
                                            let clamped = max(headWidth / 2, min(w - headWidth / 2, localX))
                                            var normalized = Double((clamped - headWidth / 2) / (w - headWidth))
                                            // Reverse input if direction is "left"
                                            if shouldReverse {
                                                normalized = 1.0 - normalized
                                            }
                                            value = max(0, min(1, normalized))
                                            sendCC()
                                        }
                                        .onEnded { _ in if !isEditing { sendCC() } }
                                )
                        }
                    } else {
                        // VERTICAL FADER
                        let headHeight: CGFloat = 20
                        let h = max(0, geo.size.height - headHeight)
                        // shouldReverse is only used for input mapping in gesture, not for visual rendering
                        let shouldReverse = (direction == "down")
                        // Fill alignment: "up" fills from bottom, "down" fills from top
                        // The alignment handles the directional flip, so we use the same value for both
                        let fillAlignment: Alignment = (direction == "up") ? .bottom : .top

                        ZStack(alignment: fillAlignment) {
                            // Main fader track background
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 2)

                            // Fader fill (dynamic based on value) - alignment handles the direction
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(height: h * value)
                                .padding(3)

                            // Fader head (dynamic position) - conditional offset for direction
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(height: headHeight)
                                .offset(y: (direction == "up") ? -(h * value) : (h * value))
                                .padding(.horizontal, 6)

                            // Text overlay inside fader at top
                            VStack(spacing: 1) {
                                Text(button.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                    .minimumScaleFactor(0.7)
                                Text("CC\(button.number)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Ch\(button.channel)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 6)
                            .allowsHitTesting(false)

                            // Full-track gesture: tap/drag anywhere
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { g in
                                            guard !isEditing else { return }
                                            let localY = g.location.y
                                            let clamped = max(headHeight / 2, min(h - headHeight / 2, h - localY))
                                            var normalized = Double((clamped - headHeight / 2) / (h - headHeight))
                                            // Reverse input if direction is "down"
                                            if shouldReverse {
                                                normalized = 1.0 - normalized
                                            }
                                            value = max(0, min(1, normalized))
                                            sendCC()
                                        }
                                        .onEnded { _ in if !isEditing { sendCC() } }
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // FIX: Removed padding to make faders fill grid cells like buttons
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clear)
                )
                if isEditing {
                    Button(action: onDelete) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.85))
                                .frame(width: 22, height: 22)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: -1.5, y: -1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(1)
                    .offset(x: -6, y: -6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .opacity(1.0)
            .disabled(takenBy != nil && !isEditing)
            // FIX: Removed .onTapGesture to eliminate delay - edit by tapping delete button instead
            // The onTapGesture was causing ~300ms delay because SwiftUI waits to disambiguate tap vs drag
            .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
            .onChange(of: isEditing) { _, editing in
                if editing { startWobble() } else { stopWobble() }
            }
            .onAppear {
                // Initialize fader value from stored value in ControlButton model
                if let storedValue = button.faderValue {
                    value = storedValue
                    debugPrint("🎚️ ControlFaderTile: Initialized fader \"\(button.title)\" with stored value: \(storedValue)")
                } else {
                    // Use default value for new faders
                    let defaultValue = Double(84) / 127.0
                    value = defaultValue
                    debugPrint("🎚️ ControlFaderTile: Initialized fader \"\(button.title)\" with default value: \(defaultValue)")
                }

                if isEditing { startWobble() }
            }
            .onDisappear {
                stopWobble()
            }
        }
        
        // MARK: - iPhone-style wobble implementation (using shared animator)
        private func startWobble() {
            guard isEditing else { return }

            // Generate unique wobble parameters for this tile (iPhone-like wobble)
            var rng = SeededRandom(seed: button.id.uuidString.hashValue)
            let amplitude = 1.2 + Double(rng.nextNormalized()) * 0.6 // ~1.2 ... 1.8 deg
            let scaleDelta = 0.003 + Double(rng.nextNormalized()) * 0.002 // ~0.3% ... 0.5%
            let interval = 0.16 + Double(rng.nextNormalized()) * 0.04 // ~0.16 ... 0.20s
            let initialDelay = Double(rng.nextNormalized()) * 0.3

            DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
                guard self.isEditing else { return }
                self.wobbleAnimator.startWobbling(
                    for: self.wobbleID,
                    amplitude: amplitude,
                    scaleDelta: scaleDelta,
                    interval: interval
                )
            }
        }

        private func stopWobble() {
            wobbleAnimator.stopWobbling(for: wobbleID)
        }
        
        private func sendCC() {
            let intVal = Int(round(value * 127))
            // Simple post via Notification; parent view already routes via triggerControl for buttons.
            // For faders, emit a custom notification so parent can listen and forward.
            NotificationCenter.default.post(name: Notification.Name("cbFaderChanged"),
                                            object: nil,
                                            userInfo: ["id": button.id, "channel": button.channel, "cc": button.number, "value": intVal, "title": button.title])
        }
    }
    
// MARK: - Performance List moved to ControlSubviews.swift

// MARK: - Performance Row moved to ControlSubviews.swift

// MARK: - Editor: Setlist column
// MARK: - CBSetlistColumn moved to ControlSubviews.swift

// MARK: - Editor: Library column
// MARK: - CBLibraryColumn moved to ControlSubviews.swift

// MARK: - CBRowLikeLibrary moved to ControlSubviews.swift

// MARK: - Full-width batch toolbar
// MARK: - CBBatchToolbar moved to ControlSubviews.swift

// MARK: - Connections Sheet (unchanged)
// MARK: - CBConnectionsSheet moved to ControlSubviews.swift

// MARK: - Projects Sheet (unchanged core)
// MARK: - CBProjectsSheet moved to ControlSubviews.swift
private struct CBProjectsSheet_Placeholder: View {
    @Binding var projectName: String
    let projects: [String]
    @Binding var isDirty: Bool

    var onRefreshList: () -> Void
    var onTapTitleWhenUnsaved: () -> Void
    var onSave: () -> Void
    var onSaveAs: (String) -> Void
    var onNew: () -> Void
    var onLoad: (String) -> Void
    var onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: String? = nil
    @State private var tempSaveAs: String = ""

    var body: some View { EmptyView() }
}

// MARK: - Add/Edit sheet (legacy CC-only; kept for name/cc/channel edits)
// MARK: - CBAddEditCueSheet moved to ControlSubviews.swift
private struct CBAddEditCueSheet_Placeholder: View {
    @Binding var editingSong: Song?
    let usedCCs: Set<Int>
    var onSave: (Song) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var ccText: String = ""
    @State private var channelText: String = "1"
    @State private var error: String? = nil

    var body: some View { EmptyView() }

    private func preset() {
        if let s = editingSong {
            name = s.name
            subtitle = s.subtitle ?? ""
            ccText = String(s.cc)
            channelText = String(s.channel)
        } else {
            name = ""
            subtitle = ""
            ccText = nextAvailableCC()
            channelText = "1"
        }
    }

    private func nextAvailableCC() -> String {
        for n in 1...127 where !usedCCs.contains(n) { return String(n) }
        return "1"
    }

    private func save() {
        error = nil
        guard let cc = Int(ccText), (0...127).contains(cc) else { error = "CC must be 0–127"; return }
        if let editing = editingSong, editing.cc == cc {
            // ok
        } else if usedCCs.contains(cc) {
            error = "That CC is already used"; return
        }
        guard let ch = Int(channelText), (1...16).contains(ch) else { error = "Channel must be 1–16"; return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Name required"; return }

        var song = editingSong ?? Song(name: trimmed, subtitle: subtitle.isEmpty ? nil : subtitle, cc: cc, channel: ch)
        song.name = trimmed
        song.subtitle = subtitle.isEmpty ? nil : subtitle
        song.cc = cc
        song.channel = ch
        onSave(song)
    }
}

// MARK: - MIDI Picker (shared by Song & Control button)
// MARK: - CBMIDIPickerSheet moved to ControlSubviews.swift
private struct CBMIDIPickerSheet_Placeholder: View {
    let title: String
    @State var kind: MIDIKind
    @State var number: Int
    @State var channel: Int
    @State var velocity: Int
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (MIDIKind, Int, Int, Int) -> Void
    var onCancel: () -> Void

    var body: some View { EmptyView() }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return conflictFor[key]
    }
}

// MARK: - Control Button Preview (used in editor)
// MARK: - ControlButtonPreview moved to ControlSubviews.swift
private struct ControlButtonPreview_Placeholder: View {
    let title: String
    let symbol: String
    let kind: MIDIKind
    let number: Int
    let channel: Int
    let velocity: Int

    var body: some View { EmptyView() }
}

    // Preview for fader in the editor
    // MARK: - ControlFaderPreview moved to ControlSubviews.swift
    private struct ControlFaderPreview_Placeholder: View {
        let title: String
        let cc: Int
        let channel: Int
        
        var body: some View { EmptyView() }
    }
    
    private struct CBGridDropSurface: View {
        let width: CGFloat
        let height: CGFloat
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        @Binding var buttons: [ControlButton]
        @Binding var dragging: ControlButton?
        @Binding var previewLocation: GridPosition?
        let isActive: Bool
        
        var body: some View {
                        Rectangle()
                .fill(Color.clear)
                .frame(width: width, height: height)
                // .onDrop(of: [UTType.text], delegate: CBGridDropSurfaceDelegate( // Disabled for iOS-style drag
                //     columns: columns,
                //     columnSpacing: columnSpacing,
                //     rowSpacing: rowSpacing,
                //     cellSize: cellSize,
                //     buttons: $buttons,
                //     dragging: $dragging,
                //     previewLocation: $previewLocation,
                //     isActive: isActive
                // ))
                .allowsHitTesting(isActive)
        }
    }
    
    private struct CBDragPreview: View {
        let dragItem: ControlButton
        let previewLocation: (col: Int, row: Int)
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        
        var body: some View {
            let width = CGFloat(dragItem.gridWidth) * cellSize + CGFloat(dragItem.gridWidth - 1) * columnSpacing
            let height = CGFloat(dragItem.gridHeight) * cellSize + CGFloat(dragItem.gridHeight - 1) * rowSpacing
            let x = CGFloat(previewLocation.col) * (cellSize + columnSpacing)
            let y = CGFloat(previewLocation.row) * (cellSize + rowSpacing)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.3))
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: width, height: height)
                .position(x: x + width/2, y: y + height/2)
                .allowsHitTesting(false)
        }
    }
    

    private struct CBGridDropSurfaceDelegate: DropDelegate {
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        @Binding var buttons: [ControlButton]
        @Binding var dragging: ControlButton?
        @Binding var previewLocation: GridPosition?
        let isActive: Bool
        
        func validateDrop(info: DropInfo) -> Bool {
            // Always return true to prevent 🚫 icon
            return true
        }
        
        func dropEntered(info: DropInfo) {
            guard isActive, dragging != nil else { 
                debugPrint("🔴 dropEntered: not active or no dragging")
                return 
            }
            updatePreview(info: info)
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            // Continuously update preview as pointer moves
            updatePreview(info: info)
            return DropProposal(operation: .move)
        }
        
        func dropExited(info: DropInfo) {
            previewLocation = nil
        }
        
        private func updatePreview(info: DropInfo) {
            guard let dragging = dragging else { return }
            let p = info.location
            let col = max(0, Int((p.x / (cellSize + columnSpacing)).rounded(.down)))
            let row = max(0, Int((p.y / (cellSize + rowSpacing)).rounded(.down)))
            let targetWidth = dragging.gridWidth
            let fits = col + targetWidth <= columns
            previewLocation = fits ? GridPosition(col: col, row: row) : nil
        }
        
        func performDrop(info: DropInfo) -> Bool {
            guard isActive, let dragging = dragging else { 
                debugPrint("🔴 performDrop failed: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
                return false 
            }
            
            // Calculate drop position from pointer location
            let p = info.location
            let col = max(0, Int((p.x / (cellSize + columnSpacing)).rounded(.down)))
            let row = max(0, Int((p.y / (cellSize + rowSpacing)).rounded(.down)))
            
            debugPrint("✅ performDrop to (\(col),\(row)) for \(dragging.title) - using smart placement")
            
            // Use smart placement to handle overlaps
            let success = smartPlacement(
                item: dragging,
                targetCol: col,
                targetRow: row,
                items: &buttons
            )
            
            if success {
                debugPrint("✅ Smart placement successful for \(dragging.title)")
            } else {
                debugPrint("🔴 Smart placement failed for \(dragging.title)")
            }
            
            // Clear preview and dragging state immediately
            previewLocation = nil
            self.dragging = nil
            
            return success
        }
        
        // Smart placement logic with repositioning
        private func smartPlacement(
            item: ControlButton,
            targetCol: Int,
            targetRow: Int,
            items: inout [ControlButton]
        ) -> Bool {
            let itemWidth = item.gridWidth
            let itemHeight = item.gridHeight
            if !hasOverlap(col: targetCol, row: targetRow, width: itemWidth, height: itemHeight, items: items, excluding: item.id) {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].gridCol = targetCol
                    items[index].gridRow = targetRow
            return true
        }
                return false
            }
            let overlapping = findOverlappingItems(
                col: targetCol, row: targetRow, width: itemWidth, height: itemHeight, 
                items: items, excluding: item.id
            )
            var repositionPlan: [(ControlButton, Int, Int)] = []
            for overlappingItem in overlapping {
                let newPos = findFreePosition(for: overlappingItem, items: items, excluding: [item.id] + overlapping.map { $0.id })
                if let (newCol, newRow) = newPos {
                    repositionPlan.append((overlappingItem, newCol, newRow))
                } else {
                    return false
                }
            }
            for (itemToMove, newCol, newRow) in repositionPlan {
                if let index = items.firstIndex(where: { $0.id == itemToMove.id }) {
                    items[index].gridCol = newCol
                    items[index].gridRow = newRow
                }
            }
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].gridCol = targetCol
                items[index].gridRow = targetRow
                return true
            }
            return false
        }
        
        // Check for overlaps
        private func hasOverlap(col: Int, row: Int, width: Int, height: Int, items: [ControlButton], excluding excludeId: UUID) -> Bool {
            for item in items {
                guard item.id != excludeId,
                      let itemCol = item.gridCol,
                      let itemRow = item.gridRow else { continue }

                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight
                
                if rectsOverlap(
                    r1: (col, row, width, height),
                    r2: (itemCol, itemRow, itemWidth, itemHeight)
                ) {
                    return true
                }
            }
            return false
        }
        
        // Find overlapping items
        private func findOverlappingItems(col: Int, row: Int, width: Int, height: Int, items: [ControlButton], excluding excludeId: UUID) -> [ControlButton] {
            var overlapping: [ControlButton] = []
            
            for item in items {
                guard item.id != excludeId,
                      let itemCol = item.gridCol,
                      let itemRow = item.gridRow else { continue }

                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight
                
                if rectsOverlap(
                    r1: (col, row, width, height),
                    r2: (itemCol, itemRow, itemWidth, itemHeight)
                ) {
                    overlapping.append(item)
                }
            }
            return overlapping
        }
        
        // Find free position for an item
        private func findFreePosition(for item: ControlButton, items: [ControlButton], excluding excludeIds: [UUID]) -> (Int, Int)? {
            let itemWidth = item.gridWidth
            let itemHeight = item.gridHeight
            let maxCols = 8
            let maxRows = 4
            
            // Try positions in order of preference
            for row in 0..<maxRows {
                for col in 0..<maxCols {
                    if col + itemWidth <= maxCols && row + itemHeight <= maxRows {
                        var hasConflict = false
                        for otherItem in items {
                            guard !excludeIds.contains(otherItem.id),
                                  let otherCol = otherItem.gridCol,
                                  let otherRow = otherItem.gridRow else { continue }
                            
                            let otherWidth = otherItem.gridWidth
                            let otherHeight = otherItem.gridHeight
                            
                            if rectsOverlap(
                                r1: (col, row, itemWidth, itemHeight),
                                r2: (otherCol, otherRow, otherWidth, otherHeight)
                            ) {
                                hasConflict = true
                                break
                            }
                        }
                        if !hasConflict {
                            return (col, row)
                        }
                    }
                }
            }
            return nil
        }
        
        // Rectangle overlap check
        private func rectsOverlap(r1: (Int, Int, Int, Int), r2: (Int, Int, Int, Int)) -> Bool {
            let (x1, y1, w1, h1) = r1

            let (x2, y2, w2, h2) = r2
            return !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)
        }
    }


// MARK: - Helper struct for collision detection
private struct GridRect {
    let col: Int
    let row: Int
    let width: Int
    let height: Int
}

// MARK: - Conditional Drag Modifier
private struct ConditionalDragModifier: ViewModifier {
    let isEditing: Bool
    let onDrag: () -> NSItemProvider
    let buttonTitle: String

    func body(content: Content) -> some View {
        if isEditing {
            content.onDrag {
                debugPrint("🟢 ConditionalDragModifier: onDrag triggered for: \(buttonTitle)")
                let provider = onDrag()
                debugPrint("🟢 ConditionalDragModifier: NSItemProvider created")
                return provider
            }
        } else {
            content
        }
    }
}

// MARK: - Simple seeded RNG for per-tile wobble variety
private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Mix the signed seed into a 64-bit state
        let mixed = UInt64(bitPattern: Int64(seed)) ^ 0x9E3779B97F4A7C15
        state = mixed != 0 ? mixed : 0xA4093822299F31D0 // avoid zero state
    }

    // xorshift64*
    private mutating func nextRaw() -> UInt64 {
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }

    mutating func nextNormalized() -> Double {
        let v = nextRaw()
        return Double(v) / Double(UInt64.max)
    }
}

// MARK: - Press effect gesture only when not editing (prevents conflicts with system drag)
private struct PressEffectWhenNotEditing: ViewModifier {
    let isEditing: Bool
    let onChange: () -> Void
    let onEnd: () -> Void

    func body(content: Content) -> some View {
        if isEditing {
            content
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onChange() }
                    .onEnded { _ in onEnd() }
            )
        }
    }
}

// MARK: - iPad Control Tile (adapted from Mac editor)
private struct iPadControlTile: View {
    let button: ControlButton
    let takenBy: String?
    let isEditing: Bool
    let isDragging: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onDrag: () -> NSItemProvider
    var onFaderMIDI: (Int, Int, Int, String, UUID) -> Void
    
    @State private var isPressed = false
    @State private var isTouching = false // Track touch state for instant feedback
    @State private var faderValue: Double = 0.66 // 0.0 to 1.0
    @State private var faderVisualValue: Double = 0.66
    @State private var lastSentValue: Double = 0.0 // Track last MIDI value sent
    // FIX #7: Replace Date() timing with frame counter for better performance
    @State private var frameCounter: Int = 0
    @State private var firedThisPress: Bool = false
    // FIX #1: Track notification subscription to prevent memory leak
    @State private var faderUpdateCancellable: AnyCancellable? = nil

    // Wobble state - now uses shared animator
    @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
    @State private var wobbleID = UUID()
        @State private var flashOpacity: Double = 0.0
    
    // MARK: - iPhone-style wobble implementation (using shared animator)
    private func startWobble() {
        guard isEditing else { return }

        // Generate unique wobble parameters for this tile (iPhone-like wobble)
        var rng = SeededRandom(seed: button.id.uuidString.hashValue)
        let amplitude = 1.2 + Double(rng.nextNormalized()) * 0.6
        let scaleDelta = 0.003 + Double(rng.nextNormalized()) * 0.002
        let interval = 0.12 + Double(rng.nextNormalized()) * 0.03
        let initialDelay = Double(rng.nextNormalized()) * 0.3

        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            guard self.isEditing else { return }
            self.wobbleAnimator.startWobbling(
                for: self.wobbleID,
                amplitude: amplitude,
                scaleDelta: scaleDelta,
                interval: interval
            )
        }
    }

    private func stopWobble() {
        wobbleAnimator.stopWobbling(for: wobbleID)
    }
    
    var body: some View {
        ZStack {
            if button.isFader == true {
                FaderTileContent()
            } else {
                if isEditing {
                    // In edit mode, render as plain content to prioritize drag
                    ZStack {
                ButtonTileContent()
                            .contentShape(Rectangle())
                    }
                    .onTapGesture { onEdit() }
                } else {
                    Button(action: {
                        // Blue flash on tap
                        flashOpacity = 1.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            withAnimation(.easeOut(duration: 0.18)) { flashOpacity = 0.0 }
                        }
                        onTap()
                    }) {
                        ZStack {
                            ButtonTileContent()
                                .contentShape(Rectangle())
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor)
                                .opacity(flashOpacity)
                                .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isTouching {
                                    withAnimation(.easeOut(duration: 0.08)) {
                                        isTouching = true
                                        isPressed = true
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.12)) {
                                    isTouching = false
                                    isPressed = false
                                }
                            }
                    )
                }
            }
            
            // Delete button in edit mode
            if isEditing {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.85))
                            .frame(width: 22, height: 22)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
                .padding(2)
                .offset(x: -4, y: -4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(isEditing ? Rectangle() : Rectangle())
        .background(isEditing ? Color.clear : Color.black.opacity(0.001))
            .opacity(isDragging ? (button.isFader == true ? 0.8 : 0.5) : 1.0)
            // .modifier(ConditionalDragModifier(isEditing: isEditing, onDrag: onDrag, buttonTitle: button.title)) // Disabled in favor of smooth drag
            .allowsHitTesting(isEditing ? true : true)
        .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
        .onChange(of: isEditing) { _, editing in
            if editing { startWobble() } else { stopWobble() }
        }
        .onAppear {
            // Initialize fader value from stored value in ControlButton model
            if let storedValue = button.faderValue {
                faderValue = storedValue
                faderVisualValue = storedValue
                debugPrint("🎚️ iPadControlTile: Initialized fader \"\(button.title)\" with stored value: \(storedValue)")
            } else {
                // Use default value for new faders
                let defaultValue = 0.66
                faderValue = defaultValue
                faderVisualValue = defaultValue
                debugPrint("🎚️ iPadControlTile: Initialized fader \"\(button.title)\" with default value: \(defaultValue)")
            }
            if isEditing { startWobble() }

            // FIX #1: Setup notification subscription using Combine to prevent memory leak
            faderUpdateCancellable = NotificationCenter.default.publisher(for: Notification.Name("cbUpdateFaderFromDAW"))
                .sink { [self] notif in
                    debugPrint("🎚️ iPadControlTile: Received cbUpdateFaderFromDAW notification for \"\(button.title)\"")
                    debugPrint("🎚️ iPadControlTile: Notification data: \(notif.userInfo ?? [:])")
                    debugPrint("🎚️ iPadControlTile: Looking for buttonID: \(button.id.uuidString)")

                    guard let info = notif.userInfo as? [String: Any],
                          let buttonID = info["buttonID"] as? String,
                          let value = info["value"] as? Double,
                          buttonID == button.id.uuidString else {
                        let receivedButtonID = (notif.userInfo as? [String: Any])?["buttonID"] as? String ?? "nil"
                        debugPrint("🎚️ iPadControlTile: ❌ Notification not for this fader (buttonID=\(receivedButtonID), expected=\(button.id.uuidString))")
                        return
                    }

                    // Update fader values from DAW MIDI input
                    faderValue = value
                    faderVisualValue = value

                    debugPrint("🎚️ iPadControlTile: ✅ Updated fader \"\(button.title)\" to \(value) from DAW MIDI")
                }
        }
        .onDisappear {
            stopWobble()
            // FIX #1: Clean up notification subscription to prevent memory leak
            faderUpdateCancellable?.cancel()
            faderUpdateCancellable = nil
        }
    }
    
    // Computed property for button background color based on toggle state
    private var buttonBackgroundColor: Color {
        if isPressed {
            return Color.accentColor
        } else if button.isToggle == true && button.toggleState {
            return Color.accentColor.opacity(0.3) // Light accent for toggle ON
        } else {
            return Color.white
        }
    }
    
    // Computed property for button text color based on toggle state
    private var buttonTextColor: Color {
        if isPressed {
            return .white
        } else if button.isToggle == true && button.toggleState {
            return .accentColor // Accent color for toggle ON
        } else {
            return .primary
        }
    }
    
    @ViewBuilder
    private func ButtonTileContent() -> some View {
        VStack(spacing: 6) {
                if button.symbol.isEmpty {
                    Text(button.title)
                        .font(.title3.weight(.semibold))
                    Text(midiLabel())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if button.title.isEmpty {
                    // Icon only - center it vertically with MIDI label at bottom
                    VStack {
                        Spacer()
                        Image(systemName: button.symbol).font(.system(size: 32, weight: .semibold))
                        Spacer()
                        Text(midiLabel())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                } else {
                    // Icon + text
                    Image(systemName: button.symbol).font(.system(size: 24, weight: .semibold))
                    Text(button.title).font(.footnote.weight(.semibold))
                    Text(midiLabel())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
        }
        .foregroundColor(buttonTextColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(buttonBackgroundColor)
                )
        )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor)
                    .opacity(flashOpacity)
            )
            .animation(.easeOut(duration: 0.12), value: flashOpacity)
            .scaleEffect(isTouching ? 1.05 : 1.0)
            .shadow(color: (isTouching || (isEditing && isDragging)) ? .blue.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTouching)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDragging)
    }
    
    @ViewBuilder
    private func FaderTileContent() -> some View {
        GeometryReader { geo in
            let isHorizontal = (button.faderOrientation == "horizontal")
            let direction = button.faderDirection ?? (isHorizontal ? "right" : "up")

            if isHorizontal {
                // HORIZONTAL FADER
                let headWidth: CGFloat = 20
                let w = max(0, geo.size.width - headWidth)
                // shouldReverse is only used for input mapping in gesture, not for visual rendering
                let shouldReverse = (direction == "left")
                // Fill alignment: "right" fills from left, "left" fills from right
                // The alignment handles the directional flip, so we use the same value for both
                let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

                ZStack(alignment: fillAlignment) {
                    // Main fader track background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 2)
                        )

                    // Fader fill (dynamic based on faderValue) - alignment handles the direction
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: w * faderVisualValue)
                        .padding(3)

                    // Fader head (dynamic position) - conditional offset for direction
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(width: headWidth)
                        .offset(x: (direction == "right") ? (w * faderVisualValue) : -(w * faderVisualValue))
                        .padding(.vertical, 6)
                }
                .gesture(
                    // Apply drag gesture directly to the fader track area
                    isEditing ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Instant touch feedback on first touch
                            if !isTouching {
                                withAnimation(.easeOut(duration: 0.08)) {
                                    isTouching = true
                                }
                            }

                            let dragX = value.location.x
                            let faderTrackWidth = w

                            // Convert X position to fader value (0.0 to 1.0)
                            let normalizedX = max(0, min(faderTrackWidth, dragX - headWidth/2))
                            var targetValue = max(0.0, min(1.0, Double(normalizedX) / Double(faderTrackWidth)))

                            // Reverse if direction is "left"
                            if shouldReverse {
                                targetValue = 1.0 - targetValue
                            }

                            // Update both values immediately for maximum responsiveness
                            faderValue = targetValue
                            faderVisualValue = targetValue

                            // FIX #7: Use frame counter instead of Date() for throttling
                            frameCounter += 1
                            let valueChange = abs(targetValue - lastSentValue)

                            // Send MIDI every 2nd frame or if value changed significantly
                            // 1. Every 2nd frame (avoids Date() overhead)
                            // 2. Value changed significantly (>0.01 = ~1.3 MIDI steps)
                            // 3. At extreme values (0.0 or 1.0)
                            if frameCounter % 2 == 0 || valueChange > 0.01 || targetValue == 0.0 || targetValue == 1.0 {
                                let midiValue = Int(round(targetValue * 127))
                                lastSentValue = targetValue
                                onFaderMIDI(button.channel, button.number, midiValue, button.title, button.id)
                            }
                        }
                        .onEnded { _ in
                            // End touch feedback
                            withAnimation(.easeOut(duration: 0.12)) {
                                isTouching = false
                            }

                            // Ensure final MIDI value is sent
                            let finalMidiValue = Int(round(faderValue * 127))
                            onFaderMIDI(button.channel, button.number, finalMidiValue, button.title, button.id)
                            lastSentValue = faderValue
                            // FIX #7: Reset frame counter
                            frameCounter = 0
                        }
                )

                // Title overlay - centered
                HStack {
                    Text(button.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.leading, 4)
                    Spacer()
                    Text(midiLabel())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.trailing, 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false) // Don't interfere with fader drag
            } else {
                // VERTICAL FADER
                let headHeight: CGFloat = 20
                let h = max(0, geo.size.height - headHeight)
                // shouldReverse is only used for input mapping in gesture, not for visual rendering
                let shouldReverse = (direction == "down")
                // Fill alignment: "up" fills from bottom, "down" fills from top
                // The alignment handles the directional flip, so we use the same value for both
                let fillAlignment: Alignment = (direction == "up") ? .bottom : .top

                ZStack(alignment: fillAlignment) {
                    // Main fader track background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 2)
                        )

                    // Fader fill (dynamic based on faderValue) - alignment handles the direction
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.2))
                            .frame(height: h * faderVisualValue)
                        .padding(3)

                    // Fader head (dynamic position) - conditional offset for direction
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(height: headHeight)
                            .offset(y: (direction == "up") ? -(h * faderVisualValue) : (h * faderVisualValue))
                        .padding(.horizontal, 6)
                }
                .gesture(
                    // Apply drag gesture directly to the fader track area
                    isEditing ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Instant touch feedback on first touch
                            if !isTouching {
                                withAnimation(.easeOut(duration: 0.08)) {
                                    isTouching = true
                                }
                            }

                            let dragY = value.location.y
                            let faderTrackHeight = h

                            // Convert Y position to fader value (0.0 to 1.0)
                            let normalizedY = max(0, min(faderTrackHeight, dragY - headHeight/2))
                            var targetValue = max(0.0, min(1.0, 1.0 - (Double(normalizedY) / Double(faderTrackHeight))))

                            // Reverse if direction is "down"
                            if shouldReverse {
                                targetValue = 1.0 - targetValue
                            }

                            // Update both values immediately for maximum responsiveness
                            faderValue = targetValue
                            faderVisualValue = targetValue

                            // FIX #7: Use frame counter instead of Date() for throttling
                            frameCounter += 1
                            let valueChange = abs(targetValue - lastSentValue)

                            // Send MIDI every 2nd frame or if value changed significantly
                            // 1. Every 2nd frame (avoids Date() overhead)
                            // 2. Value changed significantly (>0.01 = ~1.3 MIDI steps)
                            // 3. At extreme values (0.0 or 1.0)
                            if frameCounter % 2 == 0 || valueChange > 0.01 || targetValue == 0.0 || targetValue == 1.0 {
                                let midiValue = Int(round(targetValue * 127))
                                lastSentValue = targetValue
                                onFaderMIDI(button.channel, button.number, midiValue, button.title, button.id)
                            }
                        }
                        .onEnded { _ in
                            // End touch feedback
                            withAnimation(.easeOut(duration: 0.12)) {
                                isTouching = false
                            }

                            // Ensure final MIDI value is sent
                            let finalMidiValue = Int(round(faderValue * 127))
                            onFaderMIDI(button.channel, button.number, finalMidiValue, button.title, button.id)
                            lastSentValue = faderValue
                            // FIX #7: Reset frame counter
                            frameCounter = 0
                        }
                )

                // Title overlay - centered
                VStack {
                    Text(button.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    Spacer()
                    Text(midiLabel())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false) // Don't interfere with fader drag
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.clear))
        .contentShape(Rectangle())  // Ensure entire frame is tappable
        .highPriorityGesture(
            // Only apply TapGesture for buttons, not faders (faders have DragGesture with minimumDistance: 0)
            button.isFader == true ? nil : TapGesture().onEnded {
                if isEditing {
                    onEdit()
                } else {
                    onTap()
                }
            }
        )
        .scaleEffect(isTouching ? 1.05 : 1.0)
        .shadow(color: (isTouching || (isEditing && isDragging)) ? .blue.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTouching)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDragging)
    }
    
    private func midiLabel() -> String {
        switch button.kind {
        case .cc:   return "\(button.channel)•\(button.number)"
        case .note: return "\(button.channel)•\(button.number)•\(button.velocity)"
        }
    }
}

// MARK: - iPad Drop Delegate (adapted from Mac editor)
private struct iPadDropDelegate: DropDelegate {
    let columns: Int
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let cellSize: CGFloat
    let displayRows: Int
    @Binding var buttons: [ControlButton]
    @Binding var dragging: ControlButton?
    @Binding var previewLocation: GridPosition?
    @Binding var dropSurfaceElevated: Bool
    @Binding var isDragOperation: Bool
    @Binding var lastDropTime: Date
    let isActive: Bool
    let clearDragState: (String) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
            // Always return true to prevent 🚫 icon - we'll handle validation in performDrop
            return true
    }
    
    func dropEntered(info: DropInfo) {
        debugPrint("🟦 dropEntered called - isActive: \(isActive), dragging: \(dragging?.title ?? "nil")")
        debugPrint("🟦 dropEntered location: (\(info.location.x), \(info.location.y))")
        guard isActive, dragging != nil else { 
            debugPrint("🔴 dropEntered: not active or no dragging")
            return 
        }
        updatePreview(info: info)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Always update preview, even during fast drags
        updatePreview(info: info)
        // Ensure we maintain drag state during fast movement
        if dragging != nil {
        return DropProposal(operation: .move)
        } else {
            return DropProposal(operation: .forbidden)
        }
    }
    
    func dropExited(info: DropInfo) {
        // Don't clear preview immediately - give a brief moment to return
        // Only clear if we're truly exiting the drop area
        debugPrint("🚪 dropExited: keeping drag state for potential return")
    }
    
    private func updatePreview(info: DropInfo) {
        guard let dragging = dragging else {
            debugPrint("🔴 updatePreview: no dragging item")
            return
        }
        
        let p = info.location
        let rawCol = Int((p.x / (cellSize + columnSpacing)).rounded(.down))
        let rawRow = Int((p.y / (cellSize + rowSpacing)).rounded(.down))
        let row = max(0, min(rawRow, displayRows - 1))

        let targetWidth = dragging.gridWidth
        let col = max(0, min(rawCol, columns - targetWidth))
        
        let fits = col + targetWidth <= columns && row >= 0 && col >= 0

        let newPosition = fits ? GridPosition(col: col, row: row) : nil
        
        // Always update preview location during active drags to handle fast movement
        previewLocation = newPosition
        if let pos = newPosition {
            debugPrint("🟦 Preview updated to: (\(pos.col), \(pos.row))")
        } else {
            debugPrint("🟦 Preview cleared - doesn't fit")
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        debugPrint("✅ performDrop called: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
        guard isActive, let draggingButton = dragging else { 
            debugPrint("🔴 performDrop failed: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
            return false 
        }
        
        let p = info.location
        let rawCol = Int((p.x / (cellSize + columnSpacing)).rounded(.down))
        let rawRow = Int((p.y / (cellSize + rowSpacing)).rounded(.down))
        let row = max(0, min(rawRow, displayRows - 1))
        let targetWidth = draggingButton.gridWidth
        let col = max(0, min(rawCol, columns - targetWidth))
        
        debugPrint("✅ performDrop to (\(col),\(row)) for \(draggingButton.title) - using smart placement")
        
        // Use smart placement to handle overlaps and find best position
        smartPlacement(dragging: draggingButton, targetCol: col, targetRow: row)
        
        // Verify the placement was successful
        if let buttonIndex = buttons.firstIndex(where: { $0.id == draggingButton.id }) {
            let finalCol = buttons[buttonIndex].gridCol ?? -1
            let finalRow = buttons[buttonIndex].gridRow ?? -1
            debugPrint("✅ Final position for \(draggingButton.title): (\(finalCol), \(finalRow))")
        }
        
        // Record drop time to prevent auto-assignment interference
        lastDropTime = Date()
        
        // Add a small delay before clearing drag state to ensure position is committed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            clearDragState("drop completed successfully")
        }
        return true
    }
    
    // Smart placement helper functions (from Mac editor)
    private func smartPlacement(dragging: ControlButton, targetCol: Int, targetRow: Int) {
            let draggedWidth = dragging.gridWidth
            let draggedHeight = dragging.gridHeight
        guard let draggedIndex = buttons.firstIndex(where: { $0.id == dragging.id }) else { 
            debugPrint("🔴 smartPlacement: Could not find dragged button \(dragging.title) in buttons array")
            return 
        }
        
        let _ = buttons[draggedIndex].gridCol ?? -1
        let _ = buttons[draggedIndex].gridRow ?? -1
        // Removed verbose height calculation logs for cleaner testing
        debugPrint("🔍 smartPlacement: buttons array has \(buttons.count) items, draggedIndex = \(draggedIndex)")
        
        buttons[draggedIndex].gridCol = nil
        buttons[draggedIndex].gridRow = nil
        let draggedRect = GridRect(col: targetCol, row: targetRow, width: draggedWidth, height: draggedHeight)
        let overlapping = findOverlappingItems(for: draggedRect)
        if overlapping.isEmpty {
            buttons[draggedIndex].gridCol = targetCol
            buttons[draggedIndex].gridRow = targetRow
            debugPrint("✅ smartPlacement: Placed \(dragging.title) at (\(targetCol), \(targetRow)) - no overlaps")
        } else {
            var displacedItems: [(index: Int, originalCol: Int, originalRow: Int, item: ControlButton)] = []
            for overlappingIndex in overlapping {
                let originalCol = buttons[overlappingIndex].gridCol ?? 0
                let originalRow = buttons[overlappingIndex].gridRow ?? 0
                displacedItems.append((index: overlappingIndex, originalCol: originalCol, originalRow: originalRow, item: buttons[overlappingIndex]))
                buttons[overlappingIndex].gridCol = nil
                buttons[overlappingIndex].gridRow = nil
            }
            buttons[draggedIndex].gridCol = targetCol
            buttons[draggedIndex].gridRow = targetRow
            debugPrint("✅ smartPlacement: Placed \(dragging.title) at (\(targetCol), \(targetRow)) - handling \(displacedItems.count) overlaps")
            // Use iPhone-like smart positioning for displaced items
            for (index, originalCol, originalRow, item) in displacedItems {
                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight

                // Try to find a smart position (right first, then down)
                if let newPos = findSmartPosition(
                    forItemAt: (originalCol, originalRow),
                    width: itemWidth,
                    height: itemHeight,
                    excluding: index
                ) {
                    buttons[index].gridCol = newPos.col
                    buttons[index].gridRow = newPos.row
                    debugPrint("🔄 Displaced \(item.title) to new position (\(newPos.col), \(newPos.row))")
                } else {
                    buttons[index].gridCol = originalCol
                    buttons[index].gridRow = originalRow
                    debugPrint("⚠️ Could not find new position for \(item.title), keeping at original (\(originalCol), \(originalRow))")
                }
            }
        }
    }
    
    private func findOverlappingItems(for rect: GridRect) -> [Int] {
        var overlapping: [Int] = []
        for (index, item) in buttons.enumerated() {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                    width: item.gridWidth,
                    height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) {
                    debugPrint("🔍 Found overlap: \(item.title) at (\(col),\(row)) size \(itemRect.width)x\(itemRect.height) overlaps with target rect (\(rect.col),\(rect.row)) size \(rect.width)x\(rect.height)")
                overlapping.append(index)
            }
        }
        return overlapping
    }
    
    private func findFreePosition(width: Int, height: Int) -> (col: Int, row: Int)? {
        let maxSearchRows = 4
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                    if !hasOverlap(testRect) { return (col: col, row: row) }
                }
            }
        return nil
    }

    // iPhone-like smart positioning: prioritize right, then down, then general search
    private func findSmartPosition(
        forItemAt originalPos: (Int, Int),
        width: Int,
        height: Int,
        excluding excludeIndex: Int
    ) -> (col: Int, row: Int)? {
        let (originalCol, originalRow) = originalPos

        // 1. Try moving right first (same row, next column)
        let rightCol = originalCol + 1
        if rightCol + width <= columns {
            let testRect = GridRect(col: rightCol, row: originalRow, width: width, height: height)
            if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                return (rightCol, originalRow)
            }
        }

        // 2. Try moving down and left (cascade to next row)
        let nextRow = originalRow + 1
        if nextRow + height <= 4 { // max 4 rows
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: nextRow, width: width, height: height)
                if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                    return (col, nextRow)
                }
            }
        }

        // 3. Fallback to general search (left-to-right, top-to-bottom)
        return findFreePositionExcluding(width: width, height: height, excluding: excludeIndex)
    }

    private func findFreePositionExcluding(width: Int, height: Int, excluding excludeIndex: Int) -> (col: Int, row: Int)? {
        let maxSearchRows = 4
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                    return (col: col, row: row)
                }
            }
        }
        return nil
    }

    private func hasOverlapExcluding(_ rect: GridRect, excluding excludeIndex: Int) -> Bool {
        for (index, item) in buttons.enumerated() {
            if index == excludeIndex { continue }
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }
    
    private func hasOverlap(_ rect: GridRect) -> Bool {
        for item in buttons {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                    width: item.gridWidth,
                    height: item.gridHeight
            )
                if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }
    
    private func rectsOverlap(_ rect1: GridRect, _ rect2: GridRect) -> Bool {
        return !(rect1.col + rect1.width <= rect2.col ||
                rect2.col + rect2.width <= rect1.col ||
                rect1.row + rect1.height <= rect2.row ||
                rect2.row + rect2.height <= rect1.row)
    }
}

// MARK: - MIDI Table Sheet
struct MidiTableSheet: View {
    let setlist: [Song]
    let controlButtons: [ControlButton]
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    var onDismiss: () -> Void
        var onApply: (([MidiTableItem]) -> Void)? = nil

    @State private var editableItems: [MidiTableItem] = []
    @State private var showingConflictAlert = false
    @State private var pendingConflict: MidiConflict? = nil
        @State private var sortKey: MidiSortKey = .name
        @State private var sortAscending: Bool = true
        @State private var allowFullCCR: Bool = false
        
        enum MidiSortKey { case name, type, channel, value }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Channel Settings Section
                VStack(spacing: 16) {
                    HStack {
                        Text("MIDI Channel")
                            .font(.headline)
                        Spacer()
                    }
                    
                    // Global/Per Controller Toggle
                    Picker("Channel Mode", selection: $isGlobalChannel) {
                        Text("Per Controller").tag(false)
                        Text("Global").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    // Global Channel Selector (when Global is selected)
                    if isGlobalChannel {
                        HStack {
                            Text("Global Channel:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Global Channel", selection: $globalChannel) {
                                ForEach(1...16, id: \.self) { ch in
                                    Text("Channel \(ch)").tag(ch)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // MIDI Table
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Table Header
                        HStack(spacing: 0) {
                                Button(action: { toggleSort(.name) }) {
                                    HStack(spacing: 4) {
                                        Text("Name").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                        sortIndicator(for: .name)
                                    }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { toggleSort(.type) }) {
                                    HStack(spacing: 4) {
                                        Text("Type").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                        sortIndicator(for: .type)
                                    }
                                .frame(width: 70, alignment: .center)
                                }
                                .buttonStyle(.plain)
                            
                            if !isGlobalChannel {
                                    Button(action: { toggleSort(.channel) }) {
                                        HStack(spacing: 4) {
                                            Text("Channel").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                            sortIndicator(for: .channel)
                                        }
                                    .frame(width: 80, alignment: .center)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button(action: { toggleSort(.value) }) {
                                    HStack(spacing: 4) {
                                        Text("Value").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                        sortIndicator(for: .value)
                                    }
                                .frame(width: 90, alignment: .center)
                                }
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemGray6))
                        
                        ForEach(editableItems.indices, id: \.self) { index in
                            MidiTableRow(
                                item: $editableItems[index],
                                isGlobalChannel: isGlobalChannel,
                                globalChannel: globalChannel,
                                    allowFullCCR: allowFullCCR,
                                onMidiChange: { item, newMidiType, newChannel, newValue in
                                    handleMidiChange(item: item, newMidiType: newMidiType, newChannel: newChannel, newValue: newValue)
                                },
                                getOwnerName: { midiType, channel, value, excludeId in
                                    getOwnerName(for: midiType, channel: channel, value: value, excluding: excludeId)
                                }
                            )
                            .background(Color(UIColor.systemBackground))
                            
                            if index < editableItems.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("MIDI Assignments")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    if isGlobalChannel {
                        applyGlobalChannel()
                    }
                        onApply?(editableItems)
                    onDismiss()
                }
                .font(.body.weight(.semibold))
            )
            .background(Color(UIColor.systemGroupedBackground))
        }
        .onAppear {
            buildMidiTableItems()
        }
        .alert("MIDI Conflict", isPresented: $showingConflictAlert) {
            Button("Cancel", role: .cancel) {
                pendingConflict = nil
            }
            Button("Reassign") {
                if let conflict = pendingConflict {
                    resolveMidiConflict(conflict)
                }
                pendingConflict = nil
            }
        } message: {
            if let conflict = pendingConflict {
                Text("MIDI \(conflict.midiKey.kind == .cc ? "CC" : "Note") #\(conflict.midiKey.number) on Channel \(conflict.midiKey.channel) is already used by \"\(conflict.existingOwner)\". Reassign to \"\(conflict.newItem.name)\"? Previous mapping will be removed.")
            }
        }
    }
    
    private func buildMidiTableItems() {
        var items: [MidiTableItem] = []
        
        // Add setlist items
        for song in setlist {
            items.append(MidiTableItem(
                id: song.id,
                name: song.name,
                type: .setlistItem,
                midiType: song.kind,
                channel: song.channel,
                value: song.kind == .cc ? song.cc : (song.note ?? 0)
            ))
        }
        
        // Add control buttons and faders
        for button in controlButtons {
            items.append(MidiTableItem(
                id: button.id,
                name: button.title,
                type: button.isFader == true ? .fader : .button,
                midiType: button.kind,
                channel: button.channel,
                value: button.number
            ))
        }
        
            editableItems = items
            sortEditableItems()
    }
    
    private func applyGlobalChannel() {
        // Apply the global channel to all items
        for index in editableItems.indices {
            editableItems[index].channel = globalChannel
        }
    }
    
    private func handleMidiChange(item: MidiTableItem, newMidiType: MIDIKind, newChannel: Int, newValue: Int) {
        // Check if this creates a conflict
        if let conflict = checkForMidiConflict(item: item, newMidiType: newMidiType, newChannel: newChannel, newValue: newValue) {
            // Show conflict alert
            pendingConflict = conflict
            showingConflictAlert = true
        } else {
            // No conflict, update directly
            if let itemIndex = editableItems.firstIndex(where: { $0.id == item.id }) {
                editableItems[itemIndex].midiType = newMidiType
                editableItems[itemIndex].channel = newChannel
                editableItems[itemIndex].value = newValue
            }
        }
    }
    
    private func checkForMidiConflict(item: MidiTableItem, newMidiType: MIDIKind, newChannel: Int, newValue: Int) -> MidiConflict? {
        let newKey = MIDIKey(kind: newMidiType, channel: newChannel, number: newValue)
        
        // Check against all other items
        for otherItem in editableItems {
            if otherItem.id != item.id {
                let otherKey = MIDIKey(kind: otherItem.midiType, channel: otherItem.channel, number: otherItem.value)
                if otherKey == newKey {
                    return MidiConflict(
                        newItem: item,
                        existingOwner: otherItem.name,
                        midiKey: newKey
                    )
                }
            }
        }
        return nil
    }
    
    private func resolveMidiConflict(_ conflict: MidiConflict) {
        // Find the conflicting item and update it to use a free MIDI value
        if let conflictingIndex = editableItems.firstIndex(where: { 
            let key = MIDIKey(kind: $0.midiType, channel: $0.channel, number: $0.value)
            return key == conflict.midiKey && $0.id != conflict.newItem.id
        }) {
            // Find a free MIDI value for the conflicting item
            let freeValue = findFreeMidiValue(for: editableItems[conflictingIndex].midiType, channel: editableItems[conflictingIndex].channel)
            editableItems[conflictingIndex].value = freeValue
        }
        
        // Update the new item with the desired values
        if let newItemIndex = editableItems.firstIndex(where: { $0.id == conflict.newItem.id }) {
            editableItems[newItemIndex].midiType = conflict.midiKey.kind
            editableItems[newItemIndex].channel = conflict.midiKey.channel
            editableItems[newItemIndex].value = conflict.midiKey.number
        }
    }
    
    private func findFreeMidiValue(for midiType: MIDIKind, channel: Int) -> Int {
        for value in 0...127 {
            let testKey = MIDIKey(kind: midiType, channel: channel, number: value)
            let isUsed = editableItems.contains { item in
                let itemKey = MIDIKey(kind: item.midiType, channel: item.channel, number: item.value)
                return itemKey == testKey
            }
            if !isUsed {
                return value
            }
        }
        return 0 // Fallback
    }
    
    private func getOwnerName(for midiType: MIDIKind, channel: Int, value: Int, excluding excludeId: UUID) -> String? {
        let testKey = MIDIKey(kind: midiType, channel: channel, number: value)
        return editableItems.first { item in
            item.id != excludeId && MIDIKey(kind: item.midiType, channel: item.channel, number: item.value) == testKey
        }?.name
    }
        
        // MARK: - Sorting
        private func toggleSort(_ key: MidiSortKey) {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = true
            }
            sortEditableItems()
        }
        
        @ViewBuilder
        private func sortIndicator(for key: MidiSortKey) -> some View {
            if sortKey == key {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                EmptyView()
            }
        }
        
        private func sortEditableItems() {
            editableItems.sort { a, b in
                switch sortKey {
                case .name:
                    let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                    return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                case .type:
                    let va = a.midiType == .cc ? 0 : 1
                    let vb = b.midiType == .cc ? 0 : 1
                    return sortAscending ? (va, a.name) < (vb, b.name) : (va, a.name) > (vb, b.name)
                case .channel:
                    return sortAscending ? (a.channel, a.name) < (b.channel, b.name) : (a.channel, a.name) > (b.channel, b.name)
                case .value:
                    return sortAscending ? (a.value, a.name) < (b.value, b.name) : (a.value, a.name) > (b.value, b.name)
                }
            }
    }
}

struct MidiTableItem: Identifiable {
    let id: UUID
    let name: String
    let type: MidiItemType
    var midiType: MIDIKind
    var channel: Int
    var value: Int
}

struct MidiConflict {
    let newItem: MidiTableItem
    let existingOwner: String
    let midiKey: MIDIKey
}

enum MidiItemType {
    case setlistItem
    case button
    case fader
    
    var displayName: String {
        switch self {
        case .setlistItem: return "Setlist"
        case .button: return "Button"
        case .fader: return "Fader"
        }
    }
}

// MARK: - MidiValueMenu Component
struct MidiValueMenu: View {
    let item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
    let allowFullCCR: Bool
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID) -> String?
    
    var body: some View {
        Menu {
            if item.midiType == .cc && !allowFullCCR {
                ForEach(1...119, id: \.self) { val in
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    let owner = getOwnerName(item.midiType, channel, val, item.id)
                    let displayText = owner == nil ? "\(val)" : "\(val) (Used by: \(owner!))"
                    Button(displayText) { onMidiChange(item, item.midiType, channel, val) }
                        .foregroundColor(owner == nil ? .primary : .secondary)
                }
            } else {
                ForEach(0...127, id: \.self) { val in
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    let owner = getOwnerName(item.midiType, channel, val, item.id)
                    let displayText = item.midiType == .note ? 
                        (owner == nil ? "\(val) - \(val.midiNoteName)" : "\(val) - \(val.midiNoteName) (Used by: \(owner!))") :
                        (owner == nil ? "\(val)" : "\(val) (Used by: \(owner!))")
                    Button(displayText) { onMidiChange(item, item.midiType, channel, val) }
                        .foregroundColor(owner == nil ? .primary : .secondary)
                }
            }
        } label: {
            HStack(spacing: 4) {
                let displayText = item.midiType == .note ? 
                    "\(item.value) - \(item.value.midiNoteName)" :
                    "\(item.value)"
                Text(displayText)
                    .font(.body)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .id("\(item.id)-\(item.midiType)-\(isGlobalChannel)-\(globalChannel)-\(allowFullCCR)")
    }
}

struct MidiTableRow: View {
    @Binding var item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
        let allowFullCCR: Bool
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID) -> String?
    
    var body: some View {
        HStack(spacing: 0) {
            // Name Column
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                Text(item.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Type Column
            Menu {
                Button("Control Change") {
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    onMidiChange(item, .cc, channel, item.value)
                }
                .disabled(item.type == .fader)
                
                if item.type != .fader {
                    Button("Note") {
                        let channel = isGlobalChannel ? globalChannel : item.channel
                        onMidiChange(item, .note, channel, item.value)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(item.midiType == .cc ? "CC" : "Note")
                        .font(.body)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(item.type == .fader)
            .frame(width: 70, alignment: .center)
            
            // Channel Column (only shown if not global)
            if !isGlobalChannel {
                Menu {
                    ForEach(1...16, id: \.self) { ch in
                        Button("Channel \(ch)") {
                            onMidiChange(item, item.midiType, ch, item.value)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(item.channel)")
                            .font(.body)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 80, alignment: .center)
            }
            
                // Value Column - CC default 1–119; Notes 0–127. Advanced can allow full 0–127 for CC.
            MidiValueMenu(
                item: item,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                allowFullCCR: allowFullCCR,
                onMidiChange: onMidiChange,
                getOwnerName: getOwnerName
            )
            .frame(width: 90, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        }
    }
}

