import SwiftUI

@main
struct TillAppApp: App {
    private let persistence = PersistenceController.shared
    @StateObject private var repository: CountdownRepository
    @StateObject private var timerManager = TimerManager()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let persistence = PersistenceController.shared
        _repository = StateObject(wrappedValue: CountdownRepository(
            viewContext: persistence.container.viewContext,
            backgroundContext: persistence.newBackgroundContext()
        ))
    }

    var body: some Scene {
        WindowGroup {
            CountdownListView()
                .environmentObject(repository)
                .environmentObject(timerManager)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                timerManager.start()
            case .background, .inactive:
                timerManager.stop()
            default:
                break
            }
        }
    }
}
