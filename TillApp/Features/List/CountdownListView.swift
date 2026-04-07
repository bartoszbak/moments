import SwiftUI

struct CountdownListView: View {
    @EnvironmentObject private var repository: CountdownRepository
    @EnvironmentObject private var timerManager: TimerManager

    @State private var showingAddSheet = false
    @State private var editingCountdown: Countdown?
    @State private var showingDevMenu = false

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
            .navigationTitle("Till")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDevMenu = true
                    } label: {
                        Image(systemName: "curlybraces")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .overlay {
                if repository.countdowns.isEmpty {
                    ContentUnavailableView {
                        Label("No Countdowns", systemImage: "app.badge")
                    } description: {
                        Text("")
                    } actions: {
                        Button("Add new") { showingAddSheet = true }
                            .adaptiveGlassProminentButtonStyle()
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !repository.countdowns.isEmpty {
            Button {
                showingAddSheet = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Group {
                    if #available(iOS 26, *) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 56, height: 56)
                            .glassEffect(.regular.interactive(), in: .circle)
                    } else {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 0)
            }
        }
        .sheet(isPresented: $showingDevMenu) {
            DeveloperMenuView()
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
