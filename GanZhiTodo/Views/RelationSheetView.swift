//
//  RelationSheetView.swift
//  点某个干/支字后弹出：只列与该字相关的关系
//  （设计稿 v4：替代原来的常驻连线与整段「刑冲合害」文字说明）
//

import SwiftUI

/// 用户点中的那个字
struct RelationTarget: Identifiable, Equatable {
    /// 列序号 0–7
    let col: Int
    /// true = 天干行，false = 地支行
    let isStem: Bool
    let char: String

    var id: String { "\(col)-\(isStem)" }
}

/// 打开弹层时一次性算好的数据（关系不在每次 body 重算）
struct RelationPayload: Identifiable {
    let target: RelationTarget
    let hits: [RelationHit]
    let titles: [String]
    let stems: [String?]
    let branches: [String?]

    var id: String { target.id }
    var isStem: Bool { target.isStem }
    var col: Int { target.col }
}

struct RelationSheetView: View {

    @Environment(\.dismiss) private var dismiss

    let payload: RelationPayload

    /// 只保留与该字相关、且同属干/支的那几条
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if related.isEmpty {
                        Text("这个字与其余各柱没有\(payload.isStem ? "天干" : "地支")的合、冲、刑、害。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.top, 18)
                    } else {
                        ForEach(related) { hit in
                            row(hit)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(payload.target.char)
                    .font(Theme.ganzhi(30))
                Text(payload.isStem ? "天干" : "地支")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                Text("· \(selfTitle)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(related.count) 处")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
            }
            Text("只列出与这个字直接相关的关系，同柱的干与支不互算。")
                .font(.system(size: 10))
                .foregroundStyle(Color(hexString: "#B3AEA7"))
        }
        .padding(.bottom, 4)
    }

    private func row(_ hit: RelationHit) -> some View {
        let rgb = hit.kind.colorRGB
        return HStack(alignment: .top, spacing: 10) {
            Text(hit.kind.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(otherChar(hit))
                        .font(Theme.ganzhi(15))
                    Text(otherTitle(hit))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.secondaryText)
                    Text(tierText(hit.tier))
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hexString: "#B3AEA7"))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(hexString: "#D6D2CB"), lineWidth: 0.6))
                }
                Text(hit.kind.explanation)
                    .font(.system(size: 10))
                    .lineSpacing(2)
                    .foregroundStyle(Color(hexString: "#B3AEA7"))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 1)
        }
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
