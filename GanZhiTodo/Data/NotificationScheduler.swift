//
//  NotificationScheduler.swift
//  本地通知：为每条待办的每个「提前量」注册一个通知
//
//  2026-11-15 修复（提醒不出现）：
//    1. 加 UNUserNotificationCenterDelegate —— 没有它，App 在前台时系统会把通知直接丢弃
//    2. 每次回到前台全量重排 —— 重装/覆盖安装 ipa 会清掉已排队的通知，
//       而待办本身存在 App Group 容器里没丢，于是「设了提醒但从来不响」
//    3. 去掉 .timeSensitive —— 该级别需要专门的 entitlement，侧载包没有，
//       有被系统降级甚至丢弃的风险，普通提醒不需要它
//    4. 新增 pendingCount / scheduleTest，设置页可自查通知链路
//

import Foundation

#if canImport(UserNotifications)
import UserNotifications

public final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {

    public static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        // 必须尽早设置：否则前台收到的通知不会展示
        center.delegate = self
    }

    // MARK: 前台展示

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // MARK: 权限

    /// 申请通知权限（首次进入 App 时调用）
    public func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    public func currentAuthorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// 已排队的通知条数（设置页自查用）
    public func pendingCount(_ completion: @escaping (Int) -> Void) {
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async { completion(requests.count) }
        }
    }

    /// 调试用：若干秒后发一条测试提醒，用来区分「权限没开」和「排程没成功」
    public func scheduleTest(after seconds: TimeInterval = 10,
                             completion: ((Error?) -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "测试提醒"
        content.body = "看到这条说明提醒链路是通的"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "test-reminder", content: content, trigger: trigger)
        center.add(request) { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: 排程

    /// 为单条待办注册提醒
    public func schedule(for item: TodoItem) {
        guard !item.isDone, let due = item.dueDate else { return }
        let offsets = item.reminderOffsets
        for offset in offsets {
            let fireDate = due.addingTimeInterval(-Double(offset) * 60)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = offset == 0 ? "现在该做了" : ReminderPreset.title(for: offset) + "提醒"
            content.body = item.title
            content.sound = .default
            content.threadIdentifier = item.id.uuidString

            let cal = GanzhiCalendar.calendar
            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            comps.timeZone = GanzhiCalendar.beijing
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(for: item.id, offset: offset),
                                                content: content,
                                                trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    /// 删除某条待办的全部提醒
    public func cancel(for id: UUID) {
        let prefix = id.uuidString
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 全量重排：启动 / 回前台 / 修改默认提醒后调用
    public func rescheduleAll(_ items: [TodoItem]) {
        center.removeAllPendingNotificationRequests()
        for item in items where !item.isDone {
            schedule(for: item)
        }
        // v8：事迹回顾提醒一并重排（同干支到来时提示回顾）
        scheduleEventMatches(EventStore.shared.items)
    }

    /// 事迹回顾：给未来 N 天里「流日干支与历史事迹相同」的日子排一条 09:00 提醒。
    /// 上限 24 条 —— iOS 单 App 待触发通知总量 64 条，要给待办提醒留位置。
    public func scheduleEventMatches(_ records: [EventRecord], days: Int = 60, limit: Int = 24) {
        let enabled = AppGroupConfig.sharedDefaults.object(forKey: AppGroupConfig.eventReminderEnabledKey) as? Bool ?? true
        guard enabled, !records.isEmpty else { return }

        let cal = GanzhiCalendar.calendar
        let today = Date().startOfBeijingDay
        var scheduled = 0

        for offset in 1...days {
            guard scheduled < limit else { break }
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let gz = GanzhiCalendar.shared.dayPillar(for: day).text
            let hits = records.filter { $0.notifyOnMatch && EventMatcher.sameDay($0, dayGZ: gz) }
            guard !hits.isEmpty else { continue }

            let names = hits.prefix(2).map(\.title).joined(separator: "、")
            let content = UNMutableNotificationContent()
            content.title = "历史上干支相同的日子"
            content.body = "过往在相同干支发生过：\(names)"
            content.subtitle = "仅为您的个人历史笔记回顾，不代表预判、吉凶预测"
            content.sound = .default
            content.threadIdentifier = "event-\(gz)"

            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = 9
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = "event-\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            scheduled += 1
        }
    }

    private func identifier(for id: UUID, offset: Int) -> String {
        "\(id.uuidString)-\(offset)"
    }
}
#endif
