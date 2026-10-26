//
//  DozyWidgetsBundle.swift
//  DozyWidgets
//
//  Created by Hyungjun KIM on 5/14/26.
//

import WidgetKit
import SwiftUI

@main
struct DozyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayEventsWidget()
        TodayAgendaLiveActivity()
    }
}
