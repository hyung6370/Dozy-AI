//
//  HomeView.swift
//  Dozy AI
//
//  Created by HyungJun's mac on 3/17/26.
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel: HomeViewModel
    @State private var memoText = ""
    
    // MARK: - Init
    // 왜 이렇게 했나:
    // @StateObject는 init 시점에 wrappedValue를 넘겨야 하므로
    // 기본 서비스로 초기화합니다. 실제 앱에서는 DependencyContainer가
    // environmentObject로 주입되어 있으므로 onAppear에서 재설정할 수도 있고,
    // 또는 HomeView를 생성하는 부모 View에서 container를 넘겨줄 수도 있습니다.
    
    init() {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            calendarService: CalendarService(),
            reminderService: ReminderService(),
            repository: WorkLogRepository()
        ))
    }
    
    // container를 직접 받는 init (부모에서 주입 시 사용)
    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(container: container))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 오늘 날짜 헤더
                    headerSection
                    
                    if viewModel.isLoading {
                        loadingSection
                    } else if let error = viewModel.errorMessage {
                        errorSection(error)
                    } else {
                        // 통계 요약 카드
                        summaryCard
                        
                        // 오늘 일정
                        if !viewModel.todayEvents.isEmpty {
                            eventListSection
                        }
                        
                        // 완료한 할 일
                        if !viewModel.completedTasks.isEmpty {
                            completedTaskSection
                        }
                        
                        // 남은 할 일
                        if !viewModel.pendingTasks.isEmpty {
                            pendingTaskSection
                        }
                        
                        // 메모 입력
                        memoSection
                        
                        // AI 요약 (Phase 2에서 활성화)
                        if let log = viewModel.todayLog, !log.aiSummary.isEmpty {
                            aiSummarySection(log)
                        }
                        
                        // 최근 기록
                        if !viewModel.recentLogs.isEmpty {
                            recentLogsSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dozy AI")
            .refreshable {
                viewModel.loadTodayData()
            }
            .onAppear {
                viewModel.loadTodayData()
            }
            // 권한 요청 Alert
            .alert("권한 필요", isPresented: $viewModel.showPermissionAlert) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "캘린더와 미리알림 접근 권한이 필요합니다.")
            }
        }
    }
}

// MARK: - Header Section
private extension HomeView {
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.todayDateString)
                .font(.title2)
                .fontWeight(.bold)
            Text("오늘 하루를 정리해드릴게요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Loading & Error
private extension HomeView {
    
    var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("데이터를 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }
    
    func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                viewModel.loadTodayData()
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }
}

// MARK: - Summary Card
private extension HomeView {
    
    // 왜 이렇게 했나:
    // 오늘의 핵심 숫자(일정/완료/남은 할일)를 한눈에 보여주는 카드입니다.
    // .ultraThinMaterial 배경으로 다크모드에서도 자연스럽게 보이게 했습니다.
    
    var summaryCard: some View {
        HStack(spacing: 0) {
            StatBadge(icon: "calendar", value: "\(viewModel.eventCount)", label: "일정", color: .blue)
            
            Divider()
                .frame(height: 40)
            
            StatBadge(icon: "checkmark.circle.fill", value: "\(viewModel.completedCount)", label: "완료", color: .green)
            
            Divider()
                .frame(height: 40)
            
            StatBadge(icon: "clock", value: "\(viewModel.pendingCount)", label: "남은 할 일", color: .orange)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Event List Section
private extension HomeView {
    
    var eventListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "오늘 일정", icon: "calendar")
            
            ForEach(viewModel.todayEvents) { event in
                EventRow(event: event)
            }
        }
    }
}

// MARK: - Completed Tasks Section
private extension HomeView {
    
    var completedTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "완료한 할 일", icon: "checkmark.circle.fill")
            
            ForEach(viewModel.completedTasks) { task in
                TaskRow(task: task, isCompleted: true)
            }
        }
    }
}

// MARK: - Pending Tasks Section
private extension HomeView {
    
    var pendingTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "남은 할 일", icon: "clock")
            
            // 최대 5개까지만 표시
            ForEach(viewModel.pendingTasks.prefix(5)) { task in
                TaskRow(task: task, isCompleted: false)
            }
            
            // 5개 초과 시 더보기 표시
            if viewModel.pendingTasks.count > 5 {
                Text("외 \(viewModel.pendingTasks.count - 5)건 더 있음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Memo Section
private extension HomeView {
    
    // 왜 이렇게 했나:
    // 사용자가 짧은 메모를 빠르게 입력할 수 있는 섹션입니다.
    // 입력된 메모는 WorkLog에 저장되어 나중에 AI 요약의 입력 데이터로 쓰입니다.
    // onSubmit으로 키보드 리턴 키로도 제출 가능하게 했습니다.
    
    var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "메모", icon: "square.and.pencil")
            
            // 이미 입력된 메모 목록
            if let log = viewModel.todayLog, !log.memos.isEmpty {
                ForEach(Array(log.memos.enumerated()), id: \.offset) { index, memo in
                    HStack(alignment: .top, spacing: 8) {
                        Text("📝")
                            .font(.subheadline)
                        Text(memo)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // 메모 입력 필드
            HStack(spacing: 10) {
                TextField("오늘 메모를 남겨보세요...", text: $memoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitMemo()
                    }
                
                Button {
                    submitMemo()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func submitMemo() {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addMemo(trimmed)
        memoText = ""
    }
}

// MARK: - AI Summary Section (Phase 2에서 본격 활용)
private extension HomeView {
    
    func aiSummarySection(_ log: WorkLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "AI 업무 요약", icon: "brain.head.profile")
            
            VStack(alignment: .leading, spacing: 10) {
                Text(log.aiSummary)
                    .font(.subheadline)
                    .lineSpacing(4)
                
                // 핵심 하이라이트
                if !log.highlights.isEmpty {
                    Divider()
                    
                    Text("핵심 하이라이트")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    ForEach(log.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // 추천 다음 할 일
                if !log.nextActions.isEmpty {
                    Divider()
                    
                    Text("추천 다음 할 일")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    ForEach(log.nextActions, id: \.self) { action in
                        Label(action, systemImage: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.blue.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Recent Logs Section
private extension HomeView {
    
    var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "최근 기록", icon: "clock.arrow.circlepath")
            
            ForEach(viewModel.recentLogs) { log in
                RecentLogRow(log: log)
            }
        }
    }
}

#Preview {
    HomeView()
}
