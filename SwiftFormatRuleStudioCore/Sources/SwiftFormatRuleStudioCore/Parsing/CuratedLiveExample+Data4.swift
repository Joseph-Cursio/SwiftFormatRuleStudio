//
//  CuratedLiveExample+Data4.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension CuratedLiveExample {
    static let dataPart4: [String: String] = [
        "redundantParens": """
        func check(items: [Int]) {
            if (items.isEmpty) {
                return
            }
            while (items.count > 0) {
                process()
            }
        }
        """,

        "redundantPattern": """
        enum Token {
            case number(Int, Int)
            case text(String)
        }

        func describe(_ token: Token) -> String {
            if case .number(_, _) = token {
                return "number"
            }
            let (_, _) = (1, 2)
            return "other"
        }
        """,

        "redundantProperty": """
        func makeFoo() -> Foo {
            let foo = Foo()
            return foo
        }
        """,

        "redundantPublic": """
        struct Foo {
            public let bar: Int
            public func baz() {}
        }
        """,

        "redundantRawValues": """
        enum Direction: String {
            case north = "north"
            case south = "south"
            case east = "east"
            case west = "west"
        }
        """,

        "redundantReturn": """
        var greeting: String {
            return "hello"
        }

        let names = users.filter { return $0.isActive }
        """,

        "redundantSelf": """
        struct Point {
            var posX: Int
            var posY: Int

            init(startX: Int) {
                self.posX = startX
                self.posY = 0
            }

            func translate(byX deltaX: Int) {
                posX = self.posX + deltaX
            }
        }
        """,

        "redundantSendable": """
        struct CacheEntry: Sendable {
            let identifier: String
            let value: Int
        }
        """,

        "redundantSwiftTestingSuite": """
        import Testing

        @Suite
        struct MyFeatureTests {
            @Test func myFeature() {
                #expect(true)
            }
        }
        """,

        "redundantType": """
        class Foo {
            let view: UIView = UIView()

            func method() {
                let label: UILabel = UILabel()
            }
        }
        """,

        "redundantVariable": """
        func makeUser() -> User {
            let user = User(name: "Ada")
            return user
        }
        """,

        "redundantVoidReturnType": """
        func reload() -> Void {
            cache.removeAll()
        }

        let onTap: () -> Void = { () -> Void in
            print("tapped")
        }
        """,

        "semicolons": """
        func configure() {
            let width = 100;
            let height = 50; let area = width * height
            print(area)
        }
        """,

        "simplifyGenericConstraints": """
        struct Cache<Key, Value> where Key: Hashable, Value: Codable {
            var storage: [Key: Value] = [:]
        }

        func process<T>(_ value: T) where T: Codable {
            print(value)
        }
        """,

        "singlePropertyPerLine": """
        struct Config {
            public var foo = 10, bar = false
        }
        """,

        "sortDeclarations": """
        // swiftformat:sort
        enum FeatureFlag {
            case upsell
            case fooFeature
            case barFeature
        }
        """,

        "sortImports": """
        import Foundation
        @testable import MyApp
        import Combine
        import UIKit
        """,

        "sortSwitchCases": """
        func label(for direction: Direction) -> String {
            switch direction {
            case .north, .west, .east, .south:
                return "cardinal"
            case .up, .down:
                return "vertical"
            }
        }
        """,

        "sortTypealiases": """
        typealias Dependencies = Networking & Logging & Caching & Analytics
        """,

        "sortedImports": """
        import UIKit
        @testable import Networking
        import Foundation
        public import Combine
        import AVFoundation
        """,

        "sortedSwitchCases": """
        switch char {
        case "c", "a", "b":
            print("letter")
        default:
            print("other")
        }
        """,

        "spaceAroundBraces": """
        let names = users.filter{ $0.isActive }.map{ $0.name }
        """,

        "spaceAroundBrackets": """
        let value = array [5]
        let cast = foo as[String]
        """,

        "spaceAroundComments": """
        let total = 5// running total
        func reset() {/* clear */}
        """,

        "spaceAroundGenerics": """
        let box = Box <Int> (42)
        let items = Array <String> ()
        """,

        "spaceAroundOperators": """
        func add(lhs: Int, rhs: Int) -> Int {
            let total:Int = lhs+rhs
            let range = 0...total
            return range.count
        }

        func ==(lhs: Int, rhs: Int) -> Bool {
            return lhs == rhs
        }
        """,

        "spaceAroundParens": """
        struct Point {
            init (value: Int) {}

            func classify(_ value: Int) {
                switch(value) {
                case 0: break
                default: break
                }
            }
        }
        """,

        "spaceInsideBraces": """
        let evens = numbers.filter {$0 % 2 == 0}
        let doubled = evens.map {$0 * 2}
        """,

        "spaceInsideBrackets": """
        let values = [ 1, 2, 3 ]
        let first = values[ 0 ]
        """,

        "spaceInsideComments": """
        let total = price * quantity //calculate the total

        func reset() { /*clear all state*/ }
        """
    ]
}
