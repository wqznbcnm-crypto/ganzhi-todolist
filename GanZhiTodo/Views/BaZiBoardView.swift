//
//  BaZiBoardView.swift
//  八字排盘面板（改动 6-E）：流日｜流月｜流年｜大运 ‖ 年柱｜月柱｜日柱｜时柱
//  三行：主星（十神）/ 天干 / 地支；五行着色；showsRelationLines = true 时
//  在面板下方追加正交折线连线区（改动 7-D，仅周详情页使用）。
//  性能红线：关系只在数据变化时重算，不放逐帧时钟里。
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

    /// 从「选中日期 + 生辰」构建面板数据
    init(for day: Date, chart: BirthChart?, lateZi: Bool = true) {
        let pillars = GanzhiCalendar.shared.fourPillars(for: day, lateZiCountsAsNextDay: lateZi)
        var stems: [Int?] = Array(repeating: nil, count: 8)
        var branches: [Int?] = Array(repeating: nil, count: 8)

        // 0 流日 / 1 流月 / 2 流年（以选中日期为准）
        stems[0] = pillars.day.stemIndex;  branches[0] = pillars.day.branchIndex
        stems[1] = pillars.month.stemIndex; branches[1] = pillars.month.branchIndex
        stems[2] = pillars.year.stemIndex; branches[2] = pillars.year.branchIndex

        // 3 大运（当前步；未定 → 第 1 步）
        var dayunBadge: String? = nil
        if let chart {
            let steps = DayunCalculator.steps(chart: chart)
            let currentIndex = DayunCalculator.currentStepIndex(steps: steps)
            let step = steps[currentIndex ?? 0]
            stems[3] = step.pillar.stemIndex
            branches[3] = step.pillar.branchIndex
            if currentIndex == nil { dayunBadge = "?" }
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
        let titles = ["流日", "流月", "流年", "大运", "年柱", "月柱", "日柱", "时柱"]
        return (0..<8).map { i in
            var god = ""
            if let ds = dayStemIndex, let s = stems[i] {
                god = TenGod.of(dayStem: ds, otherStem: s).rawValue
            }
            if i == 6 { god = dayMasterLabel }
            return BoardColumn(id: i,
                               title: titles[i],
                               titleAccent: i == 3 || i == 6,
                               stem: stems[i].map { GanZhiText.stems[$0] },
                               branch: branches[i].map { GanZhiText.branches[$0] },
                               god: god)
        }
    }

    /// 关系命中（含 T3，供文字说明筛选）
    var relationHits: [RelationHit] {
        guard stems[4] != nil else { return [] }
        return RelationEngine.compute(stems: stems, branches: branches)
    }
}

// MARK: - 面板视图

struct BaZiBoardView: View {

    @EnvironmentObject var app: AppModel
    let data: BaZiBoardData
    /// 改动 6-E2-6：true 时在面板下方渲染连线区（仅周详情页）
    var showsRelationLines: Bool = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let colWidth: CGFloat = width >= 352 ? 41.5 : max(37, (width - 20) / 8)
            let labelWidth: CGFloat = 20
            let hasChart = !data.columns.isEmpty

            if hasChart {
                VStack(alignment: .leading, spacing: 0) {
                    board(columns: data.columns, colWidth: colWidth, labelWidth: labelWidth)
                    if showsRelationLines {
                        RelationLinesView(hits: data.relationHits,
                                          colWidth: colWidth, labelWidth: labelWidth)
                    }
                }
            } else {
                emptyGuide
            }
        }
        .frame(minHeight: showsRelationLines ? 190 : 108)
    }

    // MARK: 三行面板

    private func board(columns: [BoardColumn], colWidth: CGFloat, labelWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 列标题行
            HStack(spacing: 0) {
                Text("")
                    .frame(width: labelWidth, alignment: .leading)
                ForEach(columns) { col in
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
                    Text(col.stem ?? "—")
                        .font(Theme.ganzhi(23))
                        .foregroundStyle(stemColor(col))
                        .frame(width: colWidth)
                }
            }
            .frame(height: 30)

            // 地支行
            HStack(spacing: 0) {
                rowLabel("地支", width: labelWidth)
                ForEach(columns) { col in
                    Text(col.branch ?? "—")
                        .font(Theme.ganzhi(23))
                        .foregroundStyle(branchColor(col))
                        .frame(width: colWidth)
                }
            }
            .frame(height: 30)
            .padding(.bottom, 9)
        }
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

// MARK: - 连线区（改动 7-D，正交折线）

struct RelationLinesView: View {

    let hits: [RelationHit]
    let colWidth: CGFloat
    let labelWidth: CGFloat

    /// 轨道分配：按跨度升序处理；若某轨道已有横线与当前线 x 区间相距 ≥10pt 可复用，否则新建
    private struct Track { var ranges: [(ClosedRange<CGFloat>)] }

    private func layout() -> (lines: [(RelationHit, CGFloat, CGFloat, CGFloat)], height: CGFloat) {
        let drawable = RelationEngine.drawable(hits)
        var tracks: [Track] = []
        var result: [(RelationHit, CGFloat, CGFloat, CGFloat)] = []   // hit, x1, x2, y

        for hit in drawable {
            let x1 = labelWidth + CGFloat(hit.colA) * colWidth + colWidth / 2
            let x2 = labelWidth + CGFloat(hit.colB) * colWidth + colWidth / 2
            var assigned: Int? = nil
            for (ti, track) in tracks.enumerated() {
                let clear = track.ranges.allSatisfy { range in
                    max(x1, x2) < range.lowerBound - 10 || min(x1, x2) > range.upperBound + 10
                }
                if clear { assigned = ti; break }
            }
            let ti: Int
            if let a = assigned { ti = a } else { tracks.append(Track(ranges: [])); ti = tracks.count - 1 }
            let y = CGFloat(26 + ti * 15)
            tracks[ti].ranges.append(min(x1, x2)...max(x1, x2))
            result.append((hit, x1, x2, y))
        }
        let height = CGFloat((tracks.count + 1) * 15 + 15)
        return (result, height)
    }

    var body: some View {
        let (lines, height) = layout()
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                let top = CGFloat(0)

                // ① 全部竖线（从地支字下方 4pt 起笔，落到各自轨道高度）
                for (_, x1, x2, y) in lines {
                    for x in [x1, x2] {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: top + 4))
                        path.addLine(to: CGPoint(x: x, y: top + y))
                        context.stroke(path, with: .color(.gray.opacity(0.25)), lineWidth: 0.8)
                    }
                }

                // ② 横线白底（宽 3.4pt，两端缩进 2.6pt，让横线穿过竖线处断开）
                for (_, x1, x2, y) in lines {
                    var path = Path()
                    path.move(to: CGPoint(x: min(x1, x2) + 2.6, y: top + y))
                    path.addLine(to: CGPoint(x: max(x1, x2) - 2.6, y: top + y))
                    context.stroke(path, with: .color(.white), lineWidth: 3.4)
                }

                // ③ 横线本体：颜色 = 关系类型；线型 = 命/运（改动 7-D2）
                for (hit, x1, x2, y) in lines {
                    var path = Path()
                    path.move(to: CGPoint(x: min(x1, x2), y: top + y))
                    path.addLine(to: CGPoint(x: max(x1, x2), y: top + y))
                    let rgb = hit.kind.colorRGB
                    let color = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
                    if hit.tier == .t1 {
                        // 本命：实线 1.3pt
                        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.3))
                    } else {
                        // 流运/当日：虚线 5/3，opacity .8
                        context.stroke(path, with: .color(color.opacity(0.8)),
                                       style: StrokeStyle(lineWidth: 1.3, dash: [5, 3]))
                    }
                }
            }
            // ④ 标签：横线中点上方 3.6pt，9.5pt 同线色
            ForEach(lines, id: \.0.id) { (hit, x1, x2, y) in
                let rgb = hit.kind.colorRGB
                Text(hit.kind.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                    .position(x: (x1 + x2) / 2, y: y - 3.6 + 6)   // 视觉居中于横线上方
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 大运条（改动 6-C6 / 改动 7-B3）

struct DayunBarView: View {

    @EnvironmentObject var app: AppModel

    var body: some View {
        let chart = app.birthChart
        let steps = chart.map { DayunCalculator.steps(chart: $0) } ?? []
        let currentIndex = chart.map { DayunCalculator.currentStepIndex(steps: DayunCalculator.steps(chart: $0)) } ?? nil

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 6 步均分（space-between）
                ForEach(steps) { step in
                    let isCurrent = currentIndex.map { steps[$0].id == step.id } ?? false
                    VStack(spacing: 1) {
                        Text(step.pillar.text)
                            .font(Theme.ganzhi(13.5))
                            .foregroundStyle(isCurrent ? Theme.accent : Theme.secondaryText.opacity(0.55))
                        Text(isCurrent ? "当前" : (step.startYear.map { "\($0)" } ?? ""))
                            .font(.system(size: 8))
                            .foregroundStyle(isCurrent ? Theme.accent.opacity(0.7) : Theme.secondaryText.opacity(0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if chart != nil && (chart?.qiyunMonths == nil || chart?.birthYear == nil) {
                Text("填写起运岁数可显示年份与当前大运")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryText.opacity(0.6))
            }
        }
    }
}

// MARK: - 字距辅助

extension Text {
    func letterSpacing(_ value: CGFloat) -> some View {
        kerning(value)
    }
}
