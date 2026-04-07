//
//  NotificationListView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/7/26.
//

import SwiftUI

struct NotificationListView: View {
    
    @StateObject private var viewModel: NotificationViewModel
    
    init(repository: NotificationRepository) {
        _viewModel = StateObject(wrappedValue: NotificationViewModel(repository: repository))
    }
    
    var body: some View {
        Group {
            if viewModel.records.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image("notifications_none")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .opacity(0.4)
            Text("아직 아무런 알림이 없습니다!\n알림을 설정해서 일정을 미리 확인하세요!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listView: some View {
        List {
            ForEach(viewModel.records) { record in
                NotificationRowView(record: record)
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
            }
        }
    }
}

private struct NotificationRowView: View {
    
    let record: NotificationRecord
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.subheadline)
                .foregroundStyle(.indigo)
                .frame(width: 32, height: 32)
                .background(Color.indigo.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.eventTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if record.deliveryDate > Date() {
                        Text("예정")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                }
                Text(record.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}
