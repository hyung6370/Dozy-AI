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
    private var partner: SharedCalendarMember? {
        members.first(where: { $0.userID != currentUserID })
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
            Form {
                imageSection
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
        Section {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 72, height: 72)
                    if let url = currentCalendar.publicImageURL {
                        KFImage(url)
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 144, height: 144)))
                            .cacheOriginalImage()
                            .fade(duration: 0.15)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "calendar.badge.person.crop")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentColor)
                    }
                    if isUploadingImage {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 72, height: 72)
                        ProgressView().tint(.white)
                    }
                }

                Spacer()

                if isOwner {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(currentCalendar.imagePath == nil ? "추가" : "변경")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isUploadingImage)

                        if currentCalendar.imagePath != nil {
                            Button(role: .destructive) { removeImage() } label: {
                                Text("삭제")
                                    .font(.subheadline).fontWeight(.medium)
                            }
                            .buttonStyle(.borderless)
                            .disabled(isUploadingImage)
                        }
                    }
                } else {
                    Text("소유자만 수정 가능")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("캘린더 이미지")
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
                    imageErrorMessage = "사진을 불러올 수 없습니다. 다른 사진을 선택해보세요."
                    return
                }
                data = loaded
                editLogger.debug("loaded \(data.count) bytes")
            } catch {
                editLogger.error("loadTransferable error: \(error)")
                imageErrorMessage = "사진 로딩 실패: \(error.localizedDescription)"
                return
            }

            guard let jpegData = Self.resizedJPEGData(from: data) else {
                editLogger.error("resize/JPEG encoding failed")
                imageErrorMessage = "이 사진은 처리할 수 없습니다. (포맷 문제)"
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
