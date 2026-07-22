import SwiftUI
import FamilyControls
import PostHog
import StoreKit

// Onboarding coordinator — sleep-thief branch, rules, contract, then trial.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var didTrackStart = false
    @State private var didTrackCompanion = false
    @State private var ctaFrame: CGRect?
    @State private var ctaFramesByStep: [Int: CGRect] = [:]
    @State private var ctaStatesByStep: [Int: FireflyCTAState] = [:]
    @State private var brandDotFrame: CGRect?
    @State private var draftTargetBedtime = Date()
    @State private var draftTargetWakeTime = Date()
    @State private var didHydrateSleepWindowDraft = false

    private var showsFireflyCompanion: Bool {
        state.isOnboardingFireflyCompanionActive
    }

    private var usesMeadowBackground: Bool {
        showsFireflyCompanion
    }

    var body: some View {
        ZStack {
            switch step {
            case 0: OnbSleepProblemView(step: $step)
            case 1: OnbSleepRulesView(step: $step)
            case 2: OnbBedtimeView(
                step: $step,
                kind: .target,
                bedtime: $draftTargetBedtime,
                wakeTime: $draftTargetWakeTime
            )
            .onAppear(perform: hydrateSleepWindowDraftIfNeeded)
            case 3: OnbRoutineReadyView(step: $step)
            case 4: OnbAppBlockingHowItWorksView(step: $step)
            case 5: OnbAppBlockingCommitmentView(step: $step)
            case 6: OnbTrialPaywallView()
            default: EmptyView()
            }

            if showsFireflyCompanion {
                OnboardingFireflyCompanion(
                    step: step,
                    ctaFrame: ctaFrame,
                    ctaFramesByStep: ctaFramesByStep,
                    ctaStatesByStep: ctaStatesByStep,
                    brandDotFrame: brandDotFrame,
                    reduceMotion: reduceMotion
                )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(4)
            }
        }
        .environment(\.lullUsesMeadowBackground, usesMeadowBackground)
        .environment(\.lullHidesBrandDot, showsFireflyCompanion)
        .animation(step == 6 ? .easeInOut(duration: 0.7) : .easeInOut(duration: 0.28), value: step)
        .transition(.opacity)
        .postHogNoMask()
        .onAppear {
            hydrateSleepWindowDraftIfNeeded()
            if !didTrackStart {
                didTrackStart = true
                state.trackOnboardingStarted()
            }
            if showsFireflyCompanion, !didTrackCompanion {
                didTrackCompanion = true
                state.trackOnboardingFireflyCompanionShown()
            }
            state.trackOnboardingScreen(screenName(for: step))
        }
        .onChange(of: step) { _, newStep in
            state.trackOnboardingScreen(screenName(for: newStep))
        }
        .onChange(of: showsFireflyCompanion) { _, enabled in
            if enabled, !didTrackCompanion {
                didTrackCompanion = true
                state.trackOnboardingFireflyCompanionShown()
            }
        }
        .onPreferenceChange(FireflyCTAFramePreferenceKey.self) { frame in
            ctaFrame = frame
            if let frame {
                ctaFramesByStep[step] = frame
            }
        }
        .onPreferenceChange(FireflyCTAStatePreferenceKey.self) { ctaState in
            guard let ctaState else { return }
            ctaFrame = ctaState.frame
            withAnimation(.easeInOut(duration: 0.55)) {
                ctaFramesByStep[step] = ctaState.frame
                ctaStatesByStep[step] = ctaState
            }
        }
        .onPreferenceChange(BrandDotFramePreferenceKey.self) { frame in
            brandDotFrame = frame
        }
    }

    private func hydrateSleepWindowDraftIfNeeded() {
        guard !didHydrateSleepWindowDraft else { return }
        draftTargetBedtime = state.targetBedtime
        draftTargetWakeTime = state.targetWakeTime
        didHydrateSleepWindowDraft = true
    }

    private func screenName(for step: Int) -> String {
        switch step {
        case 0: return "sleep_thief"
        case 1: return "sleep_rules"
        case 2: return "sleep_window"
        case 3: return "sleep_contract"
        case 4: return "app_blocking_how_it_works"
        case 5: return "app_blocking_commitment"
        case 6: return "trial_paywall"
        default: return "unknown"
        }
    }
}

private struct OnboardingFireflyCompanion: View {
    let step: Int
    let ctaFrame: CGRect?
    let ctaFramesByStep: [Int: CGRect]
    let ctaStatesByStep: [Int: FireflyCTAState]
    let brandDotFrame: CGRect?
    let reduceMotion: Bool
    @State private var displayedStep = 0
    @State private var pendingStep: Int?
    @State private var visible = false
    @State private var horizontalTravel: CGFloat = -360

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0, paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let point = companionPosition(for: displayedStep, in: geo, time: time)
                let ctaReady = isCTAReady(for: displayedStep)
                let bobX = reduceMotion ? 0 : sin(time * (ctaReady ? 0.72 : 0.48)) * (ctaReady ? 4 : 14)
                let bobY = reduceMotion ? 0 : cos(time * (ctaReady ? 0.64 : 0.42)) * (ctaReady ? 5 : 12)
                let flicker = reduceMotion ? 1.0 : 0.90 + (sin(time * 1.7) + 1) * 0.045

                FireflyDot(index: displayedStep, reduceMotion: reduceMotion, drifts: !reduceMotion)
                    .scaleEffect(ctaReady ? 0.88 : 1.02)
                    .opacity((visible ? 1 : 0) * flicker)
                    .position(x: point.x + horizontalTravel + bobX, y: point.y + bobY)
                    .animation(.easeInOut(duration: reduceMotion ? 0.18 : 3.0), value: isCTAReady(for: displayedStep))
            }
        }
        .ignoresSafeArea()
        .onAppear {
            displayedStep = step
            horizontalTravel = reduceMotion ? 0 : -280
            withAnimation(.easeInOut(duration: reduceMotion ? 0.18 : 3.0)) {
                visible = true
                horizontalTravel = 0
            }
        }
        .onChange(of: step) { _, newStep in
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.12)) {
                    visible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    displayedStep = newStep
                    withAnimation(.easeIn(duration: 0.18)) {
                        visible = true
                    }
                }
            } else if canResolvePosition(for: newStep) {
                pendingStep = nil
                flyToStep(newStep)
            } else {
                pendingStep = newStep
                withAnimation(.easeInOut(duration: 0.45)) {
                    horizontalTravel = 160
                    visible = false
                }
            }
        }
        .onChange(of: ctaFramesByStep) { _, _ in
            guard !reduceMotion,
                  let pendingStep,
                  canResolvePosition(for: pendingStep)
            else { return }
            self.pendingStep = nil
            flyToStep(pendingStep)
        }
    }

    private func flyToStep(_ newStep: Int) {
        withAnimation(.easeInOut(duration: 0.45)) {
            horizontalTravel = 170
            visible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            displayedStep = newStep
            horizontalTravel = -280
            visible = true
            withAnimation(.easeInOut(duration: 3.0)) {
                horizontalTravel = 0
            }
        }
    }

    private func canResolvePosition(for step: Int) -> Bool {
        step == 0 || ctaFramesByStep[step] != nil
    }

    private func isCTAReady(for step: Int) -> Bool {
        ctaStatesByStep[step]?.enabled ?? false
    }

    private func companionPosition(for step: Int, in geo: GeometryProxy, time: TimeInterval) -> CGPoint {
        let size = geo.size
        let safeBottom = geo.safeAreaInsets.bottom
        let safeTop = geo.safeAreaInsets.top

        if step == 0 {
            if isCTAReady(for: step), let ctaFrame = ctaStatesByStep[step]?.frame ?? ctaFramesByStep[step] {
                return ctaRestPosition(ctaFrame: ctaFrame, size: size, safeTop: safeTop, time: time)
            }
            if let brandDotFrame, ctaStatesByStep[step] == nil {
                return CGPoint(x: brandDotFrame.midX, y: brandDotFrame.midY)
            }
            return roamingPosition(step: step, size: size, safeTop: safeTop, safeBottom: safeBottom, time: time)
        }

        if isCTAReady(for: step), let ctaFrame = ctaStatesByStep[step]?.frame ?? ctaFramesByStep[step] ?? ctaFrame {
            return ctaRestPosition(ctaFrame: ctaFrame, size: size, safeTop: safeTop, time: time)
        }

        return roamingPosition(step: step, size: size, safeTop: safeTop, safeBottom: safeBottom, time: time)
    }

    private func ctaRestPosition(ctaFrame: CGRect, size: CGSize, safeTop: CGFloat, time: TimeInterval) -> CGPoint {
        let horizontalRadius = min(max(ctaFrame.width * 0.36, 92), 156)
        let verticalRadius = min(max(ctaFrame.height * 0.68, 40), 58)
        let base = CGPoint(
            x: ctaFrame.midX,
            y: ctaFrame.minY - 18
        )
        return CGPoint(
            x: min(size.width - 38, max(38, base.x + CGFloat(sin(time * 0.36)) * horizontalRadius)),
            y: min(size.height - 110, max(safeTop + 72, base.y + CGFloat(cos(time * 0.31)) * verticalRadius))
        )
    }

    private func roamingPosition(
        step: Int,
        size: CGSize,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        time: TimeInterval
    ) -> CGPoint {
        let phase = Double(step) * 0.91
        let centerX = size.width * (0.42 + 0.12 * sin(time * 0.16 + phase))
        let centerY = size.height * (0.36 + 0.14 * cos(time * 0.14 + phase * 0.7))
        return CGPoint(
            x: min(max(centerX, 42), size.width - 42),
            y: min(max(centerY, safeTop + 88), size.height - safeBottom - 164)
        )
    }
}

// MARK: - Screen 0: Welcome

struct OnbWelcomeView: View {
    @Binding var step: Int

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.42, radius: 340, opacity: 0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 56)
                BrandMark(large: true)

                Spacer()

                VStack(spacing: 20) {
                    Kicker(text: "Tonight", color: .lullAmberSoft)
                    VStack(spacing: 0) {
                        Text("Help me sleep")
                            .font(.serif(46))
                            .foregroundColor(.lullInk0)
                        Text("tonight.")
                            .font(.serifItalic(46))
                            .foregroundColor(.lullAmber)
                    }
                    Text("One minute of breathing first. Then we'll build the routine that gets you back to great sleep.")
                        .font(.system(size: 14.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 290)
                }
                .padding(.horizontal, 28)

                Spacer()

                PrimaryCTA(title: "Help me sleep tonight") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    step = 1
                }
                .padding(.horizontal, 20)

                Text("~ 2 MIN · NO SIGNUP")
                    .font(.mono(10))
                    .kerning(2)
                    .foregroundColor(.lullInk4)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Screen 1: Promise

struct OnbPromiseView: View {
    @Binding var step: Int
    @State private var sparkle = false

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.08, y: 0.92, radius: 330, opacity: 0.5)
                .ignoresSafeArea()
            AmberGlow(x: 0.92, y: 0.02, radius: 260, opacity: 0.32)
                .ignoresSafeArea()

            GeometryReader { geo in
                let compact = geo.size.height < 720
                let stageHeight = max(compact ? 286 : 348, geo.size.height * (compact ? 0.38 : 0.44))

                VStack(spacing: 0) {
                    Spacer().frame(height: compact ? 22 : 30)

                    HStack {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            step = 2
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.lullInk2)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(Circle().strokeBorder(Color.lullLine, lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go back")

                        Spacer()
                        BrandMark()
                        Spacer()

                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.bottom, compact ? 22 : 30)

                    VStack(spacing: 14) {
                        VStack(spacing: 0) {
                            Text("A ritual you can")
                                .font(.serif(compact ? 25 : 27, weight: .semibold))
                                .foregroundColor(.lullInk0)

                            Text("actually follow")
                                .font(.serifItalic(compact ? 25 : 27))
                                .foregroundColor(.lullAmber)
                                .padding(.top, -3)
                        }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 330)

                        Text("TenThirty sends the nudge, gives you one card at a time, and closes the loop after you sleep.")
                            .font(.system(size: compact ? 13.5 : 14.5))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 306)
                    }
                    .padding(.horizontal, 24)

                    PromiseStage(sparkle: sparkle)
                        .frame(height: stageHeight)
                        .padding(.horizontal, 18)
                        .padding(.top, compact ? 8 : 18)

                    Spacer(minLength: compact ? 10 : 18)

                    PrimaryCTA(title: "Let's continue") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        step = 4
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, compact ? 24 : 34)
                }
            }
        }
        .onAppear {
            sparkle = false
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                sparkle = true
            }
        }
    }
}

private struct PromiseStage: View {
    var sparkle: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let phoneHeight = min(height - 4, 344)
            let phoneWidth = min(width * 0.68, phoneHeight * 0.56)
            let lift = sparkle ? -5.0 : 5.0

            ZStack {
                PromiseSparkle(size: 13)
                    .position(x: width * 0.16, y: height * 0.23)
                    .opacity(sparkle ? 0.9 : 0.18)
                    .scaleEffect(sparkle ? 1.1 : 0.72)

                PromiseSparkle(size: 18)
                    .position(x: width * 0.83, y: height * 0.18)
                    .opacity(sparkle ? 0.22 : 0.95)
                    .scaleEffect(sparkle ? 0.74 : 1.08)

                PromiseSparkle(size: 12)
                    .position(x: width * 0.85, y: height * 0.82)
                    .opacity(sparkle ? 0.82 : 0.14)
                    .scaleEffect(sparkle ? 1.04 : 0.68)

                PromisePhoneDemo(swipeProgress: sparkle ? 1 : 0)
                    .frame(width: phoneWidth, height: phoneHeight)
                    .shadow(color: Color.black.opacity(0.45), radius: 28, y: 18)
                    .offset(y: lift)

                PromiseActionLabel(
                    icon: "bell.badge.fill",
                    title: "Reminder",
                    subtitle: "10:05 PM"
                )
                .position(x: max(42, width * 0.08), y: height * 0.34)
                .offset(y: sparkle ? 5 : -3)

                PromiseActionLabel(
                    icon: "hand.draw.fill",
                    title: "Swipe",
                    subtitle: "done"
                )
                .position(x: min(width - 56, width * 0.84), y: height * 0.44)
                .offset(y: sparkle ? -4 : 5)

                PromiseActionLabel(
                    icon: "moon.zzz.fill",
                    title: "Sleep",
                    subtitle: "10:40 PM"
                )
                .position(x: max(42, width * 0.10), y: height * 0.73)
                .offset(y: sparkle ? 4 : -4)
            }
        }
    }
}

private struct PromisePhoneDemo: View {
    var swipeProgress: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let cardOffset = CGFloat(swipeProgress) * 34
            let cardRotation = Double(swipeProgress) * 7

            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(Color(hex: "#050404"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34)
                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 1.2)
                    )

                RoundedRectangle(cornerRadius: 29)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#211509"), Color(hex: "#100b07"), Color(hex: "#201708")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(6)

                VStack(spacing: 0) {
                    PromiseStatusBar()
                        .padding(.horizontal, 17)
                        .padding(.top, 13)

                    PromiseDynamicIsland()
                        .padding(.top, -13)

                    VStack(alignment: .leading, spacing: 10) {
                        PromiseNotificationCard()
                            .padding(.top, 9)

                        Text("Tonight's ritual")
                            .font(.serif(19, weight: .semibold))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 2)

                        ZStack {
                            PromiseRitualMiniCard(
                                title: "Warm shower",
                                detail: "Finished 20 min ago",
                                icon: "shower.fill",
                                done: true
                            )
                            .scaleEffect(0.92)
                            .offset(y: -12)
                            .opacity(0.48)

                            PromiseRitualMiniCard(
                                title: "Brain dump",
                                detail: "Swipe right when done",
                                icon: "pencil.and.list.clipboard",
                                done: swipeProgress > 0.5
                            )
                            .rotationEffect(.degrees(cardRotation))
                            .offset(x: cardOffset, y: 16)
                            .overlay(alignment: .topTrailing) {
                                PromiseDoneStamp()
                                    .opacity(swipeProgress)
                                    .scaleEffect(0.78 + swipeProgress * 0.22)
                                    .padding(.top, 12)
                                    .padding(.trailing, 10)
                            }
                        }
                        .frame(height: height * 0.30)
                        .padding(.top, 2)

                        HStack(spacing: 7) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("swipe cards as you finish")
                                .font(.mono(8))
                                .kerning(0.8)
                        }
                        .foregroundColor(.lullInk3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)

                        PromiseSleepPayoff()
                            .padding(.top, 7)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 10)
                }

                SleepyFace(isAsleep: true)
                    .frame(width: 82, height: 82)
                    .scaleEffect(0.68)
                    .position(x: width * 0.29, y: height * 0.94)
                    .shadow(color: Color.lullAmber.opacity(0.28), radius: 14, y: 7)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct PromiseStatusBar: View {
    var body: some View {
        HStack {
            Text("10:05")
                .font(.system(size: 9, weight: .semibold))
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 7.5, weight: .semibold))
        }
        .foregroundColor(.lullInk0.opacity(0.88))
    }
}

private struct PromiseDynamicIsland: View {
    var body: some View {
        Capsule()
            .fill(Color.black.opacity(0.92))
            .frame(width: 54, height: 15)
            .overlay(
                Circle()
                    .fill(Color(hex: "#1b2733"))
                    .frame(width: 5, height: 5)
                    .offset(x: 17)
            )
    }
}

private struct PromiseNotificationCard: View {
    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.lullAmber.opacity(0.16))
                    .frame(width: 28, height: 28)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.lullAmber)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("TenThirty")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.lullInk0)
                    Text("now")
                        .font(.system(size: 8))
                        .foregroundColor(.lullInk3)
                }

                Text("Wind-down starts now")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.lullInk1)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct PromiseRitualMiniCard: View {
    var title: String
    var detail: String
    var icon: String
    var done: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.lullAmber.opacity(0.13))
                        .frame(width: 31, height: 31)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.lullAmber)
                }

                Spacer()

                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(done ? Color(hex: "#8fce93") : .lullInk4)
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.serif(18, weight: .semibold))
                .foregroundColor(.lullInk0)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.system(size: 9.5))
                .foregroundColor(.lullInk3)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 122)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#15100c"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 16, y: 10)
    }
}

private struct PromiseDoneStamp: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
            Text("DONE")
                .font(.mono(8))
                .kerning(0.8)
        }
        .foregroundColor(Color(hex: "#8fce93"))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(hex: "#8fce93").opacity(0.13)))
        .overlay(Capsule().strokeBorder(Color(hex: "#8fce93").opacity(0.38), lineWidth: 1))
    }
}

private struct PromiseSleepPayoff: View {
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Asleep near target")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.lullInk0)
                Text("10:40 PM")
                    .font(.serifItalic(18))
                    .foregroundColor(.lullAmber)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.lullAmber.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct PromiseActionLabel: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.lullAmber)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.lullAmber.opacity(0.12)))
                .overlay(Circle().strokeBorder(Color.lullAmber.opacity(0.24), lineWidth: 1))

            Text(title)
                .font(.mono(8))
                .kerning(0.8)
                .foregroundColor(.lullInk2)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 8))
                .foregroundColor(.lullInk4)
                .lineLimit(1)
        }
        .frame(width: 62)
    }
}

private enum PromiseCardStyle {
    case tonight
    case week
}

private struct PromiseCard: View {
    var title: String
    var meta: String
    var style: PromiseCardStyle

    private var isWeek: Bool { style == .week }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(meta)
                .font(.mono(9))
                .kerning(1.0)
                .foregroundColor(isWeek ? .lullAmberSoft : Color(hex: "#6f7d8d"))
                .padding(.top, 14)
                .padding(.horizontal, 15)

            Text(title)
                .font(.serifItalic(18))
                .foregroundColor(isWeek ? .lullAmber : Color(hex: "#9fb0c4"))
                .padding(.top, 4)
                .padding(.horizontal, 15)

            Spacer()

            ZStack {
                if isWeek {
                    Circle()
                        .fill(Color.lullAmber.opacity(0.16))
                        .frame(width: 112, height: 112)
                        .blur(radius: 6)
                }

                SleepyFace(isAsleep: isWeek)
                    .frame(width: 118, height: 118)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(isWeek ? Color.lullAmber.opacity(0.18) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: isWeek ? Color.lullAmber.opacity(0.22) : Color.black.opacity(0.45), radius: 24, y: 18)
    }

    private var cardBackground: some ShapeStyle {
        if isWeek {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#241809"), Color(hex: "#160f06")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color(hex: "#13100f"))
    }
}

private struct SleepyFace: View {
    var isAsleep: Bool

    var body: some View {
        ZStack {
            if !isAsleep {
                ForEach([-1, 1], id: \.self) { side in
                    Path { path in
                        let x: CGFloat = side < 0 ? 30 : 88
                        let direction = CGFloat(side)
                        path.move(to: CGPoint(x: x, y: 24))
                        path.addLine(to: CGPoint(x: x + 6 * direction, y: 33))
                        path.addLine(to: CGPoint(x: x - 4 * direction, y: 39))
                        path.addLine(to: CGPoint(x: x + 4 * direction, y: 50))
                    }
                    .stroke(Color(hex: "#7f93a8"), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                }
            }

            if isAsleep {
                Path { path in
                    path.move(to: CGPoint(x: 40, y: 50))
                    path.addQuadCurve(to: CGPoint(x: 80, y: 50), control: CGPoint(x: 60, y: 20))
                    path.closeSubpath()
                }
                .fill(Color.lullAmber)

                Circle()
                    .fill(Color.lullInk0)
                    .frame(width: 9, height: 9)
                    .position(x: 80, y: 48)
            }

            Ellipse()
                .fill(isAsleep ? Color(hex: "#caa06a") : Color(hex: "#2c3a49"))
                .frame(width: 68, height: 60)
                .position(x: 60, y: 76)

            if isAsleep {
                closedEye(x: 48)
                closedEye(x: 72)
                Path { path in
                    path.move(to: CGPoint(x: 52, y: 86))
                    path.addQuadCurve(to: CGPoint(x: 68, y: 86), control: CGPoint(x: 60, y: 92))
                }
                .stroke(Color(hex: "#3a2a16"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                Text("z")
                    .font(.serif(13))
                    .foregroundColor(.lullAmber)
                    .position(x: 94, y: 38)
                Text("z")
                    .font(.serif(10))
                    .foregroundColor(.lullAmber.opacity(0.75))
                    .position(x: 102, y: 28)
            } else {
                awakeEye(x: 48)
                awakeEye(x: 72)
                Path { path in
                    path.move(to: CGPoint(x: 50, y: 88))
                    path.addQuadCurve(to: CGPoint(x: 70, y: 88), control: CGPoint(x: 60, y: 82))
                }
                .stroke(Color(hex: "#8aa0ad"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#9fd0ff").opacity(0.85))
                    .frame(width: 13, height: 20)
                    .rotationEffect(.degrees(18))
                    .position(x: 84, y: 96)
            }
        }
    }

    private func awakeEye(x: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#dfe8f1"))
                .frame(width: 22, height: 22)
            Circle()
                .fill(Color(hex: "#10171f"))
                .frame(width: 10, height: 10)
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: 2, y: -2)
        }
        .position(x: x, y: 68)
    }

    private func closedEye(x: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x - 6, y: 72))
            path.addQuadCurve(to: CGPoint(x: x + 6, y: 72), control: CGPoint(x: x, y: 78))
        }
        .stroke(Color(hex: "#3a2a16"), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }
}

private struct PromiseSparkle: View {
    var size: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .regular))
            .foregroundColor(.lullAmber)
    }
}

private struct PromiseArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 10))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 8, y: rect.minY + 12),
            control1: CGPoint(x: rect.minX + 14, y: rect.minY + 14),
            control2: CGPoint(x: rect.maxX - 20, y: rect.minY + 4)
        )
        path.move(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 12))
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.minY + 10))
        path.move(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 12))
        path.addLine(to: CGPoint(x: rect.maxX - 12, y: rect.minY + 24))
        return path
    }
}

// MARK: - Screen 2: Transition

struct OnbTransitionView: View {
    @Binding var step: Int
    @State private var showQuestion = false
    @State private var questionOut = false
    @State private var showFirstLine = false
    @State private var showSecondLine = false

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.3, radius: 280, opacity: 0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                HStack { BrandMark(); Spacer() }
                    .padding(.horizontal, Lull.horizontalPad)

                Spacer()

                ZStack {
                    Text("Feel calmer?")
                        .font(.serif(44))
                        .foregroundColor(.lullInk0)
                        .multilineTextAlignment(.center)
                        .scaleEffect(showQuestion ? (questionOut ? 0.97 : 1.0) : 0.94)
                        .opacity(showQuestion && !questionOut ? 1 : 0)

                    VStack(spacing: 12) {
                        Text("That tool is now yours — anytime you need it.")
                            .opacity(showFirstLine ? 1 : 0)
                            .offset(y: showFirstLine ? 0 : 12)
                        Text("Let's build the rest of your routine.")
                            .opacity(showSecondLine ? 1 : 0)
                            .offset(y: showSecondLine ? 0 : 12)
                    }
                    .font(.serif(29))
                    .foregroundColor(.lullInk0)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 310)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)

                Spacer()

                PrimaryCTA(title: "Next") {
                    step = 3
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        showQuestion = false
        questionOut = false
        showFirstLine = false
        showSecondLine = false

        withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
            showQuestion = true
        }
        withAnimation(.easeIn(duration: 0.7).delay(1.7)) {
            questionOut = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.65) {
            withAnimation(.easeOut(duration: 0.7)) {
                showFirstLine = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.55) {
            withAnimation(.easeOut(duration: 0.7)) {
                showSecondLine = true
            }
        }
    }
}

// MARK: - Screen 1: Sleep Problem

struct OnbSleepProblemView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    var body: some View {
        LullScreen(glow: false, glowX: 0.2, glowY: -0.1, glowRadius: 210, glowOpacity: 0.7) {
            AmberGlow(x: 0.2, y: -0.1, radius: 210, opacity: 0.7)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 1, total: 5, showBack: false, onSkip: {
                        state.setSleepThief(.scrolling)
                        applySleepProblemMapping(.scrolling)
                        step = 1
                    })
                    StepProgress(step: 1, total: 5)

                    HStack {
                        Spacer()
                        BrandMark()
                        Spacer()
                    }
                    .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step one · sleep thief")
                        Text("What steals\nyour sleep?")
                            .font(.serif(30))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Pick the thing TenThirty should protect you from first.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(SleepThief.allCases) { thief in
                            ChoiceRow(
                                text: thief.title,
                                selected: state.sleepThief == thief,
                                markerStyle: .radio,
                                onTap: {
                                    state.setSleepThief(thief)
                                    applySleepProblemMapping(thief)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Choose sleep rules", disabled: state.sleepThief == nil) { step = 1 }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private func applySleepProblemMapping(_ thief: SleepThief) {
        switch thief {
        case .scrolling:
            state.selectedSleepProblems = [0]
            state.selectedPreBedActivities.insert(0)
        case .racingMind:
            state.selectedSleepProblems = [1]
        case .bedtimeDelay:
            state.selectedSleepProblems = [0, 4]
        case .nightPhone:
            state.selectedSleepProblems = [2]
            state.selectedPreBedActivities.insert(0)
        case .inconsistentNights:
            state.selectedSleepProblems = [4]
        }
    }
}

// MARK: - Screen 2: Sleep Rules

struct OnbSleepRulesView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    var body: some View {
        LullScreen(glow: false, glowX: 0.82, glowY: 0.06, glowRadius: 260, glowOpacity: 0.5) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 2, total: 5, onBack: { step = 0 }, onSkip: {
                        if state.selectedSleepRules.isEmpty {
                            state.toggleSleepRule(.dimLights)
                            state.toggleSleepRule(.tomorrowsPlan)
                        }
                        step = 2
                    })
                    StepProgress(step: 2, total: 5)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step two · your rules")
                        Text("Choose your\nsleep rules.")
                            .font(.serif(30))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Pick 1-3 sleep habits and the apps to pause if you miss them.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(SleepRuleKind.editableCases) { rule in
                            ChoiceRow(
                                text: rule.title,
                                hint: rule.detail,
                                selected: state.selectedSleepRules.contains(rule),
                                disabled: !state.selectedSleepRules.contains(rule) && state.selectedSleepRules.count >= 3,
                                onTap: { state.toggleSleepRule(rule) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Text("\(state.selectedSleepRules.count)/3 selected")
                        .font(.mono(10))
                        .kerning(1.3)
                        .foregroundColor(.lullInk3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 18)

                    PrimaryCTA(title: "Build my contract", disabled: state.selectedSleepRules.isEmpty) {
                        step = 2
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 2: What Wakes You

struct OnbWhatWakesView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "New parent / postpartum",
        "Shift work or irregular schedule",
        "High-stress job / founder / on-call",
        "ADHD or racing mind",
        "Anxiety or worry",
        "Physical discomfort",
        "I suspect a medical issue",
        "None of the above",
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.8, y: 0.0, radius: 250, opacity: 0.6)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 3, total: 6, onBack: { step = 4 }, onSkip: {
                        state.selectedWakes = []
                        step = 6
                    })
                    StepProgress(step: 3, total: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step three · your situation")
                        Text("What's life like\naround your sleep?")
                            .font(.serif(30))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("We use this to read your sleep pattern and which leaks matter most. Pick anything that fits.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedWakes.contains(i),
                                onTap: { toggle(&state.selectedWakes, i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Continue", disabled: state.selectedWakes.isEmpty) { step = 6 }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }
}

// MARK: - Screen 3: Your Window

struct OnbBaselineRatingView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var score: Int = 0

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.0, radius: 280, opacity: 0.55)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                    OnbTopBar(step: 3, total: 4, onBack: { step = 1 }, onSkip: {
                        state.baselineScore = 3
                        step = 3
                    })
                StepProgress(step: 3, total: 4)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: "Step two · your baseline")
                    Text("How satisfied are\nyou with your sleep?")
                        .font(.serif(28))
                        .foregroundColor(.lullInk0)
                        .padding(.top, 10)
                    Text("This gives us a starting point, so you can see what's actually working.")
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 10)
                .padding(.bottom, 36)

                SleepScoreSelector(score: $score)

                Spacer()

                PrimaryCTA(title: "Continue", disabled: score == 0) {
                    state.baselineScore = AppState.clampedSleepScore(score)
                    step = 3
                }
                .opacity(score == 0 ? 0.45 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            score = state.baselineScore
        }
    }
}

// MARK: - Screens 7/8: Sleep Window

enum OnbBedtimeKind: Equatable {
    case current
    case target

    var progressStep: Int { 3 }
    var kicker: String {
        self == .current ? "Step three · right now" : "Step three · sleep window"
    }
    var title: String {
        self == .current
            ? "When does sleep\nactually happen?"
            : "What's your preferred\nsleeping schedule?"
    }
    var subcopy: String {
        self == .current
            ? "On an average night right now, when do you actually fall asleep and wake up?"
            : "Your routine will aim you toward this."
    }
    var durationLabel: String {
        self == .current ? "Current window" : "Target window"
    }
    var bedLabel: String {
        self == .current ? "Usually asleep" : "Target asleep"
    }
    var wakeLabel: String {
        self == .current ? "Usually up" : "Target wake"
    }
}

struct OnbBedtimeView: View {
    @Binding var step: Int
    var kind: OnbBedtimeKind
    @Binding var bedtime: Date
    @Binding var wakeTime: Date
    @EnvironmentObject var state: AppState

    private func hourFrac(_ d: Date) -> Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: d) * 60 + c.component(.minute, from: d)) / (24.0 * 60.0)
    }

    private var sleepDurationText: String {
        var dur = hourFrac(wakeTime) - hourFrac(bedtime)
        if dur <= 0 { dur += 1.0 }
        let mins = Int(dur * 24 * 60)
        return "\(mins / 60)h \(mins % 60)m"
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.2, radius: 260, opacity: 0.45)
                .ignoresSafeArea()
            GeometryReader { geo in
                let veryCompact = geo.size.height < 650
                let compact = geo.size.height < 740
                let clockSize: CGFloat = veryCompact ? 170 : (compact ? 220 : 260)
                let titleSize: CGFloat = veryCompact ? 24 : 28
                let durationSize: CGFloat = veryCompact ? 30 : 38
                let textBottom: CGFloat = veryCompact ? 8 : (compact ? 12 : 20)
                let labelTop: CGFloat = veryCompact ? 8 : 20
                let ctaBottom: CGFloat = veryCompact ? 20 : 36

                VStack(spacing: 0) {
                Spacer().frame(height: 16)
                OnbTopBar(step: 3, total: 5, onBack: { step = 1 }, onSkip: {
                    if kind == .target {
                        commitTargetSleepWindow()
                        state.refreshOnboardingClassifications()
                    }
                    step = 3
                })
                StepProgress(step: 3, total: 5)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: kind.kicker)
                    Text(kind.title)
                        .font(.serif(titleSize))
                        .foregroundColor(.lullInk0)
                        .padding(.top, 10)
                    Text(kind.subcopy)
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 10)
                .padding(.bottom, textBottom)

                // Duration
                VStack(spacing: 3) {
                    Text(sleepDurationText)
                        .font(.serif(durationSize))
                        .foregroundColor(.lullInk0)
                    Text(kind.durationLabel)
                        .font(.mono(10))
                        .kerning(1.6)
                        .foregroundColor(.lullInk3)
                }
                .padding(.bottom, veryCompact ? 8 : 16)

                // Arc clock
                SleepArcClock(bedtime: $bedtime, wakeTime: $wakeTime)
                    .frame(width: clockSize, height: clockSize)

                // Bedtime / Wake labels
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.lullAmber)
                        Text(formatted(bedtime))
                            .font(.serif(20))
                            .foregroundColor(.lullInk0)
                        Text(kind.bedLabel)
                            .font(.mono(10))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.lullAmber)
                        Text(formatted(wakeTime))
                            .font(.serif(20))
                            .foregroundColor(.lullInk0)
                        Text(kind.wakeLabel)
                            .font(.mono(10))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                    }
                }
                .padding(.horizontal, 52)
                .padding(.top, labelTop)

                Spacer()

                PrimaryCTA(title: "Continue") {
                    if kind == .current {
                        state.currentBedtime = bedtime
                        state.currentWakeTime = wakeTime
                        state.targetBedtime = bedtime
                        state.targetWakeTime = wakeTime
                        step = 3
                    } else {
                        commitTargetSleepWindow()
                        state.refreshOnboardingClassifications()
                        step = 3
                    }
                }
                    .padding(.horizontal, 20)
                    .padding(.bottom, ctaBottom)
                }
            }
        }
    }

    private func commitTargetSleepWindow() {
        state.targetBedtime = bedtime
        state.targetWakeTime = wakeTime
        state.currentBedtime = bedtime
        state.currentWakeTime = wakeTime
        state.typicalBedtime = bedtime
        state.typicalWakeTime = wakeTime
    }
}

// MARK: - Sleep Arc Clock

struct SleepArcClock: View {
    @Binding var bedtime: Date
    @Binding var wakeTime: Date

    private let clockR: CGFloat  = 100
    private let trackW: CGFloat  = 26
    private let handleR: CGFloat = 15
    private let snapMinutes = 10

    private func hourFrac(_ d: Date) -> Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: d) * 60 + c.component(.minute, from: d)) / (24.0 * 60.0)
    }

    private func ringPt(frac: Double, r: CGFloat, center: CGPoint) -> CGPoint {
        let a = frac * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    private func fracFrom(pos: CGPoint, center: CGPoint) -> Double {
        var a = atan2(pos.y - center.y, pos.x - center.x) + .pi / 2
        if a < 0 { a += 2 * .pi }
        return a / (2 * .pi)
    }

    private func snapDate(frac: Double, ref: Date) -> Date {
        let dayMinutes = 24 * 60
        let rawMins = frac * Double(dayMinutes)
        let mins = (Int((rawMins / Double(snapMinutes)).rounded()) * snapMinutes) % dayMinutes
        return Calendar.current.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: ref) ?? ref
    }

    var body: some View {
        GeometryReader { geo in
            let cx = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let bf = hourFrac(bedtime)
            let wf = hourFrac(wakeTime)
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: trackW)
                    .frame(width: clockR * 2, height: clockR * 2)
                    .position(cx)

                // Sleep arc
                SleepArcShape(startFrac: bf, endFrac: wf)
                    .stroke(
                        LinearGradient(colors: [Color.lullAmber.opacity(0.55), Color.lullAmber.opacity(0.9)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: trackW, lineCap: .round)
                    )
                    .frame(width: clockR * 2, height: clockR * 2)
                    .position(cx)

                // Hour labels
                ForEach(Array(stride(from: 0, to: 24, by: 2)), id: \.self) { h in
                    let frac = Double(h) / 24.0
                    let pos  = ringPt(frac: frac, r: clockR - trackW / 2 - 13, center: cx)
                    let lbl: String = {
                        if h == 0  { return "12a" }
                        if h == 6  { return "6a"  }
                        if h == 12 { return "12p" }
                        if h == 18 { return "6p"  }
                        return "\(h > 12 ? h - 12 : h)"
                    }()
                    Text(lbl)
                        .font(.system(size: h % 6 == 0 ? 9 : 8))
                        .foregroundColor(h % 6 == 0 ? Color.lullInk2 : Color.lullInk3)
                        .position(pos)
                }

                // Bedtime handle (moon)
                let bPos = ringPt(frac: bf, r: clockR, center: cx)
                ZStack {
                    Circle().fill(Color.lullAmber).frame(width: handleR * 2, height: handleR * 2)
                    Image(systemName: "moon.fill").font(.system(size: 10)).foregroundColor(.lullBg)
                }
                .position(bPos)
                .shadow(color: .lullAmberGlow, radius: 8)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("sleepClock"))
                    .onChanged { v in
                        let snapped = snapDate(frac: fracFrom(pos: v.location, center: cx), ref: bedtime)
                        if !Calendar.current.isDate(snapped, equalTo: bedtime, toGranularity: .minute) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        bedtime = snapped
                    })

                // Wake handle (sun)
                let wPos = ringPt(frac: wf, r: clockR, center: cx)
                ZStack {
                    Circle().fill(Color.lullAmber).frame(width: handleR * 2, height: handleR * 2)
                    Image(systemName: "sun.max.fill").font(.system(size: 10)).foregroundColor(.lullBg)
                }
                .position(wPos)
                .shadow(color: .lullAmberGlow, radius: 8)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("sleepClock"))
                    .onChanged { v in
                        let snapped = snapDate(frac: fracFrom(pos: v.location, center: cx), ref: wakeTime)
                        if !Calendar.current.isDate(snapped, equalTo: wakeTime, toGranularity: .minute) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        wakeTime = snapped
                    })
            }
        }
        .coordinateSpace(name: "sleepClock")
    }
}

struct SleepArcShape: Shape {
    var startFrac: Double
    var endFrac: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startFrac, endFrac) }
        set { startFrac = newValue.first; endFrac = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: min(rect.width, rect.height) / 2,
                 startAngle: .degrees(startFrac * 360 - 90),
                 endAngle:   .degrees(endFrac   * 360 - 90),
                 clockwise: false)
        return p
    }
}

// MARK: - Screen 5: Pre-Bed Activities

struct OnbPreBedView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "Use my phone or scroll",
        "Watch TV or screens",
        "Exercise (evening workout)",
        "Eat or have a snack",
        "Drink coffee",
        "Work",
        "Have a nightcap or alcohol",
        "None of the above",
    ]

    private var noneIndex: Int { options.count - 1 }

    var body: some View {
        LullScreen(glow: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 4, total: 4, onBack: { step = 4 }, onSkip: {
                        state.selectedPreBedActivities = []
                        step = 6
                    })
                    StepProgress(step: 4, total: 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Step three · the last 3 hours")
                        Text("What do you do in\nthe last 3 hours\nbefore bed?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("Just the habits that tend to work against sleep — pick any that sound like you.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedPreBedActivities.contains(i),
                                onTap: { togglePreBed(i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Build my routine", disabled: state.selectedPreBedActivities.isEmpty) {
                        step = 6
                    }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    private func togglePreBed(_ index: Int) {
        if index == noneIndex {
            state.selectedPreBedActivities = state.selectedPreBedActivities.contains(index) ? [] : [index]
            return
        }

        state.selectedPreBedActivities.remove(noneIndex)
        toggle(&state.selectedPreBedActivities, index)
    }
}

// MARK: - Screen 5: What You've Tried

struct OnbTriedView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private let options = [
        "Melatonin",
        "Meditation",
        "Light dinner",
        "Journaling",
        "Therapy",
        "CBT-I",
        "Warm bath",
        "None of these",
    ]

    private var noneIndex: Int { options.count - 1 }

    var body: some View {
        LullScreen(glow: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 16)
                    OnbTopBar(step: 6, total: 6, onBack: { step = 8 }, onSkip: {
                        state.selectedTriedThings = []
                        step = 11
                    })

                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Last check · what you've tried")
                        Text("What have you tried\nbefore?")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .padding(.top, 10)
                        Text("This helps us avoid giving you something that already didn't help.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, Lull.horizontalPad)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, text in
                            ChoiceRow(
                                text: text,
                                selected: state.selectedTriedThings.contains(i),
                                onTap: { toggleTried(i) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    PrimaryCTA(title: "Build my routine", disabled: state.selectedTriedThings.isEmpty) {
                        step = 11
                    }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    private func toggleTried(_ index: Int) {
        if index == noneIndex {
            state.selectedTriedThings = state.selectedTriedThings.contains(index) ? [] : [index]
            return
        }

        state.selectedTriedThings.remove(noneIndex)
        toggle(&state.selectedTriedThings, index)
    }
}

// MARK: - Screen 9: Pattern Reveal

struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x += size.width + (x == 0 ? 0 : spacing)
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Screen 11: Methodology

struct OnbMethodologyView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var orbExpanded = false
    @State private var canProceed = false
    @State private var didPlayGeneratedHaptic = false

    private static let bedtimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    private let sleepProblemLabels = [
        0: "Struggling to fall asleep",
        1: "racing mind",
        2: "can’t fall back asleep",
        3: "waking up unrefreshed",
        4: "something else",
    ]

    private let preBedActivityLabels = [
        0: "using your phone or scrolling",
        1: "watching TV or screens",
        2: "exercising in the evening",
        3: "eating or snacking",
        4: "drinking coffee",
        5: "working",
        6: "having a nightcap or alcohol",
    ]

    private var bedtimeText: String {
        Self.bedtimeFormatter.string(from: state.targetBedtime)
    }

    private var flaggedLabels: [String] {
        let problemLabels = state.selectedSleepProblems
            .sorted()
            .compactMap { sleepProblemLabels[$0] }
        let activityLabels = state.selectedPreBedActivities
            .sorted()
            .compactMap { preBedActivityLabels[$0] }
        return problemLabels + activityLabels
    }

    private var flaggedText: String {
        let labels = flaggedLabels
        guard !labels.isEmpty else { return "your sleep pattern." }
        return labels.joined(separator: ", ") + "."
    }

    var body: some View {
        LullScreen(glowX: 0.5, glowY: 0.18, glowRadius: 280, glowOpacity: 0.52) {
            GeometryReader { geo in
                let compact = geo.size.height < 760
                let orbSize: CGFloat = compact ? 136 : 156
                let titleSize: CGFloat = compact ? 25 : 27
                let bodySize: CGFloat = compact ? 13.5 : 14.5

                VStack(spacing: 0) {
                    Spacer().frame(height: compact ? 24 : 40)

                    BrandMark(large: false)

                    Spacer(minLength: compact ? 36 : 70)

                    Circle()
                        .fill(RadialGradient(
                            stops: [
                                .init(color: Color(hex: "#ffc370"), location: 0),
                                .init(color: Color.lullAmberSoft, location: 0.55),
                                .init(color: Color.lullAmberDeep, location: 1),
                            ],
                            center: UnitPoint(x: 0.48, y: 0.34),
                            startRadius: 0,
                            endRadius: orbSize * 0.5
                        ))
                        .frame(width: orbSize, height: orbSize)
                        .overlay(alignment: .topLeading) {
                            Ellipse()
                                .fill(Color.white.opacity(0.46))
                                .frame(width: orbSize * 0.38, height: orbSize * 0.22)
                                .rotationEffect(.degrees(2))
                                .offset(x: orbSize * 0.14, y: orbSize * 0.14)
                                .blur(radius: 0.4)
                        }
                        .shadow(color: .lullAmberGlow, radius: orbExpanded ? 42 : 24)
                        .scaleEffect(orbExpanded ? 1.04 : 0.94)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: orbExpanded)

                    Spacer(minLength: compact ? 58 : 90)

                    VStack(spacing: 14) {
                        Text("Built around your \(bedtimeText)\nbedtime —")
                            .font(.serif(titleSize, weight: .semibold))
                            .foregroundColor(.lullInk0)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: 330)

                        (
                            Text("shaped by what you flagged:\n")
                                .foregroundColor(.lullInk2)
                            + Text(flaggedText)
                                .foregroundColor(.lullAmber)
                        )
                        .font(.system(size: bodySize, weight: .regular))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 306)
                    }
                    .padding(.horizontal, Lull.horizontalPad)

                    Spacer()

                    PrimaryCTA(title: "Show my contract", disabled: !canProceed) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        step = 7
                    }
                    .opacity(canProceed ? 1 : 0.58)
                    .padding(.horizontal, Lull.horizontalPad)

                    Kicker(text: "Informed by CBT-I", color: .lullInk3)
                        .padding(.top, 26)
                        .padding(.bottom, compact ? 24 : 34)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear {
            state.selectedWakes = []
            state.selectedTriedThings = []
            state.currentBedtime = state.targetBedtime
            state.currentWakeTime = state.targetWakeTime
            state.typicalBedtime = state.targetBedtime
            state.typicalWakeTime = state.targetWakeTime
            state.refreshOnboardingClassifications()
            let answers = OnboardingAnswers(from: state)
            state.applyGeneratedRoutine(generateStartingRoutine(from: answers), scheduleNotifications: false)
            let generatedFeedback = UINotificationFeedbackGenerator()
            generatedFeedback.prepare()
            orbExpanded = true
            canProceed = false
            didPlayGeneratedHaptic = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.35)) {
                    canProceed = true
                }
                if !didPlayGeneratedHaptic {
                    generatedFeedback.notificationOccurred(.success)
                    didPlayGeneratedHaptic = true
                }
            }
        }
    }

}

// MARK: - Routine Ready (payoff screen)

struct OnbRoutineReadyView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var didGenerateContractRoutine = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f
    }()

    private var headlineSub: String {
        "If you miss a rule, selected apps lock. Complete it late and the lock cools down for 10 minutes."
    }

    var body: some View {
        routineContent
        .onAppear {
            generateRoutineIfNeeded()
            playRevealHaptic()
        }
    }

    private var routineContent: some View {
        LullScreen(glowX: 0.5, glowY: 0.22, glowRadius: 260, glowOpacity: 0.85) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // Brand
                    HStack { Spacer(); BrandMark(large: true); Spacer() }
                        .padding(.horizontal, 28)

                    // Copy
                    VStack(spacing: 16) {
                        Kicker(
                            text: "Your sleep contract is ready",
                            color: .lullAmberSoft
                        )
                        VStack(spacing: -4) {
                            Text("Choose the rules.")
                                .font(.serif(32))
                                .foregroundColor(.lullInk0)
                            Text("We'll enforce timing.")
                                .font(.serifItalic(36))
                                .foregroundColor(.lullAmber)
                        }
                        Text(headlineSub)
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 280)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 8)

                    // Sleep-contract card
                    let displayRoutine = state.sleepContractPreviewItems
                    VStack(spacing: 0) {
                        ForEach(displayRoutine) { row in
                            HStack(spacing: 14) {
                                Text(OnbRoutineReadyView.timeFmt.string(from: row.dueAt))
                                    .font(.mono(11))
                                    .kerning(0.6)
                                    .foregroundColor(.lullInk3)
                                    .frame(width: 50, alignment: .leading)
                                Ember(size: 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.rule.title)
                                        .font(.system(size: 14))
                                        .foregroundColor(.lullInk1)
                                    Text("Grace: \(row.rule.graceMinutes)m")
                                        .font(.mono(9))
                                        .foregroundColor(.lullInk4)
                                }
                                Spacer()
                                Text("RULE")
                                    .font(.mono(9))
                                    .kerning(0.4)
                                    .foregroundColor(.lullInk4)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 12)
                            Divider().background(Color.lullLine)
                        }
                        HStack(spacing: 14) {
                            Text(OnbRoutineReadyView.timeFmt.string(from: state.typicalBedtime))
                                .font(.mono(11))
                                .kerning(0.6)
                                .foregroundColor(.lullInk3)
                                .frame(width: 50, alignment: .leading)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.lullAmber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scroll apps locked")
                                    .font(.system(size: 14))
                                    .foregroundColor(.lullInk1)
                                Text("Until \(OnbRoutineReadyView.timeFmt.string(from: state.typicalWakeTime))")
                                    .font(.mono(9))
                                    .foregroundColor(.lullInk4)
                            }
                            Spacer()
                            Text("LOCK")
                                .font(.mono(9))
                                .kerning(0.4)
                                .foregroundColor(.lullInk4)
                        }
                        .padding(.vertical, 12)
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.05), Color.white.opacity(0.015)],
                                startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.lullLineStrong, lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    VStack(spacing: 0) {
                        PrimaryCTA(
                            title: "See how app pausing works"
                        ) {
                            step = 4
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private func playRevealHaptic() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            feedback.impactOccurred(intensity: 0.65)
        }
    }

    private func generateRoutineIfNeeded() {
        guard !didGenerateContractRoutine else { return }
        didGenerateContractRoutine = true
        state.currentBedtime = state.targetBedtime
        state.currentWakeTime = state.targetWakeTime
        state.typicalBedtime = state.targetBedtime
        state.typicalWakeTime = state.targetWakeTime
        state.refreshOnboardingClassifications()
        let answers = OnboardingAnswers(from: state)
        state.applyGeneratedRoutine(generateStartingRoutine(from: answers), scheduleNotifications: false)
    }
}

// MARK: - App Blocking How It Works

struct OnbAppBlockingHowItWorksView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var previewItems: [SleepContractItem] {
        Array(state.sleepContractPreviewItems.prefix(2))
    }

    private var firstRuleTitle: String {
        previewItems.first?.rule.title ?? "Dim the lights"
    }

    private var secondRuleTitle: String {
        if previewItems.count > 1 {
            return previewItems[1].rule.title
        }
        return "Put the phone down"
    }

    private var firstRuleTime: String {
        guard let dueAt = previewItems.first?.dueAt else { return "9:45 PM" }
        return Self.timeFmt.string(from: dueAt)
    }

    private var secondRuleTime: String {
        guard previewItems.count > 1 else { return "10:10 PM" }
        return Self.timeFmt.string(from: previewItems[1].dueAt)
    }

    private var sleepWindowText: String {
        "\(Self.timeFmt.string(from: state.typicalBedtime)) - \(Self.timeFmt.string(from: state.typicalWakeTime))"
    }

    var body: some View {
        LullScreen(glow: true, glowX: 0.52, glowY: 0.12, glowRadius: 300, glowOpacity: 0.62) {
            GeometryReader { geo in
                let compact = geo.size.height < 740

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 14 : 18) {
                            Spacer().frame(height: compact ? 18 : 30)
                            BrandMark(large: false)

                            VStack(spacing: 12) {
                                Kicker(text: "How app pausing works", color: .lullAmberSoft)

                                VStack(spacing: compact ? -8 : -10) {
                                    Text("A boundary")
                                        .font(.serif(compact ? 32 : 36, weight: .semibold))
                                        .foregroundColor(.lullInk0)
                                    Text("you can see coming.")
                                        .font(.serifItalic(compact ? 34 : 38))
                                        .foregroundColor(.lullAmber)
                                }
                                .multilineTextAlignment(.center)

                                Text("Before iOS asks for Screen Time access, here is the exact flow for tonight.")
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 318)
                            }
                            .padding(.top, compact ? 10 : 18)

                            VStack(spacing: 0) {
                                OnbAppPauseTimelineRow(
                                    marker: "NOW",
                                    icon: "checkmark.circle.fill",
                                    title: "Choose your plan",
                                    detail: "Pick 1-3 sleep habits and the apps to pause if you miss them."
                                )

                                OnbAppPauseTimelineRow(
                                    marker: firstRuleTime,
                                    icon: "hand.raised.fill",
                                    title: firstRuleTitle,
                                    detail: "When the reminder appears, long press to confirm. Your apps stay available."
                                )

                                OnbAppPauseTimelineRow(
                                    marker: secondRuleTime,
                                    icon: "lock.fill",
                                    title: secondRuleTitle,
                                    detail: "You get 10 minutes to confirm. After that, chosen apps pause. Confirm late and they unlock after 10 minutes."
                                )

                                OnbAppPauseTimelineRow(
                                    marker: "IF MISSED",
                                    icon: "clock.fill",
                                    title: "Habit missed",
                                    detail: "Apps unlock after 10 minutes, then pause again 10 minutes before your sleep window."
                                )

                                OnbAppPauseTimelineRow(
                                    marker: sleepWindowText,
                                    icon: "moon.fill",
                                    title: "Sleep window",
                                    detail: "Chosen apps pause until wake time to protect your sleep.",
                                    isLast: true
                                )
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
                            )
                            .padding(.horizontal, Lull.horizontalPad)

                            Text("TenThirty itself stays available so you can come back and confirm a late habit.")
                                .font(.mono(11))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 318)

                            Spacer().frame(height: 116)
                        }
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PrimaryCTA(title: "Choose apps to pause") {
                step = 5
            }

            GhostButton(title: "Back") {
                step = 3
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct OnbAppPauseTimelineRow: View {
    var marker: String
    var icon: String
    var title: String
    var detail: String
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.lullAmber.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.lullAmber)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.lullAmber.opacity(0.18))
                        .frame(width: 1, height: 34)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(marker.uppercased())
                    .font(.mono(9.5))
                    .kerning(1.0)
                    .foregroundColor(.lullInk4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.lullInk1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.system(size: 12.8))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 14)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - App Blocking Commitment

struct OnbAppBlockingCommitmentView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @ObservedObject private var probe = AppBlockingAccessProbe.shared
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var isSaving = false

    private var appCount: Int { selection.applicationTokens.count }
    private var categoryCount: Int { selection.categoryTokens.count }
    private var selectedCount: Int { appCount + categoryCount }
    private var hasSelection: Bool { selectedCount > 0 }
    private var nextStep: Int { 6 }

    var body: some View {
        LullScreen(glow: true, glowX: 0.48, glowY: 0.16, glowRadius: 290, glowOpacity: 0.64) {
            GeometryReader { geo in
                let compact = geo.size.height < 740

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 14 : 18) {
                            Spacer().frame(height: compact ? 18 : 30)
                            BrandMark(large: false)

                            VStack(spacing: 12) {
                                Kicker(text: "Your sleep window", color: .lullAmberSoft)

                                (Text("Which apps\nshould pause\n")
                                    .foregroundColor(.lullInk0)
                                 + Text("tonight?")
                                    .font(.serifItalic(compact ? 34 : 38))
                                    .foregroundColor(.lullAmber))
                                    .font(.serif(compact ? 32 : 36, weight: .semibold))
                                    .multilineTextAlignment(.center)

                                Text("Choose the apps that tend to pull you past bedtime. TenThirty pauses them after missed grace windows and during your sleep window.")
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 318)
                            }
                            .padding(.top, compact ? 10 : 18)

                            accessCard
                                .padding(.horizontal, Lull.horizontalPad)

                            appPickerCard
                                .padding(.horizontal, Lull.horizontalPad)

                            Spacer().frame(height: hasSelection && probe.isApproved ? 128 : 92)
                        }
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar
                }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onAppear {
            selection = state.appBlockingSelection
            probe.refresh()
        }
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: probe.isApproved ? 0 : 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("STEP 1 · SCREEN TIME ACCESS")
                    .font(.mono(10))
                    .kerning(1.3)
                    .foregroundColor(.lullInk3)
                Spacer()
                Text(probe.isApproved ? "ACCESS APPROVED" : probe.statusText.uppercased())
                    .font(.mono(9.5))
                    .kerning(1)
                    .foregroundColor(probe.isApproved ? Color(hex: "#8fce93") : .lullAmber)
            }

            if !probe.isApproved {
                Text(probe.detailText)
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    state.trackHardAppBlockingPermissionRequested()
                    Task {
                        await probe.requestAccess()
                        state.trackHardAppBlockingPermissionResult(
                            granted: probe.isApproved,
                            source: "onboarding",
                            hasError: probe.statusText == "Request failed"
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        if probe.isChecking {
                            ProgressView()
                                .tint(.lullBgDeep)
                        } else {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Check access")
                            .font(.system(size: 14.5, weight: .semibold))
                    }
                    .foregroundColor(.lullBgDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.lullAmber))
                    .shadow(color: .lullAmberGlow, radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(probe.isChecking)
                .opacity(probe.isChecking ? 0.75 : 1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(probe.isApproved ? Color(hex: "#8fce93").opacity(0.25) : Color.lullAmber.opacity(0.16), lineWidth: 1)
        )
    }

    private var appPickerCard: some View {
        Button {
            guard probe.isApproved else { return }
            showPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("STEP 2 · CHOOSE APPS TO PAUSE")
                        .font(.mono(10))
                        .kerning(1.3)
                        .foregroundColor(probe.isApproved ? .lullInk1 : .lullInk3)
                    if selectedCount > 0 {
                        Text("· \(selectedCount) SELECTED")
                            .font(.mono(10))
                            .kerning(1.0)
                            .foregroundColor(.lullAmber)
                    }
                    Spacer()
                    Image(systemName: probe.isApproved ? "chevron.right" : "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(probe.isApproved ? .lullAmber : .lullInk4)
                }

                HStack(spacing: 10) {
                    ForEach(selectionSlots, id: \.self) { slot in
                        OnbBlockingSelectionSlot(kind: slot)
                    }
                }

                if selectedCount > 0 {
                    Text(selectionSummary)
                        .font(.system(size: 12.5))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(probe.isApproved ? Color.white.opacity(0.04) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        probe.isApproved ? Color.lullAmber.opacity(0.16) : Color.lullLineStrong,
                        style: StrokeStyle(lineWidth: 1, dash: probe.isApproved ? [] : [5, 5])
                    )
            )
            .opacity(probe.isApproved ? 1 : 0.52)
        }
        .buttonStyle(.plain)
        .disabled(!probe.isApproved)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if probe.isApproved && hasSelection {
                PrimaryCTA(title: isSaving ? "Saving..." : "Finish setup", disabled: isSaving) {
                    guard !isSaving else { return }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    isSaving = true
                    state.configureAppBlocking(
                        selection: selection,
                        enabled: true,
                        startTime: state.typicalBedtime,
                        endTime: state.typicalWakeTime,
                        graceMinutes: state.appBlockingGraceMinutes
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                        step = nextStep
                    }
                }
            }

            GhostButton(title: "Not now") {
                state.trackAppBlockingSkipped(context: "onboarding")
                step = nextStep
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var selectionSlots: [OnbBlockingSelectionSlot.Kind] {
        var slots: [OnbBlockingSelectionSlot.Kind] = []
        let tokenCount = min(selectedCount, 3)
        for index in 0..<tokenCount {
            slots.append(index < appCount ? .app : .category)
        }
        while slots.count < 3 {
            slots.append(.empty)
        }
        return slots
    }

    private var selectionSummary: String {
        var parts: [String] = []
        if appCount > 0 {
            parts.append("\(appCount) \(appCount == 1 ? "app" : "apps")")
        }
        if categoryCount > 0 {
            parts.append("\(categoryCount) \(categoryCount == 1 ? "category" : "categories")")
        }
        return parts.joined(separator: " · ")
    }
}

private struct OnbBlockingTimeTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.mono(10))
                .kerning(1.2)
                .foregroundColor(.lullInk4)
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.lullInk1)
                .minimumScaleFactor(0.82)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.lullLineStrong, lineWidth: 1)
        )
    }
}

private struct OnbBlockingSelectionSlot: View {
    enum Kind: Hashable {
        case app
        case category
        case empty
    }

    var kind: Kind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(border, style: StrokeStyle(lineWidth: 1, dash: kind == .empty ? [5, 5] : []))
                )
                .frame(width: 50, height: 50)

            Image(systemName: icon)
                .font(.system(size: kind == .empty ? 17 : 16, weight: .semibold))
                .foregroundColor(iconColor)
        }
    }

    private var icon: String {
        switch kind {
        case .app: return "app.fill"
        case .category: return "square.grid.2x2.fill"
        case .empty: return "plus"
        }
    }

    private var background: Color {
        kind == .empty ? Color.clear : Color.lullAmber.opacity(0.10)
    }

    private var border: Color {
        kind == .empty ? Color.lullLineStrong : Color.lullAmber.opacity(0.30)
    }

    private var iconColor: Color {
        kind == .empty ? .lullInk4 : .lullAmber
    }
}

// MARK: - Commitment

struct OnbCommitmentView: View {
    @Binding var step: Int
    @EnvironmentObject var state: AppState
    @State private var isConfirming = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var reminderTime: Date { state.firstBedtimePrepDueTime }

    private var timeString: String { OnbCommitmentView.timeFmt.string(from: reminderTime) }

    private var nextStep: Int {
        9
    }

    var body: some View {
        LullScreen(glow: true, glowX: 0.48, glowY: 0.16, glowRadius: 290, glowOpacity: 0.64) {
            GeometryReader { geo in
                let compact = geo.size.height < 740

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 18 : 22) {
                            Spacer().frame(height: compact ? 20 : 34)
                            BrandMark(large: false)

                            VStack(spacing: 12) {
                                Kicker(text: "Tonight's commitment", color: .lullAmberSoft)

                                VStack(spacing: compact ? -11 : -13) {
                                    Text("We'll send you")
                                        .font(.serif(compact ? 32 : 36, weight: .semibold))
                                        .foregroundColor(.lullInk0)
                                    Text("a reminder")
                                        .font(.serifItalic(compact ? 38 : 42))
                                        .foregroundColor(.lullAmber)
                                }
                                .multilineTextAlignment(.center)

                                Text("Then the app will walk you through your ritual.")
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 310)
                            }
                            .padding(.top, compact ? 12 : 22)

                            VStack(spacing: 20) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.lullAmber)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(Color.lullAmber.opacity(0.12)))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("First bedtime prep")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.lullInk1)
                                        Text(timeString)
                                            .font(.mono(12))
                                            .kerning(0.7)
                                            .foregroundColor(.lullInk3)
                                    }

                                    Spacer()

                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.lullInk4)
                                }

                                Text(timeString.lowercased())
                                    .font(.serifItalic(compact ? 54 : 64))
                                    .foregroundColor(.lullAmber)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .minimumScaleFactor(0.86)
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.lullAmberSoft)
                                    Text("Locked to your first bedtime prep step")
                                        .font(.mono(10))
                                        .kerning(0.7)
                                        .foregroundColor(.lullInk3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(22)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
                            )
                            .padding(.horizontal, Lull.horizontalPad)

                            Text("No streak pressure. No daily nagging. Just a specific time so tonight's plan has a place to land.")
                                .font(.mono(11))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 310)

                            if isConfirming {
                                confirmation
                            }

                            Spacer().frame(height: 122)
                        }
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar
                }
            }
        }
    }

    private var confirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.lullAmber)
            Text("Time saved for \(timeString)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.lullInk1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.lullAmber.opacity(0.11)))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PrimaryCTA(title: isConfirming ? "Saving..." : "Yes, remind me", disabled: isConfirming) {
                guard !isConfirming else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isConfirming = true
                state.commitRoutineReminder(at: reminderTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    step = nextStep
                }
            }

            GhostButton(title: "Not now") {
                step = nextStep
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Trial Paywall

struct OnbTrialPaywallView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var isStartingTrial = false
    @State private var statusMessage: String?
    @State private var didPresentOfferCodeSheet = false
    @State private var didTrackPaywallView = false

    var body: some View {
        LullScreen(glow: true, glowX: 0.5, glowY: 0.04, glowRadius: 320, glowOpacity: 0.62) {
            GeometryReader { geo in
                let compact = geo.size.height < 760
                let bottomInset = max(geo.safeAreaInsets.bottom, 12)

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 18 : 22) {
                            Spacer().frame(height: compact ? 18 : 28)
                            BrandMark(large: false)
                                .padding(.bottom, compact ? 4 : 8)

                            trialHero(compact: compact)
                            TrialQuoteCard()
                            trialBenefits(compact: compact)
                            TrialReassuranceCard()

                            Text("Free for seven nights, then $49.99/year. Cancel anytime in Apple subscriptions.")
                                .font(.system(size: 13))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(.lullAmberSoft)
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            Spacer().frame(height: compact ? 116 : 128)
                        }
                        .padding(.horizontal, Lull.horizontalPad)
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar(bottomInset: bottomInset)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, didPresentOfferCodeSheet else { return }
            Task { await refreshAfterOfferCodeRedemption() }
        }
        .onAppear {
            guard !didTrackPaywallView else { return }
            didTrackPaywallView = true
            state.trackPaywallViewed(context: "onboarding")
        }
    }

    private func trialHero(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            Kicker(text: "Your first week", color: .lullAmberSoft)

            VStack(spacing: compact ? -15 : -17) {
                Text("Seven nights without")
                    .font(.serif(compact ? 38 : 44, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text("the 1 a.m. scroll")
                    .font(.serifItalic(compact ? 44 : 50))
                    .foregroundColor(.lullAmber)
                    .minimumScaleFactor(0.78)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Text("TenThirty protects your sleep window and blocks the apps you choose—even when late-night you wants five more minutes.")
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk2)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
    }

    private func trialBenefits(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 12) {
            TrialBenefit(
                title: "Get to bed when you planned",
                detail: "Keep chosen distractions out of reach during your sleep window"
            )
            TrialBenefit(
                title: "Follow through before bedtime",
                detail: "Timely reminders help you keep the habits that support tonight's sleep"
            )
            TrialBenefit(
                title: "Turn a missed habit into a reset",
                detail: "Complete it late, take a short cooldown, and get your evening back"
            )
            TrialBenefit(
                title: "Wake up without scroll regret",
                detail: "Protect tomorrow from another night lost to “just five more minutes”"
            )
            TrialBenefit(
                title: "Build proof you can trust yourself",
                detail: "See each kept commitment become progress you can carry into the next night"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
        )
    }

    private func bottomBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            TrialCTA(
                title: isStartingTrial ? "Starting..." : "Protect my first night",
                subtitle: "Then $49.99/year. Cancel anytime.",
                disabled: isStartingTrial || subscriptions.isLoading
            ) {
                guard !isStartingTrial && !subscriptions.isLoading else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                state.trackPaywallPrimaryTapped(product: .yearly)
                Task { await purchase(.yearly) }
            }

            Button {
                guard !isStartingTrial && !subscriptions.isLoading else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                state.trackPaywallPrimaryTapped(product: .monthly)
                Task { await purchase(.monthly) }
            } label: {
                Text("I'll skip the trial and go with $6.99/month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .underline()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isStartingTrial || subscriptions.isLoading)
            .opacity(isStartingTrial || subscriptions.isLoading ? 0.55 : 1)

            Button {
                guard !isStartingTrial && !subscriptions.isLoading else { return }
                redeemOfferCode()
            } label: {
                Text("Have a coupon code? Redeem it")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lullAmberSoft)
                    .underline()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isStartingTrial || subscriptions.isLoading)
            .opacity(isStartingTrial || subscriptions.isLoading ? 0.55 : 1)

            HStack(spacing: 26) {
                footerButton("Terms") {
                    open(TenThirtyLegalLinks.terms)
                }
                footerButton("Privacy") {
                    open(TenThirtyLegalLinks.privacy)
                }
                footerButton(subscriptions.isLoading ? "Restoring" : "Restore") {
                    Task { await restore() }
                }
            }
        }
        .padding(.horizontal, Lull.horizontalPad)
        .padding(.top, 22)
        .padding(.bottom, bottomInset + 6)
        .background(
            LinearGradient(
                colors: [Color.lullBg.opacity(0.0), Color.lullBg.opacity(0.96), Color.lullBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mono(10))
                .kerning(0.8)
                .foregroundColor(.lullInk3)
        }
        .buttonStyle(.plain)
        .disabled(title == "Restoring")
    }

    private func open(_ url: URL) {
        openURL(url)
    }

    private func redeemOfferCode() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        statusMessage = "Enter your code in Apple's sheet. We'll unlock TenThirty once Apple confirms it."
        didPresentOfferCodeSheet = true
        SKPaymentQueue.default().presentCodeRedemptionSheet()

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await refreshAfterOfferCodeRedemption()
        }
    }

    @MainActor
    private func refreshAfterOfferCodeRedemption() async {
        await subscriptions.refreshCustomerInfo()
        if subscriptions.isLullProActive {
            state.applyRevenueCatEntitlement(isActive: true)
            state.completeOnboarding()
        } else if didPresentOfferCodeSheet {
            statusMessage = "If Apple accepted your code, it may take a moment to appear. Tap Restore if TenThirty does not unlock."
        }
    }

    @MainActor
    private func purchase(_ product: LullStoreProduct) async {
        isStartingTrial = true
        statusMessage = nil
        defer { isStartingTrial = false }

        do {
            if subscriptions.currentOffering == nil {
                await subscriptions.refreshOfferings()
            }

            state.trackPurchaseStarted(product: product)
            try await subscriptions.purchase(product)
            await subscriptions.refreshCustomerInfo()

            guard subscriptions.isLullProActive else {
                statusMessage = "We could not confirm the purchase yet. Please try again, or restore if Apple already approved it."
                return
            }

            state.applyRevenueCatEntitlement(isActive: true)
            state.trackPurchaseSucceeded(product: product, isTrial: subscriptions.isInTrial)
            state.completeOnboarding()
        } catch {
            if error.localizedDescription.localizedCaseInsensitiveContains("cancel") {
                state.trackPurchaseCancelled(product: product)
            } else {
                state.trackPurchaseFailed(product: product, error: error)
            }
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func restore() async {
        statusMessage = nil
        state.trackRestoreStarted(context: "onboarding_paywall")
        await subscriptions.restorePurchases()
        if subscriptions.isLullProActive {
            state.trackRestoreSucceeded(
                context: "onboarding_paywall",
                isTrial: subscriptions.isInTrial,
                productIdentifier: subscriptions.activeProductIdentifier
            )
            state.applyRevenueCatEntitlement(isActive: true)
            state.completeOnboarding()
        } else {
            state.trackRestoreFailed(
                context: "onboarding_paywall",
                errorMessage: subscriptions.lastErrorMessage
            )
            statusMessage = subscriptions.lastErrorMessage ?? "No active TenThirty Premium purchase was found."
        }
    }
}

private struct TrialBenefit: View {
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.lullAmber.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.lullAmber)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrialQuoteCard: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("★★★★★")
                .font(.system(size: 12, weight: .semibold))
                .kerning(1.2)
                .foregroundColor(.lullAmber)
                .lineLimit(1)
                .layoutPriority(1)

            Text("\"It's been great for me\"")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.lullInk0)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Text("- Beth M.")
                .font(.system(size: 12))
                .foregroundColor(.lullInk3)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Color.white.opacity(0.045)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct TrialReassuranceCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.lullAmber.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.lullAmber)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Official App Store trial.")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.lullInk0)
                Text("Apple handles payment details securely. You can cancel anytime in your App Store subscriptions.")
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.lullAmber.opacity(0.09), Color.white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct TrialCTA: View {
    var title: String
    var subtitle: String
    var disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.lullBgDeep)
                Text(subtitle)
                    .font(.mono(9.5))
                    .kerning(0.8)
                    .foregroundColor(.lullBgDeep.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(Color.lullAmber))
            .shadow(color: Color.lullAmberGlow, radius: 16)
            .shadow(color: Color.black.opacity(0.4), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
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

// MARK: - Helpers

private func toggle(_ set: inout Set<Int>, _ value: Int) {
    if set.contains(value) { set.remove(value) } else { set.insert(value) }
}
