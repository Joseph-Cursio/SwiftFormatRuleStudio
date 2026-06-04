//
//  RuleInfoParserTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Testing
@testable import SwiftFormatRuleStudioCore

@Suite("RuleInfoParser")
struct RuleInfoParserTests {
    // Captured verbatim from `swiftformat --ruleinfo andOperator` (0.61.1).
    static let andOperator = """


    andOperator

    Prefer comma over && in if, guard or while conditions.

    Examples:

    - if true && true {
    + if true, true {

    - guard true && true else {
    + guard true, true else {
    """

    // Captured verbatim from `swiftformat --ruleinfo redundantSelf` (0.61.1),
    // including the Options section and prose that follows the first example.
    static let redundantSelf = """


    redundantSelf

    Insert/remove explicit self where applicable.

    Options:

    --self             Explicit self: "insert", "remove" (default) or "init-only"
    --self-required    Comma-delimited list of functions / types with @autoclosure arguments

    Examples:

      func foobar(foo: Int, bar: Int) {
        self.foo = foo
        self.bar = bar
    -   self.baz = 42
      }

      func foobar(foo: Int, bar: Int) {
        self.foo = foo
        self.bar = bar
    +   baz = 42
      }

    In the rare case of functions with `@autoclosure` arguments, `self` may be
    required at the call site. Use --self-required to exclude them.

      init(foo: Int, bar: Int) {
    -   baz = 42
      }
    """

    @Test("Parses name, description and example for a simple rule")
    func parsesSimpleRule() {
        let info = RuleInfoParser.parse(Self.andOperator)

        #expect(info.name == "andOperator")
        #expect(info.ruleDescription == "Prefer comma over && in if, guard or while conditions.")
        #expect(info.relatedOptions.isEmpty)
        #expect(info.example == """
        - if true && true {
        + if true, true {

        - guard true && true else {
        + guard true, true else {
        """)
    }

    @Test("Parses related options under the Options section")
    func parsesRelatedOptions() {
        let info = RuleInfoParser.parse(Self.redundantSelf)

        #expect(info.name == "redundantSelf")
        #expect(info.ruleDescription == "Insert/remove explicit self where applicable.")
        #expect(info.relatedOptions == ["--self", "--self-required"])
    }

    @Test("Captures only the first example block, stopping at trailing prose")
    func stopsAtProse() {
        let info = RuleInfoParser.parse(Self.redundantSelf)

        #expect(info.example == """
          func foobar(foo: Int, bar: Int) {
            self.foo = foo
            self.bar = bar
        -   self.baz = 42
          }

          func foobar(foo: Int, bar: Int) {
            self.foo = foo
            self.bar = bar
        +   baz = 42
          }
        """)
        // The init(...) block after the prose must NOT be included.
        #expect(info.example?.contains("init(") == false)
    }

    @Test("Empty output is handled gracefully")
    func emptyOutput() {
        let info = RuleInfoParser.parse("")
        #expect(info.name.isEmpty)
        #expect(info.example == nil)
        #expect(info.relatedOptions.isEmpty)
    }
}
