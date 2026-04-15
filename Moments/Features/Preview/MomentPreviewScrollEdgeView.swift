import BlurSwiftUI
import SwiftUI
import UIKit

struct MomentPreviewScrollEdgeView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex
    @AppStorage(AppSettingsKeys.backgroundGradientEnabled) private var backgroundGradientEnabled = AppSettingsDefaults.backgroundGradientEnabled

    @StateObject private var viewModel: MomentPreviewViewModel
    @State private var showingEditSheet = false
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
                previewBackground(for: countdown)
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
    private func previewScrollView(
        for countdown: Countdown,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Color.clear
                    .frame(height: heroTopSpacing(for: viewportHeight))

                previewPrimarySectionStack(for: countdown)
                    .background(HeightMeasurementView(height: $heroHeight))

                if viewModel.shouldShowReflectionCard {
                    previewReflectionSection(for: countdown)
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
                    minHeight: max(viewportHeight - 28 - bottomContentPadding, 0),
                    alignment: .top
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(minHeight: viewportHeight, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, bottomContentPadding)
                .animation(
                    shouldAnimatePreviewLayout(for: countdown)
                        ? .smooth(duration: 0.4, extraBounce: 0)
                        : nil,
                    value: viewModel.shouldShowReflectionCard
                )
                .animation(
                    shouldAnimatePreviewLayout(for: countdown)
                        ? .smooth(duration: 0.4, extraBounce: 0)
                        : nil,
                    value: heroHeight
                )
                .animation(
                    shouldAnimatePreviewLayout(for: countdown)
                        ? .smooth(duration: 0.4, extraBounce: 0)
                        : nil,
                    value: reflectionHeight
                )
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
        VStack(alignment: .center, spacing: 14) {
            VStack(alignment: .center, spacing: standardHeroMetricSpacing) {
                Text(metricValue(for: countdown))
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(metricLabel(for: countdown))
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, standardHeroMetricBottomPadding)

            Text(countdown.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let symbolName = countdown.sfSymbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(previewSymbolColor)
                    .padding(.top, standardHeroSymbolTopPadding)
                    .padding(.bottom, standardHeroSymbolBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 28)
    }

    private func manifestationHeroCard(for countdown: Countdown) -> some View {
        VStack(alignment: .center, spacing: 18) {
            Text(countdown.title)
                .font(
                    AppTypography.manifestationFont(
                        size: 34,
                        relativeTo: .title,
                        variant: .bold
                    )
                )
                .fontDesign(nil)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 42)

            if let symbolName = countdown.sfSymbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(previewSymbolColor)
                    .padding(.top, standardHeroSymbolTopPadding)
                    .padding(.bottom, standardHeroSymbolBottomPadding)
            }
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
                        font: viewModel.errorText == nil
                            ? primaryReflectionFont(for: countdown)
                            : .system(.body, design: .rounded),
                        color: viewModel.errorText == nil ? .primary : .secondary,
                        fontDesignOverride: countdown.isFutureManifestation ? nil : .rounded,
                        verticalSpacing: reflectionLineSpacing(for: countdown),
                        paragraphSpacing: reflectionParagraphSpacing(for: countdown),
                        onRevealCompleted: handleSurfaceRevealCompleted
                    )
                }

                if !viewModel.reflectionDisplayText.isEmpty {
                    WordRevealText(
                        text: viewModel.reflectionDisplayText,
                        font: primaryReflectionFont(for: countdown),
                        color: .primary,
                        fontDesignOverride: countdown.isFutureManifestation ? nil : .rounded,
                        verticalSpacing: reflectionLineSpacing(for: countdown),
                        paragraphSpacing: reflectionParagraphSpacing(for: countdown),
                        onRevealCompleted: { handleRevealCompleted(for: 1) }
                    )
                    .transition(.opacity)
                }

                if !viewModel.guidanceDisplayText.isEmpty {
                    if countdown.isFutureManifestation {
                        NativeRevealText(
                            text: viewModel.guidanceDisplayText,
                            font: secondaryReflectionFont(for: countdown),
                            color: .primary,
                            alignment: .center,
                            fontDesignOverride: nil,
                            onRevealCompleted: { handleRevealCompleted(for: viewModel.guidanceStage) }
                        )
                        .transition(.opacity)
                    } else {
                        WordRevealText(
                            text: viewModel.guidanceDisplayText,
                            font: secondaryReflectionFont(for: countdown),
                            color: .primary,
                            alignment: .leading,
                            fontDesignOverride: .rounded,
                            verticalSpacing: reflectionLineSpacing(for: countdown),
                            paragraphSpacing: reflectionParagraphSpacing(for: countdown),
                            onRevealCompleted: { handleRevealCompleted(for: viewModel.guidanceStage) }
                        )
                        .transition(.opacity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.28), value: viewModel.surfaceDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.reflectionDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.guidanceDisplayText)
    }

    private func primaryReflectionFont(for countdown: Countdown) -> Font {
        if countdown.isFutureManifestation {
            return AppTypography.manifestationFont(
                relativeTo: .body,
                variant: .medium,
                sizeAdjustment: 3
            )
        }

        return .system(size: 20, weight: .medium, design: .rounded)
    }

    private func secondaryReflectionFont(for countdown: Countdown) -> Font {
        if countdown.isFutureManifestation {
            return AppTypography.manifestationFont(
                relativeTo: .body,
                variant: .mediumItalic,
                sizeAdjustment: 3
            )
        }

        return primaryReflectionFont(for: countdown)
    }

    private func primaryActionButton(for countdown: Countdown) -> some View {
        Button {
            viewModel.generateReflection(for: countdown, timerManager: timerManager, repository: repository)
        } label: {
            Group {
                if viewModel.isLoadingReflection {
                    ThinkingActionLabel(
                        foregroundColor: loadingActionButtonForegroundColor,
                        backgroundColor: loadingActionButtonBackgroundColor
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
        .allowsHitTesting(!viewModel.isLoadingReflection)
    }

    @ViewBuilder
    private func bottomInsetContent(
        for countdown: Countdown,
        viewportWidth: CGFloat,
        bottomSafeAreaInset: CGFloat
    ) -> some View {
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

                if viewModel.showsBottomPrimaryAction {
                    primaryActionButton(for: countdown)
                        .frame(
                            maxWidth: readableContentWidth(
                                for: viewportWidth,
                                horizontalPadding: 24
                            )
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        } else {
            legacyBottomInsetContent(
                for: countdown,
                viewportWidth: viewportWidth
            )
        }
    }

    @ViewBuilder
    private func legacyBottomInsetContent(for countdown: Countdown, viewportWidth: CGFloat) -> some View {
        if viewModel.showsBottomPrimaryAction {
            primaryActionButton(for: countdown)
                .frame(
                    maxWidth: readableContentWidth(
                        for: viewportWidth,
                        horizontalPadding: 24
                    )
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private func previewBackground(for countdown: Countdown) -> some View {
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
            return "Today"
        }

        if countdown.isExpired(at: timerManager.currentTime) {
            return "\(dayUnit(for: countdown.daysSince(from: timerManager.currentTime))) since"
        }

        return "\(dayUnit(for: countdown.daysUntil(from: timerManager.currentTime))) until"
    }

    private func dayUnit(for count: Int) -> String {
        count == 1 ? "Day" : "Days"
    }

    private var standardHeroSymbolTopPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 0
    }

    private var standardHeroSymbolBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 32 : 16
    }

    private var standardHeroMetricSpacing: CGFloat {
        2
    }

    private var standardHeroMetricBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 8 : 0
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

    private func reflectionLineSpacing(for countdown: Countdown) -> CGFloat {
        countdown.isFutureManifestation ? 9 : 4
    }

    private func reflectionParagraphSpacing(for countdown: Countdown) -> CGFloat {
        countdown.isFutureManifestation ? 22 : 18
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

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var bottomContentPadding: CGFloat {
        if #available(iOS 26, *) {
            return viewModel.showsBottomPrimaryAction ? 112 : 44
        } else {
            return 28
        }
    }

    private func heroTopSpacing(for viewportHeight: CGFloat) -> CGFloat {
        guard shouldCenterHeroVertically else { return 0 }
        guard heroHeight > 0 else { return 0 }

        let availableHeight = max(viewportHeight - 28 - bottomContentPadding, 0)
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

    private func shouldAnimatePreviewLayout(for countdown: Countdown) -> Bool {
        true
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

    @available(iOS 26.0, *)
    private var bottomBlurBarHeight: CGFloat {
        viewModel.showsBottomPrimaryAction ? 28 : 19
    }

    @available(iOS 26.0, *)
    private var bottomBlurGradientHeight: CGFloat {
        viewModel.showsBottomPrimaryAction ? 52 : 40
    }
}

private struct WordRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: HorizontalAlignment = .leading
    var fontDesignOverride: Font.Design? = .rounded
    var verticalSpacing: CGFloat = 4
    var paragraphSpacing: CGFloat = 18
    var onRevealCompleted: (() -> Void)? = nil

    @State private var availableWidth: CGFloat = 0
    @State private var measuredLineHeight: CGFloat = 0
    @State private var revealedWordCount = 0
    @State private var revealTask: Task<Void, Never>?

    private var normalizedText: String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private var paragraphs: [Paragraph] {
        let rawParagraphs = normalizedText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let effectiveParagraphs = rawParagraphs.isEmpty ? [normalizedText] : rawParagraphs
        var startIndex = 0

        return effectiveParagraphs.compactMap { paragraph in
            let tokens = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            guard !tokens.isEmpty else { return nil }
            defer { startIndex += tokens.count }
            return Paragraph(
                tokens: tokens,
                startIndex: startIndex
            )
        }
    }

    private var totalTokenCount: Int {
        paragraphs.reduce(0) { $0 + $1.tokens.count }
    }

    var body: some View {
        VStack(
            alignment: alignment == .center ? .center : .leading,
            spacing: paragraphSpacing
        ) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                FlowTextLayout(horizontalSpacing: 5, verticalSpacing: verticalSpacing) {
                    ForEach(Array(paragraph.tokens.enumerated()), id: \.offset) { index, token in
                        let globalIndex = paragraph.startIndex + index

                        Text(token)
                            .font(font)
                            .fontDesign(fontDesignOverride)
                            .foregroundStyle(color)
                            .opacity(globalIndex < revealedWordCount ? 1 : 0)
                            .blur(radius: globalIndex < revealedWordCount ? 0 : 14)
                            .offset(y: globalIndex < revealedWordCount ? 0 : 8)
                            .animation(
                                .easeOut(duration: 0.42).delay(Double(globalIndex) * 0.045),
                                value: revealedWordCount
                            )
                            .frame(
                                height: measuredLineHeight > 0 ? measuredLineHeight : nil,
                                alignment: .bottomLeading
                            )
                            .fixedSize()
                    }
                }
                .frame(
                    width: availableWidth > 0 ? availableWidth : nil,
                    alignment: alignment == .center ? .center : .leading
                )
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                .padding(.bottom, measuredLineHeight > 0 ? max(measuredLineHeight * 0.08, 1) : 0)
            }
        }
        .font(nil)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .overlay(alignment: .topLeading) {
            Text("Agjp")
                .font(font)
                .opacity(0.001)
                .background(HeightMeasurementView(height: $measuredLineHeight))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.width) {
                        guard abs(availableWidth - proxy.size.width) > 0.5 else { return }
                        availableWidth = proxy.size.width
                    }
            }
        }
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

        guard totalTokenCount > 0 else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            revealedWordCount = totalTokenCount

            let trailingDelay = Double(max(totalTokenCount - 1, 0)) * 0.045
            let completionDelay = trailingDelay + 0.42
            try? await Task.sleep(for: .seconds(completionDelay))
            guard !Task.isCancelled else { return }
            onRevealCompleted?()
        }
    }

    private struct Paragraph {
        let tokens: [String]
        let startIndex: Int
    }
}

private struct NativeRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: TextAlignment = .leading
    var fontDesignOverride: Font.Design? = .rounded
    var onRevealCompleted: (() -> Void)? = nil

    @State private var isRevealed = false
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        Text(text)
            .font(font)
            .fontDesign(fontDesignOverride)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
            .opacity(isRevealed ? 1 : 0)
            .blur(radius: isRevealed ? 0 : 14)
            .offset(y: isRevealed ? 0 : 8)
            .animation(.easeOut(duration: 0.42), value: isRevealed)
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
        isRevealed = false

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            isRevealed = true

            try? await Task.sleep(for: .seconds(0.42))
            guard !Task.isCancelled else { return }
            onRevealCompleted?()
        }
    }
}

private struct HeightMeasurementView: View {
    @Binding var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .task(id: proxy.size.height) {
                    guard abs(height - proxy.size.height) > 0.5 else { return }
                    height = proxy.size.height
                }
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
