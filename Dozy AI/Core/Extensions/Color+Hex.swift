//
//  Color+Hex.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import SwiftUI
import UIKit

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
    
    func toHex() -> String? {
        // cgColor.components는 P3/extended 컬러스페이스에서 잘못된 값을 반환할 수 있음
        // getRed(_:green:blue:alpha:)는 항상 sRGB로 변환하여 정확한 hex를 반환
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(lroundf(Float(r) * 255)),
                      Int(lroundf(Float(g) * 255)),
                      Int(lroundf(Float(b) * 255)))
    }
}
