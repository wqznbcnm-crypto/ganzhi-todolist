//
//  BaZiBoardView.swift
//  八字排盘面板（改动 6-E / 设计稿 v4）：
//    即时排盘（流日｜流月｜流年｜大运） ‖ 本人八字（年柱｜月柱｜日柱｜时柱）
//  三行：主星（十神）/ 天干 / 地支；五行着色。
//
//  设计稿 v4 变更：
//    · 两组之间加竖直分隔线 + 组标题，一眼能分出「即时排盘」与「本人八字」
//    · 不再常驻连线；改为点击某个干/支字，弹出与该字相关的关系（sheet）
//    · 底部灰色大运条（DayunBarView）已删除
//    · 大运列取「当前所处那一步」（优先用户手动指定，其次按出生年 + 起运岁数推算）
//

import SwiftUI

/// 面板一列的数据
struct BoardColumn: Identifiable {
    let id: Int                 // 柱位 0–7
    let title: String
    let titleAccent: Bool       // 「大运」「日柱」用朱砂
    let stem: String?
    let branch: String?
    let god: String             // 主星文字（日柱列 = 元男/元女）
}

struct BaZiBoardData {
    /// 柱位 0–7 的天干/地支序号；空柱为 nil
    let stems: [Int?]
    let branches: [Int?]
    /// 日干序号（求十神基准）
    let dayStemIndex: Int?
    /// 日柱主星显示（元男/元女）
    let dayMasterLabel: String
    /// 大运列标题角标（未定 → "?"; nil = 无）
    let dayunBadge: String?

    /// 列标题（固定 8 列）
    static let titles = ["流日", "流月", "流年", "大运", "年柱", "月柱", "日柱", "时柱"]

    /// 从「选中日期 + 生辰」构建面板数据
    init(for day: Date, chart: BirthChart?, lateZi: Bool = true) {
        let pillars = GanzhiCalendar.shared.fourPillars(for: day, lateZiCountsAsNextDay: lateZi)
        var stems: [Int?] = Array(repeating: nil, count: 8)
        var branches: [Int?] = Array(repeating: nil, count: 8)

        // 0 流日 / 1 流月 / 2 流年（以选中日期为准）
        stems[0] = pillars.day.stemIndex;  branches[0] = pillars.day.branchIndex
        stems[1] = pillars.month.stemIndex; branches[1] = pillars.month.branchIndex
        stems[2] = pillars.year.stemIndex; branches[2] = pillars.year.branchIndex

        // 3 大运：当前所处那一步（不再盲取第一步）
        var dayunBadge: String? = nil
        if let chart {
            let steps = DayunCalculator.steps(chart: chart)
            if let index = DayunCalculator.resolvedIndex(chart: chart, list: steps) {
                stems[3] = steps[index].pillar.stemIndex
                branches[3] = steps[index].pillar.branchIndex
            } else {
                dayunBadge = "?"   // 既没指定也算不出：留空，而不是假装是第一步
            }
        }

        // 4–7 本命四柱
        if let chart {
            stems[4] = chart.yearPillar.stemIndex;  branches[4] = chart.yearPillar.branchIndex
            stems[5] = chart.monthPillar.stemIndex; branches[5] = chart.monthPillar.branchIndex
            stems[6] = chart.dayPillar.stemIndex;   branches[6] = chart.dayPillar.branchIndex
            stems[7] = chart.hourPillar?.stemIndex; branches[7] = chart.hourPillar?.branchIndex
        }

        self.stems = stems
        self.branches = branches
        self.dayStemIndex = chart?.dayPillar.stemIndex
        self.dayMasterLabel = chart?.dayMasterLabel ?? ""
        self.dayunBadge = dayunBadge
    }

    init(stems: [Int?], branches: [Int?], dayStemIndex: Int?, dayMasterLabel: String, dayunBadge: String?) {
        self.stems = stems
        self.branches = branches
        self.dayStemIndex = dayStemIndex
        self.dayMasterLabel = dayMasterLabel
        self.dayunBadge = dayunBadge
    }

    /// 面板列（未录入八字 → 空数组，面板显示引导态）
    var columns: [BoardColumn] {
        guard stems[4] != nil else { return [] }
        return (0..<8).map { i in
            var god = ""
            if let ds = dayStemIndex, let s = stems[i] {
                god = TenGod.of(dayStem: ds, otherStem: s).rawValue
            }
            if i == 6 { god = dayMasterLabel }
            return BoardColumn(id: i,
                               title: Self.titles[i],
                               titleAccent: i == 3 || i == 6,
                               stem: stems[i].map { GanZhiText.stems[$0] },
                               branch: branches[i].map { GanZhiText.branches[$0] },
                               god: god)
        }
    }

    /// 关系命中（含 T3）
    var relationHits: [RelationHit] {
        guard stems[4] != nil else { return [] }
        return RelationEngine.compute(stems: stems, branches: branches)
    }
}

// MARK: - 面板视图

struct BaZiBoardView: View {

    @EnvironmentObject var app: AppModel
    let data: BaZiBoardData
    /// 点击某个干/支字：参数为（列序号 0–7，是否天干行）
    var onTapChar: ((Int, Bool) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let colWidth: CGFloat = width >= 352 ? 41.5 : max(37, (width - 20) / 8)
            let labelWidth: CGFloat = 20
            let hasChart = !data.columns.isEmpty

            if hasChart {
                board(columns: data.columns, colWidth: colWidth, labelWidth: labelWidth)
            } else {
                emptyGuide
            }
        }
        .frame(height: 132)
    }

    // MARK: 组标题 + 三行面板

    private func board(columns: [BoardColumn], colWidth: CGFloat, labelWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 组标题：即时排盘 ‖ 本人八字（分隔线与下面的列分隔对齐）
            HStack(spacing: 0) {
                Text("即时排盘")
                    .font(Theme.puhui(8.5))
                    .foregroundStyle(Theme.secondaryText.opacity(0.75))
                    .frame(width: labelWidth + colWidth * 4, alignment: .leading)
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 1, height: 9)
                Text("本人八字")
                    .font(Theme.puhui(8.5))
                    .foregroundStyle(Theme.secondaryText.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.bottom, 3)

            // 列标题行
            HStack(spacing: 0) {
                Text("")
                    .frame(width: labelWidth, alignment: .leading)
                ForEach(columns) { col in
                    if col.id == 4 { groupDivider(height: 12) }
                    Text(col.title)
                        .font(.system(size: 9.5))
                        .letterSpacing(0.4)
                        .foregroundStyle(col.titleAccent ? Theme.accent : Theme.secondaryText)
                        .frame(width: colWidth)
                }
            }
            .padding(.bottom, 4)

            // 主星行
            HStack(spacing: 0) {
                rowLabel("主星", width: labelWidth)
                ForEach(columns) { col in
                    if col.id == 4 { groupDivider(height: 18) }
                    Text(col.god)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: colWidth)
                }
            }
            .frame(height: 18)

            // 天干行
            HStack(spacing: 0) {
                rowLabel("天干", width: labelWidth)
                ForEach(columns) { col in
                    if col.id == 4 { groupDivider(height: 30) }
                    charCell(col.stem ?? "—", color: stemColor(col), col: col.id, isStem: true)
                        .frame(width: colWidth)
                }
            }
            .frame(height: 30)

            // 地支行
            HStack(spacing: 0) {
                rowLabel("地支", width: labelWidth)
                ForEach(columns) { col in
                    if col.id == 4 { groupDivider(height: 30) }
                    charCell(col.branch ?? "—", color: branchColor(col), col: col.id, isStem: false)
                        .frame(width: colWidth)
                }
            }
            .frame(height: 30)
            .padding(.bottom, 6)
        }
    }

    /// 单个干/支字：可点，点开与该字相关的关系弹层
    private func charCell(_ text: String, color: Color, col: Int, isStem: Bool) -> some View {
        Text(text)
            .font(Theme.ganzhi(23))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard text != "—" else { return }
                onTapChar?(col, isStem)
            }
    }

    private func groupDivider(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(width: 1, height: height)
    }

    private func rowLabel(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 9.5))
            .foregroundStyle(Theme.secondaryText.opacity(0.7))
            .frame(width: width, alignment: .leading)
    }

    private func stemColor(_ col: BoardColumn) -> Color {
        guard let s = col.stem, let idx = GanZhiText.stems.firstIndex(of: s) else { return .secondary }
        return Theme.element(WuXing.ofStem(idx))
    }

    private func branchColor(_ col: BoardColumn) -> Color {
        guard let b = col.branch, let idx = GanZhiText.branches.firstIndex(of: b) else { return .secondary }
        return Theme.element(WuXing.ofBranch(idx))
    }

    /// 未录入引导态（改动 6-E2-5）
    private var emptyGuide: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Text("录入你的八字，看每日干支与本命四柱的呼应")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                NavigationLink {
                    BirthChartEditorView()
                } label: {
                    Text("录入八字")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
        }
        .padding(.vertical, 18)
    }
}

// MARK: - 字距辅助

extension Text {
    func letterSpacing(_ value: CGFloat) -> some View {
        kerning(value)
    }
}
