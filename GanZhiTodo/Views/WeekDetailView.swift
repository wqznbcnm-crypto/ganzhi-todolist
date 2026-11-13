//
//  WeekDetailView.swift
//  周详情页（改动 7-C/D/E）：‹返回 + 日期范围 / 7 天周条 / 八字面板+连线 /
//  大运条 / 刑冲合害文字说明 / 本周待办 / 右上角话筒（改动 9-F，anchor = 选中列）
//

import SwiftUI

struct WeekDetailView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Date

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

                // C2 周条（7 列等分，原地切换）
                weekStrip
                    .padding(.top, 14)

                // C3 八字面板 + 连线（以选中日为流日）
                BaZiBoardView(data: BaZiBoardData(for: selectedDay,
                                                  chart: app.birthChart,
                                                  lateZi: app.lateZiCountsAsNextDay),
                              showsRelationLines: true)
                    .padding(.top, 14)

                // 大运条紧随面板
                if app.birthChart != nil {
                    DayunBarView()
                        .padding(.top, 11)

                    // E 刑冲合害文字说明
                    RelationNoteView(hits: relationHits)
                        .padding(.top, 16)
                }

                // 本周待办
                weekTodoSection
                    .padding(.top, 16)
            }
            .padding(.horizontal, Theme.hPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var monthText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month], from: selectedDay)
        return "\(comps.month ?? 0)月"
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

    // MARK: 关系

    private var relationHits: [RelationHit] {
        BaZiBoardData(for: selectedDay, chart: app.birthChart, lateZi: app.lateZiCountsAsNextDay).relationHits
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
            Text(item.isDone ? "已完成" : (item.timeText == "全天" ? "" : item.timeText))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Color(hexString: "#B3AEA7"))
        }
        .padding(.vertical, 4.5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 1)
        }
    }
}

// MARK: - 刑冲合害文字说明（改动 7-E）

struct RelationNoteView: View {

    let hits: [RelationHit]

    private var drawable: [RelationHit] { RelationEngine.drawable(hits) }
    private var dropped: [RelationHit] { RelationEngine.droppedBySpan(hits) }

    /// 组合串：按干支自然序排序，用「·」分隔
    private func comboText(_ kind: RelationKind, isStem: Bool) -> String {
        let relevant = drawable.filter { $0.kind == kind && $0.isStem == isStem }
        let sorted = relevant.sorted { ($0.orderA, $0.orderB, $0.colA) < ($1.orderA, $1.orderB, $1.colA) }
        let seen = NSOrderedSet(array: sorted.map(\.chars))
        return (seen.array as? [String])?.joined(separator: " · ") ?? ""
    }

    private func count(_ kind: RelationKind) -> Int {
        drawable.filter { $0.kind == kind }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            // 标题行 + 图例
            HStack {
                Text("刑冲合害")
                    .font(.system(size: 11, weight: .semibold))
                    .letterSpacingCompat(0.6)
                    .foregroundStyle(Color(hexString: "#8B867E"))
                Spacer()
                HStack(spacing: 6) {
                    Rectangle().fill(Theme.secondaryText).frame(width: 12, height: 1.3)
                    Text("本命").font(.system(size: 9.5)).foregroundStyle(Color(hexString: "#B3AEA7"))
                    Rectangle()
                        .fill(Theme.secondaryText)
                        .frame(width: 12, height: 1)
                        .overlay(Rectangle().fill(.white).frame(width: 2.5).offset(x: 2.5))
                        .clipShape(Rectangle())
                    Text("流运").font(.system(size: 9.5)).foregroundStyle(Color(hexString: "#B3AEA7"))
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 2)

            ForEach(RelationKind.allCases, id: \.rawValue) { kind in
                relationGroup(kind)
            }

            // 被跨度规则排除的长线（N = 0 时整行不显示）
            if !dropped.isEmpty {
                Text("另有 \(dropped.count) 处跨度较大的作用未连线")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
                    .padding(.top, 6)
            }
        }
    }

    private func relationGroup(_ kind: RelationKind) -> some View {
        let n = count(kind)
        let rgb = kind.colorRGB
        let stemCombo = comboText(kind, isStem: true)
        let branchCombo = comboText(kind, isStem: false)
        let isEmpty = (n == 0)

        return HStack(alignment: .top, spacing: 10) {
            Text(kind.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                .opacity(isEmpty ? 0.35 : 1)
                .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if isEmpty {
                    Text("无")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondaryText.opacity(0.6))
                } else {
                    if !branchCombo.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("地支")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color(hexString: "#B3AEA7"))
                                .frame(width: 22, alignment: .leading)
                            Text(branchCombo)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color(hexString: "#3A3A3A"))
                        }
                    }
                    if !stemCombo.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("天干")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color(hexString: "#B3AEA7"))
                                .frame(width: 22, alignment: .leading)
                            Text(stemCombo)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color(hexString: "#3A3A3A"))
                        }
                    }
                    Text(kind.explanation)
                        .font(.system(size: 9.5))
                        .lineSpacing(3)
                        .foregroundStyle(Color(hexString: "#B3AEA7"))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(n) 处")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondaryText.opacity(0.6))
        }
        .padding(.vertical, 7)
    }
}
