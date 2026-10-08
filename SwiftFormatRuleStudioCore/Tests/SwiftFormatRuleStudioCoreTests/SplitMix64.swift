//
//  SplitMix64.swift
//  SwiftFormatRuleStudioCoreTests
//

/// A seeded generator for the property suites. Seeded rather than system-random so a
/// failure is replayable from the seed the suite hard-codes.
///
/// Deliberately *not* a `RandomNumberGenerator` conformance: this package sets
/// `.defaultIsolation(MainActor.self)`, which would make `next()` main-actor-isolated and
/// unable to satisfy that protocol's nonisolated requirement.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound + 1))
    }

    mutating func bool() -> Bool { next() & 1 == 1 }

    mutating func pick<T>(_ items: [T]) -> T { items[int(in: 0...(items.count - 1))] }

    mutating func string(from alphabet: [Character], length: ClosedRange<Int>) -> String {
        String((0..<int(in: length)).map { _ in pick(alphabet) })
    }
}
