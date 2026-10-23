//
//  Publisher+Extensions.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/18/26.
//

import Foundation
import Combine

extension Publisher {
    /// 첫 값 하나를 async로 받는다. 값 없이 완료되면 CancellationError
    /// 백그라운드 작업처럼 Combine 체인을 async 흐름 안에서 한 번만 쓸 때 사용
    func firstValue() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var resumed = false
            cancellable = first().sink(
                receiveCompletion: { completion in
                    guard !resumed else { return }
                    resumed = true
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: CancellationError())
                    }
                    cancellable = nil
                },
                receiveValue: { value in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                    cancellable = nil
                }
            )
        }
    }
}
