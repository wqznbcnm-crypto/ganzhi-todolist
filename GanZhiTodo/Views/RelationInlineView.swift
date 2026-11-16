//
//  RelationInlineView.swift
//  周页点字后的内联展开区（v7）：
//    · 不再弹 sheet，而是向下展开虚线示意（目标字 → 相关各柱）
//    · 下方紧凑列出关系条目，并提供「编辑标签」入口（宜做/忌做）
//

import SwiftUI

struct RelationInlineView: View {

    let payload: RelationPayload
    var onEditTags: (String) -> Void

    /// 只保留与该字相关、且同属干/支的那几条（与弹层口径一致）
    private var related: [RelationHit] {
        payload.hits.filter { hit in
            guard hit.isStem == payload.isStem else { return false }
            return hit.colA == payload.col || hit.colB == payload.col
        }
        .sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            return otherTitle(lhs) < otherTitle(rhs)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            GeometryReader { geo in
                diagram(width: geo.size.width)
            }
            .frame(height: 88)

            if related.isEmpty {
                Text("这个字与其余各柱没有\(payload.isStem ? "天干" : "地支")的合、冲、刑、害。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 2)
            } else {
                ForEach(related.prefix(6)) { hit in
                    compactRow(hit)
                }
                if related.count > 6 {
                    Text("另有 \(related.count - 6) 处未展开")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color(hexString: "#B3AEA7"))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.primary.opacity(0.06), lineWidth: 0.8))
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(payload.target.char)
                .font(Theme.ganzhi(24))
                .foregroundStyle(Theme.accent)
            Text(payload.isStem ? "天干" : "地支")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondaryText)
            Text("· \(selfTitle)")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondaryText)
            Text("\(related.count) 处")
                .font(.system(size: 10))
                .foregroundStyle(Color(hexString: "#B3AEA7"))
            Spacer()
            Button {
                onEditTags(payload.target.char)
            } label: {
                Label("编辑标签", systemImage: "tag")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 虚线示意

    private func diagram(width: CGFloat) -> some View {
        let colW: CGFloat = width >= 352 ? 41.5 : max(37, (width - 20) / 8)
        let labelW: CGFloat = 20
        let baseline: CGFloat = 56

        return Canvas { ctx, _ in
            // 8 列刻度 + 列名
            for i in 0..<8 {
                let x = labelW + colW * CGFloat(i) + colW / 2
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: baseline + 6))
                tick.addLine(to: CGPoint(x: x, y: baseline + 11))
                ctx.stroke(tick, with: .color(Color.primary.opacity(0.18)), lineWidth: 0.8)

                if payload.titles.indices.contains(i) {
                    let label = ctx.resolve(Text(payload.titles[i])
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hexString: "#B3AEA7")))
                    ctx.draw(label, at: CGPoint(x: x, y: baseline + 18), anchor: .center)
                }
            }

            let tx = labelW + colW * CGFloat(payload.col) + colW / 2

            // 目标字：朱砂浅底圆
            ctx.fill(Path(ellipseIn: CGRect(x: tx - 13, y: baseline - 13, width: 26, height: 26)),
                     with: .color(Theme.accent.opacity(0.10)))
            let targetText = ctx.resolve(Text(payload.target.char)
                .font(Theme.ganzhi(15))
                .foregroundStyle(Theme.accent))
            ctx.draw(targetText, at: CGPoint(x: tx, y: baseline), anchor: .center)

            // 每条关系一条虚线弧
            for hit in related {
                let ox = labelW + colW * CGFloat(otherCol(hit)) + colW / 2
                guard ox != tx else { continue }
                let midX = (tx + ox) / 2
                let lift = max(16, min(40, abs(tx - ox) * 0.30))
                let color = Color(red: hit.kind.colorRGB.r,
                                  green: hit.kind.colorRGB.g,
                                  blue: hit.kind.colorRGB.b)

                var curve = Path()
                curve.move(to: CGPoint(x: tx, y: baseline - 4))
                curve.addQuadCurve(to: CGPoint(x: ox, y: baseline - 4),
                                   control: CGPoint(x: midX, y: baseline - 4 - lift))
                ctx.stroke(curve, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [3, 3]))

                // 关系字（合/冲/刑/害）放在弧顶
                let kindText = ctx.resolve(Text(hit.kind.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color))
                ctx.draw(kindText, at: CGPoint(x: midX, y: baseline - 4 - lift + 7), anchor: .center)

                // 对方字
                let otherText = ctx.resolve(Text(otherChar(hit))
                    .font(Theme.ganzhi(13))
                    .foregroundStyle(Color.primary))
                ctx.draw(otherText, at: CGPoint(x: ox, y: baseline), anchor: .center)

                // 小圆点
                ctx.fill(Path(ellipseIn: CGRect(x: ox - 2, y: baseline - 4, width: 4, height: 4)),
                         with: .color(color.opacity(0.9)))
            }
        }
    }

    // MARK: 紧凑条目

    private func compactRow(_ hit: RelationHit) -> some View {
        let rgb = hit.kind.colorRGB
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(hit.kind.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                .frame(width: 14, alignment: .leading)
            Text(otherChar(hit))
                .font(Theme.ganzhi(13))
            Text(otherTitle(hit))
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondaryText)
            Text(tierText(hit.tier))
                .font(.system(size: 8.5))
                .foregroundStyle(Color(hexString: "#B3AEA7"))
                .padding(.horizontal, 3.5)
                .padding(.vertical, 0.5)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(hexString: "#D6D2CB"), lineWidth: 0.6))
            Text(hit.kind.explanation)
                .font(.system(size: 9.5))
                .foregroundStyle(Color(hexString: "#B3AEA7"))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: 辅助

    private func otherCol(_ hit: RelationHit) -> Int {
        hit.colA == payload.col ? hit.colB : hit.colA
    }

    private func otherTitle(_ hit: RelationHit) -> String {
        let i = otherCol(hit)
        return payload.titles.indices.contains(i) ? payload.titles[i] : "—"
    }

    private func otherChar(_ hit: RelationHit) -> String {
        let i = otherCol(hit)
        if payload.isStem, payload.stems.indices.contains(i) { return payload.stems[i] ?? "—" }
        if !payload.isStem, payload.branches.indices.contains(i) { return payload.branches[i] ?? "—" }
        return "—"
    }

    private var selfTitle: String {
        payload.titles.indices.contains(payload.col) ? payload.titles[payload.col] : ""
    }

    private func tierText(_ tier: RelationTier) -> String {
        switch tier {
        case .t1: return "本命"
        case .t2: return "流运"
        case .t2b: return "流日"
        case .t3: return "同气"
        }
    }
}
