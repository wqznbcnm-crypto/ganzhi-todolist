//
//  BirthChartEditorView.swift
//  我的八字录入（改动 6-A）：四柱下拉 + 性别 + 出生年份 + 起运岁数
//

import SwiftUI

struct BirthChartEditorView: View {

    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    // 每柱：天干序号 / 地支序号（nil = 未选）；时柱整体可留空
    @State private var yearStem: Int? = nil
    @State private var yearBranch: Int? = nil
    @State private var monthStem: Int? = nil
    @State private var monthBranch: Int? = nil
    @State private var dayStem: Int? = nil
    @State private var dayBranch: Int? = nil
    @State private var hourStem: Int? = nil
    @State private var hourBranch: Int? = nil
    @State private var hasHour = false

    @State private var gender = "男"
    @State private var birthYearText = ""
    @State private var qiyunYearsText = ""
    @State private var qiyunMonthsText = ""
    @State private var validationError: String? = nil

    var body: some View {
        Form {
            Section {
                pillarEditor("年柱", stem: $yearStem, branch: $yearBranch)
                pillarEditor("月柱", stem: $monthStem, branch: $monthBranch)
                pillarEditor("日柱", stem: $dayStem, branch: $dayBranch)
                Toggle("记得出生时辰", isOn: $hasHour.animation())
                if hasHour {
                    pillarEditor("时柱", stem: $hourStem, branch: $hourBranch)
                }
            } header: {
                Text("四柱（天干 + 地支）")
            } footer: {
                Text("不知道自己的八字，可先用任意排盘工具查出四柱再填入；不填起运岁数也能看到大运干支序列，只是不显示年份。")
            }

            Section {
                Picker("性别", selection: $gender) {
                    Text("男").tag("男")
                    Text("女").tag("女")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("性别（决定大运顺逆）")
            }

            Section {
                TextField("例如 1992", text: $birthYearText)
                    .keyboardType(.numberPad)
            } header: {
                Text("出生年份（选填）")
            } footer: {
                Text("用于给大运标注年份区间与「当前大运」。")
            }

            Section {
                HStack {
                    TextField("7", text: $qiyunYearsText)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                    Text("岁")
                    TextField("3", text: $qiyunMonthsText)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                    Text("个月")
                    Spacer()
                }
            } header: {
                Text("起运岁数（选填，强烈建议填）")
            } footer: {
                Text("从任意排盘结果里抄「X 岁起运」即可；有月则填「X 岁 Y 个月」。")
            }

            if let error = validationError {
                Section {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.accent)
                }
            }

            Section {
                Button("保存") { save() }
                if app.birthChart != nil {
                    Button("清空重录", role: .destructive) {
                        app.clearBirthChart()
                        resetFields()
                    }
                }
            }
        }
        .navigationTitle("我的八字")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadExisting)
    }

    // MARK: 单柱编辑行

    private func pillarEditor(_ title: String, stem: Binding<Int?>, branch: Binding<Int?>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .frame(width: 44, alignment: .leading)
            Picker("天干", selection: stem) {
                Text("—").tag(Int?.none)
                ForEach(0..<10, id: \.self) { i in
                    Text(GanZhiText.stems[i]).tag(Int?.some(i))
                }
            }
            .frame(width: 90)
            Picker("地支", selection: branch) {
                Text("—").tag(Int?.none)
                ForEach(0..<12, id: \.self) { i in
                    Text(GanZhiText.branches[i]).tag(Int?.some(i))
                }
            }
            .frame(width: 90)
            Spacer()
        }
    }

    // MARK: 载入 / 保存

    private func loadExisting() {
        guard let c = app.birthChart else { return }
        yearStem = c.yearPillar.stemIndex; yearBranch = c.yearPillar.branchIndex
        monthStem = c.monthPillar.stemIndex; monthBranch = c.monthPillar.branchIndex
        dayStem = c.dayPillar.stemIndex; dayBranch = c.dayPillar.branchIndex
        if let h = c.hourPillar {
            hasHour = true
            hourStem = h.stemIndex; hourBranch = h.branchIndex
        }
        gender = c.gender
        if let y = c.birthYear { birthYearText = String(y) }
        if let q = c.qiyunMonths {
            qiyunYearsText = String(q / 12)
            qiyunMonthsText = String(q % 12)
        }
    }

    private func resetFields() {
        yearStem = nil; yearBranch = nil
        monthStem = nil; monthBranch = nil
        dayStem = nil; dayBranch = nil
        hourStem = nil; hourBranch = nil
        hasHour = false
        gender = "男"
        birthYearText = ""; qiyunYearsText = ""; qiyunMonthsText = ""
        validationError = nil
    }

    private func save() {
        guard let ys = yearStem, let yb = yearBranch,
              let ms = monthStem, let mb = monthBranch,
              let ds = dayStem, let db = dayBranch else {
            validationError = "年柱、月柱、日柱为必填项"
            return
        }
        var hs: Int? = nil, hb: Int? = nil
        if hasHour {
            guard let s = hourStem, let b = hourBranch else {
                validationError = "时柱选择了「记得出生时辰」但未填全"
                return
            }
            hs = s; hb = b
        }

        // 合法性：干支阴阳相配（奇偶一致）
        for (name, s, b) in [("年柱", ys, yb), ("月柱", ms, mb), ("日柱", ds, db)] + (hs != nil ? [("时柱", hs!, hb!)] : []) {
            if !BirthChart.isValid(stemIndex: s, branchIndex: b) {
                validationError = "\(name)干支组合无效（天干与地支必须阴阳相配）"
                return
            }
        }

        var birthYear: Int? = nil
        if let y = Int(birthYearText.trimmingCharacters(in: .whitespaces)), (1900...2100).contains(y) {
            birthYear = y
        }
        var qiyun: Int? = nil
        let years = Int(qiyunYearsText.trimmingCharacters(in: .whitespaces)) ?? 0
        let months = Int(qiyunMonthsText.trimmingCharacters(in: .whitespaces)) ?? 0
        if years > 0 || months > 0 { qiyun = years * 12 + months }

        let chart = BirthChart(
            yearPillar: Pillar(stemIndex: ys, branchIndex: yb),
            monthPillar: Pillar(stemIndex: ms, branchIndex: mb),
            dayPillar: Pillar(stemIndex: ds, branchIndex: db),
            hourPillar: hs.map { Pillar(stemIndex: $0, branchIndex: hb!) },
            gender: gender, birthYear: birthYear, qiyunMonths: qiyun
        )
        app.saveBirthChart(chart)
        validationError = nil
        dismiss()
    }
}
