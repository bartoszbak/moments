import SwiftUI

struct ManifestNotificationCard: View {
    let model: ManifestNotificationCardModel
    let onEnable: () -> Void
    let onDisable: () -> Void
    let onSelectRhythm: (ManifestNotificationRhythm) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 18) {
                    cardContent
                }
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Manifest Notifications")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(model.statusTitle.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(model.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                statusChip(title: model.rhythmTitle)
                statusChip(title: model.timeTitle)
            }

            actionRow
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ManifestNotificationCardBackground())
    }

    @ViewBuilder
    private var actionRow: some View {
        if model.isDenied {
            Button("Open Settings", action: onOpenSettings)
                .frame(maxWidth: .infinity)
                .adaptiveGlassProminentButtonStyle()
        } else {
            HStack(spacing: 12) {
                Menu {
                    ForEach(ManifestNotificationRhythm.allCases, id: \.self) { rhythm in
                        Button(rhythm.title) {
                            onSelectRhythm(rhythm)
                        }
                    }
                } label: {
                    Label(model.rhythmTitle, systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                }
                .adaptiveGlassButtonStyle()

                if model.isEnabled {
                    Button("Turn Off", action: onDisable)
                        .frame(maxWidth: .infinity)
                        .adaptiveGlassButtonStyle()
                } else {
                    Button("Turn On", action: onEnable)
                        .frame(maxWidth: .infinity)
                        .adaptiveGlassProminentButtonStyle()
                }
            }
        }
    }

    private func statusChip(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modifier(ManifestNotificationChipBackground())
    }
}

private struct ManifestNotificationCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        }
    }
}

private struct ManifestNotificationChipBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.clear, in: .capsule)
        } else {
            content
                .background(
                    Color(.secondarySystemBackground),
                    in: Capsule()
                )
        }
    }
}
