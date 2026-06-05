//
//  CuratedLiveExample+Data1.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension CuratedLiveExample {
    static let dataPart1: [String: String] = [
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
        """,

        // --- batch 1 (workflow-curated) ---
        "acronyms": """
        struct Endpoint {
            let destinationUrl: URL
            let screenIds: [String]
            let entityUuid: UUID
        }
        """,

        "andOperator": """
        func validate(name: String, age: Int) -> Bool {
            guard !name.isEmpty && age >= 0 else {
                return false
            }
            if age >= 18 && name.count < 50 {
                return true
            }
            return false
        }
        """,

        "anyObjectProtocol": """
        protocol Reloadable: class {
            func reload()
        }
        """,

        "applicationMain": """
        import UIKit

        @UIApplicationMain
        class AppDelegate: UIResponder, UIApplicationDelegate {
            var window: UIWindow?
        }
        """,

        "assertionFailures": """
        func handle(_ value: Int) {
            switch value {
            case 0:
                assert(false, "unexpected zero")
            case 1:
                precondition(false, "unexpected one")
            default:
                break
            }
        }
        """,

        "blankLineAfterImports": """
        import Foundation
        import SwiftUI
        @testable import MyApp
        class Foo {
            let value = 42
        }
        """,

        "blankLinesAfterGuardStatements": """
        func process(_ input: String?) -> Int {
            guard let value = input else { return 0 }

            guard let number = Int(value) else { return 0 }
            return number * 2
        }
        """,

        "blankLinesAroundMark": """
        func foo() {
            // foo
        }
        // MARK: Bar
        func bar() {
            // bar
        }
        """,

        "blankLinesBetweenChainedFunctions": """
        let result = [1, 2, 3]
            .map { $0 * 2 }


            .filter { $0 > 2 }
        """,

        "blankLinesBetweenImports": """
        import Combine

        import Foundation


        import SwiftUI
        """,

        "blankLinesBetweenScopes": """
        func foo() {
            // foo
        }
        func bar() {
            // bar
        }
        """,

        "blockComments": """
        /*
         * Computes the area of a rectangle.
         * Returns width multiplied by height.
         */
        func area(width: Int, height: Int) -> Int {
            return width * height
        }
        """
    ]
}
