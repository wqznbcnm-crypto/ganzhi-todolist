import SwiftUI

// MARK: - 左滑删除行（v6 第 4 条）
// 待办项左滑整体左移，露出右侧红色删除按钮；点击按钮先弹确认，确认后才真正删除。

struct SwipeToDeleteRow<Content: View>: View {

    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    @State private var showConfirm = false

    /// 删除按钮宽度 / 拉开判定阈值 / 最大可拖动距离
    private let revealWidth: CGFloat = 64
    private let snapThreshold: CGFloat = 36
    private let maxDrag: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // 底层：红色删除按钮
            Button {
                showConfirm = true
            } label: {
                Text("删除")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: revealWidth, height: 38)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hexString: "#C6392F")))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .opacity(offsetX < -10 ? 1 : 0)

            // 上层：内容整体左移
            content()
                .background(Color(.systemBackground))   // 不透明底，未拉开时不透出红按钮
                .offset(x: offsetX)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { v in
                            // 只有横向拖动才响应，避免和列表上下滚动打架
                            guard abs(v.translation.width) > abs(v.translation.height) else { return }
                            offsetX = min(0, max(-maxDrag, v.translation.width))
                        }
                        .onEnded { v in
                            withAnimation(.easeOut(duration: 0.18)) {
                                offsetX = v.translation.width < -snapThreshold ? -revealWidth : 0
                            }
                        }
                )
                .confirmationDialog("删除这条待办？",
                                    isPresented: $showConfirm,
                                    titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            offsetX = 0
                            onDelete()
                        }
                    }
                    Button("取消", role: .cancel) {
                        withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
                    }
                } message: {
                    Text("删除后无法恢复")
                }
        }
    }
}
