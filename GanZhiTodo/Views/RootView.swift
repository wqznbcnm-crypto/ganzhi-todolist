//
//  RootView.swift
//  根视图：导航 + 统一弹层路由
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var app: AppModel

    var body: some View {
        NavigationStack {
            MonthCalendarView()
                .navigationDestination(for: Date.self) { day in
                    DayDetailView(day: day)
                }
        }
        .sheet(item: $app.route) { route in
            Group {
                switch route {
                case .voice(let anchor):
                    VoiceCaptureView(anchor: anchor)
                case .newTodo(let day):
                    TodoEditorView(day: day)
                case .editTodo(let item):
                    TodoEditorView(item: item)
                case .settings:
                    SettingsView()
                }
            }
        }
        .onAppear {
            app.consumePendingVoiceFlag()
        }
    }
}
