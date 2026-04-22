//
//  Color+Hex.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// sRGB 기준으로 정규화된 hex 문자열을 반환. P3/extended 컬러스페이스 안전.
    func toHex() -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        #elseif canImport(AppKit)
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        return nil
        #endif
        return String(format: "#%02X%02X%02X",
                      Int(lroundf(Float(r) * 255)),
                      Int(lroundf(Float(g) * 255)),
                      Int(lroundf(Float(b) * 255)))
    }
}
