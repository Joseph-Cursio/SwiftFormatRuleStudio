//
//  SwiftFormatFormatIntegrationTests.swift
//  SwiftFormatRuleStudioCoreTests
//

import Foundation
@testable import SwiftFormatRuleStudioCore
import Testing

/// Exercises real `swiftformat stdin` formatting end-to-end. Skips when
/// SwiftFormat is not installed.
@Suite("SwiftFormatCLIActor format Integration")
struct SwiftFormatFormatIntegrationTests {
    @Test("Formats a messy snippet via the real binary")
    func formatsViaRealBinary() async throws {
        let actor = SwiftFormatCLIActor()
        do {
            _ = try await actor.detectPath()
        } catch {
            return // not installed; skip
        }

        let messy = "struct  Foo{\nlet x=1\n}\n"
        let formatted = try await actor.format(source: messy, arguments: ["stdin", "--swift-version", "5.10"])

        #expect(formatted.contains("struct Foo {"))
        #expect(formatted.contains("let x = 1"))
    }
}
