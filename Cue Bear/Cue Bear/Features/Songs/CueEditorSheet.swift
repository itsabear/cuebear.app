//
//  CueEditorSheet.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation

/// Context for editing a cue - determines button labels and delete behavior
enum CueEditContext {
    case cueList  // Editing from cue list - "Remove" button only removes from list
    case library  // Editing from library - "Delete Cue" button deletes from library
}

struct CBAddEditCueSheet: View {
    @Binding var editingSong: Song?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    let defaultName: String
    var onSave: (Song, Bool) -> Void  // Added Bool parameter for andAddAnother
    var onCancel: () -> Void
    var onDelete: ((Song) -> Void)? = nil  // Remove from cue list only
    var onDeleteFromLibrary: ((Song) -> Void)? = nil  // Delete from library (and all cue lists)
    var onDuplicate: ((Song) -> Void)? = nil  // Callback for duplicating cue
    var editContext: CueEditContext = .library  // Default to library context for backward compatibility

    // Global channel support
    let isGlobalChannel: Bool
    let globalChannel: Int
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 0
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var midiEnabled: Bool = true
    @State private var autoAssign: Bool = true
    @State private var colorHex: String? = nil
    @State private var showColorPicker: Bool = false
    @State private var error: String? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showGlobalModeMaxReachedAlert: Bool = false
    @State private var lastEditingSongID: UUID? = nil  // Track which song we're editing to preserve unsaved changes

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignMIDI") private var savedAutoAssign: Bool = true

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom inline toolbar — outside NavigationView so it moves with the sheet
            cueSheetToolbar

            NavigationView {
            Form {
                    Section(header: Text("SONG").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                        TextField("Name", text: $name, prompt: Text(defaultName).foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme)))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .cbRow()
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    TextField("Subtitle (Tempo/Key/Notes)", text: $subtitle, prompt: Text("Subtitle (Tempo/Key/Notes)").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme)))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .cbRow()
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

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
                                        .overlay(Circle().stroke(CBColor.stroke, lineWidth: 1))
                                } else {
                                    Text("Default")
                                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                }
                            }
                        }
                    )
                    .cbRow()
                }
                Section(header: Text("MIDI").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.cb(.caption))
                            .foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    }
                    Toggle(isOn: $midiEnabled) {
                        Text("Enable MIDI")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .cbRow()

                    if midiEnabled {
                        Toggle(isOn: Binding(
                            get: { autoAssign },
                            set: { newValue in savedAutoAssign = newValue; autoAssign = newValue }
                        )) {
                            Text("Assign MIDI automatically")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                        .cbRow()
                    }

                    if midiEnabled {
                        Picker("Type", selection: $kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        ChannelPicker(title: "Channel", channel: $channel, disabled: false)
                            .cbRow()

                        MIDINumberPicker(
                            kind: kind,
                            number: $number,
                            disabled: autoAssign,
                            channel: channel,
                            currentOwnerName: currentOwnerName,
                            editingControl: nil,
                            editingSong: editingSong,
                            midiFilter: midiFilter
                        )
                        .cbRow()

                        if kind == .note {
                            VelocityPicker(velocity: $velocity, disabled: false)
                                .cbRow()
                        }
                    }
                }
                if let err = error {
                    Text(err).foregroundColor(selectedTheme.errorColor(for: colorScheme))
                        .cbRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationBarHidden(true)
            .tint(selectedTheme.accentColor(for: colorScheme))
            .cbDialog(
                editContext == .cueList ? "Remove Cue" : "Delete Cue",
                isPresented: $showDeleteAlert, themeFont: selectedTheme.font,
                message: editContext == .cueList
                    ? "What would you like to do with '\(name.isEmpty ? defaultName : name)'?"
                    : "Delete '\(name.isEmpty ? defaultName : name)' from the library? This will remove it from all cue lists.",
                buttons: editContext == .cueList
                    ? [
                        .init("Remove from Cue List", role: .secondary) {
                            if let song = editingSong {
                                onDelete?(song)
                                lastEditingSongID = nil
                            }
                        },
                        .init("Delete from Library", role: .destructive) {
                            if let song = editingSong {
                                onDeleteFromLibrary?(song)
                                lastEditingSongID = nil
                            }
                        },
                        .init("Cancel", role: .cancel) { }
                    ]
                    : [
                        .init("Delete", role: .destructive) {
                            if let song = editingSong {
                                onDelete?(song)
                                lastEditingSongID = nil
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
                // Always call preset() to ensure form is properly initialized
                // This handles: editing different songs, switching to/from add mode, and reopening add mode
                debugPrint("🎬 [CUE] Sheet appeared, editingSong: \(editingSong?.name ?? "nil"), lastEditingSongID: \(lastEditingSongID?.uuidString ?? "nil")")
                preset()
                lastEditingSongID = editingSong?.id
            }
            .onChange(of: editingSong) { oldValue, newValue in
                // When editingSong changes, check if we need to preset
                let oldID = oldValue?.id
                let newID = newValue?.id
                if oldID != newID {
                    preset()
                    lastEditingSongID = newID
                }
            }
            .onChange(of: autoAssign) { _, newValue in
                if newValue {
                    let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        autoAssign = false
                    } else {
                        channel = result.channel
                        number = result.number
                    }
                }
            }
            .onChange(of: kind) { _, newValue in
                if autoAssign {
                    let result = autoAssignMIDI(for: newValue, startChannel: channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        autoAssign = false
                    } else {
                        channel = result.channel
                        number = result.number
                    }
                }
            }
            .onChange(of: channel) { _, newValue in
                if autoAssign {
                    let result = autoAssignMIDI(for: kind, startChannel: newValue, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        autoAssign = false
                    } else {
                        channel = result.channel
                        number = result.number
                    }
                }
            }
        } // NavigationView
        } // VStack
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    // MARK: - Custom inline toolbar (replaces system .toolbar for synced sheet animation)
    private var cueSheetToolbar: some View {
        let isDisabled = (midiEnabled && conflictOwner() != nil) || (midiEnabled && midiFiltersEnabled && isFilteredMIDI())
        return HStack {
            Button("Cancel") { onCancel() }
                .font(.cb(.body))
                .foregroundStyle(CBColor.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .cbChip()

            Spacer()

            Text(editingSong == nil ? "Add Cue" : "Edit Cue")
                .font(.cb(.body, .bold))
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            HStack(spacing: 8) {
                // More menu (3 dots)
                Menu {
                    if editingSong == nil {
                        Button {
                            save(andAddAnother: true)
                        } label: {
                            Label("Save & Add Another", systemImage: "plus")
                        }
                        .disabled(isDisabled)
                    } else {
                        // v1.3 (Cue Bear Next): notes, song-only controls, remembered levels.
                        // Closes this sheet (unsaved edits here are discarded) and opens Notes & Extras.
                        if let songID = editingSong?.id {
                            Button {
                                onCancel()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    NotificationCenter.default.post(name: Notification.Name("cbOpenSongDetails"),
                                                                    object: nil, userInfo: ["songID": songID])
                                }
                            } label: {
                                Label("Notes & Extras", systemImage: "music.note.list")
                            }
                        }

                        if onDuplicate != nil {
                            Button {
                                if let song = editingSong {
                                    onDuplicate?(song)
                                }
                            } label: {
                                Label("Duplicate Cue", systemImage: "doc.on.doc")
                            }
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label(editContext == .cueList ? "Remove" : "Delete Cue", systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.cbIcon(.large, .medium))
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .cbChip()

                // Primary action button (checkmark)
                Button {
                    save(andAddAnother: false)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.cbIcon(.large, .semibold))
                        .foregroundColor(isDisabled ? .white.opacity(0.3) : .white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(isDisabled)
                .cbChip()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(selectedTheme.backgroundColor(for: colorScheme))
    }

    private func preset() {
        debugPrint("📋 [CUE] preset() called, editingSong: \(editingSong != nil ? "exists" : "nil")")
        if let s = editingSong {
            name = s.name
            subtitle = s.subtitle ?? ""
            kind = s.kind
            number = (s.kind == .note) ? (s.note ?? 60) : s.cc
            channel = s.channel
            velocity = s.velocity
            colorHex = s.colorHex
            midiEnabled = s.midiEnabled
            autoAssign = false  // editing an existing cue — preserve its MIDI, don't auto-assign
        } else {
            name = ""
            subtitle = ""
            kind = .cc
            colorHex = nil
            // FIX: Use global channel if enabled, otherwise default to 1
            channel = isGlobalChannel ? globalChannel : 1
            velocity = 127
            autoAssign = savedAutoAssign
            if savedAutoAssign {
                // Always start from 0 to find the lowest available (fill gaps first)
                debugPrint("  🆕 [CUE] No editing state, finding lowest available \(kind) on ch\(channel)")
                let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
                if result.reachedLimit {
                    showGlobalModeMaxReachedAlert = true
                    autoAssign = false
                } else {
                    channel = result.channel
                    number = result.number
                    debugPrint("  ✅ [CUE] preset() set channel=\(result.channel), number=\(result.number)")
                }
            }
        }
    }

    // Result type for auto-assign with channel increment support
    private struct AutoAssignResult {
        let channel: Int
        let number: Int
        let reachedLimit: Bool  // true if hit 127 in global mode
    }

    // New auto-assign function that can increment channel when reaching 127
    private func autoAssignMIDI(for kind: MIDIKind, startChannel: Int, startNumber: Int = 0) -> AutoAssignResult {
        debugPrint("🔍 [CUE] Auto-assigning \(kind) starting from channel \(startChannel), number \(startNumber)")
        debugPrint("  📝 [CUE] editingSong: \(editingSong?.name ?? "nil")")

        // In global mode, we can't increment channel
        if isGlobalChannel {
            // Search only on the global channel
            for n in startNumber...127 {
                // Skip filtered CC numbers only when filters are enabled
                if midiFiltersEnabled && kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CUE] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: globalChannel, number: n)
                let owner = currentOwnerName(key)
                debugPrint("  🔍 [CUE] Checking \(n): owner=\(owner ?? "nil")")
                if let owner = owner {
                    if owner != editingSong?.name {
                        debugPrint("  ✗ [CUE] \(n) is taken by '\(owner)', skipping")
                        continue
                    }
                    debugPrint("  ✓ [CUE] \(n) is taken by editing song, available")
                }
                debugPrint("  ✅ [CUE] Assigned: channel \(globalChannel), number \(n)")
                return AutoAssignResult(channel: globalChannel, number: n, reachedLimit: false)
            }
            // Reached limit in global mode
            debugPrint("  ⚠️ [CUE] Reached limit of 127 in global mode")
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
                    debugPrint("  🚫 [CUE] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: currentChannel, number: n)
                let owner = currentOwnerName(key)
                debugPrint("  🔍 [CUE] Checking \(n) on ch\(currentChannel): owner=\(owner ?? "nil")")
                if let owner = owner {
                    if owner != editingSong?.name {
                        debugPrint("  ✗ [CUE] \(n) is taken by '\(owner)', skipping")
                        continue
                    }
                    debugPrint("  ✓ [CUE] \(n) is taken by editing song, available")
                }
                debugPrint("  ✅ [CUE] Assigned: channel \(currentChannel), number \(n)")
                return AutoAssignResult(channel: currentChannel, number: n, reachedLimit: false)
            }

            // Reached end of current channel, increment and start from 0
            debugPrint("  🔄 [CUE] Channel \(currentChannel) full, moving to channel \(currentChannel + 1)")
            currentChannel += 1
            if currentChannel > 16 {
                currentChannel = 1  // Wrap around
            }
            currentNumber = 0  // Reset to start of new channel
        }

        // Exhausted all channels (unlikely but handle it)
        debugPrint("  ⚠️ [CUE] No free slots found across all channels")
        return AutoAssignResult(channel: startChannel, number: 0, reachedLimit: false)
    }

    // Legacy function for compatibility
    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
        return result.number
    }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Get the cue name to filter out - try editingSong first, then fall back to form name
        let cueNameToFilter = (editingSong?.name ?? name).trimmingCharacters(in: .whitespacesAndNewlines)

        debugPrint("🔍 [CONFLICT] Checking conflict: ownersString='\(ownersString)', editingSong?.name='\(editingSong?.name ?? "nil")', form name='\(name)', cueNameToFilter='\(cueNameToFilter)'")

        // Normalize strings for comparison (case-insensitive, trimmed)
        let normalizedOwners = ownersString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCueName = cueNameToFilter

        // Filter out this cue's name from the conflict list
        if !normalizedCueName.isEmpty {
            if ownersString.contains("|||") {
                // Multiple owners - split and filter
                let owners = ownersString.split(separator: "|||")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0 != normalizedCueName }
                guard !owners.isEmpty else {
                    debugPrint("✅ [CONFLICT] All owners filtered out, returning nil")
                    return nil
                }
                debugPrint("⚠️ [CONFLICT] Remaining owners after filter: \(owners)")
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if normalizedOwners == normalizedCueName {
                // Single owner and it's this cue itself
                debugPrint("✅ [CONFLICT] Single owner matches editing cue, returning nil")
                return nil
            }
        }

        debugPrint("❌ [CONFLICT] Returning ownersString: '\(ownersString)'")
        return ownersString
    }

    private func isFilteredMIDI() -> Bool {
        return midiFiltersEnabled && !midiFilter.isEmpty && midiFilter.contains(number)
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing song and checking its current MIDI assignment, no conflict
        if let edit = editingSong {
            let editNumber = (edit.kind == .note) ? (edit.note ?? 60) : edit.cc
            if edit.kind == kind && edit.channel == channel && editNumber == number {
                return nil
            }
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func save(andAddAnother: Bool) {
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? defaultName : trimmed

        var song = editingSong ?? Song(name: finalName, subtitle: subtitle.isEmpty ? nil : subtitle, cc: 0, channel: channel)
        song.name = finalName
        song.subtitle = subtitle.isEmpty ? nil : subtitle
        song.kind = kind
        song.channel = channel
        song.velocity = velocity
        song.colorHex = colorHex
        song.midiEnabled = midiEnabled

        // Set cc or note based on kind
        if kind == .note {
            song.note = number
            song.cc = 0  // Reset cc when using note
        } else {
            song.cc = number
            song.note = nil  // Reset note when using cc
        }

        onSave(song, andAddAnother)

        // Clear the draft tracking since we saved
        lastEditingSongID = nil

        if andAddAnother {
            debugPrint("➕ [CUE] Save & Add Another clicked")
            // CRITICAL FIX: Clear editingSong BEFORE calling autoAssignMIDI
            // This ensures the MIDI we just assigned is now considered "taken"
            let savedName = song.name
            editingSong = nil

            // Calculate next channel and number
            debugPrint("  🔢 [CUE] Calculating next free number (ignoring previously saved '\(savedName)')")
            let nextChannel = isGlobalChannel ? globalChannel : 1
            let savedKind = kind

            // Reset all form fields to defaults
            name = ""
            subtitle = ""
            colorHex = nil
            // v1.0.8: Preserve MIDI kind (CC vs Note) for "Add Another"
            // This ensures next cue uses same MIDI type as the one just saved
            kind = savedKind
            velocity = 127
            autoAssign = savedAutoAssign
            error = nil

            if savedAutoAssign {
                // Find lowest available number (starting from 0 to fill gaps)
                // Uses savedKind to find next available CC or Note number
                let result = autoAssignMIDI(for: savedKind, startChannel: nextChannel, startNumber: 0)
                if result.reachedLimit {
                    showGlobalModeMaxReachedAlert = true
                    autoAssign = false
                    channel = nextChannel
                    number = 0
                } else {
                    channel = result.channel
                    number = result.number
                    debugPrint("  ✅ [CUE] Set channel=\(result.channel), number=\(result.number)")
                }
            } else {
                channel = nextChannel
                number = 0
            }
        }
    }
}

struct CBMIDIPickerSheet: View {
    let title: String
    @State var kind: MIDIKind
    @State var number: Int
    @State var channel: Int
    @State var velocity: Int
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (MIDIKind, Int, Int, Int) -> Void
    var onCancel: () -> Void
    var editingSongName: String? = nil  // Optional: name of song being edited to filter from conflicts

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Control Change").tag(MIDIKind.cc)
                    Text("Note").tag(MIDIKind.note)
                }
                .cbRow()
                Stepper(value: $number, in: 0...127) {
                    Text(kind == .cc ? "CC Number: \(number)" : "Note Number: \(number)")
                }
                .cbRow()
                Stepper(value: $channel, in: 1...16) { Text("Channel: \(channel)") }
                    .cbRow()
                if kind == .note {
                    Stepper(value: $velocity, in: 1...127) { Text("Velocity: \(velocity)") }
                        .cbRow()
                }
                if let owner = conflictOwner() {
                    Text("⚠️ MIDI taken by: \(owner)").foregroundColor(selectedTheme.warningColor(for: colorScheme))
                        .cbRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle(title)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CBSheetButton(title: "Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    CBSheetButton(title: "Save", bold: true, disabled: conflictOwner() != nil) {
                        onSave(kind, number, channel, velocity)
                    }
                }
            }
            .tint(selectedTheme.accentColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else {
            debugPrint("🔍 [MIDI PICKER] No owner found for key")
            return nil
        }

        debugPrint("🔍 [MIDI PICKER] ownersString='\(ownersString)', editingSongName='\(editingSongName ?? "nil")'")

        // Filter out the editing song's name if provided
        guard let editingName = editingSongName else {
            debugPrint("❌ [MIDI PICKER] No editingSongName provided, returning ownersString")
            return ownersString
        }

        // Trim whitespace for comparison
        let trimmedEditingName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOwnersString = ownersString.trimmingCharacters(in: .whitespacesAndNewlines)

        debugPrint("🔍 [MIDI PICKER] Comparing: trimmedOwners='\(trimmedOwnersString)' vs trimmedEditingName='\(trimmedEditingName)'")
        debugPrint("🔍 [MIDI PICKER] Are they equal? \(trimmedOwnersString == trimmedEditingName)")

        // Check if the owners string contains the separator (multiple owners)
        if ownersString.contains("|||") {
            debugPrint("🔍 [MIDI PICKER] Multiple owners detected")
            // Multiple owners - split and filter
            let owners = ownersString.split(separator: "|||")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0 != trimmedEditingName }
            guard !owners.isEmpty else {
                debugPrint("✅ [MIDI PICKER] All owners filtered, returning nil")
                return nil
            }
            debugPrint("⚠️ [MIDI PICKER] Remaining owners: \(owners)")
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if trimmedOwnersString == trimmedEditingName {
            // Single owner and it's the editing song
            debugPrint("✅ [MIDI PICKER] Single owner matches editing song, returning nil")
            return nil
        }

        debugPrint("❌ [MIDI PICKER] No match, returning ownersString: '\(ownersString)'")
        return ownersString
    }
}
