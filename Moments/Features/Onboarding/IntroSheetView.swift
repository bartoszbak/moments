import SwiftUI

struct IntroSheetView: View {
    let onGetStarted: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome to Moments")
                    .font(.largeTitle.weight(.bold))

                Text("Here are a few things you can do:")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 14) {
                    introFeatureRow(icon: "calendar.badge.clock", title: "Calendar synchronization")
                    introFeatureRow(icon: "clock.arrow.circlepath", title: "Add past events")
                    introFeatureRow(icon: "number.circle", title: "Counters")
                    introFeatureRow(icon: "note.text", title: "Static notes")
                }

                Spacer()

                Button("Get Started", action: onGetStarted)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func introFeatureRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 24)
                .foregroundStyle(.primary)

            Text(title)
                .font(.body.weight(.medium))
        }
    }
}

#Preview {
    IntroSheetView(onGetStarted: {})
}
