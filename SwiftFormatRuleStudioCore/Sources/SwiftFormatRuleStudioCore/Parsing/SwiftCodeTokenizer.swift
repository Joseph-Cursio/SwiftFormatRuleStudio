//
//  SwiftCodeTokenizer.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// A lightweight, line-oriented Swift tokenizer for *display* syntax coloring —
/// not a parser. It splits a line into spans tagged with a semantic kind so the
/// UI can color keywords, strings, comments, numbers, and types. Good enough for
/// the short example snippets in the rule detail; it does not track multi-line
/// string/comment state across lines.
public enum SwiftCodeTokenizer {
    public enum Kind: Sendable, Equatable {
        case keyword
        case string
        case comment
        case number
        case type
        case plain
    }

    public struct Token: Sendable, Equatable {
        public let text: String
        public let kind: Kind

        public init(text: String, kind: Kind) {
            self.text = text
            self.kind = kind
        }
    }

    /// Swift keywords colored as keywords (a pragmatic subset covering what shows
    /// up in formatter examples).
    static let keywords: Set<String> = [
        "associatedtype", "async", "await", "as", "any", "break", "case", "catch",
        "class", "continue", "default", "defer", "deinit", "do", "else", "enum",
        "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard",
        "if", "import", "in", "init", "inout", "internal", "is", "let", "mutating",
        "nil", "nonmutating", "open", "operator", "private", "protocol", "public",
        "repeat", "rethrows", "return", "self", "Self", "some", "static", "struct",
        "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias",
        "var", "where", "while", "willSet", "didSet", "get", "set", "lazy", "weak",
        "unowned", "final", "indirect", "convenience", "required", "override", "macro"
    ]

    /// Tokenize a single line into display spans. Consecutive plain characters are
    /// coalesced into one `.plain` token.
    public static func tokens(inLine line: String) -> [Token] {
        let chars = Array(line)
        var tokens: [Token] = []
        var index = 0
        var plain = ""

        func flushPlain() {
            if !plain.isEmpty {
                tokens.append(Token(text: plain, kind: .plain))
                plain = ""
            }
        }

        while index < chars.count {
            guard let scanned = scanToken(chars, from: index) else {
                plain.append(chars[index])
                index += 1
                continue
            }
            flushPlain()
            tokens.append(scanned.token)
            index = scanned.next
        }

        flushPlain()
        return tokens
    }

    /// Tries to scan a single non-plain token starting at `start`. Returns the
    /// token and the index just past it, or `nil` if the character is plain.
    private static func scanToken(_ chars: [Character], from start: Int) -> (token: Token, next: Int)? {
        let char = chars[start]
        if char == "/", start + 1 < chars.count, chars[start + 1] == "/" {
            return (Token(text: String(chars[start...]), kind: .comment), chars.count)
        }
        if char == "\"" { return scanString(chars, from: start) }
        if char.isNumber {
            return scanRun(chars, from: start, kind: .number) { $0.isHexDigit || "._xXbBoOeE".contains($0) }
        }
        if char.isLetter || char == "_" { return scanIdentifier(chars, from: start) }
        return nil
    }

    private static func scanString(_ chars: [Character], from start: Int) -> (token: Token, next: Int) {
        var text = "\""
        var index = start + 1
        while index < chars.count {
            let inner = chars[index]
            text.append(inner)
            index += 1
            if inner == "\\", index < chars.count { text.append(chars[index]); index += 1; continue }
            if inner == "\"" { break }
        }
        return (Token(text: text, kind: .string), index)
    }

    private static func scanIdentifier(_ chars: [Character], from start: Int) -> (token: Token, next: Int) {
        let run = scanRun(chars, from: start, kind: .plain) { $0.isLetter || $0.isNumber || $0 == "_" }
        let word = run.token.text
        let kind: Kind
        if keywords.contains(word) {
            kind = .keyword
        } else if word.first?.isUppercase == true {
            kind = .type
        } else {
            kind = .plain
        }
        return (Token(text: word, kind: kind), run.next)
    }

    /// Scans a maximal run of characters satisfying `include`, tagging it `kind`.
    private static func scanRun(
        _ chars: [Character],
        from start: Int,
        kind: Kind,
        include: (Character) -> Bool
    ) -> (token: Token, next: Int) {
        var index = start
        var text = ""
        while index < chars.count, include(chars[index]) {
            text.append(chars[index]); index += 1
        }
        return (Token(text: text, kind: kind), index)
    }
}
