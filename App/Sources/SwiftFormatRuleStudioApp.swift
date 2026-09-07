//
//  SwiftFormatRuleStudioApp.swift
//  SwiftFormatRuleStudio
//

import SwiftUI

@main
struct SwiftFormatRuleStudioApp: App {
    // Text-size step for the Rules panel, shared with ContentView via AppStorage.
    @AppStorage("rulesTextSizeStep") private var textSizeStep = 0

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Larger Text") { step(by: 1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Smaller Text") { step(by: -1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { resetTextSize() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
            }
        }
    }

    /// The clamp lives in `TextSizeStep.stepping(_:by:)`, which is a total function under test.
    /// What is left here is the store, and `@AppStorage` writes straight through to the defaults
    /// store — so this method is reachable from a test in a way a `@State` write would not be.
    private func step(by delta: Int) {
        textSizeStep = TextSizeStep.stepping(textSizeStep, by: delta)
    }

    private func resetTextSize() {
        textSizeStep = TextSizeStep.actualSize
    }
}
