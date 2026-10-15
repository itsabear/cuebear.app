//
//  MIDIPickers.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Stepper + TextField MIDI Number Picker
struct MIDINumberPicker: View {
    let kind: MIDIKind
    @Binding var number: Int
    let disabled: Bool
    let channel: Int
    var currentOwnerName: ((MIDIKey) -> String?)?
    var editingControl: ControlButton?
    var editingSong: Song?
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    var midiFilter: Set<Int> = []
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(kind == .cc ? "CC Number" : "Note Number")
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

                Spacer()

                // Note name (for MIDI notes only)
                if kind == .note {
                    Text(number.midiNoteName)
                        .font(.cb(.small))
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }

                // Minus button
                Button(action: {
                    if number > 0 {
                        number -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.cbIcon(.small, .semibold))
                        .foregroundColor(number > 0 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(selectedTheme.titleBarColor(for: colorScheme))
                        .cornerRadius(CBRadius.small)
                }
                .buttonStyle(.plain)
                .disabled(disabled || number <= 0)

                // Text field
                TextField("", text: $textValue)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(selectedTheme.backgroundColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: CBRadius.small)
                            .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                    )
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .disabled(disabled)
                    .keyboardType(.numberPad)
                    .onAppear {
                        textValue = "\(number)"
                    }
                    .onChange(of: number) { _, newValue in
                        if !isFocused {
                            textValue = "\(newValue)"
                        }
                    }
                    .onSubmit {
                        validateAndUpdate()
                    }
                    .onChange(of: textValue) { _, newText in
                        if let value = Int(newText), value >= 0, value <= 127 {
                            number = value
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            validateAndUpdate()
                        }
                    }
                    .onTapGesture {
                        isFocused = true
                    }

                // Plus button
                Button(action: {
                    if number < 127 {
                        number += 1
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.cbIcon(.small, .semibold))
                        .foregroundColor(number < 127 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(selectedTheme.titleBarColor(for: colorScheme))
                        .cornerRadius(CBRadius.small)
                }
                .buttonStyle(.plain)
                .disabled(disabled || number >= 127)
            }

            // Show "MIDI taken by" warning if number is taken
            if let owner = ownerFor(kind: kind, number: number, channel: channel) {
                Text("⚠️ MIDI taken by: \(owner)")
                    .font(.cb(.caption))
                    .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Show filtered MIDI warning only when filters are active
            if midiFiltersEnabled && !midiFilter.isEmpty && kind == .cc && midiFilter.contains(number) {
                Text("⚠️ This CC is filtered. Turn off filter to use it.")
                    .font(.cb(.caption))
                    .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 0, value <= 127 {
            number = value
        } else {
            textValue = "\(number)"
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

        // If we're editing a song and checking its current MIDI assignment, don't show as taken
        if let edit = editingSong {
            let editNumber = (edit.kind == .note) ? (edit.note ?? 60) : edit.cc
            if edit.kind == kind && edit.channel == channel && editNumber == number {
                return nil
            }
        }

        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the editing song's name from the conflict list
        if let edit = editingSong {
            if ownersString.contains("|||") {
                // Multiple owners - filter out editing song
                let owners = ownersString.split(separator: "|||")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0 != edit.name }
                guard !owners.isEmpty else { return nil }
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if ownersString.trimmingCharacters(in: .whitespacesAndNewlines) == edit.name {
                // Single owner and it's the editing song
                return nil
            }
        }

        // Filter out the current control's name from the conflict list
        if let edit = editingControl {
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
}

// MARK: - Grid-Based Icon Picker
struct IconPicker: View {
    @Binding var symbol: String
    let icons: [String]
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var showingPopover = false

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        Button(action: { showingPopover = true }) {
            HStack {
                Text("Icon")
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                Spacer()
                if symbol.isEmpty {
                    Text("Text only")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } else {
                    Image(systemName: symbol)
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
            }
        }
        .popover(isPresented: $showingPopover) {
            IconGridView(symbol: $symbol, icons: icons, showingPopover: $showingPopover)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(CBColor.background)
        }
    }
}

// MARK: - Icon Grid View (Popover Content)
struct IconGridView: View {
    @Binding var symbol: String
    let icons: [String]
    @Binding var showingPopover: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Icon")
                    .font(.cb(.body, .semibold))
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                Spacer()
                Button(action: { showingPopover = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
            }
            .padding()
            .background(selectedTheme.titleBarColor(for: colorScheme))

            Divider()

            // Grid
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        // Text only option
                        Button(action: {
                            symbol = ""
                            showingPopover = false
                        }) {
                            VStack(spacing: 4) {
                                Text("Aa")
                                    .font(.cb(.large, .medium))
                                Text("Text only")
                                    .font(.cb(.micro))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                symbol.isEmpty
                                    ? selectedTheme.accentColor(for: colorScheme)
                                    : selectedTheme.titleBarColor(for: colorScheme)
                            )
                            .foregroundColor(
                                symbol.isEmpty ? .white : selectedTheme.primaryTextColor(for: colorScheme)
                            )
                            .cornerRadius(CBRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CBRadius.small)
                                    .stroke(
                                        symbol.isEmpty ? selectedTheme.accentColor(for: colorScheme) : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .id("text-only")

                        // Icon options
                        ForEach(icons, id: \.self) { icon in
                            let isSelected = icon == symbol

                            Button(action: {
                                symbol = icon
                                showingPopover = false
                            }) {
                                Image(systemName: icon)
                                    .font(.cbIcon(.title, .regular))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(
                                        isSelected
                                            ? selectedTheme.accentColor(for: colorScheme)
                                            : selectedTheme.titleBarColor(for: colorScheme)
                                    )
                                    .foregroundColor(
                                        isSelected ? .white : selectedTheme.primaryTextColor(for: colorScheme)
                                    )
                                    .cornerRadius(CBRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CBRadius.small)
                                            .stroke(
                                                isSelected ? selectedTheme.accentColor(for: colorScheme) : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .id(icon)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if !symbol.isEmpty {
                        proxy.scrollTo(symbol, anchor: .center)
                    } else {
                        proxy.scrollTo("text-only", anchor: .top)
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
        .background(selectedTheme.backgroundColor(for: colorScheme))
    }
}

extension IconPicker: Equatable {
    static func == (lhs: IconPicker, rhs: IconPicker) -> Bool {
        lhs.symbol == rhs.symbol && lhs.icons == rhs.icons
    }
}

// MARK: - Stepper + TextField Velocity Picker
struct VelocityPicker: View {
    @Binding var velocity: Int
    let disabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Velocity")
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            // Minus button
            Button(action: {
                if velocity > 0 {
                    velocity -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.cbIcon(.small, .semibold))
                    .foregroundColor(velocity > 0 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
            }
            .buttonStyle(.plain)
            .disabled(disabled || velocity <= 0)

            // Text field
            TextField("", text: $textValue)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedTheme.backgroundColor(for: colorScheme))
                .cornerRadius(CBRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                .disabled(disabled)
                .keyboardType(.numberPad)
                .onAppear {
                    textValue = "\(velocity)"
                }
                .onChange(of: velocity) { _, newValue in
                    if !isFocused {
                        textValue = "\(newValue)"
                    }
                }
                .onSubmit {
                    validateAndUpdate()
                }
                .onChange(of: textValue) { _, newText in
                    if let value = Int(newText), value >= 0, value <= 127 {
                        velocity = value
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndUpdate()
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

            // Plus button
            Button(action: {
                if velocity < 127 {
                    velocity += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.cbIcon(.small, .semibold))
                    .foregroundColor(velocity < 127 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
            }
            .buttonStyle(.plain)
            .disabled(disabled || velocity >= 127)
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 0, value <= 127 {
            velocity = value
        } else {
            textValue = "\(velocity)"
        }
    }
}

// MARK: - Channel Picker (Stepper + TextField)
struct ChannelPicker: View {
    let title: String
    @Binding var channel: Int
    let disabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            // Minus button
            Button(action: {
                if channel > 1 {
                    channel -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.cbIcon(.small, .semibold))
                    .foregroundColor(channel > 1 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
            }
            .buttonStyle(.plain)
            .disabled(disabled || channel <= 1)

            // Text field
            TextField("", text: $textValue)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedTheme.backgroundColor(for: colorScheme))
                .cornerRadius(CBRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                .disabled(disabled)
                .keyboardType(.numberPad)
                .onAppear {
                    textValue = "\(channel)"
                }
                .onChange(of: channel) { _, newValue in
                    if !isFocused {
                        textValue = "\(newValue)"
                    }
                }
                .onSubmit {
                    validateAndUpdate()
                }
                .onChange(of: textValue) { _, newText in
                    if let value = Int(newText), value >= 1, value <= 16 {
                        channel = value
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndUpdate()
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

            // Plus button
            Button(action: {
                if channel < 16 {
                    channel += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.cbIcon(.small, .semibold))
                    .foregroundColor(channel < 16 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
            }
            .buttonStyle(.plain)
            .disabled(disabled || channel >= 16)
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 1, value <= 16 {
            channel = value
        } else {
            textValue = "\(channel)"
        }
    }
}

// MARK: - CC Number Picker (Stepper + TextField)
struct CCNumberPicker: View {
    let title: String
    @Binding var ccNumber: Int
    let disabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            // Minus button
            Button(action: {
                if ccNumber > 0 {
                    ccNumber -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.cbIcon(.small, .semibold))
                    .foregroundColor(ccNumber > 0 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
            }
            .buttonStyle(.plain)
            .disabled(disabled || ccNumber <= 0)

            // Text field
            TextField("", text: $textValue)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedTheme.backgroundColor(for: colorScheme))
                .cornerRadius(CBRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                .disabled(disabled)
                .keyboardType(.numberPad)
                .onAppear {
                    textValue = "\(ccNumber)"
                }
                .onChange(of: ccNumber) { _, newValue in
                    if !isFocused {
                        textValue = "\(newValue)"
                    }
                }
                .onSubmit {
                    validateAndUpdate()
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndUpdate()
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

            // Plus button
            Button(action: {
                if ccNumber < 127 {
                    ccNumber += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.cbIcon(.small, .semibold))
                    .foregroundColor(ccNumber < 127 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(CBRadius.small)
            }
            .buttonStyle(.plain)
            .disabled(disabled || ccNumber >= 127)
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 0, value <= 127 {
            ccNumber = value
        } else {
            textValue = "\(ccNumber)"
        }
    }
}
