import SwiftUI
import UserNotifications

struct GetUpPromptView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var buzzTime: Date { Date().addingTimeInterval(20 * 60) }
    private var buzzTimeString: String { GetUpPromptView.timeFmt.string(from: buzzTime) }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.35, radius: 230, opacity: 0.45)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 16)

                        HStack {
                            Text("Get-up protocol")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundColor(.lullInk4)
                            Spacer()
                            Text("\(GetUpPromptView.timeFmt.string(from: Date())) · 20 min awake")
                                .font(.system(size: 11.5, weight: .medium, design: .default))
                                .foregroundColor(.lullInk4)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)

                        VStack(spacing: 16) {
                            Kicker(text: "The kindest thing for your brain", color: .lullAmberSoft)
                            (Text("Get out of bed\nfor ")
                                .font(.serif(30))
                                .foregroundColor(.lullInk0)
                            + Text("15 minutes.")
                                .font(.serifItalic(30))
                                .foregroundColor(.lullAmber))
                            .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        Text("Your bed should mean sleep. Sit somewhere dim, do something boring. Check your phone at \(buzzTimeString) — if you see a notification, it's time to go back.")
                            .font(.system(size: 13.5))
                            .foregroundColor(.lullInk2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 290)
                            .padding(.top, 16)

                        Spacer()

                        // Warm lamp + chair illustration
                        GetUpIllustration()
                            .frame(width: 200, height: 160)
                            .padding(.top, 40)

                        Spacer()

                        // Timer pill
                        HStack(spacing: 10) {
                            Ember(size: 5)
                            Text("SILENT NOTIF AT \(buzzTimeString)")
                                .font(.mono(12))
                                .kerning(0.8)
                                .foregroundColor(.lullInk2)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.03)))
                        .overlay(Capsule().strokeBorder(Color.lullLine, lineWidth: 1))
                        .padding(.top, 20)

                        VStack(spacing: 0) {
                            PrimaryCTA(title: "I'm getting up") {
                                scheduleGetUpNotification()
                                dismiss()
                            }
                            GhostButton(title: "I'd rather stay · try a story") { dismiss() }
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 36)
                        .padding(.bottom, 36)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    private func scheduleGetUpNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["get_up_return"])

        let content = UNMutableNotificationContent()
        content.title = "Time to come back."
        content.body = "You've been up 20 minutes. Your bed is waiting — lie back down."
        content.sound = nil
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let fireDate = buzzTime
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "get_up_return", content: content, trigger: trigger)
        center.add(request)
    }
}

struct GetUpIllustration: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let amber = Color(hex: "#f0b96b")
            let amberDeep = Color(hex: "#a66a2a")
            let bg2 = Color(hex: "#1a110e")
            let ink4 = Color(hex: "#5c4f42")

            // Lamp glow (ellipse radial)
            context.drawLayer { inner in
                inner.opacity = 0.6
                let glowRect = CGRect(x: w * 0.29, y: -20, width: w * 0.42, height: h * 0.8)
                let gradient = Gradient(colors: [amber.opacity(0.5), .clear])
                inner.fill(
                    Path(ellipseIn: glowRect),
                    with: .linearGradient(gradient, startPoint: CGPoint(x: glowRect.midX, y: glowRect.minY),
                                          endPoint: CGPoint(x: glowRect.midX, y: glowRect.maxY))
                )
            }

            // Lamp shade
            var shade = Path()
            shade.move(to: CGPoint(x: w * 0.41, y: h * 0.14))
            shade.addLine(to: CGPoint(x: w * 0.59, y: h * 0.14))
            shade.addLine(to: CGPoint(x: w * 0.62, y: h * 0.26))
            shade.addLine(to: CGPoint(x: w * 0.38, y: h * 0.26))
            shade.closeSubpath()
            context.fill(shade, with: .color(amberDeep.opacity(0.85)))

            // Lamp cord
            context.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.5, y: h * 0.14))
                p.addLine(to: CGPoint(x: w * 0.5, y: 0))
            }, with: .color(ink4.opacity(0.5)), lineWidth: 0.5)

            // Chair body
            let chairX = w * 0.32, chairY = h * 0.575
            context.fill(
                Path(roundedRect: CGRect(x: chairX, y: chairY, width: w * 0.2, height: h * 0.31), cornerRadius: 3),
                with: .color(bg2)
            )
            context.fill(
                Path(roundedRect: CGRect(x: chairX - 2, y: chairY, width: w * 0.2 + 4, height: h * 0.04), cornerRadius: 2),
                with: .color(Color(hex: "#231612"))
            )
            for xOffset in [chairX, chairX + w * 0.15] {
                context.fill(
                    Path(roundedRect: CGRect(x: xOffset, y: chairY + h * 0.3, width: w * 0.03, height: h * 0.11), cornerRadius: 1),
                    with: .color(bg2)
                )
            }

            // Small book nearby
            context.fill(
                Path(roundedRect: CGRect(x: chairX + w * 0.24, y: chairY + h * 0.2, width: w * 0.11, height: h * 0.018), cornerRadius: 1),
                with: .color(amberDeep.opacity(0.7))
            )
            context.fill(
                Path(roundedRect: CGRect(x: chairX + w * 0.24, y: chairY + h * 0.175, width: w * 0.11, height: h * 0.025), cornerRadius: 0),
                with: .color(Color(hex: "#231612"))
            )
        }
    }
}
