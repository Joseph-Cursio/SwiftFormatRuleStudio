//
//  SwiftVersionArgumentOrderTests.swift
//  SwiftFormatRuleStudioCoreTests
//
//  The user's --swift-version wins, because it is passed last.
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Captures the arguments a model hands to the CLI.
private actor ArgumentRecorder: SwiftFormatCLIProtocol {
    private(set) var formatArguments: [[String]] = []
    private(set) var lintArguments: [[String]] = []

    func detectPath() throws -> URL { URL(fileURLWithPath: "/usr/bin/true") }
    func version() throws -> String { "0.62.1" }
    func rulesOutput() throws -> String { "" }
    func ruleInfoOutput(ruleName _: String) throws -> String { "" }
    func allRuleInfoOutput() throws -> String { "" }
    func optionsOutput() throws -> String { "" }

    func format(source: String, arguments: [String]) throws -> String {
        formatArguments.append(arguments)
        return source
    }

    func lint(path _: String, arguments: [String]) throws -> LintRun {
        lintArguments.append(arguments)
        return LintRun(reporterOutput: "[]", summary: "")
    }
}

private struct FixedSource: SourceFileReading {
    func readSource(at _: String) throws -> String { "let x = 1\n" }
}

/// `--swift-version` may be passed twice, and the last one wins.
///
/// SwiftFormat takes the last occurrence of a repeated flag — verified against 0.62.1:
/// `--swift-version 5.0 --swift-version 5.7` applies 5.7, and reversing the pair reverses the
/// result. Every model here prepends its own `swiftVersion` and then appends the user's
/// `extraArguments`, so a user who sets the flag themselves overrides the model. That ordering is
/// the whole mechanism, and nothing was checking it.
///
/// `ImpactModel.ruleDiff` used to carry an extra `!extraArguments.contains("--swift-version")`
/// condition to avoid emitting the flag twice. It changed no behaviour — with last-wins, skipping
/// the model's copy and being overridden by the user's produce the same effective version — and it
/// was the only one of four sites to have it, so it read as though the other three were missing
/// something. It is gone; these pin the property it was standing in for.
@Suite("A user's --swift-version overrides the model's")
struct SwiftVersionArgumentOrderTests {
    private func lastSwiftVersion(in arguments: [String]) -> String? {
        var found: String?
        for (index, argument) in arguments.enumerated() where argument == "--swift-version" {
            if index + 1 < arguments.count { found = arguments[index + 1] }
        }
        return found
    }

    @Test("ImpactModel.ruleDiff lets the user's version win")
    func impactRuleDiffUsesTheUsersVersion() async {
        let recorder = ArgumentRecorder()
        let model = ImpactModel(cli: recorder, reader: FixedSource(), swiftVersion: "5.10")
        model.extraArguments = ["--swift-version", "6.0"]

        _ = await model.ruleDiff(ruleID: "indent", filePath: "/tmp/x.swift")

        let arguments = await recorder.formatArguments.first ?? []
        #expect(lastSwiftVersion(in: arguments) == "6.0",
                "the user's version must be the effective one, in \(arguments)")
    }

    @Test("TuneModel.ruleDiff lets the user's version win")
    func tuneRuleDiffUsesTheUsersVersion() async {
        let recorder = ArgumentRecorder()
        let model = TuneModel(cli: recorder, reader: FixedSource(), swiftVersion: "5.10")
        model.extraArguments = ["--swift-version", "6.0"]

        _ = await model.ruleDiff(ruleID: "indent", filePath: "/tmp/x.swift")

        let arguments = await recorder.formatArguments.first ?? []
        #expect(lastSwiftVersion(in: arguments) == "6.0",
                "the user's version must be the effective one, in \(arguments)")
    }

    /// The two drill-downs are the same computation in two models, so they must agree about
    /// which version they run under. They differed in spelling for a while and agreed in effect;
    /// this is what makes that agreement checkable rather than coincidental.
    @Test("both drill-downs resolve to the same version")
    func bothModelsAgree() async {
        let impactRecorder = ArgumentRecorder()
        let impact = ImpactModel(cli: impactRecorder, reader: FixedSource(), swiftVersion: "5.10")
        impact.extraArguments = ["--swift-version", "6.0"]
        _ = await impact.ruleDiff(ruleID: "indent", filePath: "/tmp/x.swift")

        let tuneRecorder = ArgumentRecorder()
        let tune = TuneModel(cli: tuneRecorder, reader: FixedSource(), swiftVersion: "5.10")
        tune.extraArguments = ["--swift-version", "6.0"]
        _ = await tune.ruleDiff(ruleID: "indent", filePath: "/tmp/x.swift")

        let impactVersion = lastSwiftVersion(in: await impactRecorder.formatArguments.first ?? [])
        let tuneVersion = lastSwiftVersion(in: await tuneRecorder.formatArguments.first ?? [])
        #expect(impactVersion == tuneVersion)
    }

    /// With no user override, the model's own version is the one that applies.
    @Test("the model's version applies when the user sets none")
    func modelVersionAppliesWithoutOverride() async {
        let recorder = ArgumentRecorder()
        let model = TuneModel(cli: recorder, reader: FixedSource(), swiftVersion: "5.10")

        _ = await model.ruleDiff(ruleID: "indent", filePath: "/tmp/x.swift")

        let arguments = await recorder.formatArguments.first ?? []
        #expect(lastSwiftVersion(in: arguments) == "5.10")
    }
}
