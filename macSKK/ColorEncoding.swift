// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

import SwiftUI

enum ColorEncoding {
    // 例: #RRGGBBAA
    static func encode(_ color: Color) -> String? {
        // NSColor に解決（macOS）
        let nsColor = NSColor(color)

        // sRGB に変換
        guard let srgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

        let R = Int(round(r * 255))
        let G = Int(round(g * 255))
        let B = Int(round(b * 255))
        let A = Int(round(a * 255))
        return String(format: "#%02X%02X%02X%02X", R, G, B, A)
    }

    static func decode(_ string: String) -> Color? {
        guard string.hasPrefix("#") else { return nil }
        let hex = String(string.dropFirst())
        guard hex.count == 6 || hex.count == 8,
              let value = UInt64(hex, radix: 16)
        else { return nil }

        let r, g, b, a: Double
        if hex.count == 8 {
            r = Double((value & 0xFF00_0000) >> 24) / 255.0
            g = Double((value & 0x00FF_0000) >> 16) / 255.0
            b = Double((value & 0x0000_FF00) >> 8)  / 255.0
            a = Double( value & 0x0000_00FF)        / 255.0
        } else {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8)  / 255.0
            b = Double( value & 0x0000FF)        / 255.0
            a = 1.0
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
