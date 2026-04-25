import BlurSwiftUI
import CoreMotion
import SwiftUI

struct CountdownListView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(DeveloperSettingsKeys.showEmptyStatePreview) private var showEmptyStatePreview = false
    @AppStorage(DeveloperSettingsKeys.forceIntroSheetOnLaunch) private var forceIntroSheetOnLaunch = false
    @AppStorage(DeveloperSettingsKeys.forceAboutSheetOnLaunch) private var forceAboutSheetOnLaunch = false
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.backgroundGradientEnabled) private var backgroundGradientEnabled = AppSettingsDefaults.backgroundGradientEnabled
    @AppStorage(AppSettingsKeys.hasSeenAboutSheet) private var hasSeenAboutSheet = AppSettingsDefaults.hasSeenAboutSheet
    @AppStorage(AppSettingsKeys.hasSeenIntroSheet) private var hasSeenIntroSheet = AppSettingsDefaults.hasSeenIntroSheet
    @State private var showingAddSheet = false
    @State private var previewingCountdown: Countdown?
    @State private var showingSettings = false
    @State private var showingIntroSheet = false
    @State private var showingAboutSheet = false
    @State private var paywallFeature: PremiumFeature?
    @State private var selectedFilter: CountdownMenuFilter = .all
    @State private var momentCountDisplayText = ""
    @State private var pendingMomentCountReveal = false
    @State private var momentCountRevealTrigger = 0
    @State private var lastHandledAddMomentRequestToken = 0
    @Namespace private var cardZoomNamespace

    private var isiPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var gridSpacing: CGFloat {
        isiPad ? 24 : 16
    }

    private var gridHorizontalPadding: CGFloat {
        isiPad ? 24 : 16
    }

    private func gridColumns(for size: CGSize) -> [GridItem] {
        let columnCount = if isiPad {
            size.width > size.height ? 4 : 2
        } else {
            2
        }

        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }

    private var isShowingPrimaryEmptyState: Bool {
        repository.countdowns.isEmpty || isShowingEmptyStatePreview
    }

    private var isShowingEmptyStatePreview: Bool {
        showEmptyStatePreview && !repository.countdowns.isEmpty
    }

    private var displayedCountdowns: [Countdown] {
        isShowingEmptyStatePreview ? [] : filteredCountdowns
    }

    private var filteredCountdowns: [Countdown] {
        repository.countdowns.filter { countdown in
            matchesSelectedFilter(countdown)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ScrollView {
                    if !displayedCountdowns.isEmpty {
                        countdownGrid(in: geometry.size)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 1)
                    }
                }
                .scrollIndicators(.hidden)
                .background(mainBackgroundView)
                .navigationTitle(isShowingPrimaryEmptyState ? "" : "Moments")
                .navigationBarTitleDisplayMode(isShowingPrimaryEmptyState ? .inline : .large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .fontWeight(.semibold)
                                .foregroundStyle(settingsButtonColor)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomInsetContent(bottomSafeAreaInset: geometry.safeAreaInsets.bottom)
                }
                .overlay {
                    if isShowingPrimaryEmptyState {
                        emptyLibraryView
                    } else if filteredCountdowns.isEmpty {
                        ContentUnavailableView {
                            VStack(spacing: 12) {
                                Image(systemName: "app.badge")
                                    .font(.system(size: 36, weight: .medium))

                                Text(filteredEmptyStateMessage)
                                    .font(.title3.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.primary)
                        } description: {
                            EmptyView()
                        }
                    }
                }
                .navigationDestination(item: $previewingCountdown) { countdown in
                    MomentPreviewScrollEdgeView(countdownID: countdown.id)
                        .applyCardZoomNavigationTransition(
                            sourceID: countdown.id,
                            in: cardZoomNamespace
                        )
                }
            }
        }
        .onChange(of: selectedFilter) {
            AppHaptics.impact(.light)
            syncMomentCountDisplayTextIfNeeded()
        }
        .onChange(of: forceIntroSheetOnLaunch) { _, _ in
            updateLaunchSheetPresentation()
        }
        .onChange(of: forceAboutSheetOnLaunch) { _, _ in
            updateLaunchSheetPresentation()
        }
        .onChange(of: navigationCoordinator.pendingPreviewCountdownID) { _, _ in
            openDeepLinkedCountdownIfNeeded()
        }
        .onChange(of: navigationCoordinator.isPreviewEditSheetPresented) { _, _ in
            openDeepLinkedCountdownIfNeeded()
        }
        .onChange(of: navigationCoordinator.addMomentRequestToken) { _, _ in
            handlePendingAddMomentRequestIfNeeded()
        }
        .onChange(of: repository.countdowns) { _, _ in
            openDeepLinkedCountdownIfNeeded()
            syncMomentCountDisplayTextIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownCreated)) { _ in
            pendingMomentCountReveal = true
        }
        .task {
            updateLaunchSheetPresentation()
            openDeepLinkedCountdownIfNeeded()
            handlePendingAddMomentRequestIfNeeded()
            syncMomentCountDisplayTextIfNeeded(force: true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $paywallFeature) { feature in
            PremiumPaywallView(highlightedFeature: feature)
                .environmentObject(subscriptionService)
        }
        .sheet(isPresented: $showingIntroSheet) {
            IntroSheetView {
                hasSeenIntroSheet = true
                showingIntroSheet = false
            }
        }
        .aboutSheet(isPresented: $showingAboutSheet)
        .sheet(
            isPresented: $showingAddSheet,
            onDismiss: handleAddSheetDismissed
        ) {
            AddCountdownView()
        }
    }

    private func delete(_ countdown: Countdown) {
        try? repository.delete(countdown)
        AppHaptics.impact(.medium)
    }

    private func openDeepLinkedCountdownIfNeeded() {
        guard !navigationCoordinator.isPreviewEditSheetPresented else {
            return
        }

        guard let id = navigationCoordinator.pendingPreviewCountdownID,
              let countdown = repository.countdowns.first(where: { $0.id == id })
        else {
            return
        }

        dismissTransientSheetsForExternalPresentation()
        previewingCountdown = countdown
        navigationCoordinator.clearPendingPreviewCountdownID()
    }

    @ViewBuilder
    private func countdownGrid(in size: CGSize) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: gridSpacing) {
                tileGridContent(in: size)
            }
            .padding(.horizontal, gridHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 92)
        } else {
            tileGridContent(in: size)
                .padding(.horizontal, gridHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 92)
        }
    }

    private func tileGridContent(in size: CGSize) -> some View {
        LazyVGrid(columns: gridColumns(for: size), spacing: gridSpacing) {
            ForEach(displayedCountdowns) { countdown in
                Button {
                    openCountdown(countdown)
                } label: {
                    CountdownTileView(
                        countdown: countdown,
                        currentTime: timerManager.currentTime
                    )
                }
                .applyCardZoomTransitionSource(
                    sourceID: countdown.id,
                    in: cardZoomNamespace
                )
                .buttonStyle(.plain)
                .id(countdown.id)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }

    private var filteredEmptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "Moments will show here when added."
        case .past:
            return "Past events will show here when added."
        case .upcoming:
            return "Future events will show here when added."
        case .present:
            return "Manifestations will show here when added."
        }
    }

    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Spacer()

            EmptyStateArtworkView()

            Text("No moments to wait for\nor reflect on")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var emptyStateButton: some View {
        Button(action: presentAddCountdown) {
            Text("Add first event")
                .font(.headline.weight(.semibold))
                .foregroundStyle(emptyStateButtonForegroundColor)
                .lineLimit(1)
                .padding(.horizontal, 28)
                .frame(height: 56)
                .frame(minWidth: 200)
                .frame(maxWidth: emptyStateButtonWidth)
                .background(
                    Capsule()
                        .fill(emptyStateButtonBackgroundColor)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func bottomInsetContent(bottomSafeAreaInset: CGFloat) -> some View {
        if isShowingPrimaryEmptyState {
            emptyStateButton
        } else if !repository.countdowns.isEmpty && !isShowingEmptyStatePreview {
            if #available(iOS 26, *) {
                ZStack(alignment: .bottom) {
                    VariableBlur(direction: .up)
                        .maximumBlurRadius(2)
                        .blurStartingInset(nil)
                        .dimmingTintColor(nil)
                        .dimmingAlpha(nil)
                        .dimmingOvershoot(nil)
                        .dimmingStartingInset(nil)
                        .passesTouchesThrough(true)
                        .frame(maxWidth: .infinity)
                        .frame(height: bottomBlurGradientHeight + (bottomSafeAreaInset * 2))
                        .offset(y: bottomSafeAreaInset)

                    LinearGradient(
                        stops: [
                            .init(color: Color(uiColor: .systemBackground).opacity(0), location: 0),
                            .init(color: Color(uiColor: .systemBackground).opacity(1), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: bottomBlurGradientHeight + (bottomSafeAreaInset * 2))
                    .offset(y: bottomSafeAreaInset)
                    .allowsHitTesting(false)

                    HStack(spacing: 16) {
                        filterMenuButton
                        Spacer(minLength: 0)
                        momentCountLabel
                        Spacer(minLength: 0)
                        addButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
            } else {
                HStack(spacing: 16) {
                    filterMenuButton
                    Spacer(minLength: 0)
                    momentCountLabel
                    Spacer(minLength: 0)
                    addButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
            }
        }
    }

    private var emptyStateButtonWidth: CGFloat? {
        isiPad ? 360 : nil
    }

    @available(iOS 26.0, *)
    private var bottomBlurGradientHeight: CGFloat {
        52
    }

    private var filterMenuButton: some View {
        Menu {
            ForEach(CountdownMenuFilter.allCases) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    HStack {
                        Text(filter.title)
                        if selectedFilter == filter {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: isShowingActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(settingsButtonColor)
                .frame(width: 44, height: 44)
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Filter countdowns")
    }

    private var isShowingActiveFilters: Bool {
        selectedFilter != .all
    }

    private var addButton: some View {
        Button {
            presentAddCountdown()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(addButtonSymbolColor)
                .frame(width: 44, height: 44)
        }
        .id(themeRefreshKey)
        .tint(addButtonBackgroundColor)
        .adaptiveGlassProminentButtonStyle()
        .accessibilityLabel("Add countdown")
    }

    private var momentCountLabel: some View {
        SingleRunLetterRevealText(
            text: momentCountDisplayText,
            font: .subheadline.weight(.medium),
            color: .secondary,
            trigger: momentCountRevealTrigger
        )
        .lineLimit(1)
    }

    private var momentCountText: String {
        let count = displayedCountdowns.count
        return count == 1 ? "1 moment" : "\(count) moments"
    }

    private var interfaceTintColor: Color {
        AppTheme.interfaceTintColor(from: interfaceTintHex, for: effectiveColorScheme)
    }

    private var leadingBackgroundColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex).opacity(0.33)
    }

    private var trailingBackgroundColor: Color {
        effectiveColorScheme == .dark ? .black : .white
    }

    @ViewBuilder
    private var mainBackgroundView: some View {
        if backgroundGradientEnabled {
            LinearGradient(
                colors: [leadingBackgroundColor, trailingBackgroundColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        } else {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var themeRefreshKey: String {
        "\(appearanceSetting)-\(interfaceTintHex)-\(effectiveColorScheme == .dark ? "dark" : "light")"
    }

    private var settingsButtonColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var addButtonBackgroundColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex)
    }

    private var addButtonSymbolColor: Color {
        addButtonBackgroundColor.prefersLightForeground ? .white : .black
    }

    private var emptyStateButtonBackgroundColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex)
    }

    private var emptyStateButtonForegroundColor: Color {
        emptyStateButtonBackgroundColor.prefersLightForeground ? .white : .black
    }

    private func presentAddCountdown() {
        AppHaptics.impact(.medium)
        if subscriptionService.shouldShowCreationUpsell {
            paywallFeature = .unlimitedMoments
            return
        }

        showingAddSheet = true
    }

    private func presentAddCountdownFromExternalTrigger() {
        dismissTransientSheetsForExternalPresentation()
        presentAddCountdown()
    }

    private func handlePendingAddMomentRequestIfNeeded() {
        let requestToken = navigationCoordinator.addMomentRequestToken
        guard requestToken > lastHandledAddMomentRequestToken else { return }
        lastHandledAddMomentRequestToken = requestToken
        presentAddCountdownFromExternalTrigger()
    }

    private func dismissTransientSheetsForExternalPresentation() {
        showingSettings = false
        showingIntroSheet = false
        showingAboutSheet = false
    }

    private func updateLaunchSheetPresentation() {
        if forceAboutSheetOnLaunch {
            showingAboutSheet = true
            showingIntroSheet = false
            return
        }

        if forceIntroSheetOnLaunch {
            showingIntroSheet = true
            showingAboutSheet = false
            return
        }

        showingAboutSheet = !hasSeenAboutSheet
        showingIntroSheet = false
    }

    private func handleAddSheetDismissed() {
        guard pendingMomentCountReveal else { return }
        pendingMomentCountReveal = false
        momentCountDisplayText = momentCountText
        momentCountRevealTrigger += 1
    }

    private func syncMomentCountDisplayTextIfNeeded(force: Bool = false) {
        guard force || (!showingAddSheet && !pendingMomentCountReveal) else { return }
        momentCountDisplayText = momentCountText
    }

    private func openCountdown(_ countdown: Countdown) {
        AppHaptics.impact(.soft)
        previewingCountdown = countdown
    }

    private func matchesSelectedFilter(_ countdown: Countdown) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .past:
            return !countdown.isFutureManifestation && countdown.isExpired(at: timerManager.currentTime)
        case .upcoming:
            return !countdown.isFutureManifestation && !countdown.isExpired(at: timerManager.currentTime)
        case .present:
            return countdown.isFutureManifestation
        }
    }
}

private extension View {
    @ViewBuilder
    func applyCardZoomTransitionSource(sourceID: UUID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(
                id: sourceID,
                in: namespace
            ) { source in
                source
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyCardZoomNavigationTransition(sourceID: UUID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(
                .zoom(
                    sourceID: sourceID,
                    in: namespace
                )
            )
        } else {
            self
        }
    }
}

private struct SingleRunLetterRevealText: View {
    let text: String
    let font: Font
    let color: Color
    let trigger: Int

    @State private var revealedCharacterCount = Int.max
    @State private var revealTask: Task<Void, Never>?

    private var characters: [String] {
        text.map(String.init)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                Text(character)
                    .font(font)
                    .foregroundStyle(color)
                    .opacity(index < revealedCharacterCount ? 1 : 0)
                    .blur(radius: index < revealedCharacterCount ? 0 : 12)
                    .offset(y: index < revealedCharacterCount ? 0 : 4)
                    .animation(
                        .easeOut(duration: 0.28).delay(Double(index) * 0.028),
                        value: revealedCharacterCount
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            revealedCharacterCount = characters.count
        }
        .onChange(of: text) { _, _ in
            revealedCharacterCount = characters.count
        }
        .onChange(of: trigger) { _, _ in
            startReveal()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func startReveal() {
        revealTask?.cancel()
        revealedCharacterCount = 0

        guard !characters.isEmpty else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(45))
            guard !Task.isCancelled else { return }
            revealedCharacterCount = characters.count
        }
    }
}

private enum CountdownMenuFilter: String, CaseIterable, Identifiable {
    case all
    case past
    case upcoming
    case present

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "All"
        case .past:
            "Past moments"
        case .upcoming:
            "Upcoming moments"
        case .present:
            "Manifestations"
        }
    }
}

#Preview {
    CountdownListView()
        .environmentObject(CountdownRepository(
            viewContext: PersistenceController.preview.container.viewContext,
            backgroundContext: PersistenceController.preview.newBackgroundContext()
        ))
        .environmentObject(TimerManager())
        .environmentObject(AppNavigationCoordinator.shared)
}

private struct EmptyStateArtworkView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var motionController = EmptyStateMotionController()

    private let imageSize: CGFloat = 96
    private let cornerRadius: CGFloat = 22

    var body: some View {
        Image("EmptyState")
            .resizable()
            .scaledToFit()
            .frame(width: imageSize, height: imageSize)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            }
            .scaleEffect(isMotionEnabled ? 1.04 : 1)
            .offset(x: translation.width, y: translation.height)
            .rotation3DEffect(
                .degrees(Double(-motionController.tilt.height * 7)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(Double(motionController.tilt.width * 7)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .shadow(
                color: .black.opacity(isMotionEnabled ? 0.16 : 0.1),
                radius: 18,
                x: 0,
                y: 14 - (translation.height * 0.2)
            )
            .onAppear {
                updateMotionState(isEnabled: isMotionEnabled)
            }
            .onDisappear {
                motionController.stop()
            }
            .onChange(of: isMotionEnabled) { _, isEnabled in
                updateMotionState(isEnabled: isEnabled)
            }
    }

    private var isMotionEnabled: Bool {
        !reduceMotion
    }

    private var translation: CGSize {
        CGSize(
            width: motionController.tilt.width * 8,
            height: motionController.tilt.height * 6
        )
    }

    private func updateMotionState(isEnabled: Bool) {
        if isEnabled {
            motionController.start()
        } else {
            motionController.stop()
        }
    }
}

private final class EmptyStateMotionController: ObservableObject {
    @Published var tilt: CGSize = .zero

    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.tillappcounter.Moments.empty-state-motion"
        queue.qualityOfService = .userInteractive
        return queue
    }()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }

            let roll = Self.clamped(motion.attitude.roll / 0.55)
            let pitch = Self.clamped(motion.attitude.pitch / 0.7)
            let targetTilt = CGSize(width: roll, height: -pitch)

            DispatchQueue.main.async {
                self.tilt = CGSize(
                    width: (self.tilt.width * 0.84) + (targetTilt.width * 0.16),
                    height: (self.tilt.height * 0.84) + (targetTilt.height * 0.16)
                )
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()

        withAnimation(.spring(duration: 0.35, bounce: 0.18)) {
            tilt = .zero
        }
    }

    private static func clamped(_ value: Double) -> CGFloat {
        CGFloat(max(-1, min(1, value)))
    }
}
