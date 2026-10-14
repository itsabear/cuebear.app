//
//  BugReportView.swift
//  Cue Bear
//
//  Bug report sheet with email composition
//

import SwiftUI
import MessageUI

/// View for submitting bug reports with optional user comments
struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    @State private var userComments: String = ""
    @State private var showingMailComposer = false
    @State private var showingMailError = false
    @State private var mailErrorMessage = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    /// Adaptive text color for button based on background brightness
    private var buttonTextColor: Color {
        let backgroundColor = selectedTheme.defaultCueColor(for: colorScheme)
        return backgroundColor.needsDarkText() ? .black : .white
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Help us improve Cue Bear by reporting any issues you've encountered.")
                        .font(.cb(.small))
                        .foregroundColor(.secondary)
                } header: {
                    Text("Report a Bug")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if userComments.isEmpty {
                            Text("Describe the issue you experienced... (optional)")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }

                        TextEditor(text: $userComments)
                            .frame(minHeight: 120)
                            .opacity(userComments.isEmpty ? 0.5 : 1)
                    }
                } header: {
                    Text("Comments")
                } footer: {
                    Text("Your comments help us understand and fix the issue faster. Device and app information will be included automatically.")
                        .font(.cb(.caption))
                }

                Section {
                    Text("The following information will be included: app version, device model and iOS version, memory usage, and crash logs (if available).\n\nNo personal data or project content will be shared.")
                        .font(.cb(.caption))
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        .padding(.vertical, 4)
                } header: {
                    Text("What Gets Sent")
                }
                .listRowBackground(Color.clear)

                Section {
                    Button(action: sendBugReport) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Bug Report")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(buttonTextColor)
                    }
                    .listRowBackground(selectedTheme.defaultCueColor(for: colorScheme))
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Report Bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposerView(
                    recipients: ["support@cuebear.app"],
                    subject: "Cue Bear Bug Report",
                    body: CrashReporter.shared.generateBugReportEmail(userComments: userComments),
                    onDismiss: {
                        dismiss()
                    }
                )
            }
            .alert("Cannot Send Email", isPresented: $showingMailError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(mailErrorMessage)
            }
        }
    }

    private func sendBugReport() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            // Fallback: Copy to clipboard or show error
            mailErrorMessage = "Mail is not configured on this device. Please email support@cuebear.app directly."
            showingMailError = true
        }
    }
}

// MARK: - Mail Composer Wrapper
struct MailComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    let onDismiss: () -> Void

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // Only dismiss the bug report view if email was sent successfully
            controller.dismiss(animated: true) {
                if result == .sent {
                    self.parent.onDismiss()
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Crash Alert View
/// Alert view shown when app detects a previous crash
struct CrashAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    @State private var showingBugReport = false

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    /// Adaptive text color for button based on background brightness
    private var buttonTextColor: Color {
        let backgroundColor = selectedTheme.defaultCueColor(for: colorScheme)
        return backgroundColor.needsDarkText() ? .black : .white
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.cbIcon(.hero, .regular))
                    .foregroundColor(selectedTheme.warningColor(for: colorScheme))

                VStack(spacing: 12) {
                    Text("App Recovered")
                        .font(.cb(.title))
                        .fontWeight(.bold)

                    Text("Cue Bear encountered an issue during the last session. Would you like to send a bug report?")
                        .font(.cb(.body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        showingBugReport = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Bug Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedTheme.defaultCueColor(for: colorScheme))
                        .foregroundColor(buttonTextColor)
                        .cornerRadius(CBRadius.card)
                    }
                    .padding(.horizontal)

                    Button(action: {
                        CrashReporter.shared.clearCrashLog()
                        dismiss()
                    }) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingBugReport) {
                BugReportView()
            }
            .onChange(of: showingBugReport) { oldValue, newValue in
                if !newValue {
                    // User dismissed bug report, clear crash log and dismiss alert
                    CrashReporter.shared.clearCrashLog()
                    dismiss()
                }
            }
        }
    }
}

#Preview("Bug Report") {
    BugReportView()
}

#Preview("Crash Alert") {
    CrashAlertView()
}
