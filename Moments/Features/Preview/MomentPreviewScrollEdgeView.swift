import BlurSwiftUI
import SwiftUI

struct MomentPreviewScrollEdgeView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex

    @StateObject private var viewModel: MomentPreviewViewModel
    @State private var showingEditSheet = false
    @State private var completedRevealStages: Set<Int> = []

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
                previewBackground(for: countdown)
                    .ignoresSafeArea()

                previewScrollView(for: countdown, viewportHeight: proxy.size.height)
            }

            Group {
                if #available(iOS 26, *) {
                    baseScreen.safeAreaBar(
                        edge: .bottom,
                        alignment: .center,
                        spacing: 0,
                        content: {
                            bottomSafeAreaBarContent(
                                for: countdown,
                                bottomSafeAreaInset: proxy.safeAreaInsets.bottom
                            )
                        }
                    )
                } else {
                    baseScreen.safeAreaInset(
                        edge: .bottom,
                        spacing: 0,
                        content: { legacyBottomInsetContent(for: countdown) }
                    )
                }
            }
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
            EditCountdownView(countdownID: countdownID)
        }
        .onAppear {
            viewModel.syncSavedReflection(from: countdown)
        }
        .onChange(of: repository.countdowns) { _, _ in
            guard let updatedCountdown = self.countdown else { return }
            viewModel.syncSavedReflection(from: updatedCountdown)
        }
    }

    @ViewBuilder
    private func previewScrollView(for countdown: Countdown, viewportHeight: CGFloat) -> some View {
        ScrollView {
            previewSections(for: countdown)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(minHeight: viewportHeight, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, bottomContentPadding)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func previewSections(for countdown: Countdown) -> some View {
        previewSectionStack(for: countdown)
    }

    private func previewSectionStack(for countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            previewPrimarySectionStack(for: countdown)
            previewReflectionSection(for: countdown)
        }
    }

    private func previewPrimarySectionStack(for countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            heroCard(for: countdown)
        }
    }

    @ViewBuilder
    private func previewReflectionSection(for countdown: Countdown) -> some View {
        if viewModel.shouldShowReflectionCard {
            reflectionCard(for: countdown)
        }
    }

    private func heroCard(for countdown: Countdown) -> some View {
        if countdown.isFutureManifestation {
            return AnyView(manifestationHeroCard(for: countdown))
        }

        return AnyView(standardHeroCard(for: countdown))
    }

    private func standardHeroCard(for countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(metricValue(for: countdown))
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(metricLabel(for: countdown))
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let symbolName = countdown.sfSymbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(momentAccentColor(for: countdown))
                        .frame(width: 54, height: 54)
                        .background(momentAccentColor(for: countdown).opacity(colorScheme == .dark ? 0.24 : 0.12), in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(countdown.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(countdown.targetDate.smartFormatted)
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 28)
    }

    private func manifestationHeroCard(for countdown: Countdown) -> some View {
        VStack(alignment: .center, spacing: 18) {
            if let symbolName = countdown.sfSymbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(momentAccentColor(for: countdown))
                    .frame(width: 54, height: 54)
                    .background(
                        momentAccentColor(for: countdown).opacity(colorScheme == .dark ? 0.24 : 0.12),
                        in: Circle()
                    )
            }

            Text(countdown.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 28)
    }

    private func reflectionCard(for countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if viewModel.errorText != nil {
                Label(reflectionCardTitle, systemImage: reflectionCardIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: reflectionContentSpacing(for: countdown)) {
                if !viewModel.surfaceDisplayText.isEmpty {
                    WordRevealText(
                        text: viewModel.surfaceDisplayText,
                        font: .system(.body, design: .rounded),
                        color: viewModel.errorText == nil ? .primary : .secondary,
                        onRevealCompleted: handleSurfaceRevealCompleted
                    )
                }

                if !viewModel.reflectionDisplayText.isEmpty {
                    WordRevealText(
                        text: viewModel.reflectionDisplayText,
                        font: .system(.body, design: .rounded),
                        color: .primary,
                        onRevealCompleted: { handleRevealCompleted(for: 1) }
                    )
                    .transition(.opacity)
                }

                if !viewModel.guidanceDisplayText.isEmpty {
                    WordRevealText(
                        text: viewModel.guidanceDisplayText,
                        font: .system(.body, design: .rounded),
                        color: .secondary,
                        alignment: countdown.isFutureManifestation ? .center : .leading,
                        onRevealCompleted: { handleRevealCompleted(for: viewModel.guidanceStage) }
                    )
                    .transition(.opacity)
                }
            }

            if shouldShowReflectionCompletionIcon {
                Image(systemName: "sparkle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.28), value: viewModel.surfaceDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.reflectionDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.guidanceDisplayText)
    }

    private func primaryActionButton(for countdown: Countdown) -> some View {
        Button {
            viewModel.generateReflection(for: countdown, timerManager: timerManager, repository: repository)
        } label: {
            Group {
                if viewModel.isLoadingReflection {
                    ThinkingActionLabel(
                        foregroundColor: primaryButtonForegroundColor,
                        backgroundColor: primaryButtonColor
                    )
                } else {
                    Text(primaryActionTitle(for: countdown))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryButtonForegroundColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(primaryButtonColor)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingReflection)
    }

    @available(iOS 26.0, *)
    private func bottomSafeAreaBarContent(for countdown: Countdown, bottomSafeAreaInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            VariableBlur(direction: .up)
                .maximumBlurRadius(2)
                .blurStartingInset(nil)
                .dimmingTintColor(.red)
                .dimmingAlpha(nil)
                .passesTouchesThrough(true)
                .frame(maxWidth: .infinity)
                .frame(height: bottomBlurBarHeight + (bottomSafeAreaInset * 2))
                .offset(y: bottomSafeAreaInset)

            if viewModel.showsBottomPrimaryAction {
                primaryActionButton(for: countdown)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func legacyBottomInsetContent(for countdown: Countdown) -> some View {
        if viewModel.showsBottomPrimaryAction {
            primaryActionButton(for: countdown)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
        }
    }

    private func previewBackground(for countdown: Countdown) -> some View {
        Color(.systemBackground)
    }

    private func metricValue(for countdown: Countdown) -> String {
        if countdown.isToday(at: timerManager.currentTime) {
            return "0"
        }

        if countdown.isExpired(at: timerManager.currentTime) {
            return "\(countdown.daysSince(from: timerManager.currentTime))"
        }

        return "\(countdown.daysUntil(from: timerManager.currentTime))"
    }

    private func metricLabel(for countdown: Countdown) -> String {
        if countdown.isToday(at: timerManager.currentTime) {
            return "Days until today"
        }

        if countdown.isExpired(at: timerManager.currentTime) {
            return "Days since this moment"
        }

        return "Days until this moment"
    }

    private var reflectionCardTitle: String {
        viewModel.errorText == nil ? "Reflection" : "AI generation issue"
    }

    private var reflectionCardIcon: String {
        viewModel.errorText == nil ? "text.quote" : "exclamationmark.triangle"
    }

    private func primaryActionTitle(for countdown: Countdown) -> String {
        if viewModel.errorText != nil {
            return "Try Again"
        }

        if countdown.isFutureManifestation {
            return "Get Manifestation"
        }

        return countdown.isExpired(at: timerManager.currentTime) ? "Look Back" : "Set Intention"
    }

    private func reflectionContentSpacing(for countdown: Countdown) -> CGFloat {
        countdown.isFutureManifestation ? 32 : 14
    }

    private func momentAccentColor(for countdown: Countdown) -> Color {
        if let hex = countdown.backgroundColorHex, let customColor = Color(hex: hex) {
            return customColor
        }

        if let index = countdown.backgroundColorIndex,
           ColorPalette.presets.indices.contains(index) {
            return ColorPalette.presets[index].color
        }

        return colorScheme == .dark ? .white : .black
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

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var shouldShowReflectionCompletionIcon: Bool {
        guard viewModel.errorText == nil else { return false }
        guard !viewModel.surfaceDisplayText.isEmpty else { return false }

        if viewModel.maxExpansionStage == 0 {
            return completedRevealStages.contains(0)
        }

        return completedRevealStages.contains(viewModel.maxExpansionStage)
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

    private var bottomContentPadding: CGFloat {
        if #available(iOS 26, *) {
            return viewModel.showsBottomPrimaryAction ? 112 : 76
        } else {
            return 28
        }
    }

    @available(iOS 26.0, *)
    private var bottomBlurBarHeight: CGFloat {
        viewModel.showsBottomPrimaryAction ? 28 : 19
    }
}

private struct WordRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: HorizontalAlignment = .leading
    var verticalSpacing: CGFloat = 4
    var onRevealCompleted: (() -> Void)? = nil

    @State private var revealedWordCount = 0
    @State private var revealTask: Task<Void, Never>?

    private var tokens: [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        FlowTextLayout(horizontalSpacing: 5, verticalSpacing: verticalSpacing) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                Text(token)
                    .font(font)
                    .foregroundStyle(color)
                    .opacity(index < revealedWordCount ? 1 : 0)
                    .blur(radius: index < revealedWordCount ? 0 : 14)
                    .offset(y: index < revealedWordCount ? 0 : 8)
                    .animation(
                        .easeOut(duration: 0.42).delay(Double(index) * 0.045),
                        value: revealedWordCount
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .onAppear {
            restartReveal()
        }
        .onChange(of: text) { _, _ in
            restartReveal()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func restartReveal() {
        revealTask?.cancel()
        revealedWordCount = 0

        guard !tokens.isEmpty else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            revealedWordCount = tokens.count

            let trailingDelay = Double(max(tokens.count - 1, 0)) * 0.045
            let completionDelay = trailingDelay + 0.42
            try? await Task.sleep(for: .seconds(completionDelay))
            guard !Task.isCancelled else { return }
            onRevealCompleted?()
        }
    }
}

private struct ThinkingActionLabel: View {
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        LoopingLetterRevealText(
            text: "Thinking",
            font: .headline.weight(.semibold),
            color: foregroundColor
        )
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }
}

private struct LoopingLetterRevealText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var revealedCharacterCount = 0
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
            startLoop()
        }
        .onChange(of: text) { _, _ in
            startLoop()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func startLoop() {
        revealTask?.cancel()
        revealedCharacterCount = 0

        guard !characters.isEmpty else { return }

        revealTask = Task { @MainActor in
            while !Task.isCancelled {
                revealedCharacterCount = 0
                try? await Task.sleep(for: .milliseconds(45))
                guard !Task.isCancelled else { return }

                revealedCharacterCount = characters.count
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }
            }
        }
    }
}

private struct FlowTextLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > 0, currentX + size.width > maxWidth {
                maxLineWidth = max(maxLineWidth, currentX - horizontalSpacing)
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }

            currentX += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        if !subviews.isEmpty {
            maxLineWidth = max(maxLineWidth, currentX - horizontalSpacing)
            currentY += lineHeight
        }

        return CGSize(width: maxLineWidth, height: currentY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
