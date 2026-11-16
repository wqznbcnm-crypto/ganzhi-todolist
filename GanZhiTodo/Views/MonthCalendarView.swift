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

    /// 左栏占比（固定）：日期放大到 44pt 后略放宽；两栏宽度仍锁死，不随数字宽度抖动
    private let leftRatio: CGFloat = 0.45
    private let gap: CGFloat = 8
    /// 第一行区块高度：左（年+日期）与右（标签+干支）共用，保证顶/底同时对齐
    /// 改字号后如果顶或底错开 1~3pt，只调这一个数
    private static let blockH: CGFloat = 84

    private static let weekdayEN = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let leftW = floor((total - gap) * leftRatio)
            let rightW = total - gap - leftW
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                let pillars = Self.currentPillars(now: now,
                                                  selected: app.selectedDay,
                                                  lateZi: app.lateZiCountsAsNextDay)
                VStack(alignment: .leading, spacing: 0) {
                    // 第一行：左（xxxx年 + 日期）｜右（年月日时标签 + 四柱大字）
                    // 设计稿红线对齐：年份顶部 = 标签行顶部；日期底部 = 地支行底部（靠同一个 blockH 撑住）
                    HStack(alignment: .top, spacing: gap) {
                        dateColumn(width: leftW).frame(height: Self.blockH, alignment: .topLeading)
                        pillarsBlock(width: rightW, pillars: pillars).frame(height: Self.blockH, alignment: .top)
                    }
                    // 第二行：重要日子与排盘下方的小字共用一行，顶部对齐（v6 第 3 条）
                    HStack(alignment: .top, spacing: gap) {
                        specialRow(width: leftW)
                        smallBlock(width: rightW, now: now, pillars: pillars)
                    }
                }
            }
        }
        .frame(height: 142)
    }

    // MARK: 左上：xxxx年 + 日期（重要日子单独一行，见 specialRow）

    private func dateColumn(width: CGFloat) -> some View {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month, .day, .weekday], from: app.selectedDay)
        let weekday = Self.weekdayEN[((comps.weekday ?? 1) - 1) % 7]
        // 用 String 拼接而不是字符串插值 Int：插值会走 LocalizedStringKey，千位分隔符会把 2026 显示成 2,026
        let yearText = String(comps.year ?? 0)
        // 日历口径补零：1 月 5 日显示 01.05，与 11.14 / 12.28 同宽（Sinhala 数字等宽）
        let dateText = String(format: "%02d.%02d", comps.month ?? 0, comps.day ?? 0)

        return VStack(alignment: .leading, spacing: 0) {
            // 2026 年：数字与日期同一字体（Sinhala）；「年」字用普惠体 Bold
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(yearText)
                    .font(Theme.digit(24))
                    .numericTextRoll()
                Text("年")
                    .font(Theme.puhui(16, bold: true))
            }
            .frame(width: width, alignment: .leading)

            // 顶到 blockH：日期直接落在区块底部，和右边地支行齐平
            Spacer(minLength: 0)

            // 11.14 SAT：字号锁死 44pt、宽度锁死 108pt，不随日期变化缩放
            // 108 = 实测 "88.88"@44pt = 105.3pt + 2.7pt 余量；给 104 会把末两位截成省略号
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(dateText)
                    .font(Theme.digit(44, bold: true))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 108, alignment: .leading)
                    .numericTextRoll()
                Text(weekday)
                    .font(Theme.digit(13))
                    .padding(.bottom, 6)
            }
            .frame(width: width, alignment: .leading)
        }
        // 数字变化时的滚动动画（切月 / 点日期都会触发）
        .animation(.easeInOut(duration: 0.22), value: dateText)
        .animation(.easeInOut(duration: 0.22), value: yearText)
        // 「点标题回当月」保留（设计稿 v4 第 4 条）
        .contentShape(Rectangle())
        .onTapGesture { app.goToToday() }
    }

    // MARK: 右上：即时排盘四柱（年月日跟选中日，时柱取当下时辰）

    private func pillarsBlock(width: CGFloat, pillars: FourPillars) -> some View {
        let four = [pillars.year, pillars.month, pillars.day, pillars.hour]
        let colW = width / 4
        // 与左侧数字同一动画口径：任一字变化就触发
        let key = four.map(\.text).joined()
        return VStack(alignment: .leading, spacing: 0) {
            // 年月日时（Light 小标签）—— 贴区块顶部，与左侧年份同一水平线
            HStack(spacing: 0) {
                ForEach(["年", "月", "日", "时"], id: \.self) { label in
                    Text(label)
                        .font(Theme.puhui(8.5))
                        .foregroundStyle(Theme.secondaryText.opacity(0.85))
                        .frame(width: colW)
                }
            }

            // 中间留白吸收高度差，让干支两行落到底部（与左侧日期底部齐平）
            Spacer(minLength: 0)

            // 天干行 23pt Bold（整体缩到原来的 4/5）
            HStack(spacing: 0) {
                ForEach(Array(four.enumerated()), id: \.offset) { _, pillar in
                    Text(pillar.stem)
                        .font(Theme.puhui(23, bold: true))
                        .foregroundStyle(.primary)
                        .frame(width: colW)
                        .numericTextRoll()
                }
            }

            // 地支行 23pt Bold
            HStack(spacing: 0) {
                ForEach(Array(four.enumerated()), id: \.offset) { _, pillar in
                    Text(pillar.branch)
                        .font(Theme.puhui(23, bold: true))
                        .foregroundStyle(.primary)
                        .frame(width: colW)
                        .numericTextRoll()
                }
            }
        }
        .frame(width: width, alignment: .leading)
        // 与左侧日期数字同一条动画曲线（0.22s easeInOut）：换日期/时辰时干支一起做过渡
        .animation(.easeInOut(duration: 0.22), value: key)
    }

    // MARK: 左下：今天的重要日子（与右侧小字顶部对齐，v6 第 3 条）

    private func specialRow(width: CGFloat) -> some View {
        Group {
            if let special = SpecialDayCN.day(for: app.selectedDay) {
                Text(special.text)
                    .font(Theme.puhui(18, bold: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(.top, 9)
    }

    // MARK: 右下：小字两行（干支年月日 + 时刻时辰）

    private func smallBlock(width: CGFloat, now: Date, pillars: FourPillars) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(pillars.year.text)年 · \(pillars.month.text)月 \(pillars.day.text)日")
                .font(Theme.puhui(9))
                .foregroundStyle(Color(hexString: "#B4B4B4"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .numericTextRoll()
                .animation(.easeInOut(duration: 0.22),
                           value: "\(pillars.year.text)\(pillars.month.text)\(pillars.day.text)")
                .padding(.top, 9)

            Text(timeLine(now, pillars: pillars))
                .font(Theme.puhui(9))
                .foregroundStyle(Color(hexString: "#B4B4B4"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3)
        }
        .frame(width: width, alignment: .leading)
    }

    /// 年月日跟日历里选中的那天走；时柱仍取当下时辰（v5 第 4 条）
    private static func currentPillars(now: Date, selected: Date, lateZi: Bool) -> FourPillars {
        let cal = GanzhiCalendar.calendar
        let hm = cal.dateComponents([.hour, .minute], from: now)
        let base = cal.date(bySettingHour: hm.hour ?? 0,
                            minute: hm.minute ?? 0,
                            second: 0,
                            of: selected) ?? selected
        return GanzhiCalendar.shared.fourPillars(for: base, lateZiCountsAsNextDay: lateZi)
    }
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

    @EnvironmentObject var app: AppModel
    @EnvironmentObject var noteBook: PersonalNoteBook

    let day: Date

    var body: some View {
        let almanac = Almanac.day(for: day)
        let yiji = AlmanacYiJi.day(for: day)
        let hit = noteBook.hit(for: day, lateZi: app.lateZiCountsAsNextDay)

        VStack(alignment: .leading, spacing: 8) {
            if let hit {
                // v7：命中个人命理笔记 → 优先展示用户自定义标签，万年历宜忌原文隐藏
                if !hit.note.yi.isEmpty {
                    row(badgeText: "宜", color: Theme.accent, items: hit.note.yi)
                }
                if !hit.note.ji.isEmpty {
                    row(badgeText: "忌", color: Color(hexString: "#3A3A3A"), items: hit.note.ji)
                }
                Text("个人笔记 · \(hit.scope) \(hit.char) · 万年历内容已隐藏")
                    .font(Theme.puhui(9.5))
                    .foregroundStyle(Color(hexString: "#B3AEA7"))
                    .lineLimit(1)
                    .padding(.leading, 33)
                    .padding(.top, 2)
            } else {
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

    /// 设计稿 v5 第 5 条：把「选中的日期」当作当天显示 —— 红圆底白字跟着选中日走，
    /// 不再固定在真实今天（点哪天，哪天就是红圆）
    private var isSelected: Bool {
        GanzhiCalendar.calendar.isDate(app.selectedDay, inSameDayAs: info.date)
    }

    var body: some View {
        VStack(spacing: 2) {
            // 日期数字：选中日 → 朱砂圆底白字；法定假日 → 朱砂红
            Text("\(info.dayNumber)")
                .font(.system(size: 15.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : numberColor)
                .frame(width: 27, height: 27)
                .background(
                    Circle().fill(isSelected ? Theme.accent : Color.clear)
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
        // 法定放假日：右下角小红点（只在法定放假日标；选中日红圆底时不重复标点）
        .overlay(alignment: .bottomTrailing) {
            if info.holidayType == .holiday && !isSelected {
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
                    // v6 第 4 条：左滑露出删除按钮，确认后删除
                    SwipeToDeleteRow(onDelete: { store.delete(item) }) {
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
                    // 已完成 / 已过期 → 标题划横杠
                    .strikethrough(TodoRowText.isStruck(item), color: Theme.secondaryText.opacity(0.75))
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

// MARK: - 底部两个录入入口（v8：左「事迹记录」· 右「待办记录」，替换原手动记录板块）

struct BottomActionBar: View {

    @EnvironmentObject var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 10) {
                // 左：事迹记录（已经发生的事）
                Button {
                    app.route = .newEvent(anchor: app.selectedDay)
                } label: {
                    card(icon: "bookmark",
                         title: "事迹记录",
                         subtitle: "已经发生的事",
                         filled: false)
                }
                .buttonStyle(.plain)

                // 右：待办记录（未来要做的事）→ 语音录入 + 确认卡片
                Button {
                    app.route = .voice(anchor: app.selectedDay)
                } label: {
                    card(icon: "checklist",
                         title: "待办记录",
                         subtitle: "打算要做的事",
                         filled: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.hPadding)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Color(.systemBackground))
        }
    }

    private func card(icon: String, title: String, subtitle: String, filled: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(filled ? Color.white : Theme.accent)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(filled ? Color.white.opacity(0.18) : Theme.accent.opacity(0.10))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(filled ? Color.white : .primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(filled ? Color.white.opacity(0.75) : Theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(filled ? Theme.accent : Color.primary.opacity(0.04))
        )
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
