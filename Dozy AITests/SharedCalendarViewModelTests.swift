//
//  SharedCalendarViewModelTests.swift
//  Dozy AITests
//
//  공유 캘린더 설정 저장 · 나가기 결과 콜백 (#144) — 실패 때도 completion(false) 를 불러야 한다.
//  이전엔 성공 때만 불러 iOS 설정 시트의 저장이 끝나지 않았다(DispatchGroup 이 leave 되지 않음).
//  iOS · macOS 테스트 타깃 공통.
//

import XCTest
import Combine
@testable import Dozy_AI

@MainActor
final class SharedCalendarViewModelTests: XCTestCase {

    private var service: MockSharedCalendarService!
    private var vm: SharedCalendarViewModel!

    override func setUp() async throws {
        try await super.setUp()
        service = MockSharedCalendarService()
        vm = SharedCalendarViewModel(
            createUseCase: CreateSharedCalendarUseCase(service: service),
            joinUseCase: JoinSharedCalendarUseCase(service: service),
            leaveUseCase: LeaveSharedCalendarUseCase(service: service),
            regenerateUseCase: RegenerateSharedCalendarInviteCodeUseCase(service: service),
            updateNicknameUseCase: UpdateSharedCalendarNicknameUseCase(service: service),
            service: service
        )
    }

    override func tearDown() async throws {
        vm = nil
        service = nil
        try await super.tearDown()
    }

    private func calendar(_ id: String = "cal-1", name: String = "우리 집") -> SharedCalendar {
        SharedCalendar(id: id, name: name, inviteCode: nil, inviteCodeExpiresAt: nil,
                       createdBy: "owner", createdAt: Date(), imagePath: nil)
    }

    /// completion 이 불릴 때까지 기다려 결과를 돌려준다. 끝내 안 불리면 nil.
    private func awaitCompletion(_ start: (@escaping (Bool) -> Void) -> Void) -> Bool? {
        var result: Bool?
        let done = expectation(description: "completion")
        start { success in
            result = success
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        return result
    }

    // MARK: - 이름

    func test_updateCalendarName_success_updatesNameAndReportsTrue() {
        vm.calendars = [calendar()]
        let result = awaitCompletion { vm.updateCalendarName(calendarID: "cal-1", name: "새 이름", completion: $0) }
        XCTAssertEqual(result, true)
        XCTAssertEqual(vm.calendars.first?.name, "새 이름")
    }

    func test_updateCalendarName_failure_reportsFalse() {
        service.stubbedError = .saveFailed(underlying: NSError(domain: "test", code: 1))
        vm.calendars = [calendar()]
        let result = awaitCompletion { vm.updateCalendarName(calendarID: "cal-1", name: "새 이름", completion: $0) }
        XCTAssertEqual(result, false)
        XCTAssertEqual(vm.calendars.first?.name, "우리 집")
        XCTAssertNotNil(vm.errorMessage)   // macOS 알림창용
    }

    // MARK: - 닉네임

    func test_updateNickname_failure_reportsFalse() {
        service.stubbedError = .saveFailed(underlying: NSError(domain: "test", code: 1))
        let result = awaitCompletion {
            vm.updateNickname(calendarID: "cal-1", nickname: "곰", currentUserID: "me", completion: $0)
        }
        XCTAssertEqual(result, false)
    }

    func test_updateNickname_success_reportsTrue() {
        let result = awaitCompletion {
            vm.updateNickname(calendarID: "cal-1", nickname: "곰", currentUserID: "me", completion: $0)
        }
        XCTAssertEqual(result, true)
    }

    // MARK: - 나가기

    func test_leave_success_removesCalendarAndReportsTrue() {
        vm.calendars = [calendar()]
        let result = awaitCompletion { vm.leave(calendar: calendar(), currentUserID: "me", completion: $0) }
        XCTAssertEqual(result, true)
        XCTAssertTrue(vm.calendars.isEmpty)
    }

    func test_leave_failure_keepsCalendarAndReportsFalse() {
        service.stubbedError = .saveFailed(underlying: NSError(domain: "test", code: 1))
        vm.calendars = [calendar()]
        let result = awaitCompletion { vm.leave(calendar: calendar(), currentUserID: "me", completion: $0) }
        XCTAssertEqual(result, false)
        XCTAssertEqual(vm.calendars.count, 1)
        XCTAssertFalse(vm.isLoading)
    }
}
