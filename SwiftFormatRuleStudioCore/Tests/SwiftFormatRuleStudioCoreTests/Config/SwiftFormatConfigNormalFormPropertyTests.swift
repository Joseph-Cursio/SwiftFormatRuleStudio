//
//  SwiftFormatConfigNormalFormPropertyTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Property tests over `SwiftFormatConfig`'s parse/serialize pair.
///
/// `swift-infer discover` proposed two laws here and ranked the wrong one first:
///
/// - `serialized(parse(s)) == s` — the exact round trip, scored 50. It is
///   **false**. `parseLine` classifies a line by its *trimmed* content, so a
///   whitespace-only line becomes `.blank`, whose `rendered` is `""` — the
///   original spaces are gone. `exactRoundTripDropsWhitespaceOnlyLines` pins it.
/// - `serialized(parse(serialized(parse(s)))) == serialized(parse(s))` — the
///   normal-form law, scored 40. This is the one that holds: after one pass every
///   whitespace-only line is already `""`, so normalising again is a no-op.
///
/// Two docstrings claim the stronger law (the type's "unedited lines serialize
/// byte-for-byte" and `serialized()`'s "Round-trips unedited content exactly"),
/// and the two example tests in `SwiftFormatConfigTests` appear to confirm it —
/// but neither sample contains a whitespace-only line, so neither can fail.
/// That is why the counterexample below is pinned rather than left implied.
///
/// Whether the lossy case is a defect is a judgement for the author: dropping
/// trailing whitespace on an otherwise-empty line is defensible normalisation.
/// What is not defensible is the docstring promising it does not happen.
@Suite("SwiftFormatConfig normal form")
struct SwiftFormatConfigNormalFormPropertyTests {

    // MARK: - Deterministic generator

    /// SplitMix64. Seeded rather than system-random so a failure is replayable
    /// from the seed printed in its message.
    ///
    /// Deliberately *not* a `RandomNumberGenerator` conformance: this package
    /// sets `.defaultIsolation(MainActor.self)`, which would make `next()`
    /// main-actor-isolated and unable to satisfy that protocol's nonisolated
    /// requirement.
    private struct Seeded {
        private var state: UInt64

        init(seed: UInt64) { self.state = seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        mutating func int(in range: ClosedRange<Int>) -> Int {
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int(next() % span)
        }

        mutating func word() -> String {
            let alphabet = ["indent", "self", "enable", "isEmpty", "redundantSelf", "x", "4", "remove"]
            return alphabet[int(in: 0...(alphabet.count - 1))]
        }
    }

    /// One `.swiftformat` line, drawn across every shape `parseLine` recognises.
    ///
    /// Case 1 is the whole point: a whitespace-only line is the only input the
    /// serializer does not reproduce, so a generator that never draws one cannot
    /// tell the exact round trip from the normal form.
    private static func line(using rng: inout Seeded) -> String {
        switch rng.int(in: 0...7) {
        case 0: ""
        case 1: String(repeating: " ", count: rng.int(in: 1...4))
        case 2: "# \(rng.word())"
        case 3: "  # \(rng.word())"
        case 4: "--\(rng.word()) \(rng.word())"
        case 5: "--disable \(rng.word()),\(rng.word())"
        case 6: "--enable \(rng.word())"
        default: rng.word()
        }
    }

    private static func text(seed: UInt64) -> String {
        var rng = Seeded(seed: seed)
        let count = rng.int(in: 0...10)
        return (0..<count).map { _ in line(using: &rng) }.joined(separator: "\n")
    }

    private static func normalized(_ text: String) -> String {
        SwiftFormatConfig.parse(text).serialized()
    }

    // MARK: - The law that holds

    @Test("Normalising is idempotent: serialized(parse(·)) reaches a fixed point in one pass")
    func normalisingIsIdempotent() {
        for seed in UInt64(1)...500 {
            let source = Self.text(seed: seed)
            let once = Self.normalized(source)
            let twice = Self.normalized(once)
            #expect(
                once == twice,
                "normal form not reached at seed \(seed): \(source.debugDescription) -> \(once.debugDescription) -> \(twice.debugDescription)"
            )
        }
    }

    @Test("Parsing the normal form yields an equal configuration")
    func parsingTheNormalFormIsStable() {
        for seed in UInt64(1)...500 {
            let normalForm = Self.normalized(Self.text(seed: seed))
            #expect(
                SwiftFormatConfig.parse(normalForm) == SwiftFormatConfig.parse(Self.normalized(normalForm)),
                "config differs after a second normalisation at seed \(seed)"
            )
        }
    }

    @Test("Text already in normal form is returned unchanged")
    func normalFormIsAFixedPoint() {
        for seed in UInt64(1)...500 {
            let normalForm = Self.normalized(Self.text(seed: seed))
            #expect(Self.normalized(normalForm) == normalForm, "seed \(seed)")
        }
    }

    // MARK: - The law that does not

    @Test("Exact round-trip is false: a whitespace-only line is not preserved")
    func exactRoundTripDropsWhitespaceOnlyLines() {
        let source = "--indent 4\n   \n--enable isEmpty"

        // The claim two docstrings make, and it does not hold.
        #expect(Self.normalized(source) != source)

        // What actually happens: the three spaces become the empty string.
        #expect(Self.normalized(source) == "--indent 4\n\n--enable isEmpty")

        // And it is stable from there — which is exactly the normal-form law.
        #expect(Self.normalized(Self.normalized(source)) == Self.normalized(source))
    }

    @Test("Content with no whitespace-only line does round-trip exactly")
    func exactRoundTripHoldsWithoutWhitespaceOnlyLines() {
        // The restricted domain the existing example tests happen to sample, and
        // the reason they pass: on this input the strong law is true.
        let source = "# Formatting options\n--indent 4\n\n  # indented\n--disable redundantSelf,redundantParens\n"
        #expect(Self.normalized(source) == source)
    }

    // MARK: - The strong law, on the domain where it holds

    /// The same generator with case 1 removed, plus the irregular spacings a
    /// hand-written sample never thinks to include.
    ///
    /// This is the law worth having. Normal-form idempotence is satisfied by
    /// almost any implementation — including several that mangle their input —
    /// because normalising twice is a no-op the moment normalising once is
    /// stable. Exact round-trip on the restricted domain rejects any change that
    /// stops preserving `raw`, which is the property the type actually promises.
    private static func lossless(seed: UInt64) -> String {
        var rng = Seeded(seed: seed)
        let count = rng.int(in: 0...10)
        let lines = (0..<count).map { _ -> String in
            switch rng.int(in: 0...7) {
            case 0: ""
            case 1: "# \(rng.word())"
            case 2: "  # \(rng.word())"
            case 3: "--\(rng.word()) \(rng.word())"
            case 4: "--\(rng.word())    \(rng.word())"
            case 5: "--disable \(rng.word()), \(rng.word())"
            case 6: "--enable \(rng.word())"
            default: rng.word()
            }
        }
        return lines.joined(separator: "\n")
    }

    @Test("Exact round-trip holds for every input containing no whitespace-only line")
    func exactRoundTripHoldsOnTheLosslessDomain() {
        for seed in UInt64(1)...500 {
            let source = Self.lossless(seed: seed)
            #expect(
                Self.normalized(source) == source,
                "round trip lost content at seed \(seed): \(source.debugDescription) -> \(Self.normalized(source).debugDescription)"
            )
        }
    }
}
