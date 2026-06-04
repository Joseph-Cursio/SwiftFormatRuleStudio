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
    private let failWith: SwiftFormatError?
    private let formatOverride: String?

    public private(set) var versionCallCount = 0
    public private(set) var rulesCallCount = 0
    public private(set) var optionsCallCount = 0
    public private(set) var ruleInfoCallCount = 0
    public private(set) var formatCallCount = 0
    public private(set) var lastFormatArguments: [String] = []

    public init(
        version: String = "0.61.1",
        rules: String = "",
        options: String = "",
        ruleInfos: [String: String] = [:],
        failWith: SwiftFormatError? = nil,
        formatOverride: String? = nil
    ) {
        self.versionValue = version
        self.rules = rules
        self.options = options
        self.ruleInfos = ruleInfos
        self.failWith = failWith
        self.formatOverride = formatOverride
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
}
