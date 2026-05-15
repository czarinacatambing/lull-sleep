import SwiftUI

// Quiet informational card that sits below MorningRateHero on the morning state.
// Tells the user "tonight is already taken care of" so they're not anxious at 6:42 AM.
// Subtle opacity bump from 0.85 → 1.0 once they've rated.
struct TonightPreviewCard: View {
    let rated: Bool
    let variable: String?
    let testNight: Int                // tonight's test night number
    let totalTestNights: Int
    let schedule: [Row]               // first 3 actionable items in chronological order
    let startsAt: String              // "8:14 PM" — start of wind-down
    let onEditRoutine: () -> Void

    struct Row: Identifiable {
        let id = UUID()
        let time: String              // "7:34"
        let label: String             // "Weighted blanket out"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "Tonight is already set up")
                Spacer()
                Text("STARTS \(startsAt.uppercased())")
                    .font(.mono(10))
                    .kerning(1.2)
                    .foregroundColor(.lullInk3)
            }

            // Title
            titleLine
                .padding(.top, 10)

            // Schedule rows
            VStack(spacing: 6) {
                ForEach(schedule.prefix(3)) { row in
                    scheduleRow(time: row.time, label: row.label)
                }
            }
            .padding(.top, 14)

            // Footer
            Divider()
                .background(Color.lullLine)
                .padding(.top, 14)

            HStack {
                Text("We'll remind you at \(schedule.first?.time ?? startsAt) PM")
                    .font(.mono(10))
                    .kerning(0.8)
                    .foregroundColor(.lullInk3)
                Spacer()
                Button(action: onEditRoutine) {
                    HStack(spacing: 4) {
                        Text("EDIT IN ROUTINE")
                            .font(.mono(10))
                            .kerning(1.2)
                        Text("→")
                            .font(.mono(10))
                    }
                    .foregroundColor(.lullAmberSoft)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 1, green: 0.863, blue: 0.745).opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                )
        )
        .opacity(rated ? 1.0 : 0.85)
    }

    @ViewBuilder
    private var titleLine: some View {
        if let variable = variable {
            (Text(variable).foregroundColor(.lullInk0)
                + Text(" · night \(testNight) of \(totalTestNights)").font(.serifItalic(18)).foregroundColor(.lullInk2))
                .font(.serif(18))
        } else {
            Text("Your routine is ready.")
                .font(.serif(18))
                .foregroundColor(.lullInk0)
        }
    }

    private func scheduleRow(time: String, label: String) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.mono(11))
                .foregroundColor(.lullInk3)
                .frame(width: 38, alignment: .leading)
            Ember(size: 3)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.lullInk1)
            Spacer()
        }
    }
}
