//
//  SpecialDayData.swift
//  「今天的重要日子」：法定节假日首日 / 节气 / 固定日期的常见纪念日
//
//  规则（用户 2026-11-14 定）：
//    优先级 法定节假日 > 节气 > 纪念日，一行只显示一条。
//    法定节假日首日 →「国庆第一天」，假期内其余日 →「国庆假期」。
//
//  说明：
//    · 只收录**每年固定公历日期**的纪念日。母亲节/父亲节/感恩节等按第几个星期几
//      浮动的不收录；元宵、七夕、重阳、腊八等农历节日需要农历换算，本期未实现。
//    · 本文件只做名词标注，不涉及吉凶判断。
//

import Foundation

public struct SpecialDay: Equatable {
    public enum Kind: Int {
        case holiday      // 法定节假日
        case solarTerm    // 节气
        case observance   // 纪念日
    }
    public let text: String
    public let kind: Kind
    public init(text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }
}

public enum SpecialDayCN {

    /// 法定节假日短名（HolidayData 里的正式名 → 显示用的短名）
    private static let shortNames: [String: String] = [
        "元旦": "元旦",
        "春节": "春节",
        "清明节": "清明",
        "劳动节": "劳动节",
        "端午节": "端午",
        "中秋节": "中秋",
        "国庆节": "国庆",
        "国庆节·中秋节": "国庆·中秋"
    ]

    /// 固定公历日期的纪念日：key = "MM-dd"
    private static let observances: [String: String] = [
        "01-10": "中国人民警察节",
        "02-14": "情人节",
        "03-03": "全国爱耳日",
        "03-06": "世界青光眼日",
        "03-08": "国际妇女节",
        "03-12": "植树节",
        "03-15": "国际消费者权益日",
        "03-21": "世界睡眠日",
        "03-22": "世界水日",
        "03-23": "世界气象日",
        "03-24": "世界防治结核病日",
        "04-01": "愚人节",
        "04-02": "国际儿童图书日",
        "04-07": "世界卫生日",
        "04-11": "世界帕金森病日",
        "04-22": "世界地球日",
        "04-23": "世界读书日",
        "05-08": "世界微笑日",
        "05-12": "国际护士节",
        "05-17": "世界高血压日",
        "05-18": "国际博物馆日",
        "05-25": "世界甲状腺日",
        "05-31": "世界无烟日",
        "06-01": "国际儿童节",
        "06-05": "世界环境日",
        "06-06": "全国爱眼日",
        "06-14": "世界献血者日",
        "06-23": "国际奥林匹克日",
        "06-26": "国际禁毒日",
        "07-11": "世界人口日",
        "07-20": "人类月球日",
        "08-08": "全民健身日",
        "08-19": "中国医师节",
        "09-10": "教师节",
        "09-20": "全国爱牙日",
        "09-21": "国际和平日",
        "09-27": "世界旅游日",
        "09-29": "世界心脏日",
        "10-10": "世界精神卫生日",
        "10-11": "世界镇痛日",
        "10-16": "世界粮食日",
        "10-17": "国际消除贫困日",
        "10-22": "世界传统医药日",
        "10-24": "联合国日",
        "10-29": "世界卒中日",
        "10-31": "世界城市日",
        "11-08": "记者节",
        "11-09": "全国消防日",
        "11-14": "世界糖尿病日",
        "11-20": "世界儿童日",
        "11-21": "世界问候日",
        "11-25": "国际消除对妇女暴力日",
        "12-01": "世界艾滋病日",
        "12-03": "国际残疾人日",
        "12-04": "国家宪法日",
        "12-05": "国际志愿者日",
        "12-10": "世界人权日",
        "12-13": "国家公祭日",
        "12-24": "平安夜",
        "12-25": "圣诞节"
    ]

    private static var cal: Calendar { GanzhiCalendar.calendar }

    /// 某天的重要日子（无则 nil）
    public static func day(for date: Date) -> SpecialDay? {
        if let holiday = holidayText(for: date) {
            return SpecialDay(text: holiday, kind: .holiday)
        }
        if let term = GanzhiCalendar.shared.solarTermName(on: date) {
            return SpecialDay(text: term, kind: .solarTerm)
        }
        let comps = cal.dateComponents([.month, .day], from: date)
        let key = String(format: "%02d-%02d", comps.month ?? 0, comps.day ?? 0)
        if let name = observances[key] {
            return SpecialDay(text: name, kind: .observance)
        }
        return nil
    }

    /// 法定节假日文案：首日「国庆第一天」，假期内其余日「国庆假期」
    private static func holidayText(for date: Date) -> String? {
        guard let today = HolidayCN.info(for: date), today.type == .holiday else { return nil }
        let short = shortNames[today.name] ?? today.name

        let yesterday = cal.date(byAdding: .day, value: -1, to: date) ?? date
        let isFirstDay = HolidayCN.info(for: yesterday)?.type != .holiday
        return isFirstDay ? "\(short)第一天" : "\(short)假期"
    }

    /// 待办行用的节日短名（如「中秋」）；只在**法定放假日**返回，调休上班日不标
    public static func todoLabel(for date: Date) -> String? {
        guard let entry = HolidayCN.info(for: date), entry.type == .holiday else { return nil }
        return shortNames[entry.name] ?? entry.name
    }
}
