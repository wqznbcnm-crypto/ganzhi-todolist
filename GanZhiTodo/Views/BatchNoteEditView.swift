//
//  BatchNoteEditView.swift
//  批量编辑流日干支标签（v8）：
//  按「天干 / 地支」筛选，多选若干个字，一次把宜/忌标签写进这些字。
//  标签全部由用户自己录入，App 不生成任何吉凶结论。
//

import SwiftUI

struct BatchNoteEditView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var noteBook: PersonalNoteBook

    /// 0 = 天干，1 = 地支
    @State private var scope = 0
    @State private var selected: Set<String> = []
    /// 写入宜还是忌
    @State private var target = 0
    @State private var customText = ""
    /// 待写入的标签（本次批量新增的）
    @State private var pending: [String] = []

    private var chars: [String] {
        scope == 0 ? NoteCatalog.stems : NoteCatalog.branches
    }

    private var presets: [String] {
        target == 0 ? NoteCatalog.yiPresets : NoteCatalog.jiPresets
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scopeBlock
                    charBlock
                    targetBlock
                    tagBlock
                }
                .padding(.horizontal, Theme.hPadding)
                .padding(.top, 8)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("批量编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") { apply() }
                        .fontWeight(.semibold)
                        .disabled(selected.isEmpty || pending.isEmpty)
                }
            }
        }
    }

    // MARK: 范围

    private var scopeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("① 按哪类字筛选")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            Picker("", selection: $scope) {
                Text("天干").tag(0)
                Text("地支").tag(1)
            }
            .pickerStyle(.segmented)
            .onChangeCompat(of: scope) { _ in selected.removeAll() }
        }
    }

    // MARK: 选字

    private var charBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("② 选中要一起改的字")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Button(selected.count == chars.count ? "全不选" : "全选") {
                    selected = selected.count == chars.count ? [] : Set(chars)
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.accent)
            }

            FlowGrid(items: chars, spacing: 8) { char in
                let on = selected.contains(char)
                Button {
                    if on { selected.remove(char) } else { selected.insert(char) }
                } label: {
                    Text(char)
                        .font(Theme.ganzhi(15))
                        .foregroundStyle(on ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(on ? Theme.accent : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            Text("已选 \(selected.count) 个")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: 宜 / 忌

    private var targetBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("③ 写宜还是忌")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            Picker("", selection: $target) {
                Text("宜做事项").tag(0)
                Text("忌做事项").tag(1)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: 标签

    private var tagBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("④ 要加上的标签")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            FlowGrid(items: presets, spacing: 7) { tag in
                let on = pending.contains(tag)
                Button {
                    if on { pending.removeAll { $0 == tag } } else { pending.append(tag) }
                } label: {
                    Text(tag)
                        .font(.system(size: 12.5))
                        .foregroundStyle(on ? .white : Theme.secondaryText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(on ? Theme.accent : Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("自定义标签（如 爬山）", text: $customText)
                    .font(.system(size: 13.5))
                    .padding(.horizontal, 11)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.04)))
                    .onSubmit { addCustom() }
                Button("添加") { addCustom() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.accent))
                    .buttonStyle(.plain)
                    .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !pending.isEmpty {
                Text("将写入：" + pending.joined(separator: "、"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func addCustom() {
        let t = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if !pending.contains(t) { pending.append(t) }
        customText = ""
    }

    // MARK: 应用

    private func apply() {
        for char in selected {
            var note = noteBook.note(for: char)
            if target == 0 {
                for tag in pending where !note.yi.contains(tag) { note.yi.append(tag) }
            } else {
                for tag in pending where !note.ji.contains(tag) { note.ji.append(tag) }
            }
            noteBook.setNote(note, for: char)
        }
        dismiss()
    }
}

// MARK: - 简易流式布局（等宽网格，够用且不引入第三方）

struct FlowGrid<Item: Hashable, Content: View>: View {

    let items: [Item]
    var spacing: CGFloat = 8
    @ViewBuilder var content: (Item) -> Content

    private let columns = [GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
