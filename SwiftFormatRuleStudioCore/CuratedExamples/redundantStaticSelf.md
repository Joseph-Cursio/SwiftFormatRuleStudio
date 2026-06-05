# redundantStaticSelf

```swift
enum Foo {
    static let bar = Bar()

    static func makeBaaz() -> Bar {
        Self.bar
    }
}
```
