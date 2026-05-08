//
//  LocationSearchField.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 5/8/26.
//

/*
 자동완성 드롭다운 + TextField. 사용자가 제안을 고르면 좌표까지 resolve 해서
 부모의 resolvedLocation 바인딩을 채운다. 텍스트만 치고 안 고르면 좌표 nil
 */

import SwiftUI
import MapKit

struct LocationSearchField: View {
    
    @Binding var locationText: String
    @Binding var resolvedLocation: EventLocation?
    
    @StateObject private var search = LocationSearchService()
    @State private var isResolving = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("장소 (선택)", text: $locationText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: locationText) { _, newValue in
                        // 사용자가 다시 타이핑하면 이전 좌표는 의도와 어긋날 수 있어 무효화.
                        if let resolved = resolvedLocation, newValue != resolved.name {
                            resolvedLocation = nil
                        }
                        search.update(query: newValue)
                    }
                if isResolving {
                    ProgressView().controlSize(.small)
                }
            }
            
            if isFocused, !search.completions.isEmpty, resolvedLocation == nil {
                suggestionsList
            }
        }
    }
    
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(search.completions, id: \.self) { completion in
                Button {
                    pick(completion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if completion != search.completions.last {
                    Divider()
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func pick(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let resolved = try await search.resolve(completion)
                locationText = resolved.name
                resolvedLocation = resolved
                search.update(query: "")
                isFocused = false
            } catch {
                // 좌표 변환 실패 — 텍스트만 채우고 좌표는 nil 유지.
                locationText = completion.title
                isFocused = false
            }
        }
    }
}
