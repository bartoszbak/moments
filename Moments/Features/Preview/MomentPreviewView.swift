import SwiftUI

struct MomentPreviewView: View {
    let countdownID: UUID

    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme

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
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if shouldShowReflectionCard {
                                momentHeader(for: countdown)

                                reflectionCard

                                if expandedText != nil && !isExpanded {
                                    Button {
                                        withAnimation(.smooth(duration: 0.32)) {
                                            isExpanded = true
                                        }
                                    } label: {
                                        Image(systemName: "chevron.compact.down")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 44, height: 32)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Spacer(minLength: 0)
                                momentHeader(for: countdown)
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(minHeight: availableContentHeight(in: proxy), alignment: .center)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, showsBottomPrimaryAction ? 28 : 20)
                    }
                    .safeAreaInset(edge: .bottom) {
                        if showsBottomPrimaryAction {
                            bottomPrimaryAction(for: countdown)
                                .padding(.horizontal, 32)
                                .padding(.top, 12)
                                .padding(.bottom, 12)
                                .background(Color(.systemBackground))
                        }
                    }
                }
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
            } else {
                ContentUnavailableView("Moment not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func syncSavedReflection(from countdown: Countdown) {
        primaryText = countdown.reflectionPrimaryText
        expandedText = countdown.reflectionExpandedText
    }

    private func momentHeader(for countdown: Countdown) -> some View {
        VStack(spacing: 14) {
            if let symbolName = countdown.sfSymbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(momentColor(for: countdown))
            }

            Text("\(countdown.targetDate.smartFormatted), \(metricLabel(for: countdown))")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())

            Text(countdown.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
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

    private func momentColor(for countdown: Countdown) -> Color {
        if let hex = countdown.backgroundColorHex, let customColor = Color(hex: hex) {
            return customColor
        }

        if let index = countdown.backgroundColorIndex,
           ColorPalette.presets.indices.contains(index) {
            return ColorPalette.presets[index].color
        }

        return colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.12)
    }

    private var actionButtonBackgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var actionButtonForegroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var loadingActionButtonBackgroundColor: Color {
        Color.secondary.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    private var loadingActionButtonForegroundColor: Color {
        .primary
    }

    private var showsBottomPrimaryAction: Bool {
        primaryText == nil
    }

    private var editButtonColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var shouldShowReflectionCard: Bool {
        primaryText != nil || errorText != nil
    }

    private var reflectionPrimaryDisplayText: String {
        if let errorText {
            return errorText
        }

        return primaryText ?? ""
    }

    private var reflectionExpandedDisplayText: String {
        guard isExpanded else { return "" }
        return expandedText ?? ""
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !reflectionPrimaryDisplayText.isEmpty {
                WordRevealText(
                    text: reflectionPrimaryDisplayText,
                    font: primaryText == nil && errorText != nil ? .footnote : .system(size: 20, weight: .regular, design: .serif),
                    color: primaryText == nil && errorText != nil ? .secondary : .primary
                )
            }

            if expandedText != nil {
                if isExpanded && !reflectionExpandedDisplayText.isEmpty {
                    WordRevealText(
                        text: reflectionExpandedDisplayText,
                        font: .system(size: 20, weight: .regular, design: .serif),
                        color: .secondary
                    )
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .animation(.smooth(duration: 0.36), value: reflectionPrimaryDisplayText)
        .animation(.smooth(duration: 0.32), value: reflectionExpandedDisplayText)
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
        .disabled(isLoadingReflection)
    }

    private func availableContentHeight(in proxy: GeometryProxy) -> CGFloat {
        let bottomInset: CGFloat = showsBottomPrimaryAction ? 108 : 0
        return max(proxy.size.height - bottomInset, 0)
    }

    private func generateReflection(for countdown: Countdown) {
        if primaryText != nil {
            withAnimation(.smooth(duration: 0.32)) {
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
                    withAnimation(.smooth(duration: 0.36)) {
                        primaryText = response.primary
                        expandedText = response.expanded
                        isLoadingReflection = false
                        isExpanded = false
                    }
                }
                try? repository.update(
                    countdown,
                    reflectionPrimaryText: .some(response.primary),
                    reflectionExpandedText: .some(response.expanded),
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

private struct WordRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var verticalSpacing: CGFloat = 4

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

        guard !tokens.isEmpty else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            revealedWordCount = tokens.count
        }
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
