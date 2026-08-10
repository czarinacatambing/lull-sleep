import SwiftUI
import UIKit

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
    // Dark warm brown — used as text colour on amber buttons/fills.
    static let lullBgDeep    = Color(hex: "#1a0d06")

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
// Serif display follows the mockup fallback order, using bold weights throughout.

extension Font {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let candidates = italic
            ? ["IowanOldStyle-BoldItalic", "Palatino-BoldItalic", "Georgia-BoldItalic"]
            : ["IowanOldStyle-Bold", "Palatino-Bold", "Georgia-Bold"]
        let name = candidates.first { UIFont(name: $0, size: 12) != nil } ?? (italic ? "Georgia-BoldItalic" : "Georgia-Bold")
        let font = Font.custom(name, size: size)
        return italic ? font.italic() : font
    }
    static func serifItalic(_ size: CGFloat) -> Font {
        .serif(size, italic: true)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

// MARK: - Spacing

enum Lull {
    static let horizontalPad: CGFloat = 24
    static let cardRadius: CGFloat = 22
    static let buttonHeight: CGFloat = 56
    static let buttonRadius: CGFloat = 999
}

// MARK: - Time formatting

extension Int {
    /// Formats seconds as "m:ss" for use in timer displays throughout the app.
    var lullTimeString: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}

extension TimeInterval {
    var lullTimeString: String { Int(self).lullTimeString }
}
