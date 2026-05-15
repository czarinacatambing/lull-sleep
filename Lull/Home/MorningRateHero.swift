import SwiftUI

// Primary morning action: tap a dot to rate last night. Two visual states:
//   .unrated → "How did last night go?" headline + the 5-dot row + supporting copy
//   .rated   → "Logged — *nice.*" headline + result chip below the dots
//
// Tapping a dot immediately persists the rating (optimistic). 1..n are filled.
struct MorningRateHero: View {
    let wakeTime: String
    let yesterday: Int?
    let rating: Int?
    let variable: String?       // active experiment variable name
    let testNight: Int          // 1-based: which test night the user is on now
    let totalTestNights: Int    // typically 5
    let onRate: (Int) -> Void

    @State private var tappedDot: Int? = nil
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRated: Bool { (rating ?? 0) > 0 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Pulsing radial glow, top-right corner
            if !reduceMotion {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.lullAmber.opacity(0.30), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .offset(x: 60, y: -40)
                    .scaleEffect(pulse ? 1.06 : 1.0)
                    .opacity(pulse ? 0.95 : 0.55)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                headerRow.padding(.bottom, 14)
                headline.padding(.bottom, 10)
                if !isRated { supportingCopy.padding(.bottom, 18) } else { Spacer().frame(height: 14) }
                dotRow.padding(.bottom, 10)
                scaleLabels
                if isRated { resultChip.padding(.top, 18) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 18)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.lullAmber.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 26, y: 16)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(LinearGradient(
                colors: [Color.lullAmber.opacity(0.16), Color.lullAmber.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom))
            .overlay(
                // Inset highlight on top edge
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .blur(radius: 0.5)
                    .mask(
                        VStack {
                            Rectangle().frame(height: 22)
                            Spacer()
                        }
                    )
            )
    }

    // MARK: - Header row

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.lullAmber, Color(hex: "#a66a2a")],
                                center: .center,
                                startRadius: 0,
                                endRadius: 12
                            )
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: .lullAmberGlow, radius: 8)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#1a0d06"))
                }
                Text("GOOD MORNING")
                    .font(.mono(10))
                    .kerning(1.6)
                    .foregroundColor(.lullAmberSoft)
            }
            Spacer()
            Text(wakeTime.uppercased())
                .font(.mono(10.5))
                .kerning(1.4)
                .foregroundColor(.lullInk3)
        }
    }

    // MARK: - Headline / supporting

    @ViewBuilder
    private var headline: some View {
        if isRated {
            (Text("Logged — ").foregroundColor(.lullInk0)
                + Text("nice.").font(.serifItalic(26)).foregroundColor(.lullAmber))
                .font(.serif(26))
        } else {
            Text("How did last night go?")
                .font(.serif(26))
                .foregroundColor(.lullInk0)
        }
    }

    private var supportingCopy: some View {
        Text("One tap. We'll show you how it compares to yesterday.")
            .font(.system(size: 13))
            .foregroundColor(.lullInk2)
            .lineSpacing(3)
    }

    // MARK: - Dot row

    private var dotRow: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { n in
                MorningRateDot(
                    n: n,
                    rating: rating,
                    tappedDot: tappedDot,
                    reduceMotion: reduceMotion
                ) {
                    tappedDot = n
                    onRate(n)
                    if !reduceMotion {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeOut(duration: 0.15)) { tappedDot = nil }
                        }
                    }
                }
                .accessibilityLabel("Rate \(n) of 5: \(Self.scaleLabel(for: n))")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var scaleLabels: some View {
        HStack {
            Text("WRECKED").font(.mono(9.5)).kerning(1.4).foregroundColor(.lullInk3)
            Spacer()
            Text("GREAT").font(.mono(9.5)).kerning(1.4).foregroundColor(.lullInk3)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Result chip

    private var resultChip: some View {
        HStack(alignment: .top, spacing: 12) {
            // Arrow tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.lullAmber.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.lullAmber.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: chipArrow)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.lullAmber)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let body = chipBody {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk1)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let footnote = chipFootnote {
                    Text(footnote)
                        .font(.mono(9.5))
                        .kerning(1.2)
                        .foregroundColor(.lullAmberSoft)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#0c0807").opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                )
        )
    }

    private var delta: Int? {
        guard let r = rating, let y = yesterday else { return nil }
        return r - y
    }

    private var chipArrow: String {
        guard let d = delta else { return "circle.fill" }
        if d > 0 { return "arrow.up" }
        if d < 0 { return "arrow.down" }
        return "equal"
    }

    private var chipBody: String? {
        guard let d = delta else { return nil }
        let variableText = variable.map { "the \($0.lowercased())" } ?? "this variable"
        let remainingAfterTonight = max(0, totalTestNights - testNight)
        let remainingWord = remainingAfterTonight == 1 ? "night" : "nights"
        let countWord: String = {
            switch remainingAfterTonight {
            case 1: return "One"
            case 2: return "Two"
            case 3: return "Three"
            case 4: return "Four"
            default: return "\(remainingAfterTonight)"
            }
        }()

        if d > 0 {
            return "+\(d) vs yesterday — \(variableText) might be working."
        }
        if d == 0 {
            return remainingAfterTonight > 0
                ? "Same as yesterday. \(countWord) more \(remainingWord) to call it."
                : "Same as yesterday."
        }
        return "\(d) vs yesterday. We'll watch this trend."
    }

    private var chipFootnote: String? {
        guard let variable = variable else { return nil }
        return "NIGHT \(testNight) OF \(totalTestNights) · \(variable.uppercased()) TEST"
    }

    // MARK: - Scale labels for a11y

    private static func scaleLabel(for n: Int) -> String {
        switch n {
        case 1: return "Wrecked"
        case 2: return "Rough"
        case 3: return "OK"
        case 4: return "Good"
        case 5: return "Great"
        default: return ""
        }
    }
}

// MARK: - Dot

private struct MorningRateDot: View {
    let n: Int
    let rating: Int?
    let tappedDot: Int?
    let reduceMotion: Bool
    let action: () -> Void

    private var isInRange: Bool { (rating ?? 0) >= n }
    private var isTapped: Bool { tappedDot == n }

    private var borderOpacity: Double {
        // Slope from muted (dot 1) to bright (dot 5) when unselected.
        0.22 + Double(n - 1) * 0.05
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isInRange {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.lullAmber, Color(hex: "#a66a2a")],
                                center: .center,
                                startRadius: 0,
                                endRadius: 22
                            )
                        )
                        .shadow(color: .lullAmberGlow, radius: 12)
                } else {
                    Circle()
                        .fill(Color(hex: "#0c0807").opacity(0.4))
                        .overlay(
                            Circle()
                                .strokeBorder(Color(red: 1, green: 0.863, blue: 0.745).opacity(borderOpacity), lineWidth: 1.5)
                        )
                }

                Text("\(n)")
                    .font(.serif(15))
                    .foregroundColor(isInRange ? Color(hex: "#1a0d06") : .lullInk2)
            }
            .frame(width: 44, height: 44)
            .scaleEffect(reduceMotion ? 1 : (isTapped ? 1.06 : 1))
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isTapped)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
