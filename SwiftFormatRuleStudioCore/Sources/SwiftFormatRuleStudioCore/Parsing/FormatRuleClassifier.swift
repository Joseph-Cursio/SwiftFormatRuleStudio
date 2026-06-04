//
//  FormatRuleClassifier.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Assigns a `FormatRuleCategory` to a rule by name.
///
/// SwiftFormat has no native categories, so this is a curated mapping of the
/// known rules (SwiftFormat 0.61.x) plus a name-based heuristic fallback for any
/// rule not in the table (e.g. ones added in a newer SwiftFormat). The curated
/// table is the source of truth; the heuristic only fires for unknowns.
public enum FormatRuleClassifier {
    /// The category for a rule, from the curated table or the heuristic fallback.
    nonisolated public static func category(for ruleName: String) -> FormatRuleCategory {
        curatedCategory(for: ruleName) ?? heuristicCategory(for: ruleName)
    }

    /// The curated category, or `nil` if the rule is not in the table.
    nonisolated public static func curatedCategory(for ruleName: String) -> FormatRuleCategory? {
        lookup[ruleName]
    }

    // MARK: - Curated table

    nonisolated private static let curated: [FormatRuleCategory: Set<String>] = [
        .redundancy: [
            "redundantAsync", "redundantBackticks", "redundantBreak", "redundantClosure",
            "redundantEmptyView", "redundantEquatable", "redundantExtensionACL",
            "redundantFileprivate", "redundantGet", "redundantInit", "redundantInternal",
            "redundantLet", "redundantLetError", "redundantMemberwiseInit", "redundantNilInit",
            "redundantObjc", "redundantOptionalBinding", "redundantParens", "redundantPattern",
            "redundantProperty", "redundantPublic", "redundantRawValues", "redundantReturn",
            "redundantSelf", "redundantSendable", "redundantStaticSelf", "redundantSwiftTestingSuite",
            "redundantThrows", "redundantType", "redundantTypedThrows", "redundantVariable",
            "redundantViewBuilder", "redundantVoidReturnType",
            "unusedArguments", "unusedPrivateDeclarations"
        ],
        .spacing: [
            "blankLineAfterSwitchCase", "blankLinesAfterGuardStatements", "blankLinesAroundMark",
            "blankLinesAtEndOfScope", "blankLinesAtStartOfScope", "blankLinesBetweenChainedFunctions",
            "blankLinesBetweenScopes", "consecutiveBlankLines", "consecutiveSpaces",
            "consistentSwitchCaseSpacing", "emptyBraces", "indent", "linebreakAtEndOfFile",
            "linebreaks", "spaceAroundBraces", "spaceAroundBrackets", "spaceAroundGenerics",
            "spaceAroundOperators", "spaceAroundParens", "spaceInsideBraces", "spaceInsideBrackets",
            "spaceInsideGenerics", "spaceInsideParens", "trailingSpace"
        ],
        .wrapping: [
            "braces", "elseOnSameLine", "leadingDelimiters", "modifiersOnSameLine", "wrap",
            "wrapArguments", "wrapAttributes", "wrapCaseBodies", "wrapConditionalBodies",
            "wrapEnumCases", "wrapFunctionBodies", "wrapLoopBodies",
            "wrapMultilineConditionalAssignment", "wrapMultilineFunctionChains",
            "wrapMultilineStatementBraces", "wrapPropertyBodies", "wrapSwitchCases"
        ],
        .organization: [
            "emptyExtensions", "enumNamespaces", "extensionAccessControl", "genericExtensions",
            "hoistAwait", "hoistPatternLet", "hoistTry", "markTypes", "modifierOrder",
            "organizeDeclarations", "singlePropertyPerLine", "sortDeclarations", "sortSwitchCases",
            "sortTypealiases", "sortedSwitchCases", "specifiers"
        ],
        .imports: [
            "blankLineAfterImports", "blankLinesBetweenImports", "duplicateImports",
            "sortImports", "sortedImports"
        ],
        .comments: [
            "blockComments", "docComments", "docCommentsBeforeModifiers", "fileHeader",
            "headerFileName", "spaceAroundComments", "spaceInsideComments", "todos",
            "wrapSingleLineComments"
        ],
        .testing: [
            "assertionFailures", "noForceTryInTests", "noForceUnwrapInTests", "noGuardInTests",
            "preferSwiftTesting", "swiftTestingTestCaseNames", "testSuiteAccessControl",
            "throwingTests", "validateTestCases"
        ],
        .idiomatic: [
            "acronyms", "andOperator", "anyObjectProtocol", "applicationMain", "conditionalAssignment",
            "environmentEntry", "fileMacro", "initCoderUnavailable", "isEmpty", "noExplicitOwnership",
            "numberFormatting", "opaqueGenericParameters", "preferCountWhere", "preferExplicitFalse",
            "preferFinalClasses", "preferForLoop", "preferKeyPath", "preferSwiftStringAPI",
            "privateStateVariables", "propertyTypes", "semicolons", "simplifyGenericConstraints",
            "strongOutlets", "strongifiedSelf", "trailingClosures", "trailingCommas", "typeSugar",
            "urlMacro", "void", "yodaConditions"
        ]
    ]

    nonisolated private static let lookup: [String: FormatRuleCategory] = {
        var map: [String: FormatRuleCategory] = [:]
        for (category, names) in curated {
            for name in names {
                map[name] = category
            }
        }
        return map
    }()

    // MARK: - Heuristic fallback

    nonisolated private static func heuristicCategory(for ruleName: String) -> FormatRuleCategory {
        let lower = ruleName.lowercased()
        if lower.hasPrefix("redundant") || lower.hasPrefix("unused") {
            return .redundancy
        }
        if lower.contains("import") {
            return .imports
        }
        if lower.contains("test") {
            return .testing
        }
        if lower.contains("comment") || lower.contains("doc") || lower.contains("header") || lower.contains("todo") {
            return .comments
        }
        if lower.contains("sort") || lower.contains("organize") || lower.contains("mark")
            || lower.contains("modifierorder") || lower.contains("accesscontrol") || lower.contains("hoist") {
            return .organization
        }
        if lower.contains("wrap") || lower.contains("brace") || lower.contains("sameline") {
            return .wrapping
        }
        if lower.contains("space") || lower.contains("blank") || lower.contains("indent")
            || lower.contains("linebreak") || lower.contains("consecutive") {
            return .spacing
        }
        return .idiomatic
    }
}
