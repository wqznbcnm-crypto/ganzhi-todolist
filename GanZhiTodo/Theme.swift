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
