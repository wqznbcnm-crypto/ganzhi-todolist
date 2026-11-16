//
//  Compat.swift
//  iOS 16 兼容层
//  为什么要它：把最低系统降到 iOS 16 后，iPhone 8 / 8 Plus / X 这些停在 16 的机器也能装；
//  代价只有下面这四个 iOS 17 专属 API，全部用 #available 兜住，行为自动降级。
//

import SwiftUI

extension View {

    /// 数字滚动过渡（iOS 17 的 .contentTransition(.numericText())）。
    /// iOS 16 上没有这个过渡，退化为原样显示——外层 .animation(value:) 仍会做淡入淡出，不是硬切。
    @ViewBuilder
    func numericTextRoll() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }

    /// 双参数 onChange（iOS 17 写法）。iOS 16 走单参数版本。
    /// 两个版本语义一致：只在值变化时回调一次。
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}
