//
//  FiveElement.swift
//  五行归属（改动 6-D1，口径与改动清单一致，不得自创）
//

import Foundation

/// 五行：0 木、1 火、2 土、3 金、4 水
public enum WuXing: Int, CaseIterable {
    case wood = 0, fire, earth, metal, water

    public var name: String { ["木", "火", "土", "金", "水"][rawValue] }

    /// 天干：甲乙木、丙丁火、戊己土、庚辛金、壬癸水
    public static func ofStem(_ i: Int) -> WuXing {
        WuXing(rawValue: (((i % 10) + 10) % 10) / 2) ?? .earth
    }

    /// 地支：子亥水、寅卯木、巳午火、申酉金、丑辰未戌土
    public static func ofBranch(_ i: Int) -> WuXing {
        switch (((i % 12) + 12) % 12) {
        case 0, 11: return .water     // 子、亥
        case 2, 3:  return .wood      // 寅、卯
        case 5, 6:  return .fire      // 巳、午
        case 8, 9:  return .metal     // 申、酉
        default:    return .earth     // 丑、辰、未、戌
        }
    }

    /// 相生：木→火→土→金→水→木
    public func generates() -> WuXing { WuXing(rawValue: (rawValue + 1) % 5) ?? .wood }

    /// 相克：木→土→水→火→金→木
    public func overcomes() -> WuXing { WuXing(rawValue: (rawValue + 2) % 5) ?? .earth }
}
