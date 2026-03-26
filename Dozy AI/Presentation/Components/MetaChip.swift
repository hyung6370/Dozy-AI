//
//  MetaChip.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/26/26.
//

import SwiftUI

struct MetaChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
    }
}
