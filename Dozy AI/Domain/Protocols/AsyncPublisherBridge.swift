//
//  AsyncPublisherBridge.swift
//  Dozy AI
//
//  async → AnyPublisher 임시 브리지 (#153). Data 계층을 async 로 바꾸는 동안 위 계층(UseCase · ViewModel)이
//  그대로 컴파일되도록, 프로토콜 확장에 같은 이름의 동기 Publisher 판을 두고 이 헬퍼로 감싼다.
//  동기 문맥은 Publisher 판, `await` 문맥은 async 판을 고른다. #154 · #155 가 호출부를 옮기면 #156 에서 지운다.
//
//  - Future: 만들자마자 실행 · 취소 불가 — 기존 `Future { Task { @MainActor … } }` 와 같은 동작.
//  - promise 는 메인 액터에서 넘긴다. 하류의 sink · map 이 메인 액터로 추론돼 있어 다른 큐에서 값을 내면
//    Swift 6 런타임 격리 검사로 앱이 죽는다 (#152 · PR #162).
//

import Combine

extension AnyPublisher where Failure == DozyError {
    @MainActor
    static func bridge(
        _ operation: @escaping @MainActor () async throws(DozyError) -> Output
    ) -> AnyPublisher<Output, DozyError> {
        Future { promise in
            Task { @MainActor in
                do throws(DozyError) {
                    promise(.success(try await operation()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

extension AnyPublisher where Failure == Never {
    @MainActor
    static func bridge(
        _ operation: @escaping @MainActor () async -> Output
    ) -> AnyPublisher<Output, Never> {
        Future { promise in
            Task { @MainActor in
                promise(.success(await operation()))
            }
        }
        .eraseToAnyPublisher()
    }
}
