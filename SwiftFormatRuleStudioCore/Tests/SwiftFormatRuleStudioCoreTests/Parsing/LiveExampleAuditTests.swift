//
//  LiveExampleAuditTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Measures, against the installed SwiftFormat, how many rules produce a useful
/// *live* example: the reconstructed `exampleBeforeSource`, re-formatted with
/// only that rule enabled, must actually change. The rules that DON'T are the
/// candidates for a curated hand-authored snippet. Prints a categorized report;
/// skips when SwiftFormat isn't installed.
@Suite("Live example audit")
struct LiveExampleAuditTests {
    @Test("Report rules whose live example does not change at defaults")
    func auditLiveExamples() async throws {
        let actor = SwiftFormatCLIActor()
        do {
            _ = try await actor.detectPath()
        } catch {
            return // not installed; skip
        }

        let entries = RuleListParser.parse(try await actor.rulesOutput())

        var noExample: [String] = []
        var noReconstruct: [String] = []
        var noChange: [String] = []
        var changed: [String] = []

        for entry in entries {
            let info = RuleInfoParser.parse(try await actor.ruleInfoOutput(ruleName: entry.name))
            let rule = FormatRule(name: entry.name, ruleDescription: info.ruleDescription, example: info.example)

            // Resolve through the curated→auto fallback the app actually uses.
            guard let before = rule.liveExampleSource else {
                if rule.example == nil { noExample.append(entry.name) } else { noReconstruct.append(entry.name) }
                continue
            }

            // No-fragment first (fragment suppresses scope rules), then fall back.
            let base = ["stdin", "--rules", entry.name, "--swift-version", "5.10"]
            var after = try? await actor.format(source: before, arguments: base)
            if after == nil {
                after = try? await actor.format(source: before, arguments: base + ["--fragment", "true"])
            }
            let result = after ?? before
            if result.trimmingCharacters(in: .newlines) == before.trimmingCharacters(in: .newlines) {
                noChange.append(entry.name)
            } else {
                changed.append(entry.name)
            }
        }

        print("=== LIVE EXAMPLE AUDIT (\(entries.count) rules) ===")
        print("OK (reconstructs AND changes): \(changed.count)")
        print("no example:                    \(noExample.count)  \(noExample)")
        print("no reconstruct:                \(noReconstruct.count)  \(noReconstruct)")
        print("reconstructs but NO change:    \(noChange.count)  \(noChange)")

        #expect(changed.isEmpty == false)
    }
}
