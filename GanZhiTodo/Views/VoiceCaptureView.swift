//
//  VoiceCaptureView.swift
//  中文语音录入：录音 → 实时转写 → 自动解析事件/时间 → 校对 → 保存
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

    // 解析结果（可键盘校对）
    @State private var parsedTitle = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var reminders: Set<Int> = []

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
                            correctionSection
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

    // MARK: 校对区

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("事件").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.secondaryText)
                TextField("要做什么", text: $parsedTitle, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(size: 17))
            }

            Toggle("设置时间", isOn: $hasDue.animation())
                .font(.system(size: 15))
            if hasDue {
                DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("提醒").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderPreset.all) { preset in
                            reminderChip(preset)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.softFill))
    }

    private func reminderChip(_ preset: ReminderPreset) -> some View {
        let on = reminders.contains(preset.minutes)
        return Button {
            if on { reminders.remove(preset.minutes) } else { reminders.insert(preset.minutes) }
        } label: {
            Text(preset.title)
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Color.primary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(on ? Color.primary : Color(white: 0.9)))
        }
        .buttonStyle(.plain)
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

    // MARK: 底部按钮

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
                    Text("重新说")
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
        svc.onFinalResult = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async { self.finalize(text) }
        }
        svc.onError = { [weak self] message in
            guard let self else { return }
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
        reminders = Set(parsed.reminderOffsets)
        if parsedTitle.isEmpty {
            parsedTitle = text
        }
        phase = .done
    }

    private func restart() {
        service?.cancel()
        transcript = ""
        parsedTitle = ""
        reminders = []
        startEngine()
    }

    private func save() {
        let trimmed = parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed,
                            dueDate: hasDue ? dueDate : nil,
                            reminderOffsets: Array(reminders).sorted(),
                            allDay: !hasDue)
        store.add(item)
        dismiss()
    }

    private func teardown() {
        service?.cancel()
        service = nil
    }
}
