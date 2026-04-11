import SwiftUI

struct IntroSheetView: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettingsKeys.appearance) private var appearanceSetting = AppSettingsDefaults.appearance
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex

    let onGetStarted: () -> Void

    private let features: [IntroFeature] = [
        .init(
            icon: "calendar.badge.clock",
            title: "Save upcoming moments",
            description: "Create countdowns for birthdays, trips, launches, and everything else worth waiting for."
        ),
        .init(
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            title: "Keep past dates too",
            description: "Track anniversaries, milestones, and memories that already happened in the same timeline."
        ),
        .init(
            icon: "paintpalette",
            title: "Make it feel like yours",
            description: "Customize colors, add notes, and adjust the app later from Settings whenever you want."
        ),
        .init(
            icon: "sparkles",
            title: "Moments Intelligence",
            description: "Add a little context and get calm, personal reflections that help you prepare or look back with clarity."
        ),
        .init(
            icon: "applewatch.watchface",
            title: "Watch complications",
            description: "Keep your next moment visible on Apple Watch so the countdown is always one glance away."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome to Moments")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("See what's possible")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 26) {
                    ForEach(features) { feature in
                        introFeatureRow(feature)
                    }
                }
                .padding(.top, 38)
            }
            .padding(.horizontal, 32)
            .padding(.top, 42)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onGetStarted) {
                Text("Continue")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryButtonLabelColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(interfaceTintColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(preferredColorScheme)
    }

    private func introFeatureRow(_ feature: IntroFeature) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: feature.icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(interfaceTintColor)
                .frame(width: 38, height: 38, alignment: .topLeading)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        AppTheme.preferredColorScheme(for: appearanceSetting)
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? colorScheme
    }

    private var interfaceTintColor: Color {
        AppTheme.interfaceTintColor(from: interfaceTintHex, for: effectiveColorScheme)
    }

    private var primaryButtonLabelColor: Color {
        interfaceTintColor.prefersLightForeground ? .white : .black
    }
}

private struct IntroFeature: Identifiable {
    let icon: String
    let title: String
    let description: String

    var id: String { title }
}

#Preview {
    IntroSheetView(onGetStarted: {})
}
