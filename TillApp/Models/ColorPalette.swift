import SwiftUI

struct PaletteColor {
    let color: Color
    let lightness: Double
    let hexString: String
}

enum ColorPalette {
    static let presets: [PaletteColor] = [
        .make(l: 0.85,  c: 0.16,  h:  30),   // warm peach
        .make(l: 0.85,  c: 0.16,  h: 150),   // mint
        .make(l: 0.85,  c: 0.16,  h: 250),   // periwinkle
        .make(l: 0.85,  c: 0.16,  h: 320),   // pink
        .make(l: 0.20,  c: 0.003, h: 240),   // near black
        .make(l: 0.961, c: 0.078, h:  75),   // pale yellow
    ]
}

private extension PaletteColor {
    static func make(l: Double, c: Double, h: Double) -> PaletteColor {
        let (r, g, b) = oklchToSRGB(l: l, c: c, h: h)
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        return PaletteColor(color: Color(red: r, green: g, blue: b), lightness: l, hexString: hex)
    }
}

// MARK: - OKLCH → sRGB

private func oklchToSRGB(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
    let hRad = h * .pi / 180
    let a = c * cos(hRad)
    let b = c * sin(hRad)

    let l_ = l + 0.3963377774 * a + 0.2158037573 * b
    let m_ = l - 0.1055613458 * a - 0.0638541728 * b
    let s_ = l - 0.0894841775 * a - 1.2914855480 * b

    let lc = l_ * l_ * l_
    let mc = m_ * m_ * m_
    let sc = s_ * s_ * s_

    let rLin =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
    let gLin = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
    let bLin = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

    return (gammaEncode(rLin), gammaEncode(gLin), gammaEncode(bLin))
}

private func gammaEncode(_ x: Double) -> Double {
    let v = max(0, min(1, x))
    return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055
}
