import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Brand colors (inlined — no shared theme module in extension)

private let amber     = Color(red: 240/255, green: 185/255, blue: 107/255)
private let amberGlow = Color(red: 240/255, green: 185/255, blue: 107/255).opacity(0.4)
private let ink0      = Color(red: 245/255, green: 231/255, blue: 215/255)
private let ink1      = Color(red: 229/255, green: 211/255, blue: 191/255)
private let ink3      = Color(red: 150/255, green: 128/255, blue: 106/255)
private let bg        = Color(red: 12/255,  green: 8/255,   blue: 7/255)
private let surface   = Color(white: 1, opacity: 0.04)
private let lineColor = Color(white: 1, opacity: 0.10)

// MARK: - Helpers

private func timeString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f.string(from: date)
}

// MARK: - Lock Screen / Notification Banner view

struct PrepChecklistLiveActivityView: View {
    let context: ActivityViewContext<PrepChecklistAttributes>

    private var items:    [PrepChecklistAttributes.Item] { context.attributes.items }
    private var doneIds:  [String] { context.state.doneIds }
    private var doneCount: Int  { doneIds.count }
    private var total:    Int   { items.count }
    private var allDone:  Bool  { doneCount == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            progressBar
            itemList
        }
        .padding(16)
        .background(bg)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.fill")
                .font(.system(size: 11))
                .foregroundColor(amber)
            Text("BEDTIME PREP")
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .kerning(0.8)
                .foregroundColor(ink3)
            Spacer()
            Text("\(doneCount) of \(total) done")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(allDone ? amber : ink3)
            Text(timeString(context.attributes.bedtime))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(ink3)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 99)
                    .fill(amber.opacity(0.12))
                    .frame(height: 2)
                if total > 0 {
                    RoundedRectangle(cornerRadius: 99)
                        .fill(amber)
                        .frame(width: geo.size.width * CGFloat(doneCount) / CGFloat(total), height: 2)
                        .shadow(color: amberGlow, radius: 4)
                }
            }
        }
        .frame(height: 2)
    }

    private var itemList: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                let done = doneIds.contains(item.id)
                Button(intent: TogglePrepItemIntent(itemId: item.id)) {
                    HStack(spacing: 10) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15))
                            .foregroundColor(done ? amber : lineColor)
                        Text(item.label)
                            .font(.system(.callout))
                            .foregroundColor(done ? ink3 : ink0)
                            .strikethrough(done, color: ink3)
                            .lineLimit(1)
                        Spacer()
                        Text(timeString(item.scheduledTime))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(done ? ink3.opacity(0.5) : ink3)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 26/255, green: 13/255, blue: 6/255))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(amber))
                            .shadow(color: amberGlow, radius: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Mark \(item.label) done")
            }
        }
    }
}

// MARK: - Dynamic Island expanded

private struct ExpandedView: View {
    let context: ActivityViewContext<PrepChecklistAttributes>

    private var items:    [PrepChecklistAttributes.Item] { context.attributes.items }
    private var doneIds:  [String] { context.state.doneIds }
    private var doneCount: Int  { doneIds.count }
    private var total:    Int   { items.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Bedtime prep", systemImage: "moon.fill")
                    .font(.system(.caption, design: .default).weight(.medium))
                    .foregroundColor(amber)
                Spacer()
                Text("\(doneCount)/\(total)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(ink3)
            }
            VStack(spacing: 4) {
                ForEach(items.prefix(3)) { item in
                    let done = doneIds.contains(item.id)
                    Button(intent: TogglePrepItemIntent(itemId: item.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundColor(done ? amber : lineColor)
                            Text(item.label)
                                .font(.system(.caption))
                                .foregroundColor(done ? ink3 : ink0)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 26/255, green: 13/255, blue: 6/255))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(amber))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Mark \(item.label) done")
                }
                if items.count > 3 {
                    Text("+ \(items.count - 3) more")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(ink3)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Widget

struct PrepChecklistActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrepChecklistAttributes.self) { context in
            PrepChecklistLiveActivityView(context: context)
        } dynamicIsland: { context in
            let doneCount = context.state.doneIds.count
            let total     = context.attributes.items.count

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(context: context)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 10))
                        .foregroundColor(amber)
                    Text("\(doneCount)/\(total)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(ink0)
                }
            } compactTrailing: {
                Text("\(doneCount)/\(total)")
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundColor(doneCount == total ? amber : ink0)
            } minimal: {
                Image(systemName: doneCount == total ? "moon.fill" : "moon")
                    .font(.system(size: 12))
                    .foregroundColor(amber)
            }
        }
    }
}
