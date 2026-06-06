//
//  MockSwiftFormatCLI.swift
//  SwiftFormatRuleStudioCoreTestSupport
//

import Foundation
import SwiftFormatRuleStudioCore

/// A configurable in-memory `SwiftFormatCLIProtocol` for tests. Records how
/// many times each command was invoked so caching behavior can be asserted.
public actor MockSwiftFormatCLI: SwiftFormatCLIProtocol {
    private var versionValue: String
    private let rules: String
    private let options: String
    private let ruleInfos: [String: String]
    private let allRuleInfo: String
    private let failWith: SwiftFormatError?
    private let formatOverride: String?
    private let lintOutput: String
    private let lintSummary: String

    public private(set) var versionCallCount = 0
    public private(set) var rulesCallCount = 0
    public private(set) var optionsCallCount = 0
    public private(set) var ruleInfoCallCount = 0
    public private(set) var formatCallCount = 0
    public private(set) var lastFormatArguments: [String] = []
    public private(set) var lintCallCount = 0
    public private(set) var lastLintArguments: [String] = []

    public init(
        version: String = "0.61.1",
        rules: String = "",
        options: String = "",
        ruleInfos: [String: String] = [:],
        allRuleInfo: String = "",
        failWith: SwiftFormatError? = nil,
        formatOverride: String? = nil,
        lintOutput: String = "[]",
        lintSummary: String = ""
    ) {
        self.versionValue = version
        self.rules = rules
        self.options = options
        self.ruleInfos = ruleInfos
        self.allRuleInfo = allRuleInfo
        self.failWith = failWith
        self.formatOverride = formatOverride
        self.lintOutput = lintOutput
        self.lintSummary = lintSummary
    }

    /// Changes the reported version (to exercise cache invalidation).
    public func setVersion(_ newValue: String) {
        versionValue = newValue
    }

    public func detectPath() -> URL {
        URL(fileURLWithPath: "/mock/swiftformat")
    }

    public func version() throws -> String {
        versionCallCount += 1
        if let failWith { throw failWith }
        return versionValue
    }

    public func rulesOutput() -> String {
        rulesCallCount += 1
        return rules
    }

    public func ruleInfoOutput(ruleName: String) -> String {
        ruleInfoCallCount += 1
        return ruleInfos[ruleName] ?? ""
    }

    public func allRuleInfoOutput() -> String {
        allRuleInfo
    }

    public func optionsOutput() -> String {
        optionsCallCount += 1
        return options
    }

    /// Returns `formatOverride` if set (simulating a formatting change),
    /// otherwise echoes the source unchanged (a no-op format). Records the
    /// arguments so callers can assert flags like `--swift-version`.
    public func format(source: String, arguments: [String]) throws -> String {
        formatCallCount += 1
        lastFormatArguments = arguments
        if let failWith { throw failWith }
        return formatOverride ?? source
    }

    public func lint(path _: String, arguments: [String]) throws -> LintRun {
        lintCallCount += 1
        lastLintArguments = arguments
        if let failWith { throw failWith }
        return LintRun(reporterOutput: lintOutput, summary: lintSummary)
    }
}
