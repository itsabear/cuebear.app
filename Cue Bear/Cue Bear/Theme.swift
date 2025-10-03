import SwiftUI

enum ThemeScheme: String {
    case orange
    case blue
}

final class ThemeStore: ObservableObject {
    @Published var scheme: ThemeScheme {
        didSet { persistScheme() }
    }

    // Primary brand/accent color used across the app
    @Published var accent: Color

    // Derived variants
    @Published var accentStroke: Color
    @Published var accentFillWeak: Color

    private let defaultsKey = "cb.theme.scheme"

    init() {
        let storedRaw = UserDefaults.standard.string(forKey: defaultsKey)
        let initialScheme = ThemeScheme(rawValue: storedRaw ?? "") ?? .blue
        let colors = ThemeStore.colors(for: initialScheme)

        // Initialize all stored properties before any self access
        self.scheme = initialScheme
        self.accent = colors.accent
        self.accentStroke = colors.accentStroke
        self.accentFillWeak = colors.accentFillWeak
    }

    func apply(_ scheme: ThemeScheme) {
        guard self.scheme != scheme else { return }
        self.scheme = scheme
        let colors = ThemeStore.colors(for: scheme)
        self.accent = colors.accent
        self.accentStroke = colors.accentStroke
        self.accentFillWeak = colors.accentFillWeak
    }

    private func persistScheme() {
        UserDefaults.standard.set(scheme.rawValue, forKey: defaultsKey)
    }

    private static func colors(for scheme: ThemeScheme) -> (accent: Color, accentStroke: Color, accentFillWeak: Color) {
        switch scheme {
        case .orange:
            let base = Color.orange
            return (base, base, base.opacity(0.2))
        case .blue:
            let base = Color.blue
            return (base, base, base.opacity(0.2))
        }
    }
}


