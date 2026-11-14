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
    /// 当前所处的大运（0 起）；nil = 按出生年份 + 起运岁数自动推算
    @State private var currentDayunIndex: Int? = nil
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

            // 设计稿 v4：大运列显示「当前那一步」，可直接指定
            if !previewSteps.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(previewSteps.enumerated()), id: \.offset) { index, step in
                                dayunChip(index: index, step: step)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("当前大运（选填）")
                } footer: {
                    Text("不选则按「出生年份 + 起运岁数」自动推算；两者都不填就无法判断，面板里的大运列会显示「—」而不是假装第一步。")
                }
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

    // MARK: 当前大运候选

    private var qiyunValue: Int? {
        let years = Int(qiyunYearsText.trimmingCharacters(in: .whitespaces)) ?? 0
        let months = Int(qiyunMonthsText.trimmingCharacters(in: .whitespaces)) ?? 0
        return (years > 0 || months > 0) ? years * 12 + months : nil
    }

    /// 按当前已选的年柱/月柱/性别展开 6 步大运（填了出生年与起运岁数才有年份）
    private var previewSteps: [DayunStep] {
        guard let ys = yearStem, let yb = yearBranch,
              let ms = monthStem, let mb = monthBranch else { return [] }
        let chart = BirthChart(yearPillar: Pillar(stemIndex: ys, branchIndex: yb),
                               monthPillar: Pillar(stemIndex: ms, branchIndex: mb),
                               dayPillar: Pillar(sexagenaryIndex: 0),
                               hourPillar: nil,
                               gender: gender,
                               birthYear: Int(birthYearText.trimmingCharacters(in: .whitespaces)),
                               qiyunMonths: qiyunValue,
                               currentDayunIndex: nil)
        return DayunCalculator.steps(chart: chart)
    }

    private func dayunChip(index: Int, step: DayunStep) -> some View {
        let selected = currentDayunIndex == index
        return Button {
            currentDayunIndex = selected ? nil : index   // 再点一次取消，回到自动推算
        } label: {
            VStack(spacing: 2) {
                Text("第\(index + 1)步")
                    .font(.system(size: 9))
                    .foregroundStyle(selected ? Theme.accent : Theme.secondaryText)
                Text(step.pillar.text)
                    .font(Theme.ganzhi(16))
                    .foregroundStyle(selected ? Theme.accent : .primary)
                Text(step.startYear.map { "\($0)" } ?? "—")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
            }
            .frame(width: 48)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.08) : Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
        currentDayunIndex = c.currentDayunIndex
    }

    private func resetFields() {
        yearStem = nil; yearBranch = nil
        monthStem = nil; monthBranch = nil
        dayStem = nil; dayBranch = nil
        hourStem = nil; hourBranch = nil
        hasHour = false
        gender = "男"
        birthYearText = ""; qiyunYearsText = ""; qiyunMonthsText = ""
        currentDayunIndex = nil
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
        let qiyun = qiyunValue

        let chart = BirthChart(
            yearPillar: Pillar(stemIndex: ys, branchIndex: yb),
            monthPillar: Pillar(stemIndex: ms, branchIndex: mb),
            dayPillar: Pillar(stemIndex: ds, branchIndex: db),
            hourPillar: hs.map { Pillar(stemIndex: $0, branchIndex: hb!) },
            gender: gender, birthYear: birthYear, qiyunMonths: qiyun,
            currentDayunIndex: currentDayunIndex
        )
        app.saveBirthChart(chart)
        validationError = nil
        dismiss()
    }
}
