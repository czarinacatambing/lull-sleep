import Foundation
import RevenueCat

enum LullRevenueCatConfig {
    static let apiKey = "appl_fedvtTRxNGMrhFDrLLiyjRsFeTq"
    static let proEntitlementID = "Lull Pro"

    static let productIDs: [LullStoreProduct: String] = [
        .lifetime: "lifetime",
        .yearly: "yearly",
        .monthly: "monthly",
    ]

    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }
}

enum LullStoreProduct: String, CaseIterable, Identifiable {
    case lifetime
    case yearly
    case monthly

    var id: String { rawValue }

    var productID: String {
        LullRevenueCatConfig.productIDs[self] ?? rawValue
    }
}

enum LullSubscriptionError: LocalizedError {
    case missingOffering
    case missingPackage(LullStoreProduct)

    var errorDescription: String? {
        switch self {
        case .missingOffering:
            return "No RevenueCat offering is configured for TenThirty."
        case .missingPackage(let product):
            return "The \(product.rawValue) product is not available in the current RevenueCat offering."
        }
    }
}

struct LullSubscriptionDetails {
    let planName: String
    let statusText: String
    let billingTitle: String
    let billingText: String
    let productIdentifier: String
}

@MainActor
final class LullSubscriptionManager: NSObject, ObservableObject {
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var isLullProActive = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var hasResolvedInitialCustomerInfo = false
    @Published private(set) var hasResolvedInitialOfferings = false
    @Published var lastErrorMessage: String?

    private var hasStarted = false

    #if DEBUG
    @Published var debugSimulateExpiredTrial = false
    #endif

    var grantsPremiumAccess: Bool {
        #if DEBUG
        if debugSimulateExpiredTrial { return false }
        #endif
        return isLullProActive
    }

    var isInTrial: Bool {
        customerInfo?.entitlements.all[LullRevenueCatConfig.proEntitlementID]?.periodType == .trial
    }

    var activeProductIdentifier: String? {
        customerInfo?.entitlements.all[LullRevenueCatConfig.proEntitlementID]?.productIdentifier
    }

    var currentSubscriptionDetails: LullSubscriptionDetails? {
        guard let entitlement = customerInfo?.entitlements.all[LullRevenueCatConfig.proEntitlementID] else {
            return nil
        }

        let productIdentifier = entitlement.productIdentifier
        let planName = Self.planName(for: productIdentifier)
        let statusText: String
        switch entitlement.periodType {
        case .trial:
            statusText = entitlement.isActive ? "Free trial active" : "Trial ended"
        case .intro:
            statusText = entitlement.isActive ? "Intro offer active" : "Intro offer ended"
        case .normal, .prepaid:
            statusText = entitlement.isActive ? "Active subscription" : "Subscription inactive"
        @unknown default:
            statusText = entitlement.isActive ? "Active subscription" : "Subscription inactive"
        }

        let billingTitle: String
        let billingText: String
        if let expirationDate = entitlement.expirationDate {
            let formattedDate = Self.billingDateFormatter.string(from: expirationDate)
            if entitlement.periodType == .trial && entitlement.willRenew {
                billingTitle = "First billing starts"
                billingText = formattedDate
            } else if entitlement.willRenew {
                billingTitle = "Next billing period starts"
                billingText = formattedDate
            } else {
                billingTitle = "Access ends"
                billingText = formattedDate
            }
        } else {
            billingTitle = "Billing"
            billingText = entitlement.isActive ? "No renewal date" : "No billing date available"
        }

        return LullSubscriptionDetails(
            planName: planName,
            statusText: statusText,
            billingTitle: billingTitle,
            billingText: billingText,
            productIdentifier: productIdentifier
        )
    }

    func start(postHogUserID: String) {
        guard !hasStarted else { return }
        hasStarted = true
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        if arguments.contains("--uitest-completed-onboarding")
            || environment["UITEST_COMPLETED_ONBOARDING"] == "1" {
            isLullProActive = true
            hasResolvedInitialCustomerInfo = true
            hasResolvedInitialOfferings = true
            return
        }
        #endif
        Purchases.shared.attribution.setPostHogUserID(postHogUserID)
        Purchases.shared.delegate = self
        Task {
            await refreshCustomerInfo()
            await refreshOfferings()
        }
    }

    func refreshCustomerInfo() async {
        isLoading = true
        defer {
            isLoading = false
            hasResolvedInitialCustomerInfo = true
        }

        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.describeRevenueCatError(error)
        }
    }

    func refreshOfferings() async {
        guard !isLoadingOfferings else { return }
        isLoadingOfferings = true
        defer {
            isLoadingOfferings = false
            hasResolvedInitialOfferings = true
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            lastErrorMessage = nil
        } catch {
            currentOffering = nil
            lastErrorMessage = Self.describeRevenueCatError(error)
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.describeRevenueCatError(error)
        }
    }

    func purchase(_ product: LullStoreProduct) async throws {
        guard let package = package(for: product) else {
            throw currentOffering == nil
                ? LullSubscriptionError.missingOffering
                : LullSubscriptionError.missingPackage(product)
        }

        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
    }

    func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        isLullProActive = customerInfo.entitlements.all[LullRevenueCatConfig.proEntitlementID]?.isActive == true
    }

    private func package(for product: LullStoreProduct) -> Package? {
        currentOffering?.availablePackages.first { package in
            package.storeProduct.productIdentifier == product.productID ||
            package.identifier == product.rawValue
        }
    }

    func localizedPrice(for product: LullStoreProduct) -> String? {
        package(for: product)?.storeProduct.localizedPriceString
    }

    func priceSubtitle(for product: LullStoreProduct) -> String {
        if let price = localizedPrice(for: product) {
            switch product {
            case .yearly:
                return "\(price)/year"
            case .monthly:
                return "\(price)/month"
            case .lifetime:
                return price
            }
        }

        switch product {
        case .yearly:
            return "Billed yearly"
        case .monthly:
            return "Billed monthly"
        case .lifetime:
            return "Lifetime access"
        }
    }

    func yearlyPlanSubtitle() -> String {
        if let storeProduct = package(for: .yearly)?.storeProduct {
            return Self.yearlyPlanSubtitle(
                yearlyPrice: storeProduct.price,
                localizedYearlyPrice: storeProduct.localizedPriceString,
                currencyCode: storeProduct.currencyCode
            )
        }

        return "Billed yearly"
    }

    private static func yearlyPlanSubtitle(yearlyPrice: Decimal,
                                           localizedYearlyPrice: String?,
                                           currencyCode: String?) -> String {
        let yearlyLabel: String
        if let localizedYearlyPrice {
            yearlyLabel = "\(localizedYearlyPrice)/year"
        } else if let formattedYearly = localizedPrice(yearlyPrice, currencyCode: currencyCode) {
            yearlyLabel = "\(formattedYearly)/year"
        } else {
            yearlyLabel = "\(yearlyPrice)/year"
        }

        let monthlyAmount = yearlyPrice / 12
        let monthlyLabel = localizedPrice(monthlyAmount, currencyCode: currencyCode)
            ?? "\(monthlyAmount)"
        return "\(yearlyLabel) or \(monthlyLabel)/mo"
    }

    private static func localizedPrice(_ amount: Decimal, currencyCode: String?) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.roundingMode = .halfUp
        if let currencyCode {
            formatter.currencyCode = currencyCode
        }
        return formatter.string(from: amount as NSDecimalNumber)
    }

    func purchaseIncludesIntroductoryOffer(for product: LullStoreProduct) -> Bool {
        package(for: product)?.storeProduct.introductoryDiscount != nil
    }

    private static let billingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static func planName(for productIdentifier: String) -> String {
        switch productIdentifier {
        case LullStoreProduct.yearly.productID:
            return "Yearly plan"
        case LullStoreProduct.monthly.productID:
            return "Monthly plan"
        case LullStoreProduct.lifetime.productID:
            return "Lifetime plan"
        default:
            return "TenThirty Premium"
        }
    }

    private static func describeRevenueCatError(_ error: Error) -> String {
        let nsError = error as NSError
        let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription
        let message = underlying.map { "\(error.localizedDescription)\n\($0)" } ?? error.localizedDescription
        #if DEBUG
        print("[RevenueCat] \(message)")
        print("[RevenueCat] userInfo: \(nsError.userInfo)")
        #endif
        return message
    }
}

extension LullSubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
