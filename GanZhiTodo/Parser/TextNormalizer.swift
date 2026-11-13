//
//  TextNormalizer.swift
//  语音转写文本归一化（改动 8-C）：全角转半角、去标点、中文数字转阿拉伯、少量近形纠错
//  口径：只做字符串层面的确定性处理，不做语义级改写（禁止把「回头」改写成「明天」之类的猜）。
//  归一化后的文本同时用于解析和卡片上的「识别原文」。
//

import Foundation

public enum TextNormalizer {

    public static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // 全角→半角：３点→3点、１１月→11月
        t = t.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? t
        // 标点→空格（语音转写常把整句连标点一起返回，这是解析挂掉的根因之一）。
        // 注意两点：
        // ① 冒号 :／： 不删——「10:30」「10：30」是时刻表达，删了会让时刻解析失效（改动 2 回归优先）；
        // ② ｡､ 是全角句号/逗号经 fullwidth→halfwidth 转换后的产物，必须一并删除；
        // ③ 全角 … 转换后变成三个半角点，由类中的 . 兜住。
        t = t.replacingOccurrences(of: "[，。｡、､！？；,\\.!?;~·…\"\"''「」『』（）()]", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // 中文数字→阿拉伯（仅限紧跟时间单位的场景，见函数注释）
        t = cnNumberToArabic(t)
        // 近形/同音误识纠错（只改错字，不猜语义）
        for (wrong, right) in homophones where wrong != right {
            t = t.replacingOccurrences(of: wrong, with: right)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// 近形误识对照表。注意：清单原文中 ("周天","周天")、("明早","明早") 为恒等项（占位说明不改），
    /// 恒等替换无效果，此处跳过（等价于清单口径：周天/明早保持原样）。
    static let homophones: [(String, String)] = [
        ("周曰", "周日"), ("州日", "周日"),
        ("星其", "星期"), ("里拜", "礼拜"), ("题醒", "提醒"),
        ("待办事项", "待办")
    ]

    /// 中文数字→阿拉伯数字。
    /// 覆盖：一 二 两 三…九 十、十一…九十九；
    /// 仅当数字序列**紧跟时间单位字**（点/时/分/秒/号/日/月/周/年/个）时才转换，
    /// 避免「三人会议」「十二个人」这类普通计数被误改成阿拉伯数字（保护标题原貌）。
    /// 「半」不转换：解析器的「一点半/半小时」分支直接消费中文「半」，转成 0.5 反而破坏匹配。
    static func cnNumberToArabic(_ s: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "([一二两三四五六七八九十]{1,3})(?=[点點时時分秒号日月周年个])") else { return s }
        let ns = s as NSString
        let out = NSMutableString()
        var cursor = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let r = m.range(at: 1)
            if r.location > cursor {
                out.append(ns.substring(with: NSRange(location: cursor, length: r.location - cursor)))
            }
            let word = ns.substring(with: r)
            if let v = cnValue(word) {
                out.append(String(v))
            } else {
                out.append(word)
            }
            cursor = NSMaxRange(r)
        }
        if cursor < ns.length {
            out.append(ns.substring(from: cursor))
        }
        return out as String
    }

    /// 「十」进制中文数字求值：三→3、十二→12、二十→20、九十九→99
    static func cnValue(_ w: String) -> Int? {
        let map: [Character: Int] = ["零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
                                     "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        let chars = Array(w)
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
}
