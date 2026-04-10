import Combine
import Foundation

/// Single shared timer that drives all countdown displays.
/// One timer instance per app — never create per-countdown timers.
@MainActor
final class TimerManager: ObservableObject {
    @Published private(set) var currentTime: Date = Date()

    private var cancellable: AnyCancellable?

    func start() {
        guard cancellable == nil else { return }
        cancellable = Timer
            .publish(every: 1, tolerance: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.currentTime = date
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
