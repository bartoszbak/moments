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
    @AppStorage(AppSettingsKeys.hasSeenIntroSheet) private var hasSeenIntroSheet = AppSettingsDefaults.hasSeenIntroSheet
    @State private var showingAddSheet = false
    @State private var previewingCountdown: Countdown?
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
        .navigationDestination(item: $previewingCountdown) { countdown in
            MomentPreviewView(countdownID: countdown.id)
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
        previewingCountdown = countdown
    }
}

private struct MomentPreviewView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager

    @State private var showingEditSheet = false
    @State private var isLoadingReflection = false
    @State private var isExpanded = false
    @State private var primaryText: String?
    @State private var expandedText: String?
    @State private var errorText: String?

    private var countdown: Countdown? {
        repository.countdowns.first { $0.id == countdownID }
    }

    var body: some View {
        Group {
            if let countdown {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(countdown.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))

                        Text(countdown.targetDate.smartFormatted)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(metricLabel(for: countdown))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .contentTransition(.numericText())

                        Button(primaryActionTitle(for: countdown)) {
                            generateReflection(for: countdown)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoadingReflection)

                        if isLoadingReflection {
                            ProgressView()
                        }

                        if let primaryText {
                            Text(primaryText)
                                .font(.system(.body, design: .rounded))
                                .contentTransition(.opacity)
                        }

                        if let expandedText, isExpanded {
                            Text(expandedText)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                                .contentTransition(.opacity)
                        }

                        if expandedText != nil {
                            Button(isExpanded ? "Hide" : "Expand") {
                                withAnimation(.snappy) {
                                    isExpanded.toggle()
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .navigationTitle("Moment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            showingEditSheet = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    EditCountdownView(countdownID: countdownID)
                }
                .onAppear {
                    syncSavedReflection(from: countdown)
                }
                .onChange(of: repository.countdowns) { _, _ in
                    guard let countdown else { return }
                    syncSavedReflection(from: countdown)
                }
            } else {
                ContentUnavailableView("Moment not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func syncSavedReflection(from countdown: Countdown) {
        primaryText = countdown.reflectionPrimaryText
        expandedText = countdown.reflectionExpandedText
    }

    private func metricLabel(for countdown: Countdown) -> String {
        if countdown.isToday(at: timerManager.currentTime) {
            return "Today"
        }

        if countdown.isExpired(at: timerManager.currentTime) {
            return "\(countdown.daysSince(from: timerManager.currentTime)) days since"
        }

        return "\(countdown.daysUntil(from: timerManager.currentTime)) days until"
    }

    private func primaryActionTitle(for countdown: Countdown) -> String {
        countdown.isExpired(at: timerManager.currentTime) ? "Reflect" : "Prepare"
    }

    private func generateReflection(for countdown: Countdown) {
        if primaryText != nil {
            withAnimation(.snappy) {
                isExpanded = true
            }
            return
        }

        isLoadingReflection = true
        errorText = nil

        Task {
            do {
                let response = try await ReflectionService.shared.generateReflection(for: countdown, now: timerManager.currentTime)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        primaryText = response.primary
                        expandedText = response.expanded
                    }
                    isLoadingReflection = false
                    isExpanded = false
                }
                try? repository.update(
                    countdown,
                    reflectionPrimaryText: .some(response.primary),
                    reflectionExpandedText: .some(response.expanded),
                    reflectionGeneratedAt: .some(Date())
                )
            } catch {
                await MainActor.run {
                    isLoadingReflection = false
                    errorText = "Unable to load right now."
                }
            }
        }
    }
}

private final class ReflectionService {
    static let shared = ReflectionService()

    private init() {}

    func generateReflection(for countdown: Countdown, now: Date) async throws -> ReflectionOutput {
        guard let apiKey = AppSecrets.openRouterAPIKey, !apiKey.isEmpty else {
            throw ReflectionError.missingAPIKey
        }

        let isPast = countdown.isExpired(at: now)
        let systemPrompt = ReflectionPrompt.systemPrompt(isPast: isPast)
        let userPrompt = ReflectionPrompt.userPrompt(for: countdown, now: now)

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenRouterRequest(
            model: AppSecrets.openRouterModel,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            responseFormat: .init(
                type: "json_schema",
                jsonSchema: .init(
                    name: "moment_reflection",
                    strict: true,
                    schema: .init(
                        type: "object",
                        properties: [
                            "primary": .init(type: "string"),
                            "expanded": .init(type: "string")
                        ],
                        required: ["primary", "expanded"],
                        additionalProperties: false
                    )
                )
            )
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw ReflectionError.emptyResponse
        }

        return try JSONDecoder().decode(ReflectionOutput.self, from: content)
    }
}

private enum ReflectionPrompt {
    static func systemPrompt(isPast: Bool) -> String {
        if let bundledPrompt = loadPrompt(named: isPast ? "reflection_past_system_prompt" : "reflection_future_system_prompt") {
            return bundledPrompt
        }

        if isPast {
            return """
            You create short, timeless reflections for moments that already happened.
            Return JSON with `primary` and `expanded`.
            `primary` is 1-3 short sentences, calm and emotionally meaningful.
            `expanded` is slightly deeper, concise, elegant, and never instructional.
            Avoid bullet points, listicles, dramatic language, therapy framing, and motivational clichés.
            """
        }

        return """
        You create short, timeless preparation notes for moments that are still ahead.
        Return JSON with `primary` and `expanded`.
        `primary` is 1-3 short sentences, calm and emotionally meaningful.
        `expanded` is slightly deeper, concise, elegant, and never instructional.
        Avoid bullet points, listicles, dramatic language, therapy framing, and motivational clichés.
        """
    }

    private static func loadPrompt(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else {
            return nil
        }

        return try? String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func userPrompt(for countdown: Countdown, now: Date) -> String {
        """
        Moment title: \(countdown.title)
        Moment date: \(countdown.targetDate.smartFormatted)
        Today: \(now.smartFormatted)
        Days until: \(countdown.daysUntil(from: now))
        Days since: \(countdown.daysSince(from: now))
        """
    }
}

private enum AppSecrets {
    static var openRouterAPIKey: String? {
        ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
        ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String
    }

    static var openRouterModel: String {
        (ProcessInfo.processInfo.environment["OPENROUTER_MODEL"]
         ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_MODEL") as? String)
        ?? "openai/gpt-4o-mini"
    }
}

private struct ReflectionOutput: Decodable {
    let primary: String
    let expanded: String
}

private enum ReflectionError: Error {
    case missingAPIKey
    case emptyResponse
}

private struct OpenRouterRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
        let jsonSchema: JSONSchemaContainer

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }

    struct JSONSchemaContainer: Encodable {
        let name: String
        let strict: Bool
        let schema: JSONSchemaObject
    }

    struct JSONSchemaObject: Encodable {
        let type: String
        let properties: [String: JSONSchemaValue]
        let required: [String]
        let additionalProperties: Bool

        enum CodingKeys: String, CodingKey {
            case type, properties, required
            case additionalProperties = "additionalProperties"
        }
    }

    struct JSONSchemaValue: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
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

private struct EmptyStateArtworkView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var motionController = EmptyStateMotionController()

    private let containerSize: CGFloat = 96
    private let imageSize: CGFloat = 96
    private let cornerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: containerSize, height: containerSize)
                .glassCard(cornerRadius: cornerRadius)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.12 : 0.32), lineWidth: 1)
                }

            Image("EmptyState")
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
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
            color: .black.opacity(isMotionEnabled ? 0.14 : 0.08),
            radius: 18,
            x: -translation.width * 0.35,
            y: 12 - (translation.height * 0.35)
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
