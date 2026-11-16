//
//  EventListView.swift
//  全部事迹记录（v8）：按日期倒序，可点开编辑、左滑删除
//

import SwiftUI

struct EventListView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppModel
    @ObservedObject private var store = EventStore.shared

    @State private var pendingDelete: EventRecord?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    VStack(spacing: 10) {
                        Text("还没有事迹记录")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.secondaryText)
                        Text("记下已经发生的事，之后走到相同干支时会提醒你回顾")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.items) { record in
                            row(record)
                                .contentShape(Rectangle())
                                .onTapGesture { app.route = .editEvent(record) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDelete = record
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("事迹记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        app.route = .newEvent(anchor: Date().startOfBeijingDay)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("删除这条事迹？",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let r = pendingDelete { store.delete(id: r.id) }
                    pendingDelete = nil
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("删除后无法恢复")
            }
        }
    }

    private func row(_ record: EventRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(record.title)
                    .font(.system(size: 14.5))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if !record.notifyOnMatch {
                    Text("不提醒")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }
            Text("\(Self.dateFormatter.string(from: record.day)) · \(record.pillarLine)")
                .font(.system(size: 10.5))
                .foregroundStyle(Color(hexString: "#B3AEA7"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 3)
    }
}
