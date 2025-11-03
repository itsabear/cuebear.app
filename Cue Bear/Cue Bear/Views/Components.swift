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
    public let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function

    /// Back-compat init: pass your Setlist; title defaults to "Setlist"
    public init(setlist: Setlist, title: String? = nil, themeFont: ((CGFloat, Font.Weight) -> Font)? = nil) {
        self.count = setlist.songs.count
        self.title = title ?? "Setlist"
        self.themeFont = themeFont
    }

    /// Direct init: pass a title and an item count
    public init(title: String, count: Int, themeFont: ((CGFloat, Font.Weight) -> Font)? = nil) {
        self.title = title
        self.count = count
        self.themeFont = themeFont
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text(title.isEmpty ? "Setlist" : title)
                .font(themeFont?(18, .semibold) ?? .headline)
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

    @State private var isGoPressed = false

    var body: some View {
        let chipHeight: CGFloat = 28
        VStack(spacing: 6) {
            ZStack {
            if let name = cuedName {
                HStack(spacing: 8) {
                    // v1.0.9: Truncate to 19 characters with ellipsis
                    Text("Next: \(String(name.prefix(19)))\(name.count > 19 ? "..." : "")")
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
                // v1.0.9: Add tap animation like control area buttons
                .scaleEffect(isGoPressed ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isGoPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isGoPressed {
                                isGoPressed = true
                            }
                        }
                        .onEnded { _ in
                            isGoPressed = false
                        }
                )

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
            .frame(minHeight: 28)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.15)))
            .shadow(color: Color.primary.opacity(0.05), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct ThemedCapsuleButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let strokeColor: Color
    var cornerRadius: CGFloat = 10

    // Helper to check if a color is too light/bright for good visibility
    private func isColorTooLight(_ color: Color) -> Bool {
        guard let components = UIColor(color).cgColor.components else { return false }

        // Calculate relative luminance using sRGB formula
        let red = components.count > 0 ? components[0] : 0
        let green = components.count > 1 ? components[1] : 0
        let blue = components.count > 2 ? components[2] : 0

        // Weighted luminance calculation (human eye is more sensitive to green)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue

        // If luminance > 0.7, it's too light for good visibility on light background
        return luminance > 0.7
    }

    // Create a darker version of the color for better visibility
    private func darkenColor(_ color: Color) -> Color {
        guard let components = UIColor(color).cgColor.components else { return color }

        let red = (components.count > 0 ? components[0] : 0) * 0.5
        let green = (components.count > 1 ? components[1] : 0) * 0.5
        let blue = (components.count > 2 ? components[2] : 0) * 0.5
        let alpha = components.count > 3 ? components[3] : 1.0

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    func makeBody(configuration: Configuration) -> some View {
        ButtonStyleBody(
            configuration: configuration,
            backgroundColor: backgroundColor,
            strokeColor: strokeColor,
            cornerRadius: cornerRadius,
            isColorTooLight: isColorTooLight,
            darkenColor: darkenColor
        )
    }

    private struct ButtonStyleBody: View {
        let configuration: Configuration
        let backgroundColor: Color
        let strokeColor: Color
        let cornerRadius: CGFloat
        let isColorTooLight: (Color) -> Bool
        let darkenColor: (Color) -> Color

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            // Use darker text color if stroke color is too light
            let textColor = isColorTooLight(strokeColor) ? darkenColor(strokeColor) : strokeColor

            configuration.label
                .foregroundColor(textColor)
                .frame(minHeight: 28)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(strokeColor, lineWidth: 1.5))
                .shadow(color: strokeColor.opacity(0.2), radius: 2, x: 0, y: 1)
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
                .opacity(isEnabled ? 1.0 : 0.4)  // Grey out when disabled
        }
    }
}

// MARK: - Draggable transport dock with snap-to-bottom-center (SIMPLIFIED)
struct DraggableTransportDock: View {
    let width: CGFloat
    let height: CGFloat
    let controlAreaHeight: CGFloat
    let cuedName: String?
    let canPrev: Bool
    let canNext: Bool
    let isGoEnabled: Bool
    let onPrev: () -> Void
    let onGo: () -> Void
    let onNext: () -> Void
    let onClear: () -> Void
    let isControlEditing: Bool

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        let scale: CGFloat = 1.20

        // Pill is HORIZONTAL (wider than tall)
        // Based on actual layout: HStack with 3 buttons + padding in a capsule
        let basePillWidth: CGFloat = 271.5   // Horizontal: 57 + 24 + 82.5 + 24 + 57 + 27 padding
        let basePillHeight: CGFloat = 110    // Vertical: chip(28) + spacing(6) + buttons(82.5) + padding(18)

        let scaledPillWidth = basePillWidth * scale   // ~326pts wide
        let scaledPillHeight = basePillHeight * scale // ~132pts tall

        // .position() uses CENTER coordinates
        // Boundaries for pill center to keep entire pill on screen
        let minCenterX = scaledPillWidth / 2
        let maxCenterX = width - (scaledPillWidth / 2)
        let minCenterY = scaledPillHeight / 2
        let maxCenterY = height - controlAreaHeight - (scaledPillHeight / 2) - 8

        // Default: centered horizontally, almost touching control area vertically
        let defaultCenterX = width / 2
        let defaultCenterY = maxCenterY

        // Apply drag and constrain
        let targetCenterX = defaultCenterX + dragOffset.width
        let targetCenterY = defaultCenterY + dragOffset.height
        let constrainedX = min(max(targetCenterX, minCenterX), maxCenterX)
        let constrainedY = min(max(targetCenterY, minCenterY), maxCenterY)

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
        .scaleEffect(scale)
        .position(x: constrainedX, y: constrainedY)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    dragOffset = value.translation
                }
        )
    }
}

// MARK: - Lightweight row-like container (title/subtitle + leading/trailing slots)
public struct RowLike<Leading: View, Trailing: View>: View {
    public let title: String
    public let subtitle: String?
    public let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    public var leading: () -> Leading
    public var trailing: () -> Trailing

    public init(title: String,
                subtitle: String? = nil,
                themeFont: ((CGFloat, Font.Weight) -> Font)? = nil,
                @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.themeFont = themeFont
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(themeFont?(17, .bold) ?? .body.bold())
                    .foregroundStyle(.primary)
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
            RowLike(title: "Row Title", subtitle: "Subtitle", themeFont: nil, leading: {
                Image(systemName: "bolt.fill")
            }, trailing: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            })
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

