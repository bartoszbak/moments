import SwiftUI
import UIKit

extension View {
    /// Applies Liquid Glass on iOS 26+, falls back to ultraThinMaterial on earlier OS.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        }
    }

    /// Interactive Liquid Glass for tappable surfaces.
    @ViewBuilder
    func interactiveGlassCard(cornerRadius: CGFloat = 20) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        }
    }

    /// Apply `.glass` button style on iOS 26+, `.bordered` on earlier OS.
    @ViewBuilder
    func adaptiveGlassButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Apply `.glassProminent` button style on iOS 26+, `.borderedProminent` on earlier OS.
    @ViewBuilder
    func adaptiveGlassProminentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Restores the native switch style on iPad so toggles can use the system Liquid Glass rendering.
    @ViewBuilder
    func nativeGlassToggleStyleOnIPad(tintColor: Color) -> some View {
        if #available(iOS 26, *), UIDevice.current.userInterfaceIdiom == .pad {
            self.toggleStyle(SwitchToggleStyle(tint: tintColor))
        } else {
            self
        }
    }

    /// Black-tinted circular Liquid Glass on iOS 26+, dark circle fallback on earlier OS.
    /// Use inside a Button — omits .interactive() to avoid a double-ring with Button's own highlight.
    @ViewBuilder
    func blackGlassCircle() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(.black), in: .circle)
        } else {
            self.background(Color.black.opacity(0.85), in: Circle())
        }
    }
}
