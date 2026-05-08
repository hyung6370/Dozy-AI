//
//  LocationSearchService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 5/8/26.
//

import Foundation
import Combine
import MapKit

@MainActor
final class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        // POI(상호) + 주소 모두 - 카페, 식다 같은 장소명도 잡히고 도로명 주소도 잡힘
        completer.resultTypes = [.pointOfInterest, .address]
    }
    
    /// 입력이 비면 결과 비우고 fetch 중단, 그 외에는 completer가 내부적으로 디바운스
    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            completions = []
            completer.cancel()
            return
        }
        completer.queryFragment = trimmed
    }
    
    /// 선택된 completion을 좌표 포함 EventLocation으로 변환
    /// MKLocalSearch가 비동기라 async - 호출부에서 Task 안에서 await
    func resolve(_ completion: MKLocalSearchCompletion) async throws -> EventLocation {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw LocationSearchError.noResult
        }
        let coord = item.placemark.coordinate
        return EventLocation(
            name: completion.title,
            address: completion.subtitle.isEmpty ? nil : completion.subtitle,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.completions = results }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.completions = [] }
    }
}

enum LocationSearchError: Error {
    case noResult
}
