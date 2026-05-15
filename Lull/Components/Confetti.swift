import SwiftUI

// Shared explosive-pop confetti. Two variants:
//   .mini — small contained burst inside a card (22 pieces, ±55° fan, 60–110pt peak)
//   .big  — full-screen blast that falls past the viewport (90 pieces, ±70° fan, 240–460pt peak)
//
// Both originate at the bottom-center of their parent container and pop UPWARD with a
// fan-shaped spread. The brand feel is "lifting" sleep — never fall-from-top.
// Honors prefers-reduced-motion with a static amber bloom + slow opacity pulse.
struct Confetti: View {
    enum Variant {
        case mini, big

        var pieces: Int           { self == .mini ? 22 : 90 }
        var fanDegrees: Double    { self == .mini ? 55 : 70 }
        var peakMin: Double       { self == .mini ? 60 : 240 }
        var peakMax: Double       { self == .mini ? 110 : 460 }
        var durationMin: Double   { self == .mini ? 1.4 : 3.2 }
        var durationMax: Double   { self == .mini ? 2.0 : 5.2 }
        var sizeMin: CGFloat      { self == .mini ? 4 : 6 }
        var sizeMax: CGFloat      { self == .mini ? 8 : 14 }
        var driftRange: Double    { self == .mini ? 30 : 200 }
        var delayMax: Double      { self == .mini ? 0.25 : 0.6 }
        var glowRadius: CGFloat   { self == .mini ? 3 : 6 }
        var startScale: Double    { self == .mini ? 0.3 : 0.4 }
        var endScale: Double      { self == .mini ? 0.9 : 1.0 }
        var peakProgress: Double  { self == .mini ? 0.45 : 0.35 }
        var fadeInEnd: Double     { self == .mini ? 0.15 : 0.06 }
    }

    let variant: Variant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if reduceMotion {
                ReducedMotionBloom(variant: variant)
            } else {
                GeometryReader { geo in
                    ConfettiCanvas(variant: variant, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .modifier(ClipIfMini(variant: variant))
    }
}

// MARK: - Piece

private struct ConfettiPiece: Identifiable {
    enum PieceShape { case rect, circle, streak }

    let id = UUID()
    let vx: CGFloat       // horizontal peak displacement
    let vy: CGFloat       // vertical peak displacement (negative = up)
    let drift: CGFloat    // horizontal post-peak drift
    let delay: Double
    let duration: Double
    let size: CGFloat
    let rotationEnd: Double
    let color: Color
    let shape: PieceShape
}

// MARK: - Palette (mixed amber/coral/mint/lavender/sky/cream)

private enum ConfettiPalette {
    static let colors: [Color] = [
        Color(hex: "#f0b96b"),  // amber
        Color(hex: "#f25c54"),  // coral
        Color(hex: "#9bd1c4"),  // mint
        Color(hex: "#a89cc8"),  // lavender
        Color(hex: "#f7d488"),  // soft amber
        Color(hex: "#5bc0eb"),  // sky
        Color(hex: "#ee9c81"),  // peach
        Color(hex: "#f6f4ef"),  // cream
    ]
}

// Seeded pseudo-random — matches the JSX reference so visuals stay consistent.
private func seededRandom(_ i: Int, _ seed: Int) -> Double {
    let raw = sin(Double(i) * 9301.0 + Double(seed) * 49297.0) * 233280.0
    return raw - floor(raw)
}

private func makePieces(variant: Confetti.Variant) -> [ConfettiPiece] {
    (0..<variant.pieces).map { i in
        let angleDeg = (seededRandom(i, 1) - 0.5) * 2 * variant.fanDegrees
        // -90deg = straight up in screen coordinates
        let angleRad = (angleDeg - 90) * .pi / 180
        let peak = variant.peakMin + seededRandom(i, 2) * (variant.peakMax - variant.peakMin)

        let vx = CGFloat(cos(angleRad) * peak)
        let vy = CGFloat(sin(angleRad) * peak)
        let drift = CGFloat((seededRandom(i, 6) - 0.5) * variant.driftRange)

        let delay = seededRandom(i, 3) * variant.delayMax
        let duration = variant.durationMin + seededRandom(i, 4) * (variant.durationMax - variant.durationMin)
        let size = variant.sizeMin + CGFloat(seededRandom(i, 5)) * (variant.sizeMax - variant.sizeMin)
        let rotationEnd = 360 + seededRandom(i, 8) * 720

        let palette = ConfettiPalette.colors
        let colorIdx = min(palette.count - 1, Int(seededRandom(i, 9) * Double(palette.count)))
        let color = palette[colorIdx]

        let shapeRoll = seededRandom(i, 10)
        let shape: ConfettiPiece.PieceShape =
            shapeRoll > 0.6 ? .rect : (shapeRoll > 0.3 ? .circle : .streak)

        return ConfettiPiece(
            vx: vx, vy: vy, drift: drift,
            delay: delay, duration: duration, size: size,
            rotationEnd: rotationEnd, color: color, shape: shape
        )
    }
}

// MARK: - Canvas

private struct ConfettiCanvas: View {
    let variant: Confetti.Variant
    let size: CGSize

    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                ConfettiPieceView(piece: piece, variant: variant, containerSize: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if pieces.isEmpty { pieces = makePieces(variant: variant) }
        }
    }
}

// MARK: - Piece view

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let variant: Confetti.Variant
    let containerSize: CGSize

    @State private var progress: Double = 0

    var body: some View {
        let pos = position(at: progress)
        let opa = opacityValue(at: progress)
        let rot = piece.rotationEnd * progress
        let scl = scaleValue(at: progress)

        shape
            .foregroundColor(piece.color)
            .shadow(color: piece.color.opacity(0.4), radius: variant.glowRadius)
            .rotationEffect(.degrees(rot))
            .scaleEffect(scl)
            .opacity(opa)
            .position(
                x: containerSize.width / 2 + pos.x,
                y: containerSize.height + pos.y
            )
            .onAppear {
                // Linear progress 0→1 with a cubic-bezier-ish easing; piecewise functions
                // (position/scale/opacity) shape the actual on-screen feel.
                withAnimation(
                    .timingCurve(0.22, 0.85, 0.42, 1.0, duration: piece.duration)
                        .repeatForever(autoreverses: false)
                        .delay(piece.delay)
                ) {
                    progress = 1
                }
            }
    }

    @ViewBuilder
    private var shape: some View {
        switch piece.shape {
        case .circle:
            Circle()
                .frame(width: piece.size, height: piece.size)
        case .rect:
            RoundedRectangle(cornerRadius: 2)
                .frame(width: piece.size, height: piece.size)
        case .streak:
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 2, height: piece.size * 2)
        }
    }

    /// Position relative to origin (bottom-center). Negative y = above the bottom edge.
    private func position(at t: Double) -> CGPoint {
        let peakTime = variant.peakProgress

        if t <= peakTime {
            let local = peakTime == 0 ? 0 : t / peakTime
            return CGPoint(x: piece.vx * CGFloat(local), y: piece.vy * CGFloat(local))
        }

        let local = (t - peakTime) / (1 - peakTime)
        let endX = piece.vx + piece.drift

        let endY: CGFloat = {
            switch variant {
            case .mini:
                // Brief settle: drop ~80pt below peak so the piece looks like it lands inside the card.
                return piece.vy + 80
            case .big:
                // Continue falling past the viewport (130% of container height).
                return containerSize.height * 1.3
            }
        }()

        return CGPoint(
            x: piece.vx + (endX - piece.vx) * CGFloat(local),
            y: piece.vy + (endY - piece.vy) * CGFloat(local)
        )
    }

    private func opacityValue(at t: Double) -> Double {
        // Fade in from 0 → 1 over the first `fadeInEnd` slice.
        if t <= variant.fadeInEnd {
            return variant.fadeInEnd == 0 ? 1 : t / variant.fadeInEnd
        }
        // Mini fades out from peak (0.45) to end (1.0). Big stays opaque.
        switch variant {
        case .mini:
            let peakTime = variant.peakProgress
            if t <= peakTime { return 1 }
            return max(0, 1 - (t - peakTime) / (1 - peakTime))
        case .big:
            return 1
        }
    }

    private func scaleValue(at t: Double) -> Double {
        let peakTime = variant.peakProgress
        if t <= peakTime {
            let local = peakTime == 0 ? 0 : t / peakTime
            return variant.startScale + (1 - variant.startScale) * local
        }
        let local = (t - peakTime) / (1 - peakTime)
        return 1.0 - (1.0 - variant.endScale) * local
    }
}

// MARK: - Mini clipping

private struct ClipIfMini: ViewModifier {
    let variant: Confetti.Variant
    func body(content: Content) -> some View {
        if variant == .mini {
            content.clipped()
        } else {
            content
        }
    }
}

// MARK: - Reduced-motion fallback

private struct ReducedMotionBloom: View {
    let variant: Confetti.Variant

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let radius: CGFloat = variant == .mini ? 80 : 240
            let frame: CGFloat = variant == .mini ? 160 : 480
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lullAmber.opacity(0.32), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: frame, height: frame)
                .opacity(pulse ? 0.85 : 0.45)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.7)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
