//
//  FontFinalistPreview.swift
//  Cue Bear
//
//  Narrowed-down font comparison: DIN Monospaced, Plus Jakarta Sans, Sora.
//  Uses the app's dark glass design language.
//

import SwiftUI

// MARK: - Self-contained color helper (avoids compiling full app)

private extension Color {
    init(h: String) {
        let hex = h.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    var isDark: Bool {
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: nil)
        return (r * 299 + g * 587 + b * 114) / 1000 < 0.5
    }
}

// MARK: - Font Definition

private struct F: Identifiable {
    let id = UUID()
    let name: String
    let regular: String
    let bold: String
    let note: String

    func r(_ s: CGFloat) -> Font { .custom(regular, size: s) }
    func b(_ s: CGFloat) -> Font { .custom(bold, size: s) }
}

private let fonts: [F] = [
    F(name: "DIN Alternate", regular: "DINAlternate-Bold", bold: "DINAlternate-Bold",
      note: "German industrial standard. Technical, clean, great for numbers."),
    F(name: "Plus Jakarta Sans", regular: "PlusJakartaSans-Regular", bold: "PlusJakartaSans-Bold",
      note: "Warm geometric, trending in creative apps."),
    F(name: "Sora", regular: "Sora-Regular", bold: "Sora-Bold",
      note: "Japanese-inspired geometric. Clean with subtle personality."),
]

// MARK: - Cue Row

private struct CueRow: View {
    let f: F; let name: String; let sub: String?; let hex: String; let cued: Bool; let midi: String?

    var body: some View {
        let bg = Color(h: hex)
        let fg: Color = bg.isDark ? .white : .black
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(bg.opacity(cued ? 1 : 0.9))
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    if let s = sub {
                        Text(s).font(f.r(14)).foregroundColor(fg.opacity(0.6)).lineLimit(1)
                    }
                    Spacer()
                    Text(name).font(f.b(28)).foregroundColor(fg).lineLimit(1)
                }
                .padding(.leading, 20).padding(.vertical, 16)
                Spacer()
                if let m = midi {
                    Text(m).font(f.r(13)).foregroundColor(fg.opacity(0.5)).padding(.trailing, 16)
                }
            }
        }
        .frame(height: 110)
        .overlay(Group {
            if cued {
                RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 5)
                RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 3)
            }
        })
    }
}

// MARK: - Control Tile

private struct Tile: View {
    let f: F; let title: String; let icon: String; let midi: String; let hex: String

    var body: some View {
        let bg = Color(h: hex)
        let fg: Color = bg.isDark ? .white : .black
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(fg)
            if !title.isEmpty {
                Text(title).font(f.b(11)).foregroundColor(fg).lineLimit(1).minimumScaleFactor(0.7)
            }
            Text(midi).font(f.r(9)).foregroundColor(fg.opacity(0.5))
            Spacer(minLength: 0)
        }
        .frame(width: 66, height: 66)
        .background(RoundedRectangle(cornerRadius: 8).fill(bg))
    }
}

// MARK: - Card sub-views (broken up for Swift type-checker)

private struct CardSpecimen: View {
    let f: F
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ").font(f.r(13))
            Text("abcdefghijklmnopqrstuvwxyz 0123456789").font(f.r(13))
            Text("The quick brown bear cues a lazy fox").font(f.b(16))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
}

private struct CardTopBar: View {
    let f: F
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                Text("Sunday Service")
                    .font(f.b(16))
                    .foregroundColor(.white)
                    .padding(.trailing, 14)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("USB").font(f.r(13)).foregroundColor(.white.opacity(0.8))
            }
            .frame(height: 44)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 8)
    }
}

private struct CardCueList: View {
    let f: F
    var body: some View {
        VStack(spacing: 4) {
            CueRow(f: f, name: "Intro", sub: "120 BPM - Key of C", hex: "#2979FF", cued: true, midi: "1•0")
            CueRow(f: f, name: "Verse 1", sub: nil, hex: "#7C4DFF", cued: false, midi: "1•1")
            CueRow(f: f, name: "Chorus", sub: "Big energy", hex: "#FF1744", cued: false, midi: "1•2")
            CueRow(f: f, name: "Bridge", sub: nil, hex: "#00E676", cued: false, midi: "1•3")
            CueRow(f: f, name: "Outro", sub: "Fade out", hex: "#455A64", cued: false, midi: "1•4")
        }
        .padding(.horizontal, 8)
    }
}

private struct CardControlHeader: View {
    let f: F
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 36, height: 44)
                Text("1/2").font(f.r(14)).foregroundColor(.white).frame(minWidth: 32)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 44)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            HStack(spacing: 0) {
                Text("Edit").font(f.r(15)).foregroundColor(.white)
                    .padding(.horizontal, 14).frame(height: 44)
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 24)
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 44)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct CardControlArea: View {
    let f: F
    var body: some View {
        VStack(spacing: 0) {
            CardControlHeader(f: f)
            HStack(spacing: 6) {
                Tile(f: f, title: "Verse", icon: "music.note", midi: "1•5", hex: "#7C4DFF")
                Tile(f: f, title: "FX Send", icon: "waveform", midi: "1•10", hex: "#FF6D00")
                Tile(f: f, title: "", icon: "stop.fill", midi: "1•20", hex: "#455A64")
                Tile(f: f, title: "Mute", icon: "speaker.slash.fill", midi: "1•30", hex: "#D500F9")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.8)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 8)
    }
}

private struct CardMidiTest: View {
    let f: F
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MIDI (9pt)").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                HStack(spacing: 8) {
                    Text("1•0").font(f.r(9))
                    Text("1•127").font(f.r(9))
                    Text("16•64").font(f.r(9))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Labels (11pt)").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                HStack(spacing: 8) {
                    Text("Button 1").font(f.b(11))
                    Text("Fader 3").font(f.b(11))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Card

private struct Card: View {
    let f: F

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(f.name).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text(f.note).font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
            CardSpecimen(f: f)
            CardTopBar(f: f)
            CardCueList(f: f)
            CardControlArea(f: f)
            CardMidiTest(f: f)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Preview

struct FontFinalistPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Font Finalists").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding(.top, 20)
                Text("DIN  ·  Plus Jakarta Sans  ·  Sora").font(.system(size: 14)).foregroundColor(.white.opacity(0.5))
                ForEach(fonts) { Card(f: $0).padding(.horizontal, 16) }
            }
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }
}

#Preview { FontFinalistPreview().preferredColorScheme(.dark) }
