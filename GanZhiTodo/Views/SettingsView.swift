//
//  SettingsView.swift
//  设置：语音引擎、干支规则、提醒、关于
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var app: AppModel
    @EnvironmentObject var noteBook: PersonalNoteBook
    @Environment(\.dismiss) private var dismiss

    @State private var notifAuthorized = false
    @State private var pendingCount = 0

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
                    NavigationLink {
                        BirthChartEditorView()
                    } label: {
                        HStack {
                            Text("我的八字")
                            Spacer()
                            Text(app.birthChart.map { "\($0.yearPillar.text) \($0.monthPillar.text) \($0.dayPillar.text)" + ($0.hourPillar.map { " \($0.text)" } ?? "") } ?? "未录入")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("八字排盘")
                } footer: {
                    Text("录入本命四柱后，首页与周详情页会显示流日/流月/流年/大运与本命四柱的对照面板。")
                }

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
                    Button("发一条测试提醒（10 秒后）") {
                        NotificationScheduler.shared.scheduleTest(after: 10) { _ in
                            NotificationScheduler.shared.pendingCount { count in
                                self.pendingCount = count
                            }
                        }
                    }
                    LabeledContent("已排队的提醒", value: "\(pendingCount) 条")
                } header: {
                    Text("待办提醒")
                } footer: {
                    if notifAuthorized {
                        Text("通知权限已开启。设置完提醒后，把 App 退到后台，到点会弹通知。")
                    } else {
                        Button("通知权限未开启，点此去开启") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        PersonalNoteBookView()
                    } label: {
                        HStack {
                            Text("我的命理笔记")
                            Spacer()
                            Text(noteBook.filledCount > 0 ? "\(noteBook.filledCount) 个字已填写" : "未填写")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("启用个人命理笔记", isOn: $noteBook.enabled)
                } header: {
                    Text("个人命理笔记")
                } footer: {
                    Text("按天干/地支记录你自己的宜做、忌做标签（如见朋友、谈生意、争吵）。启用后，遇到对应干支的日子/流月/流年，首页宜忌区优先显示你的内容，替代万年历宜忌。\n\n仅作个人记录，与历法吉凶判定无关。")
                }

                Section {
                } header: {
                    Text("宜忌内容说明")
                } footer: {
                    Text(NoteCatalog.disclaimer)
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
                NotificationScheduler.shared.pendingCount { count in
                    self.pendingCount = count
                }
            }
        }
    }
}
