//
//  ControlEditorSheets.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Control Button Editor (moved outside ContentView for scope)
struct CBControlEditorSheet: View {
    @Binding var editing: ControlButton?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    @Binding var pendingIsFader: Bool?
    let isGlobalChannel: Bool
    let globalChannel: Int
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>
    var onSave: (ControlButton, Bool) -> Void  // Added Bool parameter for andAddAnother
    var onCancel: () -> Void
    var onDelete: ((ControlButton) -> Void)? = nil
    var allButtons: [ControlButton] = []  // All control buttons for space validation
    var columns: Int = 8  // Grid column count
    let icons: [String]
    var isEditMode: Bool = false  // Explicit flag: true for editing existing control, false for adding new
    @Binding var canAddMore: Bool  // Whether grid has room for more controls
    @Binding var flashNewForm: Bool  // Visual feedback for "Save & Add Another"

    // v1.0.8: Use ObservedObject draft to preserve edits across sheet dismissals
    @ObservedObject var draft: ControlEditorDraft

    // Color picker inline state
    @State private var showColorPicker = false
    @State private var showPreview = false

    @State private var showDeleteAlert: Bool = false
    @State private var showGlobalModeMaxReachedAlert: Bool = false
    private enum ControlType: String, CaseIterable, Identifiable { case button, fader; var id: String { rawValue } }
    private enum ButtonType: String, CaseIterable, Identifiable { case regular, small; var id: String { rawValue } }
    // UI-only state (not persisted in draft)
    @State private var controlType: ControlType = .button
    @State private var buttonType: ButtonType = .regular
    @State private var showSpaceWarning: Bool = false
    @State private var isOutOfRoom: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignMIDI") private var savedAutoAssign: Bool = true

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

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
            // Fader dimensions depend on orientation (use draft state)
            newWidth = (draft.faderOrientation == "horizontal") ? 2 : 1
            newHeight = (draft.faderOrientation == "horizontal") ? 1 : 2
        } else {
            // Button dimensions depend on button type (use UI state)
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
                return true  // Current position still works (grow right)
            }

            // For buttons growing wider (small → regular): only allow same-row expansion
            if editingButton.isFader != true && newWidth > editingButton.gridWidth {
                // Try growing left: shift col-1
                if col - 1 >= 0 && canFitAtPosition(col: col - 1, row: row, width: newWidth, height: newHeight, excluding: editingButton.id) {
                    return true
                }
                return false  // Can't grow on this row — don't search elsewhere
            }
        }

        // Fader orientation changes can search the full grid
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
            // Use draft state for fader orientation
            width = (draft.faderOrientation == "horizontal") ? 2 : 1
            height = (draft.faderOrientation == "horizontal") ? 1 : 2
        } else {
            // Button - check button type (UI state)
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
            VStack(spacing: 0) {
                // Custom header — bypasses iOS 18+/26 toolbar chrome and gesture caching
                ZStack {
                    Text(titleForSheet())
                        .font(.cb(.body, .bold))
                        .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

                    HStack(spacing: 8) {
                        CBSheetButton(title: "Cancel") {
                            draft.clear()
                            onCancel()
                        }
                        Spacer()
                        let isDisabled = isOutOfRoom || (midiFiltersEnabled && conflictOwner() != nil) || (midiFiltersEnabled && isFilteredMIDI())
                        CBSheetIconMenu(systemName: "ellipsis") {
                            if !isEditMode {
                                Button {
                                    saveControl(andAddAnother: true)
                                } label: {
                                    Label("Save & Add Another", systemImage: "plus")
                                }
                                .disabled(isDisabled)
                            } else {
                                if onDelete != nil {
                                    Button(role: .destructive) {
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        CBSheetIconButton(systemName: "checkmark", disabled: isDisabled) {
                            saveControl(andAddAnother: false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Form {
                    // Out of room warning - shown at top for maximum visibility
                    if isOutOfRoom {
                        Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                            Text(outOfRoomMessage())
                                .font(.cb(.caption))
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                        }
                        .padding(.vertical, 4)
                        .cbRow()
                    }
                }

                Section(header: Text("Appearance")) {
                    // Control type is preselected by the add buttons; hide the picker
                    HStack {
                        TextField("Control Name", text: $draft.title, prompt: Text("Control Name").foregroundStyle(CBColor.textSecondary))
                        if !draft.title.isEmpty {
                            Button(action: { draft.title = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(CBColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cbRow()

                    // Button Type picker - only show for buttons (not faders)
                    if !draft.isFader {
                        Picker("Button Type", selection: Binding(
                            get: { draft.isSmall ? ButtonType.small : ButtonType.regular },
                            set: { draft.isSmall = ($0 == .small) }
                        )) {
                            Text("Button").tag(ButtonType.regular)
                            Text("Small Button").tag(ButtonType.small)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        // Show space warning if button type change won't fit
                        if showSpaceWarning {
                            Text("You're out of room! Try removing other controllers to change button size")
                                .font(.cb(.caption))
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                .padding(.top, 4)
                                .cbRow()
                        }
                    }

                    if !draft.isFader {
                        IconPicker(symbol: $draft.symbol, icons: icons)
                            .cbRow()
                        Picker("Behavior", selection: $draft.isToggle) {
                            Text("Momentary").tag(false)
                            Text("Toggle").tag(true)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    // Fader orientation and direction (only for faders)
                    if draft.isFader {
                        Picker("Fader Orientation", selection: $draft.faderOrientation) {
                            Text("Vertical").tag("vertical")
                            Text("Horizontal").tag("horizontal")
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        Picker("Fader Direction", selection: $draft.faderDirection) {
                            // Vertical faders: only up/down
                            if draft.faderOrientation == "vertical" {
                                Text("Up").tag("up")
                                Text("Down").tag("down")
                            }
                            // Horizontal faders: only left/right
                            else if draft.faderOrientation == "horizontal" {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                            }
                        }
                        .id("fader-direction-picker")
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        // Show space warning if orientation change won't fit
                        if showSpaceWarning {
                            Text("You're out of room! Try removing other controllers to add this one")
                                .font(.cb(.caption))
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                .padding(.top, 4)
                                .cbRow()
                        }
                    }

                    // Color Picker - Inline Disclosure
                    DisclosureGroup(
                        isExpanded: $showColorPicker,
                        content: {
                            // Inline color picker
                            CBColorPickerInline(selectedColorHex: $draft.colorHex)
                                .padding(.vertical, 8)
                        },
                        label: {
                            HStack {
                                Text("Color")
                                Spacer()
                                if let hex = draft.colorHex {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                } else {
                                    Text("Default")
                                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                }
                            }
                        }
                    )
                    .cbRow()
                }
                // Live Preview - Collapsible
                Section {
                    DisclosureGroup(
                        isExpanded: $showPreview,
                        content: {
                            HStack {
                                Spacer(minLength: 0)
                                if draft.isFader {
                                    ControlFaderPreview(title: draft.title, cc: draft.number, channel: draft.channel, orientation: draft.faderOrientation, direction: draft.faderDirection, colorHex: draft.colorHex)
                                        .id("fader-\(draft.faderOrientation)-\(draft.faderDirection)")
                                } else {
                                    ControlButtonPreview(title: draft.title, symbol: draft.symbol, kind: draft.kind, number: draft.number, channel: draft.channel, velocity: draft.velocity, isSmall: draft.isSmall, colorHex: draft.colorHex)
                                        .id("button-\(draft.isSmall)")
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                        },
                        label: {
                            Text("Preview")
                        }
                    )
                    .cbRow()
                }
                Section(header: Text("MIDI")) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.cb(.caption))
                            .foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    }
                    Toggle(isOn: Binding(
                        get: { draft.autoAssign },
                        set: { newValue in savedAutoAssign = newValue; draft.autoAssign = newValue }
                    )) {
                        Text("Assign MIDI automatically")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .cbRow()
                    if !draft.isFader {
                        Picker("Type", selection: $draft.kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }
                    if isGlobalChannel {
                        HStack {
                            Text("Channel")
                            Spacer()
                            Text("\(globalChannel) (Global Channel)")
                                .foregroundStyle(CBColor.textSecondary)
                        }
                        .cbRow()
                    } else {
                        ChannelPicker(title: "Channel", channel: $draft.channel, disabled: false)
                            .cbRow()
                    }
                    MIDINumberPicker(
                        kind: draft.kind,
                        number: $draft.number,
                        disabled: draft.autoAssign,
                        channel: isGlobalChannel ? globalChannel : draft.channel,
                        currentOwnerName: currentOwnerName,
                        editingControl: editing,
                        midiFilter: midiFilter
                    )
                    .cbRow()
                    if !draft.isFader && draft.kind == .note {
                        VelocityPicker(velocity: $draft.velocity, disabled: false)
                            .cbRow()
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            }
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .tint(selectedTheme.accentColor(for: colorScheme))
            .cbDialog("Delete Control", isPresented: $showDeleteAlert, themeFont: selectedTheme.font,
                message: "Are you sure you want to delete this \(controlType == .fader ? "fader" : (buttonType == .small ? "small button" : "button"))? This action cannot be undone.",
                buttons: [
                    .init("Delete", role: .destructive) {
                        if let control = editing {
                            onDelete?(control)
                        }
                    },
                    .init("Cancel", role: .cancel) { }
                ]
            )
            .cbDialog("Maximum Controls Reached", isPresented: $showGlobalModeMaxReachedAlert, themeFont: selectedTheme.font,
                message: "You've reached the maximum of 127 controls in Global MIDI Channel mode. Turn off Global MIDI Channel mode to continue auto-assigning on additional channels.",
                buttons: [
                    .init("OK", role: .primary) { }
                ]
            )
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
            .onChange(of: draft.autoAssign) { _, newValue in
                if newValue {
                    let result = autoAssignMIDI(for: draft.kind, startChannel: draft.channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        draft.autoAssign = false  // Turn off auto-assign since we hit the limit
                    } else {
                        draft.channel = result.channel
                        draft.number = result.number
                    }
                }
            }
            .onChange(of: draft.kind) { _, newValue in
                if draft.autoAssign {
                    let result = autoAssignMIDI(for: newValue, startChannel: draft.channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        draft.autoAssign = false
                    } else {
                        draft.channel = result.channel
                        draft.number = result.number
                    }
                }
            }
            .onChange(of: draft.channel) { _, newValue in
                if draft.autoAssign {
                    let result = autoAssignMIDI(for: draft.kind, startChannel: newValue, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        draft.autoAssign = false
                    } else {
                        draft.channel = result.channel
                        draft.number = result.number
                    }
                }
            }
            .onChange(of: controlType) { _, newType in
                if newType == .fader { draft.kind = .cc }
                pendingIsFader = (newType == .fader)
                // Re-validate space when control type changes
                isOutOfRoom = !validateSpaceForAddMode()
            }
            .onChange(of: draft.faderOrientation) { _, newOrientation in
                // Auto-set appropriate direction when orientation changes
                if newOrientation == "vertical" && (draft.faderDirection == "left" || draft.faderDirection == "right") {
                    draft.faderDirection = "up"
                } else if newOrientation == "horizontal" && (draft.faderDirection == "up" || draft.faderDirection == "down") {
                    draft.faderDirection = "right"
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
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func preset() {
        debugPrint("📋 [CONTROL] preset() called, editing: \(editing != nil ? "exists" : "nil"), isEditMode: \(isEditMode)")
        if let b = editing {
            // v1.0.8: Check if draft has been modified from the original control
            // If draft matches original, load from control (first open or after cancel)
            // If draft differs from original, preserve draft (user made changes and tapped outside)
            let draftMatchesOriginal = (
                draft.title == b.title &&
                draft.symbol == b.symbol &&
                draft.kind == b.kind &&
                draft.number == b.number &&
                draft.channel == b.channel
            )

            if draftMatchesOriginal || draft.title.isEmpty {
                // Draft is empty or matches original - safe to load from editing button
                debugPrint("  📝 [CONTROL] Loading from editing button (isEditMode=\(isEditMode), draftMatchesOriginal=\(draftMatchesOriginal))")
                draft.loadFrom(control: b)
            } else {
                // Draft has user modifications - preserve them
                debugPrint("  💾 [CONTROL] Preserving modified draft content, NOT loading from editing button")
            }

            // Determine control type from button properties (for UI-only state)
            if b.isFader == true {
                controlType = .fader
            } else {
                controlType = .button
                buttonType = (b.isSmall == true) ? .small : .regular
            }

            if isEditMode {
                draft.autoAssign = false  // editing existing control — preserve its MIDI, don't auto-assign
            } else {
                // ADD mode: auto-assign only if draft was just loaded from template
                if draftMatchesOriginal || draft.title.isEmpty {
                    draft.autoAssign = savedAutoAssign
                    if savedAutoAssign {
                        let nextChannel = isGlobalChannel ? globalChannel : draft.channel
                        let result = autoAssignMIDI(for: draft.kind, startChannel: nextChannel, startNumber: 0)
                        if result.reachedLimit {
                            showGlobalModeMaxReachedAlert = true
                            draft.autoAssign = false
                        } else {
                            draft.channel = result.channel
                            draft.number = result.number
                            debugPrint("  ✅ [CONTROL] ADD mode - set autoAssign=\(savedAutoAssign), channel=\(result.channel), number=\(result.number)")
                        }
                    }
                } else {
                    debugPrint("  ✅ [CONTROL] ADD mode - preserving draft autoAssign=\(draft.autoAssign)")
                }
            }
        } else {
            // v1.0.8: Clear draft for new control
            // Check if this is "Add Another" by seeing if number is already set to a valid value
            if draft.number > 0 {
                // "Add Another" already set the correct number - DON'T recalculate!
                debugPrint("  🎯 [CONTROL] Number already set by 'Add Another': \(draft.number), skipping recalculation")
                return
            }

            // This is a fresh "Add Control" (not "Add Another")
            draft.clear()
            draft.autoAssign = savedAutoAssign
            // FIX: Use global channel if enabled, otherwise default to 1
            let nextChannel = isGlobalChannel ? globalChannel : 1
            debugPrint("  🆕 [CONTROL] No editing state, finding free number for \(draft.kind) ch\(nextChannel)")
            if savedAutoAssign {
                let result = autoAssignMIDI(for: draft.kind, startChannel: nextChannel, startNumber: 0)
                if result.reachedLimit {
                    showGlobalModeMaxReachedAlert = true
                    draft.autoAssign = false
                } else {
                    draft.channel = result.channel
                    draft.number = result.number
                    debugPrint("  ✅ [CONTROL] preset() set channel=\(result.channel), number=\(result.number)")
                }
            } else {
                draft.channel = nextChannel
            }
        }
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
        if let edit = editing, edit.kind == draft.kind, edit.channel == draft.channel, edit.number == draft.number {
            return nil
        }
        let key = MIDIKey(kind: draft.kind, channel: draft.channel, number: draft.number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the current control's name if editing
        if let edit = editing {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }
            return filterOwnerName(ownersString, excluding: editDisplayName)
        }

        return ownersString
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing control and checking its current MIDI assignment, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the current control's name if editing
        if let edit = editing {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }
            return filterOwnerName(ownersString, excluding: editDisplayName)
        }

        return ownersString
    }

    private func filterOwnerName(_ ownersString: String, excluding excludeName: String) -> String? {
        // Check if the owners string contains the separator (multiple owners)
        if ownersString.contains("|||") {
            // Multiple owners - need to filter
            let owners = ownersString.split(separator: "|||").map(String.init).filter { $0 != excludeName }
            guard !owners.isEmpty else { return nil }
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if ownersString == excludeName {
            // Single owner and it's us
            return nil
        }
        return ownersString
    }

    private func isFilteredMIDI() -> Bool {
        return midiFiltersEnabled && !midiFilter.isEmpty && draft.kind == .cc && midiFilter.contains(draft.number)
    }

    private func assignFreeNumber() {
        draft.number = firstFreeNumber(for: draft.kind, channel: draft.channel)
    }

    // Result type for auto-assign with channel increment support
    private struct AutoAssignResult {
        let channel: Int
        let number: Int
        let reachedLimit: Bool  // true if hit 127 in global mode
    }

    // New auto-assign function that can increment channel when reaching 127
    private func autoAssignMIDI(for kind: MIDIKind, startChannel: Int, startNumber: Int = 0) -> AutoAssignResult {
        debugPrint("🔍 [CONTROL] Auto-assigning \(kind) starting from channel \(startChannel), number \(startNumber)")

        // In global mode, we can't increment channel
        if isGlobalChannel {
            // Search only on the global channel
            for n in startNumber...127 {
                // Skip filtered CC numbers only when filters are enabled
                if midiFiltersEnabled && kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CONTROL] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: globalChannel, number: n)
                let owner = currentOwnerName(key)
                if owner != nil {
                    // Skip if occupied by a different control
                    if let edit = editing, edit.kind == kind, edit.channel == globalChannel, edit.number == n {
                        debugPrint("  ✓ [CONTROL] \(n) is taken by editing control, available")
                        debugPrint("  ✅ [CONTROL] Assigned: channel \(globalChannel), number \(n)")
                        return AutoAssignResult(channel: globalChannel, number: n, reachedLimit: false)
                    } else {
                        debugPrint("  ✗ [CONTROL] \(n) is taken by '\(owner!)', skipping")
                        continue
                    }
                }
                debugPrint("  ✅ [CONTROL] Assigned: channel \(globalChannel), number \(n)")
                return AutoAssignResult(channel: globalChannel, number: n, reachedLimit: false)
            }
            // Reached limit in global mode
            debugPrint("  ⚠️ [CONTROL] Reached limit of 127 in global mode")
            return AutoAssignResult(channel: globalChannel, number: 0, reachedLimit: true)
        }

        // Non-global mode: can increment channel when reaching 127
        var currentChannel = startChannel
        var currentNumber = startNumber

        // Try up to 16 channels
        for _ in 0..<16 {
            // Search from currentNumber to 127 on current channel
            for n in currentNumber...127 {
                // Skip filtered CC numbers only when filters are enabled
                if midiFiltersEnabled && kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CONTROL] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: currentChannel, number: n)
                let owner = currentOwnerName(key)
                if owner != nil {
                    // Skip if occupied by a different control
                    if let edit = editing, edit.kind == kind, edit.channel == currentChannel, edit.number == n {
                        debugPrint("  ✓ [CONTROL] \(n) is taken by editing control, available")
                        debugPrint("  ✅ [CONTROL] Assigned: channel \(currentChannel), number \(n)")
                        return AutoAssignResult(channel: currentChannel, number: n, reachedLimit: false)
                    } else {
                        debugPrint("  ✗ [CONTROL] \(n) is taken by '\(owner!)', skipping")
                        continue
                    }
                }
                debugPrint("  ✅ [CONTROL] Assigned: channel \(currentChannel), number \(n)")
                return AutoAssignResult(channel: currentChannel, number: n, reachedLimit: false)
            }

            // Reached end of current channel, increment and start from 0
            debugPrint("  🔄 [CONTROL] Channel \(currentChannel) full, moving to channel \(currentChannel + 1)")
            currentChannel += 1
            if currentChannel > 16 {
                currentChannel = 1  // Wrap around
            }
            currentNumber = 0  // Reset to start of new channel
        }

        // Exhausted all channels (unlikely but handle it)
        debugPrint("  ⚠️ [CONTROL] No free slots found across all channels")
        return AutoAssignResult(channel: startChannel, number: 0, reachedLimit: false)
    }

    // Legacy function for compatibility - uses new auto-assign logic
    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
        return result.number
    }

    private func firstFreeNumberStartingFrom(_ start: Int, for kind: MIDIKind, channel: Int) -> Int {
        let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: start)
        return result.number
    }

    private func saveControl(andAddAnother: Bool) {
        var b = editing ?? ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: 0, channel: 1, velocity: 127, isToggle: nil)
        b.title = draft.title
        b.symbol = draft.symbol
        b.kind = (controlType == .fader) ? .cc : draft.kind
        b.number = draft.number
        // Use global channel if enabled, otherwise use the selected channel
        b.channel = isGlobalChannel ? globalChannel : draft.channel
        b.velocity = draft.velocity
        b.isToggle = draft.isToggle
        b.isFader = (controlType == .fader)
        b.colorHex = draft.colorHex

        // Auto-name only for NEW buttons (not when editing existing ones)
        // This allows users to explicitly set empty titles for icon-only buttons
        if b.title.trimmingCharacters(in: .whitespaces).isEmpty && editing == nil {
            if controlType == .fader {
                // Count existing faders
                let faderCount = allButtons.filter { $0.isFader == true && $0.id != b.id }.count
                b.title = "Fader \(faderCount + 1)"
            } else {
                // Count existing buttons
                let buttonCount = allButtons.filter { $0.isFader != true && $0.id != b.id }.count
                b.title = "Button \(buttonCount + 1)"
            }
        }

        debugPrint("💾 Saving control '\(b.title)' with colorHex: \(draft.colorHex ?? "nil")")
        // v1.0.9: Set isSmall from draft (picker updates draft.isSmall directly)
        if controlType != .fader {
            b.isSmall = draft.isSmall
        }

        // Save fader orientation and direction (only for faders)
        if controlType == .fader {
            b.faderOrientation = draft.faderOrientation
            b.faderDirection = draft.faderDirection

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
                let newWidth = b.gridWidth
                let newHeight = b.gridHeight

                // If growing wider (small → regular), use same-row right-first, left-second logic
                if newWidth > oldWidth {
                    if let col = b.gridCol, let row = b.gridRow {
                        if canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Grow right — position stays the same
                            debugPrint("🔄 Button growing right at (\(col), \(row))")
                        } else if col - 1 >= 0 && canFitAtPosition(col: col - 1, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Grow left — shift col by -1
                            b.gridCol = col - 1
                            debugPrint("🔄 Button growing left from (\(col), \(row)) to (\(col - 1), \(row))")
                        } else {
                            debugPrint("⚠️ No room to grow button - validation should have prevented this")
                        }
                    }
                }
                // Shrinking (regular → small): keep current position, no reposition needed
            }
        }

        onSave(b, andAddAnother)

        if andAddAnother {
            debugPrint("➕ [CONTROL] Save & Add Another clicked")

            // v1.0.8: Reset draft for next control

            // Calculate next channel and number BEFORE resetting draft
            debugPrint("  🔢 [CONTROL] Calculating next free number BEFORE resetting draft")
            let nextChannel = isGlobalChannel ? globalChannel : 1
            let savedNumber = b.number
            let savedKind = b.kind

            // Clear draft to defaults
            draft.clear()

            // v1.0.8: Preserve MIDI kind (CC vs Note) for "Add Another"
            // This ensures next control uses same MIDI type as the one just saved
            draft.kind = savedKind

            // Preserve fader state if we're adding faders
            if controlType == .fader {
                draft.isFader = true
                // Fader orientation and direction are preserved from previous draft values
                draft.faderOrientation = b.faderOrientation ?? "vertical"
                draft.faderDirection = b.faderDirection ?? "up"
            } else {
                // Preserve button size if we're adding buttons
                draft.isSmall = b.isSmall ?? false
                draft.isToggle = b.isToggle ?? false
            }

            // Set channel and find next free number (with channel increment if needed)
            draft.autoAssign = savedAutoAssign
            if savedAutoAssign {
                // FIX: After saving, find next free number starting from the one we just saved + 1
                let result = autoAssignMIDI(for: savedKind, startChannel: nextChannel, startNumber: savedNumber + 1)
                if result.reachedLimit {
                    showGlobalModeMaxReachedAlert = true
                    draft.autoAssign = false
                    draft.channel = nextChannel
                    draft.number = 0
                } else {
                    draft.channel = result.channel
                    draft.number = result.number
                    debugPrint("  ✅ [CONTROL] Set kind=\(savedKind), channel=\(result.channel), number=\(result.number)")
                }
            } else {
                draft.channel = nextChannel
                draft.number = 0
            }

            // NOW set editing to nil (triggers .onChange which calls preset())
            debugPrint("  🔄 [CONTROL] Setting editing=nil (will trigger .onChange)")
            editing = nil

            // Recalculate space validation after reset
            isOutOfRoom = !validateSpaceForAddMode()
        } else {
            // Why: shared draft persists across sheet presentations. Without clearing,
            // a subsequent edit of a different control sees a non-empty, non-matching
            // draft and preset() chooses to preserve it — so button B opens showing
            // button A's title/MIDI. The next save then writes A's data into B's slot.
            draft.clear()
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
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignMIDI") private var savedAutoAssign: Bool = true

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    @State private var title: String = ""
    @State private var symbol: String = "square.grid.2x2.fill"
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 0
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var autoAssign: Bool = true
    @State private var isToggle: Bool = false
    @State private var isFaderUI: Bool = false
    @State private var isSmall: Bool = false  // Track small button state for preview
    @State private var showDeleteAlert: Bool = false
    // Fader orientation and direction
    @State private var faderOrientation: String = "vertical"
    @State private var faderDirection: String = "up"
    @State private var colorHex: String? = nil  // Custom color for button/fader
    @State private var showColorPicker: Bool = false
    @State private var showPreview: Bool = false
    @State private var userDismissedExplicitly: Bool = false  // v1.0.8: Track Save/Cancel clicks

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    // Control type is not editable - just show what it is
                    HStack {
                        Text("Control Type")
                        Spacer()
                        Text(isFaderUI ? "Fader" : "Button")
                            .foregroundStyle(CBColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .cbRow()
                    if !isFaderUI {
                        Toggle("Small Button", isOn: $isSmall)
                            .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                            .cbRow()
                    }
                    HStack {
                        TextField("Control Name", text: $title, prompt: Text("Control Name").foregroundStyle(CBColor.textSecondary))
                        if !title.isEmpty {
                            Button(action: { title = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(CBColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cbRow()
                    if !isFaderUI {
                        IconPicker(symbol: $symbol, icons: icons)
                            .cbRow()
                        Picker("Behavior", selection: $isToggle) {
                            Text("Momentary").tag(false)
                            Text("Toggle").tag(true)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    // Fader orientation and direction (only for faders)
                    if isFaderUI {
                        Picker("Fader Orientation", selection: $faderOrientation) {
                            Text("Vertical").tag("vertical")
                            Text("Horizontal").tag("horizontal")
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        Picker("Fader Direction", selection: $faderDirection) {
                            // Vertical faders: only up/down
                            if faderOrientation == "vertical" {
                                Text("Up").tag("up")
                                Text("Down").tag("down")
                            }
                            // Horizontal faders: only left/right
                            else if faderOrientation == "horizontal" {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                            }
                        }
                        .id("fader-direction-picker-edit")
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    // Color Picker - Inline Disclosure
                    DisclosureGroup(
                        isExpanded: $showColorPicker,
                        content: {
                            // Inline color picker
                            CBColorPickerInline(selectedColorHex: $colorHex)
                                .padding(.vertical, 8)
                        },
                        label: {
                            HStack {
                                Text("Color")
                                Spacer()
                                if let hex = colorHex {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                } else {
                                    Text("Default")
                                        .foregroundStyle(CBColor.textSecondary)
                                }
                            }
                        }
                    )
                    .tint(.secondary)
                    .cbRow()
                }
                // Live Preview - Collapsible
                Section {
                    DisclosureGroup(
                        isExpanded: $showPreview,
                        content: {
                            HStack {
                                Spacer(minLength: 0)
                                if isFaderUI {
                                    ControlFaderPreview(title: title, cc: number, channel: channel, orientation: faderOrientation, direction: faderDirection, colorHex: colorHex)
                                } else {
                                    ControlButtonPreview(title: title, symbol: symbol, kind: kind, number: number, channel: channel, velocity: velocity, isSmall: isSmall, colorHex: colorHex)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                        },
                        label: {
                            Text("Preview")
                        }
                    )
                    .cbRow()
                }
                Section(header: Text("MIDI")) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.cb(.caption))
                            .foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    }
                    Toggle(isOn: Binding(
                        get: { autoAssign },
                        set: { newValue in savedAutoAssign = newValue; autoAssign = newValue }
                    )) {
                        Text("Assign MIDI automatically")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .cbRow()
                    if !isFaderUI {
                        Picker("Type", selection: $kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }
                    ChannelPicker(title: "Channel", channel: $channel, disabled: false)
                        .cbRow()
                    MIDINumberPicker(
                        kind: kind,
                        number: $number,
                        disabled: autoAssign,
                        channel: channel,
                        currentOwnerName: currentOwnerName,
                        editingControl: editing,
                        midiFilter: midiFilter
                    )
                    .cbRow()
                    if !isFaderUI && kind == .note {
                        VelocityPicker(velocity: $velocity, disabled: false)
                            .cbRow()
                    }
                }

                // Delete section - always show when editing existing control
                if onDelete != nil {
                    Section {
                        DestructiveWideButton(
                            title: isFaderUI ? "Delete Fader" : "Delete Button",
                            action: { showDeleteAlert = true }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .navigationTitle(isFaderUI ? "Edit Fader" : "Edit Button")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .tint(selectedTheme.accentColor(for: colorScheme))
            .cbDialog("Delete Control", isPresented: $showDeleteAlert, themeFont: selectedTheme.font,
                message: "Are you sure you want to delete this \(isFaderUI ? "fader" : "button")? This action cannot be undone.",
                buttons: [
                    .init("Delete", role: .destructive) {
                        if let control = editing {
                            onDelete?(control)
                        }
                    },
                    .init("Cancel", role: .cancel) { }
                ]
            )
            .navigationBarItems(
                leading: Button("Cancel") {
                    userDismissedExplicitly = true  // v1.0.8: Mark as explicit dismissal
                    onCancel()
                },
                trailing: saveButton
            )
            .onAppear {
                userDismissedExplicitly = false  // v1.0.8: Reset on appear
                preset()
            }
            .onDisappear {
                // v1.0.8: Auto-save if dismissed by tapping outside (not Cancel/Save)
                if !userDismissedExplicitly && !title.isEmpty && conflictOwner() == nil && !isFilteredMIDI() {
                    debugPrint("📝 [SHEET] Edit control dismissed by outside-tap - auto-saving")
                    saveEdit()
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
            .onChange(of: faderOrientation) { _, newOrientation in
                // Auto-set appropriate direction when orientation changes
                if newOrientation == "vertical" && (faderDirection == "left" || faderDirection == "right") {
                    faderDirection = "up"
                } else if newOrientation == "horizontal" && (faderDirection == "up" || faderDirection == "down") {
                    faderDirection = "right"
                }
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private var saveButton: some View {
        let isDisabled = title.isEmpty || conflictOwner() != nil || isFilteredMIDI()
        return Button("Save") {
            userDismissedExplicitly = true  // v1.0.8: Mark as explicit dismissal
            saveEdit()
        }
        .foregroundColor(isDisabled ? Color.gray.opacity(0.5) : selectedTheme.accentColor(for: colorScheme))
        .disabled(isDisabled)
    }

    // v1.0.8: Extract save logic to function for reuse in onDisappear
    private func saveEdit() {
        if var b = editing {
            b.title = title
            b.symbol = symbol
            b.kind = isFaderUI ? .cc : kind
            b.number = number
            b.channel = channel
            b.velocity = velocity
            b.isToggle = isToggle
            b.isFader = isFaderUI
            if !isFaderUI { b.isSmall = isSmall } else { b.isSmall = false }
            b.colorHex = colorHex  // Save color

            // Save fader orientation and direction (only for faders)
            if isFaderUI {
                b.faderOrientation = faderOrientation
                b.faderDirection = faderDirection
            }

            onSave(b)
        }
    }

    private func preset() {
        guard let b = editing else {
            autoAssign = savedAutoAssign
            return
        }
        title = b.title
        symbol = b.symbol
        kind = b.kind
        number = b.number
        channel = b.channel
        velocity = b.velocity
        autoAssign = savedAutoAssign
        isToggle = b.isToggle ?? false
        isFaderUI = b.isFader ?? false
        isSmall = b.isSmall ?? false  // Load small button state for preview
        colorHex = b.colorHex  // Load color

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

    private func isFilteredMIDI() -> Bool {
        return midiFiltersEnabled && !midiFilter.isEmpty && kind == .cc && midiFilter.contains(number)
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing control and checking its current MIDI assignment, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the current control's name if editing
        if let edit = editing {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }

            // Check if the owners string contains the separator (multiple owners)
            if ownersString.contains("|||") {
                // Multiple owners - need to filter
                let owners = ownersString.split(separator: "|||").map(String.init).filter { $0 != editDisplayName }
                guard !owners.isEmpty else { return nil }
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if ownersString == editDisplayName {
                // Single owner and it's us
                return nil
            }
        }

        return ownersString
    }

    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        for n in 0...127 {
            // Skip filtered CC numbers when filters are enabled
            if kind == .cc && midiFiltersEnabled && midiFilter.contains(n) {
                continue
            }
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
    var colorHex: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var midiLabel: String {
        kind == .cc ? "\(channel)•\(number)" : "\(channel)•\(number)•\(velocity)"
    }

    private var buttonColor: Color {
        if let hex = colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        // Use custom accent color if set, otherwise theme default
        if !customDefaultCueColorStorage.isEmpty {
            return Color(hex: customDefaultCueColorStorage)
        }
        return selectedTheme.defaultCueColor(for: colorScheme)
    }

    var body: some View {
        // Match real button dimensions: regular is 2 cells wide (2*cellSize + 12 spacing), small is 1 cell (cellSize x cellSize)
        // Using preview cellSize of 72 to match the aspect ratio of real buttons in the grid
        let previewCellSize: CGFloat = 72
        let columnSpacing: CGFloat = 12
        let frameWidth: CGFloat = isSmall ? previewCellSize : (2 * previewCellSize + columnSpacing)
        let frameHeight: CGFloat = previewCellSize
        let corner: CGFloat = 8

        let textColor: Color = buttonColor.needsDarkText() ? .black : .white

        return VStack(spacing: 4) {
            Spacer(minLength: 0)
            if symbol.isEmpty {
                // Text only
                Text(title.isEmpty ? "Custom" : title)
                    .font(.cb(.small, .bold))
                    .foregroundColor(textColor)
                Text(midiLabel)
                    .font(.cb(.micro))
                    .foregroundColor(textColor.opacity(0.5))
            } else if title.isEmpty {
                // Icon only
                Image(systemName: symbol)
                    .font(.cbIcon(.title, .semibold))
                    .foregroundColor(textColor)
                Text(midiLabel)
                    .font(.cb(.micro))
                    .foregroundColor(textColor.opacity(0.5))
            } else {
                // Icon + text
                Image(systemName: symbol)
                    .font(.cbIcon(.title, .semibold))
                    .foregroundColor(textColor)
                Text(title)
                    .font(.cb(.caption, .bold))
                    .foregroundColor(textColor)
                Text(midiLabel)
                    .font(.cb(.micro))
                    .foregroundColor(textColor.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .frame(width: frameWidth, height: frameHeight)
        .background(
            RoundedRectangle(cornerRadius: corner)
                .fill(buttonColor.opacity(0.9))
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
    var colorHex: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var faderColor: Color {
        if let hex = colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        // Use custom accent color if set, otherwise theme default
        if !customDefaultCueColorStorage.isEmpty {
            return Color(hex: customDefaultCueColorStorage)
        }
        return selectedTheme.defaultCueColor(for: colorScheme)
    }

    private var textColor: Color {
        faderColor.needsDarkText() ? .black : .white
    }

    var body: some View {
        let isHorizontal = (orientation == "horizontal")
        let previewValue: Double = 0.66  // Preview at 66% position

        if isHorizontal {
            // HORIZONTAL FADER PREVIEW — filled style with 8pt corners
            let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

            ZStack(alignment: fillAlignment) {
                // Track background
                RoundedRectangle(cornerRadius: CBRadius.small)
                    .fill(faderColor.opacity(0.2))

                // Fill level
                GeometryReader { geo in
                    HStack {
                        if direction != "right" { Spacer() }
                        RoundedRectangle(cornerRadius: CBRadius.small)
                            .fill(faderColor.opacity(0.85))
                            .frame(width: geo.size.width * previewValue)
                        if direction == "right" { Spacer() }
                    }
                }

                // Labels overlay
                HStack {
                    Text(title.isEmpty ? "Fader" : title)
                        .font(.cb(.caption, .bold))
                        .foregroundColor(textColor)
                        .padding(.leading, 8)
                    Spacer()
                    Text("\(channel)•\(cc)")
                        .font(.cb(.micro))
                        .foregroundColor(textColor.opacity(0.5))
                        .padding(.trailing, 8)
                }
            }
            .frame(width: 156, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: CBRadius.small))
        } else {
            // VERTICAL FADER PREVIEW — filled style with 8pt corners
            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: CBRadius.small)
                    .fill(faderColor.opacity(0.2))

                // Fill level
                GeometryReader { geo in
                    VStack {
                        if direction == "up" { Spacer() }
                        RoundedRectangle(cornerRadius: CBRadius.small)
                            .fill(faderColor.opacity(0.85))
                            .frame(height: geo.size.height * previewValue)
                        if direction != "up" { Spacer() }
                    }
                }

                // Labels overlay
                VStack(spacing: 2) {
                    Text(title.isEmpty ? "Fader" : title)
                        .font(.cb(.caption, .bold))
                        .foregroundColor(textColor)
                    Text("\(channel)•\(cc)")
                        .font(.cb(.micro))
                        .foregroundColor(textColor.opacity(0.5))
                }
                .padding(.bottom, 8)
            }
            .frame(width: 72, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: CBRadius.small))
        }
    }
}
