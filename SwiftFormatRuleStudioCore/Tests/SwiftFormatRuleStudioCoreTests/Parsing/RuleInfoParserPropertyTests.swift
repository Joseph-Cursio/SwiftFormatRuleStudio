//
//  RuleInfoParserPropertyTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

/// Structure-first round-trips: generate what `--ruleinfo` describes, lay it out as text, parse it
/// back, and get the structure again.
///
/// `RuleInfoParser` has no printer, so the layout is written here. The point of writing it is the
/// optional blank lines: every separator between sections is drawn at random. The fixtures in
/// `RuleInfoParserTests` always put a blank line between sections, which left the code handling a
/// *missing* separator — a header directly under the description, an example directly under
/// `Examples:` — free to be wrong.
@Suite("RuleInfoParser properties")
struct RuleInfoParserPropertyTests {
    private static let words = ["Remove", "the", "redundant", "keyword", "when", "safe", "Prefer", "commas"]

    private static func descriptionLines(_ gen: inout SplitMix64) -> [String] {
        (0..<gen.int(in: 1...3)).map { _ in
            (0..<gen.int(in: 1...4)).map { _ in gen.pick(words) }.joined(separator: " ")
        }
    }

    private static func exampleLines(_ gen: inout SplitMix64) -> [String] {
        (0..<gen.int(in: 1...4)).map { _ in
            gen.pick(["- ", "+ ", "  ", "\t"]) + gen.pick(["let a = 1", "foo()", "x"])
        }
    }

    @Test("parse recovers the name, description, options and example, with or without blank lines")
    func ruleInfoRoundTrips() {
        var gen = SplitMix64(seed: 0xD00D)
        for _ in 0..<300 {
            let name = "rule\(gen.int(in: 0...99))"
            let description = Self.descriptionLines(&gen)
            let options = (0..<gen.int(in: 0...3)).map { "--opt\($0)" }
            let example = gen.bool() ? Self.exampleLines(&gen) : []

            var lines = [name]
            if gen.bool() { lines.append("") }
            lines += description
            if !options.isEmpty {
                if gen.bool() { lines.append("") }
                lines.append("Options:")
                lines += options.map { "\($0)  Does a thing" }
            }
            if !example.isEmpty {
                if gen.bool() { lines.append("") }
                lines.append("Examples:")
                if gen.bool() { lines.append("") }
                lines += example
            }
            let text = lines.joined(separator: "\n")

            let parsed = RuleInfoParser.parse(text)
            #expect(parsed.name == name)
            #expect(parsed.ruleDescription == description.joined(separator: " "), "\(text)")
            #expect(parsed.relatedOptions == options)
            #expect(parsed.example == (example.isEmpty ? nil : example.joined(separator: "\n")), "\(text)")
        }
    }

    @Test("Bulk descriptions end at a header or the next rule, with or without a blank line")
    func bulkDescriptionsRoundTrip() {
        var gen = SplitMix64(seed: 0xE66)
        for _ in 0..<300 {
            let names = (0..<gen.int(in: 1...4)).map { "rule\($0)" }
            var expected: [String: String] = [:]
            var lines: [String] = []
            for name in names {
                let description = Self.descriptionLines(&gen)
                expected[name] = description.joined(separator: " ")
                lines.append(name)
                if gen.bool() { lines.append("") }
                lines += description.map { gen.bool() ? "  " + $0 : $0 }
                if gen.bool() { lines.append("") }
                if gen.bool() { lines += ["Options:", "--opt  Does a thing"] }
                if gen.bool() { lines += ["Examples:", "- a", "+ b"] }
            }
            let map = RuleInfoParser.descriptions(
                from: lines.joined(separator: "\n"),
                knownRuleNames: Set(names)
            )
            #expect(map == expected, "\(lines.joined(separator: "\n"))")
        }
    }
}
