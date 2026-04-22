//
//  Dozy_AI__macOS_App.swift
//  Dozy AI (macOS)
//
//  Created by Hyungjun KIM on 4/22/26.
//

import SwiftUI

@main
struct Dozy_AI__macOS_App: App {
    var body: some Scene {
        WindowGroup {
            MacRootView()
                .frame(minWidth: 480, minHeight: 320)
        }
    }
}
