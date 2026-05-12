import SwiftUI

// MARK: - LullScreen
// Warm dark gradient background with optional amber glow. Wraps all in-app screens.

struct LullScreen<Content: View>: View {
    var glow: Bool = true
    var glowX: CGFloat = 0.5
    var glowY: CGFloat = 0.2
    var glowRadius: CGFloat = 240
    var glowOpacity: CGFloat = 0.55
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.lullBg, .lullBg1], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

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

// MARK: - AmberGlow

struct AmberGlow: View {
    var x: CGFloat = 0.5
    var y: CGFloat = 0.2
    var radius: CGFloat = 240
    var opacity: CGFloat = 0.55

    var body: some View {
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
        .allowsHitTesting(false)
    }
}

// MARK: - BrandMark

struct BrandMark: View {
    var large: Bool = false

    var body: some View {
        HStack(spacing: large ? 10 : 7) {
            Circle()
                .fill(Color.lullAmber)
                .frame(width: large ? 12 : 8, height: large ? 12 : 8)
                .shadow(color: .lullAmberGlow, radius: 7)

            Text("lull")
                .font(.serif(large ? 24 : 16, italic: true))
                .foregroundColor(.lullInk0)
                .kerning(-0.5)
        }
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
    var color: Color = .lullInk3

    var body: some View {
        Text(text.uppercased())
            .font(.mono(10))
            .kerning(1.8)
            .foregroundColor(color)
    }
}

// MARK: - SerifTitle

struct SerifTitle: View {
    var text: String
    var size: CGFloat = 28
    var italic: Bool = false
    var color: Color = .lullInk0

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

            Text("SKIP")
                .font(.mono(11))
                .kerning(1.2)
                .foregroundColor(.lullInk3)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }
}

// MARK: - ChoiceRow

struct ChoiceRow: View {
    var text: String
    var hint: String? = nil
    var selected: Bool = false
    var big: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(selected ? Color.lullAmber : Color.white.opacity(0.25), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(selected ? Color.lullAmber : .clear)
                        )
                        .frame(width: 22, height: 22)

                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.lullBgDeep)
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
    }
}

// MARK: - SleepScoreSelector
// 5-circle 1–5 rating used in MorningCheckInView and SleepLogDetailView.
// score == 0 means "not yet selected". Pass disabled: true for read-only past entries.

struct SleepScoreSelector: View {
    @Binding var score: Int
    var disabled: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(1...5, id: \.self) { n in
                    let selected = score == n
                    let baseSize: CGFloat = 36 + CGFloat(n) * 6  // 42 → 66 pt

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

                            if selected {
                                Text("\(n)")
                                    .font(.serif(22))
                                    .foregroundColor(.lullBgDeep)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .disabled(disabled)
                }
            }
            .padding(.horizontal, 28)

            HStack {
                Text("WRECKED").font(.mono(9.5)).kerning(1.4).foregroundColor(.lullInk4)
                Spacer()
                Text("FANTASTIC").font(.mono(9.5)).kerning(1.4).foregroundColor(.lullInk4)
            }
            .padding(.horizontal, 32)
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
                Text("\(step)/\(total) · \(label.uppercased())")
                    .font(.mono(10.5))
                    .kerning(1.2)
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
                Text("NOW · \(time)")
                    .font(.mono(10))
                    .kerning(0.8)
                    .foregroundColor(.lullInk4)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }
}
