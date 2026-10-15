//
//  ProjectsSheet.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation

struct CBProjectsSheet: View {
    @Binding var projectName: String
    let projects: [String]
    @Binding var isDirty: Bool

    var onTapTitleWhenUnsaved: () -> Void
    var onLoad: (String) -> Void
    var onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @State private var confirmDelete: String? = nil

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Project")
                            .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                        Spacer()
                        if projectName == "Untitled" || isDirty {
                            Button(projectName) { onTapTitleWhenUnsaved() }
                                .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                        } else {
                            Text(projectName)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                }
                .cbRow()

                Section(header: Text("Saved Projects").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    if projects.isEmpty {
                        Text("No saved projects yet.")
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            .cbRow()
                    } else {
                        ForEach(projects, id: \.self) { name in
                            HStack {
                                Button(name) { onLoad(name); dismiss() }
                                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                                Button {
                                    debugPrint("🗑️ Delete button tapped for project: \(name)")
                                    confirmDelete = name
                                    debugPrint("🗑️ Set confirmDelete to: \(name)")
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                }
                                .buttonStyle(.plain)
                            }
                            .cbRow()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CBSheetButton(title: "Close") { dismiss() }
                }
            }
            .tint(selectedTheme.accentColor(for: colorScheme))
            .cbDialog("Delete Project", isPresented: Binding(get: { confirmDelete != nil }, set: { newVal in if !newVal { confirmDelete = nil } }), themeFont: selectedTheme.font,
                message: "Are you sure you want to delete '\(confirmDelete ?? "")'? This action cannot be undone.",
                buttons: [
                    .init("Delete", role: .destructive) {
                        debugPrint("🗑️ Delete confirmed for project: \(confirmDelete ?? "nil")")
                        if let n = confirmDelete {
                            debugPrint("🗑️ Calling onDelete with: \(n)")
                            onDelete(n)
                        }
                        confirmDelete = nil
                    },
                    .init("Cancel", role: .cancel) {
                        debugPrint("🗑️ Delete cancelled for project: \(confirmDelete ?? "nil")")
                        confirmDelete = nil
                    }
                ]
            )
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}
