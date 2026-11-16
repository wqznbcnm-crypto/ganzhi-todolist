//
//  PersonalNoteBookView.swift
//  「我的命理笔记」：选天干/地支 → 编辑该字的宜做、忌做标签
//  纯个人记录，不做吉凶判定
//

import SwiftUI

struct PersonalNoteBookView: View {

    @EnvironmentObject var book: PersonalNoteBook

    @State private var editingChar: String?
    /// v8：批量编辑
    @State private var showBatch = false

    private var stemRows: [String] { NoteCatalog.stems }
    private var branchRows: [String] { NoteCatalog.branches }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $book.enabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("个人命理笔记")
                        Text(book.enabled ? "首页命中已填写的天干/地支时，优先展示你写的宜忌"
                                          : "关闭后首页只显示万年历内容")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("总开关")
            } footer: {
                Text("仅作个人记录，与历法吉凶判定无关。已填写 \(book.filledCount) 个字。")
            }

            Section {
                ForEach(stemRows, id: \.self) { char in
                    row(char: char, kind: "天干")
                }
            } header: {
                Text("天干")
            } footer: {
                Text("某天的日干、流月干或流年干命中这里填过的字，首页宜忌区就换成你的内容。")
            }

            Section {
                ForEach(branchRows, id: \.self) { char in
                    row(char: char, kind: "地支")
                }
            } header: {
                Text("地支")
            } footer: {
                Text(NoteCatalog.disclaimer)
            }

            if book.filledCount > 0 {
                Section {
                    Button(role: .destructive) {
                        book.clearAll()
                    } label: {
                        Text("清空全部笔记")
                    }
                }
            }
        }
        .navigationTitle("我的命理笔记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("批量") { showBatch = true }
                    .font(.system(size: 14))
            }
        }
        .sheet(isPresented: $showBatch) {
            BatchNoteEditView()
        }
        .sheet(item: Binding(
            get: { editingChar.map { CharBox(char: $0) } },
            set: { editingChar = $0?.char }
        )) { box in
            PersonalNoteEditorView(char: box.char)
        }
    }

    /// sheet(item:) 需要一个 Identifiable 包装
    private struct CharBox: Identifiable {
        let char: String
        var id: String { char }
    }

    private func row(char: String, kind: String) -> some View {
        let note = book.note(for: char)
        return Button {
            editingChar = char
        } label: {
            HStack(spacing: 12) {
                Text(char)
                    .font(Theme.ganzhi(22))
                    .foregroundStyle(Theme.element(element(for: char)))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(summary(note))
                        .font(.system(size: 12))
                        .foregroundStyle(note.isEmpty ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }
                Spacer()
                if !note.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent.opacity(0.7))
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func summary(_ note: PersonalNote) -> String {
        if note.isEmpty { return "未填写" }
        var parts: [String] = []
        if !note.yi.isEmpty { parts.append("宜 \(note.yi.prefix(3).joined(separator: "、"))") }
        if !note.ji.isEmpty { parts.append("忌 \(note.ji.prefix(3).joined(separator: "、"))") }
        return parts.joined(separator: " · ")
    }

    private func element(for char: String) -> WuXing {
        if let i = NoteCatalog.stems.firstIndex(of: char) { return WuXing.ofStem(i) }
        if let i = NoteCatalog.branches.firstIndex(of: char) { return WuXing.ofBranch(i) }
        return .earth
    }
}

// MARK: - 单个字的标签编辑

struct PersonalNoteEditorView: View {

    @EnvironmentObject var book: PersonalNoteBook
    @Environment(\.dismiss) private var dismiss

    let char: String

    @State private var yi: [String] = []
    @State private var ji: [String] = []
    @State private var customYi = ""
    @State private var customJi = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    tagSection(title: "宜做事项", tint: Theme.accent,
                               presets: NoteCatalog.yiPresets, selected: $yi, custom: $customYi)
                    tagSection(title: "忌做事项", tint: Color(hexString: "#3A3A3A"),
                               presets: NoteCatalog.jiPresets, selected: $ji, custom: $customJi)
                    Text("这里只记录你自己的经验，App 不会据此推算吉凶，也不会与万年历宜忌自动合并。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hexString: "#B3AEA7"))
                        .lineSpacing(2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("\(char) 的笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        book.setNote(PersonalNote(yi: yi, ji: ji), for: char)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            let note = book.note(for: char)
            yi = note.yi
            ji = note.ji
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(char)
                .font(Theme.ganzhi(34))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("为你自己的这个字添加生活标签")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                Text("可多选预制项，也可自己写")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func tagSection(title: String, tint: Color, presets: [String],
                            selected: Binding<[String]>, custom: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Circle().fill(tint).frame(width: 18, height: 18)
                    .overlay(Text(String(title.prefix(1)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white))
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Spacer()
                Text("\(selected.wrappedValue.count) 项")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // 已选（可点掉）
            if !selected.wrappedValue.isEmpty {
                NoteChipFlow(spacing: 6) {
                    ForEach(selected.wrappedValue, id: \.self) { tag in
                        Button {
                            selected.wrappedValue.removeAll { $0 == tag }
                        } label: {
                            chip(tag, tint: tint, filled: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 预制标签（已选的已在上面展示，不重复占位）
            NoteChipFlow(spacing: 6) {
                ForEach(presets.filter { !selected.wrappedValue.contains($0) }, id: \.self) { tag in
                    Button {
                        toggle(tag, in: selected)
                    } label: {
                        chip(tag, tint: tint, filled: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 自定义
            HStack(spacing: 8) {
                TextField("自定义标签，如「爬山」", text: custom)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.045)))
                Button {
                    let t = custom.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    if !selected.wrappedValue.contains(t) { selected.wrappedValue.append(t) }
                    custom.wrappedValue = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(tint))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.025)))
    }

    private func toggle(_ tag: String, in selected: Binding<[String]>) {
        if let idx = selected.wrappedValue.firstIndex(of: tag) {
            selected.wrappedValue.remove(at: idx)
        } else {
            selected.wrappedValue.append(tag)
        }
    }

    private func chip(_ text: String, tint: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(filled ? .white : Color.primary.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(filled ? tint : Color.primary.opacity(0.05))
            )
            .overlay(Capsule().stroke(filled ? tint.opacity(0) : Color.primary.opacity(0.08), lineWidth: 0.8))
    }
}

// MARK: - 简易流式布局（标签自动换行）

struct NoteChipFlow: Layout {

    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
