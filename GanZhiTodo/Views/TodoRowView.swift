//
//  TodoRowView.swift
//  待办行（摘要卡与详情页共用）
//

import SwiftUI

struct TodoRowView: View {

    @EnvironmentObject var store: TodoStore
    let item: TodoItem
    var showsDay: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggleDone(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isDone ? Theme.accent : Theme.secondaryText.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15))
                    .foregroundStyle(item.isDone ? Theme.secondaryText : .primary)
                    .strikethrough(item.isDone, color: Theme.secondaryText)

                if hasMeta {
                    HStack(spacing: 8) {
                        Label(item.timeText, systemImage: "clock")
                        if !item.reminderOffsets.isEmpty {
                            Label(reminderText, systemImage: "bell")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private var hasMeta: Bool {
        item.dueDate != nil || !item.reminderOffsets.isEmpty
    }

    private var reminderText: String {
        let minutes = item.reminderOffsets.min() ?? 0
        return ReminderPreset.title(for: minutes)
    }
}

// MARK: - 待办行右侧时间位

/// 设计稿 v4：把节假日在待办列表里也标出来，节日名与原时间并列，
/// 例如「中秋-全天」「中秋-15:00」；不是节假日就只显示时间（全天则留空）。
enum TodoRowText {
    static func sideLabel(_ item: TodoItem) -> String {
        let time = item.timeText
        if let festival = SpecialDayCN.todoLabel(for: item.calendarDay) {
            return "\(festival)-\(time)"
        }
        return time == "全天" ? "" : time
    }
}
