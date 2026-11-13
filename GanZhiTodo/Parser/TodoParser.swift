//
//  TodoParser.swift
//  中文待办文本解析：从一句话里抽出「事件」和「时间」，不依赖任何在线服务
//
//  支持示例：
//    「明天下午三点开产品评审会」      → 开产品评审会 / 明天 15:00
//    「下周一交季度报表，提前一天提醒」 → 交季度报表 / 下周一 09:00 / 提前 1 天
//    「11月20号前提交报销单」         → 提交报销单 / 11-20 09:00
//    「两小时后给妈妈打电话」          → 给妈妈打电话 / 今天 22:50
//    「周五 10:30 牙医」              → 牙医 / 本周五 10:30
//

import Foundation

public struct ParsedTodo {
    public var title: String
    public var dueDate: Date?
    /// 是否明确说了时刻（否则按当天 09:00，视为「全天」）
    public var hasExplicitTime: Bool
    public var reminderOffsets: [Int]
    public var originalText: String

    public init(title: String, dueDate: Date?, hasExplicitTime: Bool, reminderOffsets: [Int], originalText: String) {
        self.title = title
        self.dueDate = dueDate
        self.hasExplicitTime = hasExplicitTime
        self.reminderOffsets = reminderOffsets
        self.originalText = originalText
    }
}

public enum TodoParser {

    // MARK: 中文数字

    static func intValue(_ s: String) -> Int? {
        if let v = Int(s) { return v }
        let map: [Character: Int] = ["零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
                                     "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        let chars = Array(s)
        guard !chars.isEmpty else { return nil }
        if let idx = chars.firstIndex(of: "十") {
            let head = String(chars[..<idx])
            let tail = String(chars[(idx + 1)...])
            let tens = head.isEmpty ? 1 : (map[Character(head)] ?? 0)
            let ones = tail.isEmpty ? 0 : (map[Character(tail)] ?? 0)
            return tens * 10 + ones
        }
        if chars.count == 1, let v = map[chars[0]] { return v }
        return nil
    }

    static func quantity(_ s: String) -> Double? {
        if s == "半" { return 0.5 }
        if let v = intValue(s) { return Double(v) }
        return nil
    }

    // MARK: 正则工具

    static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [])
    }

    struct Hit {
        var range: NSRange
        var groups: [String?]
    }

    static func firstHit(_ pattern: String, in text: NSString, from index: Int = 0) -> Hit? {
        guard let re = regex(pattern) else { return nil }
        guard let m = re.firstMatch(in: text as String, options: [], range: NSRange(location: index, length: text.length - index)) else { return nil }
        var groups: [String?] = []
        for g in 0..<m.numberOfRanges {
            let r = m.range(at: g)
            groups.append(r.location == NSNotFound ? nil : text.substring(with: r))
        }
        return Hit(range: m.range, groups: groups)
    }

    // MARK: 主入口

    public static func parse(_ rawText: String, now: Date = Date()) -> ParsedTodo {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = text as NSString
        var removeRanges: [NSRange] = []
        let cal = GanzhiCalendar.calendar
        let nowComps = cal.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)

        var dayDate: Date? = nil          // 目标日期（当天 0 点）
        var hour: Int? = nil
        var minute: Int = 0
        var explicitTime = false
        var offsets: [Int] = []
        var relativeInterval: TimeInterval? = nil

        // ---- 1. 提醒提前量 ----
        if let hit = firstHit(#"(提前|提早)[\s,，。、~·]*(半个|[0-9一二两三四五六七八九十半]+)[\s,，。、~·]*(分钟|分|小时|钟头|天|日|周|个?星期|个?月)[\s,，。、~·]*(提醒|通知|叫我|喊我)?"#, in: ns) {
            let numStr = (hit.groups[2] ?? "").hasPrefix("半个") ? "半" : (hit.groups[2] ?? "")
            let num = quantity(numStr) ?? 0
            let unit = hit.groups[3] ?? "分钟"
            var minutes = 0.0
            if unit.contains("分钟") || unit.contains("分") { minutes = num }
            else if unit.contains("小时") || unit.contains("钟头") { minutes = num * 60 }
            else if unit.contains("天") || unit.contains("日") { minutes = num * 1440 }
            else if unit.contains("周") || unit.contains("星期") { minutes = num * 10080 }
            else if unit.contains("月") { minutes = num * 43200 }
            if minutes > 0 { offsets.append(Int(minutes)) }
            removeRanges.append(hit.range)
        }

        // ---- 2. 具体时刻 ----
        // 2a. 14:30 / 9：05
        if let hit = firstHit(#"(上午|早上|早晨|清晨|中午|下午|傍晚|晚上|夜里|晚间|凌晨)?[\s,，。、~·]*([0-9]{1,2})[\s,，。、~·]*[:：][\s,，。、~·]*([0-9]{2})"#, in: ns) {
            hour = Int(hit.groups[2] ?? "") ?? 0
            minute = Int(hit.groups[3] ?? "") ?? 0
            hour = applyPeriod(hit.groups[1] ?? "", to: hour ?? 0)
            explicitTime = true
            removeRanges.append(hit.range)
        }
        // 2b. 下午三点 / 晚上八点半 / 十点一刻
        if hour == nil,
           let hit = firstHit(#"(上午|早上|早晨|清晨|中午|下午|傍晚|晚上|夜里|晚间|凌晨)?[\s,，。、~·]*([0-9]{1,2}|[一二两三四五六七八九十]{1,3})[\s,，。、~·]*[点時时][\s,，。、~·]*(半|一刻|三刻|[0-9]{1,2}[\s,，。、~·]*分?)?"#, in: ns) {
            if let h = intValue(hit.groups[2] ?? "") {
                hour = applyPeriod(hit.groups[1] ?? "", to: h)
                let tail = hit.groups[3] ?? ""
                if tail.contains("半") { minute = 30 }
                else if tail.contains("一刻") { minute = 15 }
                else if tail.contains("三刻") { minute = 45 }
                else if let m = Int(tail.replacingOccurrences(of: "分", with: "").trimmingCharacters(in: .whitespaces)) { minute = m }
                // 增强规格 6：裸时刻（无时段词）且小时数 ≤ 6 按下午处理（两点半 → 14:30）
                if let h = hour, (hit.groups[1] ?? "").isEmpty, h <= 6 { hour = h + 12 }
                explicitTime = true
                removeRanges.append(hit.range)
            }
        }
        // 2b2. 约数时间（增强规格 5）：晚上八九点 / 下午三四点 → 取第一个数字
        if hour == nil,
           let hit = firstHit(#"(上午|早上|早晨|清晨|中午|下午|傍晚|晚上|夜里|晚间|凌晨)?[\s,，。、~·]*([一二两三四五六七八九十])[\s,，。、~·]*([一二两三四五六七八九十])[\s,，。、~·]*[点時时]"#, in: ns) {
            if let h = intValue(hit.groups[2] ?? "") {
                hour = applyPeriod(hit.groups[1] ?? "", to: h)
                explicitTime = true
                removeRanges.append(hit.range)
            }
        }
        // 2c. 只说「中午 / 晚上 / 早上」
        if hour == nil,
           let hit = firstHit(#"(中午|晚上|夜里|晚间|早上|早晨|清晨|下午|傍晚|凌晨)"#, in: ns) {
            hour = defaultHour(for: hit.groups[1] ?? "")
            explicitTime = true
            removeRanges.append(hit.range)
        }

        // ---- 3. 日期 ----
        // 3a. 今天/明天/后天/昨天
        if let hit = firstHit(#"(今天|今日|今儿|明天|明日|明儿|后天|大后天|昨天|前天|今晚|明晚|明早|今早)"#, in: ns) {
            let word = hit.groups[1] ?? ""
            var delta = 0
            switch word {
            case "明天", "明日", "明儿", "明晚", "明早": delta = 1
            case "后天": delta = 2
            case "大后天": delta = 3
            case "昨天": delta = -1
            case "前天": delta = -2
            default: delta = 0
            }
            dayDate = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: now))
            if word.contains("晚") && hour == nil { hour = 20; explicitTime = true }
            if word.contains("早") && hour == nil { hour = 8; explicitTime = true }
            removeRanges.append(hit.range)
        }

        // 3a2. 周末类（改动 8 修订口径）：
        //   周末   → 最近的周六（今天已是周六/周日 → 取下一个周六）
        //   这周末 → 本周六（已过则取今天，不回溯过去）
        //   下周末 → 下周的周六；下下周末 → 下下周的周六
        if dayDate == nil,
           let hit = firstHit(#"(下下|下|这)?周末"#, in: ns) {
            let prefix = hit.groups[1] ?? ""
            let todayIndex = { () -> Int in
                let rawToday = (nowComps.weekday ?? 2) - 2       // 周一=0 … 周日=6
                return rawToday < 0 ? 6 : rawToday
            }()
            var delta: Int
            switch prefix {
            case "下下":
                delta = 5 - todayIndex + 14                      // 下下周六
            case "下":
                delta = 5 - todayIndex + 7                       // 下周六
            case "这":
                delta = max(0, 5 - todayIndex)                   // 本周六；已过不回溯
            default:
                let d = (5 - todayIndex + 7) % 7
                delta = d == 0 ? 7 : d                           // 今天是周六 → 下个周六；周日 → 下个周六
            }
            dayDate = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: now))
            removeRanges.append(hit.range)
        }

        // 3a3. 月底类（增强规格 2）：月底 / 月底前 / 这个月月底 → 本月最后一天
        if dayDate == nil,
           let hit = firstHit(#"(这个月|本月)?月底(之?前|以前)?"#, in: ns) {
            if let lastDay = cal.range(of: .day, in: .month, for: now)?.last {
                var comps = DateComponents(year: nowComps.year, month: nowComps.month, day: lastDay, hour: 9)
                comps.timeZone = GanzhiCalendar.beijing
                dayDate = cal.date(from: comps)
                removeRanges.append(hit.range)
            }
        }

        // 3b. 周几
        if dayDate == nil,
           let hit = firstHit(#"(下下|下|本|这|上)?[\s,，。、~·]*(周|星期|礼拜)[\s,，。、~·]*([一二三四五六日天末1-7])"#, in: ns) {
            let prefix = hit.groups[1] ?? ""
            let dayChar = hit.groups[3] ?? ""
            if let targetIndex = weekdayIndex(dayChar) {
                let rawToday = (nowComps.weekday ?? 2) - 2       // 周一=0 … 周日=6
                let todayIndex = rawToday < 0 ? 6 : rawToday
                var delta = targetIndex - todayIndex
                switch prefix {
                case "下": delta += 7
                case "下下": delta += 14
                case "上": delta -= 7
                case "本", "这": break
                default: if delta < 0 { delta += 7 }
                }
                dayDate = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: now))
                removeRanges.append(hit.range)
            }
        }

        // 3c. 3天后 / 两个小时后 / 半小时后
        if dayDate == nil,
           let hit = firstHit(#"(半个|[0-9一二两三四五六七八九十半]+)[\s,，。、~·]*(分钟|分|小时|钟头|天|日|周|个?星期|个?月)[\s,，。、~·]*(以后|之后|后|内)"#, in: ns) {
            let numStr2 = (hit.groups[1] ?? "").hasPrefix("半个") ? "半" : (hit.groups[1] ?? "")
            let num = quantity(numStr2) ?? 0
            let unit = hit.groups[2] ?? ""
            if unit.contains("分钟") || unit.contains("分") { relativeInterval = num * 60 }
            else if unit.contains("小时") || unit.contains("钟头") { relativeInterval = num * 3600 }
            else if unit.contains("天") || unit.contains("日") { relativeInterval = num * 86400 }
            else if unit.contains("周") || unit.contains("星期") { relativeInterval = num * 7 * 86400 }
            else if unit.contains("月") { relativeInterval = num * 30 * 86400 }
            removeRanges.append(hit.range)
        }

        // 3d. 11月20号 / 十一月二十日（可带年份）
        if dayDate == nil,
           let hit = firstHit(#"(明年|今年|后年)?[\s,，。、~·]*([0-9]{1,2}|[一二三四五六七八九十]{1,3})[\s,，。、~·]*月[\s,，。、~·]*([0-9]{1,2}|[一二三四五六七八九十]{1,3})[\s,，。、~·]*[日号]?[\s,，。、~·]*(之前|以前|前|截止)?"#, in: ns) {
            if let m = intValue(hit.groups[2] ?? ""), let d = intValue(hit.groups[3] ?? ""), (1...12).contains(m), (1...31).contains(d) {
                var year = nowComps.year ?? 2026
                let yearWord = hit.groups[1] ?? ""
                if yearWord.contains("明年") { year += 1 }
                if yearWord.contains("后年") { year += 2 }
                if yearWord.isEmpty && !dateIsFuture(month: m, day: d, now: now) { year += 1 }
                var comps = DateComponents(year: year, month: m, day: d, hour: 9)
                comps.timeZone = GanzhiCalendar.beijing
                dayDate = cal.date(from: comps)
                removeRanges.append(hit.range)
            }
        }

        // 3e. 下个月 5 号
        if dayDate == nil,
           let hit = firstHit(#"下个?月[\s,，。、~·]*([0-9]{1,2}|[一二三四五六七八九十]{1,3})[\s,，。、~·]*[日号][\s,，。、~·]*(之前|以前|前|截止)?"#, in: ns) {
            if let d = intValue(hit.groups[1] ?? "") {
                var comps = DateComponents(year: nowComps.year, month: (nowComps.month ?? 1) + 1, day: d, hour: 9)
                comps.timeZone = GanzhiCalendar.beijing
                dayDate = cal.date(from: comps)
                removeRanges.append(hit.range)
            }
        }

        // 3f. 11/20
        if dayDate == nil,
           let hit = firstHit(#"\b([0-9]{1,2})/([0-9]{1,2})\b"#, in: ns) {
            if let m = Int(hit.groups[1] ?? "0"), let d = Int(hit.groups[2] ?? "0"), (1...12).contains(m), (1...31).contains(d) {
                var year = nowComps.year ?? 2026
                if !dateIsFuture(month: m, day: d, now: now) { year += 1 }
                var comps = DateComponents(year: year, month: m, day: d, hour: 9)
                comps.timeZone = GanzhiCalendar.beijing
                dayDate = cal.date(from: comps)
                removeRanges.append(hit.range)
            }
        }

        // ---- 4. 组装时间 ----
        var due: Date? = nil
        if let interval = relativeInterval {
            due = now.addingTimeInterval(interval)
            explicitTime = true
        } else if let day = dayDate {
            var comps = DateComponents()
            comps.year = cal.component(.year, from: day)
            comps.month = cal.component(.month, from: day)
            comps.day = cal.component(.day, from: day)
            comps.hour = hour ?? 9
            comps.minute = hour == nil ? 0 : minute
            comps.timeZone = GanzhiCalendar.beijing
            due = cal.date(from: comps)
        } else if let h = hour {
            var comps = DateComponents()
            comps.year = nowComps.year
            comps.month = nowComps.month
            comps.day = nowComps.day
            comps.hour = h
            comps.minute = minute
            comps.timeZone = GanzhiCalendar.beijing
            if let candidate = cal.date(from: comps), candidate < now {
                due = cal.date(byAdding: .day, value: 1, to: candidate)
            } else {
                due = cal.date(from: comps)
            }
        }

        // ---- 5. 生成标题 ----
        var title = remove(text, ranges: removeRanges)
        title = stripFillers(title)
        if title.isEmpty { title = rawText.trimmingCharacters(in: .whitespacesAndNewlines) }

        return ParsedTodo(title: title, dueDate: due, hasExplicitTime: explicitTime, reminderOffsets: offsets, originalText: rawText)
    }

    // MARK: 辅助

    static func applyPeriod(_ period: String, to hour: Int) -> Int {
        switch period {
        case "下午", "傍晚":
            return hour < 12 ? hour + 12 : hour
        case "晚上", "夜里", "晚间":
            if hour < 12 { return hour + 12 }
            return hour == 12 ? 0 : hour
        case "中午":
            return hour <= 2 ? hour + 12 : hour
        case "凌晨":
            return hour == 12 ? 0 : hour
        default:
            return hour
        }
    }

    static func defaultHour(for word: String) -> Int {
        switch word {
        case "中午": return 12
        case "下午": return 15
        case "晚上", "夜里", "晚间": return 20
        case "傍晚": return 18
        case "凌晨": return 5
        default: return 8
        }
    }

    /// 周一=0 …… 周日=6；「末」按周六算
    static func weekdayIndex(_ ch: String) -> Int? {
        switch ch {
        case "一", "1": return 0
        case "二", "2": return 1
        case "三", "3": return 2
        case "四", "4": return 3
        case "五", "5": return 4
        case "六", "6", "末": return 5
        case "日", "天", "7": return 6
        default: return nil
        }
    }

    static func dateIsFuture(month: Int, day: Int, now: Date) -> Bool {
        let cal = GanzhiCalendar.calendar
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        if month > (comps.month ?? 1) { return true }
        if month < (comps.month ?? 1) { return false }
        return day >= (comps.day ?? 1)
    }

    static func remove(_ text: String, ranges: [NSRange]) -> String {
        let ns = NSMutableString(string: text)
        for r in ranges.sorted(by: { $0.location > $1.location }) {
            if r.location != NSNotFound && NSMaxRange(r) <= ns.length {
                ns.deleteCharacters(in: r)
            }
        }
        return ns as String
    }

    static func stripFillers(_ text: String) -> String {
        var s = text
        let fillers = ["提醒我", "记得", "帮我", "我要", "我想", "麻烦", "安排", "，", ",", "。", "、", "；", ";"]
        for f in fillers {
            s = s.replacingOccurrences(of: f, with: " ")
        }
        s = s.replacingOccurrences(of: "  ", with: " ")
        s = s.replacingOccurrences(of: "  ", with: " ")
        s = stripLeadingFillers(s)
        return s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。.、 ")))
    }

    /// 增强规格 7/8：剔除口语引导词与助动词前缀。
    /// 规格里的「改天/回头/有空/尽快/以后 → 不设置 due」由主流程天然满足
    /// （这些词不产生任何时间命中），此处只负责把它们从标题里去掉。
    static func stripLeadingFillers(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        let leading = ["改天", "回头", "有空", "尽快", "以后",
                       "提醒我", "记得", "帮我", "麻烦", "让我", "需要", "要", "得"]
        var changed = true
        while changed {
            changed = false
            for w in leading where s.hasPrefix(w) && s.count > w.count {
                s = String(s.dropFirst(w.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }
        return s
    }
}
