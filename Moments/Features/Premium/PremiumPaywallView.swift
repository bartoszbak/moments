import SwiftUI
import UIKit

struct PremiumPaywallView: View {
    let highlightedFeature: PremiumFeature?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionService: SubscriptionService

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex

    @State private var alertItem: PremiumAlertItem?
    @State private var subscriberBadgeRotation = 0.0

    private let features: [PremiumFeatureRow] = [
        .init(iconName: "book.pages.fill", title: "Unlimited moments"),
        .init(iconName: "sparkle", title: "AI manifestations, and reflections"),
        .init(iconName: "paintpalette.fill", title: "Full customization options"),
        .init(iconName: "calendar.badge", title: "Calendar sync and notifications"),
        .init(iconName: "plus.capsule.fill", title: "Future premium features")
    ]

    init(highlightedFeature: PremiumFeature? = nil) {
        self.highlightedFeature = highlightedFeature
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let contentMaxWidth: CGFloat = {
                    let candidateWidth = proxy.size.width - 48
                    guard candidateWidth.isFinite else { return 0 }
                    return min(max(candidateWidth, 0), 420)
                }()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 28) {
                            heroSection
                            includedCard
                            legalRow
                        }
                        .frame(maxWidth: contentMaxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    bottomCheckoutRail
                }
                .background(paywallBackground.ignoresSafeArea())
            }
            .navigationTitle("Get Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(toolbarButtonColor)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(preferredColorScheme)
        .task {
            await subscriptionService.refreshOfferings()
        }
        .onChange(of: subscriptionService.accessState) { _, newValue in
            if case .premium = newValue {
                dismiss()
            }
        }
        .alert(item: $alertItem) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var heroSection: some View {
        VStack(spacing: 18) {
            HStack(spacing: -32) {
                Image("AppIconRainbowPreview")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    }

                Image(subscriberBadgeAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 97, height: 97)
                    .rotationEffect(.degrees(subscriberBadgeRotation))
            }
            .frame(maxWidth: .infinity)

            Text("Support Moments\nunlock the Plus experience")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let highlightedFeature,
               !highlightedFeature.paywallMessage.isEmpty {
                Text(highlightedFeature.paywallMessage)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard subscriberBadgeRotation == 0 else { return }

            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                subscriberBadgeRotation = 360
            }
        }
    }

    private var includedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("What’s included")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                PremiumPill()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: feature.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)

                        Text(feature.title)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()

            Text("By supporting Moments, you support work of\nindependent engineer")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .systemGroupedBackground))
        )
    }

    private var legalRow: some View {
        HStack(spacing: 24) {
            legalButton(title: "Restore Purchase", action: handleRestoreTapped)
            if showsManageSubscriptionsAction {
                legalButton(title: "Manage", action: handleManageSubscriptionsTapped)
            }
            legalButton(title: "Terms", action: handleTermsTapped)
            legalButton(title: "Privacy Policy", action: handlePrivacyTapped)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
    }

    private func legalButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
    }

    private var bottomCheckoutRail: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(subscriptionService.packages) { package in
                                PremiumOfferCard(
                                    package: package,
                                    isSelected: subscriptionService.selectedPackageID == package.id,
                                    selectedIconColor: selectedOfferIconColor,
                                    action: { subscriptionService.select(packageID: package.id) }
                                )
                            }
                        }
                .padding(.horizontal, 16)
            }

            Button {
                handlePrimaryActionTapped()
            } label: {
                Text(subscriptionService.selectedPackage.ctaTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryButtonLabelColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(primaryButtonColor)
                    )
            }
            .buttonStyle(.plain)
            .shadow(color: primaryButtonColor.opacity(0.28), radius: 16, y: 8)
            .padding(.horizontal, 24)

            Text(subscriptionService.selectedPackage.billingNote)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.08), radius: 20, y: -2)
        )
    }

    private var paywallBackground: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color(uiColor: .systemBackground),
                AppTheme.baseInterfaceTintColor(from: interfaceTintHex).opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var primaryButtonColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex)
    }

    private var primaryButtonLabelColor: Color {
        primaryButtonColor.prefersLightForeground ? .white : .black
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var toolbarButtonColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var selectedOfferIconColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var subscriberBadgeAssetName: String {
        effectiveColorScheme == .dark ? "SubscriberBadgeDark" : "SubscriberBadge"
    }

    private func handlePrimaryActionTapped() {
        AppHaptics.impact(.medium)

        Task { @MainActor in
            do {
                try await subscriptionService.purchaseSelectedPackage()
            } catch {
                if case SubscriptionActionError.userCancelled = error {
                    return
                }

                alertItem = .init(
                    title: "Purchase unavailable",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func handleRestoreTapped() {
        AppHaptics.impact(.light)

        Task { @MainActor in
            do {
                let outcome = try await subscriptionService.restorePurchases()

                switch outcome {
                case .restoredPremium:
                    alertItem = .init(
                        title: "Purchases restored",
                        message: "Your premium access is active again."
                    )
                case .nothingToRestore:
                    alertItem = .init(
                        title: "Nothing to restore",
                        message: "No previous Moments Plus purchase was found for this App Store account."
                    )
                }
            } catch {
                alertItem = .init(
                    title: "Restore unavailable",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func handleTermsTapped() {
        guard let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") else {
            return
        }

        openURL(url)
    }

    private var showsManageSubscriptionsAction: Bool {
        if case .premium(.subscription) = subscriptionService.accessState {
            return true
        }

        return false
    }

    private func handleManageSubscriptionsTapped() {
        guard let url = subscriptionService.manageSubscriptionsURL else {
            alertItem = .init(
                title: "Subscription link unavailable",
                message: "Apple subscription management is not available right now."
            )
            return
        }

        openURL(url)
    }

    private func handlePrivacyTapped() {
        guard let url = subscriptionService.privacyPolicyURL else {
            AppHaptics.impact(.light)
            alertItem = .init(
                title: "Privacy policy link needed",
                message: "Configure PRIVACY_POLICY_URL to enable the app-specific privacy policy link."
            )
            return
        }

        openURL(url)
    }
}

private struct PremiumOfferCard: View {
    let package: PremiumPackage
    let isSelected: Bool
    let selectedIconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: selectionSymbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? selectedIconColor : .secondary)

                    Text(package.priceTitle)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if let badgeText = package.badgeText {
                        Text(badgeText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemGroupedBackground))
                            )
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                Text(package.periodTitle)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(minWidth: package.minimumCardWidth, alignment: .leading)
            .padding(16)
            .background(cardBackground)
            .overlay(cardBorder)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private var selectionSymbolName: String {
        isSelected ? "checkmark.circle.fill" : "circle"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isSelected ? Color(uiColor: .systemBackground) : Color(uiColor: .systemGroupedBackground))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(isSelected ? Color.primary.opacity(0.24) : .clear, lineWidth: 1)
    }
}

private struct PremiumFeatureRow: Identifiable {
    let iconName: String
    let title: String

    var id: String { title }
}

private struct PremiumAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    PremiumPaywallView()
        .environmentObject(SubscriptionService.shared)
}
