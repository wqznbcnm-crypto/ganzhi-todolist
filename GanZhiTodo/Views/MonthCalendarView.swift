//
//  MonthCalendarView.swift
//  首页（设计稿 v4）
//    ① 大标题：2026 年 / 11.14 SAT（Sinhala Sangam MN 数字）+ 当天重要日子（Alibaba PuHuiTi Bold）
//    ② 右侧即时排盘：年月日时小标签（Light）+ 四柱干支 29pt（Bold）+ 两行小字（干支年月日 / 当前时刻）
//    ③ 宜忌位改为历法原始数据：十二建除 / 二十八宿值日 / 日干支冲煞 / 神煞（不做吉凶结论）
//    ④ 月历：单击日期 → 下方切「当天待办」；双击日期 → 进周页
//    ⑤ 待办区：默认「最近待办」，可一键切回
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

    // 改动 4（新版）：纯手势切月 —— 跟手位移 / 防连击 / 淡入过渡
    @State private var monthDragOffset: CGFloat = 0
    @State private var monthFadeOffset: CGFloat = 0
    @State private var monthOpacity: Double = 1
    @State private var isSwitchingMonth = false

    private var monthComps: DateComponents {
        GanzhiCalendar.calendar.dateComponents([.year, .month], from: app.visibleMonth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 设计稿 v4 ①②：左日期块 ‖ 右即时排盘（两栏宽度锁死）
                HomeTopView()
                    .padding(.top, 8)

                // 设计稿 v4 ③：原「宜/忌」位置 → 历法原始数据
                AlmanacStripView(day: app.selectedDay)

                // 改动 7-B4 + 改动 4（新版）：月历网格，上滑=下一月、下滑=上一月
                WeekdayHeader()
                    .padding(.top, 22)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                          spacing: 6) {
                    ForEach(weeks.flatMap { $0 }) { info in
                        if info.isPlaceholder {
                            Color.clear.frame(height: 42)
                        } else {
                            dayCell(info)
                        }
                    }
                }
                .padding(.top, 4)
                .opacity(monthOpacity)
                .offset(y: monthDragOffset + monthFadeOffset)
                // 必须用高优先级：外层 ScrollView 会先吃掉竖直拖动
                .highPriorityGesture(monthSwipe)

                // 设计稿 v4 ⑤：最近待办 / 当天待办
                TodoListView()
                    .padding(.top, 16)
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

    /// 日期格：单击 = 看当天待办，双击 = 进周页
    private func dayCell(_ info: DayInfo) -> some View {
        DayCellView(info: info)
            .contentShape(Rectangle())
            .gesture(
                ExclusiveGesture(TapGesture(count: 2), TapGesture(count: 1))
                    .onEnded { value in
                        switch value {
                        case .first:
                            app.pushedDay = info.date.startOfBeijingDay
                        case .second:
                            app.selectForDayList(info.date)
                        }
                    }
            )
    }

    // MARK: 改动 4（新版）：垂直拖动手势（上滑=下一月，下滑=上一月）

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // 只接竖直方向；横向划动不参与，避免劫持
                guard abs(value.translation.height) > abs(value.translation.width) * 1.2 else { return }
                monthDragOffset = max(-26, min(26, value.translation.height * 0.35))
            }
            .onEnded { value in
                let dy = value.translation.height
                let dx = value.translation.width
                guard !isSwitchingMonth else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { monthDragOffset = 0 }
                    return
                }
                guard abs(dy) > abs(dx) * 1.2, abs(dy) > 40 else {
                    // 未达阈值：回弹，月份不变
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { monthDragOffset = 0 }
                    return
                }
                switchMonth(by: dy < 0 ? 1 : -1)   // 上滑 → 下一月
            }
    }

    /// 切月：换月 → 校正选中日 → 待办区回到「最近待办」→ 0.2s 淡入
    private func switchMonth(by offset: Int) {
        isSwitchingMonth = true
        monthDragOffset = 0
        app.moveMonth(by: offset)
        // 设计稿 v4：切月后待办区自动回到「最近待办」
        app.showRecentTodos()

        // 选中日若不在新月份，置为新月 1 日（避免随后推进别的月的周）
        let cal = GanzhiCalendar.calendar
        if !cal.isDate(app.selectedDay, equalTo: app.visibleMonth, toGranularity: .month),
           let first = cal.date(from: cal.dateComponents([.year, .month], from: app.visibleMonth)) {
            app.select(first)
        }

        monthFadeOffset = offset > 0 ? 10 : -10
        monthOpacity = 0
        // 先让「归零」这一帧落地，再淡入，否则两次状态更新会被合并成一帧、看不到过渡
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                monthOpacity = 1
                monthFadeOffset = 0
            }
        }
        // 防连击：0.25s 内忽略新手势
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isSwitchingMonth = false
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

// MARK: - 首页上半部：左日期块 ‖ 右即时排盘（设计稿 v4 ①②）

struct HomeTopView: View {

    @EnvironmentObject var app: AppModel

    /// 左栏占比（固定）：两栏宽度锁死，不随数字字体宽度变化而抖动
    /// 「12.28 SAT」在 71pt Sinhala 下实测约 209.5pt，0.62 × 345 ≈ 213pt，刚好放得下
    private let leftRatio: CGFloat = 0.62
    private let gap: CGFloat = 8

    private static let weekdayEN = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let leftW = floor((total - gap) * leftRatio)
            let rightW = total - gap - leftW
            HStack(alignment: .top, spacing: gap) {
                dateColumn(width: leftW)
                flowColumn(width: rightW)
            }
        }
        .frame(height: 160)
    }

    // MARK: 左：日期 + 重要日子

    private func dateColumn(width: CGFloat) -> some View {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month, .day, .weekday], from: app.selectedDay)
        let weekday = Self.weekdayEN[((comps.weekday ?? 1) - 1) % 7]
        let special = SpecialDayCN.day(for: app.selectedDay)

        return VStack(alignment: .leading, spacing: 0) {
            // 2026 年（数字用 Sinhala，汉字用普惠体——Sinhala 字体没有汉字字形）
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(comps.year ?? 0)")
                    .font(Theme.digit(34))
                Text("年")
                    .font(Theme.puhui(19))
            }
            .frame(width: width, alignment: .leading)

            // 11.14 SAT
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(comps.month ?? 0).\(comps.day ?? 0)")
                    .font(Theme.digit(71, bold: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(weekday)
                    .font(Theme.digit(19))
                    .padding(.bottom, 9)
            }
            .frame(width: width, alignment: .leading)
            .padding(.top, -2)

            // 今天的重要日子（法定节假日首日 / 节气 / 纪念日）
            if let special {
                Text(special.text)
                    .font(Theme.puhui(17, bold: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: width, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        // 「点标题回当月」保留（设计稿 v4 第 4 条）
        .contentShape(Rectangle())
        .onTapGesture { app.goToToday() }
    }

    // MARK: 右：即时排盘（此刻的年月日时四柱）

    private func flowColumn(width: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let pillars = GanzhiCalendar.shared.fourPillars(for: context.date,
                                                            lateZiCountsAsNextDay: app.lateZiCountsAsNextDay)
            let four = [pillars.year, pillars.month, pillars.day, pillars.hour]
            let colW = width / 4
            VStack(alignment: .leading, spacing: 0) {
                // 年月日时（Light 小标签）
                HStack(spacing: 0) {
                    ForEach(["年", "月", "日", "时"], id: \.self) { label in
                        Text(label)
                            .font(Theme.puhui(9.5))
                            .foregroundStyle(Theme.secondaryText.opacity(0.85))
                            .frame(width: colW)
                    }
                }

                // 天干行 29pt Bold
                HStack(spacing: 0) {
                    ForEach(Array(four.enumerated()), id: \.offset) { _, pillar in
                        Text(pillar.stem)
                            .font(Theme.puhui(29, bold: true))
                            .foregroundStyle(.primary)
                            .frame(width: colW)
                    }
                }
                .padding(.top, 2)

                // 地支行 29pt Bold
                HStack(spacing: 0) {
                    ForEach(Array(four.enumerated()), id: \.offset) { _, pillar in
                        Text(pillar.branch)
                            .font(Theme.puhui(29, bold: true))
                            .foregroundStyle(.primary)
                            .frame(width: colW)
                    }
                }

                // 小字：干支年月日
                Text("\(pillars.year.text)年 · \(pillars.month.text)月 \(pillars.day.text)日")
                    .font(Theme.puhui(9))
                    .foregroundStyle(Color(hexString: "#B4B4B4"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 7)

                // 小字：当前时刻与时辰
                Text(timeLine(context.date, pillars: pillars))
                    .font(Theme.puhui(9))
                    .foregroundStyle(Color(hexString: "#B4B4B4"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 3)
            }
        }
    }

    private func pillarArray(_ p: FourPillars) -> [Pillar] { [p.year, p.month, p.day, p.hour] }

    private func timeLine(_ date: Date, pillars: FourPillars) -> String {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let hourBranch = ((comps.hour ?? 0) + 1) / 2 % 12
        return String(format: "%02d:%02d · %@ %@", comps.hour ?? 0, comps.minute ?? 0,
                      pillars.hour.shichenName, GanZhiText.shichenRange[hourBranch])
    }
}

// MARK: - 历法原始数据（设计稿 v4 ③：原「宜/忌」位置）

struct AlmanacStripView: View {

    let day: Date

    var body: some View {
        let almanac = Almanac.day(for: day)
        let yiji = AlmanacYiJi.day(for: day)
        VStack(alignment: .leading, spacing: 8) {
            // 宜 / 忌：直接展示万年历当天的原事项，不做任何推算
            row(badgeText: "宜", color: Theme.accent, items: yiji?.yi)
            row(badgeText: "忌", color: Color(hexString: "#3A3A3A"), items: yiji?.ji)

            // 历法原始字段（建除 / 值宿 / 冲煞 / 神煞），小灰字一行
            Text(rawLine(almanac))
                .font(Theme.puhui(9.5))
                .foregroundStyle(Color(hexString: "#B3AEA7"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.leading, 33)
                .padding(.top, 2)
        }
        .padding(.top, 16)
    }

    private func row(badgeText: String, color: Color, items: [String]?) -> some View {
        HStack(alignment: .center, spacing: 9) {
            badge(badgeText, color: color)
            Text(listText(items))
                .font(Theme.puhui(12.5))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// 最多取 6 项，多了加「等」
    private func listText(_ items: [String]?) -> String {
        guard let items, !items.isEmpty else { return "—" }
        let shown = Array(items.prefix(6))
        let text = shown.joined(separator: "，")
        return items.count > shown.count ? text + "等" : text
    }

    private func rawLine(_ a: AlmanacDay) -> String {
        "建除 \(a.jianchu)日 · \(a.xiu)宿\(a.xiuElement) · \(a.chongshaText) · 神煞 \(a.shenshaText)"
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.puhui(11, bold: true))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(color))
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
        // 有待办：右上 3.5pt 墨灰圆点（设计稿 v4：与假日红点做颜色区分）
        .overlay(alignment: .topTrailing) {
            if info.hasPending {
                Circle()
                    .fill(Color(hexString: "#8B867E"))
                    .frame(width: 3.5, height: 3.5)
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
        // 法定放假日：右下角小红点（设计稿 v4：只在法定放假日标；今日红圆底时不重复标点）
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

// MARK: - 待办区（设计稿 v4 ⑤：最近待办 ⇄ 当天待办）

struct TodoListView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel

    private var dayDate: Date? {
        if case .day(let d) = app.todoScope { return d }
        return nil
    }

    /// 取数规则（最近待办）：从今天起未来若干条 + 今天之前未完成的过期项，共 4–6 条，按日期升序
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

    /// 当天待办：该日全部待办（含已完成），按时间升序
    private var dayItems: [TodoItem] {
        guard let day = dayDate else { return [] }
        let cal = GanzhiCalendar.calendar
        return store.items
            .filter { cal.isDate($0.calendarDay, inSameDayAs: day) }
            .sorted { ($0.dueDate ?? $0.calendarDay) < ($1.dueDate ?? $1.calendarDay) }
    }

    private var items: [TodoItem] { dayDate == nil ? recentItems : dayItems }

    private var title: String { dayDate == nil ? "最近待办" : "当天待办" }

    private var dayTitle: String? {
        guard let day = dayDate else { return nil }
        let c = GanzhiCalendar.calendar.dateComponents([.month, .day, .weekday], from: day)
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return "\(c.month ?? 0)月\(c.day ?? 0)日 \(weekdays[((c.weekday ?? 1) - 1) % 7])"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .letterSpacingCompat(0.6)
                    .foregroundStyle(Color(hexString: "#8B867E"))
                if let dayTitle {
                    Text(dayTitle)
                        .font(Theme.puhui(9.5))
                        .foregroundStyle(Color(hexString: "#B3AEA7"))
                }
                Spacer()
                if dayDate != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { app.showRecentTodos() }
                    } label: {
                        Text("最近待办 ›")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Text("\(items.count) 项")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText.opacity(0.6))
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            if items.isEmpty {
                Text(dayDate == nil ? "暂无待办，点底部「语音录入」说一句吧" : "这一天还没有待办")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    Button {
                        app.route = .editTodo(item)   // 点击 → 直接打开编辑页
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ item: TodoItem) -> some View {
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
                    .strikethrough(item.isDone, color: Theme.secondaryText.opacity(0.6))
                    .lineLimit(1)
                Text("\(dayText(item)) · \(GanzhiCalendar.shared.dayPillar(for: item.calendarDay).text)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hexString: "#B3AEA7"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 右：节日名 + 时间（如「中秋-全天」），等宽数字
            Text(TodoRowText.sideLabel(item))
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
