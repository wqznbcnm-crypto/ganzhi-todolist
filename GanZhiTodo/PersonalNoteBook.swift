//
//  PersonalNoteBook.swift
//  个人命理笔记的可观察状态（App 内共享）
//

import SwiftUI

@MainActor
final class PersonalNoteBook: ObservableObject {

    static let shared = PersonalNoteBook()

    /// 命理笔记总开关（关闭时首页始终显示万年历内容）
    @Published var enabled: Bool {
        didSet { PersonalNoteStorage.isEnabled = enabled }
    }

    /// 以单字（天干/地支）为键
    @Published private(set) var entries: [String: PersonalNote]

    private init() {
        self.enabled = PersonalNoteStorage.isEnabled
        self.entries = PersonalNoteStorage.load()
    }

    func note(for char: String) -> PersonalNote {
        entries[char] ?? PersonalNote()
    }

    func setNote(_ note: PersonalNote, for char: String) {
        var next = entries
        if note.isEmpty { next.removeValue(forKey: char) } else { next[char] = note }
        entries = next
        PersonalNoteStorage.save(next)
    }

    func clearAll() {
        entries = [:]
        PersonalNoteStorage.save([:])
    }

    /// 当天命中的笔记（关闭开关时恒为 nil）
    func hit(for day: Date, lateZi: Bool) -> PersonalNoteHit? {
        guard enabled else { return nil }
        return PersonalNoteMatcher.hit(for: day, lateZi: lateZi, entries: entries)
    }

    /// 已填写内容的字数统计（设置页展示用）
    var filledCount: Int {
        entries.values.filter { !$0.isEmpty }.count
    }
}
