//
//  SectionHeader.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/25/26.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
