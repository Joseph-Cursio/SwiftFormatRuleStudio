//
//  CuratedLiveExample+Data2.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension CuratedLiveExample {
    static let dataPart2: [String: String] = [
        // --- batch 2 ---
        "braces": """
        func greet(name: String)
        {
            if name.isEmpty
            {
                print("Hello, stranger")
            }
            else
            {
                print("Hello, \\(name)")
            }
        }
        """,

        "conditionalAssignment": """
        func configure(_ condition: Bool) {
            let foo: String
            if condition {
                foo = "foo"
            } else {
                foo = "bar"
            }

            switch condition {
            case true:
                view.title = "on"
            case false:
                view.title = "off"
            }
        }
        """,

        "consecutiveBlankLines": """
        func greet(name: String) {
            let message = "Hello, \\(name)"



            print(message)
        }
        """,

        "consecutiveSpaces": """
        struct Config {
            let timeout = 30
            let retries  = 3
            let baseURL   = "https://example.com"
        }
        """,

        "consistentSwitchCaseSpacing": """
        var name: PlanetType {
            switch self {
            case .mercury:
                "Mercury"

            case .venus:
                "Venus"
            case .earth:
                "Earth"
            }
        }
        """,

        "docComments": """
        // A placeholder type used to demonstrate syntax rules
        class Foo {
            // This function doesn't really do anything
            func bar() {
                /// TODO: implement Foo.bar() algorithm
                print("stub")
            }
        }
        """,

        "docCommentsBeforeModifiers": """
        @MainActor
        /// Refreshes the cached value from disk.
        public func reload() {}
        """,

        "duplicateImports": """
        import Foundation
        import SwiftUI
        import Foundation

        struct ContentView {
            let title = "Hello"
        }
        """,

        "elseOnSameLine": """
        func check(_ value: Int?) {
            guard let value = value
            else {
                return
            }
            if value > 0 {
                print("positive")
            }
            else {
                print("nonpositive")
            }
        }
        """,

        "emptyBraces": """
        func reset() {

        }
        """,

        "emptyExtensions": """
        extension String {}

        extension Int {
            var doubled: Int { self * 2 }
        }
        """,

        "enumNamespaces": """
        final class FeatureFlags {
            static let isEnabled = true
            static let maxCount = 10
        }

        struct Constants {
            static let appName = "Demo"
            static let version = "1.0"
        }
        """,

        "environmentEntry": """
        import SwiftUI

        struct ScreenNameKey: EnvironmentKey {
            static var defaultValue: String? {
                nil
            }
        }

        extension EnvironmentValues {
            var screenName: String? {
                get { self[ScreenNameKey.self] }
                set { self[ScreenNameKey.self] = newValue }
            }
        }
        """,

        "extensionAccessControl": """
        extension Foo {
            public func bar() {}
            public func baz() {}
        }

        public extension Qux {
            func corge() {}
            func grault() {}
        }
        """,

        "genericExtensions": """
        extension Array where Element == Foo {}

        extension LinkedList where Element == Foo {}
        """,

        "hoistAwait": """
        func loadGreeting() async -> String {
            return greet(await forename(), await surname())
        }
        """,

        "hoistPatternLet": """
        func describe(_ quux: Result<Int, Error>, _ corge: Result<Int, Error>) {
            if case .success(let value) = quux {
                print(value)
            }
            if case let .failure(error) = corge {
                print(error)
            }
        }
        """,

        "hoistTry": """
        func makeMessage() throws -> String {
            return String(try await fetchGreeting(), try fetchName())
        }
        """,

        "indent": """
        func process(_ value: Int) -> String {
        switch value {
        case 0:
        return "zero"
        default:
        return "other"
        }
        }
        """,

        "initCoderUnavailable": """
        import UIKit

        class CustomView: UIView {
            init(frame: CGRect, title: String) {
                super.init(frame: frame)
            }

            required init?(coder aDecoder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        """,

        "isEmpty": """
        func validate(_ items: [String]) -> Bool {
            if items.count == 0 {
                return false
            }
            return items.count > 0
        }
        """,

        "leadingDelimiters": """
        func check(maybeFoo: Int?, maybeBar: Int?) {
            guard let foo = maybeFoo
                , let bar = maybeBar else { return }
            print(foo, bar)
        }
        """,

        "markTypes": """
        final class FooViewController: UIViewController {
            var count = 0
        }

        extension String: FooProtocol {
            var bar: Int { 0 }
        }
        """,

        "modifierOrder": """
        class IconView {
            lazy public weak private(set) var foo: UIView?

            final public override func update() {}
        }
        """,

        "modifiersOnSameLine": """
        struct Counter {
            @MainActor
            public private(set)
            var count: Int = 0

            nonisolated
            func reset() {}
        }
        """
    ]
}
