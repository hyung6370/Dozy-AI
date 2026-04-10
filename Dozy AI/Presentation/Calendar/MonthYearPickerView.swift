//
//  MonthYearPickerView.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 4/10/26.
//

import SwiftUI

struct MonthYearPickerView: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let monthNames = ["1월", "2월", "3월", "4월", "5월", "6월",
                              "7월", "8월", "9월", "10월", "11월", "12월"]

    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 20)...(current + 20))
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("년도", selection: $selectedYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text(verbatim: "\(year)년").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("월", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthNames[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .navigationTitle("날짜 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("이동") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
