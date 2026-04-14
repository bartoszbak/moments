import CoreMotion
import SwiftUI

struct CountdownListView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(DeveloperSettingsKeys.showEmptyStatePreview) private var showEmptyStatePreview = false
    @AppStorage(DeveloperSettingsKeys.forceIntroSheetOnLaunch) private var forceIntroSheetOnLaunch = false
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.backgroundGradientEnabled) private var backgroundGradientEnabled = AppSettingsDefaults.backgroundGradientEnabled
    @AppStorage(AppSettingsKeys.hasSeenIntroSheet) private var hasSeenIntroSheet = AppSettingsDefaults.hasSeenIntroSheet
    @State private var showingAddSheet = false
    @State private var previewingCountdown: Countdown?
    @State private var showingSettings = false
    @State private var showingIntroSheet = false
    @State private var selectedFilter: CountdownFilter = .all
    @Binding var deepLinkedCountdownID: UUID?

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
            switch selectedFilter {
            case .all:
                true
            case .past:
                countdown.isExpired(at: timerManager.currentTime)
            case .upcoming:
                !countdown.isExpired(at: timerManager.currentTime)
            }
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

                    if !repository.countdowns.isEmpty && !isShowingEmptyStatePreview {
                        ToolbarItemGroup(placement: .bottomBar) {
                            filterMenuButton
                            Spacer()
                            addButton
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if isShowingPrimaryEmptyState {
                        emptyStateButton
                    }
                }
                .overlay {
                    if isShowingPrimaryEmptyState {
                        emptyLibraryView
                    } else if filteredCountdowns.isEmpty {
                        ContentUnavailableView {
                            Label(emptyStateTitle, systemImage: "app.badge")
                        } description: {
                            Text(emptyStateDescription)
                        }
                    }
                }
                .navigationDestination(item: $previewingCountdown) { countdown in
                    MomentPreviewScrollEdgeView(countdownID: countdown.id)
                }
            }
        }
        .onChange(of: selectedFilter) {
            AppHaptics.impact(.light)
        }
        .onChange(of: forceIntroSheetOnLaunch) { _, isEnabled in
            if isEnabled {
                showingIntroSheet = true
            }
        }
        .onChange(of: deepLinkedCountdownID) { _, _ in
            openDeepLinkedCountdownIfNeeded()
        }
        .onChange(of: repository.countdowns) { _, _ in
            openDeepLinkedCountdownIfNeeded()
        }
        .task {
            showingIntroSheet = !hasSeenIntroSheet || forceIntroSheetOnLaunch
            openDeepLinkedCountdownIfNeeded()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingIntroSheet) {
            IntroSheetView {
                hasSeenIntroSheet = true
                showingIntroSheet = false
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCountdownView()
        }
    }

    private func delete(_ countdown: Countdown) {
        try? repository.delete(countdown)
        AppHaptics.impact(.medium)
    }

    private func openDeepLinkedCountdownIfNeeded() {
        guard let id = deepLinkedCountdownID,
              let countdown = repository.countdowns.first(where: { $0.id == id })
        else {
            return
        }

        previewingCountdown = countdown
        deepLinkedCountdownID = nil
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
                .buttonStyle(.plain)
                .id(countdown.id)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            "No Countdowns"
        case .past:
            "No Past Countdowns"
        case .upcoming:
            "No Upcoming Countdowns"
        }
    }

    private var emptyStateDescription: String {
        if repository.countdowns.isEmpty {
            return ""
        }

        switch selectedFilter {
        case .all:
            return ""
        case .past:
            return "Change the filter to see upcoming countdowns."
        case .upcoming:
            return "Change the filter to see past countdowns."
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

    private var emptyStateButtonWidth: CGFloat? {
        isiPad ? 360 : nil
    }

    private var filterMenuButton: some View {
        Menu {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(CountdownFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
        } label: {
            Image(systemName: selectedFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(settingsButtonColor)
                .frame(width: 48, height: 48)
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Filter countdowns")
    }

    private var addButton: some View {
        Button {
            presentAddCountdown()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(addButtonSymbolColor)
                .frame(width: 48, height: 48)
        }
        .id(themeRefreshKey)
        .tint(addButtonBackgroundColor)
        .adaptiveGlassProminentButtonStyle()
        .accessibilityLabel("Add countdown")
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
        showingAddSheet = true
    }

    private func openCountdown(_ countdown: Countdown) {
        AppHaptics.impact(.soft)
        previewingCountdown = countdown
    }
}

private enum CountdownFilter: String, CaseIterable, Identifiable {
    case all
    case past
    case upcoming

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "All"
        case .past:
            "Past"
        case .upcoming:
            "Upcoming"
        }
    }
}

#Preview {
    CountdownListView(deepLinkedCountdownID: .constant(nil))
        .environmentObject(CountdownRepository(
            viewContext: PersistenceController.preview.container.viewContext,
            backgroundContext: PersistenceController.preview.newBackgroundContext()
        ))
        .environmentObject(TimerManager())
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
