//
//  FormatRuleClassifierTests.swift
//  SwiftFormatRuleStudioCoreTests
//

@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("FormatRuleClassifier")
struct FormatRuleClassifierTests {
    /// Every rule from `swiftformat --rules` (0.61.1). Used to assert the
    /// curated table covers the full rule set (no heuristic fallback needed).
    static let allRuleNames: [String] = [
        "acronyms",
        "andOperator",
        "anyObjectProtocol",
        "applicationMain",
        "assertionFailures",
        "blankLineAfterImports",
        "blankLineAfterSwitchCase",
        "blankLinesAfterGuardStatements",
        "blankLinesAroundMark",
        "blankLinesAtEndOfScope",
        "blankLinesAtStartOfScope",
        "blankLinesBetweenChainedFunctions",
        "blankLinesBetweenImports",
        "blankLinesBetweenScopes",
        "blockComments",
        "braces",
        "conditionalAssignment",
        "consecutiveBlankLines",
        "consecutiveSpaces",
        "consistentSwitchCaseSpacing",
        "docComments",
        "docCommentsBeforeModifiers",
        "duplicateImports",
        "elseOnSameLine",
        "emptyBraces",
        "emptyExtensions",
        "enumNamespaces",
        "environmentEntry",
        "extensionAccessControl",
        "fileHeader",
        "fileMacro",
        "genericExtensions",
        "headerFileName",
        "hoistAwait",
        "hoistPatternLet",
        "hoistTry",
        "indent",
        "initCoderUnavailable",
        "isEmpty",
        "leadingDelimiters",
        "linebreakAtEndOfFile",
        "linebreaks",
        "markTypes",
        "modifierOrder",
        "modifiersOnSameLine",
        "noExplicitOwnership",
        "noForceTryInTests",
        "noForceUnwrapInTests",
        "noGuardInTests",
        "numberFormatting",
        "opaqueGenericParameters",
        "organizeDeclarations",
        "preferCountWhere",
        "preferExplicitFalse",
        "preferFinalClasses",
        "preferForLoop",
        "preferKeyPath",
        "preferSwiftStringAPI",
        "preferSwiftTesting",
        "privateStateVariables",
        "propertyTypes",
        "redundantAsync",
        "redundantBackticks",
        "redundantBreak",
        "redundantClosure",
        "redundantEmptyView",
        "redundantEquatable",
        "redundantExtensionACL",
        "redundantFileprivate",
        "redundantGet",
        "redundantInit",
        "redundantInternal",
        "redundantLet",
        "redundantLetError",
        "redundantMemberwiseInit",
        "redundantNilInit",
        "redundantObjc",
        "redundantOptionalBinding",
        "redundantParens",
        "redundantPattern",
        "redundantProperty",
        "redundantPublic",
        "redundantRawValues",
        "redundantReturn",
        "redundantSelf",
        "redundantSendable",
        "redundantStaticSelf",
        "redundantSwiftTestingSuite",
        "redundantThrows",
        "redundantType",
        "redundantTypedThrows",
        "redundantVariable",
        "redundantViewBuilder",
        "redundantVoidReturnType",
        "semicolons",
        "simplifyGenericConstraints",
        "singlePropertyPerLine",
        "sortDeclarations",
        "sortImports",
        "sortSwitchCases",
        "sortTypealiases",
        "sortedImports",
        "sortedSwitchCases",
        "spaceAroundBraces",
        "spaceAroundBrackets",
        "spaceAroundComments",
        "spaceAroundGenerics",
        "spaceAroundOperators",
        "spaceAroundParens",
        "spaceInsideBraces",
        "spaceInsideBrackets",
        "spaceInsideComments",
        "spaceInsideGenerics",
        "spaceInsideParens",
        "specifiers",
        "strongOutlets",
        "strongifiedSelf",
        "swiftTestingTestCaseNames",
        "testSuiteAccessControl",
        "throwingTests",
        "todos",
        "trailingClosures",
        "trailingCommas",
        "trailingSpace",
        "typeSugar",
        "unusedArguments",
        "unusedPrivateDeclarations",
        "urlMacro",
        "validateTestCases",
        "void",
        "wrap",
        "wrapArguments",
        "wrapAttributes",
        "wrapCaseBodies",
        "wrapConditionalBodies",
        "wrapEnumCases",
        "wrapFunctionBodies",
        "wrapLoopBodies",
        "wrapMultilineConditionalAssignment",
        "wrapMultilineFunctionChains",
        "wrapMultilineStatementBraces",
        "wrapPropertyBodies",
        "wrapSingleLineComments",
        "wrapSwitchCases",
        "yodaConditions"

    ]

    @Test("Every known rule is curated (no fallback needed)")
    func fullCoverage() {
        let uncurated = Self.allRuleNames.filter { FormatRuleClassifier.curatedCategory(for: $0) == nil }
        #expect(uncurated.isEmpty, "Uncurated rules: \(uncurated.sorted())")
    }

    @Test("All 145 rules are accounted for in the fixture")
    func fixtureCount() {
        #expect(Self.allRuleNames.count == 145)
        #expect(Set(Self.allRuleNames).count == 145) // no duplicates
    }

    @Test("Representative rules land in the expected category")
    func representativeMappings() {
        #expect(FormatRuleClassifier.category(for: "redundantSelf") == .redundancy)
        #expect(FormatRuleClassifier.category(for: "unusedArguments") == .redundancy)
        #expect(FormatRuleClassifier.category(for: "spaceInsideParens") == .spacing)
        #expect(FormatRuleClassifier.category(for: "indent") == .spacing)
        #expect(FormatRuleClassifier.category(for: "wrapArguments") == .wrapping)
        #expect(FormatRuleClassifier.category(for: "braces") == .wrapping)
        #expect(FormatRuleClassifier.category(for: "sortDeclarations") == .organization)
        #expect(FormatRuleClassifier.category(for: "sortImports") == .imports)
        #expect(FormatRuleClassifier.category(for: "duplicateImports") == .imports)
        #expect(FormatRuleClassifier.category(for: "docComments") == .comments)
        #expect(FormatRuleClassifier.category(for: "todos") == .comments)
        #expect(FormatRuleClassifier.category(for: "noForceTryInTests") == .testing)
        #expect(FormatRuleClassifier.category(for: "andOperator") == .idiomatic)
        #expect(FormatRuleClassifier.category(for: "preferKeyPath") == .idiomatic)
    }

    @Test("Import-related blank-line rules go to imports, not spacing")
    func importBlankLinesDisambiguation() {
        #expect(FormatRuleClassifier.category(for: "blankLineAfterImports") == .imports)
        #expect(FormatRuleClassifier.category(for: "blankLinesBetweenImports") == .imports)
        // …while a generic blank-line rule stays in spacing.
        #expect(FormatRuleClassifier.category(for: "blankLinesBetweenScopes") == .spacing)
    }

    @Test("Comment-spacing rules go to comments, not spacing")
    func commentSpacingDisambiguation() {
        #expect(FormatRuleClassifier.category(for: "spaceAroundComments") == .comments)
        #expect(FormatRuleClassifier.category(for: "wrapSingleLineComments") == .comments)
    }

    @Test("Unknown rules fall back via the name heuristic, covering every branch")
    func heuristicFallback() {
        #expect(FormatRuleClassifier.curatedCategory(for: "redundantFutureThing") == nil)
        #expect(FormatRuleClassifier.category(for: "redundantFutureThing") == .redundancy)
        #expect(FormatRuleClassifier.category(for: "unusedFutureThing") == .redundancy)
        #expect(FormatRuleClassifier.category(for: "futureImportSorter") == .imports)
        #expect(FormatRuleClassifier.category(for: "futureTestHelper") == .testing)
        #expect(FormatRuleClassifier.category(for: "futureDocComment") == .comments)
        #expect(FormatRuleClassifier.category(for: "futureHeaderTweak") == .comments)
        #expect(FormatRuleClassifier.category(for: "futureSortThing") == .organization)
        #expect(FormatRuleClassifier.category(for: "futureHoistThing") == .organization)
        #expect(FormatRuleClassifier.category(for: "futureWrapThing") == .wrapping)
        #expect(FormatRuleClassifier.category(for: "futureBraceThing") == .wrapping)
        #expect(FormatRuleClassifier.category(for: "futureSpaceThing") == .spacing)
        #expect(FormatRuleClassifier.category(for: "futureBlankThing") == .spacing)
        #expect(FormatRuleClassifier.category(for: "totallyNovelRule") == .idiomatic)
    }
}
