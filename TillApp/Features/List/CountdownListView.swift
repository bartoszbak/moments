import SwiftUI

struct CountdownListView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager

    @State private var showingAddSheet = false
    @State private var editingCountdown: Countdown?

    var body: some View {
        NavigationStack {
            List {
                ForEach(repository.countdowns) { countdown in
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
                        .tint(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Countdowns")
            .overlay {
                if repository.countdowns.isEmpty {
                    ContentUnavailableView {
                        Label("No Countdowns", systemImage: "timer")
                    } description: {
                        Text("Tap + to add your first countdown")
                    } actions: {
                        Button("Add Countdown") { showingAddSheet = true }
                            .adaptiveGlassProminentButtonStyle()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .adaptiveGlassButtonStyle()
                }
            }
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
}

#Preview {
    CountdownListView()
        .environmentObject(CountdownRepository(
            viewContext: PersistenceController.preview.container.viewContext,
            backgroundContext: PersistenceController.preview.newBackgroundContext()
        ))
        .environmentObject(TimerManager())
}
