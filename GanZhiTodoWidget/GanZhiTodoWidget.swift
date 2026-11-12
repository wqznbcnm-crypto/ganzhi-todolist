//
//  GanZhiTodoWidget.swift
//  主屏幕小组件（中等尺寸）：当月简易日历 + 今日四柱 + 今日待办
//

import WidgetKit
import SwiftUI

// MARK: - 数据

struct WidgetEntry: TimelineEntry {
    let date: Date
    let pillars: FourPillars
    let monthHeader: (year: Pillar, month: Pillar)
    let month: Date
    let todos: [TodoItem]
}

enum WidgetDataLoader {

    static func todos(on day: Date) -> [TodoItem] {
        guard let data = try? Data(contentsOf: AppGroupConfig.todosURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let all = (try? decoder.decode([TodoItem].self, from: data)) ?? []
        return all.filter { $0.calendarDay == day.startOfBeijingDay && !$0.isDone }
            .sorted { ($0.dueDate ?? $0.createdAt) < ($1.dueDate ?? $1.createdAt) }
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let now = Date()
        let cal = GanzhiCalendar.calendar
        let start = cal.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now

        var entries: [WidgetEntry] = []
        for hour in 0..<24 {
            let date = cal.date(byAdding: .hour, value: hour, to: start) ?? now
            entries.append(makeEntry(for: date))
        }
        let nextReload = cal.date(byAdding: .hour, value: 24, to: start) ?? now
        completion(Timeline(entries: entries, policy: .after(nextReload)))
    }

    private func makeEntry(for date: Date) -> WidgetEntry {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month], from: date)
        let month = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!
        return WidgetEntry(date: date,
                           pillars: GanzhiCalendar.shared.fourPillars(for: date),
                           monthHeader: GanzhiCalendar.shared.monthHeaderPillars(year: comps.year ?? 2026, month: comps.month ?? 1),
                           month: month,
                           todos: WidgetDataLoader.todos(on: date))
    }
}

// MARK: - 主 Widget

struct GanZhiTodoWidget: Widget {
    let kind = "GanZhiTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GanZhiTodoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("干支日历")
        .description("当月日历、今日四柱与待办")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 视图

struct GanZhiTodoWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    private let accent = Color(red: 0.66, green: 0.22, blue: 0.18)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leftColumn
            MiniMonthGrid(month: entry.month, today: entry.date)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dayText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(weekdayText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.monthHeader.year.text)年 \(entry.monthHeader.month.text)月")
                .font(.system(size: 10, design: .serif))
                .foregroundStyle(.secondary)

            Text(entry.pillars.text)
                .font(.system(size: 10.5, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Rectangle().fill(.secondary.opacity(0.15)).frame(height: 1)

            if entry.todos.isEmpty {
                Text("今日无待办")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entry.todos.prefix(3)) { todo in
                        HStack(spacing: 5) {
                            Circle().fill(accent).frame(width: 4, height: 4)
                            Text(todo.title)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                    }
                    if entry.todos.count > 3 {
                        Text("还有 \(entry.todos.count - 3) 项…")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month, .day], from: entry.date)
        return "\(comps.month ?? 0)月\(comps.day ?? 0)日"
    }

    private var weekdayText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.weekday], from: entry.date)
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return weekdays[((comps.weekday ?? 1) - 1) % 7]
    }
}

// MARK: - 迷你月历

struct MiniMonthGrid: View {

    let month: Date
    let today: Date

    private let labels = ["一", "二", "三", "四", "五", "六", "日"]

    private var weeks: [[Int?]] {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month], from: month)
        let first = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = (cal.component(.weekday, from: first) + 5) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading)
        for d in 1...days { cells.append(d) }
        while cells.count % 7 != 0 { cells.append(nil) }
        var result: [[Int?]] = []
        for i in stride(from: 0, to: cells.count, by: 7) {
            result.append(Array(cells[i..<min(i + 7, cells.count)]))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            Text("\(day)")
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundStyle(isToday(day) ? Color.white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 13)
                                .background(
                                    Circle().fill(isToday(day) ? Color.primary : Color.clear).frame(width: 16, height: 16)
                                )
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 13)
                        }
                    }
                }
            }
        }
    }

    private func isToday(_ day: Int) -> Bool {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month, .day], from: today)
        let mcomps = cal.dateComponents([.year, .month], from: month)
        return comps.year == mcomps.year && comps.month == mcomps.month && comps.day == day
    }
}

// MARK: - 入口

@main
struct GanZhiTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        GanZhiTodoWidget()
    }
}
