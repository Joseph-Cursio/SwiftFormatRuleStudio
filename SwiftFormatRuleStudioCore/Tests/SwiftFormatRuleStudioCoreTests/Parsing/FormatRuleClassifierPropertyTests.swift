//
//  FormatRuleClassifierPropertyTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

/// The heuristic fallback is a keyword table written as an `if` chain. The example test reaches
/// every branch, but through one keyword each; this checks every keyword, alone.
@Suite("FormatRuleClassifier properties")
struct FormatRuleClassifierPropertyTests {
    /// Every keyword in `heuristicCategory`, in the chain's order, with the category it decides.
    /// No keyword contains an earlier one, so a name holding just this keyword reaches its own row.
    private static let table: [(keyword: String, category: FormatRuleCategory)] = [
        ("comment", .comments), ("doc", .comments), ("header", .comments), ("todo", .comments),
        ("sort", .organization), ("organize", .organization), ("mark", .organization),
        ("modifierorder", .organization), ("accesscontrol", .organization), ("hoist", .organization),
        ("wrap", .wrapping), ("brace", .wrapping), ("sameline", .wrapping),
        ("space", .spacing), ("blank", .spacing), ("indent", .spacing),
        ("linebreak", .spacing), ("consecutive", .spacing)
    ]

    /// An uncurated name containing a keyword — in any case, between affixes that spell no
    /// keyword — lands in that keyword's category.
    @Test("Each heuristic keyword decides the category on its own, case-insensitively")
    func heuristicKeywordsDecideTheCategory() {
        var gen = SplitMix64(seed: 0xF00)
        let neutral = Array("qzQZ")
        for (keyword, category) in Self.table {
            for _ in 0..<20 {
                let cased = String(keyword.map { gen.bool() ? Character($0.uppercased()) : $0 })
                let name = gen.string(from: neutral, length: 0...3) + cased + gen.string(from: neutral, length: 0...3)
                #expect(FormatRuleClassifier.curatedCategory(for: name) == nil, "\(name) is curated")
                #expect(FormatRuleClassifier.category(for: name) == category, "\(name)")
            }
        }
    }
}
