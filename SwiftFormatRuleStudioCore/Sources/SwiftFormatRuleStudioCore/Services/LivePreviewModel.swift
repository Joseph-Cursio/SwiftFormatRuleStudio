//
//  LivePreviewModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import LintStudioCore
import Observation

/// The observable model behind the live code preview (M3): holds editable
/// source, runs `swiftformat stdin` (debounced), and exposes the before/after
/// diff. Lives in Core so the formatting + diff logic is unit-testable; the view
/// is a thin editor + diff renderer.
@MainActor
@Observable
public final class LivePreviewModel {
    public enum PreviewState: Equatable, Sendable {
        case idle
        case formatting
        case formatted
        case failed(String)
    }

    /// The editable source. Call `scheduleFormat()` (debounced) on change.
    public var source: String

    /// The Swift version passed as `--swift-version`. SwiftFormat disables some
    /// rules without it, so it's worth always supplying.
    public var swiftVersion: String?

    /// Extra `swiftformat` arguments — typically the active `.swiftformat`
    /// config's `commandLineArguments`, so the preview reflects the user's
    /// edited settings rather than SwiftFormat's defaults.
    public var extraArguments: [String] = []

    public private(set) var formattedSource: String = ""
    public private(set) var diff: [PreviewDiffLine] = []
    public private(set) var state: PreviewState = .idle

    private let cli: any SwiftFormatCLIProtocol
    private let debounceNanoseconds: UInt64
    private var pendingFormat: Task<Void, Never>?

    public init(
        cli: any SwiftFormatCLIProtocol = SwiftFormatCLIActor(),
        source: String = "",
        swiftVersion: String? = "5.10",
        debounceMilliseconds: UInt64 = 350
    ) {
        self.cli = cli
        self.source = source
        self.swiftVersion = swiftVersion
        self.debounceNanoseconds = debounceMilliseconds * 1_000_000
    }

    /// Whether formatting would change anything.
    public var hasChanges: Bool {
        diff.contains { $0.change != .unchanged }
    }

    /// The arguments passed to `swiftformat` for the current settings.
    var formatArguments: [String] {
        var arguments = ["stdin"]
        // Don't double-set the Swift version if the config already provides it.
        if let swiftVersion, !swiftVersion.isEmpty, !extraArguments.contains("--swift-version") {
            arguments += ["--swift-version", swiftVersion]
        }
        arguments += extraArguments
        return arguments
    }

    /// Formats the current `source` immediately and recomputes the diff.
    public func formatNow() async {
        let input = source
        state = .formatting
        do {
            let output = try await cli.format(source: input, arguments: formatArguments)
            formattedSource = output
            diff = PreviewDiffLine.lines(from: UnifiedDiffEngine.computeDiff(before: input, after: output))
            state = .formatted
        } catch {
            formattedSource = ""
            diff = []
            state = .failed(error.localizedDescription)
        }
    }

    /// Debounced format trigger — call from the editor's `onChange`. Cancels any
    /// in-flight debounce so only the latest edit formats.
    public func scheduleFormat() {
        pendingFormat?.cancel()
        pendingFormat = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            if Task.isCancelled { return }
            await formatNow()
        }
    }
}
