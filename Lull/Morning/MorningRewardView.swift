import SwiftUI

// Payload captured at the moment the user logs a morning score, so the reward
// sheet can render with the just-logged numbers (without recomputing from
// AppState after advanceExperiment may have already mutated state).
struct PendingMorningReward: Identifiable, Equatable {
    let id = UUID()
    let score: Int
    let yesterday: Int?
    let baseline: Int
    let variable: String?
    let night: Int
}

// Mini-celebration screen that follows the morning rating.
// Confetti pops UP inside the score card only when today.score > yesterday.score.
// Steady (=) and off-night (▼) share the same layout with no confetti.
struct MorningRewardView: View {
    let score: Int
    let yesterday: Int?
    let baseline: Int

    let variable: String?       // tonight's experiment variable; nil = no experiment running
    let night: Int              // scored nights so far (1...totalNights)
    let totalNights: Int

    let allowRerate: Bool       // RE-RATE chip shown only before noon
    let onRerate: () -> Void
    let onDismiss: () -> Void
    let onNote: () -> Void

    // MARK: derived

    private var deltaVsYesterday: Int? {
        guard let y = yesterday else { return nil }
        return score - y
    }

    private enum Mood { case improved, steady, off, firstNight }

    private var mood: Mood {
        guard let d = deltaVsYesterday else { return .firstNight }
        if d > 0 { return .improved }
        if d == 0 { return .steady }
        return .off
    }

    private var kickerText: String {
        switch mood {
        case .improved: return "Better than yesterday"
        case .steady:   return "Logged · steady"
        case .off:      return "Logged · off-night"
        case .firstNight: return "Logged · steady"
        }
    }

    private var kickerColor: Color {
        mood == .improved ? .lullAmberSoft : .lullInk3
    }

    private var showsConfetti: Bool { mood == .improved }

    private var dateFmt: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "EEE · h:mm a"; return f
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.32, radius: 360, opacity: showsConfetti ? 0.85 : 0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Header
                HStack {
                    BrandMark()
                    Spacer()
                    if allowRerate {
                        Button(action: onRerate) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .medium))
                                Text("RE-RATE")
                                    .font(.mono(9.5))
                                    .kerning(1.2)
                            }
                            .foregroundColor(.lullInk3)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().strokeBorder(Color.lullLine, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 40)

                        // Kicker
                        Kicker(text: kickerText, color: kickerColor)

                        // Score card with mini confetti (when improved)
                        scoreCard
                            .padding(.top, 22)

                        // Headline
                        headlineText
                            .padding(.top, 24)
                            .padding(.horizontal, 28)

                        // Caption row
                        captionRow
                            .padding(.top, 10)

                        // Tonight's experiment card
                        if let variable {
                            tonightExperimentCard(variable: variable)
                                .padding(.horizontal, 22)
                                .padding(.top, 32)
                        }
                    }
                }

                // CTAs
                VStack(spacing: 0) {
                    PrimaryCTA(title: "See tonight's plan", action: onDismiss)
                    GhostButton(title: "Add a note · woke at 4am", action: onNote)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Score card

    private var scoreCard: some View {
        let borderColor: Color = showsConfetti ? Color.lullAmber.opacity(0.32) : Color.lullLine
        let fill: AnyShapeStyle = showsConfetti
            ? AnyShapeStyle(LinearGradient(
                colors: [Color.lullAmber.opacity(0.12), Color.lullAmber.opacity(0.02)],
                startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(Color.white.opacity(0.03))

        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(score)")
                    .font(.serif(64))
                    .foregroundColor(.lullInk0)
                    .kerning(-1.5)
                Text("/5")
                    .font(.serif(22))
                    .foregroundColor(.lullInk3)
            }
            deltaPill
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(minWidth: 220)
        // .background gives the inner ZStack the same frame as the VStack so
        // the Confetti's GeometryReader can measure the card and animate pieces
        // inside it. Layering as a sibling in a .fixedSize ZStack collapsed it.
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                if showsConfetti {
                    Confetti(variant: .mini)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private var deltaPill: some View {
        switch mood {
        case .improved:
            if let d = deltaVsYesterday {
                pillContent(text: "▲ +\(d) VS YESTERDAY",
                            fg: .lullAmber,
                            bg: Color.lullAmber.opacity(0.18))
            }
        case .off:
            if let d = deltaVsYesterday {
                pillContent(text: "▼ \(d) VS YESTERDAY",
                            fg: .lullInk3,
                            bg: Color(red: 120/255, green: 140/255, blue: 160/255).opacity(0.16))
            }
        case .steady:
            pillContent(text: "= SAME AS YESTERDAY",
                        fg: .lullInk3,
                        bg: Color.white.opacity(0.06))
        case .firstNight:
            EmptyView()
        }
    }

    private func pillContent(text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.mono(10))
            .kerning(1.2)
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }

    // MARK: - Headline

    @ViewBuilder
    private var headlineText: some View {
        switch mood {
        case .improved:
            (Text("That's ").foregroundColor(.lullInk0)
                + Text("better than yesterday.").font(.serifItalic(22)).foregroundColor(.lullAmber))
                .font(.serif(22))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        case .steady, .firstNight:
            (Text("Steady night. Two more like it and we'll ").foregroundColor(.lullInk0)
                + Text("promote a variable.").font(.serifItalic(22)).foregroundColor(.lullAmber))
                .font(.serif(22))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        case .off:
            (Text("Off-night happens. We'll ").foregroundColor(.lullInk0)
                + Text("keep testing.").font(.serifItalic(22)).foregroundColor(.lullAmber))
                .font(.serif(22))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Caption row

    private var captionRow: some View {
        Text(captionText)
            .font(.mono(10.5))
            .kerning(1.2)
            .foregroundColor(.lullInk3)
    }

    private var captionText: String {
        let y = yesterday.map(String.init) ?? "—"
        return "YESTERDAY \(y) · TODAY \(score) · BASELINE \(baseline)"
    }

    // MARK: - Tonight's experiment

    private func tonightExperimentCard(variable: String) -> some View {
        // `night` is the number of already-rated nights (including the one just logged).
        // Tonight will be the (night + 1)-th test night; remaining is what's left AFTER tonight.
        let nextNight = min(night + 1, totalNights)
        let remaining = max(0, totalNights - nextNight)
        let remainingWord = remaining == 1 ? "night" : "nights"
        let countWord: String = {
            switch remaining {
            case 1: return "One"
            case 2: return "Two"
            case 3: return "Three"
            case 4: return "Four"
            default: return "\(remaining)"
            }
        }()
        let remainingText = remaining > 0
            ? "\(countWord) more \(remainingWord) to know if it earns a spot in your routine."
            : ""

        return VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Tonight's experiment", color: .lullAmberSoft)

            (Text("Testing ").foregroundColor(.lullInk1)
                + Text(variable).foregroundColor(.lullAmber)
                + Text(" — night \(nextNight) of \(totalNights). ").foregroundColor(.lullInk1)
                + Text(remainingText).foregroundColor(.lullInk2))
                .font(.system(size: 13))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    showsConfetti
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.lullAmber.opacity(0.08), Color.lullAmber.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(showsConfetti ? Color.lullAmber.opacity(0.32) : Color.lullLine,
                                      lineWidth: 1)
                )
        )
    }
}
