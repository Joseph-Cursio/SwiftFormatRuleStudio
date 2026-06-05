//
//  CuratedLiveExample+Data3.swift
//  SwiftFormatRuleStudio
//

import Foundation

extension CuratedLiveExample {
    static let dataPart3: [String: String] = [
        "noExplicitOwnership": """
        borrowing func process(_ value: consuming Data) {
            store(value)
        }
        """,

        "noForceTryInTests": """
        import Testing

        struct MyFeatureTests {
            @Test func doSomething() {
                try! MyFeature().doSomething()
            }
        }
        """,

        "noForceUnwrapInTests": """
        import Testing

        struct MyFeatureTests {
            @Test func myFeature() {
                let myValue = foo.bar!.value
                #expect(myValue!.property == other)
            }
        }
        """,

        "noGuardInTests": """
        import XCTest

        final class SomeTestCase: XCTestCase {
            func test_something() {
                guard let value = optionalValue, value.matchesCondition else {
                    XCTFail()
                    return
                }
                print(value)
            }
        }
        """,

        "numberFormatting": """
        let population = 1234567
        let color = 0xFF77A5
        let mask = 0b10101010
        let scaled = 1.5e123456
        let pi = 3.14159265
        """,

        "opaqueGenericParameters": """
        func handle<T: Fooable>(_ value: T) {
            print(value)
        }

        func process<T>(_ value: T) {
            print(value)
        }
        """,

        "organizeDeclarations": """
        public class Foo {
            public func c() -> String { "" }

            public let a: Int = 1
            private let g: Int = 2
            let e: Int = 2
            public let b: Int = 3

            public func d() {}
            func f() {}
            init() {}
            deinit {}
        }
        """,

        "preferCountWhere": """
        func activeUserCount(_ users: [User]) -> Int {
            users.filter { $0.isActive }.count
        }
        """,

        "preferExplicitFalse": """
        func process(flag: Bool, items: [Int]) {
            if !flag {
                return
            }
            guard !items.isEmpty else { return }
        }
        """,

        "preferFinalClasses": """
        class NetworkManager {
            let baseURL: URL

            init(baseURL: URL) {
                self.baseURL = baseURL
            }
        }
        """,

        "preferForLoop": """
        let strings = ["foo", "bar", "baaz"]

        strings.forEach { item in
            print(item)
        }

        strings.forEach { print($0) }
        """,

        "preferKeyPath": """
        let names = users.map { $0.name }
        let active = users.compactMap { $0.session }
        """,

        "preferSwiftStringAPI": """
        func sanitize(_ text: String) -> String {
            return text.replacingOccurrences(of: "foo", with: "bar")
        }
        """,

        "preferSwiftTesting": """
        import XCTest

        final class CalculatorTests: XCTestCase {
            func testAddition() {
                let result = 2 + 2
                XCTAssertEqual(result, 4)
                XCTAssertTrue(result > 0)
            }
        }
        """,

        "privateStateVariables": """
        import SwiftUI

        struct CounterView: View {
            @State var count = 0
            @StateObject var model = CounterModel()

            var body: some View {
                Text("\\(count)")
            }
        }
        """,

        "propertyTypes": """
        class Foo {
            let view = UIView()

            func setup() {
                let color: Color = .red
            }
        }
        """,

        "redundantBackticks": """
        let `value` = 42
        func send(to `recipient`: String) {
            print(`recipient`)
        }
        """,

        "redundantBreak": """
        func describe(_ value: Int) {
            switch value {
            case 0:
                print("zero")
                break
            default:
                print("other")
                break
            }
        }
        """,

        "redundantClosure": """
        let foo = { Foo() }()
        """,

        "redundantEmptyView": """
        import SwiftUI

        struct StatusBadge: View {
            let isActive: Bool

            var body: some View {
                if isActive {
                    Text("Online")
                } else {
                    EmptyView()
                }
            }
        }
        """,

        "redundantExtensionACL": """
        public extension URL {
            public func queryParameter(_ name: String) -> String {
                return ""
            }
        }
        """,

        "redundantFileprivate": """
        struct Settings {
            fileprivate let apiKey = "secret"
        }
        """,

        "redundantGet": """
        struct Circle {
            let radius: Double
            var area: Double {
                get {
                    return radius * radius * 3.14159
                }
            }
        }
        """,

        "redundantInit": """
        let greeting = String.init("Hello")
        let count = Int.init("42")
        let copy = Array.init(repeating: 0, count: 3)
        """,

        "redundantInternal": """
        internal struct Counter {
            internal var count = 0

            internal func increment() {
                count += 1
            }
        }
        """,

        "redundantLet": """
        func process() {
            let _ = computeResult()
            if let _ = optionalValue {
                print("present")
            }
        }
        """,

        "redundantLetError": """
        func loadData() {
            do {
                try performRequest()
            } catch let error {
                print("Request failed: \\(error)")
            }
        }
        """,

        "redundantNilInit": """
        struct UserProfile {
            var nickname: String? = nil
            var age: Int?
        }
        """,

        "redundantObjc": """
        class ProfileView: UIView {
            @objc @IBOutlet var nameLabel: UILabel!

            @IBAction @objc func saveTapped() {}
        }
        """,

        "redundantOptionalBinding": """
        func greet(_ name: String?) {
            if let name = name {
                print("Hello, \\(name)")
            }
        }
        """
    ]
}
