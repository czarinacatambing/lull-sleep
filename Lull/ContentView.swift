import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @State private var showWelcome = true
    @State private var logoOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        Group {
            if showWelcome {
                welcomeScreen
            } else {
                mainContent
                    .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            if state.requestedTab != nil || state.showMidSleepMode {
                showWelcome = false
            }
        }
        .onChange(of: state.requestedTab) { _, requested in
            if requested != nil {
                showWelcome = false
            }
        }
        .onChange(of: state.showMidSleepMode) { _, active in
            if active {
                showWelcome = false
            }
        }
    }

    private var welcomeScreen: some View {
        ZStack {
            Color(hex: "#0c0807").ignoresSafeArea()
            AmberGlow(x: 0.5, y: 0.4, radius: 260, opacity: 0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                BrandMark(large: true)
                    .scaleEffect(3.2)
                    .opacity(logoOpacity)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { showWelcome = false }
                } label: {
                    Text("Help me sleep")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#1a0d06"))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.lullAmber))
                        .shadow(color: .lullAmberGlow, radius: 10)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 56)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) { logoOpacity = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(0.5)) { buttonOpacity = 1 }
        }
    }

    private var mainContent: some View {
        Group {
            if state.hasCompletedOnboarding {
                HomeTabView(initialTab: state.initialTab)
                    .fullScreenCover(isPresented: $state.showSleepSounds) {
                        if state.canUseSleepSounds {
                            SleepSoundsStep(mode: .standalone)
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
                    .fullScreenCover(item: $state.pendingPromotion) { promotion in
                        RoutinePromotedView(promotion: promotion) {
                            // acknowledgePromotion routes to the Routine tab and queues
                            // the brief pulse on the promoted row.
                            state.acknowledgePromotion()
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
                    .onShake { state.activateMidSleepFromShake() }
                    .onAppear {
                        if state.shouldPresentDay14Prompt {
                            state.activePaywallRoute = .day14
                        }
                        state.evaluateTrialStatus()
                        state.presentPendingStreakMilestoneIfEligible()
                    }
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
