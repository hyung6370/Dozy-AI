//
//  SearchView.swift
//  Dozy AI
//

import SwiftUI
import SwiftData
import Combine

struct SearchView: View {

    let container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isSearchFocused: Bool

    @State private var query: String = ""
    @State private var externalEvents: [CalendarEvent] = []
    @State private var isLoadingExternal = false
    @State private var externalCancellable: AnyCancellable?
    @State private var updateCancellable: AnyCancellable?

    @Query private var allDozyEvents: [DozyEvent]
    @Query private var allWorkLogs: [WorkLog]
    @Query(sort: \UserCategory.order) private var allCategories: [UserCategory]

    // 메모리 상에서 상세로 넘어가기 위한 상태
    @State private var selectedEvent: CalendarEvent?
    @State private var dozyEventToEdit: DozyEvent?
    @State private var calendarEventToEdit: CalendarEvent?
    @State private var pendingMemoDelete: PendingMemoDelete?

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var hasQuery: Bool { trimmed.count >= 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if !hasQuery {
                    emptyState(message: "제목 · 위치 · 메모 · 일지 · 카테고리를 검색해보세요")
                } else if resultIsEmpty {
                    emptyState(message: "검색 결과가 없습니다")
                } else {
                    resultList
                }
            }
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                isSearchFocused = true
                loadExternalEvents()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    selectedEvent = nil
                    dozyEventToEdit = nil
                    calendarEventToEdit = nil
                    pendingMemoDelete = nil
                }
            }
            .sheet(item: $selectedEvent) { ev in
                EventDetailView(
                    event: ev,
                    dozyEvent: allDozyEvents.first(where: { $0.id == ev.id }),
                    onEdit: { dozy in dozyEventToEdit = dozy },
                    onDelete: nil,
                    onDeleteThisOnly: nil, onDeleteFutureEvents: nil,
                    onEditCalendar: { calendarEventToEdit = $0 },
                    onDeleteCalendar: nil,
                    onSaveMemos: { dozy in
                        updateCancellable = container.updateDozyEventUseCase.execute(dozy)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { _ in }, receiveValue: { })
                    },
                    onUpdateDisplaySettings: { event, priority, isPinned, category in
                        applyDisplaySettings(event: event, priority: priority,
                                             isPinned: isPinned, category: category)
                    }
                )
            }
            .sheet(item: $dozyEventToEdit) { dozy in
                EventEditView(
                    eventToEdit: dozy,
                    selectedDate: dozy.startDate
                ) { saved in
                    updateCancellable = container.updateDozyEventUseCase.execute(saved)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { _ in }, receiveValue: { })
                }
            }
            .sheet(item: $calendarEventToEdit) { ev in
                CalendarEventEditView(event: ev) { edit in
                    updateCancellable = container.updateCalendarEventUseCase.execute(ev, with: edit)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { _ in }, receiveValue: { })
                }
            }
            .alert("메모 삭제", isPresented: Binding(
                get: { pendingMemoDelete != nil },
                set: { if !$0 { pendingMemoDelete = nil } }
            )) {
                Button("삭제", role: .destructive) {
                    if let pending = pendingMemoDelete { deletePendingMemo(pending) }
                    pendingMemoDelete = nil
                }
                Button("취소", role: .cancel) { pendingMemoDelete = nil }
            } message: {
                Text("'\(pendingMemoDelete?.memo ?? "")'\n메모를 삭제하시겠습니까?")
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("검색", text: $query)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty state

    private func emptyState(message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result list

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !matchedCategories.isEmpty {
                    categorySection
                }
                if !matchedWorkLogs.isEmpty {
                    workLogSection
                }
                if !eventsByDate.isEmpty {
                    eventSection
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            FlowHStack {
                ForEach(matchedCategories) { cat in
                    HStack(spacing: 4) {
                        Text(cat.emoji)
                        Text(cat.name).font(.subheadline)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((Color(hex: cat.colorHex) ?? .blue).opacity(0.15),
                                in: Capsule())
                }
            }
        }
    }

    private var workLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("일지").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            ForEach(matchedWorkLogs) { log in
                VStack(alignment: .leading, spacing: 6) {
                    Text(log.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR"))))
                        .font(.caption).foregroundStyle(.secondary)
                    if !log.aiSummary.isEmpty {
                        Text(log.aiSummary).font(.subheadline).lineLimit(3)
                    }
                    if !log.highlights.isEmpty {
                        ForEach(log.highlights, id: \.self) { h in
                            Text("• \(h)").font(.caption)
                        }
                    }
                    let matchedMemos = log.memos.filter { $0.lowercased().contains(trimmed) }
                    ForEach(matchedMemos, id: \.self) { memo in
                        memoSnippet(memo) {
                            pendingMemoDelete = PendingMemoDelete(
                                parent: .workLog(log), memo: memo
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일정").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            ForEach(eventsByDate, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.date.formatted(.dateTime.year().month().day().weekday().locale(Locale(identifier: "ko_KR"))))
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(group.events) { ev in
                        VStack(alignment: .leading, spacing: 4) {
                            EventRow(event: ev)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedEvent = ev }
                            if let memo = matchedMemo(for: ev),
                               ev.source == .dozy,
                               let dozy = allDozyEvents.first(where: { $0.id == ev.id }),
                               dozy.memos.contains(memo) {
                                memoSnippet(memo) {
                                    pendingMemoDelete = PendingMemoDelete(
                                        parent: .dozyEvent(dozy), memo: memo
                                    )
                                }
                            } else if let memo = matchedMemo(for: ev) {
                                memoSnippet(memo, onDelete: nil)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 메모 스니펫 뷰 (onDelete 있으면 롱프레스로 삭제 트리거)
    @ViewBuilder
    private func memoSnippet(_ memo: String, onDelete: (() -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "note.text").font(.caption2)
                .foregroundStyle(.secondary)
            Text(memo).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .modifier(LongPressDeleteModifier(action: onDelete))
    }

    /// 매칭된 메모 또는 notes 스니펫 반환
    private func matchedMemo(for ev: CalendarEvent) -> String? {
        guard hasQuery else { return nil }
        if ev.source == .dozy,
           let dozy = allDozyEvents.first(where: { $0.id == ev.id }),
           let memo = dozy.memos.first(where: { $0.lowercased().contains(trimmed) }) {
            return memo
        }
        if let notes = ev.notes, notes.lowercased().contains(trimmed) {
            return notes
        }
        return nil
    }

    // MARK: - Filtering

    private var matchedCategories: [UserCategory] {
        guard hasQuery else { return [] }
        return allCategories.filter { $0.name.lowercased().contains(trimmed) }
    }

    private var matchedWorkLogs: [WorkLog] {
        guard hasQuery else { return [] }
        return allWorkLogs
            .filter { log in
                log.aiSummary.lowercased().contains(trimmed)
                    || log.highlights.contains(where: { $0.lowercased().contains(trimmed) })
                    || log.nextActions.contains(where: { $0.lowercased().contains(trimmed) })
                    || log.memos.contains(where: { $0.lowercased().contains(trimmed) })
            }
            .sorted(by: { $0.date > $1.date })
    }

    /// 모든 소스(Dozy · Apple · Google) 통합 결과 (최신순)
    private var matchedEvents: [CalendarEvent] {
        guard hasQuery else { return [] }

        let dozyEvents: [CalendarEvent] = allDozyEvents
            .filter { e in
                e.title.lowercased().contains(trimmed)
                    || (e.location ?? "").lowercased().contains(trimmed)
                    || (e.notes ?? "").lowercased().contains(trimmed)
                    || e.memos.contains(where: { $0.lowercased().contains(trimmed) })
                    || e.category.lowercased().contains(trimmed)
            }
            .map { $0.toCalendarEvent() }

        let externalMatched = externalEvents.filter { e in
            e.title.lowercased().contains(trimmed)
                || (e.location ?? "").lowercased().contains(trimmed)
                || (e.notes ?? "").lowercased().contains(trimmed)
        }

        // Dozy가 Apple/Google 쪽에 중복으로 들어올 수 있으므로 id로 중복 제거하되,
        // 반복 이벤트의 여러 occurrence(동일 eventIdentifier, 상이한 startDate)는 보존하기 위해
        // id + startDate 조합을 키로 사용.
        var seen = Set<String>()
        let combined = (dozyEvents + externalMatched).filter {
            seen.insert("\($0.id)_\($0.startDate.timeIntervalSince1970)").inserted
        }
        return combined.sorted(by: { $0.startDate > $1.startDate })
    }

    private var eventsByDate: [(date: Date, events: [CalendarEvent])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: matchedEvents) { cal.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private var resultIsEmpty: Bool {
        matchedCategories.isEmpty && matchedWorkLogs.isEmpty && matchedEvents.isEmpty
    }

    // MARK: - Apply display settings (from EventDetail save button)

    private func applyDisplaySettings(event: CalendarEvent, priority: Int, isPinned: Bool, category: String?) {
        if event.source == .dozy {
            guard let dozy = allDozyEvents.first(where: { $0.id == event.id }) else { return }
            dozy.priority = priority
            dozy.isPinned = isPinned
            if let category {
                dozy.category = category
                if let cat = allCategories.first(where: { $0.name == category }) {
                    dozy.colorHex = cat.colorHex
                }
            }
            updateCancellable = container.updateDozyEventUseCase.execute(dozy)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { })
        } else {
            let finalCategory = category ?? event.category
            updateCancellable = container.eventDisplaySettingsRepository
                .save(eventID: event.id, priority: priority, isPinned: isPinned, category: finalCategory)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        }
    }

    // MARK: - Memo deletion

    private func deletePendingMemo(_ pending: PendingMemoDelete) {
        switch pending.parent {
        case .dozyEvent(let dozy):
            dozy.memos.removeAll { $0 == pending.memo }
            dozy.updatedAt = Date()
            updateCancellable = container.updateDozyEventUseCase.execute(dozy)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { })
        case .workLog(let log):
            guard let idx = log.memos.firstIndex(of: pending.memo) else { return }
            updateCancellable = container.saveWorkLogUseCase
                .deleteMemo(at: idx, in: log)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { })
        }
    }

    // MARK: - External fetch

    private func loadExternalEvents() {
        guard externalEvents.isEmpty, !isLoadingExternal else { return }
        isLoadingExternal = true
        let cal = Calendar.current
        // 오래된 기록 검색 지원 — 과거 10년 / 미래 2년 범위까지 확장
        let end = cal.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let start = cal.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        externalCancellable = container.fetchCalendarEventsForPeriodUseCase
            .execute(from: start, to: end)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in self.isLoadingExternal = false },
                receiveValue: { events in
                    // Dozy source는 @Query로 따로 처리하므로 제외
                    self.externalEvents = events.filter { $0.source != .dozy }
                    self.isLoadingExternal = false
                }
            )
    }
}

// MARK: - Helpers

/// 간단한 wrapping HStack (카테고리 칩용)
private struct FlowHStack<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 6) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 삭제 확인용 — 이벤트 메모 or 일지 메모
struct PendingMemoDelete {
    enum Parent {
        case dozyEvent(DozyEvent)
        case workLog(WorkLog)
    }
    let parent: Parent
    let memo: String
}

/// action이 주어지면 롱프레스로 실행
private struct LongPressDeleteModifier: ViewModifier {
    let action: (() -> Void)?
    func body(content: Content) -> some View {
        if let action {
            content.onLongPressGesture { action() }
        } else {
            content
        }
    }
}
