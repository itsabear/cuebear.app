//
//  MidiAssignments.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - MIDI Table Sheet
struct MidiTableSheet: View {
    let setlist: [Song]
    @Binding var controlButtons: [ControlButton]
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    @Binding var midiFiltersEnabled: Bool
    @Binding var midiFilter: Set<Int>
    @Binding var customMidiFilters: [(Int, String)]
    var onDismiss: () -> Void
        var onApply: (([MidiTableItem]) -> Void)? = nil

    @State private var editableItems: [MidiTableItem] = []
    @State private var showingConflictAlert = false
    @State private var pendingConflict: MidiConflict? = nil
        @State private var sortKey: MidiSortKey = .name
        @State private var sortAscending: Bool = true
        @State private var allowFullCCR: Bool = false

        enum MidiSortKey { case name, type, channel, value }

    @State private var showMidiAssignmentsSheet = false

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            Form {
                // Section 1: Global MIDI Channel
                Section {
                    Toggle("Global MIDI Channel", isOn: $isGlobalChannel)
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                        .cbRow()

                    if isGlobalChannel {
                        ChannelPicker(title: "Channel", channel: $globalChannel, disabled: false)
                            .cbRow()
                    }
                } footer: {
                    Text("When enabled, all cues and controls will be assigned to the same MIDI channel. When disabled, each item can use any of the 16 MIDI channels.")
                        .font(.cb(.caption))
                }

                // Section 2: MIDI Filter
                Section {
                    NavigationLink(destination: MidiFilterView(midiFilter: $midiFilter, customMidiFilters: $customMidiFilters)) {
                        Text("MIDI Filter")
                    }
                    .tint(selectedTheme.accentColor(for: colorScheme))
                    .cbRow()
                } header: {
                    Text("Auto-Assignment")
                } footer: {
                    Text("Exclude MIDI CC numbers from automatic assignment")
                }

                // Section 3: MIDI Assignments
                Section {
                    NavigationLink(destination: MidiAssignmentsView(
                        setlist: setlist,
                        controlButtons: $controlButtons,
                        isGlobalChannel: $isGlobalChannel,
                        globalChannel: $globalChannel,
                        midiFiltersEnabled: midiFiltersEnabled,
                        midiFilter: midiFilter,
                        onApply: onApply,
                        onDismissAll: onDismiss
                    )) {
                        Text("MIDI Assignments")
                    }
                    .tint(selectedTheme.accentColor(for: colorScheme))
                    .cbRow()
                } footer: {
                    Text("View and edit MIDI assignments for all cues and controls")
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("MIDI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CBSheetButton(title: "Done", bold: true) { onDismiss() }
                }
            }
            .tint(selectedTheme.accentColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}

// MARK: - MIDI Assignments View (NavigationLink destination)
struct MidiAssignmentsView: View {
    let setlist: [Song]
    @Binding var controlButtons: [ControlButton]
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    let midiFiltersEnabled: Bool
    let midiFilter: Set<Int>
    var onApply: (([MidiTableItem]) -> Void)? = nil
    var onDismissAll: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    @State private var editableItems: [MidiTableItem] = []
    @State private var showingConflictAlert = false
    @State private var pendingConflict: MidiConflict? = nil
    @State private var sortKey: MidiSortKey = .name
    @State private var sortAscending: Bool = true
    @State private var allowFullCCR: Bool = false

    enum MidiSortKey { case name, type, channel, value }

    var body: some View {
        VStack(spacing: 0) {
            // MIDI Table
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Table Header
                        HStack(spacing: 0) {
                                Button(action: { toggleSort(.name) }) {
                                    HStack(spacing: 4) {
                                        Text("Name").font(.cb(.small, .semibold)).foregroundStyle(CBColor.textSecondary)
                                        sortIndicator(for: .name)
                                    }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { toggleSort(.type) }) {
                                    HStack(spacing: 4) {
                                        Text("Type").font(.cb(.small, .semibold)).foregroundStyle(CBColor.textSecondary)
                                        sortIndicator(for: .type)
                                    }
                                .frame(width: 70, alignment: .center)
                                }
                                .buttonStyle(.plain)
                            
                            if !isGlobalChannel {
                                    Button(action: { toggleSort(.channel) }) {
                                        HStack(spacing: 4) {
                                            Text("Channel").font(.cb(.small, .semibold)).foregroundStyle(CBColor.textSecondary)
                                            sortIndicator(for: .channel)
                                        }
                                    .frame(width: 80, alignment: .center)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button(action: { toggleSort(.value) }) {
                                    HStack(spacing: 4) {
                                        Text("Value").font(.cb(.small, .semibold)).foregroundStyle(CBColor.textSecondary)
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
                                midiFiltersEnabled: midiFiltersEnabled,
                                midiFilter: midiFilter,
                                getEditableItems: { editableItems },
                                onMidiChange: { item, newMidiType, newChannel, newValue in
                                    handleMidiChange(item: item, newMidiType: newMidiType, newChannel: newChannel, newValue: newValue)
                                },
                                getOwnerName: { midiType, channel, value, excludeId, excludeName in
                                    getOwnerName(for: midiType, channel: channel, value: value, excluding: excludeId, excludeName: excludeName)
                                },
                                onDismissAll: onDismissAll,
                                onApply: onApply
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
        .onAppear {
            buildMidiTableItems()
        }
        .cbDialog("MIDI Conflict", isPresented: $showingConflictAlert, themeFont: selectedTheme.font,
            message: pendingConflict.map { c in
                "MIDI \(c.midiKey.kind == .cc ? "CC" : "Note") #\(c.midiKey.number) on Channel \(c.midiKey.channel) is already used by \"\(c.existingOwner)\". Reassign to \"\(c.newItem.name)\"? Previous mapping will be removed."
            } ?? "",
            buttons: [
                .init("Reassign", role: .primary) {
                    if let conflict = pendingConflict {
                        resolveMidiConflict(conflict)
                    }
                    pendingConflict = nil
                },
                .init("Cancel", role: .cancel) {
                    pendingConflict = nil
                }
            ]
        )
        .navigationTitle("MIDI Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(selectedTheme.accentColor(for: colorScheme))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                CBSheetButton(title: "Done", bold: true) {
                    debugPrint("🎛️ [MIDI Assignments] Done button clicked - applying \(editableItems.count) items")
                    onApply?(editableItems)
                    if let onDismissAll = onDismissAll {
                        onDismissAll()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func buildMidiTableItems() {
        debugPrint("🎛️ [Build Items] Starting - setlist.count=\(setlist.count), controlButtons.count=\(controlButtons.count)")
        var items: [MidiTableItem] = []
        var seenIDs: Set<UUID> = []

        // Add setlist items
        for song in setlist {
            // Skip if we've already added this ID (prevents duplicates)
            guard !seenIDs.contains(song.id) else { continue }
            seenIDs.insert(song.id)

            items.append(MidiTableItem(
                id: song.id,
                name: song.name,
                type: .setlistItem,
                midiType: song.kind,
                channel: song.channel,
                value: song.kind == .cc ? song.cc : (song.note ?? 0)
            ))
        }
        debugPrint("🎛️ [Build Items] Added \(items.count) setlist items")

        // Add control buttons and faders
        for button in controlButtons {
            // Skip if we've already added this ID (prevents duplicates)
            guard !seenIDs.contains(button.id) else { continue }
            seenIDs.insert(button.id)

            let itemType: MidiItemType = button.isFader == true ? .fader : .button
            debugPrint("🎛️ [Build Items] Adding \(itemType.displayName): '\(button.title)' - \(button.kind) Ch\(button.channel) #\(button.number)")

            items.append(MidiTableItem(
                id: button.id,
                name: button.title,
                type: itemType,
                midiType: button.kind,
                channel: button.channel,
                value: button.number
            ))
        }
        debugPrint("🎛️ [Build Items] Total items: \(items.count) (setlist + controls)")

            editableItems = items
            sortEditableItems()
        debugPrint("🎛️ [Build Items] Finished - editableItems.count=\(editableItems.count)")
    }
    
    private func applyGlobalChannel() {
        // Apply the global channel to all items
        for index in editableItems.indices {
            editableItems[index].channel = globalChannel
        }
    }
    
    private func handleMidiChange(item: MidiTableItem, newMidiType: MIDIKind, newChannel: Int, newValue: Int) {
        debugPrint("🎛️ [MIDI Assignments] handleMidiChange for '\(item.name)' (\(item.type.displayName)): \(newMidiType) Ch\(newChannel) #\(newValue)")

        // Check if this creates a conflict
        if let conflict = checkForMidiConflict(item: item, newMidiType: newMidiType, newChannel: newChannel, newValue: newValue) {
            debugPrint("🎛️ [MIDI Assignments] Conflict detected with: \(conflict.existingOwner)")
            // Show conflict alert
            pendingConflict = conflict
            showingConflictAlert = true
        } else {
            // No conflict, update directly
            if let itemIndex = editableItems.firstIndex(where: { $0.id == item.id }) {
                debugPrint("🎛️ [MIDI Assignments] Updating editableItems[\(itemIndex)] for '\(item.name)'")
                editableItems[itemIndex].midiType = newMidiType
                editableItems[itemIndex].channel = newChannel
                editableItems[itemIndex].value = newValue
            } else {
                debugPrint("🎛️ [MIDI Assignments] ERROR: Could not find item in editableItems!")
            }
        }
    }
    
    private func checkForMidiConflict(item: MidiTableItem, newMidiType: MIDIKind, newChannel: Int, newValue: Int) -> MidiConflict? {
        let newKey = MIDIKey(kind: newMidiType, channel: newChannel, number: newValue)

        // Collect all owners of this MIDI key
        let owners = editableItems.filter { otherItem in
            otherItem.id != item.id && MIDIKey(kind: otherItem.midiType, channel: otherItem.channel, number: otherItem.value) == newKey
        }.map { $0.name }

        if !owners.isEmpty {
            // Format multiple owners
            let ownerString: String
            if owners.count == 1 {
                ownerString = owners[0]
            } else if owners.count == 2 {
                ownerString = "\(owners[0]) and \(owners[1])"
            } else if owners.count <= 4 {
                ownerString = owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            } else {
                let shown = owners.prefix(3).joined(separator: ", ")
                ownerString = "\(shown), and \(owners.count - 3) more"
            }

            return MidiConflict(
                newItem: item,
                existingOwner: ownerString,
                midiKey: newKey
            )
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
    
    private func getOwnerName(for midiType: MIDIKind, channel: Int, value: Int, excluding excludeId: UUID, excludeName: String) -> String? {
        let testKey = MIDIKey(kind: midiType, channel: channel, number: value)
        let owners = editableItems.filter { item in
            item.id != excludeId && MIDIKey(kind: item.midiType, channel: item.channel, number: item.value) == testKey
        }.map { $0.name }

        debugPrint("🔍 [MIDI Assignments] getOwnerName for \(midiType) Ch\(channel) #\(value), excluding '\(excludeName)': found \(owners.count) owners: \(owners)")

        // Remove duplicate names (filter out the item being edited by name as well)
        let uniqueOwners = owners.filter { $0 != excludeName }
        let dedupedOwners = Array(Set(uniqueOwners)).sorted()

        // Format multiple owners
        if dedupedOwners.isEmpty {
            return nil
        } else if dedupedOwners.count == 1 {
            return dedupedOwners[0]
        } else if dedupedOwners.count == 2 {
            return "\(dedupedOwners[0]) and \(dedupedOwners[1])"
        } else if dedupedOwners.count <= 4 {
            return dedupedOwners.dropLast().joined(separator: ", ") + ", and " + dedupedOwners.last!
        } else {
            let shown = dedupedOwners.prefix(3).joined(separator: ", ")
            return "\(shown), and \(dedupedOwners.count - 3) more"
        }
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
                .font(.cbIcon(.micro, .regular))
                .foregroundStyle(CBColor.textSecondary)
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
    let getOwnerName: (MIDIKind, Int, Int, UUID, String) -> String?
    
    var body: some View {
        Menu {
            if item.midiType == .cc && !allowFullCCR {
                ForEach(1...119, id: \.self) { val in
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    let owner = getOwnerName(item.midiType, channel, val, item.id, item.name)
                    let displayText = owner == nil ? "\(val)" : "\(val) (Used by: \(owner!))"
                    Button(displayText) { onMidiChange(item, item.midiType, channel, val) }
                        .foregroundColor(owner == nil ? .primary : .secondary)
                }
            } else {
                ForEach(0...127, id: \.self) { val in
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    let owner = getOwnerName(item.midiType, channel, val, item.id, item.name)
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
                    .font(.cb(.body))
                    .foregroundStyle(CBColor.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.cbIcon(.micro, .regular))
                    .foregroundStyle(CBColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .id("\(item.id)-\(item.midiType)-\(isGlobalChannel)-\(globalChannel)-\(allowFullCCR)")
    }
}

// MARK: - MIDI Assignment Edit Sheet
struct MidiAssignmentEditSheet: View {
    @Binding var item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
    let allowFullCCR: Bool
    let midiFiltersEnabled: Bool
    let midiFilter: Set<Int>
    let getEditableItems: () -> [MidiTableItem]  // Closure to get current editableItems
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID, String) -> String?
    var onDismissAll: (() -> Void)? = nil
    var onApply: (([MidiTableItem]) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    @State private var editedType: MIDIKind
    @State private var editedChannel: Int
    @State private var editedValue: Int

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    init(item: Binding<MidiTableItem>, isGlobalChannel: Bool, globalChannel: Int, allowFullCCR: Bool, midiFiltersEnabled: Bool, midiFilter: Set<Int>, getEditableItems: @escaping () -> [MidiTableItem], onMidiChange: @escaping (MidiTableItem, MIDIKind, Int, Int) -> Void, getOwnerName: @escaping (MIDIKind, Int, Int, UUID, String) -> String?, onDismissAll: (() -> Void)? = nil, onApply: (([MidiTableItem]) -> Void)? = nil) {
        self._item = item
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
        self.allowFullCCR = allowFullCCR
        self.midiFiltersEnabled = midiFiltersEnabled
        self.midiFilter = midiFilter
        self.getEditableItems = getEditableItems
        self.onMidiChange = onMidiChange
        self.getOwnerName = getOwnerName
        self.onDismissAll = onDismissAll
        self.onApply = onApply
        self._editedType = State(initialValue: item.wrappedValue.midiType)
        self._editedChannel = State(initialValue: item.wrappedValue.channel)
        self._editedValue = State(initialValue: item.wrappedValue.value)
    }

    var body: some View {
        Form {
            Section(header: Text("Item")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(item.name)
                            .foregroundStyle(CBColor.textSecondary)
                    }
                    .cbRow()

                    HStack {
                        Text("Type")
                        Spacer()
                        Text(item.type.displayName)
                            .foregroundStyle(CBColor.textSecondary)
                    }
                    .cbRow()
                }

                Section(header: Text("MIDI Assignment")) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.cb(.caption))
                            .foregroundStyle(CBColor.textSecondary)
                            .cbRow()
                    }
                    if item.type != .fader {
                        Picker("MIDI Type", selection: $editedType) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .cbRow()
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    if !isGlobalChannel {
                        ChannelPicker(title: "Channel", channel: $editedChannel, disabled: false)
                            .cbRow()
                    } else {
                        HStack {
                            Text("Channel")
                            Spacer()
                            Text("\(globalChannel) (Global)")
                                .foregroundStyle(CBColor.textSecondary)
                        }
                        .cbRow()
                    }

                    // Value picker with ownership warnings
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text(editedType == .cc ? "CC Number" : "Note Number")
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

                            Spacer()

                            if editedType == .note {
                                Text(editedValue.midiNoteName)
                                    .font(.cb(.small))
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            }

                            // Minus button
                            Button(action: {
                                if editedValue > (editedType == .cc && !allowFullCCR ? 1 : 0) {
                                    editedValue -= 1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.cbIcon(.small, .semibold))
                                    .foregroundColor(editedValue > (editedType == .cc && !allowFullCCR ? 1 : 0) ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .background(selectedTheme.titleBarColor(for: colorScheme))
                                    .cornerRadius(CBRadius.small)
                            }
                            .buttonStyle(.plain)
                            .disabled(editedValue <= (editedType == .cc && !allowFullCCR ? 1 : 0))

                            // Text field
                            TextField("", value: $editedValue, format: .number)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(selectedTheme.backgroundColor(for: colorScheme))
                                .cornerRadius(CBRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CBRadius.small)
                                        .stroke(selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                                )
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                                .keyboardType(.numberPad)

                            // Plus button
                            Button(action: {
                                let maxValue = (editedType == .cc && !allowFullCCR) ? 119 : 127
                                if editedValue < maxValue {
                                    editedValue += 1
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.cbIcon(.small, .semibold))
                                    .foregroundColor(editedValue < ((editedType == .cc && !allowFullCCR) ? 119 : 127) ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .background(selectedTheme.titleBarColor(for: colorScheme))
                                    .cornerRadius(CBRadius.small)
                            }
                            .buttonStyle(.plain)
                            .disabled(editedValue >= ((editedType == .cc && !allowFullCCR) ? 119 : 127))
                        }

                        // Show ownership warning
                        if let owner = getOwnerName(editedType, isGlobalChannel ? globalChannel : editedChannel, editedValue, item.id, item.name) {
                            Text("⚠️ MIDI taken by: \(owner)")
                                .font(.cb(.caption))
                                .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Show filtered MIDI warning only when filters are enabled
                        if midiFiltersEnabled && !midiFilter.isEmpty && editedType == .cc && midiFilter.contains(editedValue) {
                            Text("⚠️ This CC is filtered. Turn off filter to use it.")
                                .font(.cb(.caption))
                                .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .cbRow()
                }

            // Save button section at bottom
            Section {
                let channel = isGlobalChannel ? globalChannel : editedChannel
                let hasConflict = getOwnerName(editedType, channel, editedValue, item.id, item.name) != nil
                let isFiltered = midiFiltersEnabled && !midiFilter.isEmpty && editedType == .cc && midiFilter.contains(editedValue)
                let isDisabled = hasConflict || isFiltered

                Button(action: {
                    debugPrint("🎛️ [Edit Sheet] Save clicked for '\(item.name)' - type:\(editedType) ch:\(channel) val:\(editedValue)")

                    // Call onMidiChange to check for conflicts and update if valid
                    // This will update editableItems in the parent view
                    onMidiChange(item, editedType, channel, editedValue)

                    // Small delay to ensure editableItems is updated before applying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // Get the current editableItems and apply changes
                        let currentItems = getEditableItems()
                        debugPrint("🎛️ [Edit Sheet] Applying \(currentItems.count) items and dismissing all sheets")
                        onApply?(currentItems)

                        // Dismiss all sheets (MIDI Settings + MIDI Assignments)
                        if let onDismissAll = onDismissAll {
                            onDismissAll()
                        } else {
                            dismiss()
                        }
                    }
                }) {
                    Text("Save")
                        .font(.cb(.body, .semibold))
                        .foregroundColor(isDisabled ? Color.gray.opacity(0.5) : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isDisabled ? Color.gray.opacity(0.3) : selectedTheme.accentColor(for: colorScheme))
                        .cornerRadius(CBRadius.control)
                }
                .disabled(isDisabled)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("Edit MIDI Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CBSheetButton(title: "Cancel") { dismiss() }
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}

struct MidiTableRow: View {
    @Binding var item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
    let allowFullCCR: Bool
    let midiFiltersEnabled: Bool
    let midiFilter: Set<Int>
    let getEditableItems: () -> [MidiTableItem]
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID, String) -> String?
    var onDismissAll: (() -> Void)? = nil
    var onApply: (([MidiTableItem]) -> Void)? = nil

    var body: some View {
        NavigationLink(destination: MidiAssignmentEditSheet(
            item: $item,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel,
            allowFullCCR: allowFullCCR,
            midiFiltersEnabled: midiFiltersEnabled,
            midiFilter: midiFilter,
            getEditableItems: getEditableItems,
            onMidiChange: onMidiChange,
            getOwnerName: getOwnerName,
            onDismissAll: onDismissAll,
            onApply: onApply
        )) {
            HStack(spacing: 0) {
                // Name Column
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.cb(.body))
                        .lineLimit(1)
                    Text(item.type.displayName)
                        .font(.cb(.caption))
                        .foregroundStyle(CBColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Type Column
                Text(item.midiType == .cc ? "CC" : "Note")
                    .font(.cb(.body))
                    .foregroundStyle(CBColor.textPrimary)
                    .frame(width: 70, alignment: .center)

                // Channel Column (only shown if not global)
                if !isGlobalChannel {
                    Text("\(item.channel)")
                        .font(.cb(.body))
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(width: 80, alignment: .center)
                }

                // Value Column
                Text(item.midiType == .note ? "\(item.value) - \(item.value.midiNoteName)" : "\(item.value)")
                    .font(.cb(.body))
                    .foregroundStyle(CBColor.textPrimary)
                    .frame(width: 90, alignment: .center)

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.cbIcon(.caption, .regular))
                    .foregroundStyle(CBColor.textSecondary)
                    .frame(width: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - MIDI Filter View
struct MidiFilterView: View {
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    @Binding var midiFilter: Set<Int>
    @Binding var customMidiFilters: [(Int, String)]

    // Standard CC recommendations
    private let recommendedFilters: [(Int, String)] = [
        (1, "Mod Wheel"),
        (7, "Volume"),
        (10, "Pan"),
        (11, "Expression"),
        (64, "Sustain Pedal"),
        (120, "All Sound Off"),
        (121, "Reset All Controllers"),
        (122, "Local Control"),
        (123, "All Notes Off"),
        (124, "Omni Mode Off"),
        (125, "Omni Mode On"),
        (126, "Mono Mode On"),
        (127, "Poly Mode On")
    ]

    var body: some View {
        Form {
            // Master toggle section
            Section {
                Toggle(isOn: $midiFiltersEnabled) {
                    Text("Enable MIDI Filters")
                }
                .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                .cbRow()
            }

            Section {
                Text("Exclude these MIDI CC numbers from auto-assignment. Common performance controllers (mod wheel, volume, sustain) are filtered by default to prevent conflicts.")
                    .font(.cb(.small))
                    .foregroundStyle(CBColor.textSecondary)
            }
            .cbRow()

            // Add Custom Filter Button
            Section {
                NavigationLink(destination: AddCustomFilterView(
                    midiFilter: $midiFilter,
                    customMidiFilters: $customMidiFilters
                )) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                        Text("Add Custom Filter")
                    }
                }
                .tint(selectedTheme.accentColor(for: colorScheme))
                .cbRow()
                .disabled(!midiFiltersEnabled)
            }

            // Custom Filters Section
            if !customMidiFilters.isEmpty {
                Section("Custom Filters") {
                    ForEach(Array(customMidiFilters.enumerated()), id: \.offset) { index, filter in
                        let cc = filter.0
                        let name = filter.1

                        Toggle(isOn: Binding(
                            get: { midiFilter.contains(cc) },
                            set: { isOn in
                                if isOn {
                                    midiFilter.insert(cc)
                                } else {
                                    midiFilter.remove(cc)
                                }
                            }
                        )) {
                            HStack {
                                Text("CC \(cc)")
                                    .font(.cb(.body))
                                    .frame(width: 60, alignment: .leading)
                                Text(name)
                                    .font(.cb(.body))
                                    .foregroundStyle(CBColor.textSecondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                        .disabled(!midiFiltersEnabled)
                        .swipeActions {
                            Button(role: .destructive) {
                                midiFilter.remove(cc)
                                customMidiFilters.removeAll { $0.0 == cc && $0.1 == name }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .cbRow()
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let cc = customMidiFilters[index].0
                            midiFilter.remove(cc)
                        }
                        customMidiFilters.remove(atOffsets: indexSet)
                    }
                }
            }

            Section("Recommended Filters") {
                ForEach(recommendedFilters, id: \.0) { cc, name in
                    Toggle(isOn: Binding(
                        get: { midiFilter.contains(cc) },
                        set: { isOn in
                            if isOn {
                                midiFilter.insert(cc)
                            } else {
                                midiFilter.remove(cc)
                            }
                        }
                    )) {
                        HStack {
                            Text("CC \(cc)")
                                .font(.cb(.body))
                                .frame(width: 60, alignment: .leading)
                            Text(name)
                                .font(.cb(.body))
                                .foregroundStyle(CBColor.textSecondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .disabled(!midiFiltersEnabled)
                    .cbRow()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("MIDI Filter")
        .navigationBarTitleDisplayMode(.inline)
        .tint(selectedTheme.accentColor(for: colorScheme))
    }

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }
}

// MARK: - Add Custom MIDI Filter View
struct AddCustomFilterView: View {
    @Binding var midiFilter: Set<Int>
    @Binding var customMidiFilters: [(Int, String)]

    @State private var customCC: Int = 0
    @State private var customDescription: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                CCNumberPicker(title: "CC Number", ccNumber: $customCC, disabled: false)
                    .cbRow()

                TextField("Description", text: $customDescription)
                    .textInputAutocapitalization(.words)
                    .cbRow()
            } header: {
                Text("Custom MIDI Filter")
            } footer: {
                Text("Add a MIDI CC number with a custom description to exclude from auto-assignment")
            }
        }
        .scrollContentBackground(.hidden)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("Add Custom Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                CBSheetButton(title: "Add", bold: true, disabled: customDescription.isEmpty) {
                    if !customDescription.isEmpty {
                        customMidiFilters.append((customCC, customDescription))
                        midiFilter.insert(customCC)
                    }
                    dismiss()
                }
            }
        }
        .tint(selectedTheme.accentColor(for: colorScheme))
    }

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }
}
