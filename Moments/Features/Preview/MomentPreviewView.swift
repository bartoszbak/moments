import SwiftUI

struct MomentPreviewView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex

    @State private var showingEditSheet = false
    @State private var isLoadingReflection = false
    @State private var expansionStage = 0
    @State private var surfaceText: String?
    @State private var reflectionText: String?
    @State private var guidanceText: String?
    @State private var errorText: String?
    @State private var headerHeight: CGFloat = 0
    @State private var reflectionHeight: CGFloat = 0
    @State private var expandButtonHeight: CGFloat = 0

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
    }

    @ViewBuilder
    private func previewScreen(for countdown: Countdown) -> some View {
        let baseScreen = previewBaseContent(for: countdown)
            .background(Color(.systemBackground))
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

                if #available(iOS 26, *) {
                    if showsBottomPrimaryAction {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Spacer()
                            toolbarPrimaryAction(for: countdown)
                            Spacer()
                        }
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
                guard let updatedCountdown = self.countdown else { return }
                syncSavedReflection(from: updatedCountdown)
            }

        Group {
            if #available(iOS 26, *) {
                baseScreen
            } else {
                baseScreen
                    .overlay(alignment: .bottom) {
                        previewLegacyBottomOverlay(for: countdown)
                    }
            }
        }
    }

    private func previewBaseContent(for countdown: Countdown) -> some View {
        GeometryReader { proxy in
            previewScrollView(proxy: proxy, countdown: countdown)
        }
    }

    private func syncSavedReflection(from countdown: Countdown) {
        surfaceText = countdown.reflectionSurfaceText ?? countdown.reflectionPrimaryText
        reflectionText = countdown.reflectionText ?? countdown.reflectionExpandedText
        guidanceText = countdown.reflectionGuidanceText
    }

    private func momentHeader(for countdown: Countdown) -> some View {
        Group {
            if countdown.isFutureManifestation {
                manifestationMomentHeader(for: countdown)
            } else {
                standardMomentHeader(for: countdown)
            }
        }
    }

    private func standardMomentHeader(for countdown: Countdown) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: standardHeroMetricSpacing) {
                Text(metricValue(for: countdown))
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(metricLabel(for: countdown))
                    .font(.system(.headline, design: .rounded, weight: .medium))
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
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(previewSymbolColor)
                    .padding(.top, standardHeroSymbolTopPadding)
                    .padding(.bottom, standardHeroSymbolBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func manifestationMomentHeader(for countdown: Countdown) -> some View {
        VStack(spacing: 14) {
            AlternatingLetterRevealText(
                items: [dateOrManifestLabel(for: countdown), metricLabel(for: countdown)],
                font: AppTypography.manifestationFont(
                    relativeTo: .subheadline,
                    variant: .medium
                ),
                color: .secondary
            )

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

            if let symbolName = countdown.sfSymbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(previewSymbolColor)
                    .padding(.top, standardHeroSymbolTopPadding)
                    .padding(.bottom, standardHeroSymbolBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
        if countdown.isFutureManifestation {
            return "Always upcoming"
        }
        if countdown.isToday(at: timerManager.currentTime) {
            return "Today"
        }

        if countdown.isExpired(at: timerManager.currentTime) {
            return "Days since"
        }

        return "Days until"
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

    private func primaryActionTitle(for countdown: Countdown) -> String {
        countdown.isExpired(at: timerManager.currentTime) ? "Look Back" : "Set intention"
    }

    private func dateOrManifestLabel(for countdown: Countdown) -> String {
        countdown.isFutureManifestation ? "Manifest" : countdown.targetDate.smartFormatted
    }

    private var previewSymbolColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.72)
            : Color.black.opacity(0.42)
    }

    private var actionButtonBackgroundColor: Color {
        primaryButtonColor
    }

    private var actionButtonForegroundColor: Color {
        primaryButtonColor.prefersLightForeground ? .white : .black
    }

    private var loadingActionButtonBackgroundColor: Color {
        Color(uiColor: .tertiarySystemFill)
    }

    private var loadingActionButtonForegroundColor: Color {
        .primary
    }

    private var showsBottomPrimaryAction: Bool {
        surfaceText == nil && errorText == nil
    }

    private var bottomActionReservedHeight: CGFloat {
        guard showsBottomPrimaryAction else { return 0 }

        if #available(iOS 26, *) {
            return 72
        }

        return 108
    }

    private var previewContentBottomPadding: CGFloat {
        guard showsBottomPrimaryAction else { return 20 }

        if #available(iOS 26, *) {
            return 16
        }

        return 28
    }

    private var editButtonColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var primaryButtonColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex)
    }

    private var shouldShowReflectionCard: Bool {
        surfaceText != nil || errorText != nil
    }

    private var surfaceDisplayText: String {
        if let errorText {
            return errorText
        }

        return surfaceText ?? ""
    }

    private var reflectionDisplayText: String {
        guard expansionStage >= 1 else { return "" }
        return reflectionText ?? ""
    }

    private var guidanceDisplayText: String {
        guard expansionStage >= 2 else { return "" }
        return guidanceText ?? ""
    }

    private var maxExpansionStage: Int {
        let hasReflection = !(reflectionText?.isEmpty ?? true)
        let hasGuidance = !(guidanceText?.isEmpty ?? true)
        return (hasReflection ? 1 : 0) + (hasGuidance ? 1 : 0)
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !surfaceDisplayText.isEmpty {
                WordRevealText(
                    text: surfaceDisplayText,
                    font: surfaceText == nil && errorText != nil
                        ? .system(.footnote, design: .rounded)
                        : primaryReflectionFont,
                    color: surfaceText == nil && errorText != nil ? .secondary : .primary
                )
            }

            if reflectionText != nil || guidanceText != nil {
                if !reflectionDisplayText.isEmpty {
                    WordRevealText(
                        text: reflectionDisplayText,
                        font: primaryReflectionFont,
                        color: .primary
                    )
                    .transition(.opacity)
                }

                if !guidanceDisplayText.isEmpty {
                    WordRevealText(
                        text: guidanceDisplayText,
                        font: secondaryReflectionFont,
                        color: .primary
                    )
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .animation(.smooth(duration: 0.36), value: surfaceDisplayText)
        .animation(.smooth(duration: 0.32), value: reflectionDisplayText)
        .animation(.smooth(duration: 0.32), value: guidanceDisplayText)
    }

    private var primaryReflectionFont: Font {
        if countdown?.isFutureManifestation == true {
            return AppTypography.manifestationFont(
                relativeTo: .callout,
                variant: .medium,
                sizeAdjustment: 3
            )
        }

        return .system(.callout, design: .rounded, weight: .medium)
    }

    private var secondaryReflectionFont: Font {
        if countdown?.isFutureManifestation == true {
            return AppTypography.manifestationFont(
                relativeTo: .callout,
                variant: .book,
                sizeAdjustment: 2
            )
        }

        return primaryReflectionFont
    }

    private func previewScrollView(proxy: GeometryProxy, countdown: Countdown) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Color.clear
                    .frame(height: headerTopSpacing(in: proxy))

                momentHeader(for: countdown)
                    .background(HeightMeasurementView(height: $headerHeight))

                if shouldShowReflectionCard {
                    reflectionCard
                        .background(HeightMeasurementView(height: $reflectionHeight))

                    if expansionStage < maxExpansionStage {
                        Button {
                            withAnimation(.smooth(duration: 0.32)) {
                                expansionStage += 1
                            }
                        } label: {
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 32)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .buttonStyle(.plain)
                        .background(HeightMeasurementView(height: $expandButtonHeight))
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: availableContentHeight(in: proxy), alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, previewContentBottomPadding)
            .animation(.smooth(duration: 0.36), value: shouldShowReflectionCard)
            .animation(.smooth(duration: 0.36), value: headerHeight)
            .animation(.smooth(duration: 0.36), value: reflectionHeight)
            .animation(.smooth(duration: 0.36), value: expandButtonHeight)
        }
        .scrollIndicators(.hidden)
    }

    private func bottomPrimaryAction(for countdown: Countdown) -> some View {
        Button(action: { generateReflection(for: countdown) }) {
            Group {
                if isLoadingReflection {
                    ThinkingActionLabel(
                        foregroundColor: loadingActionButtonForegroundColor,
                        backgroundColor: loadingActionButtonBackgroundColor
                    )
                } else {
                    Text(primaryActionButtonTitle(for: countdown))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(actionButtonForegroundColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(actionButtonBackgroundColor)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLoadingReflection)
    }

    @available(iOS 26.0, *)
    private func toolbarPrimaryAction(for countdown: Countdown) -> some View {
        Button(action: { generateReflection(for: countdown) }) {
            Group {
                if isLoadingReflection {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)

                        Text(primaryActionButtonTitle(for: countdown))
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(loadingActionButtonForegroundColor)
                } else {
                    Text(primaryActionButtonTitle(for: countdown))
                        .font(.headline.weight(.semibold))
                }
            }
        }
        .tint(isLoadingReflection ? loadingActionButtonBackgroundColor : primaryButtonColor)
        .buttonStyle(.glassProminent)
        .allowsHitTesting(!isLoadingReflection)
    }

    @ViewBuilder
    private func previewLegacyBottomOverlay(for countdown: Countdown) -> some View {
        if showsBottomPrimaryAction {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                previewBottomBar(for: countdown)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 18, x: 0, y: 8)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func previewBottomBar(for countdown: Countdown) -> some View {
        bottomPrimaryAction(for: countdown)
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 12)
    }

    private func availableContentHeight(in proxy: GeometryProxy) -> CGFloat {
        max(proxy.size.height - bottomActionReservedHeight, 0)
    }

    private func headerTopSpacing(in proxy: GeometryProxy) -> CGFloat {
        guard headerHeight > 0 else { return 0 }

        let referenceHeight = max(proxy.size.height - bottomActionReservedHeight, 0)
        let centeredHeaderSpacing = max((referenceHeight - headerHeight) / 2, 0)

        guard shouldShowReflectionCard else {
            return centeredHeaderSpacing
        }

        let extraBelowHeader =
            16 + reflectionHeight +
            ((expansionStage < maxExpansionStage) ? (16 + expandButtonHeight) : 0)
        let maxSpacingThatStillFits = max(availableContentHeight(in: proxy) - headerHeight - extraBelowHeader, 0)

        return min(centeredHeaderSpacing, maxSpacingThatStillFits)
    }

    private func generateReflection(for countdown: Countdown) {
        if surfaceText != nil {
            withAnimation(.smooth(duration: 0.32)) {
                if expansionStage < maxExpansionStage {
                    expansionStage += 1
                }
            }
            return
        }

        isLoadingReflection = true
        errorText = nil

        Task {
            do {
                let response = try await ReflectionService.shared.generateReflection(for: countdown, now: timerManager.currentTime)
                await MainActor.run {
                    withAnimation(.smooth(duration: 0.36)) {
                        surfaceText = response.surface
                        reflectionText = response.reflection
                        guidanceText = response.guidance
                        isLoadingReflection = false
                        expansionStage = 0
                    }
                }
                try? repository.update(
                    countdown,
                    reflectionSurfaceText: .some(response.surface),
                    reflectionText: .some(response.reflection),
                    reflectionGuidanceText: .some(response.guidance),
                    reflectionPrimaryText: .some(nil),
                    reflectionExpandedText: .some(nil),
                    reflectionGeneratedAt: .some(Date())
                )
            } catch {
                await MainActor.run {
                    withAnimation(.smooth(duration: 0.28)) {
                        isLoadingReflection = false
                        errorText = "Unable to load right now."
                    }
                }
            }
        }
    }

    private func primaryActionButtonTitle(for countdown: Countdown) -> String {
        guard isLoadingReflection else {
            return primaryActionTitle(for: countdown)
        }

        return "Thinking"
    }
}

private struct ThinkingActionLabel: View {
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        LetterRevealText(
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

private struct WordRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var verticalSpacing: CGFloat = 4
    var paragraphSpacing: CGFloat = 18

    @State private var revealedWordCount = 0
    @State private var revealTask: Task<Void, Never>?

    private var paragraphs: [Paragraph] {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
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
            return Paragraph(tokens: tokens, startIndex: startIndex)
        }
    }

    private var totalTokenCount: Int {
        paragraphs.reduce(0) { $0 + $1.tokens.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: paragraphSpacing) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                FlowTextLayout(horizontalSpacing: 5, verticalSpacing: verticalSpacing) {
                    ForEach(Array(paragraph.tokens.enumerated()), id: \.offset) { index, token in
                        let globalIndex = paragraph.startIndex + index

                        Text(token)
                            .font(font)
                            .foregroundStyle(color)
                            .opacity(globalIndex < revealedWordCount ? 1 : 0)
                            .blur(radius: globalIndex < revealedWordCount ? 0 : 14)
                            .offset(y: globalIndex < revealedWordCount ? 0 : 8)
                            .animation(
                                .easeOut(duration: 0.42).delay(Double(globalIndex) * 0.045),
                                value: revealedWordCount
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(nil)
        .fontDesign(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            revealedWordCount = totalTokenCount
        }
    }

    private struct Paragraph {
        let tokens: [String]
        let startIndex: Int
    }
}

private struct LetterRevealText: View {
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
        revealedCharacterCount = 0

        guard !characters.isEmpty else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(45))
            revealedCharacterCount = characters.count
        }
    }
}

private struct AlternatingLetterRevealText: View {
    let items: [String]
    let font: Font
    let color: Color

    @State private var currentIndex = 0
    @State private var cycleTask: Task<Void, Never>?

    private var visibleItems: [String] {
        let trimmed = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return trimmed.filter { !$0.isEmpty }
    }

    var body: some View {
        Group {
            if let currentText = currentText {
                LetterRevealText(
                    text: currentText,
                    font: font,
                    color: color
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .center)
        .task(id: visibleItems) {
            startCycling()
        }
        .onDisappear {
            cycleTask?.cancel()
        }
    }

    private var currentText: String? {
        guard !visibleItems.isEmpty else { return nil }
        return visibleItems[currentIndex % visibleItems.count]
    }

    private func startCycling() {
        cycleTask?.cancel()
        currentIndex = 0

        guard visibleItems.count > 1 else { return }

        cycleTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.8))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    currentIndex = (currentIndex + 1) % visibleItems.count
                }
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
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
