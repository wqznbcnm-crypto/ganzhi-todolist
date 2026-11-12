//
//  MonthCalendarView.swift
//  主界面：万年历月视图 + 四柱条 + 当日待办摘要
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
    let pendingCount: Int

    static func placeholder(_ index: Int) -> DayInfo {
        DayInfo(id: "p-\(index)", date: .distantPast, isPlaceholder: true, dayNumber: 0,
                dayPillar: Pillar(sexagenaryIndex: 0), termName: nil, pendingCount: 0)
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
            VStack(spacing: 0) {
                MonthHeaderView()
                    .padding(.top, 8)

                PillarBarView()
                    .padding(.top, 20)

                WeekdayHeader()
                    .padding(.top, 22)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                    ForEach(weeks.flatMap { $0 }) { info in
                        if info.isPlaceholder {
                            Color.clear.frame(height: 58)
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

                TodaySummaryView(day: app.selectedDay)
                    .padding(.top, 24)
            }
            .padding(.horizontal, Theme.hPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
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

    // MARK: 生成六周网格

    private var weeks: [[DayInfo]] {
        let cal = GanzhiCalendar.calendar
        let first = cal.date(from: DateComponents(year: monthComps.year, month: monthComps.month, day: 1))!
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = (cal.component(.weekday, from: first) + 5) % 7   // 周一=0

        // 当月每天未完成待办数
        var counts: [Int: Int] = [:]
        for item in store.items(inMonthOf: app.visibleMonth) where !item.isDone {
            let d = cal.component(.day, from: item.calendarDay)
            counts[d, default: 0] += 1
        }

        var cells: [DayInfo] = []
        for i in 0..<leading { cells.append(.placeholder(i)) }
        for d in 1...daysInMonth {
            guard let date = cal.date(from: DateComponents(year: monthComps.year, month: monthComps.month, day: d)) else { continue }
            let pillar = GanzhiCalendar.shared.dayPillar(for: date)
            let term = GanzhiCalendar.shared.solarTermName(on: date)
            cells.append(DayInfo(id: "\(monthComps.year ?? 0)-\(monthComps.month ?? 0)-\(d)",
                                 date: date, isPlaceholder: false, dayNumber: d,
                                 dayPillar: pillar, termName: term,
                                 pendingCount: counts[d] ?? 0))
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

// MARK: - 月标题

struct MonthHeaderView: View {

    @EnvironmentObject var app: AppModel

    private var headerPillars: (year: Pillar, month: Pillar) {
        let comps = GanzhiCalendar.calendar.dateComponents([.year, .month], from: app.visibleMonth)
        return GanzhiCalendar.shared.monthHeaderPillars(year: comps.year ?? 2026, month: comps.month ?? 1)
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    if isCurrentMonth {
                        Text("今天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accent))
                    }
                }
                Text("\(headerPillars.year.text)年 · \(headerPillars.month.text)月")
                    .font(Theme.ganzhi(13))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            HStack(spacing: 4) {
                Button { app.moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.softFill))
                }
                Button { app.moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.softFill))
                }
            }
        }
    }

    private var titleText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.year, .month], from: app.visibleMonth)
        return "\(comps.year ?? 0)年\(comps.month ?? 1)月"
    }

    private var isCurrentMonth: Bool {
        GanzhiCalendar.calendar.isDate(app.visibleMonth, equalTo: Date(), toGranularity: .month)
    }
}

// MARK: - 四柱条

struct PillarBarView: View {

    @EnvironmentObject var app: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let pillars = GanzhiCalendar.shared.fourPillars(for: now, lateZiCountsAsNextDay: app.lateZiCountsAsNextDay)
            let cal = GanzhiCalendar.calendar
            let comps = cal.dateComponents([.hour, .minute], from: now)
            let hourBranch = ((comps.hour ?? 0) + 1) / 2 % 12

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    PillarItem(label: "年", pillar: pillars.year)
                    Text("·").font(.system(size: 12)).foregroundStyle(Theme.secondaryText.opacity(0.4))
                    PillarItem(label: "月", pillar: pillars.month)
                    Text("·").font(.system(size: 12)).foregroundStyle(Theme.secondaryText.opacity(0.4))
                    PillarItem(label: "日", pillar: pillars.day)
                    Text("·").font(.system(size: 12)).foregroundStyle(Theme.secondaryText.opacity(0.4))
                    PillarItem(label: "时", pillar: pillars.hour)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text("\(pillars.hour.shichenName) \(GanZhiText.shichenRange[hourBranch])")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                ShichenScale(current: hourBranch)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.softFill))
        }
    }
}

/// 单柱展示：小标签 + 干支
struct PillarItem: View {
    let label: String
    let pillar: Pillar
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.secondaryText)
            Text(pillar.text).font(Theme.ganzhi(16)).foregroundStyle(.primary)
        }
    }
}

/// 十二时辰刻度：实时标出当前时辰
struct ShichenScale: View {
    let current: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { i in
                VStack(spacing: 3) {
                    Capsule()
                        .fill(i == current ? Color.primary : Theme.hairline)
                        .frame(height: i == current ? 4 : 3)
                    Text(GanZhiText.branches[i])
                        .font(.system(size: 8, weight: i == current ? .semibold : .regular))
                        .foregroundStyle(i == current ? .primary : Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 星期表头

struct WeekdayHeader: View {
    private let labels = ["一", "二", "三", "四", "五", "六", "日"]
    var body: some View {
        HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(index >= 5 ? Theme.secondaryText : Theme.secondaryText.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 日期单元格

struct DayCellView: View {

    @EnvironmentObject var app: AppModel
    let info: DayInfo

    private var isToday: Bool {
        GanzhiCalendar.calendar.isDate(info.date, inSameDayAs: Date())
    }

    private var isSelected: Bool {
        GanzhiCalendar.calendar.isDate(info.date, inSameDayAs: app.selectedDay)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(info.dayNumber)")
                .font(.system(size: 17, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isToday ? Color.primary : Color.clear)
                )
                .overlay(
                    Circle().stroke(isSelected && !isToday ? Color.primary.opacity(0.35) : .clear, lineWidth: 1.5)
                )

            if let term = info.termName {
                Text(term)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
            } else {
                Text(info.dayPillar.text)
                    .font(Theme.ganzhi(8.5))
                    .foregroundStyle(Theme.secondaryText)
            }

            if info.pendingCount > 0 {
                HStack(spacing: 2.5) {
                    ForEach(0..<min(info.pendingCount, 3), id: \.self) { _ in
                        Circle().fill(Theme.accent).frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 5)
            } else {
                Color.clear.frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}

// MARK: - 当日待办摘要

struct TodaySummaryView: View {

    @EnvironmentObject var store: TodoStore
    let day: Date

    private var items: [TodoItem] { store.items(on: day) }
    private var isToday: Bool { GanzhiCalendar.calendar.isDate(day, inSameDayAs: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(isToday ? "今天" : "\(monthDayText)")
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(Theme.ganzhi(11))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                NavigationLink(value: day) {
                    HStack(spacing: 2) {
                        Text("全部 \(items.count)")
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }

            if items.isEmpty {
                Text("这一天没有待办，点右下角「语音录入」说一句吧")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 6)
            } else {
                ForEach(items.prefix(4)) { item in
                    TodoRowView(item: item, showsDay: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private var monthDayText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month, .day], from: day)
        return "\(comps.month ?? 0)月\(comps.day ?? 0)日"
    }

    private var subtitle: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.weekday, .year, .month, .day], from: day)
        let pillar = GanzhiCalendar.shared.dayPillar(for: day)
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let wd = weekdays[((comps.weekday ?? 1) - 1) % 7]
        var parts = [wd, "\(pillar.text)日"]
        if let term = GanzhiCalendar.shared.solarTermName(on: day) {
            parts.append(term)
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 底部操作栏

struct BottomActionBar: View {

    @EnvironmentObject var app: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                app.route = .newTodo(app.selectedDay)
            } label: {
                Label("键盘录入", systemImage: "square.and.pencil")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Theme.softFill))
            }
            .buttonStyle(.plain)

            Button {
                app.route = .voice
            } label: {
                Label("语音录入", systemImage: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.hPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.bar)
    }
}
