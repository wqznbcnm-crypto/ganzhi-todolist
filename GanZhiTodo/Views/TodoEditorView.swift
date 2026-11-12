//
//  TodoEditorView.swift
//  待办新增 / 键盘编辑
//

import SwiftUI

struct TodoEditorView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    private let day: Date?
    private let item: TodoItem?

    @State private var title = ""
    @State private var note = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var reminders: Set<Int> = []
    @FocusState private var titleFocused: Bool

    init(day: Date) {
        self.day = day
        self.item = nil
    }

    init(item: TodoItem) {
        self.item = item
        self.day = nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("要做什么", text: $title, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 17))
                        .focused($titleFocused)
                    TextField("备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 15))
                }

                Section {
                    Toggle("设置时间", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("时间", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("提醒")
                            .font(.system(size: 15))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ReminderPreset.all) { preset in
                                    chip(preset)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        if reminders.isEmpty {
                            Text("不提醒")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }

                if let item {
                    Section {
                        Button(role: .destructive) {
                            store.delete(item)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除这条待办")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(item == nil ? "新建待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: populate)
    }

    private func chip(_ preset: ReminderPreset) -> some View {
        let on = reminders.contains(preset.minutes)
        return Button {
            if on { reminders.remove(preset.minutes) } else { reminders.insert(preset.minutes) }
        } label: {
            Text(preset.title)
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(on ? Color.primary : Theme.softFill))
        }
        .buttonStyle(.plain)
    }

    private func populate() {
        if let item {
            title = item.title
            note = item.note
            if let due = item.dueDate {
                hasDue = true
                dueDate = due
            } else {
                hasDue = false
            }
            reminders = Set(item.reminderOffsets)
        } else {
            // 新建模式：默认时间为当天 09:00，提醒沿用设置里的默认值
            let base = (day ?? Date()).startOfBeijingDay
            dueDate = GanzhiCalendar.calendar.date(byAdding: .hour, value: 9, to: base) ?? base
            hasDue = false
            if let defaultReminder = app.defaultReminder {
                reminders = [defaultReminder]
            } else {
                reminders = []
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                titleFocused = true
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let due = hasDue ? dueDate : nil
        let offsets = Array(reminders).sorted()

        if let item {
            var copy = item
            copy.title = trimmed
            copy.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.dueDate = due
            copy.allDay = !hasDue
            copy.reminderOffsets = offsets
            store.update(copy)
        } else {
            let newItem = TodoItem(title: trimmed,
                                   note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                   dueDate: due,
                                   reminderOffsets: offsets,
                                   allDay: !hasDue)
            store.add(newItem)
        }
        dismiss()
    }
}
