//
//  MacWeatherCardView.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/30/26.
//

import SwiftUI
import AppKit

struct MacWeatherCardView: View {
    
    @StateObject private var service = DozyWeatherService()
    
    var body: some View {
        Group {
            switch service.state {
            case .idle:
                permissionPromptView
            case .loading:
                loadingView
            case .loaded:
                if let weather = service.weather {
                    weatherContent(weather)
                }
            case .denied:
                deniedView
            case .failed:
                failedView
            }
        }
    }
    
    // MARK: - Permission Prompt (idle)

    private var permissionPromptView: some View {
        Button { service.fetchIfNeeded() } label: {
            HStack(spacing: 14) {
                Text("🌤️").font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 날씨")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("클릭 해서 현재 위치 날씨를 확인하세요")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(defaultGradient, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
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
        .background(defaultGradient, in: RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Denied

    private var deniedView: some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                Text("📍").font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text("위치 권한 필요")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("시스템 설정에서 위치 접근을 허용해주세요")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Text("설정 열기")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2), in: Capsule())
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(defaultGradient, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Failed

    private var failedView: some View {
        Button { service.fetchIfNeeded() } label: {
            HStack(spacing: 14) {
                Text("⚠️").font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text("날씨를 불러오지 못했습니다")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("클릭해서 다시 시도하세요")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(defaultGradient, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Default Gradient (idle/loading/denied/failed 공용)

    private var defaultGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "4A90D9") ?? .blue, Color(hex: "1C5FAD") ?? .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Weather Content
    
    private func weatherContent(_ weather: CurrentWeatherInfo) -> some View {
        VStack(spacing: 0) {
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
            
            VStack(spacing: 4) {
                Text(weather.emoji).font(.system(size: 64))
                Text(weather.temperatureString)
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white)
                Text(weather.conditionString)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            
            Spacer()
            
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
        .compositingGroup()
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
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
    
    // MARK: - Gradient (iOS 동일)
    
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

#Preview {
    MacWeatherCardView()
}
