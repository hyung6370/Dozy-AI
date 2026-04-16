//
//  WeatherCardView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/16/26.
//

import SwiftUI

struct WeatherCardView: View {

    @StateObject private var service = DozyWeatherService()

    var body: some View {
        Group {
            if let weather = service.weather {
                weatherContent(weather)
            } else {
                loadingView
            }
        }
        .onAppear { service.fetchIfNeeded() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView().scaleEffect(0.8).tint(.white)
            Text("날씨 불러오는 중...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(20)
        .background(
            LinearGradient(colors: [Color(hex: "4A90D9") ?? .blue, Color(hex: "1C5FAD") ?? .blue.opacity(0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    // MARK: - Weather Content

    private func weatherContent(_ weather: CurrentWeatherInfo) -> some View {
        VStack(spacing: 0) {
            // 위치
            if let city = service.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(city)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.top, 20)
            } else {
                Spacer().frame(height: 20)
            }

            Spacer()

            // 날씨 아이콘 + 기온
            VStack(spacing: 4) {
                Text(weather.emoji)
                    .font(.system(size: 64))

                Text(weather.temperatureString)
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white)

                Text(weather.conditionString)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            // 하단 구분선 + 상세 정보
            Divider()
                .overlay(Color.white.opacity(0.3))
                .padding(.horizontal, 20)

            HStack {
                detailItem(icon: "thermometer.medium", text: weather.feelsLikeString)
                Spacer()
                detailItem(icon: "humidity.fill", text: weather.humidityString)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(
            LinearGradient(
                colors: cardGradientColors(weather),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(color: cardGradientColors(weather).first?.opacity(0.4) ?? .clear, radius: 12, y: 6)
    }

    private func detailItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Gradient

    private func cardGradientColors(_ weather: CurrentWeatherInfo) -> [Color] {
        switch weather.weatherCode {
        case 0, 1:
            return weather.isDay
                ? [Color(hex: "56CCF2") ?? .cyan, Color(hex: "2F80ED") ?? .blue]
                : [Color(hex: "1A1A4E") ?? .indigo, Color(hex: "2C3E8C") ?? .blue]
        case 2, 3:
            return weather.isDay
                ? [Color(hex: "8E9EBB") ?? .gray, Color(hex: "5A6A85") ?? .gray]
                : [Color(hex: "2C3A4A") ?? .gray, Color(hex: "1A2535") ?? .black]
        case 45, 48:
            return [Color(hex: "B0BEC5") ?? .gray, Color(hex: "78909C") ?? .gray]
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return [Color(hex: "4B6CB7") ?? .blue, Color(hex: "182848") ?? .indigo]
        case 71, 73, 75, 77, 85, 86:
            return [Color(hex: "A8BFCC") ?? .cyan, Color(hex: "6E8FA3") ?? .blue]
        case 95, 96, 99:
            return [Color(hex: "373B44") ?? .gray, Color(hex: "1C1C2E") ?? .black]
        default:
            return [Color(hex: "4A90D9") ?? .blue, Color(hex: "1C5FAD") ?? .blue]
        }
    }
}
