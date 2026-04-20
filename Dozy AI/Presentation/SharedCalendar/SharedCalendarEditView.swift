//
//  SharedCalendarEditView.swift
//  Dozy AI
//

import SwiftUI

struct SharedCalendarEditView: View {

    let calendar: SharedCalendar
    let isOwner: Bool           // DetailView에서 확정된 값 전달 (로딩 상태 무관)
    let currentUserID: String
    @ObservedObject var viewModel: SharedCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var calendarName: String
    @State private var myNickname: String
    @State private var originalNickname: String

    private var members: [SharedCalendarMember] {
        viewModel.membersMap[calendar.id] ?? []
    }
    private var partner: SharedCalendarMember? {
        members.first(where: { $0.userID != currentUserID })
    }

    private var hasChanges: Bool {
        let nameChanged = isOwner && calendarName.trimmingCharacters(in: .whitespaces) != calendar.name
        let nickChanged = myNickname.trimmingCharacters(in: .whitespaces) != originalNickname
        return nameChanged || nickChanged
    }

    init(
        calendar: SharedCalendar,
        isOwner: Bool,
        currentUserID: String,
        viewModel: SharedCalendarViewModel
    ) {
        self.calendar = calendar
        self.isOwner = isOwner
        self.currentUserID = currentUserID
        self.viewModel = viewModel

        let nick = (viewModel.membersMap[calendar.id] ?? [])
            .first(where: { $0.userID == currentUserID })?.nickname ?? ""
        _calendarName = State(initialValue: calendar.name)
        _myNickname = State(initialValue: nick)
        _originalNickname = State(initialValue: nick)
    }

    var body: some View {
        NavigationStack {
            Form {
                calendarNameSection
                nicknameSection
            }
            .navigationTitle("캘린더 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges)
                }
            }
        }
    }

    // MARK: - 캘린더 이름

    private var calendarNameSection: some View {
        Section {
            if isOwner {
                TextField("캘린더 이름", text: $calendarName)
            } else {
                HStack {
                    Text(calendar.name)
                    Spacer()
                    Text("소유자만 수정 가능")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("캘린더 이름")
        }
    }

    // MARK: - 닉네임

    private var nicknameSection: some View {
        Section {
            // 나 — 항상 편집 가능
            HStack {
                Text("나")
                    .font(.subheadline)
                Spacer()
                TextField("닉네임 입력", text: $myNickname)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }

            // 파트너 — 항상 읽기 전용
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let partnerDisplayName = partner?.nickname.flatMap { $0.isEmpty ? nil : $0 } ?? "파트너"
                    Text(partnerDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if partner?.nickname?.isEmpty == false {
                        Text("파트너")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
        } header: {
            Text("닉네임")
        } footer: {
            Text("닉네임은 공유 캘린더 안에서만 표시되는 이름입니다.")
        }
    }

    // MARK: - 저장

    private func save() {
        let group = DispatchGroup()

        if isOwner {
            let name = calendarName.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && name != calendar.name {
                group.enter()
                viewModel.updateCalendarName(calendarID: calendar.id, name: name) { group.leave() }
            }
        }

        let nick = myNickname.trimmingCharacters(in: .whitespaces)
        if nick != originalNickname {
            group.enter()
            viewModel.updateNickname(calendarID: calendar.id, nickname: nick, currentUserID: currentUserID) {
                group.leave()
            }
        }

        group.notify(queue: .main) { dismiss() }
    }
}
