//
//  OptionRuleUsageTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("OptionRuleUsage")
struct OptionRuleUsageTests {
    @Test("Known options map to their rule(s)")
    func lookups() {
        #expect(OptionRuleUsage.rules(forOptionKey: "self") == ["redundantSelf"])
        #expect(OptionRuleUsage.rules(forOptionKey: "indent") == ["indent"])
        #expect(OptionRuleUsage.rules(forOptionKey: "property-types") == ["propertyTypes", "redundantType"])
        #expect(OptionRuleUsage.rules(forOptionKey: "does-not-exist").isEmpty)
    }

    @Test("Every entry maps to at least one rule")
    func noEmptyEntries() {
        #expect(OptionRuleUsage.rulesByOptionKey.values.allSatisfy { !$0.isEmpty })
    }
}

/// Validates the curated table against the installed SwiftFormat: every
/// `--options` entry must be attributed, and to the same rule(s) `--ruleinfo`
/// reports. Skips when SwiftFormat isn't installed.
@Suite("OptionRuleUsage Integration")
struct OptionRuleUsageIntegrationTests {
    @Test("Curated table matches the live catalog")
    func matchesLiveCatalog() async throws {
        let actor = SwiftFormatCLIActor()
        do {
            _ = try await actor.detectPath()
        } catch {
            return // not installed; skip
        }

        let options = OptionsParser.parse(try await actor.optionsOutput())
        let entries = RuleListParser.parse(try await actor.rulesOutput())

        // Build the live option→rules map from every rule's ruleinfo.
        var live: [String: [String]] = [:]
        for entry in entries {
            let info = RuleInfoParser.parse(try await actor.ruleInfoOutput(ruleName: entry.name))
            for option in info.relatedOptions {
                let key = option.hasPrefix("--") ? String(option.dropFirst(2)) : option
                live[key, default: []].append(entry.name)
            }
        }

        for option in options {
            let curated = Set(OptionRuleUsage.rules(forOptionKey: option.key))
            #expect(curated.isEmpty == false, "\(option.name) has no curated rule")
            #expect(curated == Set(live[option.key] ?? []), "mismatch for \(option.name)")
        }
    }
}
