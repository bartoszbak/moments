import SwiftUI
import UIKit

struct MomentPreviewScrollEdgeView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.backgroundGradientEnabled) private var backgroundGradientEnabled = AppSettingsDefaults.backgroundGradientEnabled

    @StateObject private var viewModel: MomentPreviewViewModel
    @State private var showingEditSheet = false
    @State private var paywallFeature: PremiumFeature?
    @State private var completedRevealStages: Set<Int> = []
    @State private var heroHeight: CGFloat = 0
    @State private var reflectionHeight: CGFloat = 0

    init(countdownID: UUID) {
        self.countdownID = countdownID
        _viewModel = StateObject(wrappedValue: MomentPreviewViewModel(countdownID: countdownID))
    }

    private var countdown: Countdown? {
        repository.countdowns.first { $0.id == countdownID }
    }

    var body: some View {
        Group {
            if let countdown {
                previewScreen(for: countdown)
            } else {
                ContentUnavailableView("Moment not found", systemImage: "exclamationmark.triangle")
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onDisappear {
            viewModel.cancelReflection()
        }
        .onChange(of: viewModel.surfaceDisplayText) { _, newValue in
            if newValue.isEmpty {
                completedRevealStages.remove(0)
            } else {
                completedRevealStages.removeAll()
            }
        }
    }

    private func previewScreen(for countdown: Countdown) -> some View {
        GeometryReader { proxy in
            let baseScreen = ZStack {
                previewBackground
                    .ignoresSafeArea()

                previewScrollView(
                    for: countdown,
                    viewportWidth: proxy.size.width,
                    viewportHeight: proxy.size.height
                )
            }

            baseScreen.safeAreaInset(
                edge: .bottom,
                spacing: 0,
                content: {
                    bottomInsetContent(
                        for: countdown,
                        viewportWidth: proxy.size.width,
                        bottomSafeAreaInset: proxy.safeAreaInsets.bottom
                    )
                }
            )
        }
        .navigationTitle("Moment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .fontWeight(.medium)
                .foregroundStyle(editButtonColor)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCountdownView(countdownID: countdownID) {
                showingEditSheet = false
                dismiss()
            }
        }
        .sheet(item: $paywallFeature) { feature in
            PremiumPaywallView(highlightedFeature: feature)
        }
        .onAppear {
            viewModel.syncSavedReflection(from: countdown)
        }
        .onChange(of: repository.countdowns) { _, _ in
            guard let updatedCountdown = self.countdown else {
                if !showingEditSheet {
                    dismiss()
                }
                return
            }
            viewModel.syncSavedReflection(from: updatedCountdown)
        }
    }

    @ViewBuilder
    private func previewScrollView(
        for countdown: Countdown,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Color.clear
                    .frame(height: heroTopSpacing(for: countdown, viewportHeight: viewportHeight))

                MomentPreviewHeroSection(
                    countdown: countdown,
                    currentTime: timerManager.currentTime,
                    previewSymbolColor: previewSymbolColor
                )
                    .background(HeightMeasurementView(height: $heroHeight))

                if viewModel.shouldShowReflectionCard {
                    MomentPreviewReflectionSection(
                        countdown: countdown,
                        viewModel: viewModel,
                        onSurfaceRevealCompleted: handleSurfaceRevealCompleted,
                        onRevealCompleted: handleRevealCompleted
                    )
                        .background(HeightMeasurementView(height: $reflectionHeight))
                }

                Spacer(minLength: 0)
            }
                .frame(
                    maxWidth: readableContentWidth(
                        for: viewportWidth,
                        horizontalPadding: 32
                    ),
                    alignment: .leading
                )
                .frame(
                    minHeight: max(viewportHeight - 28 - bottomContentPadding(for: countdown), 0),
                    alignment: .top
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(minHeight: viewportHeight, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, bottomContentPadding(for: countdown))
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: viewModel.shouldShowReflectionCard)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: heroHeight)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: reflectionHeight)
        }
        .scrollIndicators(.hidden)
    }

    private func primaryActionButton(for countdown: Countdown) -> some View {
        MomentPreviewPrimaryActionButton(
            isLoading: viewModel.isLoadingReflection,
            isEnabled: viewModel.isPrimaryActionEnabled(for: countdown, now: timerManager.currentTime),
            label: primaryActionButtonLabel(for: countdown),
            foregroundColor: primaryButtonForegroundColor,
            backgroundColor: primaryButtonColor,
            disabledBackgroundColor: disabledPrimaryActionBackgroundColor(for: countdown),
            loadingForegroundColor: loadingActionButtonForegroundColor,
            loadingBackgroundColor: loadingActionButtonBackgroundColor,
            action: {
                handlePrimaryAction(for: countdown)
            }
        )
    }

    @ViewBuilder
    private func bottomInsetContent(
        for countdown: Countdown,
        viewportWidth: CGFloat,
        bottomSafeAreaInset: CGFloat
    ) -> some View {
        BottomGlassActionBar(
            showsPrimaryAction: viewModel.showsBottomPrimaryAction(
                for: countdown,
                now: timerManager.currentTime
            ),
            maxContentWidth: readableContentWidth(
                for: viewportWidth,
                horizontalPadding: 24
            ),
            bottomSafeAreaInset: bottomSafeAreaInset,
            bottomBlurGradientHeight: bottomBlurGradientHeight(for: countdown)
        ) {
            primaryActionButton(for: countdown)
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        if backgroundGradientEnabled {
            LinearGradient(
                colors: [leadingBackgroundColor, trailingBackgroundColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(.systemBackground)
        }
    }

    private func readableContentWidth(for viewportWidth: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return .infinity }
        return min(700, max(viewportWidth - (horizontalPadding * 2), 0))
    }

    private func primaryActionTitle(for countdown: Countdown) -> String {
        if viewModel.errorText != nil {
            return "Try Again"
        }

        if countdown.isFutureManifestation {
            switch viewModel.manifestationRegenerationAvailability(
                for: countdown,
                now: timerManager.currentTime
            ) {
            case .initialGeneration:
                return "Get Manifestation"
            case .available:
                return "Regenerate"
            case .lockedUntilTomorrow:
                return "Regenerate Tomorrow"
            }
        }

        return countdown.isExpired(at: timerManager.currentTime) ? "Look Back" : "Set Intention"
    }

    private func primaryActionButtonLabel(for countdown: Countdown) -> String {
        let title = primaryActionTitle(for: countdown)

        guard viewModel.errorText == nil,
              viewModel.isPrimaryActionEnabled(for: countdown, now: timerManager.currentTime),
              !subscriptionService.isPremium,
              subscriptionService.freeAIGenerationsRemaining > 0 else {
            return title
        }

        return "\(title) (\(subscriptionService.freeAIGenerationsRemaining) available)"
    }

    private var previewSymbolColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.72)
            : Color.black.opacity(0.42)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var leadingBackgroundColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex).opacity(0.33)
    }

    private var trailingBackgroundColor: Color {
        effectiveColorScheme == .dark ? .black : .white
    }

    private var editButtonColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var primaryButtonColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex)
    }

    private var primaryButtonForegroundColor: Color {
        primaryButtonColor.prefersLightForeground ? .white : .black
    }

    private var loadingActionButtonBackgroundColor: Color {
        Color(uiColor: .tertiarySystemFill)
    }

    private var loadingActionButtonForegroundColor: Color {
        .primary
    }

    private func disabledPrimaryActionBackgroundColor(for countdown: Countdown) -> Color? {
        guard countdown.isFutureManifestation else { return nil }

        switch viewModel.manifestationRegenerationAvailability(
            for: countdown,
            now: timerManager.currentTime
        ) {
        case .lockedUntilTomorrow:
            return Color(uiColor: .systemGray3)
        case .initialGeneration, .available:
            return nil
        }
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private func bottomContentPadding(for countdown: Countdown) -> CGFloat {
        if #available(iOS 26, *) {
            return viewModel.showsBottomPrimaryAction(for: countdown, now: timerManager.currentTime) ? 112 : 44
        } else {
            return 28
        }
    }

    private func heroTopSpacing(for countdown: Countdown, viewportHeight: CGFloat) -> CGFloat {
        guard shouldCenterHeroVertically else { return 0 }
        guard heroHeight > 0 else { return 0 }

        let availableHeight = max(viewportHeight - 28 - bottomContentPadding(for: countdown), 0)
        let contentHeight = heroHeight + reflectionSectionHeight
        return max((availableHeight - contentHeight) / 2, 0)
    }

    private var reflectionSectionHeight: CGFloat {
        guard viewModel.shouldShowReflectionCard else { return 0 }
        return reflectionHeight > 0 ? reflectionHeight + 28 : 0
    }

    private var shouldCenterHeroVertically: Bool {
        !viewModel.shouldShowReflectionCard || countdown?.isFutureManifestation == true
    }

    private func handlePrimaryAction(for countdown: Countdown) {
        guard viewModel.isPrimaryActionEnabled(for: countdown, now: timerManager.currentTime) else {
            return
        }

        if subscriptionService.shouldPresentUpgrade(for: .aiReflections) {
            paywallFeature = .aiReflections
        } else {
            viewModel.generateReflection(
                for: countdown,
                timerManager: timerManager,
                repository: repository,
                subscriptionService: subscriptionService
            )
        }
    }

    private func handleSurfaceRevealCompleted() {
        handleRevealCompleted(for: 0)
    }

    private func handleRevealCompleted(for stage: Int) {
        guard !completedRevealStages.contains(stage) else { return }
        guard stage == viewModel.expansionStage else { return }
        completedRevealStages.insert(stage)

        guard stage < viewModel.maxExpansionStage else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard viewModel.expansionStage == stage else { return }

            withAnimation(.smooth(duration: 0.28)) {
                viewModel.expansionStage += 1
            }
        }
    }

    private func bottomBlurGradientHeight(for countdown: Countdown) -> CGFloat {
        viewModel.showsBottomPrimaryAction(for: countdown, now: timerManager.currentTime) ? 52 : 40
    }
}
