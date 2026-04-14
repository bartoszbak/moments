import SwiftUI
import UIKit

private let defaultInterfaceTintHex = "#D3E2FF"

enum MomentSymbolPolicy {
    static func normalized(_ symbolName: String?) -> String? {
        guard let trimmed = symbolName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.hasSuffix(".fill")
        else {
            return nil
        }

        return trimmed
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >>  8) & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }

    /// sRGB hex string, resolved in light mode. Never returns nil for standard colors.
    var hexString: String {
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }

    var relativeLuminance: Double {
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: nil) else { return 1 }

        func linearize(_ component: CGFloat) -> Double {
            let value = Double(component)
            if value <= 0.04045 {
                return value / 12.92
            }

            return pow((value + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linearize(r)) + (0.7152 * linearize(g)) + (0.0722 * linearize(b))
    }

    var prefersLightForeground: Bool {
        relativeLuminance < 0.45
    }

    var requiresDarkModeTintOverride: Bool {
        relativeLuminance < 0.18
    }
}

enum AppTheme {
    static func preferredColorScheme(for appearance: String) -> ColorScheme? {
        switch appearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    static func baseInterfaceTintColor(from hex: String) -> Color {
        Color(hex: hex) ?? Color(hex: defaultInterfaceTintHex) ?? .blue
    }

    static func defaultInterfaceTintColor(for colorScheme: ColorScheme) -> Color {
        interfaceTintColor(from: defaultInterfaceTintHex, for: colorScheme)
    }

    static func interfaceTintColor(from hex: String, for colorScheme: ColorScheme) -> Color {
        let baseColor = baseInterfaceTintColor(from: hex)

        if colorScheme == .dark && baseColor.requiresDarkModeTintOverride {
            return .white
        }

        return baseColor
    }
}

enum AppHaptics {
    private static let settingsKey = "settings.haptics.enabled"
    private static let defaultEnabled = true

    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard

        guard defaults.object(forKey: settingsKey) != nil else {
            return defaultEnabled
        }

        return defaults.bool(forKey: settingsKey)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
