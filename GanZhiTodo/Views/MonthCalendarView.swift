//
//  MonthCalendarView.swift
//  首页（改动 7-B + 设计稿改版）：大号年月标题 + 即时排盘‖个人命盘（眼睛开关+大运） + 月历 + 最近待办 + 底部录入栏
//  改动 4：月份切换为上下方向（右上两枚纵向按钮 + 日历垂直拖动）
//  改动 5：节气名（朱砂小字）/ 法定假日（红数字+右下红点）/ 调休上班日（右上「班」角标）
//  设计稿改版：① 大字年月两行标题 ② 即时排盘/个人命盘双栏 + 眼睛显示隐藏命盘与大运
//              ③ 月历上移、字号放大 ④ 今日红圆底白字
//  硬规则：首页不得出现任何刑冲合害连线或关系文字。
//

import SwiftUI

// MARK: - 单元格数据

struct DayInfo: Identifiable {
    let id: String
    let date: Date
    let isPlaceholder: Bool
    let dayNumber: Int
    let dayPillar: Pillar
    let termName: String?
    let hasPending: Bool
    let holidayType: HolidayType?   // 改动 5：法定假日 / 调休上班日
    let festivalName: String?

    static func placeholder(_ index: Int) -> DayInfo {
        DayInfo(id: "p-\(index)", date: .distantPast, isPlaceholder: true, dayNumber: 0,
                dayPillar: Pillar(sexagenaryIndex: 0), termName: nil, hasPending: false,
                holidayType: nil, festivalName: nil)
    }
}

// MARK: - 主视图

struct MonthCalendarView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel

    private var monthComps: DateComponents {
        GanzhiCalendar.calendar.dateComponents([.year, .month], from: app.visibleMonth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MonthHeaderView()
                    .padding(.top, 8)

                // 设计稿改版 ②：即时排盘 ‖ 个人命盘（眼睛开关）+ 大运
                HomeBoardView()
                    .padding(.top, 12)

                // 改动 7-B4 + 改动 4：月历网格（垂直拖动切月；设计稿改版 ③ 上移+放大）
                WeekdayHeader()
                    .padding(.top, 12)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                          spacing: 6) {
                    ForEach(weeks.flatMap { $0 }) { info in
                        if info.isPlaceholder {
                            Color.clear.frame(height: 42)
                        } else {
                            NavigationLink(value: info.date) {
                                DayCellView(info: info)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { app.select(info.date) })
                        }
                    }
                }
                .padding(.top, 4)
                .gesture(monthDragGesture)

                // 改动 7-B5：最近待办
                RecentTodosView()
                    .padding(.top, 12)
            }
            .padding(.horizontal, Theme.hPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) { BottomActionBar() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.route = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: 改动 4-2：垂直拖动切换月份（上滑=下一月，下滑=上一月）

    private var monthDragGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.height < -30 {
                    app.moveMonth(by: 1)
                } else if value.translation.height > 30 {
                    app.moveMonth(by: -1)
                }
            }
    }

    // MARK: 生成网格

    private var weeks: [[DayInfo]] {
        let cal = GanzhiCalendar.calendar
        let first = cal.date(from: DateComponents(year: monthComps.year, month: monthComps.month, day: 1))!
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = (cal.component(.weekday, from: first) + 5) % 7   // 周一=0

        var pending: Set<Int> = []
        for item in store.items(inMonthOf: app.visibleMonth) where !item.isDone {
            pending.insert(cal.component(.day, from: item.calendarDay))
        }

        var cells: [DayInfo] = []
        for i in 0..<leading { cells.append(.placeholder(i)) }
        for d in 1...daysInMonth {
            guard let date = cal.date(from: DateComponents(year: monthComps.year, month: monthComps.month, day: d)) else { continue }
            let pillar = GanzhiCalendar.shared.dayPillar(for: date)
            let term = GanzhiCalendar.shared.solarTermName(on: date)
            let holiday = HolidayCN.info(for: date)
            cells.append(DayInfo(id: "\(monthComps.year ?? 0)-\(monthComps.month ?? 0)-\(d)",
                                 date: date, isPlaceholder: false, dayNumber: d,
                                 dayPillar: pillar, termName: term,
                                 hasPending: pending.contains(d),
                                 holidayType: holiday?.type,
                                 festivalName: holiday?.name))
        }
        while cells.count % 7 != 0 {
            cells.append(.placeholder(cells.count))
        }

        var result: [[DayInfo]] = []
        var index = 0
        while index < cells.count {
            result.append(Array(cells[index..<min(index + 7, cells.count)]))
            index += 7
        }
        return result
    }
}

// MARK: - 月标题（改动 7-B1 + 改动 4 + 设计稿改版 ①：大字两行年月）

struct MonthHeaderView: View {

    @EnvironmentObject var app: AppModel

    private var headerPillars: (year: Pillar, month: Pillar) {
        let comps = GanzhiCalendar.calendar.dateComponents([.year, .month], from: app.visibleMonth)
        return GanzhiCalendar.shared.monthHeaderPillars(year: comps.year ?? 2026, month: comps.month ?? 1)
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                // 年：中号
                Text("\(yearInt) 年")
                    .font(.system(size: 21, weight: .semibold))
                    .letterSpacingCompat(0.5)
                // 月：特大号粗体
                Text("\(monthInt)月")
                    .font(.system(size: 44, weight: .bold))
                    .letterSpacingCompat(0.5)
                    .padding(.top, 2)
                // 干支行
                Text("\(headerPillars.year.text)年 · \(headerPillars.month.text)月")
                    .font(Theme.ganzhi(13))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 8)
                // 分钟级刷新只更新这一行文字（性能红线：不触发面板重算）
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    nowLine(context.date)
                }
                .padding(.top, 3)
            }
            Spacer()
            // 改动 4：两枚纵向圆形按钮，上=上一月、下=下一月
            VStack(spacing: 6) {
                Button { app.moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hexString: "#9B9B9B"))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.primary.opacity(0.035)))
                }
                .buttonStyle(.plain)
                Button { app.moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hexString: "#9B9B9B"))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.primary.opacity(0.035)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var yearInt: Int {
        GanzhiCalendar.calendar.component(.year, from: app.visibleMonth)
    }
    private var monthInt: Int {
        GanzhiCalendar.calendar.component(.month, from: app.visibleMonth)
    }

    private func nowLine(_ date: Date) -> some View {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let pillars = GanzhiCalendar.shared.fourPillars(for: date, lateZiCountsAsNextDay: true)
        let hourBranch = ((comps.hour ?? 0) + 1) / 2 % 12
        return Text(String(format: "%02d:%02d · %@ %@", comps.hour ?? 0, comps.minute ?? 0,
                           pillars.hour.shichenName, GanZhiText.shichenRange[hourBranch]))
            .font(.system(size: 12))
            .foregroundStyle(Color(hexString: "#B4B4B4"))
    }
}

// MARK: - 首页排盘区（设计稿改版 ②：即时排盘 ‖ 个人命盘，眼睛开关命盘+大运）

/// 双栏面板的一列数据
struct HomeBoardColumn: Identifiable {
    let id: Int
    let title: String
    let titleAccent: Bool        // 「日柱」朱砂
    let stemIndex: Int?
    let branchIndex: Int?
}

struct HomeBoardView: View {

    @EnvironmentObject var app: AppModel
    /// 眼睛开关：true = 显示个人命盘与大运（记忆到 UserDefaults）
    @AppStorage("homeChartVisible") private var chartVisible = true

    /// 即时排盘：当前时刻的 年柱(流年)/月柱(流月)/日柱(流日)/时柱(流时)
    private var flowColumns: [HomeBoardColumn] {
        let p = GanzhiCalendar.shared.fourPillars(for: Date(), lateZiCountsAsNextDay: app.lateZiCountsAsNextDay)
        let items: [(String, Pillar)] = [("年柱", p.year), ("月柱", p.month), ("日柱", p.day), ("时柱", p.hour)]
        return items.enumerated().map { i, pair in
            HomeBoardColumn(id: i, title: pair.0, titleAccent: pair.0 == "日柱",
                            stemIndex: pair.1.stemIndex, branchIndex: pair.1.branchIndex)
        }
    }

    /// 个人命盘：本命四柱（时柱可选）
    private var chartColumns: [HomeBoardColumn] {
        guard let chart = app.birthChart else { return [] }
        let items: [(String, Pillar?)] = [("年柱", chart.yearPillar), ("月柱", chart.monthPillar),
                                          ("日柱", chart.dayPillar), ("时柱", chart.hourPillar)]
        return items.enumerated().map { i, pair in
            HomeBoardColumn(id: i, title: pair.0, titleAccent: pair.0 == "日柱",
                            stemIndex: pair.1?.stemIndex, branchIndex: pair.1?.branchIndex)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // 左：即时排盘
                VStack(spacing: 0) {
                    sectionTitle("即时排盘")
                    boardBody(flowColumns)
                }
                .frame(maxWidth: .infinity)

                // 右：个人命盘 + 眼睛
                VStack(spacing: 0) {
                    sectionTitleWithEye("个人命盘")
                    if !chartVisible {
                        hiddenPlaceholder
                    } else if app.birthChart == nil {
                        noChartGuide
                    } else {
                        boardBody(chartColumns)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // 大运：仅当眼睛睁开且有命盘时显示
            if chartVisible, app.birthChart != nil {
                DayunBarView()
                    .padding(.top, 10)
            }
        }
    }

    // MARK: 区块标题（左：无眼睛；右：带眼睛开关）

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(hexString: "#5C5852"))
            .frame(height: 20, alignment: .bottom)
            .frame(maxWidth: .infinity)
    }

    private func sectionTitleWithEye(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hexString: "#5C5852"))
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { chartVisible.toggle() }
            } label: {
                Image(systemName: chartVisible ? "eye" : "eye.slash")
                    .font(.system(size: 12.5))
                    .foregroundStyle(chartVisible ? Theme.accent : Color(hexString: "#9B9B9B"))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 20, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }

    // MARK: 四柱面板（列标题 / 天干 / 地支，五行着色）

    private func boardBody(_ columns: [HomeBoardColumn]) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(columns) { col in
                    Text(col.title)
                        .font(.system(size: 9))
                        .foregroundStyle(col.titleAccent ? Theme.accent : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 0) {
                ForEach(columns) { col in
                    Text(col.stemIndex.map { GanZhiText.stems[$0] } ?? "—")
                        .font(Theme.ganzhi(20))
                        .foregroundStyle(elementColor(col.stemIndex, isStem: true))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 25)
            HStack(spacing: 0) {
                ForEach(columns) { col in
                    Text(col.branchIndex.map { GanZhiText.branches[$0] } ?? "—")
                        .font(Theme.ganzhi(20))
                        .foregroundStyle(elementColor(col.branchIndex, isStem: false))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 25)
        }
        .padding(.top, 7)
    }

    private func elementColor(_ index: Int?, isStem: Bool) -> Color {
        guard let index else { return Theme.secondaryText.opacity(0.4) }
        return Theme.element(isStem ? WuXing.ofStem(index) : WuXing.ofBranch(index))
    }

    // MARK: 眼睛关闭时的占位（与面板同高，布局不跳动）

    private var hiddenPlaceholder: some View {
        Text("八字已隐藏")
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryText.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: 85, alignment: .center)
    }

    // MARK: 未录入八字引导

    private var noChartGuide: some View {
        VStack(spacing: 7) {
            Text("未录入八字")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText.opacity(0.7))
            NavigationLink {
                BirthChartEditorView()
            } label: {
                Text("去录入 ›")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 85, alignment: .center)
    }
}

// MARK: - 星期表头（改动 7-B4-1）

struct WeekdayHeader: View {
    private let labels = ["一", "二", "三", "四", "五", "六", "日"]
    var body: some View {
        HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 日期单元格（改动 7-B4 + 改动 5 + 设计稿改版 ③④：放大、今日红圆底白字）

struct DayCellView: View {

    @EnvironmentObject var app: AppModel
    let info: DayInfo

    private var isToday: Bool {
        GanzhiCalendar.calendar.isDate(info.date, inSameDayAs: Date())
    }

    var body: some View {
        VStack(spacing: 2) {
            // 日期数字：今日 → 朱砂圆底白字（设计稿改版 ④）；法定假日 → 朱砂红
            Text("\(info.dayNumber)")
                .font(.system(size: 15.5, weight: isToday ? .semibold : .medium))
                .foregroundStyle(isToday ? Color.white : numberColor)
                .frame(width: 27, height: 27)
                .background(
                    Circle().fill(isToday ? Theme.accent : Color.clear)
                )
            // 下方小字：节气日显示节气名（朱砂），否则日柱
            if let term = info.termName {
                Text(term)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            } else {
                Text(info.dayPillar.text)
                    .font(Theme.ganzhi(9))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .contentShape(Rectangle())
        // 有待办：右上 3pt 圆点（距右 12、距顶 6）
        .overlay(alignment: .topTrailing) {
            if info.hasPending {
                Circle()
                    .fill(Color(hexString: "#CFCBC4"))
                    .frame(width: 3, height: 3)
                    .padding(.top, 5)
                    .padding(.trailing, 12)
            }
        }
        // 调休上班日：右上角「班」角标（灰描边小圆 + 6.5pt 字）
        .overlay(alignment: .topTrailing) {
            if info.holidayType == .workday {
                Text("班")
                    .font(.system(size: 6.5))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Theme.secondaryText.opacity(0.5), lineWidth: 0.6))
                    .padding(.top, 0)
                    .padding(.trailing, 1)
            }
        }
        // 法定放假日：右下角小红点（与右上待办圆点分居两侧，不重叠；今日红圆底时不重复标点）
        .overlay(alignment: .bottomTrailing) {
            if info.holidayType == .holiday && !isToday {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 3, height: 3)
                    .padding(.bottom, 2)
                    .padding(.trailing, 12)
            }
        }
    }

    private var numberColor: Color {
        if info.holidayType == .holiday { return Theme.accent }   // 法定假日 → 朱砂红
        return .primary
    }
}

// MARK: - 最近待办（改动 7-B5）

struct RecentTodosView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel

    /// 取数规则：从今天起未来若干条 + 今天之前未完成的过期项，共 4–6 条，按日期升序
    private var recentItems: [TodoItem] {
        let cal = GanzhiCalendar.calendar
        let today = Date().startOfBeijingDay
        let upcoming = store.items.filter { !$0.isDone && $0.calendarDay >= today }
        let overdue = store.items.filter { !$0.isDone && $0.calendarDay < today }
        var result = Array(upcoming.prefix(5))
        if result.count < 4 {
            result.append(contentsOf: overdue.prefix(4 - result.count))
        } else if result.count < 6, !overdue.isEmpty {
            result.append(overdue[0])
        }
        return result.sorted { $0.calendarDay < $1.calendarDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline) {
                Text("最近待办")
                    .font(.system(size: 11, weight: .semibold))
                    .letterSpacingCompat(0.6)
                    .foregroundStyle(Color(hexString: "#8B867E"))
                Spacer()
                Text("\(recentItems.count) 项")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText.opacity(0.6))
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            if recentItems.isEmpty {
                Text("暂无待办，点底部「语音录入」说一句吧")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentItems) { item in
                    Button {
                        app.route = .editTodo(item)   // 点击 → 直接打开编辑页
                    } label: {
                        recentRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func recentRow(_ item: TodoItem) -> some View {
        HStack(spacing: 9) {
            // 左：完成状态圆圈
            Circle()
                .fill(item.isDone ? Theme.accent : Color.clear)
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(item.isDone ? Theme.accent : Color(hexString: "#D6D2CB"), lineWidth: 1.2))
            // 中：标题 + 次行「13日 · 辛卯」
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(item.isDone ? Theme.secondaryText : .primary)
                    .lineLimit(1)
                Text("\(dayText(item)) · \(GanzhiCalendar.shared.dayPillar(for: item.calendarDay).text)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hexString: "#B3AEA7"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 右：时间（等宽数字）
            Text(item.timeText == "全天" ? "" : item.timeText)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Color(hexString: "#B3AEA7"))
        }
        .padding(.vertical, 4.5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 1)
        }
    }

    private func dayText(_ item: TodoItem) -> String {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.month, .day], from: item.calendarDay)
        return "\(comps.day ?? 0)日"
    }
}

// MARK: - 底部操作栏（改动 7-B6：常驻固定，46/23，朱砂语音按钮）

struct BottomActionBar: View {

    @EnvironmentObject var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 10) {
                Button {
                    // 键盘录入：日期默认取当前选中日期
                    app.route = .newTodo(app.selectedDay)
                } label: {
                    Label("键盘录入", systemImage: "square.and.pencil")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color(hexString: "#3A3A3A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)

                Button {
                    // 改动 9：首页底部语音入口 anchor = 当前选中日期
                    app.route = .voice(anchor: app.selectedDay)
                } label: {
                    Label("语音录入", systemImage: "waveform")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(Theme.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.hPadding)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - 颜色/字距小工具

extension Color {
    /// "#RRGGBB" → Color（预览稿里的固定灰阶）
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r, g, b: Double
        if hex.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension Text {
    func letterSpacingCompat(_ value: CGFloat) -> some View {
        kerning(value)
    }
}
