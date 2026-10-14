//
//  Components.swift — Cue Bear (compat-safe)
//  - Works whether Setlist has a `name` or not
//  - Transport bar uses Prev/Play/Stop/Next (no Pause needed)
//

import SwiftUI
import UIKit

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
                        .font(.cbIcon(points: min(28, containerWidth * 0.22), .bold))
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
                    .font(.cb(points: min(32, containerWidth * 0.25), .bold))
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
                        .font(.cbIcon(points: min(28, containerWidth * 0.22), .bold))
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
                RoundedRectangle(cornerRadius: CBRadius.control)
                    .fill(backgroundColor(pressed: configuration.isPressed))
            )
            .overlay(
                Group {
                    if isOutlined {
                        RoundedRectangle(cornerRadius: CBRadius.control)
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
        .background(RoundedRectangle(cornerRadius: CBRadius.panel).fill(Color.black.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: CBRadius.panel).stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: CBRadius.control).stroke(Color.white.opacity(0.25), lineWidth: 1))
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
                .font(.cb(.body, bold ? .bold : .regular))
                .foregroundColor(disabled ? .white.opacity(0.3) : .white)
                .lineLimit(1)
                .fixedSize()   // never squeeze or wrap the label (toolbars on iPadOS 26 propose a narrow width)
                .padding(.horizontal, 14)
                .frame(minWidth: 44)
                .frame(height: 44)
                .cbChip()
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
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
                .font(.cbIcon(.large, weight))
                .foregroundColor(disabled ? .white.opacity(0.3) : .white)
                .frame(width: 44, height: 44)
                .cbChip()
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
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
                .font(.cbIcon(.large, .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .cbChip()
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
}
