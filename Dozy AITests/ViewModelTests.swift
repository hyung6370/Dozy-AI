//
//  ViewModelTests.swift
//  Dozy AITests
//

import XCTest
import Combine
import SwiftUI
@testable import Dozy_AI

// MARK: - EventEditViewModel Tests

@MainActor
final class EventEditViewModelTests: XCTestCase {

    // 테스트 기준일: 2026년 4월 11일 토요일
    private let selectedDate: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 11
        return Calendar.current.date(from: c)!
    }()

    private func makeDozyEvent(title: String = "테스트", location: String? = nil) -> DozyEvent {
        DozyEvent(title: title, startDate: selectedDate, endDate: selectedDate, location: location)
    }

    // MARK: init - 새 이벤트

    func test_init_newEvent_titleIsEmpty() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertTrue(vm.title.isEmpty)
    }

    func test_init_newEvent_isAllDayIsFalse() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertFalse(vm.isAllDay)
    }

    func test_init_newEvent_defaultStartIs9AM() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(Calendar.current.component(.hour, from: vm.startDate), 9)
    }

    func test_init_newEvent_defaultEndIs10AM() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(Calendar.current.component(.hour, from: vm.endDate), 10)
    }

    func test_init_newEvent_isEditingIsFalse() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertFalse(vm.isEditing)
    }

    func test_init_newEvent_defaultCategoryIsDefault() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.category, UserCategory.defaultName)
    }

    func test_init_newEvent_recurrenceRuleIsNone() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.recurrenceRule, "none")
    }

    func test_init_newEvent_priorityIsZero() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.priority, 0)
    }

    // MARK: init - 기존 이벤트 편집

    func test_init_existingEvent_copiesTitle() {
        let event = makeDozyEvent(title: "중요한 미팅")
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.title, "중요한 미팅")
    }

    func test_init_existingEvent_copiesStartDate() {
        let event = makeDozyEvent()
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.startDate, event.startDate)
    }

    func test_init_existingEvent_isEditingIsTrue() {
        let vm = EventEditViewModel(eventToEdit: makeDozyEvent(), selectedDate: selectedDate, onSave: { _ in })
        XCTAssertTrue(vm.isEditing)
    }

    func test_init_existingEvent_withLocation_copiesLocation() {
        let event = makeDozyEvent(location: "회의실 A")
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.location, "회의실 A")
    }

    func test_init_existingEvent_nilLocation_setsEmptyString() {
        let event = makeDozyEvent(location: nil)
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate, onSave: { _ in })
        XCTAssertEqual(vm.location, "")
    }

    // MARK: isSavable

    func test_isSavable_emptyTitle_returnsFalse() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        vm.title = ""
        XCTAssertFalse(vm.isSavable)
    }

    func test_isSavable_whitespaceOnlyTitle_returnsFalse() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        vm.title = "   "
        XCTAssertFalse(vm.isSavable)
    }

    func test_isSavable_validTitle_returnsTrue() {
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate, onSave: { _ in })
        vm.title = "새 이벤트"
        XCTAssertTrue(vm.isSavable)
    }

    // MARK: save() - 새 이벤트 생성

    func test_save_newEvent_callsOnSaveWithCorrectTitle() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "새 미팅"
        vm.save()
        XCTAssertEqual(saved?.title, "새 미팅")
    }

    func test_save_newEvent_emptyLocation_setsNil() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "이벤트"; vm.location = ""
        vm.save()
        XCTAssertNil(saved?.location)
    }

    func test_save_newEvent_nonEmptyLocation_preserves() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "이벤트"; vm.location = "회의실 B"
        vm.save()
        XCTAssertEqual(saved?.location, "회의실 B")
    }

    func test_save_newEvent_allDayTrue_endEqualsStart() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "종일 이벤트"; vm.isAllDay = true
        vm.save()
        XCTAssertEqual(saved?.startDate, saved?.endDate)
    }

    func test_save_newEvent_noRecurrenceRule_recurrenceEndDateIsNil() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "이벤트"; vm.recurrenceRule = "none"
        vm.save()
        XCTAssertNil(saved?.recurrenceEndDate)
    }

    func test_save_newEvent_withRecurrenceRule_recurrenceEndDateIsSet() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "이벤트"; vm.recurrenceRule = "weekly"
        vm.save()
        XCTAssertNotNil(saved?.recurrenceEndDate)
    }

    func test_save_newEvent_emptyNotes_setsNil() {
        var saved: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: nil, selectedDate: selectedDate) { saved = $0 }
        vm.title = "이벤트"; vm.notes = ""
        vm.save()
        XCTAssertNil(saved?.notes)
    }

    // MARK: save() - 기존 이벤트 수정 (mutates in place)

    func test_save_existingEvent_updatesTitle() {
        let event = makeDozyEvent(title: "원래 제목")
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate, onSave: { _ in })
        vm.title = "수정된 제목"
        vm.save()
        XCTAssertEqual(event.title, "수정된 제목")
    }

    func test_save_existingEvent_noRecurrence_clearsRecurrenceEndDate() {
        let event = makeDozyEvent()
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate, onSave: { _ in })
        vm.title = "이벤트"; vm.recurrenceRule = "none"
        vm.save()
        XCTAssertNil(event.recurrenceEndDate)
    }

    func test_save_existingEvent_callsOnSaveWithSameInstance() {
        let event = makeDozyEvent()
        var savedEvent: DozyEvent?
        let vm = EventEditViewModel(eventToEdit: event, selectedDate: selectedDate) { savedEvent = $0 }
        vm.title = "수정"; vm.save()
        XCTAssertTrue(savedEvent === event)
    }
}

// MARK: - DailySummaryViewModel Tests

final class DailySummaryViewModelTests: XCTestCase {

    private var aiService: MockAIService!
    private var workLogRepo: MockWorkLogRepository!
    private var viewModel: DailySummaryViewModel!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        aiService   = MockAIService()
        workLogRepo = MockWorkLogRepository()
        viewModel   = DailySummaryViewModel(
            generateSummaryUseCase: GenerateDailySummaryUseCase(aiService: aiService,
                                                                repository: workLogRepo),
            fetchRecentLogsUseCase: FetchRecentLogsUseCase(repository: workLogRepo)
        )
    }

    override func tearDown() { cancellables.removeAll(); super.tearDown() }

    // MARK: hasEnoughData

    func test_hasEnoughData_emptyState_returnsFalse() {
        XCTAssertFalse(viewModel.hasEnoughData)
    }

    func test_hasEnoughData_withEvents_returnsTrue() {
        viewModel.events = [makeTestEvent()]
        XCTAssertTrue(viewModel.hasEnoughData)
    }

    func test_hasEnoughData_withCompletedTasks_returnsTrue() {
        viewModel.completedTasks = [makeTestTask()]
        XCTAssertTrue(viewModel.hasEnoughData)
    }

    func test_hasEnoughData_withMemos_returnsTrue() {
        viewModel.memos = ["메모"]
        XCTAssertTrue(viewModel.hasEnoughData)
    }

    // MARK: scorePercentage

    func test_scorePercentage_noSummary_returnsZero() {
        viewModel.summary = nil
        XCTAssertEqual(viewModel.scorePercentage, 0)
    }

    func test_scorePercentage_75percent_returns75() {
        viewModel.summary = makeTestSummary(score: 0.75)
        XCTAssertEqual(viewModel.scorePercentage, 75)
    }

    func test_scorePercentage_perfectScore_returns100() {
        viewModel.summary = makeTestSummary(score: 1.0)
        XCTAssertEqual(viewModel.scorePercentage, 100)
    }

    // MARK: peakHourLabel

    func test_peakHourLabel_noActivities_returnsNoData() {
        viewModel.hourlyActivities = []
        XCTAssertEqual(viewModel.peakHourLabel, "데이터 없음")
    }

    func test_peakHourLabel_withActivities_returnsLabel() {
        viewModel.hourlyActivities = [
            HourlyActivity(hour: 9,  eventCount: 1, taskCount: 0),
            HourlyActivity(hour: 14, eventCount: 3, taskCount: 1)
        ]
        XCTAssertFalse(viewModel.peakHourLabel.isEmpty)
        XCTAssertNotEqual(viewModel.peakHourLabel, "데이터 없음")
    }

    // MARK: generateSummary - 데이터 부족

    func test_generateSummary_noData_setsErrorMessage() {
        viewModel.generateSummary()
        XCTAssertEqual(viewModel.errorMessage, "요약할 데이터가 부족합니다.")
    }

    func test_generateSummary_noData_doesNotStartGenerating() {
        viewModel.generateSummary()
        XCTAssertFalse(viewModel.isGenerating)
    }

    // MARK: generateSummary - 성공 흐름

    func test_generateSummary_setsIsGeneratingTrue() {
        aiService.stubbedSummary = makeTestSummary()
        viewModel.events = [makeTestEvent()]
        viewModel.generateSummary()
        XCTAssertTrue(viewModel.isGenerating)
    }

    func test_generateSummary_onSuccess_setsSummary() {
        let expectation = self.expectation(description: "summary 설정")
        aiService.stubbedSummary = makeTestSummary(summaryText: "오늘 요약")
        viewModel.events = [makeTestEvent()]

        viewModel.$summary
            .dropFirst()
            .sink { summary in
                XCTAssertEqual(summary?.summaryText, "오늘 요약")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.generateSummary()
        wait(for: [expectation], timeout: 2.0)
    }

    func test_generateSummary_onSuccess_resetsIsGenerating() {
        let expectation = self.expectation(description: "isGenerating = false")
        aiService.stubbedSummary = makeTestSummary()
        viewModel.events = [makeTestEvent()]

        var seenTrue = false
        viewModel.$isGenerating
            .sink { isGenerating in
                if isGenerating { seenTrue = true }
                if !isGenerating && seenTrue { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.generateSummary()
        wait(for: [expectation], timeout: 2.0)
    }

    func test_generateSummary_onSuccess_clearsGenerationProgress() {
        let expectation = self.expectation(description: "progress 초기화")
        aiService.stubbedSummary = makeTestSummary()
        viewModel.events = [makeTestEvent()]

        viewModel.$isGenerating
            .filter { !$0 }
            .dropFirst()
            .sink { [weak self] _ in
                XCTAssertTrue(self?.viewModel.generationProgress.isEmpty ?? false)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.generateSummary()
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: generateSummary - 실패 흐름

    func test_generateSummary_onFailure_setsErrorMessage() {
        let expectation = self.expectation(description: "errorMessage 설정")
        aiService.stubbedError = DozyError.aiSummarizationFailed
        viewModel.events = [makeTestEvent()]

        viewModel.$errorMessage
            .dropFirst()
            .compactMap { $0 }
            .sink { message in
                XCTAssertFalse(message.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.generateSummary()
        wait(for: [expectation], timeout: 2.0)
    }

    func test_generateSummary_onFailure_resetsIsGenerating() {
        let expectation = self.expectation(description: "isGenerating = false on error")
        aiService.stubbedError = DozyError.aiSummarizationFailed
        viewModel.events = [makeTestEvent()]

        var seenTrue = false
        viewModel.$isGenerating
            .sink { isGenerating in
                if isGenerating { seenTrue = true }
                if !isGenerating && seenTrue { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.generateSummary()
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: buildHighlightsData

    func test_buildHighlightsData_emptyInput_producesEmptyHighlights() {
        viewModel.buildHighlightsData()
        XCTAssertTrue(viewModel.categorizedHighlights.isEmpty)
    }

    func test_buildHighlightsData_withEvents_groupsByCategory() {
        viewModel.events = [
            makeTestEvent(title: "미팅 A"),
            makeTestEvent(title: "미팅 B")
        ]
        viewModel.buildHighlightsData()
        XCTAssertFalse(viewModel.categorizedHighlights.isEmpty)
        XCTAssertEqual(viewModel.categorizedHighlights[0].items.count, 2)
    }

    func test_buildHighlightsData_createsHourlyActivitiesFor7to21() {
        viewModel.buildHighlightsData()
        // 7시 ~ 21시 = 15개
        XCTAssertEqual(viewModel.hourlyActivities.count, 15)
    }

    func test_buildHighlightsData_withTasks_addsToDefaultCategory() {
        viewModel.completedTasks = [makeTestTask(title: "PR 리뷰")]
        viewModel.buildHighlightsData()
        let defaultGroup = viewModel.categorizedHighlights.first {
            $0.category.name == UserCategory.defaultName
        }
        XCTAssertNotNil(defaultGroup)
        XCTAssertTrue(defaultGroup?.items.first?.contains("PR 리뷰") ?? false)
    }

    // MARK: buildRecommendationsData

    func test_buildRecommendationsData_noData_producesEmptyList() {
        viewModel.buildRecommendationsData()
        XCTAssertTrue(viewModel.recommendedActions.isEmpty)
    }

    func test_buildRecommendationsData_fromAI_usesAISuggestions() {
        viewModel.summary = makeTestSummary(nextActions: ["AI 추천 작업"])
        viewModel.buildRecommendationsData()
        XCTAssertFalse(viewModel.recommendedActions.isEmpty)
        XCTAssertTrue(viewModel.recommendedActions.first?.isFromAI ?? false)
    }

    func test_buildRecommendationsData_highPriorityTask_comesBefore_lowPriorityTask() {
        viewModel.pendingTasks = [
            makeTestTask(title: "낮은 우선순위", priority: 9),
            makeTestTask(title: "높은 우선순위", priority: 1)
        ]
        viewModel.buildRecommendationsData()
        let titles = viewModel.recommendedActions.map { $0.title }
        let highIdx = titles.firstIndex(of: "높은 우선순위")!
        let lowIdx  = titles.firstIndex(of: "낮은 우선순위")!
        XCTAssertLessThan(highIdx, lowIdx)
    }

    func test_buildRecommendationsData_criticalAIAction_markedAsCritical() {
        viewModel.summary = makeTestSummary(nextActions: ["🔴 즉시 해야 할 일"])
        viewModel.buildRecommendationsData()
        let first = viewModel.recommendedActions.first
        XCTAssertEqual(first?.priority, .critical)
    }
}
