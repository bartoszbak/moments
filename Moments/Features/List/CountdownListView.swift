import SwiftUI

struct CountdownListView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(DeveloperSettingsKeys.showEmptyStatePreview) private var showEmptyStatePreview = false
    @AppStorage(DeveloperSettingsKeys.forceIntroSheetOnLaunch) private var forceIntroSheetOnLaunch = false
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.hasSeenIntroSheet) private var hasSeenIntroSheet = AppSettingsDefaults.hasSeenIntroSheet
    @State private var showingAddSheet = false
    @State private var editingCountdown: Countdown?
    @State private var showingSettings = false
    @State private var showingIntroSheet = false
    @State private var selectedFilter: CountdownFilter = .all
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

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
        NavigationStack {
            ScrollView {
                if !displayedCountdowns.isEmpty {
                    countdownGrid
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 1)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .tint(interfaceTintColor)
            .navigationTitle(isShowingPrimaryEmptyState ? "" : "Moments")
            .navigationBarTitleDisplayMode(isShowingPrimaryEmptyState ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "plus.minus.capsule")
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
        }
        .onChange(of: selectedFilter) {
            AppHaptics.impact(.light)
        }
        .onChange(of: forceIntroSheetOnLaunch) { _, isEnabled in
            if isEnabled {
                showingIntroSheet = true
            }
        }
        .task {
            showingIntroSheet = !hasSeenIntroSheet || forceIntroSheetOnLaunch
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
        .sheet(item: $editingCountdown) { countdown in
            EditCountdownView(countdownID: countdown.id)
        }
    }

    private func delete(_ countdown: Countdown) {
        try? repository.delete(countdown)
        AppHaptics.impact(.medium)
    }

    @ViewBuilder
    private var countdownGrid: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 16) {
                tileGridContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 92)
        } else {
            tileGridContent
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 92)
        }
    }

    private var tileGridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
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

            Image("EmptyState")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)

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
        Button("Add first event") {
            presentAddCountdown()
        }
        .id(themeRefreshKey)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .tint(primaryActionBackgroundColor)
        .foregroundStyle(primaryActionForegroundColor)
        .adaptiveGlassProminentButtonStyle()
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
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
        AppTheme.defaultInterfaceTintColor(for: effectiveColorScheme)
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

    private var primaryActionBackgroundColor: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var primaryActionForegroundColor: Color {
        effectiveColorScheme == .dark ? .black : .white
    }

    private func presentAddCountdown() {
        AppHaptics.impact(.medium)
        showingAddSheet = true
    }

    private func openCountdown(_ countdown: Countdown) {
        AppHaptics.impact(.soft)
        editingCountdown = countdown
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
    CountdownListView()
        .environmentObject(CountdownRepository(
            viewContext: PersistenceController.preview.container.viewContext,
            backgroundContext: PersistenceController.preview.newBackgroundContext()
        ))
        .environmentObject(TimerManager())
}
