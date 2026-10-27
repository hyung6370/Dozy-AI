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

    /// 일정 카테고리 색을 현재 colorScheme 에서 보기 좋게 보정.
    /// 다크모드에서 어두운 배경에 어두운 사용자 색(예: 검정, 짙은 남색)이 묻혀 안 보이는 문제 해결.
    /// hue·saturation 은 유지하고 brightness 만 임계값 미만일 때 끌어올린다 → 사용자가 고른 색의
    /// "정체성"은 그대로 두면서 시각만 보강.
    func eventDisplayColor(in colorScheme: ColorScheme,
                           darkLiftThreshold: CGFloat = 0.35,
                           darkLiftTo: CGFloat = 0.55) -> Color {
        guard colorScheme == .dark else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        #elseif canImport(AppKit)
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return self }
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        return self
        #endif
        guard b < darkLiftThreshold else { return self }
        return Color(hue: h, saturation: s, brightness: darkLiftTo, opacity: a)
    }

    /// 일정 pill 텍스트에 카테고리 색을 그대로 쓰되, 다크모드에선 어두운 색이 묻혀 안 보이는 걸 방지.
    /// `eventDisplayColor` 는 fill 용이라 더 보수적이고, 이건 텍스트 가독성에 맞춰 임계/타겟이 더 높음.
    /// hue·saturation 은 유지 → 사용자가 고른 색의 정체성은 그대로.
    func eventTextColor(in colorScheme: ColorScheme,
                        darkLiftThreshold: CGFloat = 0.7,
                        darkLiftTo: CGFloat = 0.85) -> Color {
        guard colorScheme == .dark else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        #elseif canImport(AppKit)
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return self }
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        return self
        #endif
        guard b < darkLiftThreshold else { return self }
        return Color(hue: h, saturation: s, brightness: darkLiftTo, opacity: a)
    }

    /// HSB brightness 를 `factor` 만큼 곱한 변형색을 반환. factor < 1 이면 어둡게.
    /// 캘린더 일정 텍스트처럼 대비가 필요한 곳에서 카테고리 색을 진하게 가져갈 때 사용.
    func adjustingBrightness(_ factor: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        #elseif canImport(AppKit)
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return self }
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        return self
        #endif
        return Color(hue: h, saturation: s, brightness: max(0, min(1, b * factor)), opacity: a)
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
