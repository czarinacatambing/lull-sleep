import ActivityKit
import SwiftUI
import WidgetKit

struct SleepCompanionWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LullSleepAttributes.self) { context in
            SleepCompanionLockScreenView(context: context)
        } dynamicIsland: { context in
            let phase = context.state.effectivePhase
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    switch phase {
                    case .sleeping:       DISleepLeading(state: context.state)
                    case .awaitingRating: DIWakeLeading(state: context.state)
                    case .rated:          DIConfirmLeading()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    switch phase {
                    case .sleeping:       DISleepTrailing(state: context.state)
                    case .awaitingRating: DIWakeTrailing(state: context.state)
                    case .rated:          DIConfirmTrailing(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    switch phase {
                    case .sleeping:       DISleepBottom()
                    case .awaitingRating: DIWakeBottom(state: context.state)
                    case .rated:          EmptyView()
                    }
                }
            } compactLeading: {
                Image(systemName: compactGlyph(for: phase))
                    .font(.system(size: 13))
                    .foregroundColor(LullLA.amber)
            } compactTrailing: {
                CompactTrailingView(state: context.state, phase: phase)
            } minimal: {
                Image(systemName: compactGlyph(for: phase))
                    .font(.system(size: 12))
                    .foregroundColor(LullLA.amber)
            }
        }
    }

    private func compactGlyph(for phase: LullSleepAttributes.ContentState.Phase) -> String {
        switch phase {
        case .sleeping:       return "moon.fill"
        case .awaitingRating: return "sun.horizon.fill"
        case .rated:          return "checkmark"
        }
    }
}

private struct CompactTrailingView: View {
    let state: LullSleepAttributes.ContentState
    let phase: LullSleepAttributes.ContentState.Phase

    var body: some View {
        switch phase {
        case .sleeping:
            Text(timerInterval: Date()...max(state.wakeTime, Date().addingTimeInterval(1)), countsDown: true)
                .font(LullLAFont.fraunces(size: 14, weight: .regular))
                .foregroundColor(LullLA.ink0)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: 64)
        case .awaitingRating:
            HStack(spacing: 2) {
                Text("Rate")
                    .font(LullLAFont.fraunces(size: 13, weight: .regular))
                    .foregroundColor(LullLA.amber)
                Text("1–5")
                    .font(LullLAFont.mono(size: 10))
                    .foregroundColor(LullLA.amber)
            }
        case .rated:
            HStack(spacing: 3) {
                Text(state.score.map { String(format: "%.1f", $0) } ?? "—")
                    .font(LullLAFont.fraunces(size: 14, weight: .regular))
                    .foregroundColor(LullLA.ink0)
                if let delta = state.deltaVsBaseline {
                    let sign = delta >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: "%.1f", delta))")
                        .font(LullLAFont.mono(size: 9))
                        .foregroundColor(LullLA.amberSoft)
                }
            }
        }
    }
}
