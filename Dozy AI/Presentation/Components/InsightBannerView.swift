//
//  InsightBannerView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/3/26.
//

import SwiftUI

struct InsightBannerView: View {
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 3) {
                Text("더 깊은 분석이 필요하신가요?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Pro 플랜에서 90일 이상 데이터를 확인하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("PRO")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.indigo, in: Capsule())
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    InsightBannerView()
}
