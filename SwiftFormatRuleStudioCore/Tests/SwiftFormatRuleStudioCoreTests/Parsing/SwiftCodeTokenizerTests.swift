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

    /// Every character the number guard used to take and the number scan rejects: `isNumber`, not a
    /// hex digit, not one of `._xXbBoOeE`. Six are in Latin-1 (`¹ ² ³ ¼ ½ ¾`), 790 in the BMP. Each
    /// once hung `tokens(inLine:)` while allocating without bound (#26), so a regression shows up as
    /// this test never finishing, not as a failure.
    private static let numericNonHex: [Character] = (0...0xFFFF)
        .compactMap(Unicode.Scalar.init(_:))
        .map(Character.init)
        .filter { $0.isNumber && !($0.isHexDigit || "._xXbBoOeE".contains($0)) }

    /// Never a number, and the line round-trips. Most become `.plain`; the 16 that are also letters
    /// (`Ⅰ`…`Ⅿ`, letter numbers) take the identifier path, as they did before.
    @Test("A numeric character that is not a hex digit is never a number, and the line round-trips")
    func numericNonHexIsNeverANumber() {
        #expect(Self.numericNonHex.count == 790)
        for char in Self.numericNonHex {
            let tokens = SwiftCodeTokenizer.tokens(inLine: String(char))
            #expect(tokens.map(\.text) == [String(char)], "\(char.unicodeScalars.map(\.value))")
            #expect(!tokens.contains { $0.kind == .number })
        }
    }

    @Test("Lines that start a token with ½ or ² tokenize and round-trip", arguments: [
        "½", "²", "let n = ½", "/* costs ½ */", " * Runs in O(²) time.", "1½", "x²",
    ])
    func numericNonHexInContext(line: String) {
        #expect(SwiftCodeTokenizer.tokens(inLine: line).map(\.text).joined() == line)
    }

    @Test("A number literal still starts at an ASCII digit")
    func asciiDigitStillStartsANumber() {
        #expect(SwiftCodeTokenizer.tokens(inLine: "1½") == [
            .init(text: "1", kind: .number), .init(text: "½", kind: .plain),
        ])
        #expect(SwiftCodeTokenizer.tokens(inLine: "x²") == [.init(text: "x²", kind: .plain)])
    }
}
