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
    /// 点中的字（v7：向下内联展开虚线示意，不再弹窗）
    @State private var activeTarget: RelationTarget?
    /// 正在编辑标签的字
    @State private var editingTagChar: String?

    /// v8：事迹记录
    @ObservedObject private var eventStore = EventStore.shared

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

                    // v8 ①：本周哪几天与历史事迹干支相同
                    if !weekEventMatches.isEmpty {
                        eventMatchSection.padding(.top, 8)
                    }

                    // C3 排盘面板：即时排盘 ‖ 本人八字；点字 → 下方内联展开虚线示意（v7）
                    BaZiBoardView(data: boardData) { col, isStem in
                        toggleRelation(col: col, isStem: isStem)
                    }
                    .padding(.top, 14)

                    if let payload = inlinePayload {
                        RelationInlineView(payload: payload) { char in
                            editingTagChar = char
                        }
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 本周待办
                    weekTodoSection
                        .padding(.top, 16)

                    // v8 ②：本周已经发生的事迹
                    weekEventSection
                        .padding(.top, 14)
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
        .animation(.easeInOut(duration: 0.18), value: activeTarget)
        .sheet(item: Binding(
            get: { editingTagChar.map { TagCharBox(char: $0) } },
            set: { editingTagChar = $0?.char }
        )) { box in
            PersonalNoteEditorView(char: box.char)
        }
    }

    /// sheet(item:) 用的包装
    private struct TagCharBox: Identifiable {
        let char: String
        var id: String { char }
    }

    private var monthText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month], from: selectedDay)
        return "\(comps.month ?? 0)月"
    }

    // MARK: 点字 → 内联展开（再点同一个字收起）

    private func toggleRelation(col: Int, isStem: Bool) {
        let data = boardData
        let stemsText: [String?] = data.stems.map { $0.map { GanZhiText.stems[$0] } }
        let branchesText: [String?] = data.branches.map { $0.map { GanZhiText.branches[$0] } }
        guard let char = (isStem ? stemsText[col] : branchesText[col]) else { return }
        let target = RelationTarget(col: col, isStem: isStem, char: char)
        withAnimation(.easeInOut(duration: 0.18)) {
            activeTarget = (activeTarget == target) ? nil : target
        }
    }

    /// 展开区所需数据（关系在展开时按当前面板算一次）
    private var inlinePayload: RelationPayload? {
        guard let target = activeTarget else { return nil }
        let data = boardData
        let stemsText: [String?] = data.stems.map { $0.map { GanZhiText.stems[$0] } }
        let branchesText: [String?] = data.branches.map { $0.map { GanZhiText.branches[$0] } }
        return RelationPayload(target: target,
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
        activeTarget = nil
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
                    // 原地切换：不 push、不弹层；换天收起展开区
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDay = day
                        activeTarget = nil
                    }
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
                        if matchedDays.contains(day.startOfBeijingDay) {
                            // v8：这一天流日干支与某条历史事迹一致 → 朱砂小标（完整提示见周条下方）
                            Text("事")
                                .font(Theme.puhui(7.5, bold: true))
                                .foregroundStyle(.white)
                                .frame(width: 11, height: 11)
                                .background(Circle().fill(Theme.accent))
                        } else {
                            // 有待办：列底 3pt 圆点
                            Circle()
                                .fill(pending.contains(day.startOfBeijingDay) ? Color(hexString: "#CFCBC4") : .clear)
                                .frame(width: 3, height: 3)
                        }
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

    // MARK: v8 事迹匹配数据

    private struct DayEventMatch: Identifiable {
        let day: Date
        let dayGZ: String
        let records: [EventRecord]
        var id: Date { day }
    }

    /// 本周每天流日干支 vs 历史事迹（按日柱比较；记录带时辰时仍按日柱标天，时辰在文案里注明）
    private var weekEventMatches: [DayEventMatch] {
        weekDays.compactMap { day in
            let gz = GanzhiCalendar.shared.dayPillar(for: day).text
            let hits = eventStore.items.filter { $0.notifyOnMatch && EventMatcher.sameDay($0, dayGZ: gz) }
            return hits.isEmpty ? nil : DayEventMatch(day: day, dayGZ: gz, records: hits)
        }
    }

    private var matchedDays: Set<Date> {
        Set(weekEventMatches.map { $0.day.startOfBeijingDay })
    }

    private var weekSummary: String {
        let wd = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return "\(GanzhiCalendar.calendar.component(.day, from: weekDays[0]))日 – \(GanzhiCalendar.calendar.component(.day, from: weekDays[6]))日"
    }

    /// ① 干支匹配提醒
    private var eventMatchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("历史事迹匹配")
                    .font(.system(size: 11, weight: .semibold))
                    .letterSpacingCompat(0.6)
                    .foregroundStyle(Theme.accent.opacity(0.85))
                Spacer()
                Text("同为干支")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText.opacity(0.6))
            }
            .padding(.bottom, 6)

            ForEach(weekEventMatches) { match in
                VStack(alignment: .leading, spacing: 3) {
                    let c = GanzhiCalendar.calendar.dateComponents([.month, .day, .weekday], from: match.day)
                    let wd = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][((c.weekday ?? 1) - 1) % 7]
                    Text("\(c.month ?? 0)/\(c.day ?? 0) \(wd) · \(match.dayGZ)日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    ForEach(match.records) { record in
                        Text("【历史事迹匹配】你曾在相同干支发生过：\(record.title)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.05)))
                .padding(.bottom, 6)
            }

            Text("仅为您的个人历史笔记回顾，不代表预判、吉凶预测。")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.secondaryText.opacity(0.75))
        }
    }

    /// ② 本周已发生的事迹
    private var weekEventSection: some View {
        let records = eventStore.records(from: weekDays[0], to: weekDays[6])
        return VStack(alignment: .leading, spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline) {
                Text("本周事迹")
                    .font(.system(size: 11, weight: .semibold))
                    .letterSpacingCompat(0.6)
                    .foregroundStyle(Color(hexString: "#8B867E"))
                Spacer()
                Text("\(records.count) 条")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText.opacity(0.6))
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            if records.isEmpty {
                Text("本周还没有记录事迹")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(records) { record in
                    Button {
                        app.route = .editEvent(record)
                    } label: {
                        weekEventRow(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekEventRow(_ record: EventRecord) -> some View {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.month, .day, .weekday], from: record.day)
        let wd = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][((comps.weekday ?? 1) - 1) % 7]
        return HStack(spacing: 9) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 9))
                .foregroundStyle(Theme.accent.opacity(0.7))
                .frame(width: 13)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(comps.month ?? 0)/\(comps.day ?? 0) \(wd) · \(record.pillarLine)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hexString: "#B3AEA7"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4.5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 1)
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
                    .strikethrough(TodoRowText.isStruck(item), color: Theme.secondaryText.opacity(0.75))
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
