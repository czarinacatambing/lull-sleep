import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Effective phase (the data-vs-visual flip)

// The activity's stored phase doesn't auto-advance at wake time because no app
// code runs while the user sleeps. Every view computes effectivePhase from the
// clock: if Date.now is past wakeTime and we're still nominally "sleeping",
// we render the wake UI anyway. Whenever iOS redraws the Lock Screen (glance,
// notification, system schedule) the user sees the flip without us pushing.
extension LullSleepAttributes.ContentState {
    func effectivePhase(at date: Date = Date(), isStale: Bool = false) -> Phase {
        if phase == .sleeping && (isStale || date >= wakeTime) {
            return .awaitingRating
        }
        return phase
    }
}

// MARK: - Time helpers

private let _timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm"
    return f
}()

private let _timeAmPmFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

private func shortTime(_ date: Date) -> String { _timeFormatter.string(from: date) }
private func longTime(_ date: Date) -> String  { _timeAmPmFormatter.string(from: date) }

// MARK: - Lock Screen view

struct SleepCompanionLockScreenView: View {
    let context: ActivityViewContext<LullSleepAttributes>

    private var state: LullSleepAttributes.ContentState { context.state }

    var body: some View {
        TimelineView(.periodic(from: state.wakeTime, by: 60)) { timeline in
            Group {
                switch state.effectivePhase(at: timeline.date, isStale: context.isStale) {
                case .sleeping:
                    SleepingLockCard(state: state)
                case .awaitingRating:
                    WakeLockCard(state: state)
                case .rated:
                    ConfirmLockCard(state: state)
                }
            }
        }
    }
}

// MARK: - Sleeping (Lock Screen)

private struct SleepingLockCard: View {
    let state: LullSleepAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(LullLA.amberSoft)
                    .frame(width: 7, height: 7)
                    .shadow(color: LullLA.amberGlow, radius: 4)
                Text("TenThirty")
                    .font(LullLAFont.fraunces(size: 13, weight: .light))
                    .foregroundColor(LullLA.ink2)
                Spacer()
                Text("BEDTIME · \(shortTime(state.bedtime))")
                    .font(LullLAFont.mono(size: 9.5))
                    .tracking(1.7)
                    .foregroundColor(LullLA.ink3)
                    .lineLimit(1)
            }

            // Body
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LullLA.amber.opacity(0.10))
                        .frame(width: 42, height: 42)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 18))
                        .foregroundColor(LullLA.amber)
                        .rotationEffect(.degrees(-20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("WAKES IN")
                        .font(LullLAFont.mono(size: 9.5))
                        .tracking(1.7)
                        .foregroundColor(LullLA.ink3)
                    Text(timerInterval: Date()...max(state.wakeTime, Date().addingTimeInterval(1)), countsDown: true)
                        .font(LullLAFont.fraunces(size: 30, weight: .light))
                        .foregroundColor(LullLA.ink0)
                        .lineLimit(1)
                        .monospacedDigit()
                    Text(longTime(state.wakeTime))
                        .font(LullLAFont.mono(size: 10))
                        .tracking(1.0)
                        .foregroundColor(LullLA.ink3)
                }
                Spacer()
            }
            .padding(.top, 14)

            // Footer
            Rectangle()
                .fill(LullLA.hairline)
                .frame(height: 1)
                .padding(.top, 12)

            HStack {
                Text("Can't sleep?")
                    .font(.system(size: 12.5))
                    .foregroundColor(LullLA.ink3)
                Spacer()
                Link(destination: URL(string: "tenthirty://midsleep")!) {
                    Text("Mid-Sleep mode")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(LullLA.ink1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LullLA.amber.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(LullLA.amber.opacity(0.22), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(
            ZStack {
                LullLA.cardSleeping
                RadialGradient(
                    colors: [LullLA.amber.opacity(0.10), .clear],
                    center: .topTrailing,
                    startRadius: 2,
                    endRadius: 140
                )
            }
        )
        // Backup tap target: if Link("tenthirty://midsleep") fails for any reason
        // (Live Activity Link quirks), tapping anywhere else on the card still
        // navigates to Mid-Sleep mode. widgetURL is iOS's first-class
        // tap-to-open mechanism for widget surfaces.
        .widgetURL(URL(string: "tenthirty://midsleep"))
    }
}

// MARK: - Wake / Rate (Lock Screen)

private struct WakeLockCard: View {
    let state: LullSleepAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 13))
                    .foregroundColor(LullLA.amber)
                Text("TenThirty")
                    .font(LullLAFont.fraunces(size: 13, weight: .light))
                    .foregroundColor(LullLA.ink2)
                Spacer()
                Text("GOOD MORNING · \(shortTime(state.wakeTime))")
                    .font(LullLAFont.mono(size: 9.5))
                    .tracking(1.7)
                    .foregroundColor(LullLA.ink3)
                    .lineLimit(1)
            }

            // Prompt
            Text("How did you sleep?")
                .font(LullLAFont.fraunces(size: 22, weight: .light))
                .foregroundColor(LullLA.ink0)
                .padding(.top, 4)

            // Rating row
            RatingDotRow(currentRating: state.rating, numbered: true, showLabels: true)
                .padding(.top, 2)
        }
        .padding(16)
        .background(LullLA.cardWake)
    }
}

// MARK: - Confirmation (Lock Screen)

private struct ConfirmLockCard: View {
    let state: LullSleepAttributes.ContentState

    private static let savedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TenThirty")
                    .font(LullLAFont.fraunces(size: 13, weight: .light))
                    .foregroundColor(LullLA.ink2)
                Spacer()
                Text("SAVED · \(Self.savedFormatter.string(from: Date()))")
                    .font(LullLAFont.mono(size: 9.5))
                    .tracking(1.7)
                    .foregroundColor(LullLA.ink3)
                    .lineLimit(1)
            }
            HStack(spacing: 14) {
                CheckGlyph()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your score is saved")
                        .font(.system(size: 14))
                        .foregroundColor(LullLA.ink1)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(state.score.map { String(format: "%.1f", $0) } ?? "—")
                            .font(LullLAFont.fraunces(size: 22, weight: .light))
                            .foregroundColor(LullLA.ink0)
                        if let delta = state.deltaVsBaseline {
                            let sign = delta >= 0 ? "+" : ""
                            Text("\(sign)\(String(format: "%.1f", delta)) VS \(state.baselineLabel ?? "BASELINE")")
                                .font(LullLAFont.mono(size: 10))
                                .tracking(1.0)
                                .foregroundColor(LullLA.amberSoft)
                        }
                    }
                }
                Spacer()
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(LullLA.cardConfirm)
        .widgetURL(URL(string: "tenthirty://reward"))
    }
}

// MARK: - Rating dot row

struct RatingDotRow: View {
    let currentRating: Int?
    let numbered: Bool
    var showLabels = false
    var dotSize: CGFloat = 30
    var hitSize: CGFloat = 44
    var labelSize: CGFloat = 7.5

    private let labels = ["Awful", "Rough", "Mixed", "Pretty good", "Great"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { n in
                let filled = (currentRating ?? 0) >= n
                Button(intent: LullRateSleepIntent(rating: n)) {
                    VStack(spacing: showLabels ? 3 : 0) {
                        ZStack {
                            Circle()
                                .fill(filled ? LullLA.amber : Color.clear)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            filled ? LullLA.amberSoft : LullLA.amber.opacity(0.35),
                                            lineWidth: filled ? 1.0 : 1.4
                                        )
                                )
                                .shadow(color: filled ? LullLA.amberGlow : .clear, radius: filled ? 6 : 0)
                                .frame(width: dotSize, height: dotSize)
                            if numbered {
                                Text("\(n)")
                                    .font(LullLAFont.fraunces(size: 13, weight: .regular))
                                    .foregroundColor(filled ? LullLA.onAmber : LullLA.amberSoft)
                            }
                        }
                        .frame(width: hitSize, height: hitSize)

                        if showLabels {
                            Text(labels[n - 1])
                                .font(LullLAFont.mono(size: labelSize))
                                .tracking(0.4)
                                .foregroundColor(filled ? LullLA.amberSoft : LullLA.ink3)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.65)
                                .frame(width: hitSize, height: 20, alignment: .top)
                        }
                    }
                    .frame(
                        width: hitSize,
                        height: showLabels ? hitSize + 23 : hitSize
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Rate \(n) of 5: \(labels[n - 1])")
                if n < 5 { Spacer(minLength: 0) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How did you sleep?")
    }
}

// MARK: - Check glyph

struct CheckGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LullLA.amber.opacity(0.12))
            Circle()
                .strokeBorder(LullLA.amber, lineWidth: 1.4)
                .padding(6)
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LullLA.amber)
        }
    }
}

// MARK: - Dynamic Island regions

struct DISleepLeading: View {
    let state: LullSleepAttributes.ContentState
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(LullLA.amber.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: "moon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(LullLA.amber)
                    .rotationEffect(.degrees(-20))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("SLEEPING")
                    .font(LullLAFont.mono(size: 8.5))
                    .tracking(1.6)
                    .foregroundColor(LullLA.ink3)
                Text("TenThirty")
                    .font(LullLAFont.fraunces(size: 13, weight: .light))
                    .foregroundColor(LullLA.ink2)
            }
        }
    }
}

struct DISleepTrailing: View {
    let state: LullSleepAttributes.ContentState
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("WAKES IN")
                .font(LullLAFont.mono(size: 8.5))
                .tracking(1.6)
                .foregroundColor(LullLA.ink3)
            Text(timerInterval: Date()...max(state.wakeTime, Date().addingTimeInterval(1)), countsDown: true)
                .font(LullLAFont.fraunces(size: 22, weight: .light))
                .foregroundColor(LullLA.ink0)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

struct DISleepBottom: View {
    var body: some View {
        HStack {
            Text("Awake at 3am?")
                .font(.system(size: 12))
                .foregroundColor(LullLA.ink3)
            Spacer()
            Link(destination: URL(string: "tenthirty://midsleep")!) {
                Text("Mid-Sleep mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LullLA.ink1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LullLA.amber.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(LullLA.amber.opacity(0.22), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

struct DIWakeLeading: View {
    let state: LullSleepAttributes.ContentState
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(LullLA.amber.opacity(0.14)).frame(width: 32, height: 32)
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(LullLA.amber)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("GOOD MORNING")
                    .font(LullLAFont.mono(size: 8.5))
                    .tracking(1.6)
                    .foregroundColor(LullLA.ink3)
                Text("rate last night")
                    .font(LullLAFont.fraunces(size: 15, weight: .light))
                    .foregroundColor(LullLA.ink1)
            }
        }
    }
}

struct DIWakeTrailing: View {
    let state: LullSleepAttributes.ContentState
    private var sleptText: String {
        let cal = Calendar.autoupdatingCurrent
        let bed = cal.dateComponents([.hour, .minute], from: state.bedtime)
        let wake = cal.dateComponents([.hour, .minute], from: state.wakeTime)
        let bedMinutes = (bed.hour ?? 0) * 60 + (bed.minute ?? 0)
        let wakeMinutes = (wake.hour ?? 0) * 60 + (wake.minute ?? 0)
        let raw = wakeMinutes - bedMinutes
        let mins = raw > 0 ? raw : raw + 24 * 60
        let h = mins / 60
        let m = mins % 60
        return "\(h)h \(m)m"
    }
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("SLEPT")
                .font(LullLAFont.mono(size: 8.5))
                .tracking(1.6)
                .foregroundColor(LullLA.ink3)
            Text(sleptText)
                .font(LullLAFont.fraunces(size: 16, weight: .light))
                .foregroundColor(LullLA.ink0)
        }
    }
}

struct DIWakeBottom: View {
    let state: LullSleepAttributes.ContentState
    var body: some View {
        RatingDotRow(
            currentRating: state.rating,
            numbered: true,
            showLabels: true,
            dotSize: 22,
            hitSize: 44,
            labelSize: 6.5
        )
            .padding(.horizontal, 6)
    }
}

struct DIConfirmLeading: View {
    var body: some View {
        HStack(spacing: 8) {
            CheckGlyph()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("SCORE READY")
                    .font(LullLAFont.mono(size: 8.5))
                    .tracking(1.6)
                    .foregroundColor(LullLA.ink3)
                Text("thanks — saved")
                    .font(LullLAFont.fraunces(size: 13, weight: .light))
                    .foregroundColor(LullLA.ink1)
            }
        }
    }
}

struct DIConfirmTrailing: View {
    let state: LullSleepAttributes.ContentState
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(state.score.map { String(format: "%.1f", $0) } ?? "—")
                .font(LullLAFont.fraunces(size: 26, weight: .light))
                .foregroundColor(LullLA.ink0)
            if let delta = state.deltaVsBaseline {
                let sign = delta >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.1f", delta)) VS \(state.baselineLabel ?? "BASELINE")")
                    .font(LullLAFont.mono(size: 9))
                    .tracking(1.0)
                    .foregroundColor(LullLA.amberSoft)
            }
        }
    }
}
