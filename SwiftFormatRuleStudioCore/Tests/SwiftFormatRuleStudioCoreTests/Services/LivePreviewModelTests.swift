//
//  LivePreviewModelTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import SwiftFormatRuleStudioCoreTestSupport
import Testing

@Suite("LivePreviewModel")
@MainActor
struct LivePreviewModelTests {
    /// A fixed isolation file, so the `--config` flag every invocation carries is
    /// assertable by path (production uses `.shared`).
    private static let isolation = ConfigIsolation(
        path: FileManager.default.temporaryDirectory
            .appendingPathComponent("SFRSLivePreviewIsolation.swiftformat").path
    )
    private static let config = isolation.arguments

    private func makeModel(
        source: String,
        formatOverride: String? = nil,
        failWith: SwiftFormatError? = nil,
        swiftVersion: String? = "5.10"
    ) -> (LivePreviewModel, MockSwiftFormatCLI) {
        let cli = MockSwiftFormatCLI(failWith: failWith, formatOverride: formatOverride)
        let model = LivePreviewModel(
            cli: cli,
            source: source,
            swiftVersion: swiftVersion,
            configIsolation: Self.isolation
        )
        return (model, cli)
    }

    @Test("Formatting that changes the source produces a diff")
    func formatsWithChanges() async {
        let (model, _) = makeModel(source: "let x=1", formatOverride: "let x = 1")
        await model.formatNow()

        #expect(model.state == .formatted)
        #expect(model.formattedSource == "let x = 1")
        #expect(model.hasChanges)
        #expect(model.diff.contains { $0.change == .added })
        #expect(model.diff.contains { $0.change == .removed })
    }

    @Test("A no-op format reports no changes")
    func formatsNoOp() async {
        let (model, _) = makeModel(source: "let x = 1") // no override → echoes input
        await model.formatNow()

        #expect(model.state == .formatted)
        #expect(model.formattedSource == "let x = 1")
        #expect(model.hasChanges == false)
        #expect(model.diff.allSatisfy { $0.change == .unchanged })
    }

    @Test("A formatting failure surfaces .failed and clears output")
    func formatFails() async {
        let (model, _) = makeModel(source: "let x=1", failWith: .notFound)
        await model.formatNow()

        guard case .failed = model.state else {
            Issue.record("expected .failed, got \(model.state)")
            return
        }
        #expect(model.formattedSource.isEmpty)
        #expect(model.diff.isEmpty)
    }

    @Test("swiftVersion is passed as --swift-version")
    func passesSwiftVersion() async {
        let (model, cli) = makeModel(source: "x", swiftVersion: "5.10")
        await model.formatNow()

        let args = await cli.lastFormatArguments
        #expect(args == ["stdin"] + Self.config + ["--swift-version", "5.10"])
    }

    @Test("No --swift-version flag when version is nil")
    func omitsSwiftVersionWhenNil() async {
        let (model, cli) = makeModel(source: "x", swiftVersion: nil)
        await model.formatNow()

        let args = await cli.lastFormatArguments
        #expect(args == ["stdin"] + Self.config)
    }

    @Test("extraArguments (the active config) are appended")
    func appendsExtraArguments() async {
        let (model, cli) = makeModel(source: "x", swiftVersion: "5.10")
        model.extraArguments = ["--indent", "4", "--disable", "redundantSelf"]
        await model.formatNow()

        let args = await cli.lastFormatArguments
        #expect(args == ["stdin"] + Self.config
            + ["--swift-version", "5.10", "--indent", "4", "--disable", "redundantSelf"])
    }

    @Test("Config-provided --swift-version is not duplicated")
    func swiftVersionNotDuplicated() async {
        let (model, cli) = makeModel(source: "x", swiftVersion: "5.10")
        model.extraArguments = ["--swift-version", "6.0", "--indent", "4"]
        await model.formatNow()

        let args = await cli.lastFormatArguments
        #expect(args == ["stdin"] + Self.config + ["--swift-version", "6.0", "--indent", "4"])
    }

    @Test("stdinPath is passed as --stdin-path, right after stdin")
    func passesStdinPath() async {
        let (model, cli) = makeModel(source: "x", swiftVersion: "5.10")
        model.stdinPath = "/ws/Sources/Foo.swift"
        await model.formatNow()

        let args = await cli.lastFormatArguments
        #expect(args == ["stdin"] + Self.config
            + ["--stdin-path", "/ws/Sources/Foo.swift", "--swift-version", "5.10"])
    }

    // MARK: - Fragment fallback

    /// A CLI that rejects any format without `--fragment`, as SwiftFormat rejects a
    /// bare snippet that is not a complete file.
    private func fragmentOnlyModel() -> (LivePreviewModel, MockSwiftFormatCLI) {
        let failure: @Sendable ([String]) -> SwiftFormatError? = { args in
            args.contains("--fragment") ? nil : .executionFailed(message: "unexpected end of file")
        }
        let cli = MockSwiftFormatCLI(formatOverride: "let x = 1", formatFailureForArguments: failure)
        let model = LivePreviewModel(cli: cli, source: "let x=1", swiftVersion: nil, configIsolation: Self.isolation)
        return (model, cli)
    }

    @Test("With fragmentFallback, a failed format is retried once with --fragment true")
    func fragmentFallbackRetries() async {
        let (model, cli) = fragmentOnlyModel()
        model.fragmentFallback = true
        await model.formatNow()

        #expect(model.state == .formatted)
        #expect(model.formattedSource == "let x = 1")
        #expect(await cli.formatCallCount == 2)
        #expect(await cli.lastFormatArguments == ["stdin"] + Self.config + ["--fragment", "true"])
    }

    @Test("Without fragmentFallback, a failed format fails without a retry")
    func noFragmentFallbackFails() async {
        let (model, cli) = fragmentOnlyModel()
        await model.formatNow()

        #expect(model.state == .failed(SwiftFormatError.executionFailed(message: "unexpected end of file")
            .localizedDescription))
        #expect(await cli.formatCallCount == 1)
    }

    @Test("A format that already passed --fragment is not retried")
    func fragmentFormatIsNotRetried() async {
        let (model, cli) = makeModel(source: "let x=1", failWith: .executionFailed(message: "bad"))
        model.fragmentFallback = true
        model.extraArguments = ["--fragment", "true"]
        await model.formatNow()

        guard case .failed = model.state else {
            Issue.record("expected .failed, got \(model.state)")
            return
        }
        #expect(await cli.formatCallCount == 1)
    }

    // MARK: - Debounce

    @Test("A scheduled format runs once the debounce elapses")
    func scheduledFormatRuns() async throws {
        let cli = MockSwiftFormatCLI(formatOverride: "let x = 1")
        let model = LivePreviewModel(
            cli: cli, source: "let x=1", debounceMilliseconds: 1, configIsolation: Self.isolation
        )
        model.scheduleFormat()
        for _ in 0 ..< 400 where model.state != .formatted {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        #expect(model.state == .formatted)
        #expect(model.formattedSource == "let x = 1")
    }
}

/// Exercises real `swiftformat stdin` formatting end-to-end. Skips when
/// SwiftFormat is not installed.
@Suite("SwiftFormatCLIActor format Integration")
struct SwiftFormatFormatIntegrationTests {
    @Test("Formats a messy snippet via the real binary")
    func formatsViaRealBinary() async throws {
        let actor = SwiftFormatCLIActor()
        do {
            _ = try await actor.detectPath()
        } catch {
            return // not installed; skip
        }

        let messy = "struct  Foo{\nlet x=1\n}\n"
        let formatted = try await actor.format(source: messy, arguments: ["stdin", "--swift-version", "5.10"])

        #expect(formatted.contains("struct Foo {"))
        #expect(formatted.contains("let x = 1"))
    }
}
