//
//  LocationMapView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 5/8/26.
//

import SwiftUI
import MapKit

struct LocationMapView: View {
    let location: EventLocation
    
    @State private var cameraPosition: MapCameraPosition
    
    init(location: EventLocation) {
        self.location = location
        let coord = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        let region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 400,
            longitudinalMeters: 400
        )
        _cameraPosition = State(initialValue: .region(region))
    }
    
    var body: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            Marker(location.name, coordinate: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ))
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { openInAppleMaps() }
    }
    
    /// 시스템 지도 앱으로 길찾기 — 사용자가 임베드 지도 탭 시 호출.
    private func openInAppleMaps() {
        let coord = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        let placemark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: placemark)
        item.name = location.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: NSNumber(value: MKMapType.standard.rawValue)
        ])
    }
}
