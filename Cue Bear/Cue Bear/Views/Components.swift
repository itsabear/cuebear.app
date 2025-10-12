//
//  Components.swift — Cue Bear (compat-safe)
//  - Works whether Setlist has a `name` or not
//  - Transport bar uses Prev/Play/Stop/Next (no Pause needed)
//

import SwiftUI
import UIKit

// MARK: - Setlist Header (no hard dependency on Setlist.name)
public struct SetlistHeader: View {
    public let title: String
    public let count: Int

    /// Back-compat init: pass your Setlist; title defaults to "Setlist"
    public init(setlist: Setlist, title: String? = nil) {
        self.count = setlist.songs.count
        self.title = title ?? "Setlist"
    }

    /// Direct init: pass a title and an item count
    public init(title: String, count: Int) {
        self.title = title
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text(title.isEmpty ? "Setlist" : title)
                .font(.headline)
            Spacer()
            Text("\(count) item\(count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Key/Value Row (simple 2-col display for forms/sheets)
public struct KeyValueRow: View {
    public let key: String
    public let value: String

    public init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }

    public var body: some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Transport Bar (Prev · Play · Stop · Next)
public struct CBTransportBar: View {
    public var onAction: (TransportAction) -> Void

    public init(onAction: @escaping (TransportAction) -> Void) {
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: 18) {
            CBTransportTile(icon: "backward.end.fill", label: "Prev") { onAction(.prev) }
            CBTransportTile(icon: "play.fill",          label: "Play") { onAction(.play) }
            CBTransportTile(icon: "stop.fill",          label: "Stop") { onAction(.stop) }
            CBTransportTile(icon: "forward.end.fill",   label: "Next") { onAction(.next) }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

public struct CBTransportTile: View {
    public let icon: String
    public let label: String
    public var action: () -> Void

    @State private var down = false

    public init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 24, weight: .semibold))
                Text(label).font(.footnote.weight(.semibold))
            }
            .foregroundColor(down ? .white : .primary)
            .frame(width: 120, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(down ? Color.accentColor : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true } }
                .onEnded { _ in down = false }
        )
    }
}

// MARK: - Centered Floating Transport Dock (Prev · GO · Next) with Clear in label
struct CBTransportDock: View {
    let cuedName: String?
    var canPrev: Bool = true
    var canNext: Bool = true
    var isGoEnabled: Bool = true
    var onPrev: () -> Void
    var onGo: () -> Void
    var onNext: () -> Void
    var onClear: () -> Void

    var body: some View {
        let chipHeight: CGFloat = 28
        VStack(spacing: 6) {
            ZStack {
            if let name = cuedName {
                HStack(spacing: 8) {
                    Text("Next: \(name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Clear cued item")
                }
                .padding(.horizontal, 12)
                .background(Color.clear)
                .clipShape(Capsule())
                }
            }
            .frame(height: chipHeight)

            HStack(spacing: 24) {
                Button(action: onPrev) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22.5, weight: .semibold))
                        .frame(width: 57, height: 57)
                        .background(Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canPrev)
                .opacity(canPrev ? 1.0 : 0.5)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onGo()
                }) {
                    Text("GO")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 82.5, height: 82.5)
                        .background(isGoEnabled ? Color.accentColor : Color.gray)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isGoEnabled)

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22.5, weight: .semibold))
                        .frame(width: 57, height: 57)
                        .background(Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canNext)
                .opacity(canNext ? 1.0 : 0.5)
            }
            .padding(.horizontal, 13.5)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        }
    }
}

// MARK: - White capsule button style (for menu/control bars)
struct WhiteCapsuleButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.15)))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Draggable transport dock with snap-to-bottom-center
struct DraggableTransportDock: View {
    let width: CGFloat
    let height: CGFloat
    @Binding var controlAreaHeight: CGFloat
    let cuedName: String?
    let canPrev: Bool
    let canNext: Bool
    let isGoEnabled: Bool
    let onPrev: () -> Void
    let onGo: () -> Void
    let onNext: () -> Void
    let onClear: () -> Void
    let isControlEditing: Bool

    // Simplified state for drag handling
    @State private var position: CGPoint = .zero
    @State private var isTrackingDrag: Bool = false
    @State private var isDragging: Bool = false

    // Visual size of the transport capsule (20% larger than baseline)
    private var dockSize: CGSize { CGSize(width: 320 * 1.20, height: 150 * 1.20) }

    // Calculate proper upper limit to be flush with menu bar (small padding)
    private var upperLimit: CGFloat {
        return 64 + 10 // Menu bar height + small padding
    }

    var body: some View {
        ZStack {
            CBTransportDock(
                cuedName: cuedName,
                canPrev: canPrev,
                canNext: canNext,
                isGoEnabled: isGoEnabled,
                onPrev: onPrev,
                onGo: onGo,
                onNext: onNext,
                onClear: onClear
            )
            // Render 20% larger for better hit targets as requested
            .scaleEffect(1.20)
            // While dragging, prevent internal buttons from handling touches to avoid gesture competition
            .allowsHitTesting(!isDragging)
        }
        .frame(width: dockSize.width, height: dockSize.height)
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .highPriorityGesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .local)
                .onChanged { value in
                    if !isTrackingDrag {
                        isTrackingDrag = true
                        isDragging = true
                        if position == .zero {
                            let bottomCenterY = max(upperLimit, height - controlAreaHeight - 20)
                            let bottomCenterX = max(50, min(width - 50, width / 2))
                            position = CGPoint(x: bottomCenterX, y: bottomCenterY)
                        }
                    }

                    // Update position directly during drag for smooth 1:1 movement
                    let newX = max(50, min(width - 50, position.x + value.translation.width))
                    let newY = max(upperLimit, min(height - 100, position.y + value.translation.height))

                    position = CGPoint(x: newX, y: newY)
                }
                .onEnded { value in
                    defer {
                        isTrackingDrag = false
                        isDragging = false
                    }

                    // Final position update
                    let newX = max(50, min(width - 50, position.x + value.translation.width))
                    let newY = max(upperLimit, min(height - 100, position.y + value.translation.height))

                    position = CGPoint(x: newX, y: newY)
                }
        )
        .position(
            x: max(50, min(width - 50, position.x)),
            y: max(upperLimit, min(height - 100, position.y))
        )
        // Ensure default position snaps once control area height is known
        .task(id: "\(width)-\(height)") {
            // Only initialize if we have valid dimensions
            guard width > 0 && height > 0 else { return }

            if position == .zero {
                // Initialize to bottom center position (not middle of screen)
                let bottomCenterY = max(upperLimit, height - controlAreaHeight - 20) // 20 points above control area
                let bottomCenterX = max(50, min(width - 50, width / 2))

                // FIX: Disable animation for initial positioning to prevent "flying in" from (0,0)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    position = CGPoint(x: bottomCenterX, y: bottomCenterY)
                }
            }
        }
        .onChange(of: controlAreaHeight) { _, _ in
            // Avoid any position adjustments mid-drag to prevent jitter
            if isDragging { return }
            guard position != .zero else {
                // Initialize to bottom center position (not middle of screen)
                let bottomCenterY = max(upperLimit, height - controlAreaHeight - 20) // 20 points above control area
                let bottomCenterX = max(50, min(width - 50, width / 2))

                // FIX: Disable animation for initial positioning
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    position = CGPoint(x: bottomCenterX, y: bottomCenterY)
                }
                return
            }

            // NO AUTO-SNAPPING - leave capsule exactly where user placed it
            // CONSTRAINED MOVEMENT - prevent dragging onto menu bar or control area
        }
        .onChange(of: isControlEditing) { _, editing in
            guard !isDragging else { return }
            // NO AUTO-SNAPPING - leave capsule exactly where user placed it
            // CONSTRAINED MOVEMENT - prevent dragging onto menu bar or control area
        }
    }
}

// MARK: - Lightweight row-like container (title/subtitle + leading/trailing slots)
public struct RowLike<Leading: View, Trailing: View>: View {
    public let title: String
    public let subtitle: String?
    public var leading: () -> Leading
    public var trailing: () -> Trailing

    public init(title: String,
                subtitle: String? = nil,
                @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.bold()).foregroundStyle(.primary)
                if let sub = subtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

// MARK: - Previews (optional)
#if DEBUG
struct Components_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Your Setlist may not have a name; pass a title explicitly:
            SetlistHeader(setlist: Setlist(songs: []), title: "My Show")
            CBTransportBar { _ in }
            RowLike(title: "Row Title", subtitle: "Subtitle") {
                Image(systemName: "bolt.fill")
            } trailing: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

