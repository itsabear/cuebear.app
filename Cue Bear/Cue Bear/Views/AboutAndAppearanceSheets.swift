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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
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
                            .font(.system(size: 36, weight: .bold))

                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                    }
                    .padding(.top, 40)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Professional MIDI Cueing System")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Cue Bear is a powerful iPad app designed for live performers, theatrical productions, and studio musicians. Trigger MIDI cues seamlessly with your Mac using USB or WiFi connection.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            .padding(.horizontal, 20)
                    }

                    Divider()
                        .padding(.horizontal, 40)

                    // Credits
                    VStack(spacing: 12) {
                        Text("Created by")
                            .font(.headline)

                        Text("Omri Behr")
                            .font(.title3.weight(.semibold))
                    }

                    // Links
                    VStack(spacing: 16) {
                        // Bug Report Button (custom button, not a link)
                        bugReportButton()

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
                        .font(.caption)
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(selectedTheme.backgroundColor(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
                }
            }
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
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
                    .font(.body.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(linkColor.opacity(0.1))
            .foregroundColor(linkColor)
            .cornerRadius(12)
        }
    }

    #if DEBUG
    private func testCrashButton() -> some View {
        return Button(action: {
            // Trigger a test crash to verify crash reporting
            CrashReporter.shared.markCrashOccurred()
            fatalError("🧪 TEST CRASH: This is a test crash to verify crash reporting works")
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .frame(width: 24)
                Text("🧪 Test Crash (Debug Only)")
                    .font(.body.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(12)
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
                    .font(.body.weight(.medium))
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(linkColor.opacity(0.1))
            .foregroundColor(linkColor)
            .cornerRadius(12)
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
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                        Text("Select a theme that matches your musical style")
                            .font(.subheadline)
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
            .toolbarBackground(selectedTheme.backgroundColor(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Restore original theme on cancel
                        selectedThemeID = originalThemeID
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
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
                .font(.system(size: 9, weight: .black))
                .foregroundColor(theme.accentColor(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentColor(for: colorScheme).opacity(0.15))
                .cornerRadius(4)

            // Theme name
            Text(theme.name)
                .font(.system(size: 17, weight: .bold))
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
                    .font(.system(size: 11, weight: .bold))
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
    @AppStorage("navigationPillSize") private var navigationPillSize: Double = 1.0
    @AppStorage("cueCapsuleSize") private var cueCapsuleSize: Double = 1.0
    @AppStorage("fontSize") private var fontSize: Double = 1.0
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

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
                    .buttonStyle(.plain)

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
                            .tint(selectedTheme.defaultCueColor(for: colorScheme))

                        HStack {
                            Text("70%")
                                .font(.caption)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            Spacer()
                            Text("150%")
                                .font(.caption)
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

                // Navigation Pill Size Section
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Scale")
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                            Text("\(Int(navigationPillSize * 100))%")
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                .font(.system(.body, design: .monospaced))
                        }

                        Slider(value: $navigationPillSize, in: 0.7...1.5, step: 0.05)
                            .tint(selectedTheme.defaultCueColor(for: colorScheme))

                        HStack {
                            Text("70%")
                                .font(.caption)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            Spacer()
                            Text("150%")
                                .font(.caption)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("NAVIGATION PILL SIZE")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } footer: {
                    Text("Adjusts the size of the prev/next navigation pill")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                // Cue Capsule Size Section
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Scale")
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                            Text("\(Int(cueCapsuleSize * 100))%")
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                .font(.system(.body, design: .monospaced))
                        }

                        Slider(value: $cueCapsuleSize, in: 0.8...1.5, step: 0.05)
                            .tint(selectedTheme.defaultCueColor(for: colorScheme))

                        HStack {
                            Text("80%")
                                .font(.caption)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            Spacer()
                            Text("150%")
                                .font(.caption)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("CUE CAPSULE SIZE")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } footer: {
                    Text("Adjusts the size of the GO capsule transport controls")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                // Reset Section
                Section {
                    Button {
                        showMIDIData = true
                        cueHeight = 86
                        navigationPillSize = 1.0
                        cueCapsuleSize = 1.0
                        fontSize = 1.0
                        customDefaultCueColorStorage = ""
                        showColorPicker = false
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("Reset to Defaults")
                            .font(.body.weight(.semibold))
                            .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
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
            .toolbarBackground(selectedTheme.backgroundColor(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
                }
            }
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
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
