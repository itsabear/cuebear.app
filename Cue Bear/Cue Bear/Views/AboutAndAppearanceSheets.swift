import SwiftUI

// MARK: - About Sheet
struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

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
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
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
                        linkButton(title: "Email Support", icon: "envelope.fill", url: "mailto:support@cuebear.app")
                        linkButton(title: "Website", icon: "globe", url: "https://cuebear.app")
                        linkButton(title: "Privacy Policy", icon: "hand.raised.fill", url: "https://cuebear.app/privacy")
                    }
                    .padding(.horizontal, 40)

                    // Copyright
                    Text("© 2024 Omri Behr. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                }
            }
            .tint(selectedTheme.buttonBackgroundColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func linkButton(title: String, icon: String, url: String) -> some View {
        let accentColor = selectedTheme.accentColor(for: colorScheme)

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
            .background(accentColor.opacity(0.1))
            .foregroundColor(accentColor)
            .cornerRadius(12)
        }
    }
}

// MARK: - Appearance Sheet
struct AppearanceSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var originalThemeID: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
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
            .id(selectedThemeID) // Force view recreation when theme changes
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(selectedTheme.backgroundColor(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(selectedTheme.buttonBackgroundColor(for: colorScheme))
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
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
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
                    .foregroundColor(.green)
                Text("ACTIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
            }
            .opacity(isSelected ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(selectedTheme.titleBarColor(for: colorScheme))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? theme.accentColor(for: colorScheme) : Color.clear, lineWidth: 3)
        )
        .shadow(color: isSelected ? theme.accentColor(for: colorScheme).opacity(0.3) : Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
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
