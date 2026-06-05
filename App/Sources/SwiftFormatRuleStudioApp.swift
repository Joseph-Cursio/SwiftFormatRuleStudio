//
//  SwiftFormatRuleStudioApp.swift
//  SwiftFormatRuleStudio
//

import SwiftUI

@main
struct SwiftFormatRuleStudioApp: App {
    // Text-size step for the Rules panel, shared with ContentView via AppStorage.
    @AppStorage("rulesTextSizeStep") private var textSizeStep = 0

    private let minStep = -3
    private let maxStep = 6

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Larger Text") { textSizeStep = min(textSizeStep + 1, maxStep) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Smaller Text") { textSizeStep = max(textSizeStep - 1, minStep) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { textSizeStep = 0 }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
            }
        }
    }
}
