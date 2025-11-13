import SwiftUI

// MARK: - Design Preview for Xcode Canvas
// This file is for testing neomorphic button designs without running the app

struct DesignPreview: View {
    @State private var selectedIndex: Int? = nil
    @State private var lastPlayedIndex: Int? = nil

    // Neomorphism colors - exact spec from reference
    let bgColor = Color(hex: "e0e5ec")  // Light gray background
    let lightShadow = Color.white  // Pure white highlight
    let darkShadow = Color(hex: "a3b1c6")  // Cool gray shadow

    var body: some View {
        ZStack {
            // Background matching neomorphism design
            bgColor.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Neomorphic Cue Button Preview")
                    .font(.title.bold())
                    .padding(.top, 40)

                Text("Tap buttons to toggle states")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Preview buttons
                VStack(spacing: 16) {
                    neomorphicButton(
                        title: "Opening Number",
                        subtitle: "Full Band",
                        color: Color(hex: "FF9500"),
                        index: 0,
                        cc: 0,
                        channel: 1
                    )

                    neomorphicButton(
                        title: "Act 1 Scene 2",
                        subtitle: "Piano & Strings",
                        color: Color(hex: "30D158"),
                        index: 1,
                        cc: 1,
                        channel: 1
                    )

                    neomorphicButton(
                        title: "Intermission",
                        subtitle: nil,
                        color: Color(hex: "0A84FF"),
                        index: 2,
                        cc: 2,
                        channel: 1
                    )

                    neomorphicButton(
                        title: "Finale",
                        subtitle: "Full Orchestra",
                        color: Color(hex: "FF453A"),
                        index: 3,
                        cc: 3,
                        channel: 1
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func neomorphicButton(
        title: String,
        subtitle: String?,
        color: Color,
        index: Int,
        cc: Int,
        channel: Int
    ) -> some View {
        let isCued = selectedIndex == index
        let corner: CGFloat = 24  // Increased from 16 for softer, more rounded appearance
        let height: CGFloat = isCued ? 103.2 : 86

        return Button(action: {
            if selectedIndex == index {
                lastPlayedIndex = index
                selectedIndex = nil
            } else {
                lastPlayedIndex = selectedIndex
                selectedIndex = index
            }
        }) {
            ZStack {
                // Neomorphic button base
                RoundedRectangle(cornerRadius: corner)
                    .fill(bgColor)
                    .frame(maxWidth: .infinity, minHeight: height)

                // RAISED STATE (not cued): outer shadows for elevated appearance
                if !isCued {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(bgColor)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .shadow(color: lightShadow, radius: 15, x: -8, y: -8)
                        .shadow(color: darkShadow, radius: 15, x: 8, y: 8)
                        // Outer bright glow on top-left corner
                        .overlay(
                            GeometryReader { geometry in
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: geometry.size.width * 0.4
                                )
                                .clipShape(RoundedRectangle(cornerRadius: corner))
                                .allowsHitTesting(false)
                            }
                        )
                        // Inner white glow edge
                        .overlay(
                            RoundedRectangle(cornerRadius: corner)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.8),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .blur(radius: 1)
                        )
                }

                // PRESSED STATE (cued): inner shadows for inset appearance
                if isCued {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(bgColor)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .overlay(
                            // Inner stroke for definition
                            RoundedRectangle(cornerRadius: corner)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            darkShadow.opacity(0.2),
                                            lightShadow.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                }

                // Content overlay - dark grey text with LED indicator
                HStack(alignment: .center, spacing: 0) {
                    // Fixed left padding
                    Spacer()
                        .frame(width: 28)  // Fixed left margin

                    // LED indicator - fixed position, realistic on/off states with proper glow
                    ZStack {
                        // Multi-layer outer glow when lit (more intense)
                        if isCued {
                            // Outermost glow layer
                            Circle()
                                .fill(color.opacity(0.4))
                                .frame(width: 24, height: 24)
                                .blur(radius: 6)

                            // Mid glow layer
                            Circle()
                                .fill(color.opacity(0.5))
                                .frame(width: 18, height: 18)
                                .blur(radius: 4)

                            // Inner glow layer
                            Circle()
                                .fill(color.opacity(0.6))
                                .frame(width: 14, height: 14)
                                .blur(radius: 2)
                        }

                        // LED body - bright when on, subtle color hint when off
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: isCued ? [
                                        color.opacity(0.95),
                                        color
                                    ] : [
                                        // Off state: subtle color hint (not dark)
                                        color.opacity(0.25),
                                        color.opacity(0.15)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 6
                                )
                            )
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(
                                        color.opacity(isCued ? 0.3 : 0.2),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(
                                color: isCued ? color.opacity(0.7) : Color.clear,
                                radius: isCued ? 8 : 0,
                                x: 0,
                                y: 0
                            )
                    }
                    .frame(width: 12)  // Fixed width for LED

                    // Fixed spacing between LED and text
                    Spacer()
                        .frame(width: 24)

                    // Text content - grows in size but stays aligned left
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: isCued ? 28 : 22, weight: .bold))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))  // Dark grey
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let sub = subtitle, !sub.isEmpty {
                            Text(sub)
                                .font(isCued ? .headline : .footnote)
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))  // Medium grey
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // MIDI info - fixed position on right
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("CC \(cc)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text("Ch \(channel)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 60)  // Fixed width for MIDI info

                    // Fixed right padding
                    Spacer()
                        .frame(width: 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)  // Fixed height per state
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(nil, value: isCued)  // No animation - instant state change
    }
}

// MARK: - Xcode Canvas Previews
#Preview("Default State") {
    DesignPreview()
}

#Preview("Dark Mode") {
    DesignPreview()
        .preferredColorScheme(.dark)
}
