import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showWelcome = true
    @State private var logoOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        if showWelcome {
            welcomeScreen
        } else {
            mainContent
                .preferredColorScheme(.dark)
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
                    Text("Get started")
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
                    .sheet(isPresented: $state.showMorningCheckIn) { MorningCheckInView() }
                    .fullScreenCover(item: $state.pendingPromotion) { promotion in
                        RoutinePromotedView(promotion: promotion) {
                            // acknowledgePromotion routes to the Routine tab and queues
                            // the brief pulse on the promoted row.
                            state.acknowledgePromotion()
                        }
                    }
                    .onShake { state.activateMidSleepFromShake() }
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
