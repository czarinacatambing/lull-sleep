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
        var peakProgress: Double  { self == .mini ? 0.45 : 0.35 }
        var fadeInEnd: Double     { self == .mini ? 0.15 : 0.06 }
        var startScale: Double    { self == .mini ? 0.3 : 0.4 }
        var endScale: Double      { self == .mini ? 0.9 : 1.0 }
    }

    let variant: Variant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ReducedMotionBloom(variant: variant)
                .allowsHitTesting(false)
                .modifier(ClipIfMini(variant: variant))
        } else {
            ConfettiCanvas(variant: variant)
                .allowsHitTesting(false)
                .modifier(ClipIfMini(variant: variant))
        }
    }
}

// MARK: - Piece

private struct ConfettiPiece {
    enum PieceShape { case rect, circle, streak }

    let vx: CGFloat
    let vy: CGFloat
    let drift: CGFloat
    let delay: Double
    let duration: Double
    let size: CGFloat
    let rotationEnd: Double   // degrees
    let color: Color
    let shape: PieceShape
}

// MARK: - Palette

private enum ConfettiPalette {
    static let colors: [Color] = [
        Color(hex: "#f0b96b"),
        Color(hex: "#f25c54"),
        Color(hex: "#9bd1c4"),
        Color(hex: "#a89cc8"),
        Color(hex: "#f7d488"),
        Color(hex: "#5bc0eb"),
        Color(hex: "#ee9c81"),
        Color(hex: "#f6f4ef"),
    ]
}

// Seeded pseudo-random so visuals stay consistent across launches.
private func seededRandom(_ i: Int, _ seed: Int) -> Double {
    let raw = sin(Double(i) * 9301.0 + Double(seed) * 49297.0) * 233280.0
    return raw - floor(raw)
}

private func makePieces(variant: Confetti.Variant) -> [ConfettiPiece] {
    (0..<variant.pieces).map { i in
        let angleDeg = (seededRandom(i, 1) - 0.5) * 2 * variant.fanDegrees
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

// MARK: - Canvas (TimelineView-driven, no SwiftUI animation dependency)

private struct ConfettiCanvas: View {
    let variant: Confetti.Variant

    @State private var pieces: [ConfettiPiece] = []
    @State private var startDate: Date? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let start = startDate else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    draw(piece: piece, elapsed: elapsed, context: &context, size: size)
                }
            }
        }
        .onAppear {
            if pieces.isEmpty { pieces = makePieces(variant: variant) }
            // Delay past the sheet/fullScreenCover slide-up (~0.35s) so the
            // clock starts after the presentation animation completes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                startDate = Date()
            }
        }
    }

    private func draw(piece: ConfettiPiece, elapsed: Double,
                      context: inout GraphicsContext, size: CGSize) {
        let t = pieceProgress(piece: piece, elapsed: elapsed)
        guard t > 0 && t < 1 else { return }

        let opa = opacity(t: t)
        guard opa > 0 else { return }

        let pos = position(piece: piece, t: t, size: size)
        let rot = piece.rotationEnd * t * (.pi / 180)
        let scl = CGFloat(scale(t: t))

        let cx = size.width / 2 + pos.x
        let cy = size.height + pos.y

        context.drawLayer { ctx in
            ctx.opacity = opa
            ctx.transform = CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: rot)
                .scaledBy(x: scl, y: scl)
            let s = piece.size
            switch piece.shape {
            case .circle:
                ctx.fill(Path(ellipseIn: CGRect(x: -s/2, y: -s/2, width: s, height: s)),
                         with: .color(piece.color))
            case .rect:
                ctx.fill(Path(roundedRect: CGRect(x: -s/2, y: -s/2, width: s, height: s),
                              cornerRadius: 2),
                         with: .color(piece.color))
            case .streak:
                ctx.fill(Path(roundedRect: CGRect(x: -1, y: -s, width: 2, height: s * 2),
                              cornerRadius: 1),
                         with: .color(piece.color))
            }
        }
    }

    private func pieceProgress(piece: ConfettiPiece, elapsed: Double) -> Double {
        let adjusted = elapsed - piece.delay
        guard adjusted > 0 else { return 0 }
        return min(adjusted / piece.duration, 1.0)
    }

    private func position(piece: ConfettiPiece, t: Double, size: CGSize) -> CGPoint {
        let peakTime = variant.peakProgress
        if t <= peakTime {
            let local = peakTime == 0 ? 0 : t / peakTime
            return CGPoint(x: piece.vx * CGFloat(local), y: piece.vy * CGFloat(local))
        }
        let local = (t - peakTime) / (1 - peakTime)
        let endX = piece.vx + piece.drift
        let endY: CGFloat = variant == .mini ? piece.vy + 80 : size.height * 1.3
        return CGPoint(
            x: piece.vx + (endX - piece.vx) * CGFloat(local),
            y: piece.vy + (endY - piece.vy) * CGFloat(local)
        )
    }

    private func opacity(t: Double) -> Double {
        if t <= variant.fadeInEnd {
            return variant.fadeInEnd == 0 ? 1 : t / variant.fadeInEnd
        }
        switch variant {
        case .mini:
            let peakTime = variant.peakProgress
            if t <= peakTime { return 1 }
            return max(0, 1 - (t - peakTime) / (1 - peakTime))
        case .big:
            return 1
        }
    }

    private func scale(t: Double) -> Double {
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
