//
//  NotificationScheduler.swift
//  本地通知：为每条待办的每个「提前量」注册一个通知
//

import Foundation

#if canImport(UserNotifications)
import UserNotifications

public final class NotificationScheduler {

    public static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    /// 申请通知权限（首次进入 App 时调用）
    public func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    public func currentAuthorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// 为单条待办注册提醒
    public func schedule(for item: TodoItem) {
        guard !item.isDone, let due = item.dueDate else { return }
        let offsets = item.reminderOffsets.isEmpty ? [] : item.reminderOffsets
        for offset in offsets {
            let fireDate = due.addingTimeInterval(-Double(offset) * 60)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = offset == 0 ? "现在该做了" : ReminderPreset.title(for: offset) + "提醒"
            content.body = item.title
            content.sound = .default
            content.threadIdentifier = item.id.uuidString
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

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

    /// 全量重排（例如修改了默认提醒、或从备份恢复数据后）
    public func rescheduleAll(_ items: [TodoItem]) {
        center.removeAllPendingNotificationRequests()
        for item in items where !item.isDone {
            schedule(for: item)
        }
    }

    private func identifier(for id: UUID, offset: Int) -> String {
        "\(id.uuidString)-\(offset)"
    }
}
#endif
