# organizeDeclarations

The class, struct and enum each get reordered and MARK-ed by default. Raise a
`*-threshold` above a body's line count to stop organizing that kind, or change
`--visibility-order` / `--organization-mode` to re-sort the groups.

```swift
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

struct Bar {
    func beta() {}
    let value: Int = 0
    func alpha() {}
    init() {}
}

enum Baaz {
    func method() {}
    var computed: Int { 0 }
    case one
    case two
}
```
