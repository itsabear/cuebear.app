import SwiftUI

// Standalone, preview-only transport concepts. Not wired into the app runtime.

struct CBPreviewTransportBar: View {
    let cuedName: String?
    var onPrev: () -> Void = {}
    var onGo: () -> Void = {}
    var onNext: () -> Void = {}
    var isGoEnabled: Bool = true

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(cuedName != nil ? "Cued: \(cuedName!)" : "No cue selected")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)

            HStack(spacing: 28) {
                Button(action: onPrev) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous")

                Button(action: onGo) {
                    Text("GO")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(isGoEnabled ? Color.accentColor : Color.gray)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!isGoEnabled)
                .accessibilityLabel("GO")

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next")
            }
        }
        .padding(.vertical, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

struct CBPreviewTransportDock: View {
    let cuedName: String?
    var onPrev: () -> Void = {}
    var onGo: () -> Void = {}
    var onNext: () -> Void = {}
    var isGoEnabled: Bool = true
    var showClear: Bool = false
    var onClear: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            if let name = cuedName {
                HStack(spacing: 8) {
                    Text("Next: \(name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    if showClear {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear cued item")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            } else {
                Text("No cue selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 24) {
                Button(action: onPrev) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .frame(width: 76, height: 76)
                        .background(Color(.systemBackground).opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onGo) {
                    Text("GO")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 110, height: 110)
                        .background(isGoEnabled ? Color.accentColor : Color.gray)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isGoEnabled)

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .frame(width: 76, height: 76)
                        .background(Color(.systemBackground).opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        }
    }
}

struct CBTransportBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Color(UIColor.secondarySystemBackground)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    CBPreviewTransportBar(cuedName: "Intro – 120 BPM")
                }
            }
            .previewDisplayName("Sticky Transport Bar – Enabled")

            ZStack {
                Color(UIColor.secondarySystemBackground)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    CBPreviewTransportBar(cuedName: nil, isGoEnabled: false)
                }
            }
            .previewDisplayName("Sticky Transport Bar – Disabled")
        }
        .previewLayout(.fixed(width: 1024, height: 768))
    }
}

struct CBTransportDock_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    CBPreviewTransportDock(cuedName: "Verse – 95 BPM")
                        .padding(.bottom, 40)
                }
            }
            .previewDisplayName("Floating Dock – Enabled")

            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    CBPreviewTransportDock(cuedName: nil, isGoEnabled: false)
                        .padding(.bottom, 40)
                }
            }
            .previewDisplayName("Floating Dock – Disabled")
        }
        .previewLayout(.fixed(width: 1024, height: 768))
    }
}

struct CBTransportDock_WithClear_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            VStack {
                Spacer()
                CBPreviewTransportDock(cuedName: "Chorus – 128 BPM", showClear: true)
                    .padding(.bottom, 40)
            }
        }
        .previewLayout(.fixed(width: 1024, height: 768))
        .previewDisplayName("Floating Dock – With Clear Chip")
    }
}


