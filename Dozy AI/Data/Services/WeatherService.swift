//
//  WeatherService.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/16/26.
//

import Foundation
@preconcurrency import CoreLocation
import OSLog
import Combine

final class DozyWeatherService: NSObject, ObservableObject {

    @Published var weather: CurrentWeatherInfo? = nil
    @Published var locationName: String? = nil
    @Published var state: WeatherLoadState = .idle

    enum WeatherLoadState {
        case idle, loading, loaded, denied, failed
    }

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetchIfNeeded() {
        guard state == .idle || state == .failed else { return }
        state = .loading

        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
    }

    // MARK: - Private

    private func fetchWeather(for location: CLLocation) {
        state = .loaded   // 재진입 방지
        Task {
            do {
                let lat = location.coordinate.latitude
                let lon = location.coordinate.longitude
                let urlString = "https://api.open-meteo.com/v1/forecast"
                    + "?latitude=\(lat)&longitude=\(lon)"
                    + "&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,is_day"
                    + "&timezone=auto"

                guard let url = URL(string: urlString) else { throw URLError(.badURL) }
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let current = response.current

                let geocoder = CLGeocoder()
                let placemarks = try? await geocoder.reverseGeocodeLocation(location)
                let city = placemarks?.first?.locality
                    ?? placemarks?.first?.administrativeArea

                await MainActor.run {
                    self.weather = CurrentWeatherInfo(
                        temperature: current.temperature2m,
                        feelsLike: current.apparentTemperature,
                        weatherCode: current.weatherCode,
                        humidity: current.relativeHumidity2m,
                        isDay: current.isDay == 1
                    )
                    self.locationName = city
                    self.state = .loaded
                }
                Logger.app.info("☀️ 날씨 로드 완료: \(city ?? "알 수 없음") \(Int(current.temperature2m.rounded()))°")
            } catch {
                Logger.app.error("날씨 로드 실패: \(error.localizedDescription)")
                await MainActor.run { self.state = .failed }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension DozyWeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        DispatchQueue.main.async {
            guard self.state == .loading else { return }
            self.fetchWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            Logger.app.error("위치 오류: \(error.localizedDescription)")
            self.state = .failed
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                guard self.state == .loading else { return }
                self.locationManager.requestLocation()
            case .denied, .restricted:
                self.state = .denied
            default:
                break
            }
        }
    }
}

// MARK: - Open-Meteo Response

private struct OpenMeteoResponse: Decodable {
    let current: CurrentData

    struct CurrentData: Decodable {
        let temperature2m: Double
        let apparentTemperature: Double
        let weatherCode: Int
        let relativeHumidity2m: Double
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case relativeHumidity2m = "relative_humidity_2m"
            case isDay = "is_day"
        }
    }
}

// MARK: - Model

struct CurrentWeatherInfo {
    let temperature: Double
    let feelsLike: Double
    let weatherCode: Int
    let humidity: Double
    let isDay: Bool

    var temperatureString: String { "\(Int(temperature.rounded()))°" }
    var feelsLikeString: String { "체감 \(Int(feelsLike.rounded()))°" }
    var humidityString: String { "습도 \(Int(humidity))%" }

    /// WMO 날씨 코드 → 한국어 상태
    var conditionString: String {
        switch weatherCode {
        case 0:           return "맑음"
        case 1:           return "대체로 맑음"
        case 2:           return "부분적으로 흐림"
        case 3:           return "흐림"
        case 45, 48:      return "안개"
        case 51, 53, 55:  return "이슬비"
        case 61, 63, 65:  return "비"
        case 71, 73, 75:  return "눈"
        case 77:          return "눈 결정"
        case 80, 81, 82:  return "소나기"
        case 85, 86:      return "눈 소나기"
        case 95:          return "뇌우"
        case 96, 99:      return "우박 동반 뇌우"
        default:          return "날씨 정보 없음"
        }
    }

    /// WMO 날씨 코드 → 이모지 (isDay 반영)
    var emoji: String {
        switch weatherCode {
        case 0:           return isDay ? "☀️" : "🌙"
        case 1:           return isDay ? "🌤️" : "🌙"
        case 2:           return isDay ? "⛅" : "☁️"
        case 3:           return "☁️"
        case 45, 48:      return "🌫️"
        case 51, 53, 55:  return "🌦️"
        case 61, 63, 65:  return "🌧️"
        case 71, 73, 75:  return "🌨️"
        case 77:          return "❄️"
        case 80, 81, 82:  return "🌧️"
        case 85, 86:      return "🌨️"
        case 95:          return "⛈️"
        case 96, 99:      return "⛈️"
        default:          return "🌡️"
        }
    }
}
