import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var showMenu = false
    @State private var currentDate = Date()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE · h:mm a"; return f
    }()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Hi,"
        }
    }

    var body: some View {
        ZStack {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: -0.05, radius: 260, opacity: 0.7)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)

                    // Top bar
                    HStack {
                        BrandMark()
                        Spacer()
                        Button(action: { withAnimation(.easeOut(duration: 0.18)) { showMenu.toggle() } }) {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.lullLine, lineWidth: 1)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.lullInk2)
                            }
                        }
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, 8)

                    // Greeting
                    VStack(alignment: .leading, spacing: 14) {
                        Kicker(text: DashboardView.dateFmt.string(from: currentDate))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(greeting)
                                .font(.serif(32))
                                .foregroundColor(.lullInk0)
                            Text("let's wind down.")
                                .font(.serifItalic(32))
                                .foregroundColor(.lullInk2)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                    // Tonight's suggestion card
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(RadialGradient(colors: [Color.lullAmberGlow, .clear],
                                                 center: .center, startRadius: 0, endRadius: 100))
                            .frame(width: 200, height: 200)
                            .offset(x: 40, y: -40)
                            .allowsHitTesting(false)

                        VStack(alignment: .leading, spacing: 0) {
                            Kicker(text: "Tonight's routine", color: .lullAmberSoft)

                            if let status = state.experimentStatus {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(status.variable) —")
                                        .font(.serif(22))
                                        .foregroundColor(.lullInk0)
                                        .padding(.top, 8)
                                    Text("\(state.sleepWindowMinutes) minutes total.")
                                        .font(.serifItalic(22))
                                        .foregroundColor(.lullAmber)
                                }
                                Text(status.insightLine)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(3)
                                    .padding(.top, 8)
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Building your routine —")
                                        .font(.serif(22))
                                        .foregroundColor(.lullInk0)
                                        .padding(.top, 8)
                                    Text("\(state.sleepWindowMinutes) minutes total.")
                                        .font(.serifItalic(22))
                                        .foregroundColor(.lullAmber)
                                }
                                Text("Complete a few nights to start personalizing your sleep routine.")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(3)
                                    .padding(.top, 8)
                            }

                            PrimaryCTA(title: "Start routine") { state.showNightlyFlow = true }
                                .padding(.top, 22)
                        }
                        .padding(22)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(
                                colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.lullAmber.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 20, y: 18)
                    .clipped()
                    .padding(.horizontal, 22)

                    // What's coming
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Kicker(text: "What's coming")
                            Spacer()
                            Text("EDIT")
                                .font(.mono(10.5))
                                .kerning(1)
                                .foregroundColor(.lullInk3)
                        }

                        VStack(spacing: 8) {
                            ForEach(state.scheduledRoutine.filter {
                                $0.step.label != "Brightness check" && $0.step.label != "Temperature check"
                            }) { row in
                                HStack(spacing: 12) {
                                    Text(row.timeString)
                                        .font(.mono(11))
                                        .foregroundColor(.lullInk3)
                                        .frame(width: 38, alignment: .leading)
                                    Ember(size: 4)
                                    Text(row.step.label)
                                        .font(.system(size: 13.5))
                                        .foregroundColor(.lullInk1)
                                    Spacer()
                                    Text(row.badge)
                                        .font(.mono(10))
                                        .kerning(0.6)
                                        .foregroundColor(.lullInk4)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02)))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                            }
                            // Sleep target row
                            let fmt = DateFormatter()
                            let _ = (fmt.dateFormat = "h:mm")
                            HStack(spacing: 12) {
                                Text(fmt.string(from: state.typicalBedtime))
                                    .font(.mono(11))
                                    .foregroundColor(.lullInk3)
                                    .frame(width: 38, alignment: .leading)
                                Ember(size: 4)
                                Text("Sleep")
                                    .font(.system(size: 13.5))
                                    .foregroundColor(.lullInk1)
                                Spacer()
                                Text("\(state.sleepDurationString) target")
                                    .font(.mono(10))
                                    .kerning(0.6)
                                    .foregroundColor(.lullInk4)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02)))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }
        }
        .fullScreenCover(isPresented: $state.showNightlyFlow) {
            NightlyFlowView()
        }
        .onAppear { currentDate = Date() }

        if showMenu {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showMenu = false } }

            VStack(alignment: .trailing, spacing: 0) {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.18)) { showMenu = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        state.showMidSleepMode = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Ember(size: 5)
                        Text("Mid-Sleep Mode")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#1a1310"))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.5), radius: 16, y: 8)
            )
            .frame(width: 190)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 68)
            .padding(.trailing, 22)
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            .zIndex(10)
        }
        } // ZStack
    }
}
