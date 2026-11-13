//
//  DayDetailView.swift
//  单日待办详情
//

import SwiftUI

struct DayDetailView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel
    let day: Date

    private var items: [TodoItem] { store.items(on: day) }

    var body: some View {
        ZStack {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                    Text("这一天还没有待办")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondaryText)
                    Text("点下方「语音录入」说一句，或「键盘录入」手动添加")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText.opacity(0.7))
                }
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            app.route = .editTodo(item)
                        } label: {
                            TodoRowView(item: item)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: Theme.hPadding, bottom: 6, trailing: Theme.hPadding))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { store.delete(item) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(titleText)
                        .font(.system(size: 16, weight: .semibold))
                    Text(subtitle)
                        .font(Theme.ganzhi(10))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.route = .newTodo(day)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            DayDetailActionBar(day: day)
        }
        .onAppear { app.select(day) }
    }

    private var titleText: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.month, .day], from: day)
        return "\(comps.month ?? 0)月\(comps.day ?? 0)日"
    }

    private var subtitle: String {
        let comps = GanzhiCalendar.calendar.dateComponents([.weekday], from: day)
        let pillar = GanzhiCalendar.shared.dayPillar(for: day)
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let wd = weekdays[((comps.weekday ?? 1) - 1) % 7]
        var parts = [wd, "\(pillar.text)日"]
        if let term = GanzhiCalendar.shared.solarTermName(on: day) { parts.append(term) }
        return parts.joined(separator: " · ")
    }
}

/// 详情页底部操作栏
struct DayDetailActionBar: View {

    @EnvironmentObject var app: AppModel
    let day: Date

    var body: some View {
        HStack(spacing: 12) {
            Button {
                app.route = .newTodo(day)
            } label: {
                Label("键盘录入", systemImage: "square.and.pencil")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Theme.softFill))
            }
            .buttonStyle(.plain)

            Button {
                // 改动 9：日详情页语音入口 anchor = 正在看的那天
                app.route = .voice(anchor: day)
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
