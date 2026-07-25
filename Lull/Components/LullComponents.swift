import SwiftUI

private struct LullUsesMeadowBackgroundKey: EnvironmentKey {
    static let defaultValue = false
}

private struct LullHidesBrandDotKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var lullUsesMeadowBackground: Bool {
        get { self[LullUsesMeadowBackgroundKey.self] }
        set { self[LullUsesMeadowBackgroundKey.self] = newValue }
    }

    var lullHidesBrandDot: Bool {
        get { self[LullHidesBrandDotKey.self] }
        set { self[LullHidesBrandDotKey.self] = newValue }
    }
}

struct FireflyCTAState: Equatable {
    let frame: CGRect
    let enabled: Bool
}

struct FireflyCTAFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

struct FireflyCTAStatePreferenceKey: PreferenceKey {
    static var defaultValue: FireflyCTAState? = nil

    static func reduce(value: inout FireflyCTAState?, nextValue: () -> FireflyCTAState?) {
        value = nextValue() ?? value
    }
}

struct BrandDotFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

// MARK: - FireflyMascot

struct FireflyMascotView: View {
    let phase: Int
    let reduceMotion: Bool
    var usesFrameSequence = true
    var playbackSpeed = 1.0

    var body: some View {
        Group {
            if usesFrameSequence, Self.hasFrameSequence {
                FireflyMascotFrameSequenceView(playbackSpeed: playbackSpeed)
            } else {
                FireflyMascotFallbackView(phase: phase, reduceMotion: reduceMotion)
            }
        }
        .frame(width: 390, height: 219)
        .accessibilityHidden(true)
    }

    private static var hasFrameSequence: Bool {
        FireflyMascotFrameStore.frameURL(forFrameNumber: 1) != nil
    }
}

private enum FireflyMascotFrameStore {
    static let frameCount = 240
    static let framesPerSecond = 24
    private static let subdirectory = "FireflyMascotFrames"
    private static var cache: [UIImage?] = Array(repeating: nil, count: frameCount)

    static func frameURL(forFrameNumber frameNumber: Int) -> URL? {
        let name = String(format: "firefly_%03d", frameNumber)
        if let nested = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: subdirectory
        ) {
            return nested
        }
        return Bundle.main.url(forResource: name, withExtension: "png")
    }

    static func image(at zeroBasedIndex: Int) -> UIImage? {
        let index = min(max(zeroBasedIndex, 0), frameCount - 1)
        if let cached = cache[index] { return cached }

        guard let url = frameURL(forFrameNumber: index + 1),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache[index] = image
        return image
    }
}

private struct FireflyMascotFrameSequenceView: View {
    let playbackSpeed: Double
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Double(FireflyMascotFrameStore.framesPerSecond))) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate) * playbackSpeed
            let index = Int((elapsed * Double(FireflyMascotFrameStore.framesPerSecond)).rounded(.down)) % FireflyMascotFrameStore.frameCount
            Group {
                if let image = FireflyMascotFrameStore.image(at: index) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.medium)
                            .scaledToFit()
                            .blur(radius: 8)
                            .saturation(1.35)
                            .opacity(0.42)
                            .blendMode(.screen)

                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.medium)
                            .scaledToFit()
                            .brightness(0.09)
                            .contrast(1.18)
                            .saturation(1.28)
                            .shadow(color: .lullAmberGlow.opacity(0.8), radius: 10)
                    }
                } else {
                    Color.clear
                }
            }
            .compositingGroup()
        }
        .onAppear {
            startDate = Date()
        }
        .allowsHitTesting(false)
    }
}

private struct FireflyMascotFallbackView: View {
    let phase: Int
    let reduceMotion: Bool
    @State private var wingFlutter = false

    private var wingOpacity: Double {
        phase == 1 ? 0.26 : 0.16
    }

    private var glowScale: CGFloat {
        phase == 1 ? 1.22 : 0.92
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.lullAmber.opacity(0.34),
                            Color.lullAmber.opacity(0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 32
                    )
                )
                .frame(width: 72, height: 72)
                .scaleEffect(glowScale)
                .blur(radius: 1.2)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.86),
                            Color.lullAmber.opacity(0.96),
                            Color.lullAmber.opacity(0.24),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 19
                    )
                )
                .frame(width: 34, height: 34)
                .shadow(color: .lullAmberGlow, radius: 18)

            ZStack {
                wing
                    .rotationEffect(.degrees(wingFlutter ? -24 : -17), anchor: .leading)
                    .offset(x: 0, y: -9)
                wing
                    .scaleEffect(x: 1, y: -1)
                    .rotationEffect(.degrees(wingFlutter ? 24 : 17), anchor: .leading)
                    .offset(x: 0, y: 9)
            }
            .offset(x: -1, y: -2)
            .opacity(0.38)

            insectBody
                .scaleEffect(0.58)
                .opacity(0.24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                wingFlutter.toggle()
            }
        }
    }

    private var wing: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.lullInk0.opacity(wingOpacity),
                        Color.lullAmber.opacity(0.08),
                        .clear
                    ],
                    center: .leading,
                    startRadius: 1,
                    endRadius: 22
                )
            )
            .frame(width: 32, height: 17)
            .overlay(
                Ellipse()
                    .stroke(Color.lullInk0.opacity(wingOpacity * 0.45), lineWidth: 0.6)
            )
            .blur(radius: 0.12)
    }

    private var insectBody: some View {
        ZStack {
            antenna
                .stroke(Color.black.opacity(0.70), lineWidth: 0.9)
                .frame(width: 18, height: 10)
                .offset(x: -21, y: -8)

            Capsule()
                .fill(Color.black.opacity(0.84))
                .frame(width: 32, height: 8.5)
                .offset(x: -1, y: -1)

            Ellipse()
                .fill(Color.black.opacity(0.88))
                .frame(width: 13, height: 11)
                .offset(x: -15, y: -2)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color.lullAmber.opacity(0.95),
                            Color.lullAmber.opacity(0.12)
                        ],
                        center: .leading,
                        startRadius: 0,
                        endRadius: 17
                    )
                )
                .frame(width: 27, height: 17)
                .offset(x: 15, y: 1)
                .shadow(color: .lullAmberGlow, radius: 18)

            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 1.2, height: 12)
                }
            }
            .rotationEffect(.degrees(90))
            .offset(x: 14, y: 1)

            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 4.5, height: 4.5)
                .offset(x: 6, y: -3)
        }
        .rotationEffect(.degrees(-4))
    }

    private var antenna: Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 8))
        path.addCurve(to: CGPoint(x: 3, y: 2), control1: CGPoint(x: 12, y: 4), control2: CGPoint(x: 8, y: 2))
        path.move(to: CGPoint(x: 16, y: 8))
        path.addCurve(to: CGPoint(x: 5, y: 9), control1: CGPoint(x: 12, y: 9), control2: CGPoint(x: 8, y: 10))
        return path
    }
}

// MARK: - LullScreen
// Warm dark gradient background with optional amber glow. Wraps all in-app screens.

struct LullScreen<Content: View>: View {
    @Environment(\.lullUsesMeadowBackground) private var usesMeadowBackground
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var glow: Bool = true
    var glowX: CGFloat = 0.5
    var glowY: CGFloat = 0.2
    var glowRadius: CGFloat = 240
    var glowOpacity: CGFloat = 0.55
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            if usesMeadowBackground {
                TodayMeadowBackdrop()
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: [.lullBg, .lullBg1], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }

            if glow {
                AmberGlow(x: glowX, y: glowY, radius: glowRadius, opacity: glowOpacity)
                    .ignoresSafeArea()
            }

            content
        }
        .foregroundColor(.lullInk1)
        .preferredColorScheme(.dark)
    }
}

private struct OnboardingAmbientFireflyField: View {
    let reduceMotion: Bool

    private let positions: [CGPoint] = [
        CGPoint(x: 0.16, y: 0.20),
        CGPoint(x: 0.78, y: 0.18),
        CGPoint(x: 0.34, y: 0.38),
        CGPoint(x: 0.88, y: 0.43),
        CGPoint(x: 0.18, y: 0.62),
        CGPoint(x: 0.70, y: 0.70),
        CGPoint(x: 0.42, y: 0.82)
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0, paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ForEach(Array(positions.enumerated()), id: \.offset) { index, point in
                    let phase = Double(index) * 0.74
                    let driftX = reduceMotion ? 0 : sin(time * (0.42 + Double(index % 3) * 0.06) + phase) * CGFloat(10 + index % 3 * 4)
                    let driftY = reduceMotion ? 0 : cos(time * (0.34 + Double(index % 4) * 0.04) + phase) * CGFloat(8 + index % 4 * 3)

                    FireflyDot(index: index, reduceMotion: reduceMotion, drifts: !reduceMotion)
                        .scaleEffect(index % 3 == 0 ? 0.72 : 0.58)
                        .opacity(index < 3 ? 0.82 : 0.55)
                        .position(
                            x: geo.size.width * point.x + driftX,
                            y: geo.size.height * point.y + driftY
                        )
                }
            }
        }
    }
}

// MARK: - AmberGlow

struct AmberGlow: View {
    @Environment(\.lullUsesMeadowBackground) private var usesMeadowBackground
    var x: CGFloat = 0.5
    var y: CGFloat = 0.2
    var radius: CGFloat = 240
    var opacity: CGFloat = 0.55

    var body: some View {
        Group {
            if usesMeadowBackground {
                Color.clear
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    RadialGradient(
                        colors: [Color.lullAmber.opacity(opacity * 0.35), .clear],
                        center: UnitPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius
                    )
                    .frame(width: w, height: h)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - BrandMark

struct BrandMark: View {
    @Environment(\.lullHidesBrandDot) private var hidesBrandDot
    var large: Bool = false
    var maxWidth: CGFloat? = nil

    var body: some View {
        HStack(alignment: .center, spacing: large ? 9 : 6) {
            Text("TenThirty")
                .font(.system(size: large ? 27 : 17, weight: .regular, design: .default))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(maxWidth == nil ? 0.85 : 0.5)
                .layoutPriority(1)

            Circle()
                .fill(Color.lullAmber)
                .frame(width: large ? 8 : 5.5, height: large ? 8 : 5.5)
                .shadow(color: .lullAmberGlow, radius: large ? 8 : 5)
                .opacity(hidesBrandDot ? 0 : 1)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: BrandDotFramePreferenceKey.self,
                            value: proxy.frame(in: .global)
                        )
                    }
                )
        }
        .fixedSize(horizontal: maxWidth == nil, vertical: true)
        .frame(width: maxWidth, alignment: .center)
        .accessibilityLabel("TenThirty")
    }
}

// MARK: - Ember dot

struct Ember: View {
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(Color.lullAmber)
            .frame(width: size, height: size)
            .shadow(color: .lullAmberGlow, radius: size)
    }
}

// MARK: - Kicker

struct Kicker: View {
    var text: String
    var color: SwiftUI.Color = .lullInk3

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
    }
}

// MARK: - SerifTitle

struct SerifTitle: View {
    var text: String
    var size: CGFloat = 28
    var italic: Bool = false
    var color: SwiftUI.Color = .lullInk0

    var body: some View {
        Text(text)
            .font(italic ? .serifItalic(size) : .serif(size))
            .foregroundColor(color)
            .lineSpacing(size * 0.1)
    }
}

// MARK: - Step Progress Bar

struct StepProgress: View {
    var step: Int
    var total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < step ? Color.lullAmber : Color.lullLine)
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
                    .shadow(color: i == step - 1 ? .lullAmberGlow : .clear, radius: 4)
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
    }
}

// MARK: - Onboarding Top Bar

struct OnbTopBar: View {
    var step: Int
    var total: Int
    var showBack: Bool = true
    var onBack: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil

    var body: some View {
        HStack {
            if showBack {
                Button(action: { onBack?() }) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.lullLine, lineWidth: 1)
                            .frame(width: 36, height: 36)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.lullInk2)
                    }
                }
            } else {
                Spacer().frame(width: 36)
            }

            Spacer()

            Text("\(step) / \(total)")
                .font(.mono(11))
                .kerning(1.2)
                .foregroundColor(.lullInk3)

            Spacer()

            if let onSkip {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSkip()
                } label: {
                    Text("SKIP")
                        .font(.mono(11))
                        .kerning(1.2)
                        .foregroundColor(.lullInk3)
                        .frame(width: 36, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip question")
            } else {
                Spacer().frame(width: 36)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }
}

// MARK: - ChoiceRow

struct ChoiceRow: View {
    enum MarkerStyle {
        case checkbox
        case radio
    }

    var text: String
    var hint: String? = nil
    var selected: Bool = false
    var big: Bool = false
    var disabled: Bool = false
    var markerStyle: MarkerStyle = .checkbox
    var onTap: () -> Void

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            onTap()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    switch markerStyle {
                    case .checkbox:
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(selected ? Color.lullAmber : Color.white.opacity(0.25), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selected ? Color.lullAmber : .clear)
                            )
                            .frame(width: 22, height: 22)
                    case .radio:
                        Circle()
                            .strokeBorder(selected ? Color.lullAmber : Color.white.opacity(0.25), lineWidth: 1.5)
                            .background(
                                Circle()
                                    .fill(selected ? Color.lullAmber.opacity(0.12) : .clear)
                            )
                            .frame(width: 22, height: 22)
                    }

                    if selected {
                        switch markerStyle {
                        case .checkbox:
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.lullBgDeep)
                        case .radio:
                            Circle()
                                .fill(Color.lullAmber)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: big ? 16 : 15, weight: .regular))
                        .foregroundColor(selected ? .lullInk0 : .lullInk1)
                        .multilineTextAlignment(.leading)

                    if let hint {
                        Text(hint.uppercased())
                            .font(.mono(10))
                            .kerning(0.8)
                            .foregroundColor(.lullInk3)
                    }
                }
                Spacer()
            }
            .padding(big ? EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22)
                       : EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected
                        ? LinearGradient(colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.04)],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(selected ? Color.lullAmber.opacity(0.55) : Color.lullLine, lineWidth: 1)
            )
            .shadow(color: selected ? Color.black.opacity(0.35) : .clear, radius: 11, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
    }
}

// MARK: - SleepScoreSelector
// 5-circle 1–5 rating used in MorningCheckInView and SleepLogDetailView.
// score == 0 means "not yet selected". Pass disabled: true for read-only past entries.

struct SleepScoreSelector: View {
    @Binding var score: Int
    var disabled: Bool = false

    private let labels = ["Awful", "Rough", "Mixed", "Pretty good", "Great"]

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(1...5, id: \.self) { n in
                    let selected = score == n
                    let baseSize: CGFloat = 36 + CGFloat(n) * 6  // 42 → 66 pt

                    VStack(spacing: 8) {
                        Button(action: {
                            guard !disabled else { return }
                            score = n
                        }) {
                            ZStack {
                                Circle()
                                    .fill(selected
                                        ? AnyShapeStyle(RadialGradient(colors: [.lullAmber, .lullAmberDeep],
                                                                        center: .center, startRadius: 0, endRadius: baseSize / 2))
                                        : AnyShapeStyle(Color.clear))
                                    .overlay(Circle().strokeBorder(
                                        selected ? Color.clear : Color.white.opacity(0.12 + Double(n) * 0.04),
                                        lineWidth: 1.2))
                                    .frame(width: baseSize, height: baseSize)
                                    .shadow(color: selected ? .lullAmberGlow : .clear, radius: 11)

                                Text("\(n)")
                                    .font(.serif(selected ? 22 : 18))
                                    .foregroundColor(selected ? .lullBgDeep : .lullInk3)
                            }
                            .frame(width: 72, height: 72)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .disabled(disabled)

                        Text(labels[n - 1])
                            .font(.mono(8.5))
                            .kerning(0.4)
                            .foregroundColor(selected ? .lullInk1 : .lullInk4)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .frame(height: 24, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - HoursSleptStepper

struct HoursSleptStepper: View {
    @Binding var hours: Double

    private let minHours: Double = 3.0
    private let maxHours: Double = 12.0
    private let step: Double = 0.5

    private var formatted: String {
        let rounded = (hours * 2).rounded() / 2
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("HOURS SLEPT")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk4)

            HStack(spacing: 22) {
                stepButton(symbol: "minus", action: decrement, enabled: hours > minHours)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatted)
                        .font(.serif(34))
                        .foregroundColor(.lullInk0)
                        .monospacedDigit()
                    Text("hrs")
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk3)
                }
                .frame(minWidth: 110)

                stepButton(symbol: "plus", action: increment, enabled: hours < maxHours)
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void, enabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(enabled ? .lullAmber : .lullInk4)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .overlay(Circle().strokeBorder(
                            enabled ? Color.lullAmber.opacity(0.35) : Color.lullLine,
                            lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func increment() {
        hours = min(maxHours, ((hours * 2).rounded() / 2) + step)
    }

    private func decrement() {
        hours = max(minHours, ((hours * 2).rounded() / 2) - step)
    }
}

// MARK: - PrimaryCTA

struct PrimaryCTA: View {
    var title: String
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.lullBgDeep)
                .frame(maxWidth: .infinity)
                .frame(height: Lull.buttonHeight)
                .background(
                    Capsule()
                        .fill(disabled ? Color.lullAmber.opacity(0.25) : Color.lullAmber)
                )
                .shadow(color: disabled ? .clear : Color.lullAmberGlow, radius: 16)
                .shadow(color: disabled ? .clear : Color.black.opacity(0.4), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .overlay {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                Color.clear
                    .preference(key: FireflyCTAFramePreferenceKey.self, value: frame)
                    .preference(
                        key: FireflyCTAStatePreferenceKey.self,
                        value: FireflyCTAState(frame: frame, enabled: !disabled)
                    )
            }
        }
    }
}

// MARK: - GhostButton

struct GhostButton: View {
    var title: String
    var fontSize: CGFloat = 14
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(.lullInk2)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card background helper

extension View {
    func lullCard(radius: CGFloat = 22, accent: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(
                        accent
                        ? LinearGradient(colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)],
                                         startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(accent ? Color.lullAmber.opacity(0.25) : Color.lullLine, lineWidth: 1)
            )
    }
}

// MARK: - Step Header (Nightly Walkthrough)

struct NightlyStepHeader: View {
    var step: Int
    var total: Int
    var label: String
    var time: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandMark()
                Spacer()
                Text("\(step)/\(total) · \(label)")
                    .font(.system(size: 11.5, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk3)
            }

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < step ? Color.lullAmber : Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .frame(height: 2)
                }
            }
            .padding(.top, 18)

            if let time {
                Text("Now · \(time)")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk4)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }
}

// MARK: - ConfettiView

private enum ConfettiShape { case rect, circle, streak }

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var rotation: Double
    var rotationSpeed: Double
    var color: SwiftUI.Color
    var shape: ConfettiShape
    var width: CGFloat
    var height: CGFloat
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    private static let colors: [SwiftUI.Color] = [
        Color(hex: "#f0b96b"), // amber
        Color(hex: "#f4826a"), // coral
        Color(hex: "#7ed4a0"), // mint
        Color(hex: "#b39ddb"), // lavender
        Color(hex: "#7ec8e3"), // sky
    ]

    var body: some View {
        Canvas { ctx, size in
            for p in particles {
                let rect = CGRect(
                    x: p.x * size.width - p.width / 2,
                    y: p.y * size.height - p.height / 2,
                    width: p.width,
                    height: p.height
                )
                ctx.translateBy(x: rect.midX, y: rect.midY)
                ctx.rotate(by: .degrees(p.rotation))
                ctx.translateBy(x: -rect.midX, y: -rect.midY)

                var path: Path
                switch p.shape {
                case .rect:
                    path = Path(rect)
                case .circle:
                    path = Path(ellipseIn: CGRect(x: rect.minX, y: rect.minY, width: p.width, height: p.width))
                case .streak:
                    path = Path(CGRect(x: rect.minX, y: rect.minY, width: p.width * 0.3, height: p.height * 1.8))
                }
                ctx.fill(path, with: .color(p.color))
            }
        }
        .onAppear {
            particles = (0..<70).map { _ in makeParticle() }
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
                elapsed += 1.0 / 60.0
                let gravity: CGFloat = 0.0006
                particles = particles.map { var p = $0
                    p.velocityY += gravity
                    p.x += p.velocityX
                    p.y += p.velocityY
                    p.rotation += p.rotationSpeed
                    return p
                }
                if elapsed > 3.5 { timer?.invalidate(); timer = nil }
            }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func makeParticle() -> ConfettiParticle {
        let shapes: [ConfettiShape] = [.rect, .rect, .circle, .streak]
        return ConfettiParticle(
            x: CGFloat.random(in: 0.05...0.95),
            y: CGFloat.random(in: 1.0...1.2),
            velocityX: CGFloat.random(in: -0.004...0.004),
            velocityY: CGFloat.random(in: -0.022...(-0.008)),
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -4...4),
            color: Self.colors.randomElement()!,
            shape: shapes.randomElement()!,
            width: CGFloat.random(in: 6...14),
            height: CGFloat.random(in: 8...18)
        )
    }
}
