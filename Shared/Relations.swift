//
//  Relations.swift
//  刑冲合害关系表与配对引擎（改动 6-D4 / 改动 7-D）
//
//  柱位序号：0 = 流日、1 = 流月、2 = 流年、3 = 大运、4 = 年柱、5 = 月柱、6 = 日柱、7 = 时柱。
//  关系只在同一行内（天干行、地支行）两两匹配，跨行不算。
//

import Foundation

/// 关系类型
public enum RelationKind: String, CaseIterable {
    case he = "合"       // 木绿
    case chong = "冲"    // 火红
    case xing = "刑"     // 土褐
    case hai = "害"      // 紫灰

    /// 关系色（改动 7-D2，固定色，不随明暗模式变化）
    public var colorRGB: (r: Double, g: Double, b: Double) {
        switch self {
        case .he:    return (0.24, 0.55, 0.30)   // #3D8C4D
        case .chong: return (0.78, 0.20, 0.16)   // #C73329
        case .xing:  return (0.60, 0.44, 0.28)   // #997048
        case .hai:   return (0.48, 0.43, 0.56)   // #7A6E8F
        }
    }

    /// 释义文案（改动 7-E3，固定，不得改写）
    public var explanation: String {
        switch self {
        case .he:    return "主和合、成事有人助；合多则牵绊多，事缓而能成。"
        case .chong: return "主变动、冲击与迁移；冲不一定凶，多指事情会突然改变方向。"
        case .xing:  return "主摩擦、纠缠与反复；多指人际或事务上的来回消耗。"
        case .hai:   return "主暗损、隔阂与隐性牵制；表面无事，实际受阻。"
        }
    }
}

/// 作用层级（改动 7-D1）
public enum RelationTier {
    case t1            // 本命四柱之间（实线）
    case t2            // 流年(2)/大运(3) × 本命四柱（虚线）
    case t2b           // 流日(0) × 其余各柱（虚线）
    case t3            // 与当日无关的组合（不画线，不进正文）
}

/// 一条两两关系
public struct RelationHit: Identifiable, Hashable {
    public let id: String
    public let kind: RelationKind
    /// true = 天干行；false = 地支行
    public let isStem: Bool
    /// 两个字的干支文本（按干支自然序排序后的展示串）
    public let chars: String
    public let colA: Int
    public let colB: Int
    public let tier: RelationTier
    public let span: Int
    /// 排序用：干支自然序的数值（小者在前）
    public let orderA: Int
    public let orderB: Int
}

public enum RelationEngine {

    // MARK: - 关系表（改动 6-D4，照抄不得自创）

    /// 天干五合
    static let stemHe: Set<[Int]> = [[0, 5], [1, 6], [2, 7], [3, 8], [4, 9]]
    /// 天干相冲（戊、己无冲）
    static let stemChong: Set<[Int]> = [[0, 6], [1, 7], [2, 8], [3, 9]]

    /// 地支六合
    static let branchHe6: Set<[Int]> = [[0, 1], [2, 11], [3, 10], [4, 9], [5, 8], [6, 7]]
    /// 地支三合局（任意两支相见即按「半合」处理，归入「合」，与六合同一优先级）
    static let branchSanheGroups: [[Set<Int>]] = [
        [Set([8, 0, 4])],   // 申子辰 水局
        [Set([11, 3, 7])],  // 亥卯未 木局
        [Set([2, 6, 10])],  // 寅午戌 火局
        [Set([5, 9, 1])],   // 巳酉丑 金局
    ]
    /// 地支六冲
    static let branchChong: Set<[Int]> = [[0, 6], [1, 7], [2, 8], [3, 9], [4, 10], [5, 11]]
    /// 地支六害
    static let branchHai: Set<[Int]> = [[0, 7], [1, 6], [2, 5], [3, 4], [8, 11], [9, 10]]
    /// 地支相刑（两两配对部分；自刑「同支重见」在引擎里单独处理）
    static let branchXing: Set<[Int]> = [[2, 5], [5, 8], [1, 10], [10, 7], [0, 3]]

    // MARK: - 两两判定

    static func pairKey(_ a: Int, _ b: Int) -> [Int] { [min(a, b), max(a, b)] }

    /// 天干两两关系（合优先于冲）
    public static func stemRelation(_ a: Int, _ b: Int) -> RelationKind? {
        let key = pairKey(a, b)
        if stemHe.contains(key) { return .he }
        if stemChong.contains(key) { return .chong }
        return nil
    }

    /// 地支两两关系（优先级：合 > 冲 > 害 > 刑；三合半合要求异支）
    public static func branchRelation(_ a: Int, _ b: Int) -> RelationKind? {
        let key = pairKey(a, b)
        if branchHe6.contains(key) { return .he }
        if a != b {
            for group in branchSanheGroups where group[0].contains(a) && group[0].contains(b) { return .he }
        }
        if branchChong.contains(key) { return .chong }
        if branchHai.contains(key) { return .hai }
        if branchXing.contains(key) { return .xing }
        return nil
    }

    // MARK: - 全量配对引擎

    /// 八柱位的天干/地支序号；nil 表示该柱为空（如时柱留空）
    /// - Parameters:
    ///   - stems: 索引 = 柱位（0–7），值 = 天干序号
    ///   - branches: 索引 = 柱位（0–7），值 = 地支序号
    public static func compute(stems: [Int?], branches: [Int?]) -> [RelationHit] {
        var hits: [RelationHit] = []
        let n = 8

        func tierOf(_ a: Int, _ b: Int) -> RelationTier {
            let pair = [min(a, b), max(a, b)]
            let benming: Set<Int> = [4, 5, 6, 7]
            // T1 本命：4/5/6/7 两两
            if pair.allSatisfy(benming.contains) { return .t1 }
            // T2 流年(2)/大运(3) × 本命
            if benming.contains(pair[1]), pair[0] == 2 || pair[0] == 3 { return .t2 }
            // T2b 流日(0) × 其余各柱
            if pair[0] == 0 { return .t2b }
            // 其余（流月相关等）与当日无关
            return .t3
        }

        for a in 0..<n {
            guard let sa = stems[a], let ba = branches[a] else { continue }
            for b in (a + 1)..<n {
                guard let sb = stems[b], let bb = branches[b] else { continue }
                let span = b - a
                let tier = tierOf(a, b)

                // 天干行
                if let kind = stemRelation(sa, sb) {
                    hits.append(makeHit(kind: kind, isStem: true, a: sa, b: sb,
                                        colA: a, colB: b, tier: tier, span: span))
                }
                // 地支行
                if let kind = branchRelation(ba, bb) {
                    hits.append(makeHit(kind: kind, isStem: false, a: ba, b: bb,
                                        colA: a, colB: b, tier: tier, span: span))
                }
            }
        }

        // 自刑：辰辰(4)、午午(6)、酉酉(9)、亥亥(11) 同支重见才算（本命内部与本命×流运）
        let selfXingBranches: [Int] = [4, 6, 9, 11]
        var seen: [Int: Int] = [:]
        for (col, br) in branches.enumerated() {
            guard let br else { continue }
            if selfXingBranches.contains(br) {
                if let prev = seen[br] {
                    let tier = tierOf(prev, col)
                    hits.append(makeHit(kind: .xing, isStem: false, a: br, b: br,
                                        colA: prev, colB: col, tier: tier, span: col - prev))
                }
                seen[br] = col
            }
        }

        return hits.sorted { $0.span < $1.span }
    }

    static func makeHit(kind: RelationKind, isStem: Bool, a: Int, b: Int,
                        colA: Int, colB: Int, tier: RelationTier, span: Int) -> RelationHit {
        let lo = min(a, b), hi = max(a, b)
        let chars = isStem
            ? GanZhiText.stems[lo] + GanZhiText.stems[hi]
            : GanZhiText.branches[lo] + GanZhiText.branches[hi]
        return RelationHit(
            id: "\(kind.rawValue)-\(isStem ? "干" : "支")-\(chars)-\(colA)-\(colB)",
            kind: kind, isStem: isStem, chars: chars,
            colA: colA, colB: colB, tier: tier, span: span,
            orderA: lo, orderB: hi
        )
    }

    // MARK: - 画线筛选（改动 7-D1/D3）

    /// 可画线的关系（T1/T2/T2b 且跨度 ≤5），已按跨度升序排序
    public static func drawable(_ hits: [RelationHit]) -> [RelationHit] {
        hits.filter {
            if case .t3 = $0.tier { return false }
            return $0.span <= 5
        }
    }

    /// 被跨度规则排除的长线（须进文字说明）
    public static func droppedBySpan(_ hits: [RelationHit]) -> [RelationHit] {
        hits.filter {
            if case .t3 = $0.tier { return false }
            return $0.span > 5
        }
    }
}
