import RevenueCat
import SwiftUI

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var accessState: PremiumAccessState = .loading
    @Published private(set) var offeringState: PremiumOfferingState = .loading
    @Published private(set) var lastRuntimeIssue: SubscriptionRuntimeIssue?
    @Published private(set) var packages: [PremiumPackage] = PremiumPackage.defaultPackages
    @Published var selectedPackageID: PremiumPackageID = .yearly

    private var revenueCatPackages: [PremiumPackageID: RevenueCat.Package] = [:]
    private var customerInfoUpdatesTask: Task<Void, Never>?
    private var hasConfigured = false
    private var isRevenueCatConfigured = false

    private init() {}

    deinit {
        customerInfoUpdatesTask?.cancel()
    }

    var selectedPackage: PremiumPackage {
        packages.first(where: { $0.id == selectedPackageID }) ?? packages[1]
    }

    var isPremium: Bool {
        if case .premium = accessState {
            return true
        }

        return false
    }

    var settingsStatusText: String {
        switch accessState {
        case .loading:
            return "Checking"
        case .free:
            return "Free"
        case .premium(.subscription):
            return "Active"
        case .premium(.lifetime):
            return "Lifetime"
        case .failed:
            return "Error"
        }
    }

    var settingsDescriptionText: String {
        switch accessState {
        case .loading:
            return "Checking premium access and available offerings."
        case .free:
            return "Turn intention into momentum. Count down to the life you’re creating."
        case .premium:
            return "Premium access is active."
        case let .failed(message):
            return message
        }
    }

    func configure() async {
        hasConfigured = true

        guard let revenueCatAPIKey = MonetizationConfig.revenueCatAPIKey else {
            applyDeveloperOverridesOrFallback()
            return
        }

        if !isRevenueCatConfigured {
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: revenueCatAPIKey)
            isRevenueCatConfigured = true
            startCustomerInfoListener()
        }

        await refreshOfferings()
        await refreshCustomerInfo()
    }

    func refreshCustomerInfo() async {
        if let developerAccessOverride {
            accessState = developerAccessOverride
            return
        }

        guard isRevenueCatConfigured else {
            applyDeveloperOverridesOrFallback()
            return
        }

        accessState = .loading

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
        } catch {
            accessState = .failed(message: "Couldn't refresh premium access.")
        }
    }

    func refreshOfferings() async {
        if let developerOfferingOverride {
            offeringState = developerOfferingOverride
            return
        }

        guard isRevenueCatConfigured else {
            applyDeveloperOverridesOrFallback()
            return
        }

        offeringState = .loading

        do {
            let offerings = try await Purchases.shared.offerings()
            apply(offerings: offerings)
        } catch {
            revenueCatPackages = [:]
            packages = PremiumPackage.defaultPackages
            offeringState = .unavailable(reason: "Couldn't load subscription options.")
            lastRuntimeIssue = .offeringsUnavailable
        }
    }

    func select(packageID: PremiumPackageID) {
        guard selectedPackageID != packageID else { return }
        selectedPackageID = packageID
        AppHaptics.impact(.light)
    }

    func purchaseSelectedPackage() async throws {
        try await purchase(packageID: selectedPackageID)
    }

    func purchase(packageID: PremiumPackageID) async throws {
        select(packageID: packageID)

        guard MonetizationConfig.revenueCatAPIKey != nil else {
            let issue = SubscriptionRuntimeIssue.missingAPIKey
            lastRuntimeIssue = issue
            throw SubscriptionActionError.runtime(issue)
        }

        guard let revenueCatPackage = revenueCatPackages[packageID] else {
            throw SubscriptionActionError.offeringUnavailable
        }

        let customerInfo = try await purchase(package: revenueCatPackage)
        apply(customerInfo: customerInfo)

        guard case .premium = accessState else {
            throw SubscriptionActionError.purchaseFailed("Purchase completed, but premium access did not activate.")
        }
    }

    func restorePurchases() async throws -> RestorePurchasesOutcome {
        guard MonetizationConfig.revenueCatAPIKey != nil else {
            let issue = SubscriptionRuntimeIssue.missingAPIKey
            lastRuntimeIssue = issue
            throw SubscriptionActionError.runtime(issue)
        }

        let customerInfo = try await restorePurchasesFromRevenueCat()
        apply(customerInfo: customerInfo)

        if case .premium = accessState {
            return .restoredPremium
        }

        return .nothingToRestore
    }

    var manageSubscriptionsURL: URL? {
        URL(string: "https://apps.apple.com/account/subscriptions")
    }

    private func applyDeveloperOverridesOrFallback() {
        if let developerAccessOverride {
            accessState = developerAccessOverride
        } else if MonetizationConfig.revenueCatAPIKey == nil {
            accessState = .free
            lastRuntimeIssue = .missingAPIKey
        } else if hasConfigured {
            accessState = .free
            lastRuntimeIssue = nil
        } else {
            accessState = .loading
        }

        if let developerOfferingOverride {
            offeringState = developerOfferingOverride
        } else if MonetizationConfig.revenueCatAPIKey == nil {
            offeringState = .unavailable(reason: "RevenueCat is not configured.")
        } else if hasConfigured {
            offeringState = .unavailable(reason: "Subscription options are not loaded yet.")
        } else {
            offeringState = .loading
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        if let developerAccessOverride {
            accessState = developerAccessOverride
            return
        }

        if let source = premiumAccessSource(from: customerInfo) {
            accessState = .premium(source)
            lastRuntimeIssue = nil
        } else {
            accessState = .free
            if case .unavailable = offeringState {
                lastRuntimeIssue = .offeringsUnavailable
            } else {
                lastRuntimeIssue = nil
            }
        }
    }

    private func apply(offerings: Offerings) {
        if let developerOfferingOverride {
            offeringState = developerOfferingOverride
            return
        }

        guard let currentOffering = offerings.current else {
            revenueCatPackages = [:]
            packages = PremiumPackage.defaultPackages
            offeringState = .unavailable(reason: "No current offering is configured in RevenueCat.")
            lastRuntimeIssue = .offeringsUnavailable
            return
        }

        var resolvedPackages: [PremiumPackageID: RevenueCat.Package] = [:]

        if let monthly = currentOffering.monthly ?? currentOffering.package(identifier: "monthly") {
            resolvedPackages[.monthly] = monthly
        }

        if let annual = currentOffering.annual
            ?? currentOffering.package(identifier: "yearly")
            ?? currentOffering.package(identifier: "annual") {
            resolvedPackages[.yearly] = annual
        }

        if let lifetime = currentOffering.lifetime ?? currentOffering.package(identifier: "lifetime") {
            resolvedPackages[.lifetime] = lifetime
        }

        revenueCatPackages = resolvedPackages
        packages = PremiumPackage.defaultPackages

        if resolvedPackages.isEmpty {
            offeringState = .unavailable(reason: "The default offering has no mapped packages yet.")
            lastRuntimeIssue = .offeringsUnavailable
        } else {
            offeringState = .available
            if case .free = accessState {
                lastRuntimeIssue = nil
            }
        }
    }

    private func premiumAccessSource(from customerInfo: CustomerInfo) -> PremiumAccessSource? {
        guard let entitlement = customerInfo.entitlements.all[MonetizationConfig.premiumEntitlementID],
              entitlement.isActive else {
            return nil
        }

        if entitlement.productIdentifier == revenueCatPackages[.lifetime]?.storeProduct.productIdentifier {
            return .lifetime
        }

        return .subscription
    }

    private func startCustomerInfoListener() {
        guard customerInfoUpdatesTask == nil else { return }

        customerInfoUpdatesTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await customerInfo in Purchases.shared.customerInfoStream {
                    await self.apply(customerInfo: customerInfo)
                }
            } catch {
                await self.handleCustomerInfoStreamFailure()
            }
        }
    }

    private func handleCustomerInfoStreamFailure() {
        if case .free = accessState {
            lastRuntimeIssue = .customerInfoUpdatesUnavailable
        }
    }

    private func purchase(package: RevenueCat.Package) async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
                if userCancelled {
                    continuation.resume(throwing: SubscriptionActionError.userCancelled)
                    return
                }

                if let error {
                    continuation.resume(throwing: SubscriptionActionError.purchaseFailed(error.localizedDescription))
                    return
                }

                guard let customerInfo else {
                    continuation.resume(throwing: SubscriptionActionError.purchaseFailed("Purchase completed without updated customer info."))
                    return
                }

                continuation.resume(returning: customerInfo)
            }
        }
    }

    private func restorePurchasesFromRevenueCat() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.restorePurchases { customerInfo, error in
                if let error {
                    continuation.resume(throwing: SubscriptionActionError.restoreFailed(error.localizedDescription))
                    return
                }

                guard let customerInfo else {
                    continuation.resume(throwing: SubscriptionActionError.restoreFailed("Restore completed without updated customer info."))
                    return
                }

                continuation.resume(returning: customerInfo)
            }
        }
    }

    private var developerAccessOverride: PremiumAccessState? {
        let rawValue = UserDefaults.standard.string(forKey: DeveloperSettingsKeys.paywallAccessStateOverride)
            ?? DeveloperPaywallAccessOverride.live.rawValue

        guard let override = DeveloperPaywallAccessOverride(rawValue: rawValue) else {
            return nil
        }

        switch override {
        case .live:
            return nil
        case .free:
            return .free
        case .premiumSubscription:
            return .premium(.subscription)
        case .premiumLifetime:
            return .premium(.lifetime)
        case .loading:
            return .loading
        case .failed:
            return .failed(message: "Developer paywall access override is simulating a failed state.")
        }
    }

    private var developerOfferingOverride: PremiumOfferingState? {
        let rawValue = UserDefaults.standard.string(forKey: DeveloperSettingsKeys.paywallOfferingStateOverride)
            ?? DeveloperPaywallOfferingOverride.live.rawValue

        guard let override = DeveloperPaywallOfferingOverride(rawValue: rawValue) else {
            return nil
        }

        switch override {
        case .live:
            return nil
        case .available:
            return .available
        case .unavailable:
            return .unavailable(reason: "Developer paywall offering override is simulating missing packages.")
        }
    }
}

enum PremiumAccessState: Equatable {
    case loading
    case free
    case premium(PremiumAccessSource)
    case failed(message: String)
}

enum PremiumAccessSource: Equatable {
    case subscription
    case lifetime
}

enum PremiumOfferingState: Equatable {
    case loading
    case available
    case unavailable(reason: String)
}

enum PremiumPackageID: String, CaseIterable, Identifiable {
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }
}

struct PremiumPackage: Identifiable, Equatable {
    let id: PremiumPackageID
    let priceTitle: String
    let periodTitle: String
    let badgeText: String?
    let ctaTitle: String
    let billingNote: String

    static let defaultPackages: [PremiumPackage] = [
        .init(
            id: .monthly,
            priceTitle: "$2.99",
            periodTitle: "for 1 month",
            badgeText: nil,
            ctaTitle: "Continue with Monthly",
            billingNote: "$2.99 billed monthly."
        ),
        .init(
            id: .yearly,
            priceTitle: "$49.99",
            periodTitle: "for 12 months",
            badgeText: "-28%",
            ctaTitle: "Start 1 week free trial",
            billingNote: "Try free for 1 week, then $49.99/year"
        ),
        .init(
            id: .lifetime,
            priceTitle: "$99.99",
            periodTitle: "Lifetime deal",
            badgeText: nil,
            ctaTitle: "Unlock Lifetime",
            billingNote: "One-time payment of $99.99."
        )
    ]

    var minimumCardWidth: CGFloat {
        switch id {
        case .monthly:
            return 124
        case .yearly:
            return 186
        case .lifetime:
            return 138
        }
    }
}

enum SubscriptionRuntimeIssue: Equatable {
    case missingAPIKey
    case offeringsUnavailable
    case customerInfoUpdatesUnavailable

    var recoverySuggestion: String {
        switch self {
        case .missingAPIKey:
            return "Add a RevenueCat app key in Moments/Config.xcconfig to enable live purchases."
        case .offeringsUnavailable:
            return "RevenueCat is configured, but the default offering or packages are not ready yet."
        case .customerInfoUpdatesUnavailable:
            return "Premium updates are temporarily unavailable. Reopen the sheet or try again."
        }
    }
}

enum SubscriptionActionError: LocalizedError {
    case runtime(SubscriptionRuntimeIssue)
    case offeringUnavailable
    case userCancelled
    case purchaseFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case let .runtime(issue):
            return issue.recoverySuggestion
        case .offeringUnavailable:
            return "The selected package is not available in the current RevenueCat offering."
        case .userCancelled:
            return "The purchase was cancelled."
        case let .purchaseFailed(message):
            return message
        case let .restoreFailed(message):
            return message
        }
    }
}

enum RestorePurchasesOutcome {
    case restoredPremium
    case nothingToRestore
}

private enum MonetizationConfig {
    static var revenueCatAPIKey: String? {
        normalizedSecret(
            ProcessInfo.processInfo.environment["REVENUECAT_API_KEY_IOS"]
                ?? Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY_IOS") as? String
        )
    }

    static var premiumEntitlementID: String {
        let resolvedValue =
            ProcessInfo.processInfo.environment["REVENUECAT_ENTITLEMENT_PREMIUM"]
            ?? Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_ENTITLEMENT_PREMIUM") as? String

        let trimmed = resolvedValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmed,
           !trimmed.isEmpty,
           !trimmed.contains("$(") {
            return trimmed
        }

        return "premium"
    }

    private static func normalizedSecret(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.contains("$("),
              !placeholderValues.contains(trimmed) else {
            return nil
        }

        return trimmed
    }

    private static let placeholderValues: Set<String> = [
        "apn_your_public_sdk_key"
    ]
}
