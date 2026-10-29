//
//  SearchView.swift
//  Dozy AI
//
//  검색 화면. 매칭은 SearchMatcher, 조회 · 저장은 SearchViewModel (#72).
//  Dozy 일정 · 일지 · 카테고리는 @Query 로 받아 편집 즉시 결과에 반영한다.
//

import SwiftUI
import SwiftData

struct SearchView: View {

    @StateObject private var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isSearchFocused: Bool

    @Query private var allDozyEvents: [DozyEvent]
    @Query private var allWorkLogs: [WorkLog]
    @Query(sort: \UserCategory.order) private var allCategories: [UserCategory]

    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(container: container))
    }

    var body: some View {
        let results = viewModel.results(
            dozyEvents: allDozyEvents, workLogs: allWorkLogs, categories: allCategories
        )
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if !viewModel.hasQuery {
                    emptyState(message: "제목 · 위치 · 메모 · 일지 · 카테고리를 검색해보세요")
                } else if results.isEmpty {
                    emptyState(message: "검색 결과가 없습니다")
                } else {
                    resultList(results)
                }
            }
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear { isSearchFocused = true }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background { viewModel.clearModalState() }
            }
            .sheet(item: $viewModel.selectedEvent) { ev in
                EventDetailView(
                    event: ev,
                    dozyEvent: dozyEvent(for: ev),
                    onEdit: { dozy in viewModel.dozyEventToEdit = dozy },
                    onDelete: nil,
                    onDeleteThisOnly: nil, onDeleteFutureEvents: nil,
                    onEditCalendar: { viewModel.calendarEventToEdit = $0 },
                    onDeleteCalendar: nil,
                    onSaveMemos: { dozy in viewModel.save(dozy) },
                    onUpdateDisplaySettings: { event, priority, isPinned, category in
                        viewModel.applyDisplaySettings(
                            event: event, priority: priority, isPinned: isPinned, category: category,
                            dozyEvents: allDozyEvents, categories: allCategories
                        )
                    }
                )
            }
            .sheet(item: $viewModel.dozyEventToEdit) { dozy in
                EventEditView(
                    eventToEdit: dozy,
                    selectedDate: dozy.startDate
                ) { saved in
                    viewModel.save(saved)
                }
            }
            .sheet(item: $viewModel.calendarEventToEdit) { ev in
                CalendarEventEditView(event: ev) { edit in
                    viewModel.saveCalendarEdit(ev, with: edit)
                }
            }
            .alert("메모 삭제", isPresented: Binding(
                get: { viewModel.pendingMemoDelete != nil },
                set: { if !$0 { viewModel.pendingMemoDelete = nil } }
            )) {
                Button("삭제", role: .destructive) { viewModel.confirmMemoDelete() }
                Button("취소", role: .cancel) { viewModel.pendingMemoDelete = nil }
            } message: {
                Text("'\(viewModel.pendingMemoDelete?.memo ?? "")'\n메모를 삭제하시겠습니까?")
            }
        }
    }

    private func dozyEvent(for event: CalendarEvent) -> DozyEvent? {
        allDozyEvents.first(where: { $0.id == event.id })
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(symbol: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("검색", text: $viewModel.query)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(symbol: "xmark.circle.fill")
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
            Image(symbol: "magnifyingglass")
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

    private func resultList(_ results: SearchResults) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !results.categories.isEmpty {
                    categorySection(results.categories)
                }
                if !results.workLogs.isEmpty {
                    workLogSection(results.workLogs)
                }
                let groups = results.eventsByDate
                if !groups.isEmpty {
                    eventSection(groups)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func categorySection(_ categories: [UserCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            FlowHStack {
                ForEach(categories) { cat in
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

    private func workLogSection(_ logs: [WorkLog]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("일지").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            ForEach(logs) { log in
                VStack(alignment: .leading, spacing: 6) {
                    Text(log.date.formatted(.dateTime.year().month().day().locale(.current)))
                        .font(.caption).foregroundStyle(.secondary)
                    if !log.aiSummary.isEmpty {
                        Text(log.aiSummary).font(.subheadline).lineLimit(3)
                    }
                    if !log.highlights.isEmpty {
                        ForEach(log.highlights, id: \.self) { h in
                            Text("• \(h)").font(.caption)
                        }
                    }
                    ForEach(viewModel.matchedMemos(in: log), id: \.self) { memo in
                        memoSnippet(memo) {
                            viewModel.requestMemoDelete(memo, from: .workLog(log))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func eventSection(_ groups: [(date: Date, events: [CalendarEvent])]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일정").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            ForEach(groups, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.date.formatted(.dateTime.year().month().day().weekday().locale(.current)))
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(group.events) { ev in
                        VStack(alignment: .leading, spacing: 4) {
                            EventRow(event: ev)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.selectedEvent = ev }
                            eventMemo(for: ev)
                        }
                    }
                }
            }
        }
    }

    /// 매칭된 메모 스니펫. 내 Dozy 메모면 롱프레스로 삭제, notes 는 표시만.
    @ViewBuilder
    private func eventMemo(for ev: CalendarEvent) -> some View {
        let dozy = ev.source == .dozy ? dozyEvent(for: ev) : nil
        if let memo = viewModel.matchedMemo(for: ev, dozyEvent: dozy) {
            if let dozy, dozy.memos.contains(memo) {
                memoSnippet(memo) {
                    viewModel.requestMemoDelete(memo, from: .dozyEvent(dozy))
                }
            } else {
                memoSnippet(memo, onDelete: nil)
            }
        }
    }

    /// 메모 스니펫 뷰 (onDelete 있으면 롱프레스로 삭제 트리거)
    @ViewBuilder
    private func memoSnippet(_ memo: String, onDelete: (() -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(symbol: "note.text").font(.caption2)
                .foregroundStyle(.secondary)
            Text(memo).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .modifier(LongPressDeleteModifier(action: onDelete))
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
