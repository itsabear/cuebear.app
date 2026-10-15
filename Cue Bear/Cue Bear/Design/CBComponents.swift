//
//  CBComponents.swift — Cue Bear design foundation
//
//  The standard pieces every screen is built from. Each one takes its look from CBTokens.swift.
//
//  Surfaces:   .cbChip()  .cbCard()  .cbRow()
//  Screens:    .cbSheetChrome()  .cbFormChrome()  CBSheetHeader
//  Actions:    CBButtonStyle (.primary / .secondary / .destructive / .highlight)
//              CBSheetButton, CBSheetIconButton, CBSheetIconMenu (in Components.swift)
//  Labels:     CBSectionLabel  CBPill  CBStatusDot
//

import SwiftUI

// MARK: - Surfaces

extension View {
    /// Floating chip over content: the top bar capsules, toolbar buttons.
    func cbChip(radius: CGFloat = CBRadius.control) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(CBColor.chip))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(CBColor.stroke, lineWidth: CBSize.hairline))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    /// A card on the screen background. `outline` draws a colored edge (selection, "now").
    func cbCard(fill: Color = CBColor.surface,
                outline: Color? = nil,
                outlineWidth: CGFloat = CBSize.selection,
                padding: CGFloat = CBSpace.l,
                radius: CGFloat = CBRadius.card) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay {
                if let outline {
                    RoundedRectangle(cornerRadius: radius).stroke(outline, lineWidth: outlineWidth)
                }
            }
    }

    /// Row background inside a Form or List.
    func cbRow() -> some View {
        listRowBackground(CBColor.surface)
    }

    /// Form or List on the screen background (hides the system grouped background).
    func cbFormChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(CBColor.background)
            .tint(CBColor.highlight)
    }

    /// Everything a sheet needs: background, dark scheme, default type and tint.
    func cbSheetChrome() -> some View {
        self
            .font(.cb(.body))
            .foregroundStyle(CBColor.textPrimary)
            .tint(CBColor.highlight)
            .background(CBColor.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

// MARK: - Sheet header

/// The header every sheet uses: optional leading action, centered title, optional trailing action.
/// Replaces the system toolbar so sheets look the same on every iPadOS version.
struct CBSheetHeader: View {
    let title: String
    var leadingTitle: String? = nil
    var leadingAction: (() -> Void)? = nil
    var trailingTitle: String? = nil
    var trailingDisabled: Bool = false
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Text(title)
                .font(.cb(.large, .bold))
                .foregroundStyle(CBColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 120)
            HStack {
                if let leadingTitle, let leadingAction {
                    CBSheetButton(title: leadingTitle, action: leadingAction)
                }
                Spacer()
                if let trailingTitle, let trailingAction {
                    CBSheetButton(title: trailingTitle, bold: true, disabled: trailingDisabled, action: trailingAction)
                }
            }
        }
        .padding(.horizontal, CBSpace.l)
        .padding(.top, CBSpace.m)
        .padding(.bottom, CBSpace.s)
    }
}

// MARK: - Buttons

/// The app's buttons. Primary = white fill, the one main action on a screen.
struct CBButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive, highlight }

    var kind: Kind = .secondary
    var fullWidth: Bool = false
    var height: CGFloat = CBSize.control

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind, fullWidth: fullWidth, height: height)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let kind: Kind
        let fullWidth: Bool
        let height: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.cb(.body, .semibold))
                .lineLimit(1)
                .foregroundStyle(foreground)
                .padding(.horizontal, CBSpace.l)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: height)
                .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(fill))
                .overlay {
                    if kind == .secondary {
                        RoundedRectangle(cornerRadius: CBRadius.control).stroke(CBColor.stroke, lineWidth: CBSize.hairline)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
        }

        private var fill: Color {
            switch kind {
            case .primary: return CBColor.primary
            case .secondary: return CBColor.surface
            case .destructive: return CBColor.danger
            case .highlight: return CBColor.highlight
            }
        }

        private var foreground: Color {
            switch kind {
            case .primary: return CBColor.onPrimary
            case .secondary: return CBColor.textPrimary
            case .destructive, .highlight: return CBColor.onHighlight
            }
        }
    }
}

extension ButtonStyle where Self == CBButtonStyle {
    static var cbPrimary: CBButtonStyle { CBButtonStyle(kind: .primary) }
    static var cbSecondary: CBButtonStyle { CBButtonStyle(kind: .secondary) }
    static var cbDestructive: CBButtonStyle { CBButtonStyle(kind: .destructive) }
    static var cbHighlight: CBButtonStyle { CBButtonStyle(kind: .highlight) }
}

// MARK: - Labels

/// Small uppercase label above a group ("NOW", "SETLIST", "CONTROLS").
struct CBSectionLabel: View {
    let text: String
    var color: Color = CBColor.textTertiary

    init(_ text: String, color: Color = CBColor.textTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.cb(.caption, .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Status capsule with a dot: connection state, badges.
struct CBPill: View {
    let text: String
    var color: Color = CBColor.textSecondary
    var showsDot: Bool = true

    var body: some View {
        HStack(spacing: CBSpace.s) {
            if showsDot { CBStatusDot(color: color) }
            Text(text)
                .font(.cb(.small, .semibold))
                .foregroundStyle(CBColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, CBSpace.m)
        .frame(height: 36)
        .background(Capsule().fill(color.opacity(0.18)))
        .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: CBSize.hairline))
    }
}

/// Tiny tag inside a row or tile ("USB", "this song").
struct CBTag: View {
    let text: String
    var color: Color = CBColor.highlight

    var body: some View {
        Text(text)
            .font(.cb(.micro, .bold))
            .foregroundStyle(CBColor.onHighlight)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }
}

struct CBStatusDot: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

// MARK: - Text field

/// Text field on a card or sheet.
struct CBTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.cb(.body))
            .foregroundStyle(CBColor.textPrimary)
            .padding(.horizontal, CBSpace.m)
            .frame(minHeight: CBSize.control)
            .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: CBRadius.control).stroke(CBColor.stroke, lineWidth: CBSize.hairline))
    }
}
