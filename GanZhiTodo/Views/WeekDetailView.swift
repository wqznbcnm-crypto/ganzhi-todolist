//
//  WeekDetailView.swift
//  周详情页（改动 7-C/D/E + 设计稿 v4）：
//    ‹返回 + 日期范围 / 7 天周条 / 排盘面板（即时排盘 ‖ 本人八字）/ 本周待办
//
//  设计稿 v4 变更：
//    · 去掉常驻连线与整段刑冲合害说明 → 点某个干/支字弹层只看该字的关系
//    · 去掉底部灰色大运条（DayunBarView 已删除）
//    · 恢复系统左边缘右滑返回（页面隐藏了返回按钮，需手动启用系统手势）
//

import SwiftUI

struct WeekDetailView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Date
    /// 切周过渡：只用 0.18s 淡入淡出，不做整页横移
    @State private var weekOpacity: Double = 1
    /// 点字后的关系弹层
    @State private var relationPayload: RelationPayload?

    init(day: Date) {
        _selectedDay = State(initialValue: day.startOfBeijingDay)
    }

    /// 本周一至周日
    private var weekDays: [Date] {
        let cal = GanzhiCalendar.calendar
        guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDay) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var dateRangeText: String {
        let cal = GanzhiCalendar.calendar
        let days = weekDays
        guard days.count == 7 else { return "" }
        let f = { (d: Date) -> String in
            let c = cal.dateComponents([.month, .day], from: d)
            return "\(c.month ?? 0)月\(c.day ?? 0)日"
        }
        return "\(f(days[0])) – \(f(days[6]))"
    }

    /// 本周待办（周一至周日过滤）
    private var weekItems: [TodoItem] {
        let days = Set(weekDays.map { $0.startOfBeijingDay })
        return store.items.filter { days.contains($0.calendarDay) }
    }

    private var boardData: BaZiBoardData {
        BaZiBoardData(for: selectedDay, chart: app.birthChart, lateZi: app.lateZiCountsAsNextDay)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // C1 顶部：返回 + 日期范围 + 话筒（改动 9-F）
                HStack {
                    Button {
                        dismiss()   // 返回首页保留原选中日期
                    } label: {
                        Text("‹ \(monthText)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(dateRangeText)
                        .font(.system(size: 11))
                        .letterSpacingCompat(0.4)
                        .foregroundStyle(Theme.secondaryText)
                    // 改动 9-F：20pt 朱砂话筒，与日期范围同排居右
                    Button {
                        app.route = .voice(anchor: selectedDay)
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 0) {
                    // C2 周条（7 列等分，原地切换）；左右滑切周（改动 7-F5）
                    weekStrip
                        .padding(.top, 14)
                        .simultaneousGesture(weekSwipe)

                    // C3 排盘面板：即时排盘 ‖ 本人八字；点字出关系弹层
                    BaZiBoardView(data: boardData) { col, isStem in
                        openRelation(col: col, isStem: isStem)
                    }
                    .padding(.top, 14)

                    // 本周待办
                    weekTodoSection
                        .padding(.top, 16)
                }
                .opacity(weekOpacity)
            }
            .padding(.horizontal, Theme.hPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .enableInteractivePopGesture()
        .sheet(item: $relationPayload) { payload in
            RelationSheetView(payload: payload)
        }
    }

    private var monthText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month], from: selectedDay)
        return "\(comps.month ?? 0)月"
    }

    // MARK: 点字 → 关系弹层

    private func openRelation(col: Int, isStem: Bool) {
        let data = boardData
        let stemsText: [String?] = data.stems.map { $0.map { GanZhiText.stems[$0] } }
        let branchesText: [String?] = data.branches.map { $0.map { GanZhiText.branches[$0] } }
        let raw = isStem ? stemsText[col] : branchesText[col]
        guard let char = raw else { return }

        relationPayload = RelationPayload(target: RelationTarget(col: col, isStem: isStem, char: char),
                                          hits: data.relationHits,
                                          titles: BaZiBoardData.titles,
                                          stems: stemsText,
                                          branches: branchesText)
    }

    // MARK: 改动 7-F5：左右滑切周（左滑=下一周，右滑=上一周）

    private var weekSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                // 左边缘 24pt 内让给系统返回手势
                guard value.startLocation.x >= 24 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.5, abs(dx) > 44 else { return }
                shiftWeek(by: dx < 0 ? 1 : -1)
            }
    }

    /// 切周：±7 天保持星期几；1900–2100 之外静默忽略；0.18s 淡入淡出
    private func shiftWeek(by offset: Int) {
        let cal = GanzhiCalendar.calendar
        guard let next = cal.date(byAdding: .day, value: 7 * offset, to: selectedDay) else { return }
        let year = cal.component(.year, from: next)
        guard year >= 1900, year <= 2100 else { return }

        selectedDay = next
        // 跨月切周后返回首页，首页要停在该周所属月份
        app.visibleMonth = next.startOfBeijingDay

        weekOpacity = 0
        // 先落地归零帧，再淡入（否则两次更新会被合并、看不到过渡）
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) { weekOpacity = 1 }
        }
    }

    // MARK: 周条

    private var weekStrip: some View {
        let cal = GanzhiCalendar.calendar
        let today = Date().startOfBeijingDay
        let weekdayLabels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        var pending: Set<Date> = []
        for item in store.items where !item.isDone { pending.insert(item.calendarDay) }

        return HStack(spacing: 0) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
                Button {
                    // 原地切换：不 push、不弹层
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDay = day }
                } label: {
                    VStack(spacing: 3) {
                        Text(weekdayLabels[index])
                            .font(.system(size: 9))
                            .foregroundStyle(isSelected ? Theme.accent.opacity(0.7) : Color(hexString: "#B3AEA7"))
                        Text("\(cal.component(.day, from: day))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isSelected ? Theme.accent : .primary)
                        Text(GanzhiCalendar.shared.dayPillar(for: day).text)
                            .font(Theme.ganzhi(8.5))
                            .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryText)
                        // 有待办：列底 3pt 圆点
                        Circle()
                            .fill(pending.contains(day.startOfBeijingDay) ? Color(hexString: "#CFCBC4") : .clear)
                            .frame(width: 3, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Theme.accent.opacity(0.07) : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { _ = today }   // 保留 today 供今日点标注扩展
    }

    // MARK: 本周待办

    private var weekTodoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline) {
                Text("本周待办")
                    .font(.system(size: 11, weight: .semibold))
                    .letterSpacingCompat(0.6)
                    .foregroundStyle(Color(hexString: "#8B867E"))
                Spacer()
                Text("\(weekItems.count) 项")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText.opacity(0.6))
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            if weekItems.isEmpty {
                Text("本周还没有待办")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(weekItems) { item in
                    Button {
                        app.route = .editTodo(item)
                    } label: {
                        weekRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekRow(_ item: TodoItem) -> some View {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.month, .day, .weekday], from: item.calendarDay)
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let wd = weekdays[((comps.weekday ?? 1) - 1) % 7]
        return HStack(spacing: 9) {
            Circle()
                .fill(item.isDone ? Theme.accent : Color.clear)
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(item.isDone ? Theme.accent : Color(hexString: "#D6D2CB"), lineWidth: 1.2))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(item.isDone ? Theme.secondaryText : .primary)
                    .lineLimit(1)
                Text("\(comps.month ?? 0)/\(comps.day ?? 0) \(wd)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hexString: "#B3AEA7"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(TodoRowText.sideLabel(item))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Color(hexString: "#B3AEA7"))
        }
        .padding(.vertical, 4.5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 1)
        }
    }
}
