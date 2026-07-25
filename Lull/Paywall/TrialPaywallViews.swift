import StoreKit
import SwiftUI

enum TrialPaywallMode {
    case onboarding
    case subscriptionRequired
}

struct TrialPaywallScreen: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let mode: TrialPaywallMode

    @State private var isPurchasing = false
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

                            hero(compact: compact)
                            TrialQuoteCard()
                            benefits(compact: compact)
                            TrialReassuranceCard()

                            Text(pricingFootnote)
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
            state.trackPaywallViewed(context: analyticsContext)
        }
    }

    private var analyticsContext: String {
        switch mode {
        case .onboarding: return "onboarding"
        case .subscriptionRequired: return "trial_expired"
        }
    }

    private var pricingFootnote: String {
        switch mode {
        case .onboarding:
            return "Free for seven nights, then $49.99/year. Cancel anytime in Apple subscriptions."
        case .subscriptionRequired:
            return "Both plans include a seven-night App Store trial. Cancel anytime in Apple subscriptions."
        }
    }

    @ViewBuilder
    private func hero(compact: Bool) -> some View {
        switch mode {
        case .onboarding:
            onboardingHero(compact: compact)
        case .subscriptionRequired:
            expiredHero(compact: compact)
        }
    }

    private func onboardingHero(compact: Bool) -> some View {
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

    private func expiredHero(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            Kicker(text: "Trial ended", color: .lullAmberSoft)

            VStack(spacing: compact ? -15 : -17) {
                Text("Your sleep contract")
                    .font(.serif(compact ? 38 : 44, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text("is paused")
                    .font(.serifItalic(compact ? 44 : 50))
                    .foregroundColor(.lullAmber)
                    .minimumScaleFactor(0.78)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Text("Start another seven-night trial to turn app blocking, rule enforcement, and nightly protection back on.")
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk2)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
    }

    private func benefits(compact: Bool) -> some View {
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
                detail: "Confirm completion to unlock, or mark it missed for a short reset"
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

    @ViewBuilder
    private func bottomBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            switch mode {
            case .onboarding:
                onboardingActions
            case .subscriptionRequired:
                subscriptionRequiredActions
            }

            if mode == .onboarding {
                Button {
                    guard !isPurchasing && !subscriptions.isLoading else { return }
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
                .disabled(isPurchasing || subscriptions.isLoading)
                .opacity(isPurchasing || subscriptions.isLoading ? 0.55 : 1)
            }

            HStack(spacing: 26) {
                footerButton("Terms") { openURL(TenThirtyLegalLinks.terms) }
                footerButton("Privacy") { openURL(TenThirtyLegalLinks.privacy) }
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

    private var onboardingActions: some View {
        Group {
            TrialCTA(
                title: isPurchasing ? "Starting..." : "Protect my first night",
                subtitle: "Then $49.99/year. Cancel anytime.",
                disabled: isPurchasing || subscriptions.isLoading
            ) {
                guard !isPurchasing && !subscriptions.isLoading else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                state.trackPaywallPrimaryTapped(product: .yearly)
                Task { await purchase(.yearly) }
            }

            Button {
                guard !isPurchasing && !subscriptions.isLoading else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                state.trackPaywallPrimaryTapped(product: .monthly)
                Task { await purchase(.monthly) }
            } label: {
                Text("I'll skip the trial and go with $9.99/month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lullInk2)
                    .underline()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || subscriptions.isLoading)
            .opacity(isPurchasing || subscriptions.isLoading ? 0.55 : 1)
        }
    }

    private var subscriptionRequiredActions: some View {
        Group {
            TrialCTA(
                title: isPurchasing ? "Starting..." : "Start 7-day free trial",
                subtitle: "Yearly · then $49.99/year",
                disabled: isPurchasing || subscriptions.isLoading
            ) {
                guard !isPurchasing && !subscriptions.isLoading else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                state.trackPaywallPrimaryTapped(product: .yearly)
                Task { await purchase(.yearly) }
            }

            TrialCTA(
                title: isPurchasing ? "Starting..." : "Start 7-day free trial",
                subtitle: "Monthly · then $9.99/month",
                disabled: isPurchasing || subscriptions.isLoading
            ) {
                guard !isPurchasing && !subscriptions.isLoading else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                state.trackPaywallPrimaryTapped(product: .monthly)
                Task { await purchase(.monthly) }
            }
        }
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
            finishSuccessfulUnlock()
        } else if didPresentOfferCodeSheet {
            statusMessage = "If Apple accepted your code, it may take a moment to appear. Tap Restore if TenThirty does not unlock."
        }
    }

    @MainActor
    private func purchase(_ product: LullStoreProduct) async {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

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
            finishSuccessfulUnlock()
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
        state.trackRestoreStarted(context: analyticsContext)
        await subscriptions.restorePurchases()
        if subscriptions.isLullProActive {
            state.trackRestoreSucceeded(
                context: analyticsContext,
                isTrial: subscriptions.isInTrial,
                productIdentifier: subscriptions.activeProductIdentifier
            )
            state.applyRevenueCatEntitlement(isActive: true)
            finishSuccessfulUnlock()
        } else {
            state.trackRestoreFailed(
                context: analyticsContext,
                errorMessage: subscriptions.lastErrorMessage
            )
            statusMessage = subscriptions.lastErrorMessage ?? "No active TenThirty Premium purchase was found."
        }
    }

    private func finishSuccessfulUnlock() {
        switch mode {
        case .onboarding:
            state.completeOnboarding()
        case .subscriptionRequired:
            break
        }
    }
}

struct OnbTrialPaywallView: View {
    var body: some View {
        TrialPaywallScreen(mode: .onboarding)
    }
}

struct TrialExpiredPaywallView: View {
    var body: some View {
        TrialPaywallScreen(mode: .subscriptionRequired)
    }
}

struct TrialBenefit: View {
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

struct TrialQuoteCard: View {
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

struct TrialReassuranceCard: View {
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

struct TrialCTA: View {
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
