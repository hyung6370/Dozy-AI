//
//  NetworkMonitor.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/13/26.
//

import Foundation
import Network
import Combine
import OSLog

/// NWPathMonitor를 감싸는 네트워크 상태 옵저버.
/// 앱 전역에서 `NetworkMonitor.shared`로 접근합니다.
///
/// - `isConnected`: 현재 네트워크 연결 여부 (메인 스레드에서 업데이트)
/// - `connectionType`: 연결 타입 (wifi / cellular / wiredEthernet 등)
@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: NWInterface.InterfaceType? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.dozy-ai.NetworkMonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let connected = path.status == .satisfied
                if self.isConnected != connected {
                    Logger.network.info("🌐 네트워크 상태 변경: \(connected ? "연결됨" : "끊김")")
                }
                self.isConnected = connected
                self.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
