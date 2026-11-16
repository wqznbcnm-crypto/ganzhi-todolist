//
//  EventRecord.swift
//  事迹记录（v8）：记录已经发生的事，绑定量子四柱；后续走到相同干支时做回顾提醒。
//
//  设计说明（重要）：
//  · 记录四柱在**录入时冻结**成文本，之后历法实现若有调整，历史记录也不会漂移。
//  · 匹配主键取「日柱」，记录填写了时辰时再加「时柱」。
//    为什么不是严格「年月日时」全等：年柱 60 年一轮，年月日全同基本一辈子撞不上，
//    提醒永远不会触发、功能等于没有。日柱 + 时柱是 60 天一轮，才是「回顾」的实际用法。
//    这一取舍在交付说明里也写了，用户要严格四柱可以改一行。
//

import Foundation
import Combine

public struct EventRecord: Codable, Identifiable, Equatable {

    public var id: UUID
    /// 事件描述（例：摔跤磕碰）
    public var title: String
    /// 发生日期；填写时辰时含具体时刻，未填时为当天 00:00
    public var occurredAt: Date
    /// 是否填写了具体时辰
    public var hasHour: Bool
    /// 四柱（文本，录入时冻结）
    public var yearGZ: String
    public var monthGZ: String
    public var dayGZ: String
    /// 未填时辰 = nil
    public var hourGZ: String?
    /// 这一条是否参与同干支回顾提醒
    public var notifyOnMatch: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(),
                title: String,
                occurredAt: Date,
                hasHour: Bool,
                notifyOnMatch: Bool = true,
                createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.occurredAt = occurredAt
        self.hasHour = hasHour
        self.notifyOnMatch = notifyOnMatch
        self.createdAt = createdAt

        // 未填时辰：用当天 12:00 取三柱，避开 23:00 子时换日的边界歧义
        let cal = GanzhiCalendar.calendar
        let base = hasHour
            ? occurredAt
            : (cal.date(bySettingHour: 12, minute: 0, second: 0, of: occurredAt) ?? occurredAt)
        let p = GanzhiCalendar.shared.fourPillars(for: base)
        self.yearGZ = p.year.text
        self.monthGZ = p.month.text
        self.dayGZ = p.day.text
        self.hourGZ = hasHour ? p.hour.text : nil
    }

    /// 录入时用的完整四柱文本，如「丙午年 己亥月 壬辰日 亥时」
    public var pillarLine: String {
        var parts = ["\(yearGZ)年", "\(monthGZ)月", "\(dayGZ)日"]
        if let h = hourGZ { parts.append("\(h)时") }
        return parts.joined(separator: " ")
    }

    /// 记录日（用于「本周事迹」按天归类）
    public var day: Date { occurredAt.startOfBeijingDay }
}

// MARK: - 匹配

public enum EventMatcher {

    /// 日柱是否相同（周页按天标记用这个口径）
    public static func sameDay(_ record: EventRecord, dayGZ: String) -> Bool {
        record.dayGZ == dayGZ
    }

    /// 精确匹配：日柱相同；若记录填了时辰，还要求时辰相同
    public static func hits(_ record: EventRecord, dayGZ: String, hourGZ: String?) -> Bool {
        guard record.dayGZ == dayGZ else { return false }
        if record.hasHour, let h = record.hourGZ {
            return hourGZ == h
        }
        return true
    }
}

// MARK: - 存储

public final class EventStore: ObservableObject {

    public static let shared = EventStore()

    @Published public private(set) var items: [EventRecord] = []

    private let queue = DispatchQueue(label: "ganzhitodo.events", qos: .userInitiated)

    public init() {
        load()
    }

    public var fileURL: URL { AppGroupConfig.eventsURL }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        items = (try? decoder.decode([EventRecord].self, from: data)) ?? []
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
        items.sort { $0.occurredAt > $1.occurredAt }   // 新的在前
    }

    // MARK: 增删改

    public func add(_ record: EventRecord) {
        items.append(record)
        sort()
        persist()
    }

    public func update(_ record: EventRecord) {
        if let i = items.firstIndex(where: { $0.id == record.id }) {
            items[i] = record
        } else {
            items.append(record)
        }
        sort()
        persist()
    }

    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    // MARK: 查询

    /// 落在某一天的事迹（本周事迹区用）
    public func records(on day: Date) -> [EventRecord] {
        let target = day.startOfBeijingDay
        return items.filter { $0.day == target }
    }

    /// 某个区间内（含首尾）的事迹
    public func records(from start: Date, to end: Date) -> [EventRecord] {
        let s = start.startOfBeijingDay
        let e = end.startOfBeijingDay
        return items.filter { $0.day >= s && $0.day <= e }
    }

    /// 与给定日柱（可加时柱）匹配、且允许提醒的记录
    public func matching(dayGZ: String, hourGZ: String? = nil) -> [EventRecord] {
        items.filter { $0.notifyOnMatch && EventMatcher.hits($0, dayGZ: dayGZ, hourGZ: hourGZ) }
    }
}
