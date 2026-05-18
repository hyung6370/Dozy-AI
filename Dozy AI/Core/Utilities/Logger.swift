//
//  Logger.swift
//  Dozy AI
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.dozy.ai"

    static let app      = Logger(subsystem: subsystem, category: "App")
    static let sync     = Logger(subsystem: subsystem, category: "Sync")
    static let calendar = Logger(subsystem: subsystem, category: "Calendar")
    static let auth     = Logger(subsystem: subsystem, category: "Auth")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let network  = Logger(subsystem: subsystem, category: "Network")
    static let nav      = Logger(subsystem: subsystem, category: "Nav")
}
