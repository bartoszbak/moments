import SwiftUI

@MainActor
final class MomentPreviewViewModel: ObservableObject {
    let countdownID: UUID

    @Published var surfaceText: String?
    @Published var reflectionText: String?
    @Published var guidanceText: String?
    @Published var errorText: String?
    @Published var isLoadingReflection = false
    @Published var expansionStage = 0

    private var reflectionTask: Task<Void, Never>?

    init(countdownID: UUID) {
        self.countdownID = countdownID
    }

    // MARK: - Computed State

    var shouldShowReflectionCard: Bool {
        surfaceText != nil || errorText != nil
    }

    var showsBottomPrimaryAction: Bool {
        surfaceText == nil
    }

    var surfaceDisplayText: String {
        errorText ?? surfaceText ?? ""
    }

    var reflectionDisplayText: String {
        guard expansionStage >= 1 else { return "" }
        return reflectionText ?? ""
    }

    var guidanceDisplayText: String {
        guard expansionStage >= guidanceStage else { return "" }
        return guidanceText ?? ""
    }

    var maxExpansionStage: Int {
        let hasReflection = !(reflectionText?.isEmpty ?? true)
        let hasGuidance = !(guidanceText?.isEmpty ?? true)
        return (hasReflection ? 1 : 0) + (hasGuidance ? 1 : 0)
    }

    var guidanceStage: Int {
        let hasReflection = !(reflectionText?.isEmpty ?? true)
        return hasReflection ? 2 : 1
    }

    // MARK: - Actions

    func syncSavedReflection(from countdown: Countdown) {
        surfaceText = countdown.reflectionSurfaceText ?? countdown.reflectionPrimaryText
        reflectionText = countdown.reflectionText ?? countdown.reflectionExpandedText
        guidanceText = countdown.reflectionGuidanceText
        // Clear any stale error so the action button reappears when there's no saved reflection
        if surfaceText == nil {
            errorText = nil
        }
    }

    func expandNextStage() {
        withAnimation(.smooth(duration: 0.32)) {
            if expansionStage < maxExpansionStage {
                expansionStage += 1
            }
        }
    }

    func generateReflection(
        for countdown: Countdown,
        timerManager: TimerManager,
        repository: CountdownRepository
    ) {
        if surfaceText != nil {
            expandNextStage()
            return
        }

        isLoadingReflection = true
        errorText = nil
        reflectionTask?.cancel()

        let now = timerManager.currentTime
        reflectionTask = Task { @MainActor in
            do {
                let response = try await ReflectionService.shared.generateReflection(for: countdown, now: now)
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.36)) {
                    self.surfaceText = response.surface
                    self.reflectionText = response.reflection
                    self.guidanceText = response.guidance
                    self.isLoadingReflection = false
                    self.expansionStage = 0
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
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.28)) {
                    self.isLoadingReflection = false
                    self.errorText = (error as? LocalizedError)?.errorDescription ?? "Unable to load right now."
                }
            }
        }
    }

    func cancelReflection() {
        reflectionTask?.cancel()
    }
}
