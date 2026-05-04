//
//  MacNotificationListView.swift
//  Dozy AI (macOS)
//
//  iOS NotificationListView 의 macOS 포팅. sheet 로 띄우는 단일 컬럼 리스트.
//  NotificationViewModel / NotificationRepository / NotificationRecord 는
//  iOS 와 공유되는 코드를 그대로 재사용.
//

import SwiftUI

struct MacNotificationListView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NotificationViewModel

    init(repository: NotificationRepository) {
        _viewModel = StateObject(wrappedValue: NotificationViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.records.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .navigationTitle("알림")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear { viewModel.onAppear() }
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 480)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .opacity(0.5)
            Text("아직 아무런 알림이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            ForEach(viewModel.records) { record in
                MacNotificationRow(record: record)
                    .listRowBackground(
                        record.isRead ? Color.clear : Color.blue.opacity(0.05)
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.delete(record)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.delete(record)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

private struct MacNotificationRow: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconCircle

            VStack(alignment: .leading, spacing: 4) {
                titleRow
                subtitleText
                Text(record.deliveryDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !record.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var iconCircle: some View {
        let (system, tint): (String, Color) = record.kind == "shared"
            ? ("person.2.fill", .blue)
            : ("bell.fill", .indigo)
        Image(systemName: system)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.1), in: Circle())
    }

    @ViewBuilder
    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(record.eventTitle)
                .font(.subheadline)
                .fontWeight(.medium)
            if record.kind == "reminder", record.deliveryDate > Date() {
                Text("예정")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            } else if record.kind == "shared" {
                Text("공유")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var subtitleText: some View {
        if record.kind == "shared" {
            Text(record.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(remainingTimeLabel(for: record.eventStartDate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func remainingTimeLabel(for eventStart: Date) -> String {
        let diff = eventStart.timeIntervalSince(Date())

        if diff <= 0 {
            return "\(record.eventTitle) 일정이 시작됐어요"
        }

        let minutes = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)

        if days >= 1 {
            return "\(record.eventTitle)까지 \(days)일 남았습니다"
        } else if hours >= 1 {
            return "\(record.eventTitle)까지 \(hours)시간 전입니다"
        } else {
            return "\(record.eventTitle)까지 \(minutes)분 남았습니다"
        }
    }
}
