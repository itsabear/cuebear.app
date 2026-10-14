import SwiftUI

// MARK: - About Sheet
struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    @State private var showingBugReport = false

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.1"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Icon and Name
                    VStack(spacing: 16) {
                        Image("BearPawIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .cornerRadius(26)
                            .shadow(radius: 10)

                        Text("Cue Bear")
                            .font(.custom("Sora-Bold", size: 36))

                        VStack(spacing: 4) {
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.custom("Sora-Regular", size: 15))
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                    .padding(.top, 40)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Professional MIDI Cueing System")
                            .font(.custom("Sora-Bold", size: 17))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Cue Bear is a powerful iPad app designed for live performers, theatrical productions, and studio musicians. Trigger MIDI cues seamlessly with your Mac using USB or WiFi connection.")
                            .font(.custom("Sora-Regular", size: 17))
                            .multilineTextAlignment(.center)
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            .padding(.horizontal, 20)
                    }

                    Divider()
                        .padding(.horizontal, 40)

                    // Credits
                    VStack(spacing: 12) {
                        Text("Created by")
                            .font(.custom("Sora-Bold", size: 17))

                        Text("Omri Behr")
                            .font(.custom("Sora-Bold", size: 20))
                    }

                    // Links
                    VStack(spacing: 16) {
                        // Bug Report Button (custom button, not a link)
                        bugReportButton()

                        // Reset Tutorials Button
                        resetTutorialsButton()

                        #if DEBUG
                        // TEST CRASH BUTTON - Only visible in debug builds
                        testCrashButton()
                        #endif

                        linkButton(title: "Email Support", icon: "envelope.fill", url: "mailto:support@cuebear.app")
                        linkButton(title: "Website", icon: "globe", url: "https://cuebear.app")
                        linkButton(title: "Privacy Policy", icon: "hand.raised.fill", url: "https://cuebear.app/privacy")
                    }
                    .padding(.horizontal, 40)

                    // Copyright
                    Text("© 2024 Omri Behr. All rights reserved.")
                        .font(.custom("Sora-Regular", size: 12))
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    CBSheetButton(title: "Done", bold: true) { dismiss() }
                }
            }
            .tint(selectedTheme.accentColor(for: colorScheme))
            .sheet(isPresented: $showingBugReport) {
                BugReportView()
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func bugReportButton() -> some View {
        let linkColor = selectedTheme.warningColor(for: colorScheme)

        return Button(action: {
            showingBugReport = true
        }) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .frame(width: 24)
                Text("Report a Bug")
                    .font(.custom("Sora-Bold", size: 17))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(linkColor.opacity(0.1))
            .foregroundColor(linkColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func resetTutorialsButton() -> some View {
        let linkColor = selectedTheme.defaultCueColor(for: colorScheme)

        return Button(action: {
            // Reset all tutorial flags
            UserDefaults.standard.removeObject(forKey: "hasSeenTutorial1")
            UserDefaults.standard.removeObject(forKey: "hasSeenTutorial2")
            UserDefaults.standard.removeObject(forKey: "hasSeenTutorial2b")
            UserDefaults.standard.removeObject(forKey: "hasSeenTutorial2c")
            UserDefaults.standard.removeObject(forKey: "hasSeenTutorial3")
            // Also reset nav pill tutorial
            UserDefaults.standard.removeObject(forKey: "hasSeenNavPillTutorial")
            // Also reset onboarding so it shows first
            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
            // Dismiss the sheet
            dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24)
                Text("Reset Tutorials")
                    .font(.custom("Sora-Bold", size: 17))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(linkColor.opacity(0.1))
            .foregroundColor(linkColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    #if DEBUG
    private func testCrashButton() -> some View {
        return Button(action: {
            // Trigger a test crash to verify crash reporting
            CrashReporter.shared.markCrashOccurred()

            // Use a slight delay to ensure UI state is properly saved before termination
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Terminate the app to simulate a crash
                // In debug mode, actual crashes (like force-unwrap nil) freeze the app
                // exit(1) cleanly terminates the app, allowing crash detection on next launch
                exit(1)
            }
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .frame(width: 24)
                Text("🧪 Test Crash (Debug Only)")
                    .font(.custom("Sora-Bold", size: 17))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    #endif

    private func linkButton(title: String, icon: String, url: String) -> some View {
        let linkColor = selectedTheme.defaultCueColor(for: colorScheme)

        return Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .font(.custom("Sora-Bold", size: 17))
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(linkColor.opacity(0.1))
            .foregroundColor(linkColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Appearance Sheet
struct AppearanceSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @State private var originalThemeID: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var originalTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == originalThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Vibe")
                            .font(.custom("Sora-Bold", size: 28))
                            .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                        Text("Select a theme that matches your musical style")
                            .font(.custom("Sora-Regular", size: 15))
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // Theme Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(AppTheme.allThemes) { theme in
                            ThemePreviewCard(theme: theme, isSelected: theme.id == selectedThemeID)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedThemeID = theme.id
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(selectedTheme.accentColor(for: colorScheme))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CBSheetButton(title: "Cancel") {
                        selectedThemeID = originalThemeID
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    CBSheetButton(title: "Done", bold: true) { dismiss() }
                }
            }
            .onAppear {
                // Save original theme when sheet appears
                originalThemeID = selectedThemeID
            }
        }
    }
}

// MARK: - Theme Preview Card
struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(spacing: 12) {
            // Genre badge
            Text(theme.genre.uppercased())
                .font(.custom("Sora-Bold", size: 9))
                .foregroundColor(theme.accentColor(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentColor(for: colorScheme).opacity(0.15))
                .cornerRadius(4)

            // Theme name
            Text(theme.name)
                .font(.custom("Sora-Bold", size: 17))
                .foregroundColor(theme.primaryTextColor(for: colorScheme))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)

            // Color swatches
            HStack(spacing: 8) {
                Circle()
                    .fill(theme.backgroundColor(for: colorScheme))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                Circle()
                    .fill(theme.defaultCueColor(for: colorScheme))
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(theme.accentColor(for: colorScheme))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }

            // Font sample
            Text("Aa")
                .font(theme.font(size: 28, weight: .semibold))
                .foregroundColor(theme.secondaryTextColor(for: colorScheme))

            // Selection indicator - reserve space to prevent size changes
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(selectedTheme.successColor(for: colorScheme))
                Text("ACTIVE")
                    .font(.custom("Sora-Bold", size: 11))
                    .foregroundColor(selectedTheme.successColor(for: colorScheme))
            }
            .opacity(isSelected ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.titleBarColor(for: colorScheme))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? theme.accentColor(for: colorScheme) : Color.clear, lineWidth: 3)
        )
        .shadow(color: isSelected ? theme.accentColor(for: colorScheme).opacity(0.3) : Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Appearance Settings Sheet
struct AppearanceSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("showMIDIData") private var showMIDIData: Bool = true
    @AppStorage("cueHeight") private var cueHeight: Double = 86
    @AppStorage("fontSize") private var fontSize: Double = 1.0
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignCueColors") private var autoAssignCueColors: Bool = true
    @AppStorage("autoAssignControlColors") private var autoAssignControlColors: Bool = true

    @State private var showColorPicker = false

    // Computed property for unified cue size control
    private var cueSize: Binding<Double> {
        Binding<Double>(
            get: {
                // Convert current height and fontSize to unified scale
                // Use fontSize as primary scale (0.8-1.4), map to 70%-150%
                let scale = (fontSize - 0.8) / (1.4 - 0.8) * (1.5 - 0.7) + 0.7
                return scale
            },
            set: { newScale in
                // Snap to 1.0 (100%) when close for easier selection
                let snappedScale = abs(newScale - 1.0) < 0.03 ? 1.0 : newScale

                // Map unified scale (0.7-1.5) to individual values
                // fontSize: 0.7→0.8, 1.0→1.0, 1.5→1.4
                fontSize = (snappedScale - 0.7) / (1.5 - 0.7) * (1.4 - 0.8) + 0.8
                // cueHeight: 0.7→60, 1.0→86, 1.5→120
                cueHeight = (snappedScale - 0.7) / (1.5 - 0.7) * (120 - 60) + 60
            }
        )
    }

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var customDefaultCueColor: Binding<String?> {
        Binding<String?>(
            get: { customDefaultCueColorStorage.isEmpty ? nil : customDefaultCueColorStorage },
            set: { customDefaultCueColorStorage = $0 ?? "" }
        )
    }

    private var effectiveDefaultCueColor: String {
        customDefaultCueColorStorage.isEmpty ? selectedTheme.defaultCueColorHexValue(for: colorScheme) : customDefaultCueColorStorage
    }

    var body: some View {
        NavigationView {
            Form {
                // Accent Color Section (affects cues and buttons)
                Section {
                    Button {
                        showColorPicker.toggle()
                    } label: {
                        HStack {
                            Text("Accent Color")
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                            Circle()
                                .fill(Color(hex: effectiveDefaultCueColor))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1))
                        }
                    }
                    .buttonStyle(IOSPressButtonStyle())

                    if showColorPicker {
                        CBColorPickerInline(selectedColorHex: customDefaultCueColor)
                            .padding(.vertical, 8)
                    }
                } header: {
                    Text("ACCENT COLOR")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } footer: {
                    Text("Color used for new cues, buttons, and interactive elements")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                // Auto Assign Colors Section
                Section {
                    Toggle("Auto Assign Cue Colors", isOn: $autoAssignCueColors)
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    Toggle("Auto Assign Button & Fader Colors", isOn: $autoAssignControlColors)
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                } header: {
                    Text("AUTO ASSIGN COLORS")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } footer: {
                    Text("Randomly assigns a color from the palette when adding new cues or controls")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                // MIDI Data Display Section
                Section {
                    Toggle("Show MIDI Data", isOn: $showMIDIData)
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                } header: {
                    Text("MIDI DISPLAY")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } footer: {
                    Text("Shows CC/Note numbers on cues, buttons, and faders")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                // Unified Cue Size Section (controls both height and font size)
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Scale")
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                            Text("\(Int(cueSize.wrappedValue * 100))%")
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                .font(.system(.body, design: .monospaced))
                        }

                        Slider(value: cueSize, in: 0.7...1.5, step: 0.05)
                            .tint(selectedTheme.accentColor(for: colorScheme))

                        HStack {
                            Text("70%")
                                .font(.custom("Sora-Regular", size: 12))
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            Spacer()
                            Text("150%")
                                .font(.custom("Sora-Regular", size: 12))
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("CUE SIZE")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } footer: {
                    Text("Adjusts the size of cue buttons and text throughout the app")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                // Reset Section
                Section {
                    Button {
                        showMIDIData = true
                        cueHeight = 86
                        fontSize = 1.0
                        customDefaultCueColorStorage = ""
                        showColorPicker = false
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("Reset to Defaults")
                            .font(.custom("Sora-Bold", size: 17))
                            .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Appearance Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    CBSheetButton(title: "Done", bold: true) { dismiss() }
                }
            }
            .tint(selectedTheme.accentColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}

// MARK: - Previews
struct AboutSheet_Previews: PreviewProvider {
    static var previews: some View {
        AboutSheet()
    }
}

struct AppearanceSheet_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSheet()
    }
}

struct AppearanceSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsSheet()
    }
}
