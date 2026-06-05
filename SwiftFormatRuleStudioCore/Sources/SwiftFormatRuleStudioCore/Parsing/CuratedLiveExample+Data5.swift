//
//  CuratedLiveExample+Data5.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension CuratedLiveExample {
    static let dataPart5: [String: String] = [
        "spaceInsideGenerics": """
        let values: Array< Int > = []
        let lookup: Dictionary< String, Int > = [:]
        """,

        "spaceInsideParens": """
        func greet( name: String, count: Int ) {
            print( "Hello, \\(name)" )
        }
        """,

        "specifiers": """
        class ProfileView {
            lazy public weak private(set) var avatar: UIView?

            final public override func reload() {}

            convenience private init() {}
        }
        """,

        "strongOutlets": """
        import UIKit

        final class ProfileViewController: UIViewController {
            @IBOutlet weak var avatarImageView: UIImageView!
            @IBOutlet weak var nameLabel: UILabel!
        }
        """,

        "strongifiedSelf": """
        class Loader {
            func load(completion: @escaping () -> Void) {
                run { [weak self] in
                    guard let `self` = self else { return }
                    self.process()
                }
            }
        }
        """,

        "swiftTestingTestCaseNames": """
        import Testing

        @Suite("My Feature Tests")
        struct MyFeatureTests {
            @Test("feature has no bugs") func testMyFeatureHasNoBugs() {
                let myFeature = MyFeature()
                #expect(myFeature.crashes.isEmpty)
            }
        }
        """,

        "testSuiteAccessControl": """
        import XCTest

        final class MyTests: XCTestCase {
            public func testExample() {
                XCTAssertTrue(true)
            }

            func helperMethod() {
                // helper code
            }
        }
        """,

        "throwingTests": """
        import Testing

        struct MyFeatureTests {
            @Test func doSomething() {
                try! MyFeature().doSomething()
            }
        }
        """,

        "todos": """
        // MARK - View lifecycle
        func setup() {
            // TODO fix this properly
            // FIXME handle the error case
        }
        """,

        "trailingClosures": """
        func run() {
            DispatchQueue.main.async(execute: {
                print("done")
            })
            foo(action: {
                print("custom")
            })
        }
        """,

        "trailingCommas": """
        let array = [
            foo,
            bar,
            baz
        ]

        let single = [
            item
        ]

        func greet(
            name: String,
            count: Int
        ) {}
        """,

        "typeSugar": """
        struct Container {
            var items: Array<String>
            var lookup: Dictionary<String, Int>
            var note: Optional<String>
        }
        """,

        "unusedArguments": """
        func greet(name: String, count: Int, _ flag: Bool) {
            print("Hello \\(name)")
        }

        let handler = { (value: Int, error: Error?) in
            print(error as Any)
        }
        """,

        "unusedPrivateDeclarations": """
        struct Foo {
            private var unused = "unused"
            private var alsoUnused = "alsoUnused"
            var bar = "bar"
        }
        """,

        "validateTestCases": """
        import XCTest

        final class CalculatorTests: XCTestCase {
            func additionReturnsSum() {
                XCTAssertEqual(Calculator.add(2, 3), 5)
            }
        }
        """,

        "void": """
        let foo: () -> ()
        let bar: Void -> Void
        let baz: (Void) -> Void
        func quux() -> (Void) {}
        let callback = { _ in Void() }
        """,

        "wrapArguments": """
        func register(name: String,
                age: Int,
                    email: String) {
            print(name)
        }
        """,

        "wrapCaseBodies": """
        func describe(_ value: Direction) -> String {
            switch value {
            case .north: return "up"
            case .south: return "down"
            }
        }
        """,

        "wrapConditionalBodies": """
        func check(_ value: Int?) -> Int {
            guard let value = value else { return 0 }
            if value > 10 { return 10 }
            return value
        }
        """,

        "wrapEnumCases": """
        enum Token {
            case plus, minus
            case number(Int), name(String)
        }
        """,

        "wrapFunctionBodies": """
        struct Counter {
            var value = 0

            func increment() { value += 1 }
        }
        """,

        "wrapLoopBodies": """
        func printAll(_ items: [Int]) {
            for item in items { print(item) }
        }
        """,

        "wrapMultilineConditionalAssignment": """
        let planetLocation = if let star = planet.star {
            "The \\(star.name) system"
        } else {
            "Rogue planet"
        }
        """,

        "wrapMultilineFunctionChains": """
        let evenSquaresSum = [20, 17, 35, 4]
            .filter { $0 % 2 == 0 }.map { $0 * $0 }
            .reduce(0, +)
        """,

        "wrapMultilineStatementBraces": """
        func process(first: Int,
                     second: Int) {
            print(first + second)
        }
        """,

        "wrapPropertyBodies": """
        struct Foo {
            var bar: String { "bar" }
        }
        """,

        "wrapSwitchCases": """
        func describe(_ value: Direction) -> String {
            switch value {
            case .north, .south, .east, .west:
                return "cardinal"
            case .up, .down:
                return "vertical"
            }
        }
        """,

        "yodaConditions": """
        func check(foo: Int, bar: Color) {
            if 5 == foo, .red == bar {
                print("match")
            }
        }
        """
    ]
}
