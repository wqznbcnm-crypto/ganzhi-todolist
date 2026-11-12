//
//  SettingsView.swift
//  设置：语音引擎、干支规则、提醒、关于
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var notifAuthorized = false

    private var defaultReminderProxy: Binding<Int> {
        Binding<Int>(
            get: { app.defaultReminder ?? -1 },
            set: { app.defaultReminder = ($0 == -1 ? nil : $0) }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("识别引擎", selection: $app.speechEngine) {
                        Text("自动（优先讯飞）").tag(SpeechEngine.auto.rawValue)
                        Text("科大讯飞").tag(SpeechEngine.iflytek.rawValue)
                        Text("系统中文识别").tag(SpeechEngine.apple.rawValue)
                    }
                    if SpeechServiceFactory.iflytekAvailable() {
                        Label("科大讯飞 SDK 已集成", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Label("未集成讯飞 SDK，当前使用系统中文识别", systemImage: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("语音识别")
                } footer: {
                    Text("语音转文字全部在本机 App 内完成，不依赖 Siri 解析内容。\n\n唤醒方式：在「快捷指令」App 新建快捷指令，动作选择「语音记待办」，然后长按编辑名字为「小记小记」；喊 Hey Siri 再喊「小记小记」即可打开本 App 并自动录音。")
                }

                Section {
                    Toggle("晚子时（23:00–23:59）归次日", isOn: $app.lateZiCountsAsNextDay)
                } header: {
                    Text("干支换算")
                } footer: {
                    Text("年柱以立春、月柱以十二「节」的交节时刻为界，全部按北京时间计算。节气时刻为天文近似值，误差约 ±15 分钟；节气当天以正午 12:00 为界判定当日所属干支。")
                }

                Section {
                    Picker("默认提醒", selection: defaultReminderProxy) {
                        Text("不提醒").tag(-1)
                        ForEach(ReminderPreset.all) { preset in
                            Text(preset.title).tag(preset.minutes)
                        }
                    }
                } header: {
                    Text("待办提醒")
                } footer: {
                    if notifAuthorized {
                        Text("通知权限已开启")
                    } else {
                        Button("通知权限未开启，点此去开启") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("数据", value: "仅保存在本机")
                    LabeledContent("日历范围", value: "公历 1900–2100")
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                NotificationScheduler.shared.currentAuthorizationStatus { status in
                    self.notifAuthorized = (status == .authorized || status == .provisional)
                }
            }
        }
    }
}
