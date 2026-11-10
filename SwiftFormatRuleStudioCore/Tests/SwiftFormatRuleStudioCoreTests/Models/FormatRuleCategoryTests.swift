//
//  FormatRuleCategoryTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

@Suite("FormatRuleCategory")
struct FormatRuleCategoryTests {
    @Test("Every category exposes a capitalized display name")
    func displayNames() {
        for category in FormatRuleCategory.allCases {
            #expect(category.displayName == category.rawValue.capitalized)
        }
    }
}
