//
//  EventCaptureView.swift
//  事迹记录录入（v8）：记录已经发生的事，绑定量子四柱
//  · 文字手输 + 麦克风语音（麦克风在输入框右侧）
//  · 选发生日期；可额外选时辰 —— 填了就是四柱，不填只记年月日三柱
//  · 单条可设是否参与「同干支回顾提醒」
//

import SwiftUI

struct EventCaptureView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppModel
    let store = EventStore.shared

    /// 编辑已有记录（nil = 新建）
    let editing: EventRecord?

    @State private var title: String = ""
    @State private var day: Date = Date().startOfBeijingDay
    @State private var hasHour = false
    @State private var hourMinute: Date = Date()
    @State private var notifyOnMatch = true
    @State private var showDatePicker = false

    @State private var recording = false
    @State private var speechDenied = false
    private let speech = AppleSpeechService()
    @State private var speechBase = ""

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init(anchor: Date = Date().startOfBeijingDay, editing: EventRecord? = nil) {
        self.editing = editing
        _day = State(initialValue: anchor.startOfBeijingDay)
        if let e = editing {
            _title = State(initialValue: e.title)
            _day = State(initialValue: e.occurredAt.startOfBeijingDay)
            _hasHour = State(initialValue: e.hasHour)
            _hourMinute = State(initialValue: e.occurredAt)
            _notifyOnMatch = State(initialValue: e.notifyOnMatch)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    dateBlock
                    hourBlock
                    if let preview = pillarPreview {
                        pillarBlock(preview)
                    }
                    notifyBlock
                    disclaimer
                }
                .padding(.horizontal, Theme.hPadding)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle(editing == nil ? "记录事迹" : "编辑事迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { stopSpeech(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { setupSpeech() }
            .onDisappear { stopSpeech() }
        }
    }

    // MARK: 标题 + 麦克风

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("发生了什么")
            HStack(spacing: 10) {
                TextField("例：摔跤磕碰、签了合同、搬家", text: $title, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04)))

                Button {
                    toggleSpeech()
                } label: {
                    Image(systemName: recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(recording ? Color(hexString: "#3A3A3A") : Theme.accent))
                }
                .buttonStyle(.plain)
            }
            if speechDenied {
                Text("麦克风或语音识别权限未开启，可在系统设置里允许")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
            } else if recording {
                Text("正在听…再点一次结束")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    // MARK: 日期

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("发生日期")
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showDatePicker.toggle() }
            } label: {
                HStack {
                    let c = GanzhiCalendar.calendar.dateComponents([.year, .month, .day], from: day)
                    Text("\(c.year ?? 0) 年 \(c.month ?? 0) 月 \(c.day ?? 0) 日")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04)))
            }
            .buttonStyle(.plain)

            if showDatePicker {
                DatePicker("", selection: $day, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
        }
    }

    // MARK: 时辰

    private var hourBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasHour.animation(.easeInOut(duration: 0.18))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("我记得具体时辰")
                        .font(.system(size: 15))
                    Text(hasHour ? "记录完整四柱：年 · 月 · 日 · 时" : "只记年月日三柱；不知道时辰也没关系")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .tint(Theme.accent)

            if hasHour {
                DatePicker("时刻", selection: $hourMinute, displayedComponents: [.hourAndMinute])
                    .font(.system(size: 14))
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
        }
    }

    // MARK: 四柱预览

    private var pillarPreview: FourPillars? {
        let cal = GanzhiCalendar.calendar
        let c = cal.dateComponents([.hour, .minute], from: hourMinute)
        let base = hasHour
            ? (cal.date(bySettingHour: c.hour ?? 12, minute: c.minute ?? 0, second: 0, of: day) ?? day)
            : (cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
        return GanzhiCalendar.shared.fourPillars(for: base, lateZiCountsAsNextDay: app.lateZiCountsAsNextDay)
    }

    private func pillarBlock(_ p: FourPillars) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("绑定干支")
            HStack(spacing: 0) {
                pillarCell("年", p.year.text)
                pillarCell("月", p.month.text)
                pillarCell("日", p.day.text)
                if hasHour {
                    pillarCell("时", p.hour.text)
                } else {
                    VStack(spacing: 4) {
                        Text("时").font(Theme.puhui(9)).foregroundStyle(Theme.secondaryText)
                        Text("—").font(Theme.ganzhi(19)).foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035)))
        }
    }

    private func pillarCell(_ label: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(Theme.puhui(9)).foregroundStyle(Theme.secondaryText)
            Text(text).font(Theme.ganzhi(19)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 单条提醒开关

    private var notifyBlock: some View {
        Toggle(isOn: $notifyOnMatch) {
            VStack(alignment: .leading, spacing: 2) {
                Text("走到相同干支时提醒我回顾")
                    .font(.system(size: 15))
                Text("关掉则这条只记在列表里，不触发回顾提醒")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .tint(Theme.accent)
    }

    private var disclaimer: some View {
        Text("仅为您的个人历史笔记回顾，不代表预判、吉凶预测。")
            .font(.system(size: 11))
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
    }

    // MARK: 语音

    private func setupSpeech() {
        speech.onPartialResult = { text in
            title = speechBase.isEmpty ? text : speechBase + text
        }
        speech.onFinalResult = { text in
            let merged = speechBase.isEmpty ? text : speechBase + text
            title = TextNormalizer.normalize(merged)
        }
        speech.onError = { _ in recording = false }
    }

    private func toggleSpeech() {
        if recording {
            stopSpeech()
            return
        }
        AppleSpeechService.requestPermission { state in
            guard state == .authorized else {
                speechDenied = true
                return
            }
            speechBase = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !speechBase.isEmpty { speechBase += "，" }
            recording = true
            speech.start()
        }
    }

    private func stopSpeech() {
        guard recording else { return }
        recording = false
        speech.stop()
    }

    // MARK: 保存

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stopSpeech()

        let cal = GanzhiCalendar.calendar
        var occurred = day.startOfBeijingDay
        if hasHour {
            let c = cal.dateComponents([.hour, .minute], from: hourMinute)
            occurred = cal.date(bySettingHour: c.hour ?? 12, minute: c.minute ?? 0,
                                second: 0, of: day) ?? day
        }

        if let existing = editing {
            // 改了日期/时辰 → 四柱跟着重算（保留 id 与创建时间）
            let rebuilt = EventRecord(id: existing.id, title: trimmed, occurredAt: occurred,
                                      hasHour: hasHour, notifyOnMatch: notifyOnMatch,
                                      createdAt: existing.createdAt)
            store.update(rebuilt)
        } else {
            store.add(EventRecord(title: trimmed, occurredAt: occurred,
                                  hasHour: hasHour, notifyOnMatch: notifyOnMatch))
        }
        NotificationScheduler.shared.rescheduleAll(TodoStore.shared.items)
        dismiss()
    }
}
