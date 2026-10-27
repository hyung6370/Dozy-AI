//
//  LogWorkShortcut.swift
//  Dozy AI
//
//  "Dozy에 메모 남겨줘" — Siri 가 메모 내용을 받아 오늘 WorkLog.memos 에 추가한다.
//  앱을 열지 않고(openAppWhenRun = false) 백그라운드에서 저장하고 Siri 가 결과를 읽어준다.
//

import AppIntents
import Foundation
import SwiftData

struct LogWorkMemoIntent: AppIntent {

    static var title: LocalizedStringResource = "메모 기록"
    static var description = IntentDescription("오늘의 업무 기록에 메모를 추가합니다.")
    static var openAppWhenRun: Bool = false

    /// 구문에 내용이 없으면 Siri 가 requestValueDialog 로 되묻는다.
    /// ("Dozy에 기록해줘" → "무엇을 기록할까요?" → 사용자가 말함 → 저장)
    @Parameter(title: "메모", requestValueDialog: "무엇을 기록할까요?")
    var memo: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$memo) 기록")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw $memo.needsValueError("무엇을 기록할까요?")
        }

        let context = try AppIntentStore.modelContainer().mainContext
        let log = try AppIntentStore.todayLog(in: context)
        log.addMemo(text)
        try context.save()

        return .result(dialog: "메모를 남겼어요: \(text)")
    }
}
