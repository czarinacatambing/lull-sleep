import SwiftUI
import MessageUI
import RevenueCat
import RevenueCatUI

enum UserTier: String, Codable {
    case onboarding
    case trial
    case free
    case awaitingVerdict
    case paywallPending
    case subscribed
    case shareUnlocked
    case freeForever
}

enum RevenueCatPaywallContext: String, Identifiable {
    case trialExpired
    case upgrade

    var id: String { rawValue }
}

enum UnlockMethod: Codable {
    case subscribe(PaywallPlan)
    case share(ShareUnlockSource)
}

enum PaywallPlan: String, Codable, CaseIterable {
    case lifetime
    case yearly
    case monthly

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = rawValue == "annual" ? .yearly : PaywallPlan(rawValue: rawValue) ?? .yearly
    }

    var displayPrice: String {
        switch self {
        case .lifetime: return "Lifetime access"
        case .yearly: return "Yearly plan"
        case .monthly: return "Monthly plan"
        }
    }

    var cta: String {
        switch self {
        case .lifetime: return "Unlock lifetime access"
        case .yearly: return "Subscribe yearly"
        case .monthly: return "Subscribe monthly"
        }
    }

    var legalPrice: String {
        switch self {
        case .lifetime: return "one-time purchase"
        case .yearly: return "yearly renewal"
        case .monthly: return "monthly renewal"
        }
    }

    var storeProductID: String { rawValue }
}

enum ShareUnlockSource: String, Codable {
    case sms
    case `public`
}

struct PaywallState: Codable {
    var tier: UserTier = .onboarding
    var unlockMethod: UnlockMethod? = nil
    var dismissalCount: Int = 0
    var lastDismissalAt: Date? = nil
    var verdictRevealed: Bool = false
    var trialStartedAt: Date? = nil
    var trialEndsAt: Date? = nil
    var trialExpiredAt: Date? = nil
    var originalGeneratedRoutine: [RoutineStep]? = nil
    var trialCustomizedRoutine: [RoutineStep]? = nil
    var lastReassessmentAt: Date? = nil
    var gentleBlockingBypassedUntil: Date? = nil

    var trialHasStarted: Bool { trialStartedAt != nil && trialEndsAt != nil }

    func isTrialActive(now: Date = Date()) -> Bool {
        guard trialStartedAt != nil, let trialEndsAt else { return false }
        return now < trialEndsAt
    }
}

enum PaywallOutcome: String, Codable {
    case positive
    case neutral
    case negative

    var reframeLine: String {
        switch self {
        case .positive:
            return "5 nights, one variable, one real answer. Unlock to see what worked."
        case .neutral:
            return "Your data was close to the line. Unlock to see exactly where, and what to try next."
        case .negative:
            return "Whether tonight worked or didn't, this is the data we'll use to pick your next experiment."
        }
    }

    var verdictWord: String {
        switch self {
        case .positive: return "worked"
        case .neutral: return "was close"
        case .negative: return "didn't help"
        }
    }
}

struct PaywallVerdict: Codable {
    var diagnosis: String
    var confirmation: String
    var experiment: String
    var chronotype: Chronotype
    var scoreDelta: String
    var outcome: PaywallOutcome
    var verdictSentence: String
    var research: String
    var recommendation: String
    var nightsLogged: Int
    var sparklineScores: [Int]
}

enum PaywallRoute: Identifiable {
    case nightFive
    case day14
    case verdictReplay

    var id: String {
        switch self {
        case .nightFive: return "night-five"
        case .day14: return "day-14"
        case .verdictReplay: return "verdict-replay"
        }
    }
}

enum PaywallEntryPoint {
    case verdict
    case settings

    var kicker: String { self == .settings ? "TENTHIRTY PREMIUM" : "UNLOCK YOUR VERDICT" }
}

let PREMIUM_INCLUDES = [
    "App blocking during wind-down",
    "Sleep sounds (7 ambient tracks)",
    "Add or customize routine steps",
    "Today's full verdict + sleep pattern reveal",
    "Deeper habit progress after your free week",
    "More ways to keep your routine consistent",
]

struct NightFivePaywallFlow: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let route: PaywallRoute

    @State private var screen: FlowScreen
    @State private var showPricing = false
    @State private var showShare = false
    @State private var pricingEntry: PaywallEntryPoint = .verdict

    init(route: PaywallRoute) {
        self.route = route
        switch route {
        case .day14:
            _screen = State(initialValue: .day14)
        case .verdictReplay:
            _screen = State(initialValue: .unlockedShare)
        case .nightFive:
            _screen = State(initialValue: .transition)
        }
    }

    enum FlowScreen {
        case transition
        case blurredVerdict
        case unlockedSubscriber
        case unlockedShare
        case freeForever
        case day14
    }

    private var verdict: PaywallVerdict {
        state.activePaywallVerdict ?? state.buildVerdictSnapshotFromRecentLogs()
    }

    var body: some View {
        ZStack {
            switch screen {
            case .transition:
                PaywallTransitionView {
                    state.paywallState.tier = .paywallPending
                    state.persist()
                    screen = .blurredVerdict
                }
            case .blurredVerdict:
                BlurredVerdictPaywallView(verdict: verdict) {
                    pricingEntry = .verdict
                    showPricing = true
                }
            case .unlockedSubscriber:
                VerdictUnlockedView(verdict: verdict, mode: .subscriber) {
                    state.requestedTab = 2
                    dismiss()
                } onHome: {
                    dismiss()
                } onSubscribe: {
                    pricingEntry = .verdict
                    showPricing = true
                }
            case .unlockedShare:
                VerdictUnlockedView(verdict: verdict, mode: .shareOnly) {
                    state.requestedTab = 2
                    dismiss()
                } onHome: {
                    dismiss()
                } onSubscribe: {
                    pricingEntry = .settings
                    showPricing = true
                }
            case .freeForever:
                FreeForeverView {
                    dismiss()
                } onUnlock: {
                    pricingEntry = .verdict
                    showPricing = true
                }
            case .day14:
                Day14ReengagementView {
                    state.seedDay14Verdict()
                    screen = .blurredVerdict
                } onDismiss: {
                    state.dismissDay14Prompt()
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled(screen == .transition || screen == .blurredVerdict)
        .sheet(isPresented: $showPricing) {
            PricingSheet(entryPoint: pricingEntry) { plan in
                state.unlockVerdict(method: .subscribe(plan))
                showPricing = false
                screen = .unlockedSubscriber
            } onNotNow: {
                showPricing = false
                if pricingEntry == .verdict {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        showShare = true
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShare) {
            ShareToUnlockSheet(verdict: verdict) { source in
                state.unlockVerdict(method: .share(source))
                showShare = false
                screen = .unlockedShare
            } onNoThanks: {
                state.markFreeForever()
                showShare = false
                screen = .freeForever
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onDisappear {
            state.activePaywallRoute = nil
            state.justTriggeredNightFivePaywall = false
        }
    }
}

struct PaywallTransitionView: View {
    let onAdvance: () -> Void
    @State private var nightVisible = false
    @State private var verdictVisible = false
    @State private var emberVisible = false

    var body: some View {
        LullScreen(glow: true, glowX: 0.5, glowY: 0.5, glowRadius: 520, glowOpacity: 1.1) {
            ZStack {
                VStack(spacing: 28) {
                    Text("NIGHT 5")
                        .font(.mono(11))
                        .kerning(4.6)
                        .foregroundColor(.lullInk3.opacity(0.42))
                        .opacity(nightVisible ? 1 : 0)
                    Text("YOUR VERDICT IS READY")
                        .font(.mono(11))
                        .kerning(3.5)
                        .foregroundColor(.lullInk0)
                        .opacity(verdictVisible ? 1 : 0)
                }
                GeometryReader { geo in
                    Ember(size: 5)
                        .opacity(emberVisible ? 0.55 : 0)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.68)
                }
                .allowsHitTesting(false)
            }
        }
        .statusBarHidden(true)
        .contentShape(Rectangle())
        .onTapGesture { onAdvance() }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { nightVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) { verdictVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.8)) { emberVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { onAdvance() }
        }
    }
}

struct BlurredVerdictPaywallView: View {
    let verdict: PaywallVerdict
    let onUnlock: () -> Void

    var body: some View {
        LullScreen(glowX: 0.5, glowY: 0.64, glowRadius: 460, glowOpacity: 0.9) {
            VStack(spacing: 0) {
                HStack {
                    BrandMark()
                    Spacer()
                    Kicker(text: "Night 5")
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 18)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        topZone
                        earnedDivider
                        gatedZone
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("blurred — unlock to reveal")
                        Text(verdict.outcome.reframeLine)
                            .font(.serifItalic(16))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 18)
                }

                VStack(spacing: 10) {
                    Kicker(text: "Unlock your verdict", color: .lullAmberSoft)
                    PrimaryCTA(title: "Unlock", action: onUnlock)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var topZone: some View {
        VStack(alignment: .leading, spacing: 14) {
            Kicker(text: "Diagnosis")
            Text(verdict.diagnosis)
                .font(.serif(18))
                .foregroundColor(.lullInk0)
            Text(verdict.confirmation)
                .font(.system(size: 11.5))
                .foregroundColor(.lullInk3)
            Divider().background(Color.lullLine)
            Kicker(text: "Experiment")
            Text(verdict.experiment)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.lullInk1)
        }
        .padding(18)
        .lullCard(radius: 18, accent: true)
    }

    private var earnedDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.lullLine).frame(height: 1)
            Text("EARNED ON NIGHT 5")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk4)
                .fixedSize()
            Rectangle().fill(Color.lullLine).frame(height: 1)
        }
    }

    private var gatedZone: some View {
        VStack(alignment: .leading, spacing: 18) {
            BlurBar(width: 132, height: 20, glow: true)
            HStack(alignment: .center, spacing: 12) {
                BlurBar(width: 62, height: 28, glow: true)
                VStack(alignment: .leading, spacing: 7) {
                    BlurSentence(widths: [112, 74, 96])
                    BlurSentence(widths: [88, 132])
                }
            }
            BlurSentence(widths: [144, 92, 118])
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "What the research shows")
                BlurSentence(widths: [132, 84, 106])
                BlurSentence(widths: [132, 96])
            }
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "What to try next")
                BlurSentence(widths: [118, 76, 138])
                BlurSentence(widths: [96, 128])
            }
        }
        .padding(18)
        .lullCard(radius: 18)
    }
}

struct PricingSheet: View {
    let entryPoint: PaywallEntryPoint
    let onSubscribed: (PaywallPlan) -> Void
    let onNotNow: () -> Void

    var body: some View {
        RevenueCatPaywallSheet(context: entryPoint == .settings ? .upgrade : .trialExpired) {
            onSubscribed(.yearly)
        } onClose: {
            onNotNow()
        }
    }
}

struct RevenueCatPaywallSheet: View {
    @EnvironmentObject private var subscriptions: LullSubscriptionManager
    @Environment(\.openURL) private var openURL
    let context: RevenueCatPaywallContext
    var allowsDismiss = true
    let onSubscribed: () -> Void
    let onClose: () -> Void
    @State private var showCustomerCenter = false
    @State private var didAttemptInitialLoad = false

    var body: some View {
        Group {
            if !didAttemptInitialLoad {
                loadingView
            } else if let offering = subscriptions.currentOffering,
                      offering.hasPaywall,
                      !offering.availablePackages.isEmpty {
                hostedPaywall(offering: offering)
            } else {
                unavailableView
            }
        }
        .task {
            await subscriptions.refreshCustomerInfo()
            await subscriptions.refreshOfferings()
            didAttemptInitialLoad = true
            completeIfSubscribed()
        }
        .onChange(of: subscriptions.isLullProActive) { _, _ in
            completeIfSubscribed()
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
                .onCustomerCenterRestoreCompleted { customerInfo in
                    subscriptions.apply(customerInfo: customerInfo)
                }
                .onCustomerCenterRestoreFailed { error in
                    subscriptions.lastErrorMessage = error.localizedDescription
                }
        }
    }

    private var loadingView: some View {
        LullScreen(glow: true, glowX: 0.5, glowY: 0.1, glowRadius: 300, glowOpacity: 0.75) {
            ProgressView()
                .tint(.lullAmber)
        }
    }

    private func hostedPaywall(offering: Offering) -> some View {
        ZStack(alignment: .topTrailing) {
            PaywallView(offering: offering)
                .onRequestedDismissal {
                    guard allowsDismiss else { return }
                    onClose()
                }
                .ignoresSafeArea()

            VStack {
                Spacer()
                legalLinks
            }
            .padding(.bottom, 14)

            if allowsDismiss {
                VStack(alignment: .trailing, spacing: 10) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.lullInk0)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.black.opacity(0.36)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")

                    Button {
                        showCustomerCenter = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.lullInk0)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.black.opacity(0.36)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage subscription")
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
            } else {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showCustomerCenter = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.lullInk0)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.black.opacity(0.36)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Manage subscription")
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 18) {
            legalButton("Terms", url: TenThirtyLegalLinks.terms)
            legalButton("Privacy", url: TenThirtyLegalLinks.privacy)
        }
        .font(.mono(10))
        .foregroundColor(.lullInk2)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.black.opacity(0.38)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func legalButton(_ title: String, url: URL) -> some View {
        Button(title) {
            openURL(url)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var unavailableView: some View {
        LullScreen(glow: true, glowX: 0.5, glowY: 0.05, glowRadius: 330, glowOpacity: 0.85) {
            VStack(alignment: .leading, spacing: 18) {
                Kicker(text: context == .trialExpired ? "TRIAL ENDED" : "TENTHIRTY PREMIUM", color: .lullAmberSoft)
                Text(allowsDismiss ? "TenThirty Premium isn't available right now." : "Your free trial has ended.")
                    .font(.serif(30))
                    .foregroundColor(.lullInk0)
                Text(
                    allowsDismiss
                        ? "RevenueCat did not return an active paywall offering for this build. You can try again from Settings later."
                        : "Subscribe to keep using your sleep contract, app blocking, and nightly enforcement."
                )
                    .font(.system(size: 14))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)
                if allowsDismiss {
                    GhostButton(title: "Close", action: onClose)
                } else {
                    GhostButton(title: "Restore purchases") {
                        Task { await subscriptions.restorePurchases() }
                    }
                }
            }
            .padding(24)
        }
    }

    private func completeIfSubscribed() {
        guard subscriptions.isLullProActive else { return }
        onSubscribed()
    }
}

struct ShareToUnlockSheet: View {
    @EnvironmentObject private var state: AppState
    let verdict: PaywallVerdict
    let onUnlocked: (ShareUnlockSource) -> Void
    let onNoThanks: () -> Void
    @State private var composer: MessageComposerPayload?
    @State private var activity: ActivityPayload?

    private let bodyText = "I'm using TenThirty to help improve my sleep. Try it tonight. https://apps.apple.com/app/tenthirty"

    var body: some View {
        LullScreen(glow: true, glowX: 0.5, glowY: 0.12, glowRadius: 320, glowOpacity: 0.8) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Kicker(text: "One more way", color: .lullAmberSoft)
                    Text("Share to unlock.")
                        .font(.serif(32))
                        .foregroundColor(.lullInk0)
                    Text("Pick one — same result either way.")
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk2)
                    option(title: "Invite a friend",
                           detail: "Send a quick message via iMessage or SMS. We'll confirm with iOS when it sends.") {
                        state.recordVerdictShareAttempt(source: .sms)
                        composer = MessageComposerPayload(image: ShareCardRenderer.image(for: verdict), body: bodyText)
                    }
                    option(title: "Post publicly",
                           detail: "Share your card to X, Instagram, Threads, or Reddit. We unlock once the share opens.") {
                        state.recordVerdictShareAttempt(source: .public)
                        activity = ActivityPayload(items: [ShareCardRenderer.image(for: verdict), bodyText])
                    }
                    HStack {
                        Spacer()
                        Image(uiImage: ShareCardRenderer.image(for: verdict))
                            .resizable()
                            .aspectRatio(4 / 5, contentMode: .fit)
                            .frame(width: 124)
                            .rotationEffect(.degrees(-1.5))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lullAmber.opacity(0.22), lineWidth: 1))
                            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
                        Spacer()
                    }
                    Text("THIS IS WHAT GETS SHARED EITHER WAY")
                        .font(.mono(9.5))
                        .kerning(1.2)
                        .foregroundColor(.lullInk4)
                        .frame(maxWidth: .infinity)
                    GhostButton(title: "No thanks", action: onNoThanks)
                        .frame(maxWidth: 170)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 36)
            }
        }
        .sheet(item: $composer) { payload in
            MessageComposer(payload: payload) { result in
                composer = nil
                if result == .sent { onUnlocked(.sms) }
            }
        }
        .sheet(item: $activity) { payload in
            ActivityView(payload: payload) { completed in
                activity = nil
                if completed { onUnlocked(.public) }
            }
        }
    }

    private func option(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.lullInk0)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(.lullInk3)
                        .lineSpacing(3)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.lullBgDeep)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.lullAmber))
            }
            .padding(16)
            .lullCard(radius: 16, accent: true)
        }
        .buttonStyle(.plain)
    }
}

enum VerdictUnlockedMode { case subscriber, shareOnly }

struct VerdictUnlockedView: View {
    let verdict: PaywallVerdict
    let mode: VerdictUnlockedMode
    let onStartTonight: () -> Void
    let onHome: () -> Void
    let onSubscribe: () -> Void
    @State private var revealStage = 0
    @State private var footerVisible = false

    var body: some View {
        LullScreen(glowX: 0.5, glowY: 0.28, glowRadius: 340, glowOpacity: 0.75) {
            VStack(spacing: 0) {
                if mode == .shareOnly {
                    Text("VERDICT UNLOCKED · THANKS FOR SHARING")
                        .font(.mono(10))
                        .kerning(1.2)
                        .foregroundColor(.lullAmber)
                        .padding(.top, 18)
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Kicker(text: "Sleep pattern", color: .lullAmberSoft)
                        reveal(index: 1) {
                            Text(verdict.chronotype.displayName)
                                .font(.serif(36))
                                .foregroundColor(.lullAmber)
                        }
                        reveal(index: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(verdict.scoreDelta)
                                    .font(.serif(52))
                                    .foregroundColor(.lullInk0)
                                Text(verdict.outcome.verdictWord)
                                    .font(.serifItalic(22))
                                    .foregroundColor(.lullAmber)
                            }
                            Text(verdict.verdictSentence)
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk2)
                                .lineSpacing(4)
                        }
                        reveal(index: 3) {
                            VerdictBlock(title: "What the research shows", text: verdict.research)
                        }
                        reveal(index: 4) {
                            VerdictBlock(title: "What to try next", text: verdict.recommendation)
                        }
                    }
                    .padding(22)
                    .padding(.bottom, mode == .shareOnly ? 130 : 20)
                }
                if mode == .subscriber {
                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Start tonight", action: onStartTonight)
                        GhostButton(title: "I'll come back to this", action: onHome)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 34)
                }
            }
            if mode == .shareOnly {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: "Keep going with TenThirty", color: .lullAmberSoft)
                        Text("Tonight's verdict is yours. New experiments and Premium features need a subscription.")
                            .font(.system(size: 13))
                            .foregroundColor(.lullInk2)
                            .lineSpacing(3)
                        PrimaryCTA(title: "Subscribe to access premium features", action: onSubscribe)
                        GhostButton(title: "Maybe later", action: onHome)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().fill(Color.lullLine).frame(height: 1), alignment: .top)
                    .opacity(footerVisible ? 1 : 0)
                }
            }
        }
        .onAppear {
            for i in 1...4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 0.3) {
                    withAnimation(.easeOut(duration: 0.4)) { revealStage = i }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.35)) { footerVisible = true }
            }
        }
    }

    private func reveal<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .blur(radius: revealStage >= index ? 0 : 12)
            .opacity(revealStage >= index ? 1 : 0.55)
    }
}

struct VerdictBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: title)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.lullInk2)
                .lineSpacing(4)
        }
        .padding(16)
        .lullCard(radius: 16)
    }
}

struct FreeForeverView: View {
    let onDone: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        LullScreen(glowX: 0.5, glowY: 0.18, glowRadius: 300, glowOpacity: 0.65) {
            VStack(alignment: .leading, spacing: 22) {
                BrandMark()
                    .padding(.top, 18)
                Kicker(text: "Keeping your routine", color: .lullAmberSoft)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your wind-down stays.")
                        .font(.serif(32))
                        .foregroundColor(.lullInk0)
                    Text("Premium pauses.")
                        .font(.serifItalic(32))
                        .foregroundColor(.lullAmber)
                }
                Text("Your 3-step routine works free, forever. You'll keep logging your sleep each morning — we still use that data to keep our aggregate stats honest.")
                    .font(.system(size: 14))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)
                Divider().background(Color.lullLine)
                Kicker(text: "Premium you're passing on")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(PREMIUM_INCLUDES, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk3)
                    }
                }
                Spacer()
                PrimaryCTA(title: "Got it", action: onDone)
                GhostButton(title: "Actually, unlock it now", action: onUnlock)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
    }
}

struct Day14ReengagementView: View {
    @EnvironmentObject private var state: AppState
    let onSeeVerdict: () -> Void
    let onDismiss: () -> Void
    @State private var isActive = true

    var body: some View {
        LullScreen(glowX: 0.5, glowY: 0.2, glowRadius: 320, glowOpacity: 0.72) {
            VStack(alignment: .leading, spacing: 22) {
                BrandMark()
                    .padding(.top, 18)
                Kicker(text: "14 nights later", color: .lullAmberSoft)
                (Text("You've logged ")
                 + Text("\(state.loggedNightCount) nights").font(.serifItalic(30)).foregroundColor(.lullAmber)
                 + Text(" of sleep. Want to see what they tell us?"))
                    .font(.serif(30))
                    .foregroundColor(.lullInk0)
                    .lineSpacing(4)
                Text("We can take a fresh read of your last 5 nights and start a new experiment tonight — built on the data you've already given us.")
                    .font(.system(size: 14))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)
                Sparkline(scores: state.sleepLogs.filter { $0.score > 0 }.sorted { $0.date < $1.date }.map(\.score))
                    .frame(height: 110)
                    .padding(.vertical, 8)
                Text("LAST 5 · SEED FOR YOUR NEXT EXPERIMENT")
                    .font(.mono(9.5))
                    .kerning(1.2)
                    .foregroundColor(.lullInk4)
                Spacer()
                PrimaryCTA(title: "See my next verdict") {
                    isActive = false
                    onSeeVerdict()
                }
                GhostButton(title: "Not yet") {
                    isActive = false
                    onDismiss()
                }
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if isActive { onDismiss() }
            }
        }
        .onDisappear { isActive = false }
    }
}

struct BlurBar: View {
    var width: CGFloat
    var height: CGFloat
    var glow: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: height * 0.42)
            .fill(LinearGradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width, height: height)
            .shadow(color: glow ? Color.lullAmber.opacity(0.18) : .clear, radius: 18)
    }
}

struct BlurSentence: View {
    var widths: [CGFloat]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                BlurBar(width: width, height: 11)
            }
        }
    }
}

struct Sparkline: View {
    let scores: [Int]

    var body: some View {
        GeometryReader { geo in
            let values = scores.isEmpty ? [0] : scores
            let gap: CGFloat = 5
            let barW = max(4, (geo.size.width - gap * CGFloat(values.count - 1)) / CGFloat(values.count))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, score in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index >= values.count - 5 ? Color.lullAmber : Color.white.opacity(0.12))
                        .frame(width: barW, height: max(8, geo.size.height * CGFloat(score) / CGFloat(AppState.maxSleepScore)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MessageComposerPayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let body: String
}

struct MessageComposer: UIViewControllerRepresentable {
    let payload: MessageComposerPayload
    let onComplete: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            return UIActivityViewController(activityItems: [payload.image, payload.body], applicationActivities: nil)
        }
        let vc = MFMessageComposeViewController()
        vc.body = payload.body
        vc.messageComposeDelegate = context.coordinator
        if let data = payload.image.pngData() {
            vc.addAttachmentData(data, typeIdentifier: "public.png", filename: "lull-verdict.png")
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onComplete: (MessageComposeResult) -> Void
        init(onComplete: @escaping (MessageComposeResult) -> Void) { self.onComplete = onComplete }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.onComplete(result) }
        }
    }
}

struct ActivityPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let payload: ActivityPayload
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: payload.items, applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .print, .saveToCameraRoll, .addToReadingList]
        vc.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ShareCardRenderer {
    static func image(for verdict: PaywallVerdict) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(Color.lullBg).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let glow = UIColor(Color.lullAmber.opacity(0.18)).cgColor
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [glow, UIColor.clear.cgColor] as CFArray, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 540, y: 400), startRadius: 0, endCenter: CGPoint(x: 540, y: 400), endRadius: 520, options: [])

            draw("lull", at: CGPoint(x: 88, y: 86), size: 58, color: UIColor(Color.lullInk0), serif: true, italic: true)
            draw("NIGHT 5 VERDICT", at: CGPoint(x: 88, y: 210), size: 34, color: UIColor(Color.lullAmber), mono: true)
            draw(verdict.chronotype.displayName, at: CGPoint(x: 88, y: 306), size: 88, color: UIColor(Color.lullAmber), serif: true)
            draw(verdict.diagnosis, at: CGPoint(x: 88, y: 448), size: 46, color: UIColor(Color.lullInk0), serif: true)
            draw(verdict.experiment, at: CGPoint(x: 88, y: 540), size: 34, color: UIColor(Color.lullInk2))
            draw("\(verdict.scoreDelta) · \(verdict.outcome.verdictWord)", at: CGPoint(x: 88, y: 690), size: 74, color: UIColor(Color.lullInk0), serif: true)
            draw(verdict.verdictSentence, at: CGPoint(x: 88, y: 828), size: 38, color: UIColor(Color.lullInk1), maxWidth: 880)
            draw("TRY NEXT", at: CGPoint(x: 88, y: 1082), size: 28, color: UIColor(Color.lullInk3), mono: true)
            draw(verdict.recommendation, at: CGPoint(x: 88, y: 1138), size: 38, color: UIColor(Color.lullInk1), maxWidth: 880)
        }
    }

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat, color: UIColor, serif: Bool = false, italic: Bool = false, mono: Bool = false, maxWidth: CGFloat = 900) {
        let font: UIFont
        if mono {
            font = UIFont.monospacedSystemFont(ofSize: size, weight: .medium)
        } else if serif {
            font = UIFont(name: italic ? "Fraunces-LightItalic" : "Fraunces-Light", size: size) ?? .systemFont(ofSize: size, weight: .light)
        } else {
            font = .systemFont(ofSize: size, weight: .regular)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = size * 0.18
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        text.draw(with: CGRect(x: point.x, y: point.y, width: maxWidth, height: 260), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
    }
}
