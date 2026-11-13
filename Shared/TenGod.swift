//
//  TenGod.swift
//  十神（主星）推算（改动 6-D3，口径与改动清单一致）
//  口径：同阴阳取前者、异阴阳取后者。
//  校验样例（日干 丁 阴火）：丙 → 劫财、甲 → 正印、壬 → 正官、
//  戊 → 伤官、辛 → 偏财，与业界排盘一致。
//

import Foundation

public enum TenGod: String {
    case bijian = "比肩", jiecai = "劫财"
    case shishen = "食神", shangguan = "伤官"
    case piancai = "偏财", zhengcai = "正财"
    case qisha = "七杀", zhengguan = "正官"
    case pianyin = "偏印", zhengyin = "正印"

    /// 以日干为基准，求另一个天干的十神
    public static func of(dayStem: Int, otherStem: Int) -> TenGod {
        let me = WuXing.ofStem(dayStem)
        let it = WuXing.ofStem(otherStem)
        let samePolarity = (((dayStem % 10) + 10) % 10) % 2 == (((otherStem % 10) + 10) % 10) % 2

        if it == me {            return samePolarity ? .bijian : .jiecai }      // 同我
        if me.generates() == it { return samePolarity ? .shishen : .shangguan }  // 我生
        if me.overcomes() == it { return samePolarity ? .piancai : .zhengcai }   // 我克
        if it.overcomes() == me { return samePolarity ? .qisha : .zhengguan }    // 克我
        return samePolarity ? .pianyin : .zhengyin                               // 生我
    }
}
