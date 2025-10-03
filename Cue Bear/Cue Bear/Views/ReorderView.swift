import SwiftUI

/// Dedicated screen for reordering the setlist.
/// Always shows big drag handles; no distractions.
struct ReorderView: View {
    @Binding var songs: [Song]
    var onDone: () -> Void

    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationView {
            List {
                ForEach(songs) { song in
                    HStack(spacing: 14) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.name)
                                .font(.headline)
                                .lineLimit(1)
                            if let sub = song.subtitle, !sub.isEmpty {
                                Text(sub)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("CC #\(song.cc)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .onMove(perform: move)
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode) // keeps drag handles on
            .navigationTitle("Reorder Cues")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("A–Z") {
                        withAnimation(.easeOut(duration: 0.15)) {
                            songs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        }
                    }
                    .accessibilityLabel("Sort A to Z")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDone() }
                        .bold()
                }
            }
        }
        .onAppear { editMode = .active }
    }

    private func move(from: IndexSet, to: Int) {
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0.10)) {
            songs.move(fromOffsets: from, toOffset: to)
        }
    }
}
