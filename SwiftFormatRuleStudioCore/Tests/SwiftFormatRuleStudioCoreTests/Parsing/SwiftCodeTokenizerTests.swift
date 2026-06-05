//
//  SwiftCodeTokenizerTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("SwiftCodeTokenizer")
struct SwiftCodeTokenizerTests {
    private func kind(of word: String, in line: String) -> SwiftCodeTokenizer.Kind? {
        SwiftCodeTokenizer.tokens(inLine: line).first { $0.text == word }?.kind
    }

    @Test("Round-trips: joined token text reproduces the line")
    func roundTrip() {
        let line = "    let name: String = \"Jon\" // a comment"
        let joined = SwiftCodeTokenizer.tokens(inLine: line).map(\.text).joined()
        #expect(joined == line)
    }

    @Test("Classifies keywords, types, strings, numbers, comments")
    func classifications() {
        #expect(kind(of: "let", in: "let value = 1") == .keyword)
        #expect(kind(of: "struct", in: "struct Foo {}") == .keyword)
        #expect(kind(of: "Foo", in: "struct Foo {}") == .type)
        #expect(kind(of: "value", in: "let value = 1") == .plain)

        let stringLine = SwiftCodeTokenizer.tokens(inLine: "x = \"hi\"")
        #expect(stringLine.contains { $0.text == "\"hi\"" && $0.kind == .string })

        let numberLine = SwiftCodeTokenizer.tokens(inLine: "let n = 0xFF_00")
        #expect(numberLine.contains { $0.text == "0xFF_00" && $0.kind == .number })

        let commentLine = SwiftCodeTokenizer.tokens(inLine: "doThing() // go")
        #expect(commentLine.contains { $0.text == "// go" && $0.kind == .comment })
    }

    @Test("A keyword inside a string is not colored as a keyword")
    func keywordInsideStringStaysString() {
        let tokens = SwiftCodeTokenizer.tokens(inLine: "let s = \"let func\"")
        #expect(tokens.contains { $0.text == "\"let func\"" && $0.kind == .string })
        // Only the leading `let` keyword, not the ones inside the string.
        #expect(tokens.filter { $0.kind == .keyword }.count == 1)
    }
}
