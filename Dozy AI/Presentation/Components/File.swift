//
//  File.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import SwiftUI

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)   // ← color 파라미터 적용 (기존: 하드코딩 .blue)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
