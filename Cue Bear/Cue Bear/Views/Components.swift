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
                Text(label).font(.custom("Sora-Bold", size: 13))
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
    var isDragging: Bool = false  // Disable buttons during drag
    var onPrev: () -> Void
    var onGo: () -> Void
    var onNext: () -> Void
    var onClear: () -> Void

    @State private var isGoPressed = false

    var body: some View {
        GeometryReader { geo in
            // Scale everything to fit the container
            let containerWidth = geo.size.width
            let containerHeight = geo.size.height
            let goButtonSize = min(containerWidth - 20, 100)  // Leave 10px padding on each side
            let buttonHeight = (containerHeight - goButtonSize - 20) / 2  // Split remaining height for +/- buttons

            VStack(spacing: 0) {
                // Top button: Up arrow (PREVIOUS)
                Button(action: onPrev) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: min(28, containerWidth * 0.22), weight: .bold))
                        .foregroundColor(canPrev ? .primary : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canPrev || isDragging)
                .frame(height: buttonHeight)

                // Divider
                Divider()
                    .frame(height: 1)

                // Middle: GO button — fires on touch-down for zero latency
                Text("GO")
                    .font(.custom("Sora-Bold", size: min(32, containerWidth * 0.25)))
                    .foregroundColor(.black)
                    .frame(width: goButtonSize, height: goButtonSize)
                    .background(isGoEnabled ? Color.white : Color.gray)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(isGoPressed ? 0.1 : 0.3), radius: isGoPressed ? 1 : 6, x: 0, y: isGoPressed ? 0 : 3)
                    .scaleEffect(isGoPressed ? 0.92 : 1.0)
                    .opacity(isGoPressed ? 0.7 : 1.0)
                    .animation(.easeOut(duration: 0.06), value: isGoPressed)
                    .contentShape(Circle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !isGoPressed, isGoEnabled, !isDragging else { return }
                                isGoPressed = true
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                onGo()
                            }
                            .onEnded { _ in
                                isGoPressed = false
                            }
                    )
                    .allowsHitTesting(isGoEnabled && !isDragging)
                .padding(.vertical, 4)

                // Divider
                Divider()
                    .frame(height: 1)

                // Bottom button: Down arrow (NEXT)
                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: min(28, containerWidth * 0.22), weight: .bold))
                        .foregroundColor(canNext ? .primary : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canNext || isDragging)
                .frame(height: buttonHeight)
            }
            .frame(width: containerWidth, height: containerHeight)
        }
    }
}

// MARK: - iOS-like press button style (for plain buttons that need press feedback)
/// Mimics Apple's native button feedback - opacity dim only, no scale
struct IOSPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

// MARK: - Dark glass button style (for menu/control bars)
struct WhiteCapsuleButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 28)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.7 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.4 : 0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ThemedCapsuleButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let strokeColor: Color
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        ButtonStyleBody(
            configuration: configuration,
            cornerRadius: cornerRadius
        )
    }

    private struct ButtonStyleBody: View {
        let configuration: Configuration
        let cornerRadius: CGFloat

        @Environment(\.isEnabled) private var isEnabled

        private var isPhone: Bool {
            UIDevice.current.userInterfaceIdiom == .phone
        }

        var body: some View {
            configuration.label
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(.white.opacity(0.9))
                .frame(minHeight: isPhone ? 28 : 36)
                .padding(.horizontal, isPhone ? 14 : 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.black.opacity(configuration.isPressed ? 0.7 : 0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(configuration.isPressed ? 0.4 : 0.2), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .opacity(isEnabled ? 1.0 : 0.4)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
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
                    Text(sub).font(.custom("Sora-Regular", size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

// MARK: - Custom Dialog (replaces system .alert with themed design)

struct CBDialogButton: Identifiable {
    let id = UUID()
    let title: String
    let role: Role
    let action: () -> Void

    enum Role {
        case primary      // White filled, black text
        case secondary    // Outlined, white text
        case destructive  // Red filled, white text
        case cancel       // Outlined, white text
    }

    init(_ title: String, role: Role = .primary, action: @escaping () -> Void = {}) {
        self.title = title
        self.role = role
        self.action = action
    }
}

private struct CBDialogButtonStyle: ButtonStyle {
    let role: CBDialogButton.Role

    func makeBody(configuration: Configuration) -> some View {
        let isOutlined = role == .secondary || role == .cancel
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor(pressed: configuration.isPressed))
            )
            .overlay(
                Group {
                    if isOutlined {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private func backgroundColor(pressed: Bool) -> Color {
        switch role {
        case .primary:
            return pressed ? Color.white.opacity(0.7) : Color.white
        case .destructive:
            return pressed ? Color.red.opacity(0.7) : Color.red
        case .secondary, .cancel:
            return pressed ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
        }
    }
}

struct CBDialog: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    var textField: Binding<String>?
    var textFieldPlaceholder: String
    let themeFont: (CGFloat, Font.Weight) -> Font
    let buttons: [CBDialogButton]

    @FocusState private var isTextFieldFocused: Bool

    init(
        isPresented: Binding<Bool>,
        title: String,
        message: String = "",
        textField: Binding<String>? = nil,
        textFieldPlaceholder: String = "",
        themeFont: @escaping (CGFloat, Font.Weight) -> Font,
        buttons: [CBDialogButton]
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.textField = textField
        self.textFieldPlaceholder = textFieldPlaceholder
        self.themeFont = themeFont
        self.buttons = buttons
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            dialogCard
        }
        .onAppear {
            if textField != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private var dialogCard: some View {
        VStack(spacing: 20) {
            dialogHeader
            dialogTextField
            dialogButtons
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
    }

    @ViewBuilder
    private var dialogHeader: some View {
        Text(title)
            .font(themeFont(20, .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

        if !message.isEmpty {
            Text(message)
                .font(themeFont(14, .regular))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var dialogTextField: some View {
        if let tf = textField {
            TextField(textFieldPlaceholder, text: tf)
                .font(themeFont(16, .regular))
                .foregroundColor(.white)
                .tint(.white)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
                .focused($isTextFieldFocused)
                .onSubmit {
                    if let primary = buttons.first(where: { $0.role == .primary }) {
                        primary.action()
                        isPresented = false
                    }
                }
        }
    }

    private var dialogButtons: some View {
        VStack(spacing: 10) {
            ForEach(buttons) { button in
                Button {
                    button.action()
                    isPresented = false
                } label: {
                    Text(button.title)
                        .font(themeFont(16, .semibold))
                        .foregroundColor(foregroundColor(for: button.role))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(CBDialogButtonStyle(role: button.role))
            }
        }
    }

    private func foregroundColor(for role: CBDialogButton.Role) -> Color {
        switch role {
        case .primary: return .black
        case .destructive: return .white
        case .secondary, .cancel: return .white
        }
    }
}

extension View {
    func cbDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        themeFont: @escaping (CGFloat, Font.Weight) -> Font,
        message: String = "",
        textField: Binding<String>? = nil,
        textFieldPlaceholder: String = "",
        buttons: [CBDialogButton]
    ) -> some View {
        self.overlay {
            if isPresented.wrappedValue {
                CBDialog(
                    isPresented: isPresented,
                    title: title,
                    message: message,
                    textField: textField,
                    textFieldPlaceholder: textFieldPlaceholder,
                    themeFont: themeFont,
                    buttons: buttons
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPresented.wrappedValue)
    }
}

// MARK: - Sheet Toolbar Button (avoids iOS 18+ toolbar Button chrome)
// iOS 18+ wraps `Button` inside `ToolbarItem` in a default capsule. Using a tappable
// styled view (no Button) skips that auto-chrome so we get only our square edges.
struct CBSheetButton: View {
    let title: String
    var bold: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            Text(title)
                .font(.custom(bold ? "Sora-Bold" : "Sora-Regular", size: 15))
                .foregroundColor(disabled ? .white.opacity(0.3) : .white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// Icon-only variant: 44x44 square with SF Symbol.
struct CBSheetIconButton: View {
    let systemName: String
    var weight: Font.Weight = .semibold
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: weight))
                .foregroundColor(disabled ? .white.opacity(0.3) : .white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// Menu variant: same square chrome, holds a Menu so iOS won't add capsule chrome
// because the styled label is the menu's tap target (no surrounding Button wrapper).
struct CBSheetIconMenu<Content: View>: View {
    let systemName: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
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

