//
//  MacEventSourceIcon.swift
//  Dozy AI (macOS)
//
//  이벤트 출처(Apple/Google) 를 알려주는 작은 로고. Dozy/Holiday 는 표시 안 함.
//  macOS 캘린더 / Today / 메뉴바의 이벤트 행과 막대에 공통 사용.
//

import SwiftUI

struct MacEventSourceIcon: View {
    let source: CalendarSource
    var size: CGFloat = 12
    var tint: Color? = nil

    @ViewBuilder
    var body: some View {
        if source == .apple {
            Image(systemName: "apple.logo")
                .font(.system(size: size))
                .foregroundStyle(tint ?? .primary)
        } else if source == .google {
            Image("google")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
