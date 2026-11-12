//
//  TodoStore.swift
//  本地存储：JSON 文件放在 App Group 共享目录，App 与小组件都能读取
//

import Foundation
import Combine
import WidgetKit

public final class TodoStore: ObservableObject {

    public static let shared = TodoStore()

    @Published public private(set) var items: [TodoItem] = []

    private let queue = DispatchQueue(label: "ganzhitodo.store", qos: .userInitiated)

    public init() {
        load()
    }

    // MARK: 文件位置

    public var directoryURL: URL { AppGroupConfig.containerURL }

    public var fileURL: URL { AppGroupConfig.todosURL }

    // MARK: 读写

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        items = (try? decoder.decode([TodoItem].self, from: data)) ?? []
        sort()
    }

    private func persist() {
        let snapshot = items
        queue.async { [fileURL] in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func sort() {
        items.sort { lhs, rhs in
            let l = lhs.dueDate ?? lhs.createdAt
            let r = rhs.dueDate ?? rhs.createdAt
            if l == r { return lhs.createdAt < rhs.createdAt }
            return l < r
        }
    }

    // MARK: 查询

    /// 某天的待办（按时间排序，未完成的在前）
    public func items(on day: Date) -> [TodoItem] {
        let target = day.startOfBeijingDay
        return items
            .filter { $0.calendarDay == target }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                let l = a.dueDate ?? a.createdAt
                let r = b.dueDate ?? b.createdAt
                return l < r
            }
    }

    public func items(inMonthOf date: Date) -> [TodoItem] {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month], from: date)
        return items.filter {
            let c = cal.dateComponents([.year, .month], from: $0.calendarDay)
            return c.year == comps.year && c.month == comps.month
        }
    }

    /// 某天未完成待办数量（日历单元格上的小圆点用）
    public func numberOfPending(on day: Date) -> Int {
        items(on: day).filter { !$0.isDone }.count
    }

    public var todayItems: [TodoItem] { items(on: Date()) }

    // MARK: 增删改

    public func add(_ item: TodoItem) {
        items.append(item)
        sort()
        persist()
        NotificationScheduler.shared.schedule(for: item)
        notifyChange()
    }

    public func update(_ item: TodoItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        sort()
        persist()
        NotificationScheduler.shared.cancel(for: item.id)
        NotificationScheduler.shared.schedule(for: item)
        notifyChange()
    }

    public func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        persist()
        NotificationScheduler.shared.cancel(for: item.id)
        notifyChange()
    }

    public func delete(at offsets: IndexSet, in day: Date) {
        let list = items(on: day)
        for index in offsets where index < list.count {
            delete(list[index])
        }
    }

    public func toggleDone(_ item: TodoItem) {
        var copy = item
        copy.isDone.toggle()
        copy.completedAt = copy.isDone ? Date() : nil
        update(copy)
    }

    public func purgeCompleted(before date: Date) {
        items.removeAll { $0.isDone && ($0.completedAt ?? $0.createdAt) < date }
        persist()
        notifyChange()
    }

    private func notifyChange() {
        WidgetRefresher.reload()
        NotificationCenter.default.post(name: .todoStoreDidChange, object: nil)
    }
}

public extension Notification.Name {
    static let todoStoreDidChange = Notification.Name("ganzhitodo.store.didChange")
}

/// 触发小组件刷新（App 内改动后调用）
public enum WidgetRefresher {
    public static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
