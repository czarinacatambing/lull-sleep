import SwiftUI

// MARK: - Colors

extension Color {
    static let lullBg        = Color(hex: "#0c0807")
    static let lullBg1       = Color(hex: "#120c0a")
    static let lullBg2       = Color(hex: "#1a110e")
    static let lullBg3       = Color(hex: "#231612")
    static let lullInk0      = Color(hex: "#f5e7d7")
    static let lullInk1      = Color(hex: "#e5d3bf")
    static let lullInk2      = Color(hex: "#b9a691")
    static let lullInk3      = Color(hex: "#8a7a68")
    static let lullInk4      = Color(hex: "#5c4f42")
    static let lullAmber     = Color(hex: "#f0b96b")
    static let lullAmberSoft = Color(hex: "#d99a4a")
    static let lullAmberDeep = Color(hex: "#a66a2a")
    static let lullLine      = Color(red: 1, green: 0.863, blue: 0.745).opacity(0.08)
    static let lullLineStrong = Color(red: 1, green: 0.863, blue: 0.745).opacity(0.14)
    static let lullAmberGlow = Color(hex: "#f0b96b").opacity(0.45)

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Typography
// Fonts: Fraunces (serif display), JetBrains Mono (data labels).
// Add font files to Resources/Fonts/ and register in Info.plist under UIAppFonts.
// Download from: https://fonts.google.com/specimen/Fraunces and https://fonts.google.com/specimen/JetBrains+Mono

extension Font {
    static func serif(_ size: CGFloat, weight: Font.Weight = .light, italic: Bool = false) -> Font {
        let name = italic ? "Fraunces-LightItalic" : "Fraunces-Light"
        return .custom(name, size: size)
    }
    static func serifItalic(_ size: CGFloat) -> Font {
        .custom("Fraunces-LightItalic", size: size)
    }
    static func mono(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Regular", size: size)
    }
}

// MARK: - Spacing

enum Lull {
    static let horizontalPad: CGFloat = 24
    static let cardRadius: CGFloat = 22
    static let buttonHeight: CGFloat = 56
    static let buttonRadius: CGFloat = 999
}
