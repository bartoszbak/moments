import SwiftUI

struct CountdownListView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(DeveloperSettingsKeys.showEmptyStatePreview) private var showEmptyStatePreview = false
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @State private var showingAddSheet = false
    @State private var editingCountdown: Countdown?
    @State private var showingSettings = false
    @State private var selectedFilter: CountdownFilter = .all

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
            List {
                ForEach(displayedCountdowns) { countdown in
                    CountdownRowView(
                        countdown: countdown,
                        currentTime: timerManager.currentTime
                    )
                    .id(countdown.id)
                    .contentShape(Rectangle())
                    .onTapGesture { editingCountdown = countdown }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(countdown)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingCountdown = countdown
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(interfaceTintColor)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(isShowingPrimaryEmptyState ? .hidden : .visible)
            .background(Color(.systemBackground))
            .tint(interfaceTintColor)
            .navigationTitle(isShowingPrimaryEmptyState ? "" : "Till")
            .navigationBarTitleDisplayMode(isShowingPrimaryEmptyState ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "plus.minus.capsule")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

            Text("No events to wait\nor reflect on")
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
            showingAddSheet = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .font(.title3.weight(.semibold))
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .tint(interfaceTintColor)
        .adaptiveGlassProminentButtonStyle()
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.clear)
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
                .frame(width: 48, height: 48)
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Filter countdowns")
    }

    private var addButton: some View {
        Button {
            showingAddSheet = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 48, height: 48)
        }
        .id(themeRefreshKey)
        .tint(interfaceTintColor)
        .adaptiveGlassProminentButtonStyle()
        .accessibilityLabel("Add countdown")
    }

    private var interfaceTintColor: Color {
        AppTheme.interfaceTintColor(from: interfaceTintHex, for: effectiveColorScheme)
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
