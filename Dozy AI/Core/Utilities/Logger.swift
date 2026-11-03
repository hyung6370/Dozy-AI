//
//  Logger.swift
//  Dozy AI
//

import OSLog

// Logger 는 스레드 안전. BGTask · AppDelegate 콜백 · 위젯 등 nonisolated 문맥에서도 쓰므로 확장 전체를 메인 액터에서 뺀다.
nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.dozy.ai"

    static let app      = Logger(subsystem: subsystem, category: "App")
    static let sync     = Logger(subsystem: subsystem, category: "Sync")
    static let calendar = Logger(subsystem: subsystem, category: "Calendar")
    static let auth     = Logger(subsystem: subsystem, category: "Auth")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let network  = Logger(subsystem: subsystem, category: "Network")
    static let nav      = Logger(subsystem: subsystem, category: "Nav")
    static let ai       = Logger(subsystem: subsystem, category: "AI")
    static let reminder = Logger(subsystem: subsystem, category: "Reminder")
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    /// 검색 자연어 질의 해석 (#72)
    static let search = Logger(subsystem: subsystem, category: "Search")
    /// 홈 메모 저장 (#137)
    static let memo = Logger(subsystem: subsystem, category: "Memo")
    /// APNs 토큰 · 공유 캘린더 푸시 (#95). AppDelegate 콜백 · 비동기 등록에서 쓰므로 메인 액터에 묶지 않는다.
    static let push = Logger(subsystem: subsystem, category: "Push")
    /// 백그라운드 크래시 리포팅에서도 쓰므로 메인 액터에 묶지 않는다 (#117). Logger 는 스레드 안전.
    static let analytics = Logger(subsystem: subsystem, category: "Analytics")
}
