//
//  InteractivePopGesture.swift
//  恢复「左边缘右滑返回」
//
//  背景：SwiftUI 的 .navigationBarBackButtonHidden(true) 会连带禁用 UIKit 的
//  interactivePopGestureRecognizer，导致隐藏返回按钮的页面既没有按钮、也没有手势。
//  这里用一个零尺寸的宿主控制器找到所在 UINavigationController，把手势的 delegate
//  置空并重新启用；只在导航栈深度 > 1 时启用，避免在根页左滑把导航栈卡死。
//

import SwiftUI
import UIKit

struct InteractivePopGestureEnabler: UIViewControllerRepresentable {

    final class Controller: UIViewController {

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enable()
        }

        private func enable() {
            guard let nav = navigationController ?? ancestorNavigation(),
                  nav.viewControllers.count > 1 else { return }
            nav.interactivePopGestureRecognizer?.delegate = nil
            nav.interactivePopGestureRecognizer?.isEnabled = true
        }

        private func ancestorNavigation() -> UINavigationController? {
            var node: UIViewController? = parent
            while let current = node {
                if let nav = current as? UINavigationController { return nav }
                if let nav = current.navigationController { return nav }
                node = current.parent
            }
            return nil
        }
    }

    func makeUIViewController(context: Context) -> UIViewController { Controller() }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    /// 挂在自定义返回按钮的页面上，重新启用系统左边缘右滑返回
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureEnabler().frame(width: 0, height: 0))
    }
}
