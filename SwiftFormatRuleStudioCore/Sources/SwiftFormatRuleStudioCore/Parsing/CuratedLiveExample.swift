//
//  CuratedLiveExample.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Hand-authored "before" snippets for the live example, used in preference to
/// the auto-reconstructed `FormatRule.exampleBeforeSource`.
///
/// SwiftFormat's `--ruleinfo` examples are great for *reading* but often don't
/// re-format usefully on their own: some are abbreviated (a multi-line case
/// shown as one line), some are aspirational (demonstrate a capability the
/// default option doesn't perform on the bare snippet), and some need
/// surrounding context (a type, a sibling declaration) the diff can't supply.
/// A curated snippet is written so that running *this rule* on it actually
/// changes it at default options — and, where the rule has an option, so that
/// flipping the option visibly changes the result. The `LiveExampleAuditTests`
/// validation test keeps every curated entry honest against the installed
/// SwiftFormat.
public enum CuratedLiveExample {
    /// The curated "before" for `ruleName`, or `nil` if none is curated yet.
    public static func source(forRule ruleName: String) -> String? {
        snippets[ruleName]
    }

    /// Rule name → curated "before" snippet. Built as close to each rule's
    /// static example as possible, adding only the context needed to make the
    /// transformation actually fire.
    static let snippets: [String: String] = [
        // multiline-only (default) blanks only the multi-line case; `always`
        // also blanks the single-line ones — so include both kinds.
        "blankLineAfterSwitchCase": """
        func handle(_ action: Action) {
            switch action {
            case .reset:
                reset()
            case .update:
                validate()
                apply()
            case .done:
                finish()
            }
        }
        """,

        // --type-blank-lines governs only *type* bodies; a function/closure's
        // boundary blank is ALWAYS removed regardless of the option. So include
        // both: two structs (one with a leading blank, one without) to demo
        // remove/insert/preserve on type scopes, plus a function whose leading
        // blank is stripped under every value — which is why even "preserve"
        // shows a change here, not a no-op.
        "blankLinesAtStartOfScope": """
        // type scope — obeys the option
        struct Spaced {

            let value = 1
        }

        // type scope — obeys the option
        struct Tight {
            let value = 2
        }

        // function scope — blank always removed
        func reset() {

            cache.clear()
        }
        """,

        // Mirror of blankLinesAtStartOfScope for the *end* of scope — same shared
        // --type-blank-lines option, blank line before the closing brace.
        "blankLinesAtEndOfScope": """
        // type scope — obeys the option
        struct Spaced {
            let value = 1

        }

        // type scope — obeys the option
        struct Tight {
            let value = 2
        }

        // function scope — blank always removed
        func reset() {
            cache.clear()

        }
        """,

        // --- redundant* family ---

        "redundantStaticSelf": """
        enum Foo {
            static let bar = Bar()

            static func makeBaaz() -> Bar {
                Self.bar
            }
        }
        """,

        // Typed throws is Swift 6; the example formatter runs at 6.0.
        "redundantTypedThrows": """
        func alpha() throws(Never) -> Int {
            return 0
        }

        func beta() throws(any Error) -> Int {
            throw MyError.failed
        }
        """,

        "redundantViewBuilder": """
        struct MyView: View {
            @ViewBuilder
            var body: some View {
                Text("hello")
            }
        }
        """,

        "redundantEquatable": """
        struct Point: Equatable {
            let x: Int
            let y: Int

            static func == (lhs: Point, rhs: Point) -> Bool {
                lhs.x == rhs.x && lhs.y == rhs.y
            }
        }
        """,

        "redundantMemberwiseInit": """
        struct User {
            var name: String
            var age: Int

            init(name: String, age: Int) {
                self.name = name
                self.age = age
            }
        }
        """,

        // --redundant-async: tests-only (default) strips async only from the test
        // method; "always" also strips it from the regular function.
        "redundantAsync": """
        import XCTest

        class FeatureTests: XCTestCase {
            func testValue() async {
                XCTAssertEqual(value, 1)
            }
        }

        func loadConfig() async -> Int {
            return 0
        }
        """,

        // Mirror of redundantAsync for throws — tests-only (default) vs always.
        "redundantThrows": """
        import XCTest

        class FeatureTests: XCTestCase {
            func testValue() throws {
                XCTAssertEqual(value, 1)
            }
        }

        func loadConfig() throws -> Int {
            return 0
        }
        """
    ]
}
