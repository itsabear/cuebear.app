//
//  ButtonStyleExplorer.swift
//  Cue Bear
//
//  Interactive preview for exploring alternative top-bar button designs.
//  This file is in Preview Content and will NOT be included in the app bundle.
//

import SwiftUI

// MARK: - Button Style Enum

private enum TopBarStyle: String, CaseIterable, Identifiable {
    case solidChips = "Solid Tinted Chips"
    case darkGlass = "Dark Glass Tags"
    case outlinedBadges = "Outlined Badges"
    case studioButtons = "Studio Buttons"
    case neonGlow = "Neon Glow"
    case gafferTape = "Gaffer Tape"
    case brutalBlock = "Brutal Block"
    case terminalConsole = "Terminal"
    case holoPrism = "Holo Prism"
    case cornerBracket = "Corner Bracket"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .solidChips: return "Solid accent fill, 8pt corners, no material"
        case .darkGlass: return "Dark semi-transparent, thin accent border, console feel"
        case .outlinedBadges: return "No fill, accent border only, minimal"
        case .studioButtons: return "Beveled gradient, squared corners, hardware feel"
        case .neonGlow: return "Stage-lighting glow edges, like LED strips on a rig"
        case .gafferTape: return "Rough torn-tape labels, like stage floor marks"
        case .brutalBlock: return "Bold, raw, thick borders, unapologetically loud"
        case .terminalConsole: return "Monospace green-on-black, retro terminal aesthetic"
        case .holoPrism: return "Shifting rainbow gradient border, holographic sticker vibe"
        case .cornerBracket: return "Technical blueprint marks, only corners drawn"
        }
    }
}

// MARK: - 1. Solid Tinted Chips

private struct SolidChipButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica-Bold", size: 13))
                }
            }
            .foregroundColor(accentColor.needsDarkText() ? .black : .white)
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor)
                    .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isPressed ? 0.2 : 0))
            )
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct SolidChipTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 8) {
            SolidChipButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            SolidChipButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            SolidChipButton(icon: "antenna.radiowaves.left.and.right", label: "USB", accentColor: accentColor, isPressed: pressedButton == "conn") {
                tapFeedback("conn")
            }
            SolidChipButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - 2. Dark Glass Tags

private struct DarkGlassButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica", size: 13))
                }
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(isPressed ? 0.7 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(isPressed ? 0.4 : 0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct DarkGlassTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 8) {
            DarkGlassButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            DarkGlassButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            // Connection with green dot
            Button(action: { tapFeedback("conn") }) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("USB")
                        .font(.custom("Helvetica", size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(pressedButton == "conn" ? 0.7 : 0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(pressedButton == "conn" ? 0.4 : 0.2), lineWidth: 1)
                )
                .scaleEffect(pressedButton == "conn" ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressedButton)
            }
            .buttonStyle(.plain)

            DarkGlassButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - 3. Outlined Badges

private struct OutlinedBadgeButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica", size: 13))
                }
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accentColor, lineWidth: 1.5)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct OutlinedBadgeTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 8) {
            OutlinedBadgeButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            OutlinedBadgeButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            // Connection with status dot
            Button(action: { tapFeedback("conn") }) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("USB")
                        .font(.custom("Helvetica", size: 13))
                        .foregroundColor(Color.green)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pressedButton == "conn" ? Color.green.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green, lineWidth: 1.5)
                )
                .scaleEffect(pressedButton == "conn" ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressedButton)
            }
            .buttonStyle(.plain)

            OutlinedBadgeButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - 4. Studio Buttons

private struct StudioButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    private var topColor: Color {
        Color.white.opacity(0.12)
    }
    private var bottomColor: Color {
        Color.black.opacity(0.15)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica-Bold", size: 13))
                }
            }
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                ZStack {
                    // Base fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(isPressed ? 0.6 : 0.8),
                                    accentColor.opacity(isPressed ? 0.4 : 0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    // Top highlight bevel
                    if !isPressed {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [topColor, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    // Bottom edge shadow
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 6)
                            .fill(bottomColor)
                            .frame(height: isPressed ? 0 : 2)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: Color.black.opacity(isPressed ? 0.1 : 0.3), radius: isPressed ? 1 : 3, x: 0, y: isPressed ? 1 : 2)
            .offset(y: isPressed ? 1 : 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct StudioTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 8) {
            StudioButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            StudioButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            // Connection — green accent for connected
            StudioButton(icon: "antenna.radiowaves.left.and.right", label: "USB", accentColor: Color(red: 0.2, green: 0.55, blue: 0.3), isPressed: pressedButton == "conn") {
                tapFeedback("conn")
            }
            StudioButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - 5. Neon Glow

private struct NeonGlowButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica-Bold", size: 13))
                }
            }
            .foregroundColor(isPressed ? .white : accentColor)
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? accentColor.opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor, lineWidth: isPressed ? 2.5 : 1.5)
                    .shadow(color: accentColor.opacity(isPressed ? 0.9 : 0.6), radius: isPressed ? 10 : 5, x: 0, y: 0)
            )
            .shadow(color: accentColor.opacity(isPressed ? 0.5 : 0.25), radius: isPressed ? 12 : 6, x: 0, y: 0)
            .scaleEffect(isPressed ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct NeonGlowTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 10) {
            NeonGlowButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            NeonGlowButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            NeonGlowButton(icon: "antenna.radiowaves.left.and.right", label: "USB", accentColor: .green, isPressed: pressedButton == "conn") {
                tapFeedback("conn")
            }
            NeonGlowButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { pressedButton = nil }
    }
}

// MARK: - 6. Gaffer Tape

private struct GafferTapeButton: View {
    let icon: String
    let label: String?
    let isPressed: Bool
    var action: () -> Void

    // Slight random rotation per button for organic feel
    let tilt: Double

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                if let label = label {
                    Text(label.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(1)
                }
            }
            .foregroundColor(.black)
            .padding(.horizontal, label != nil ? 14 : 8)
            .frame(minWidth: 38, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.85, green: 0.83, blue: 0.78)) // off-white gaffer tape
                    .overlay(
                        // Subtle texture lines
                        VStack(spacing: 3) {
                            ForEach(0..<6, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.black.opacity(0.04))
                                    .frame(height: 0.5)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .rotationEffect(.degrees(isPressed ? 0 : tilt))
            .shadow(color: Color.black.opacity(0.4), radius: isPressed ? 0 : 2, x: 1, y: 2)
            .offset(y: isPressed ? 1 : 0)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct GafferTapeTopBar: View {
    let title: String
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 10) {
            GafferTapeButton(icon: "line.3.horizontal", label: nil, isPressed: pressedButton == "menu", action: { tapFeedback("menu") }, tilt: -1.2)
            GafferTapeButton(icon: "chevron.down", label: title, isPressed: pressedButton == "list", action: { tapFeedback("list") }, tilt: 0.8)

            Spacer()

            GafferTapeButton(icon: "antenna.radiowaves.left.and.right", label: "USB", isPressed: pressedButton == "conn", action: { tapFeedback("conn") }, tilt: -0.5)
            GafferTapeButton(icon: "pencil", label: nil, isPressed: pressedButton == "edit", action: { tapFeedback("edit") }, tilt: 1.5)
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - 7. Brutal Block

private struct BrutalBlockButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                if let label = label {
                    Text(label.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .tracking(0.5)
                }
            }
            .foregroundColor(isPressed ? accentColor : .white)
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 42, minHeight: 42)
            .background(
                Rectangle()
                    .fill(isPressed ? Color.white : Color.black)
            )
            .overlay(
                Rectangle()
                    .stroke(isPressed ? accentColor : Color.white, lineWidth: 3)
            )
            // Hard offset shadow — no blur, purely geometric
            .background(
                Rectangle()
                    .fill(accentColor)
                    .offset(x: isPressed ? 0 : 3, y: isPressed ? 0 : 3)
            )
            .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)
            .animation(.spring(response: 0.1, dampingFraction: 0.5), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct BrutalBlockTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 10) {
            BrutalBlockButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            BrutalBlockButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            BrutalBlockButton(icon: "antenna.radiowaves.left.and.right", label: "USB", accentColor: .green, isPressed: pressedButton == "conn") {
                tapFeedback("conn")
            }
            BrutalBlockButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressedButton = nil }
    }
}

// MARK: - 8. Terminal Console

private struct TerminalButton: View {
    let icon: String
    let label: String?
    let isPressed: Bool
    var action: () -> Void

    private let termGreen = Color(red: 0.2, green: 1.0, blue: 0.4)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                if let label = label {
                    Text("[\(label)]")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
            .foregroundColor(isPressed ? .black : termGreen)
            .padding(.horizontal, label != nil ? 10 : 4)
            .frame(minWidth: 38, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPressed ? termGreen : Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(termGreen.opacity(0.5), lineWidth: 1)
            )
            // CRT scanline overlay
            .overlay(
                VStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(isPressed ? 0.05 : 0.1))
                            .frame(height: 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            )
            .shadow(color: termGreen.opacity(isPressed ? 0.4 : 0.15), radius: isPressed ? 6 : 2, x: 0, y: 0)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct TerminalTopBar: View {
    let title: String
    @Binding var pressedButton: String?

    private let termGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    private let termAmber = Color(red: 1.0, green: 0.75, blue: 0.2)

    var body: some View {
        HStack(spacing: 6) {
            // Blinking cursor
            Text("_")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(termGreen)
                .opacity(0.6)

            TerminalButton(icon: "line.3.horizontal", label: nil, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            TerminalButton(icon: "chevron.down", label: title, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            // Connection — amber for status
            Button(action: { tapFeedback("conn") }) {
                HStack(spacing: 4) {
                    Circle().fill(termGreen).frame(width: 6, height: 6)
                    Text("USB")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(pressedButton == "conn" ? .black : termAmber)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(pressedButton == "conn" ? termAmber : Color.black)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(termAmber.opacity(0.5), lineWidth: 1)
                )
                .scaleEffect(pressedButton == "conn" ? 0.95 : 1.0)
                .animation(.easeOut(duration: 0.1), value: pressedButton)
            }
            .buttonStyle(.plain)

            TerminalButton(icon: "pencil", label: nil, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressedButton = nil }
    }
}

// MARK: - 9. Holo Prism

private struct HoloPrismButton: View {
    let icon: String
    let label: String?
    let isPressed: Bool
    var action: () -> Void

    @State private var animationPhase: CGFloat = 0

    private var gradientColors: [Color] {
        [
            Color(red: 1.0, green: 0.4, blue: 0.4),  // pink-red
            Color(red: 1.0, green: 0.8, blue: 0.3),  // gold
            Color(red: 0.3, green: 1.0, blue: 0.5),  // green
            Color(red: 0.3, green: 0.7, blue: 1.0),  // cyan
            Color(red: 0.7, green: 0.4, blue: 1.0),  // purple
            Color(red: 1.0, green: 0.4, blue: 0.4),  // loop back
        ]
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica-Bold", size: 13))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, label != nil ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            startAngle: .degrees(animationPhase),
                            endAngle: .degrees(animationPhase + 360)
                        ),
                        lineWidth: isPressed ? 2.5 : 1.5
                    )
                    .shadow(color: Color.purple.opacity(0.3), radius: isPressed ? 8 : 3, x: 0, y: 0)
            )
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .brightness(isPressed ? 0.15 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                animationPhase = 360
            }
        }
    }
}

private struct HoloPrismTopBar: View {
    let title: String
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 8) {
            HoloPrismButton(icon: "line.3.horizontal", label: nil, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            HoloPrismButton(icon: "chevron.down", label: title, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            HoloPrismButton(icon: "antenna.radiowaves.left.and.right", label: "USB", isPressed: pressedButton == "conn") {
                tapFeedback("conn")
            }
            HoloPrismButton(icon: "pencil", label: nil, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - 10. Corner Bracket

private struct CornerBracketButton: View {
    let icon: String
    let label: String?
    let accentColor: Color
    let isPressed: Bool
    var action: () -> Void

    private let bracketLength: CGFloat = 8
    private let bracketWeight: CGFloat = 2

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                if let label = label {
                    Text(label)
                        .font(.custom("Helvetica", size: 13))
                }
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, label != nil ? 16 : 4)
            .frame(minWidth: 40, minHeight: 40)
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let c = isPressed ? accentColor : Color.white.opacity(0.6)
                    let len = bracketLength
                    let wt = bracketWeight

                    // Top-left corner
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: len))
                        p.addLine(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: len, y: 0))
                    }.stroke(c, lineWidth: wt)

                    // Top-right corner
                    Path { p in
                        p.move(to: CGPoint(x: w - len, y: 0))
                        p.addLine(to: CGPoint(x: w, y: 0))
                        p.addLine(to: CGPoint(x: w, y: len))
                    }.stroke(c, lineWidth: wt)

                    // Bottom-left corner
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h - len))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.addLine(to: CGPoint(x: len, y: h))
                    }.stroke(c, lineWidth: wt)

                    // Bottom-right corner
                    Path { p in
                        p.move(to: CGPoint(x: w - len, y: h))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: w, y: h - len))
                    }.stroke(c, lineWidth: wt)
                }
            )
            .background(
                Rectangle()
                    .fill(isPressed ? accentColor.opacity(0.15) : Color.clear)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct CornerBracketTopBar: View {
    let title: String
    let accentColor: Color
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 10) {
            CornerBracketButton(icon: "line.3.horizontal", label: nil, accentColor: accentColor, isPressed: pressedButton == "menu") {
                tapFeedback("menu")
            }
            CornerBracketButton(icon: "chevron.down", label: title, accentColor: accentColor, isPressed: pressedButton == "list") {
                tapFeedback("list")
            }

            Spacer()

            CornerBracketButton(icon: "antenna.radiowaves.left.and.right", label: "USB", accentColor: .green, isPressed: pressedButton == "conn") {
                tapFeedback("conn")
            }
            CornerBracketButton(icon: "pencil", label: nil, accentColor: accentColor, isPressed: pressedButton == "edit") {
                tapFeedback("edit")
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - Current Apple-style (Baseline)

private struct CurrentAppleTopBar: View {
    let title: String
    @Binding var pressedButton: String?

    var body: some View {
        HStack(spacing: 0) {
            // Left capsule group
            HStack(spacing: 0) {
                Button(action: { tapFeedback("menu") }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.leading, 4)
                    .padding(.trailing, 14)
            }
            .background(Capsule().fill(.regularMaterial))
            .clipShape(Capsule())

            Spacer()

            // Right capsule group
            HStack(spacing: 8) {
                Button(action: { tapFeedback("conn") }) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("USB")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                }
                .background(Capsule().fill(.regularMaterial))
                .clipShape(Capsule())

                Button(action: { tapFeedback("edit") }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .background(Capsule().fill(.regularMaterial))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
    }

    private func tapFeedback(_ id: String) {
        pressedButton = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressedButton = nil }
    }
}

// MARK: - Individual Style Preview (Full Screen with Cues)

private struct StyleFullPreview: View {
    let style: TopBarStyle
    let accentColor: Color

    @State private var pressedButton: String? = nil
    @State private var selectedCue: Int? = nil

    private let cues: [(name: String, subtitle: String?, hex: String)] = [
        ("Intro", "120 BPM - Key of C", "#D8BA98"),
        ("Verse 1", nil, "#7F0303"),
        ("Chorus", "Big energy", "#EFE8DF"),
        ("Bridge", nil, "#96C0CE"),
        ("Outro", "Fade out", "#0F414A"),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#1C1C1E").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    Color.clear.frame(height: 60)
                    ForEach(Array(cues.enumerated()), id: \.offset) { index, cue in
                        cueRow(index: index, name: cue.name, subtitle: cue.subtitle, hex: cue.hex)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                                    selectedCue = selectedCue == index ? nil : index
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Top gradient
            VStack {
                LinearGradient(
                    colors: [Color(hex: "#1C1C1E"), Color(hex: "#1C1C1E").opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .ignoresSafeArea()
                Spacer()
            }
            .allowsHitTesting(false)

            // Top bar
            VStack {
                topBar
                    .padding(.top, 8)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        switch style {
        case .solidChips:
            SolidChipTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        case .darkGlass:
            DarkGlassTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        case .outlinedBadges:
            OutlinedBadgeTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        case .studioButtons:
            StudioTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        case .neonGlow:
            NeonGlowTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        case .gafferTape:
            GafferTapeTopBar(title: "Sunday Set", pressedButton: $pressedButton)
        case .brutalBlock:
            BrutalBlockTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        case .terminalConsole:
            TerminalTopBar(title: "Sunday Set", pressedButton: $pressedButton)
        case .holoPrism:
            HoloPrismTopBar(title: "Sunday Set", pressedButton: $pressedButton)
        case .cornerBracket:
            CornerBracketTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: $pressedButton)
        }
    }

    private func cueRow(index: Int, name: String, subtitle: String?, hex: String) -> some View {
        let isCued = selectedCue == index
        let textColor: Color = Color(hex: hex).needsDarkText() ? .black : .white

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: hex))
                .opacity(isCued ? 1.0 : 0.90)

            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    if let sub = subtitle {
                        Text(sub)
                            .font(.custom("Helvetica", size: 14))
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    Spacer()
                    Text(name)
                        .font(.custom("Helvetica-Bold", size: 28))
                        .foregroundColor(textColor)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(height: 110)
        .overlay(
            Group {
                if isCued {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 5)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 3)
                }
            }
        )
    }
}

// MARK: - Comparison Strip (All styles stacked)

private struct AllStylesComparison: View {
    let accentColor: Color
    @State private var pressedButtons: [TopBarStyle: String?] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Current (baseline)
                styleSection(label: "CURRENT (Apple Material Capsules)") {
                    CurrentAppleTopBar(
                        title: "Sunday Set",
                        pressedButton: binding(for: .solidChips, fallback: "current")
                    )
                }

                ForEach(TopBarStyle.allCases) { style in
                    styleSection(label: style.rawValue.uppercased(), description: style.description) {
                        switch style {
                        case .solidChips:
                            SolidChipTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        case .darkGlass:
                            DarkGlassTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        case .outlinedBadges:
                            OutlinedBadgeTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        case .studioButtons:
                            StudioTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        case .neonGlow:
                            NeonGlowTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        case .gafferTape:
                            GafferTapeTopBar(title: "Sunday Set", pressedButton: binding(for: style))
                        case .brutalBlock:
                            BrutalBlockTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        case .terminalConsole:
                            TerminalTopBar(title: "Sunday Set", pressedButton: binding(for: style))
                        case .holoPrism:
                            HoloPrismTopBar(title: "Sunday Set", pressedButton: binding(for: style))
                        case .cornerBracket:
                            CornerBracketTopBar(title: "Sunday Set", accentColor: accentColor, pressedButton: binding(for: style))
                        }
                    }
                }
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .preferredColorScheme(.dark)
    }

    private func styleSection<Content: View>(label: String, description: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.custom("Helvetica-Bold", size: 11))
                    .foregroundColor(.gray)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let desc = description {
                    Text(desc)
                        .font(.custom("Helvetica", size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            content()
                .padding(.vertical, 12)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func binding(for style: TopBarStyle, fallback: String = "") -> Binding<String?> {
        Binding(
            get: { pressedButtons[style] ?? nil },
            set: { pressedButtons[style] = $0 }
        )
    }
}

// MARK: - Interactive Color Picker Comparison

private struct InteractiveStyleExplorer: View {
    @State private var selectedStyle: TopBarStyle = .studioButtons
    @State private var accentHue: Double = 0.58 // Blue default
    @State private var pressedButton: String? = nil

    private var accentColor: Color {
        Color(hue: accentHue, saturation: 0.7, brightness: 0.85)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Style picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TopBarStyle.allCases) { style in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedStyle = style
                            }
                        }) {
                            Text(style.rawValue)
                                .font(.custom("Helvetica-Bold", size: 12))
                                .foregroundColor(selectedStyle == style ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedStyle == style ? Color.white : Color.white.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.black.opacity(0.3))

            // Hue slider
            HStack(spacing: 12) {
                Text("ACCENT")
                    .font(.custom("Helvetica-Bold", size: 10))
                    .foregroundColor(.gray)
                    .tracking(1)
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 20, height: 20)
                Slider(value: $accentHue, in: 0...1)
                    .tint(accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))

            // Full preview
            StyleFullPreview(style: selectedStyle, accentColor: accentColor)
        }
        .background(Color(hex: "#1C1C1E"))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview("All Styles - Side by Side") {
    AllStylesComparison(accentColor: Color(hex: "#0A84FF"))
}

#Preview("Interactive Explorer") {
    InteractiveStyleExplorer()
}

#Preview("Studio Buttons - Full App") {
    StyleFullPreview(style: .studioButtons, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Dark Glass - Full App") {
    StyleFullPreview(style: .darkGlass, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Solid Chips - Full App") {
    StyleFullPreview(style: .solidChips, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Outlined Badges - Full App") {
    StyleFullPreview(style: .outlinedBadges, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Neon Glow - Full App") {
    StyleFullPreview(style: .neonGlow, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Gaffer Tape - Full App") {
    StyleFullPreview(style: .gafferTape, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Brutal Block - Full App") {
    StyleFullPreview(style: .brutalBlock, accentColor: Color(hex: "#FF1744"))
        .preferredColorScheme(.dark)
}

#Preview("Terminal - Full App") {
    StyleFullPreview(style: .terminalConsole, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Holo Prism - Full App") {
    StyleFullPreview(style: .holoPrism, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}

#Preview("Corner Bracket - Full App") {
    StyleFullPreview(style: .cornerBracket, accentColor: Color(hex: "#0A84FF"))
        .preferredColorScheme(.dark)
}
