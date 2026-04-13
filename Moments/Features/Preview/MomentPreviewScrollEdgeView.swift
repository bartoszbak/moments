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
    }

    private func previewScreen(for countdown: Countdown) -> some View {
        let baseScreen = ZStack {
            previewBackground(for: countdown)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    previewSections(for: countdown)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, bottomContentPadding)
                }
                .scrollIndicators(.hidden)
                .modifier(BottomScrollEdgeEffectModifier())
            }
        }

        return Group {
            if #available(iOS 26, *) {
                baseScreen.safeAreaBar(
                    edge: .bottom,
                    alignment: .center,
                    spacing: 0,
                    content: { bottomSafeAreaBarContent(for: countdown) }
                )
            } else {
                baseScreen.safeAreaInset(
                    edge: .bottom,
                    spacing: 0,
                    content: { legacyBottomInsetContent(for: countdown) }
                )
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
    private func previewSections(for countdown: Countdown) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 20) {
                previewSectionStack(for: countdown)
            }
        } else {
            previewSectionStack(for: countdown)
        }
    }

    private func previewSectionStack(for countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            heroCard(for: countdown)

            if let details = countdown.detailsText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !details.isEmpty {
                detailCard(text: details)
            }

            if viewModel.shouldShowReflectionCard {
                reflectionCard
            } else {
                reflectionPromptCard(for: countdown)
            }
        }
    }

    private func heroCard(for countdown: Countdown) -> some View {
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
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 32)
    }

    private func detailCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Context", systemImage: "note.text")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 28)
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(reflectionCardTitle, systemImage: reflectionCardIcon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.surfaceDisplayText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(viewModel.errorText == nil ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !viewModel.reflectionDisplayText.isEmpty {
                    Divider()
                        .overlay(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))

                    Text(viewModel.reflectionDisplayText)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !viewModel.guidanceDisplayText.isEmpty {
                    Divider()
                        .overlay(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))

                    Text(viewModel.guidanceDisplayText)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if viewModel.expansionStage < viewModel.maxExpansionStage {
                Button {
                    viewModel.expandNextStage()
                } label: {
                    Label("Continue", systemImage: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .adaptiveGlassButtonStyle()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 28)
        .animation(.smooth(duration: 0.28), value: viewModel.surfaceDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.reflectionDisplayText)
        .animation(.smooth(duration: 0.28), value: viewModel.guidanceDisplayText)
    }

    private func reflectionPromptCard(for countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(promptTitle(for: countdown), systemImage: "sparkles")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(promptBody(for: countdown))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 28)
    }

    private func primaryActionButton(for countdown: Countdown) -> some View {
        Button {
            viewModel.generateReflection(for: countdown, timerManager: timerManager, repository: repository)
        } label: {
            Group {
                if viewModel.isLoadingReflection {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Thinking")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(primaryButtonForegroundColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(primaryButtonColor)
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
    @ViewBuilder
    private func bottomSafeAreaBarContent(for countdown: Countdown) -> some View {
        if viewModel.showsBottomPrimaryAction {
            primaryActionButton(for: countdown)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    momentAccentColor(for: countdown).opacity(colorScheme == .dark ? 0.20 : 0.12),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    momentAccentColor(for: countdown).opacity(colorScheme == .dark ? 0.18 : 0.10),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 320
            )
        }
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

    private func promptTitle(for countdown: Countdown) -> String {
        countdown.isExpired(at: timerManager.currentTime) ? "Reflect on what happened" : "Generate an AI reflection"
    }

    private func promptBody(for countdown: Countdown) -> String {
        if countdown.isExpired(at: timerManager.currentTime) {
            return "Create a short reflection about what this moment meant, what changed after it, and what is still worth carrying forward."
        }

        return "Generate a calm reflection for this moment with a surface thought, a deeper connection, and a gentle next step."
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

        return countdown.isExpired(at: timerManager.currentTime) ? "Look Back" : "Set Intention"
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

    private var bottomContentPadding: CGFloat {
        28
    }
}

private struct BottomScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}
