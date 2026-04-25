import SwiftUI
import UIKit

struct MomentPreviewScrollEdgeView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
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
    @State private var hasRevealedDetailContent = false
    @State private var dragOffsetY: CGFloat = 0

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
            navigationCoordinator.setPreviewEditSheetPresented(false)
        }
        .onChange(of: viewModel.surfaceDisplayText) { _, newValue in
            if newValue.isEmpty {
                completedRevealStages.remove(0)
            } else {
                completedRevealStages.removeAll()
            }
        }
        .onChange(of: showingEditSheet) { _, isPresented in
            navigationCoordinator.setPreviewEditSheetPresented(isPresented)
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
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .fontWeight(.medium)
                .foregroundStyle(editButtonColor)
                .opacity(hasRevealedDetailContent ? 1 : 0)
                .offset(y: hasRevealedDetailContent ? 0 : 8)
                .animation(.easeOut(duration: 0.24).delay(0.08), value: hasRevealedDetailContent)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .opacity(hasRevealedDetailContent ? 1 : 0)
                .scaleEffect(hasRevealedDetailContent ? 1 : 0.92)
                .animation(.easeOut(duration: 0.24).delay(0.1), value: hasRevealedDetailContent)
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
            revealDetailContentIfNeeded()
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
        .offset(y: dragOffsetY)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18, coordinateSpace: .local)
                .onChanged { value in
                    guard value.translation.height > 0 else { return }
                    dragOffsetY = value.translation.height * 0.22
                }
                .onEnded { value in
                    let shouldDismiss =
                        value.translation.height > 140
                        || value.predictedEndTranslation.height > 220
                    if shouldDismiss {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            dragOffsetY = 0
                        }
                    }
                }
        )
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
                .opacity(hasRevealedDetailContent ? 1 : 0.18)
                .offset(y: hasRevealedDetailContent ? 0 : 24)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: viewModel.shouldShowReflectionCard)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: heroHeight)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: reflectionHeight)
                .animation(.easeOut(duration: 0.34).delay(0.08), value: hasRevealedDetailContent)
        }
        .scrollIndicators(.hidden)
    }

    private func primaryActionButton(for countdown: Countdown) -> some View {
        let requiresManifestationUpgrade = viewModel.requiresManifestationUpgrade(
            for: countdown,
            now: timerManager.currentTime,
            subscriptionService: subscriptionService
        )

        return MomentPreviewPrimaryActionButton(
            isLoading: viewModel.isLoadingReflection,
            isEnabled: requiresManifestationUpgrade
                || viewModel.isPrimaryActionEnabled(for: countdown, now: timerManager.currentTime),
            prefersResponsiveGlassStyle: prefersResponsiveGlassStyle(for: countdown),
            label: primaryActionButtonLabel(for: countdown),
            secondaryLabel: primaryActionButtonSecondaryLabel(for: countdown),
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
        let showsRegenerationHelper = shouldShowManifestationRegenerationHelper(for: countdown)

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
            VStack(spacing: 10) {
                if showsLockedManifestationAction(for: countdown) {
                    lockedManifestationActionButton(for: countdown)
                } else {
                    primaryActionButton(for: countdown)
                }

                if showsRegenerationHelper {
                    Text("Free includes 3 regenerations, one each day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func lockedManifestationActionButton(for countdown: Countdown) -> some View {
        Button(action: {}) {
            Text(primaryActionButtonLabel(for: countdown))
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .controlSize(.small)
        .buttonBorderShape(.capsule)
        .adaptiveGlassButtonStyle()
        .tint(primaryButtonColor)
        .foregroundStyle(.secondary)
        .disabled(true)
        .accessibilityHint("Available again tomorrow.")
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
            if viewModel.requiresManifestationUpgrade(
                for: countdown,
                now: timerManager.currentTime,
                subscriptionService: subscriptionService
            ) {
                return "Get Plus to Regenerate"
            }

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

        if countdown.isFutureManifestation {
            switch viewModel.manifestationRegenerationAvailability(
                for: countdown,
                now: timerManager.currentTime
            ) {
            case .available, .lockedUntilTomorrow:
                return title
            case .initialGeneration:
                break
            }
        }

        return title
    }

    private func primaryActionButtonSecondaryLabel(for countdown: Countdown) -> String? {
        guard !countdown.isFutureManifestation,
              viewModel.errorText == nil,
              viewModel.isPrimaryActionEnabled(for: countdown, now: timerManager.currentTime),
              !subscriptionService.isPremium,
              subscriptionService.freeAIGenerationsRemaining > 0 else {
            return nil
        }

        let remaining = subscriptionService.freeAIGenerationsRemaining
        let noun = remaining == 1 ? "generation" : "generations"
        return "\(remaining) \(noun) available"
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

    private func prefersResponsiveGlassStyle(for countdown: Countdown) -> Bool {
        guard countdown.isFutureManifestation else { return false }

        if case .lockedUntilTomorrow = viewModel.manifestationRegenerationAvailability(
            for: countdown,
            now: timerManager.currentTime
        ) {
            return true
        }

        return false
    }

    private func shouldShowManifestationRegenerationHelper(for countdown: Countdown) -> Bool {
        guard countdown.isFutureManifestation else { return false }
        guard !subscriptionService.isPremium else { return false }

        switch viewModel.manifestationRegenerationAvailability(
            for: countdown,
            now: timerManager.currentTime
        ) {
        case .initialGeneration:
            return false
        case .available, .lockedUntilTomorrow:
            return true
        }
    }

    private func showsLockedManifestationAction(for countdown: Countdown) -> Bool {
        guard countdown.isFutureManifestation else { return false }
        guard !viewModel.requiresManifestationUpgrade(
            for: countdown,
            now: timerManager.currentTime,
            subscriptionService: subscriptionService
        ) else {
            return false
        }

        if case .lockedUntilTomorrow = viewModel.manifestationRegenerationAvailability(
            for: countdown,
            now: timerManager.currentTime
        ) {
            return true
        }

        return false
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
        let requiresManifestationUpgrade = viewModel.requiresManifestationUpgrade(
            for: countdown,
            now: timerManager.currentTime,
            subscriptionService: subscriptionService
        )

        guard requiresManifestationUpgrade
            || viewModel.isPrimaryActionEnabled(for: countdown, now: timerManager.currentTime) else {
            return
        }

        if requiresManifestationUpgrade {
            paywallFeature = .aiReflections
        } else if subscriptionService.shouldPresentUpgrade(for: .aiReflections) {
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

private extension MomentPreviewScrollEdgeView {
    func revealDetailContentIfNeeded() {
        guard !hasRevealedDetailContent else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.3)) {
                hasRevealedDetailContent = true
            }
        }
    }
}
