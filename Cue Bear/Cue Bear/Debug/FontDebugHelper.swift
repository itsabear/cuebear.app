import SwiftUI
import UIKit

/// Debug helper to list all available fonts in the app
struct FontDebugHelper {
    static func printAllFonts() {
        print("=== ALL AVAILABLE FONTS ===")
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
        print("=== END OF FONTS ===")
    }

    static func checkCustomFonts() {
        print("=== CHECKING CUSTOM FONTS ===")

        // Check bundle resources
        print("\n--- Bundle Font Files ---")
        if let fontURLs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
            print("Found \(fontURLs.count) TTF files in bundle:")
            for url in fontURLs {
                print("  📦 \(url.lastPathComponent)")
            }
        } else {
            print("⚠️ No TTF files found in bundle root")
        }

        // Check fonts in subdirectory
        if let fontURLsInSubdir = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") {
            print(" Found \(fontURLsInSubdir.count) TTF files in Fonts subdirectory:")
            for url in fontURLsInSubdir {
                print("  📦 \(url.lastPathComponent)")
            }
        }

        print("\n--- Font Registration Check ---")
        let fontNames = [
            "Montserrat-Bold",
            "BebasNeue-Regular",
            "Oswald-Regular",
            "Exo2-ExtraBold",
            "PlayfairDisplay-Regular",
            "Bitter-Regular",
            "FredokaOne-Regular",
            "NunitoSans-Black",
            "CormorantGaramond-Italic",
            "SpaceGrotesk-Medium"
        ]

        for fontName in fontNames {
            if let font = UIFont(name: fontName, size: 12) {
                print("✅ \(fontName) - LOADED (family: \(font.familyName))")
            } else {
                print("❌ \(fontName) - NOT FOUND")
            }
        }
        print("\n=== END OF CUSTOM FONTS CHECK ===\n")
    }
}

/// SwiftUI view to display font debug info
struct FontDebugView: View {
    @State private var allFonts: [String] = []
    @State private var customFontsStatus: [String: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Font Debug Info")
                    .font(.title.bold())
                    .padding()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Fonts Status")
                        .font(.headline)

                    ForEach(Array(customFontsStatus.keys.sorted()), id: \.self) { fontName in
                        HStack {
                            Image(systemName: customFontsStatus[fontName] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(customFontsStatus[fontName] == true ? .green : .red)
                            Text(fontName)
                                .font(.system(size: 14, design: .monospaced))
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Button("Print All Fonts to Console") {
                    FontDebugHelper.printAllFonts()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .padding()
        }
        .onAppear {
            checkFonts()
        }
    }

    private func checkFonts() {
        let fontNames = [
            "Montserrat-Bold",
            "BebasNeue-Regular",
            "Oswald-Regular",
            "Exo2-ExtraBold",
            "PlayfairDisplay-Regular",
            "Bitter-Regular",
            "FredokaOne-Regular",
            "NunitoSans-Black",
            "CormorantGaramond-Italic",
            "SpaceGrotesk-Medium"
        ]

        for fontName in fontNames {
            customFontsStatus[fontName] = UIFont(name: fontName, size: 12) != nil
        }

        // Also print to console
        FontDebugHelper.checkCustomFonts()
    }
}
