//
//  CalendarVisibilityFilterTests.swift
//  Dozy AITests
//

import Testing
import Foundation
@testable import Dozy_AI

@Suite("CalendarVisibilityFilter")
final class CalendarVisibilityFilterTests {

    // 테스트마다 고유한 suite → 실제 사용자 설정도, 다른 테스트도 오염시키지 않는다
    private let suiteName = "test.visibility.\(UUID().uuidString)"
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    // 프로덕션의 private 키를 일부러 복제해 둔다.
    // 키가 바뀌면 이 테스트가 깨지는 게 맞다 — 사용자의 저장된 설정이 날아가는 변경이니까.
    private let sourcesKey = "dozy_hidden_calendar_sources"
    private let sharedKey = "dozy_hidden_shared_calendar_ids"

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeSUT() -> CalendarVisibilityFilter {
        CalendarVisibilityFilter(defaults: defaults)
    }

    private func makeCalendar(id: String) -> SharedCalendar {
        SharedCalendar(id: id, name: "테스트", inviteCode: nil,
                       inviteCodeExpiresAt: nil, createdBy: "me",
                       createdAt: Date(), imagePath: nil)
    }

    // MARK: - 초기화 / 복원

    @Test("빈 저장소로 시작하면 아무것도 숨기지 않는다")
    func 초기상태_빈저장소() {
        let sut = makeSUT()
        #expect(sut.hiddenSources.isEmpty)
        #expect(sut.hiddenSharedCalendarIDs.isEmpty)
        #expect(sut.isFilterActive == false)
    }

    @Test("저장돼 있던 숨김 소스를 복원한다")
    func 초기화_저장값복원() {
        defaults.set(["apple", "google"], forKey: sourcesKey)
        #expect(makeSUT().hiddenSources == [.apple, .google])
    }

    @Test("알 수 없는 rawValue 는 버리고 유효한 값만 복원한다")
    func 초기화_알수없는값무시() {
        defaults.set(["apple", "notion"], forKey: sourcesKey)
        #expect(makeSUT().hiddenSources == [.apple])
    }

    // MARK: - dozy 마이그레이션

    @Test("과거에 dozy 를 숨긴 상태였어도 항상 표시한다")
    func 마이그레이션_메모리에서제거() {
        defaults.set(["dozy", "apple"], forKey: sourcesKey)
        #expect(makeSUT().hiddenSources == [.apple])
    }

    @Test("마이그레이션 결과가 저장소에도 반영된다")
    func 마이그레이션_저장소에도반영() {
        defaults.set(["dozy", "apple"], forKey: sourcesKey)
        _ = makeSUT()
        #expect(defaults.array(forKey: sourcesKey) as? [String] == ["apple"])
    }

    @Test("마이그레이션할 게 없으면 초기화만으로 저장소에 쓰지 않는다")
    func 마이그레이션_불필요하면쓰지않음() {
        _ = makeSUT()
        #expect(defaults.array(forKey: sourcesKey) as? [String] == nil)
    }

    // MARK: - 소스 가시성

    @Test("기본적으로 모든 소스가 보인다", arguments: CalendarSource.allCases)
    func 기본가시성(source: CalendarSource) {
        #expect(makeSUT().isVisible(source))
    }

    @Test("숨겼다 다시 켜면 원래대로 돌아온다", arguments: CalendarSource.allCases)
    func 가시성_왕복(source: CalendarSource) {
        let sut = makeSUT()
        sut.setVisible(source, false)
        #expect(sut.isVisible(source) == false)
        sut.setVisible(source, true)
        #expect(sut.isVisible(source))
    }

    @Test("toggle 은 현재 상태를 뒤집는다")
    func toggle_상태반전() {
        let sut = makeSUT()
        sut.toggle(.google)
        #expect(sut.isVisible(.google) == false)
        sut.toggle(.google)
        #expect(sut.isVisible(.google))
    }

    // MARK: - 영속성

    @Test("숨긴 소스는 새 인스턴스에서도 유지된다")
    func 영속성_소스() {
        makeSUT().setVisible(.naver, false)
        #expect(makeSUT().isVisible(.naver) == false)
    }

    @Test("숨긴 공유 캘린더는 새 인스턴스에서도 유지된다")
    func 영속성_공유캘린더() {
        makeSUT().setVisibleSharedCalendar("cal-1", false)
        #expect(makeSUT().isVisibleSharedCalendar("cal-1") == false)
    }

    // MARK: - isFilterActive (하나씩만 참인 입력)

    @Test("소스만 숨겨도 필터는 활성이다")
    func 필터활성_소스만() {
        let sut = makeSUT()
        sut.setVisible(.apple, false)
        #expect(sut.isFilterActive)
    }

    @Test("공유 캘린더만 숨겨도 필터는 활성이다")
    func 필터활성_공유캘린더만() {
        let sut = makeSUT()
        sut.setVisibleSharedCalendar("cal-1", false)
        #expect(sut.isFilterActive)
    }

    @Test("둘 다 비어 있을 때만 비활성이다")
    func 필터비활성_둘다빔() {
        #expect(makeSUT().isFilterActive == false)
    }

    // MARK: - reconcile

    @Test("더 이상 존재하지 않는 공유 캘린더 ID 는 정리된다")
    func reconcile_사라진ID정리() {
        let sut = makeSUT()
        sut.setVisibleSharedCalendar("gone", false)
        sut.setVisibleSharedCalendar("alive", false)
        sut.reconcileSharedCalendars(with: [makeCalendar(id: "alive")])
        #expect(sut.hiddenSharedCalendarIDs == ["alive"])
    }

    @Test("정리할 게 없으면 저장소에 다시 쓰지 않는다")
    func reconcile_변화없으면쓰지않음() {
        let sut = makeSUT()
        sut.setVisibleSharedCalendar("alive", false)
        defaults.set(["sentinel"], forKey: sharedKey)   // 쓰기가 일어나면 덮어써질 표식
        sut.reconcileSharedCalendars(with: [makeCalendar(id: "alive")])
        #expect(defaults.array(forKey: sharedKey) as? [String] == ["sentinel"])
    }

    @Test("남은 캘린더가 없으면 숨김 목록을 전부 비운다")
    func reconcile_빈목록이면전부제거() {
        let sut = makeSUT()
        sut.setVisibleSharedCalendar("a", false)
        sut.reconcileSharedCalendars(with: [])
        #expect(sut.hiddenSharedCalendarIDs.isEmpty)
    }

    // MARK: - reset

    @Test("reset 은 메모리와 저장소를 모두 비운다")
    func reset_전체초기화() {
        let sut = makeSUT()
        sut.setVisible(.apple, false)
        sut.setVisibleSharedCalendar("a", false)
        sut.reset()
        #expect(sut.isFilterActive == false)
        #expect(makeSUT().isFilterActive == false)   // 저장소까지 비워졌는지
    }
}
