//
//  EventLocation.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 5/8/26.
//

/*
 사용자가 자동완성 제안에서 고른 장소 - 표시명 + 좌표 + 보조주소
 DozyEvent에는 location(String?) + latitude/longitude(Double?)로 분리 저장하지만,
 ViewModel <-> View 사이에선 이 값 타입 하나로 다룬다.
 */

import Foundation

struct EventLocation: Equatable, Hashable {
    /// POI 이름. DozyEvent.location에 저장될 표시명
    let name: String
    /// completer의 subtitle(주소, 부가 설명). nil 가능
    let address: String?
    let latitude: Double
    let longitude: Double
}
