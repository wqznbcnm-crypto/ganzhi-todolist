//
//  VoiceCaptureView.swift
//  中文语音录入：录音 → 实时转写 → 自动解析事件/时间 → 确认卡片逐项校对 → 保存
//  改动 3：录音结束不再直接入库，弹出「确认卡片」（事件/时间/提醒三行，逐项可点修改）；
//          卡片顶部展示转写原文；底部为「保存 / 重录」两个按钮。
//

import SwiftUI
import AVFoundation
import UIKit

struct VoiceCaptureView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case listening
        case done
        case error(String)
        case denied
    }

    @State private var phase: Phase = .listening
    @State private var transcript = ""
    @State private var pulsing = false

    // 确认卡片状态（逐项可点修改）
    @State private var parsedTitle = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var showDatePicker = false
    @State private var reminderMinutes: Int? = nil
    @State private var showCustomReminder = false
    @State private var customReminderText = ""

    @State private var service: (any SpeechRecognitionService)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        micSection
                            .padding(.top, 28)
                        transcriptSection
                        if case .done = phase {
                            confirmCard
                        }
                        if case .error(let message) = phase {
                            errorBox(message)
                        }
                        if case .denied = phase {
                            deniedBox
                        }
                    }
                    .padding(.horizontal, Theme.hPadding)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)

                actionBar
            }
            .navigationTitle("语音记待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { teardown(); dismiss() }
                }
            }
            .alert("自定义提前提醒", isPresented: $showCustomReminder) {
                TextField("提前多少分钟", text: $customReminderText)
                    .keyboardType(.numberPad)
                Button("确定") {
                    if let m = Int(customReminderText.trimmingCharacters(in: .whitespaces)), m >= 0 {
                        reminderMinutes = m
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("填 0 表示准时提醒")
            }
        }
        .onAppear(perform: begin)
        .onDisappear(perform: teardown)
    }

    // MARK: 麦克风

    private var micSection: some View {
        ZStack {
            if case .listening = phase {
                Circle()
                    .stroke(Theme.accent.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 128, height: 128)
                    .scaleEffect(pulsing ? 1.15 : 0.9)
                    .opacity(pulsing ? 0.1 : 0.6)
                Circle()
                    .stroke(Theme.accent.opacity(0.18), lineWidth: 1)
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulsing ? 1.2 : 0.92)
                    .opacity(pulsing ? 0.06 : 0.4)
            }

            Circle()
                .fill(circleColor)
                .frame(width: 92, height: 92)
            Image(systemName: iconName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white)
        }
        .onChange(of: phase) { _, newPhase in
            if case .listening = newPhase {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                withAnimation { pulsing = false }
            }
        }
    }

    private var circleColor: Color {
        switch phase {
        case .listening: return Theme.accent
        case .done: return Color.primary
        case .denied, .error: return Theme.secondaryText
        }
    }

    private var iconName: String {
        switch phase {
        case .listening: return "waveform"
        case .done: return "checkmark"
        case .denied, .error: return "mic.slash"
        }
    }

    // MARK: 转写

    private var transcriptSection: some View {
        VStack(spacing: 6) {
            if transcript.isEmpty {
                Text("说点什么，比如：\n「明天下午三点开产品评审会」")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            } else {
                Text(transcript)
                    .font(.system(size: 20, weight: .regular))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            if case .listening = phase {
                Text("正在聆听… 说完会自动停止")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .softCard()
    }

    // MARK: 确认卡片（改动 3）

    private var confirmCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片顶部：语音转写原文（浅灰小字，供核对）
            Text("原文：\(transcript)")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondaryText.opacity(0.8))
                .lineLimit(2)
                .padding(.bottom, 10)

            // 第一行：事件（点击弹键盘可编辑）
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("事件")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 26, alignment: .leading)
                TextField("要做什么", text: $parsedTitle, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(size: 16))
            }
            .padding(.vertical, 10)

            Divider().overlay(Theme.secondaryText.opacity(0.18))

            // 第二行：时间（点击弹出系统 DatePicker；可清除为「无日期」）
            VStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDatePicker.toggle()
                        if showDatePicker && !hasDue { hasDue = true }
                    }
                } label: {
                    HStack {
                        Text("时间")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 26, alignment: .leading)
                        Text(dueDisplayText)
                            .font(.system(size: 16))
                            .foregroundStyle(hasDue ? Color.primary : Theme.secondaryText)
                        Spacer()
                        if hasDue {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hasDue = false
                                    showDatePicker = false
                                }
                            } label: {
                                Text("清除")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)
                if showDatePicker {
                    DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .onChange(of: dueDate) { _, _ in hasDue = true }
                }
            }
            .padding(.vertical, 10)

            Divider().overlay(Theme.secondaryText.opacity(0.18))

            // 第三行：提醒（点击弹出预设菜单 + 自定义分钟数）
            HStack {
                Text("提醒")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 26, alignment: .leading)
                Menu {
                    Button("不提醒") { reminderMinutes = nil }
                    Button("准时提醒") { reminderMinutes = 0 }
                    Button("提前 30 分钟") { reminderMinutes = 30 }
                    Button("提前 1 小时") { reminderMinutes = 60 }
                    Button("提前 1 天") { reminderMinutes = 1440 }
                    Button("提前 5 天") { reminderMinutes = 7200 }
                    Button("自定义分钟数…") {
                        customReminderText = ""
                        showCustomReminder = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(reminderDisplayText)
                            .font(.system(size: 16))
                            .foregroundStyle(reminderMinutes == nil ? Theme.secondaryText : Color.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.softFill))
    }

    private var dueDisplayText: String {
        guard hasDue else { return "无日期" }
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.month, .day, .hour, .minute], from: dueDate)
        return String(format: "%d月%d日 %02d:%02d", comps.month ?? 1, comps.day ?? 1, comps.hour ?? 0, comps.minute ?? 0)
    }

    private var reminderDisplayText: String {
        guard let m = reminderMinutes else { return "不提醒" }
        return ReminderPreset.title(for: m)
    }

    private func errorBox(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard()
    }

    private var deniedBox: some View {
        VStack(spacing: 10) {
            Text("需要麦克风与语音识别权限才能语音录入")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
            Button("去系统设置开启") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .softCard()
    }

    // MARK: 底部按钮（listening → 完成；done → 重录 / 保存）

    private var actionBar: some View {
        HStack(spacing: 12) {
            if case .listening = phase {
                Button {
                    service?.stop()
                } label: {
                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.primary))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    restart()
                } label: {
                    Text("重录")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.softFill))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Text("保存")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.primary))
                }
                .buttonStyle(.plain)
                .disabled(parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, Theme.hPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.bar)
    }

    // MARK: 流程

    private func begin() {
        let useIFlytek = SpeechServiceFactory.iflytekAvailable() && app.speechEngine != SpeechEngine.apple.rawValue

        if useIFlytek {
            startEngine()
        } else {
            AppleSpeechService.requestPermission { state in
                switch state {
                case .authorized:
                    startEngine()
                case .denied:
                    phase = .denied
                case .notDetermined:
                    startEngine()
                }
            }
        }
    }

    private func startEngine() {
        let svc = SpeechServiceFactory.make(preference: app.speechEngine)
        svc.onPartialResult = { text in
            DispatchQueue.main.async { self.transcript = text }
        }
        svc.onFinalResult = { text in
            DispatchQueue.main.async { self.finalize(text) }
        }
        svc.onError = { message in
            DispatchQueue.main.async {
                if self.transcript.isEmpty {
                    self.phase = .error(message)
                } else {
                    self.finalize(self.transcript)
                }
            }
        }
        svc.onStarted = {
            DispatchQueue.main.async { self.phase = .listening }
        }
        service = svc
        phase = .listening
        transcript = ""
        svc.start()
    }

    /// 转写+解析完成 → 弹出确认卡片（不直接入库）
    private func finalize(_ text: String) {
        transcript = text
        let parsed = TodoParser.parse(text, now: Date())
        parsedTitle = parsed.title
        if let due = parsed.dueDate {
            hasDue = true
            dueDate = due
        } else {
            hasDue = false
            dueDate = (app.selectedDay).addingTimeInterval(9 * 3600)
        }
        showDatePicker = false
        reminderMinutes = parsed.reminderOffsets.first ?? app.defaultReminder
        if parsedTitle.isEmpty {
            parsedTitle = text
        }
        phase = .done
    }

    private func restart() {
        service?.cancel()
        transcript = ""
        parsedTitle = ""
        reminderMinutes = nil
        showDatePicker = false
        startEngine()
    }

    /// 保存：写入 TodoStore，并按选中的提醒设置通知（由 store.add 内部调度）
    private func save() {
        let trimmed = parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }   // 转写为空/未填标题：不产生待办
        let item = TodoItem(title: trimmed,
                            dueDate: hasDue ? dueDate : nil,
                            reminderOffsets: reminderMinutes.map { [$0] } ?? [],
                            allDay: !hasDue)
        store.add(item)
        dismiss()
    }

    private func teardown() {
        service?.cancel()
        service = nil
    }
}
