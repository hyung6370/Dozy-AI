//
//  SharedCalendarEditView.swift
//  Dozy AI
//

import SwiftUI
import PhotosUI
import Kingfisher
import OSLog

private let editLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dozy", category: "SharedCalendarEdit")

struct SharedCalendarEditView: View {

    let calendar: SharedCalendar
    let isOwner: Bool           // DetailView에서 확정된 값 전달 (로딩 상태 무관)
    let currentUserID: String
    @ObservedObject var viewModel: SharedCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var calendarName: String
    @State private var myNickname: String
    @State private var originalNickname: String
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var imageErrorMessage: String?
    @State private var imageChanged = false

    private var currentCalendar: SharedCalendar {
        viewModel.calendars.first(where: { $0.id == calendar.id }) ?? calendar
    }

    private var members: [SharedCalendarMember] {
        viewModel.membersMap[calendar.id] ?? []
    }

    private var hasChanges: Bool {
        let nameChanged = isOwner && calendarName.trimmingCharacters(in: .whitespaces) != calendar.name
        let nickChanged = myNickname.trimmingCharacters(in: .whitespaces) != originalNickname
        return nameChanged || nickChanged || imageChanged
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
            ScrollView {
                VStack(spacing: DozySpacing.xl) {
                    imageSection
                    calendarNameSection
                    nicknameSection
                }
                .padding(.vertical, DozySpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .dozyThemedShellBackground(systemBackground: DozyColor.Background.grouped)
            .navigationTitle("캘린더 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(DozyColor.Text.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                onPhotoPicked(newItem)
            }
            .alert("이미지 업로드 실패", isPresented: Binding(
                get: { imageErrorMessage != nil },
                set: { if !$0 { imageErrorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { imageErrorMessage = nil }
            } message: {
                Text(imageErrorMessage ?? "")
            }
        }
    }

    // MARK: - 캘린더 이미지

    private var imageSection: some View {
        VStack(spacing: DozySpacing.sm) {
            ZStack {
                SharedCalendarCover(imageURL: currentCalendar.publicImageURL, size: 96, cornerRadius: DozyRadius.xl)
                if isUploadingImage {
                    RoundedRectangle(cornerRadius: DozyRadius.xl, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 96, height: 96)
                    ProgressView().tint(.white)
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            if isOwner {
                HStack(spacing: DozySpacing.md) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(currentCalendar.imagePath == nil ? "사진 추가" : "사진 변경")
                            .font(DozyFont.subheadlineEmphasized)
                            .foregroundStyle(DozyColor.Brand.primary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isUploadingImage)

                    if currentCalendar.imagePath != nil {
                        Button(role: .destructive) { removeImage() } label: {
                            Text("삭제")
                                .font(DozyFont.subheadlineEmphasized)
                                .foregroundStyle(DozyColor.State.danger)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isUploadingImage)
                    }
                }
            } else {
                Text("대표 사진은 소유자만 바꿀 수 있어요")
                    .font(DozyFont.caption)
                    .foregroundStyle(DozyColor.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 캘린더 이름

    private var calendarNameSection: some View {
        DozyListSection(header: "캘린더 이름", footer: isOwner ? nil : "캘린더 이름은 소유자만 바꿀 수 있어요.") {
            if isOwner {
                TextField("캘린더 이름", text: $calendarName)
                    .font(DozyFont.bodyEmphasized)
                    .padding(.horizontal, DozySpacing.md)
                    .frame(minHeight: 56)
            } else {
                Text(calendar.name)
                    .font(DozyFont.bodyEmphasized)
                    .foregroundStyle(DozyColor.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DozySpacing.md)
                    .frame(minHeight: 56)
            }
        }
    }

    // MARK: - 닉네임

    private var nicknameSection: some View {
        DozyListSection(header: "닉네임", footer: "닉네임은 이 공유 캘린더 안에서만 보이는 이름이에요.") {
            // 나 — 항상 편집 가능
            HStack(spacing: DozySpacing.sm) {
                SharedMemberAvatar(
                    name: myNickname.isEmpty ? String(localized: "나") : myNickname,
                    seed: currentUserID, size: 36
                )
                Text("나")
                    .font(DozyFont.bodyEmphasized)
                    .foregroundStyle(DozyColor.Text.primary)
                Spacer()
                TextField("닉네임 입력", text: $myNickname)
                    .font(DozyFont.body)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
            .padding(.horizontal, DozySpacing.md)
            .frame(minHeight: 60)

            // 다른 멤버 — 읽기 전용
            ForEach(members.filter { $0.userID != currentUserID }, id: \.userID) { member in
                HStack(spacing: DozySpacing.sm) {
                    SharedMemberAvatar(name: member.displayName(currentUserID: currentUserID), seed: member.userID, size: 36)
                    Text(member.displayName(currentUserID: currentUserID))
                        .font(DozyFont.bodyEmphasized)
                        .foregroundStyle(DozyColor.Text.secondary)
                    Spacer()
                    Text(member.isOwner ? "소유자" : "멤버")
                        .font(DozyFont.caption)
                        .foregroundStyle(DozyColor.Text.tertiary)
                }
                .padding(.horizontal, DozySpacing.md)
                .frame(minHeight: 60)
            }
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

    // MARK: - 이미지 업로드 / 삭제

    private func onPhotoPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        editLogger.debug("photo picked, loading Data…")
        Task { @MainActor in
            isUploadingImage = true
            defer { isUploadingImage = false; photoItem = nil }

            let data: Data
            do {
                guard let loaded = try await item.loadTransferable(type: Data.self) else {
                    editLogger.error("loadTransferable returned nil")
                    imageErrorMessage = String(localized: "사진을 불러올 수 없습니다. 다른 사진을 선택해보세요.")
                    return
                }
                data = loaded
                editLogger.debug("loaded \(data.count) bytes")
            } catch {
                editLogger.error("loadTransferable error: \(error)")
                imageErrorMessage = String(localized: "사진 로딩 실패: \(error.localizedDescription)")
                return
            }

            guard let jpegData = Self.resizedJPEGData(from: data) else {
                editLogger.error("resize/JPEG encoding failed")
                imageErrorMessage = String(localized: "이 사진은 처리할 수 없습니다. (포맷 문제)")
                return
            }
            editLogger.debug("resized JPEG \(jpegData.count) bytes, uploading…")

            let oldURL = currentCalendar.publicImageURL
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                viewModel.updateCalendarImage(calendarID: calendar.id, jpegData: jpegData) { success in
                    editLogger.debug("upload completion success=\(success)")
                    if !success {
                        imageErrorMessage = viewModel.errorMessage ?? "업로드에 실패했습니다."
                    } else {
                        if let oldURL {
                            KingfisherManager.shared.cache.removeImage(forKey: oldURL.absoluteString)
                        }
                        imageChanged = true
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func removeImage() {
        let oldURL = currentCalendar.publicImageURL
        isUploadingImage = true
        viewModel.removeCalendarImage(calendarID: calendar.id) { success in
            isUploadingImage = false
            if success {
                if let oldURL {
                    KingfisherManager.shared.cache.removeImage(forKey: oldURL.absoluteString)
                }
                imageChanged = true
            }
        }
    }

    private static func resizedJPEGData(from data: Data, maxDimension: CGFloat = 512, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
