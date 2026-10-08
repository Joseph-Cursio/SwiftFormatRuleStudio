//
//  SwiftCodeTokenizerPropertyTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Single-lexeme laws: text that is exactly one token of a kind tokenizes to that one token.
///
/// The round-trip test (joined token text reproduces the line) cannot see a misplaced token
/// *boundary*: a scanner that ends a string literal early, or splits an identifier in two, still
/// emits every character exactly once. These laws pin the boundaries. Each was written against a
/// mutant that survived the whole suite.
@Suite("SwiftCodeTokenizer properties")
struct SwiftCodeTokenizerPropertyTests {
    /// A well-formed string literal is one `.string` token ending at its closing quote — the
    /// scanner neither stops at an escaped quote nor runs past the closing one into the rest of
    /// the line. The trailing `" tail"` is what makes running past observable.
    @Test("A string literal is one token ending at its closing quote")
    func stringLiteralIsOneTokenEndingAtItsClosingQuote() {
        var gen = SplitMix64(seed: 0xA11CE)
        for _ in 0..<300 {
            let content = gen.string(from: ["a", "b", " ", "\"", "\\", "/", "1", "x"], length: 0...10)
            let literal = "\"" + content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\""
            let tokens = SwiftCodeTokenizer.tokens(inLine: literal + " tail")
            #expect(tokens.first == SwiftCodeTokenizer.Token(text: literal, kind: .string), "literal \(literal)")
        }
    }

    /// A Swift identifier is one token, never split at a digit or an underscore.
    @Test("An identifier is one token")
    func identifierIsOneToken() {
        var gen = SplitMix64(seed: 0xB0B)
        let head = Array("abcXYZ_")
        let tail = Array("abcXYZ_0189")
        for _ in 0..<300 {
            let identifier = String(gen.pick(head)) + gen.string(from: tail, length: 0...8)
            #expect(SwiftCodeTokenizer.tokens(inLine: identifier).map(\.text) == [identifier], "\(identifier)")
        }
    }
}
