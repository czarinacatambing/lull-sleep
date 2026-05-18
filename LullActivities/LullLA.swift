import SwiftUI

// Live Activity design tokens.
// Hex values come from Docs/live-activities-spec.md — do not eyeball or fold
// into the main LullTheme palette.
enum LullLA {
    // Card fills
    static let cardSleeping = Color(hex: 0x0C0C12, alpha: 0.92)
    static let cardWake     = Color(hex: 0x1A120C, alpha: 0.96)
    static let cardConfirm  = Color(hex: 0x1A120C, alpha: 0.96)

    // Ink
    static let ink0 = Color(hex: 0xF5E7D7)
    static let ink1 = Color(hex: 0xE5D3BF)
    static let ink2 = Color(hex: 0xB9A691)
    static let ink3 = Color(hex: 0x8A7A68)
    static let ink4 = Color(hex: 0x5C4F42)

    // Amber
    static let amber     = Color(hex: 0xF0B96B)
    static let amberSoft = Color(hex: 0xD99A4A)
    static let amberDeep = Color(hex: 0xA66A2A)
    static let amberGlow = Color(hex: 0xF0B96B, alpha: 0.45)

    // On-amber ink for filled rating numerals
    static let onAmber = Color(hex: 0x1A0D06)

    // Lines
    static let hairline = Color(white: 1.0, opacity: 0.08)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex         & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// Typography helpers — Fraunces variable italic + JetBrains Mono.
enum LullLAFont {
    static func fraunces(size: CGFloat, weight: Font.Weight = .light, italic: Bool = true) -> Font {
        // Variable font is registered at runtime; we approximate weight via SwiftUI's .weight()
        // because variable-axis access from SwiftUI is limited. Italic is the visible distinction
        // we need for the wake / score display.
        var f = Font.custom("Fraunces", size: size).weight(weight)
        if italic { f = f.italic() }
        return f
    }

    static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.custom("JetBrainsMono-Regular", size: size).weight(weight)
    }
}
