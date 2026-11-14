//
//  Theme.swift
//  视觉规范：黑白为主，干支浅灰小字，一点朱砂做点缀
//

import SwiftUI

enum Theme {

    /// 点缀色（今日、录音、节气的强调）
    static let accent = Color(red: 0.66, green: 0.22, blue: 0.18)

    /// 版面边距
    static let hPadding: CGFloat = 20

    /// 干支字体：衬线体，小字号更耐看
    static func ganzhi(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// 公历数字
    static func number(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let hairline = Color.primary.opacity(0.07)
    static let softFill = Color.primary.opacity(0.035)
    static let secondaryText = Color.primary.opacity(0.45)
}

// MARK: - 设计稿 v4 指定字体

extension Theme {

    /// 数字字体：Sinhala Sangam MN（iOS 系统内置）
    /// 注意：该字体只覆盖拉丁字母、数字与标点，**不含汉字**；
    /// 「年 / 月 / 日 / 时」这类汉字必须用 `puhui` 另起一段。
    static func digit(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "SinhalaSangamMN-Bold" : "SinhalaSangamMN", size: size)
    }

    /// 中文与干支字体：Alibaba PuHuiTi（随包，Info.plist UIAppFonts 注册）
    /// PostScript 名：AlibabaPuHuiTiB（Bold）/ AlibabaPuHuiTiL（Light）
    static func puhui(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "AlibabaPuHuiTiB" : "AlibabaPuHuiTiL", size: size)
    }
}

// MARK: - 五行配色（改动 6-D2：固定色，不随明暗模式变化）

extension Theme {
    /// 五行色：木绿、火红、土褐、金黄、水蓝（固定色）
    static func element(_ e: WuXing) -> Color {
        switch e {
        case .wood:  return Color(red: 0.24, green: 0.55, blue: 0.30)   // #3D8C4D 木绿
        case .fire:  return Color(red: 0.78, green: 0.20, blue: 0.16)   // #C73329 火红
        case .earth: return Color(red: 0.60, green: 0.44, blue: 0.28)   // #997048 土褐
        case .metal: return Color(red: 0.78, green: 0.60, blue: 0.18)   // #C7992E 金黄
        case .water: return Color(red: 0.18, green: 0.37, blue: 0.66)   // #2E5EA8 水蓝
        }
    }
}

/// 细分割线
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

/// 轻量卡片背景
struct SoftCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.softFill)
            )
    }
}

extension View {
    func softCard() -> some View { modifier(SoftCard()) }
}
