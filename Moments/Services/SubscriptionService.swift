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
        packages.first(where: { $0.id == selectedPackageID })
            ?? packages.first(where: { $0.id == .yearly })
            ?? packages.first
            ?? PremiumPackage.defaultPackages[1]
    }

    var isPremium: Bool {
        if case .premium = accessState {
            return true
        }

        return false
    }

    var privacyPolicyURL: URL? {
        MonetizationConfig.privacyPolicyURL
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

        if shouldSimulateSuccessfulPurchase {
            activateDeveloperPremiumOverride(for: packageID)
            return
        }

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

    var freeCreatedMomentAllowance: Int {
        3
    }

    var freeAIGenerationAllowance: Int {
        3
    }

    var freeCreatedMomentCount: Int {
        UserDefaults.standard.integer(forKey: AppSettingsKeys.freeCreatedMomentCount)
    }

    var freeAIGenerationCount: Int {
        UserDefaults.standard.integer(forKey: AppSettingsKeys.freeAIGenerationCount)
    }

    var freeAIGenerationsRemaining: Int {
        max(freeAIGenerationAllowance - freeAIGenerationCount, 0)
    }

    var shouldShowCreationUpsell: Bool {
        !isPremium && freeCreatedMomentCount >= freeCreatedMomentAllowance
    }

    func recordCreatedMoment() {
        guard !isPremium else { return }
        UserDefaults.standard.set(
            freeCreatedMomentCount + 1,
            forKey: AppSettingsKeys.freeCreatedMomentCount
        )
    }

    func recordAIGeneration() {
        guard !isPremium else { return }
        UserDefaults.standard.set(
            freeAIGenerationCount + 1,
            forKey: AppSettingsKeys.freeAIGenerationCount
        )
    }

    func isUnlocked(_ feature: PremiumFeature, currentMomentCount: Int? = nil) -> Bool {
        if isPremium {
            return true
        }

        switch feature {
        case .unlimitedMoments:
            return true
        case .aiReflections,
             .calendarSync,
             .manifestationReminders,
             .alternateIcons,
             .advancedThemes,
             .premiumWidgets:
            if feature == .aiReflections {
                return freeAIGenerationCount < freeAIGenerationAllowance
            }
            return false
        }
    }

    func shouldPresentUpgrade(
        for feature: PremiumFeature,
        currentMomentCount: Int? = nil
    ) -> Bool {
        !isUnlocked(feature, currentMomentCount: currentMomentCount)
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
        packages = PremiumPackage.resolvedPackages(
            from: resolvedPackages,
            fallback: PremiumPackage.defaultPackages
        )
        selectedPackageID = PremiumPackage.preferredSelection(
            availablePackageIDs: packages.map(\.id),
            currentSelection: selectedPackageID
        )

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

            for await customerInfo in Purchases.shared.customerInfoStream {
                self.apply(customerInfo: customerInfo)
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

    private var shouldSimulateSuccessfulPurchase: Bool {
        UserDefaults.standard.bool(forKey: DeveloperSettingsKeys.simulateSuccessfulPurchase)
    }

    private func activateDeveloperPremiumOverride(for packageID: PremiumPackageID) {
        let overrideValue: DeveloperPaywallAccessOverride = packageID == .lifetime
            ? .premiumLifetime
            : .premiumSubscription

        UserDefaults.standard.set(
            overrideValue.rawValue,
            forKey: DeveloperSettingsKeys.paywallAccessStateOverride
        )

        accessState = developerAccessOverride ?? .premium(.subscription)
        lastRuntimeIssue = nil
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

enum PremiumFeature: String, Identifiable, CaseIterable {
    case unlimitedMoments
    case aiReflections
    case calendarSync
    case manifestationReminders
    case alternateIcons
    case advancedThemes
    case premiumWidgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedMoments:
            return "Unlimited moments"
        case .aiReflections:
            return "AI reflections"
        case .calendarSync:
            return "Calendar sync"
        case .manifestationReminders:
            return "Manifestation reminders"
        case .alternateIcons:
            return "Alternate app icons"
        case .advancedThemes:
            return "Advanced themes"
        case .premiumWidgets:
            return "Premium widgets"
        }
    }

    var paywallMessage: String {
        switch self {
        case .unlimitedMoments:
            return "Free includes 3 created moments. Upgrade to keep adding more."
        case .aiReflections:
            return "Free includes 3 AI generations. Upgrade to keep generating reflections and manifestations."
        case .calendarSync:
            return "Upgrade to sync future moments into your calendar."
        case .manifestationReminders:
            return "Upgrade to unlock manifestation reminder scheduling."
        case .alternateIcons:
            return ""
        case .advancedThemes:
            return "Upgrade to unlock deeper visual customization."
        case .premiumWidgets:
            return "Upgrade to unlock richer widget styles and premium presentation."
        }
    }

    var freeMomentLimit: Int? {
        switch self {
        case .unlimitedMoments:
            return 2
        case .aiReflections,
             .calendarSync,
             .manifestationReminders,
             .alternateIcons,
             .advancedThemes,
             .premiumWidgets:
            return nil
        }
    }
}

struct PremiumPackage: Identifiable, Equatable {
    let id: PremiumPackageID
    let priceTitle: String
    let periodTitle: String
    let badgeText: String?
    let ctaTitle: String
    let billingNote: String

    init(
        id: PremiumPackageID,
        priceTitle: String,
        periodTitle: String,
        badgeText: String?,
        ctaTitle: String,
        billingNote: String
    ) {
        self.id = id
        self.priceTitle = priceTitle
        self.periodTitle = periodTitle
        self.badgeText = badgeText
        self.ctaTitle = ctaTitle
        self.billingNote = billingNote
    }

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

    static func resolvedPackages(
        from packagesByID: [PremiumPackageID: RevenueCat.Package],
        fallback: [PremiumPackage]
    ) -> [PremiumPackage] {
        let orderedIDs = PremiumPackageID.allCases
        let resolved = orderedIDs.compactMap { id -> PremiumPackage? in
            guard let package = packagesByID[id] else { return nil }
            return PremiumPackage(
                id: id,
                package: package,
                monthlyPackage: packagesByID[.monthly]
            )
        }

        return resolved.isEmpty ? fallback : resolved
    }

    static func preferredSelection(
        availablePackageIDs: [PremiumPackageID],
        currentSelection: PremiumPackageID
    ) -> PremiumPackageID {
        if availablePackageIDs.contains(currentSelection) {
            return currentSelection
        }

        if availablePackageIDs.contains(.yearly) {
            return .yearly
        }

        return availablePackageIDs.first ?? .yearly
    }

    private init(
        id: PremiumPackageID,
        package: RevenueCat.Package,
        monthlyPackage: RevenueCat.Package?
    ) {
        let product = package.storeProduct
        let intro = product.introductoryDiscount

        self.id = id
        self.priceTitle = product.localizedPriceString
        self.periodTitle = Self.periodTitle(for: id, product: product)
        self.badgeText = Self.badgeText(for: id, package: package, monthlyPackage: monthlyPackage)
        self.ctaTitle = Self.ctaTitle(for: id, intro: intro)
        self.billingNote = Self.billingNote(for: id, product: product, intro: intro)
    }

    private static func periodTitle(for id: PremiumPackageID, product: StoreProduct) -> String {
        switch id {
        case .lifetime:
            return "Lifetime deal"
        case .monthly, .yearly:
            if let period = product.subscriptionPeriod {
                return "for \(localizedPeriod(period))"
            }

            return defaultPackages.first(where: { $0.id == id })?.periodTitle ?? ""
        }
    }

    private static func ctaTitle(
        for id: PremiumPackageID,
        intro: StoreProductDiscount?
    ) -> String {
        switch id {
        case .lifetime:
            return "Unlock Lifetime"
        case .monthly:
            if hasFreeTrial(intro) {
                return "Start free trial"
            }
            return "Continue with Monthly"
        case .yearly:
            if hasFreeTrial(intro) {
                return "Start free trial"
            }
            return "Continue with Yearly"
        }
    }

    private static func billingNote(
        for id: PremiumPackageID,
        product: StoreProduct,
        intro: StoreProductDiscount?
    ) -> String {
        switch id {
        case .lifetime:
            return "One-time payment of \(product.localizedPriceString)."
        case .monthly, .yearly:
            let renewalPeriod = product.subscriptionPeriod.map(localizedPeriod) ?? renewalLabel(for: id)

            if let intro,
               intro.paymentMode == .freeTrial {
                let trialPeriod = localizedDiscountPeriod(intro)
                return "Try free for \(trialPeriod), then \(product.localizedPriceString)/\(renewalPeriod)"
            }

            return "\(product.localizedPriceString) billed every \(renewalPeriod)."
        }
    }

    private static func badgeText(
        for id: PremiumPackageID,
        package: RevenueCat.Package,
        monthlyPackage: RevenueCat.Package?
    ) -> String? {
        guard id == .yearly,
              let monthlyPackage else { return nil }

        let monthlyProduct = monthlyPackage.storeProduct
        let yearlyProduct = package.storeProduct

        guard let monthlyPrice = decimal(from: monthlyProduct.pricePerYear),
              monthlyPrice.doubleValue > 0 else {
            return "Best Value"
        }

        let yearlyPrice = yearlyProduct.price as NSDecimalNumber
        let savings = 1 - (yearlyPrice.doubleValue / monthlyPrice.doubleValue)
        let percentage = Int((savings * 100).rounded())

        guard percentage >= 5 else { return "Best Value" }
        return "-\(percentage)%"
    }

    private static func hasFreeTrial(_ intro: StoreProductDiscount?) -> Bool {
        intro?.paymentMode == .freeTrial
    }

    private static func renewalLabel(for id: PremiumPackageID) -> String {
        switch id {
        case .monthly:
            return "month"
        case .yearly:
            return "year"
        case .lifetime:
            return "lifetime"
        }
    }

    private static func localizedPeriod(_ period: SubscriptionPeriod) -> String {
        let value = period.value
        let unit = switch period.unit {
        case .day:
            value == 1 ? "day" : "days"
        case .week:
            value == 1 ? "week" : "weeks"
        case .month:
            value == 1 ? "month" : "months"
        case .year:
            value == 1 ? "year" : "years"
        @unknown default:
            value == 1 ? "period" : "periods"
        }

        return "\(value) \(unit)"
    }

    private static func localizedDiscountPeriod(_ discount: StoreProductDiscount) -> String {
        let totalUnits = max(discount.numberOfPeriods, 1) * discount.subscriptionPeriod.value
        let totalPeriod = SubscriptionPeriod(value: totalUnits, unit: discount.subscriptionPeriod.unit)
        return localizedPeriod(totalPeriod)
    }

    private static func decimal(from value: NSDecimalNumber?) -> NSDecimalNumber? {
        guard let value, value != .notANumber else { return nil }
        return value
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

        return "Moments Plus"
    }

    static var privacyPolicyURL: URL? {
        normalizedURL(
            ProcessInfo.processInfo.environment["PRIVACY_POLICY_URL"]
                ?? Bundle.main.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String
        )
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

    private static func normalizedURL(_ value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.contains("$("),
              !placeholderURLs.contains(trimmed),
              let url = URL(string: trimmed) else {
            return nil
        }

        return url
    }

    private static let placeholderValues: Set<String> = [
        "apn_your_public_sdk_key"
    ]

    private static let placeholderURLs: Set<String> = [
        "https://example.com/privacy"
    ]
}
