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

    /// 改动 9：上下文日期。在某一天的页面录音时 = 那一天；
    /// 相对日期与兜底日期都以它为基准（不再依赖全局 selectedDay）
    var anchor: Date = Date().startOfBeijingDay

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
    /// 改动 8：解析出的时间是否为用户明说（false → 时间行加「默认」角标）
    @State private var parsedHasExplicitTime = true
    /// 改动 9：解析出的日期是否为用户明说（false 且有日期 → 加「本页」角标）
    @State private var parsedHasExplicitDate = true
    /// 改动 9：日期是否来自本页兜底（anchor + 9h）
    @State private var dateFromPage = false
    /// 改动 8：防连点产生两张卡片的令牌（每次 finalize 校验）
    @State private var parseToken = UUID()
    /// 改动 8：识别原文可点编辑 / 长按查看原始未归一化文本
    @State private var editingOriginal = false
    @State private var originalDraft = ""
    @State private var rawOriginal = ""
    @State private var showRawOriginal = false

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
            .alert("原始转写文本", isPresented: $showRawOriginal) {
                Button("好", role: .cancel) { }
            } message: {
                Text(rawOriginal.isEmpty ? "（空）" : rawOriginal)
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
            // 改动 9：顶部一行「录入位置」灰字，说明当前录音的上下文日期
            Text("录入位置：\(anchorPageText)")
                .font(.system(size: 9))
                .foregroundStyle(Theme.secondaryText)
                .padding(.bottom, 4)

            // 卡片顶部固定一行：识别原文（浅灰小字）。
            // 点按可进入文本编辑，改完立即重新解析；长按查看原始未归一化文本
            VStack(alignment: .leading, spacing: 4) {
                if editingOriginal {
                    TextField("识别原文", text: $originalDraft, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 13))
                        .onSubmit {
                            let t = TextNormalizer.normalize(originalDraft)
                            guard !t.isEmpty else { return }
                            transcript = t
                            reparse(from: t)
                            editingOriginal = false
                        }
                } else {
                    Text("识别原文：\(transcript)")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .onTapGesture {
                            originalDraft = transcript
                            editingOriginal = true
                        }
                        .onLongPressGesture {
                            showRawOriginal = true
                        }
                }
            }
            .padding(.bottom, 10)

            // 第一行：事件（点击弹键盘可编辑；无解析结果→原文全文，再兜底「新待办」）
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 3, height: 3)
                    .opacity(parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
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

            // 第二行：时间（点击弹出系统 DatePicker；无时间→「未设具体时间」灰字可点选；
            //         非用户明说的时间加「默认」角标）
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 3, height: 3)
                        .opacity(hasDue ? 0 : 1)
                    Text("时间")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 26, alignment: .leading)
                    Text(dueDisplayText)
                        .font(.system(size: 16))
                        .foregroundStyle(hasDue ? Color.primary : Theme.secondaryText)
                    if hasDue && !parsedHasExplicitTime {
                        Text("默认")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.softFill))
                    }
                    // 改动 9：日期来自本页兜底（anchor 09:00）→ 加「本页」角标
                    if hasDue && dateFromPage {
                        Text("本页")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.softFill))
                    }
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
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDatePicker.toggle()
                        if showDatePicker && !hasDue { hasDue = true }
                    }
                }
                if showDatePicker {
                    DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .onChange(of: dueDate) { _, _ in
                            hasDue = true
                            dateFromPage = false          // 用户手动改了日期：不再是本页兜底
                            parsedHasExplicitDate = true
                            parsedHasExplicitTime = true
                        }
                }
            }
            .padding(.vertical, 10)

            Divider().overlay(Theme.secondaryText.opacity(0.18))

            // 第三行：提醒（点击弹出预设菜单 + 自定义分钟数；无→「不提醒」灰字）
            HStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 3, height: 3)
                    .opacity(reminderMinutes == nil ? 1 : 0)
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

            // 改动 9：时间已过 → 提示只记录不提醒（保存时也不会创建通知）
            if dueIsPast {
                Text("时间已过，只记录不提醒")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.bottom, 8)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.softFill))
    }

    private var dueDisplayText: String {
        guard hasDue else { return "未设具体时间" }
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.month, .day, .weekday, .hour, .minute], from: dueDate)
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]   // weekday: 1=周日
        let wd = weekdayNames[(comps.weekday ?? 1) - 1]
        // 改动 9：日期行格式「11月20日 周五 · 15:00」
        return String(format: "%d月%d日 %@ · %02d:%02d", comps.month ?? 1, comps.day ?? 1, wd, comps.hour ?? 0, comps.minute ?? 0)
    }

    /// 改动 9：录入位置（anchor 日期）文本，如「11月20日」
    private var anchorPageText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month, .day], from: anchor)
        return String(format: "%d月%d日", comps.month ?? 1, comps.day ?? 1)
    }

    /// 改动 9：dueDate 已过去 → 不创建提醒，卡片给出提示
    private var dueIsPast: Bool {
        hasDue && dueDate < Date()
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
                    requestStop()
                } label: {
                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.primary))
                }
                .buttonStyle(.plain)
            } else if case .error = phase {
                // 改动 8：没听清 → 只给「重录」，不给保存（避免空数据落库）
                Button {
                    restart()
                } label: {
                    Text("重录")
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
            DispatchQueue.main.async {
                self.finalize(text, token: self.parseToken)
            }
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

    /// 转写+解析完成 → 弹出确认卡片（不直接入库）。
    /// 改动 8：先判空——输入为空/单字绝不构造空 ParsedTodo 弹卡片，走「没听清，再说一次」；
    /// token 校验防止连点录音产生两张卡片。
    private func finalize(_ text: String, token: UUID? = nil) {
        guard token == nil || token == parseToken else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = clean.isEmpty ? fallback : clean

        guard input.count > 1 else {
            phase = .error("没听清，再说一次")   // 回到录音页，保留重录按钮
            return
        }
        rawOriginal = text
        transcript = TextNormalizer.normalize(input)
        reparse(from: transcript)
        phase = .done
    }

    /// 用（归一化后的）文本重跑解析并刷新卡片三项；确认卡片唯一落库入口不变。
    /// 改动 9：解析以 anchor 为上下文；无日期时兜底 = anchor + 9h（anchor 非今天才有本页兜底）
    private func reparse(from text: String) {
        let parsed = TodoParser.parse(text, now: Date(), anchor: anchor)
        parsedHasExplicitTime = parsed.hasExplicitTime
        parsedHasExplicitDate = parsed.hasExplicitDate
        parsedTitle = parsed.title.isEmpty ? text : parsed.title
        if parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsedTitle = "新待办"   // 兜底：永不留白
        }
        let anchorIsToday = GanzhiCalendar.calendar.isDate(anchor, inSameDayAs: Date())
        if let due = parsed.dueDate {
            hasDue = true
            dueDate = due
            dateFromPage = false
        } else if !anchorIsToday {
            // 在某个具体日期的页面录音：没说日期 → 落在本页（anchor 09:00），卡片加「本页」角标
            hasDue = true
            dueDate = anchor.addingTimeInterval(9 * 3600)
            dateFromPage = true
        } else {
            hasDue = false
            dueDate = anchor.addingTimeInterval(9 * 3600)
            dateFromPage = false
        }
        showDatePicker = false
        reminderMinutes = parsed.reminderOffsets.first ?? app.defaultReminder
    }

    /// 改动 8：停止识别；300ms 内没等到 final 回调就用当前 transcript 兜底解析。
    /// final 先到的话会把 phase 改成 .done，兜底自动跳过。
    private func requestStop() {
        service?.stop()
        let snapshot = transcript
        let token = parseToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.parseToken == token, self.phase == .listening else { return }
            self.finalize(snapshot, token: token)
        }
    }

    private func restart() {
        parseToken = UUID()   // 令牌失效：上一轮未触发的 300ms 兜底 / final 回调作废
        service?.cancel()
        transcript = ""
        parsedTitle = ""
        reminderMinutes = nil
        parsedHasExplicitTime = true
        parsedHasExplicitDate = true
        dateFromPage = false
        rawOriginal = ""
        editingOriginal = false
        showDatePicker = false
        startEngine()
    }

    /// 保存：写入 TodoStore，并按选中的提醒设置通知（由 store.add 内部调度）。
    /// 改动 9：dueDate 已过去时不创建提醒（只记录）
    private func save() {
        let trimmed = parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }   // 转写为空/未填标题：不产生待办
        let offsets = dueIsPast ? [] : (reminderMinutes.map { [$0] } ?? [])
        let item = TodoItem(title: trimmed,
                            dueDate: hasDue ? dueDate : nil,
                            reminderOffsets: offsets,
                            allDay: !hasDue)
        store.add(item)
        dismiss()
    }

    private func teardown() {
        service?.cancel()
        service = nil
    }
}
