import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @EnvironmentObject private var sleepSoundsAudio: SleepSoundsAudioStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showWelcome = true
    @State private var logoOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var welcomeBrandDotFrame: CGRect?
    @State private var welcomeCTAFrame: CGRect?
    @State private var welcomeFireflyExiting = false
    @State private var welcomeFireflySequenceActive = true
    @State private var welcomeFireflyDotVisible = false
    @State private var welcomeFireflyDotDrifting = false

    private var usesOnboardingFireflyCompanion: Bool {
        !state.hasCompletedOnboarding && state.isOnboardingFireflyCompanionActive
    }

    var body: some View {
        Group {
            if showWelcome && !state.hasCompletedOnboarding {
                welcomeScreen
            } else {
                mainContent
                    .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            if state.hasCompletedOnboarding {
                showWelcome = false
                return
            }
            if state.requestedTab != nil {
                showWelcome = false
            }
        }
        .onChange(of: state.hasCompletedOnboarding) { _, completed in
            if completed {
                showWelcome = false
            }
        }
        .onChange(of: state.requestedTab) { _, requested in
            if requested != nil {
                showWelcome = false
            }
        }
        .task {
            #if DEBUG
            state.applyUITestLaunchArgumentsIfNeeded()
            #endif
        }
    }

    private var welcomeScreen: some View {
        ZStack {
            if usesOnboardingFireflyCompanion {
                TodayMeadowBackdrop()
                    .ignoresSafeArea()
            } else {
                Color(hex: "#0c0807").ignoresSafeArea()
            }
            AmberGlow(x: 0.5, y: 0.4, radius: 260, opacity: 0.4)
                .ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        BrandMark()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 44)

                        Text("The night belongs to sleep again")
                            .font(.serif(28))
                            .foregroundColor(.lullInk0)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: min(280, geo.size.width - 52))
                            .padding(.bottom, 18)

                        Text("One-minute setup. Pick your rules. Then we hold you to them.")
                            .font(.system(size: 14.5))
                            .foregroundColor(.lullInk3)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .frame(maxWidth: min(236, geo.size.width - 64))
                    }
                    .opacity(logoOpacity)

                    Spacer()

                    Button {
                        if usesOnboardingFireflyCompanion {
                            withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.7)) {
                                welcomeFireflyExiting = true
                            }
                            withAnimation(.easeInOut(duration: 0.28)) { showWelcome = false }
                        } else {
                            withAnimation(.easeInOut(duration: 0.4)) { showWelcome = false }
                        }
                    } label: {
                        Text("Help me sleep")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#1a0d06"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.lullAmber)
                            )
                            .shadow(color: .lullAmberGlow, radius: 10)
                    }
                    .buttonStyle(.plain)
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: FireflyCTAFramePreferenceKey.self,
                                value: proxy.frame(in: .global)
                            )
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 56)
                    .opacity(buttonOpacity)
                }
            }
            .zIndex(2)

            if usesOnboardingFireflyCompanion {
                GeometryReader { geo in
                    TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0, paused: reduceMotion)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let mascotHeight: CGFloat = 219
                        let buttonTop = welcomeCTAFrame?.minY ?? (geo.size.height - 108)
                        let videoY = max(geo.size.height * 0.52, buttonTop + 4 - mascotHeight / 2)
                        let handoffX: CGFloat = -1
                        let handoffY: CGFloat = 0
                        let driftX = reduceMotion || !welcomeFireflyDotDrifting ? 0 : sin(time * 0.72) * 18 + sin(time * 1.31) * 7
                        let driftY = reduceMotion || !welcomeFireflyDotDrifting ? 0 : cos(time * 0.64) * 10 + sin(time * 1.08) * 5
                        let dotY = videoY

                        ZStack {
                            if !reduceMotion {
                                FireflyMascotView(phase: 1, reduceMotion: reduceMotion, playbackSpeed: 2)
                                    .opacity(welcomeFireflySequenceActive ? 1 : 0)
                                    .position(x: geo.size.width * 0.5, y: videoY)
                            }

                            FireflyDot(index: 0, reduceMotion: reduceMotion, drifts: !reduceMotion)
                                .scaleEffect(0.72)
                                .position(
                                    x: geo.size.width * 0.5 + handoffX + (welcomeFireflyDotVisible ? driftX : 0),
                                    y: dotY + handoffY + (welcomeFireflyDotVisible ? driftY : 0)
                                )
                                .opacity(welcomeFireflyDotVisible || reduceMotion ? 1 : 0)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                        .opacity(welcomeFireflyExiting ? 0 : 1)
                        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.42), value: welcomeFireflySequenceActive)
                        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.45), value: welcomeFireflyDotVisible)
                        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.55), value: welcomeFireflyDotDrifting)
                        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.7), value: welcomeFireflyExiting)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(1)
            }
        }
        .environment(\.lullUsesMeadowBackground, usesOnboardingFireflyCompanion)
        .environment(\.lullHidesBrandDot, usesOnboardingFireflyCompanion)
        .onAppear {
            welcomeFireflyExiting = false
            welcomeFireflySequenceActive = true
            welcomeFireflyDotVisible = reduceMotion
            welcomeFireflyDotDrifting = reduceMotion
            withAnimation(.easeIn(duration: 0.6)) { logoOpacity = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(0.5)) { buttonOpacity = 1 }
            guard usesOnboardingFireflyCompanion, !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.45) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    welcomeFireflyDotVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.92) {
                withAnimation(.easeInOut(duration: 0.42)) {
                    welcomeFireflySequenceActive = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.08) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    welcomeFireflyDotDrifting = true
                }
            }
        }
        .onPreferenceChange(BrandDotFramePreferenceKey.self) { frame in
            welcomeBrandDotFrame = frame
        }
        .onPreferenceChange(FireflyCTAFramePreferenceKey.self) { frame in
            welcomeCTAFrame = frame
        }
    }

    private struct WelcomeFireflyIntro: View {
        let brandDotFrame: CGRect?
        let ctaFrame: CGRect?
        let exiting: Bool
        let reduceMotion: Bool
        @State private var phase = 0
        @State private var visible = false

        var body: some View {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0, paused: reduceMotion)) { timeline in
                    let point = position(in: geo, time: timeline.date.timeIntervalSinceReferenceDate)
                    fireflyView
                        .scaleEffect(scale)
                        .opacity(visible ? opacity : 0)
                        .position(point)
                        .animation(reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: phase == 2 ? 2.4 : 1.15), value: phase)
                        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.7), value: exiting)
                        .animation(.easeInOut(duration: 0.28), value: visible)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                guard !visible else { return }
                if reduceMotion {
                    phase = 2
                    visible = true
                    return
                }
                phase = 0
                visible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    phase = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 9.6) {
                    phase = 2
                }
            }
        }

        @ViewBuilder
        private var fireflyView: some View {
            if phase < 2, !reduceMotion {
                FireflyMascotView(phase: phase, reduceMotion: reduceMotion)
            } else {
                FireflyDot(index: 0, reduceMotion: reduceMotion, drifts: !reduceMotion)
            }
        }

        private var scale: CGFloat {
            if exiting { return 0.68 }
            switch phase {
            case 0: return 1
            case 1: return 1
            default: return 0.72
            }
        }

        private var opacity: Double {
            exiting ? 0.0 : 1.0
        }

        private func position(in geo: GeometryProxy, time: TimeInterval) -> CGPoint {
            if exiting, let ctaFrame {
                return CGPoint(x: ctaFrame.maxX + 86, y: ctaFrame.midY - 8)
            }

            switch phase {
            case 0:
                return CGPoint(x: geo.size.width * 0.50, y: geo.size.height * 0.72)
            case 1:
                return CGPoint(x: geo.size.width * 0.50, y: geo.size.height * 0.72)
            default:
                if let brandDotFrame {
                    return CGPoint(x: brandDotFrame.midX, y: brandDotFrame.midY)
                }
                return CGPoint(x: geo.size.width * 0.16, y: geo.safeAreaInsets.top + 255)
            }
        }

        private func ctaHoverPosition(ctaFrame: CGRect, geo: GeometryProxy, time: TimeInterval) -> CGPoint {
            let horizontalRadius = min(max(ctaFrame.width * 0.36, 92), 156)
            let verticalRadius = min(max(ctaFrame.height * 0.68, 40), 58)
            let baseX = ctaFrame.midX
            let baseY = ctaFrame.minY - 18
            return CGPoint(
                x: min(geo.size.width - 42, max(42, baseX + CGFloat(sin(time * 0.36)) * horizontalRadius)),
                y: min(geo.size.height - geo.safeAreaInsets.bottom - 92, max(geo.safeAreaInsets.top + 72, baseY + CGFloat(cos(time * 0.31)) * verticalRadius))
            )
        }
    }

    private var mainContent: some View {
        Group {
            if state.hasCompletedOnboarding {
                postOnboardingContent
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var postOnboardingContent: some View {
        if !subscriptions.hasResolvedInitialCustomerInfo {
            subscriptionLoadingView
        } else if subscriptions.isLullProActive || state.hasPremiumAccess {
            subscribedAppContent
        } else {
            TrialExpiredPaywallView()
                .onAppear {
                    state.handleSubscriptionLapsed()
                }
        }
    }

    private var subscriptionLoadingView: some View {
        ZStack {
            Color.lullBgDeep.ignoresSafeArea()
            ProgressView()
                .tint(.lullAmber)
        }
    }

    private var subscribedAppContent: some View {
        HomeTabView(initialTab: state.initialTab)
            .fullScreenCover(isPresented: $state.showSleepSounds) {
                if state.canUseSleepSounds {
                    SleepSoundsStep(mode: .standalone)
                        .environmentObject(sleepSoundsAudio)
                } else {
                    Color.clear
                        .onAppear {
                            state.showSleepSounds = false
                            state.presentUpgradePaywall()
                        }
                }
            }
            .sheet(isPresented: $state.showMorningCheckIn) { MorningCheckInView() }
            .fullScreenCover(item: $state.activeStreakMilestone) { milestone in
                StreakMilestoneView(milestone: milestone) {
                    state.acknowledgeStreakMilestone()
                }
            }
            .fullScreenCover(item: $state.activePaywallRoute) { route in
                NightFivePaywallFlow(route: route)
            }
            .sheet(item: $state.activeRevenueCatPaywall, onDismiss: {
                state.handleRevenueCatPaywallDismissed(isSubscribed: subscriptions.isLullProActive)
            }) { context in
                RevenueCatPaywallSheet(context: context) {
                    state.applyRevenueCatEntitlement(isActive: true)
                    state.handleRevenueCatPaywallDismissed(isSubscribed: true)
                } onClose: {
                    state.handleRevenueCatPaywallDismissed(isSubscribed: subscriptions.isLullProActive)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if state.shouldPresentDay14Prompt {
                    state.activePaywallRoute = .day14
                }
                state.evaluateTrialStatus()
                state.presentPendingStreakMilestoneIfEligible()
            }
    }
}
